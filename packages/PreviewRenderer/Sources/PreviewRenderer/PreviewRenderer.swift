import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema

public enum PreviewStatus: String, Codable, Sendable { case valid, rejected }

public enum LoudnessMatchMethod: String, Codable, Sendable {
    case bs1770Integrated
    case rmsFallback
    case unavailable
}

public struct PreviewDifferenceMetrics: Codable, Equatable, Sendable {
    public var differenceRMSDBFS: Double
    public var crestFactorDeltaDB: Double
    public var spectralCentroidDeltaHz: Double
    public var bandEnergyDistance: Double
}

public struct RenderedPreview: Sendable {
    public var id: UUID
    public var sourceSnapshotID: UUID
    public var plan: ProcessingPlan
    public var audio: AudioBuffer
    public var analysis: AnalysisReport
    public var loudnessMatchGainDB: Double
    public var loudnessMatchMethod: LoudnessMatchMethod
    public var difference: PreviewDifferenceMetrics
    public var status: PreviewStatus
    public var rejectionReasons: [String]
    public var warnings: [String]
}

public struct PreviewRenderer: Sendable {
    private let analyzer = AudioAnalyzer()
    public init() {}

    public func render(plan: ProcessingPlan, source: AudioBuffer) throws -> RenderedPreview {
        try PlanValidator().validateForRealtimeActivation(plan)
        let originalAnalysis = analyzer.analyze(source)
        let unmatchedResult = try renderAudio(plan: plan, source: source)
        let unmatchedAnalysis = analyzer.analyze(unmatchedResult)
        var committedPlan = plan
        var matchDB = committedPlan.nodes
            .filter { $0.enabled && $0.type == .loudnessMatch }
            .reduce(0) { $0 + $1.parameters[.gainDB, default: 0] }
        var matchMethod = LoudnessMatchMethod.unavailable
        var warnings: [String] = []
        var matchWasLimited = false

        // A preview must be the exact graph that will be committed. Derive the
        // comparison gain from the unmatched graph, materialize it as a normal
        // processing node, then start over with a freshly compiled final graph.
        // Starting over also includes the gain node's real-time smoothing in the
        // audition instead of applying an offline-only scalar multiplication.
        let hasMaterializedMatch = committedPlan.nodes.contains { $0.enabled && $0.type == .loudnessMatch }
        if plan.outputConstraints.loudnessMatchPreview, !hasMaterializedMatch {
            let target = loudnessMatchTarget(
                source: source,
                originalAnalysis: originalAnalysis,
                rendered: unmatchedResult,
                renderedAnalysis: unmatchedAnalysis
            )
            matchMethod = target.method
            if target.method != .unavailable {
                let peakLimitedDB = plan.outputConstraints.maxTruePeakDB
                    - (unmatchedAnalysis.metrics["true_peak_dbtp"]?.value ?? -240)
                let remainingAddedGainDB = max(
                    0,
                    plan.outputConstraints.maxAddedGainDB - requestedPositiveGainDB(in: plan)
                )
                let upperBoundDB = min(peakLimitedDB, remainingAddedGainDB, 24)
                matchDB = max(-60, min(target.gainDB, upperBoundDB))
                matchWasLimited = target.gainDB - matchDB > 0.05
                let matchNode = ProcessingNode(
                    id: loudnessMatchNodeID(for: committedPlan),
                    type: .loudnessMatch,
                    parameters: [.gainDB: matchDB],
                    rationale: "Persist the measured preview compensation so the audition and committed processing are identical.",
                    confidence: 1,
                    category: .loudness
                )
                // Keep the final safety limiter last. A positive level match
                // placed after it could exceed the ceiling on later live input
                // even when the captured preview itself happened to be safe.
                let matchIndex = committedPlan.nodes.lastIndex {
                    $0.enabled && $0.type == .limiter
                } ?? committedPlan.nodes.endIndex
                committedPlan.nodes.insert(matchNode, at: matchIndex)
                try PlanValidator().validateForRealtimeActivation(committedPlan)

                // Gain nodes use the same 10 ms smoothing online and offline.
                // On a short capture, applying the analytically derived target
                // once can miss because both the existing graph and this new
                // node start from their reset states. Calibrate against complete
                // fresh renders, retaining the last plan that was actually
                // rendered, so even these short auditions remain exact.
                for _ in 0..<3 {
                    let calibratedAudio = try renderAudio(plan: committedPlan, source: source)
                    let calibratedAnalysis = analyzer.analyze(calibratedAudio)
                    let residual = loudnessMatchTarget(
                        source: source,
                        originalAnalysis: originalAnalysis,
                        rendered: calibratedAudio,
                        renderedAnalysis: calibratedAnalysis
                    )
                    guard residual.method != .unavailable, abs(residual.gainDB) > 0.01 else { break }
                    let proposedDB = matchDB + residual.gainDB
                    let calibratedDB = max(-60, min(proposedDB, upperBoundDB))
                    if proposedDB - calibratedDB > 0.05 { matchWasLimited = true }
                    guard abs(calibratedDB - matchDB) > 0.001 else { break }
                    matchDB = calibratedDB
                    committedPlan.nodes[matchIndex].parameters[.gainDB] = matchDB
                    try PlanValidator().validateForRealtimeActivation(committedPlan)
                }
            }
        }

        if matchWasLimited {
            warnings.append("Level matching was limited by the true-peak ceiling or the plan's added-gain budget.")
        }

        let result = committedPlan == plan
            ? unmatchedResult
            : try renderAudio(plan: committedPlan, source: source)
        let report = committedPlan == plan ? unmatchedAnalysis : analyzer.analyze(result)
        var reasons: [String] = []
        let peakDB = report.metrics["true_peak_dbtp"]?.value ?? -240
        if peakDB > committedPlan.outputConstraints.maxTruePeakDB + 0.05 {
            reasons.append("The exact committed graph exceeds the configured true-peak ceiling.")
        }
        let difference = differenceMetrics(
            original: source,
            rendered: result,
            originalAnalysis: originalAnalysis,
            renderedAnalysis: report
        )
        if committedPlan.outputConstraints.preserveMonoCompatibility,
           let correlation = report.metrics["stereo_correlation"]?.value, correlation < -0.2 { reasons.append("Stereo correlation violated the mono-compatibility constraint.") }
        if committedPlan.goals.contains(where: {
            ($0.attribute == .harshness || $0.attribute == .cymbalHarshness)
                && ($0.direction == .doNotIncrease || $0.direction == .decrease)
        }),
           let before = originalAnalysis.metrics["high_band_ratio"]?.value,
           let after = report.metrics["high_band_ratio"]?.value, after > before + 0.03 { reasons.append("High-band energy increased beyond the explicit harshness guardrail.") }
        if committedPlan.goals.contains(where: {
            $0.attribute == .brightness && ($0.direction == .preserve || $0.direction == .doNotDecrease)
        }),
           let before = originalAnalysis.metrics["high_band_ratio"]?.value,
           let after = report.metrics["high_band_ratio"]?.value,
           after < before - 0.03 {
            reasons.append("High-band energy fell beyond the measurable air/brightness preservation guardrail.")
        }
        if committedPlan.goals.contains(where: {
            $0.attribute == .lowEnd && ($0.direction == .preserve || $0.direction == .doNotDecrease)
        }),
           let before = originalAnalysis.metrics["low_band_ratio"]?.value,
           let after = report.metrics["low_band_ratio"]?.value,
           after < before - 0.03 {
            reasons.append("Low-band energy fell beyond the explicit low-end-weight preservation guardrail.")
        }
        if committedPlan.goals.contains(where: {
            $0.attribute == .punch && ($0.direction == .preserve || $0.direction == .doNotDecrease)
        }), difference.crestFactorDeltaDB < -1.5 {
            reasons.append("Crest behavior fell beyond the measurable pick-attack/punch preservation guardrail.")
        }
        if committedPlan.goals.contains(where: {
            $0.attribute == .dynamicControl && ($0.direction == .preserve || $0.direction == .doNotDecrease)
        }) {
            if difference.crestFactorDeltaDB < -2 {
                reasons.append("Crest behavior fell beyond the measurable dynamics-preservation guardrail.")
            } else if abs(difference.crestFactorDeltaDB) > 3 {
                warnings.append("Crest behavior changed materially despite the dynamics-preservation request; listening is decisive because crest factor is not musical dynamics by itself.")
            }
        }
        if let originalRMSDBFS = originalAnalysis.metrics["rms_dbfs"]?.value,
           originalRMSDBFS.isFinite,
           difference.differenceRMSDBFS < originalRMSDBFS - 30 {
            warnings.append("The level-matched result may be difficult to distinguish; increase processing strength or choose a more representative capture.")
        }
        return RenderedPreview(
            id: UUID(), sourceSnapshotID: committedPlan.sourceSnapshotID, plan: committedPlan, audio: result, analysis: report,
            loudnessMatchGainDB: matchDB, loudnessMatchMethod: matchMethod, difference: difference,
            status: reasons.isEmpty ? .valid : .rejected, rejectionReasons: reasons, warnings: warnings
        )
    }

    public func compare(reference: AudioBuffer, candidate: AudioBuffer) throws -> PreviewDifferenceMetrics {
        guard reference.sampleRate == candidate.sampleRate,
              reference.channelCount == candidate.channelCount,
              reference.frameCount == candidate.frameCount else {
            throw DSPError.channelFormatChanged(expected: reference.channelCount, actual: candidate.channelCount)
        }
        return differenceMetrics(
            original: reference,
            rendered: candidate,
            originalAnalysis: analyzer.analyze(reference),
            renderedAnalysis: analyzer.analyze(candidate)
        )
    }

    private func renderAudio(plan: ProcessingPlan, source: AudioBuffer) throws -> AudioBuffer {
        var result = source
        var graph = try CompiledGraph(
            plan: plan,
            sampleRate: source.sampleRate,
            channelCount: source.channelCount
        )
        try graph.process(&result)
        return result
    }

    private func loudnessMatchTarget(
        source: AudioBuffer,
        originalAnalysis: AnalysisReport,
        rendered: AudioBuffer,
        renderedAnalysis: AnalysisReport
    ) -> (gainDB: Double, method: LoudnessMatchMethod) {
        if let originalLUFS = originalAnalysis.metrics["integrated_loudness_lufs"]?.value,
           let renderedLUFS = renderedAnalysis.metrics["integrated_loudness_lufs"]?.value,
           originalLUFS.isFinite, renderedLUFS.isFinite {
            return (originalLUFS - renderedLUFS, .bs1770Integrated)
        }
        let originalRMS = rms(source)
        let renderedRMS = rms(rendered)
        guard originalRMS.isFinite, renderedRMS.isFinite, originalRMS > 0, renderedRMS > 1e-12 else {
            return (0, .unavailable)
        }
        return (20 * log10(originalRMS / renderedRMS), .rmsFallback)
    }

    private func requestedPositiveGainDB(in plan: ProcessingPlan) -> Double {
        plan.nodes.reduce(0) { total, node in
            guard node.enabled else { return total }
            return total + node.parameters.reduce(0) { subtotal, parameter in
                guard [.gainDB, .makeupGainDB].contains(parameter.key), parameter.value > 0 else {
                    return subtotal
                }
                return subtotal + parameter.value
            }
        }
    }

    private func loudnessMatchNodeID(for plan: ProcessingPlan) -> UUID {
        var bytes = plan.requestID.uuid
        bytes.0 ^= 0x4c
        bytes.1 ^= 0x41
        bytes.2 ^= 0x41
        bytes.3 ^= 0x4d
        bytes.6 = (bytes.6 & 0x0f) | 0x50
        bytes.8 = (bytes.8 & 0x3f) | 0x80
        var candidate = UUID(uuid: bytes)
        while plan.nodes.contains(where: { $0.id == candidate }) {
            bytes.15 &+= 1
            candidate = UUID(uuid: bytes)
        }
        return candidate
    }

    private func rms(_ buffer: AudioBuffer) -> Double {
        var energy = 0.0, count = 0
        for channel in buffer.channels { for sample in channel { energy += Double(sample * sample); count += 1 } }
        return count > 0 ? sqrt(energy / Double(count)) : 0
    }

    private func differenceMetrics(
        original: AudioBuffer,
        rendered: AudioBuffer,
        originalAnalysis: AnalysisReport,
        renderedAnalysis: AnalysisReport
    ) -> PreviewDifferenceMetrics {
        var squareError = 0.0
        var count = 0
        for channel in original.channels.indices {
            for frame in original.channels[channel].indices {
                let delta = Double(rendered.channels[channel][frame] - original.channels[channel][frame])
                squareError += delta * delta
                count += 1
            }
        }
        let differenceRMS = count > 0 ? sqrt(squareError / Double(count)) : 0
        let beforeCrest = originalAnalysis.metrics["crest_factor"]?.value ?? 0
        let afterCrest = renderedAnalysis.metrics["crest_factor"]?.value ?? 0
        let crestDelta = 20 * log10(max(afterCrest, 1e-12) / max(beforeCrest, 1e-12))
        let centroidDelta = (renderedAnalysis.metrics["spectral_centroid_hz"]?.value ?? 0)
            - (originalAnalysis.metrics["spectral_centroid_hz"]?.value ?? 0)
        let bandKeys = ["low_band_ratio", "mid_band_ratio", "high_band_ratio"]
        let bandDistance = sqrt(bandKeys.reduce(0.0) { partial, key in
            let delta = (renderedAnalysis.metrics[key]?.value ?? 0) - (originalAnalysis.metrics[key]?.value ?? 0)
            return partial + delta * delta
        })
        return .init(
            differenceRMSDBFS: differenceRMS > 0 ? 20 * log10(differenceRMS) : -240,
            crestFactorDeltaDB: crestDelta.isFinite ? crestDelta : 0,
            spectralCentroidDeltaHz: centroidDelta,
            bandEnergyDistance: bandDistance
        )
    }
}
