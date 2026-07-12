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
        try PlanValidator().validate(plan)
        let originalAnalysis = analyzer.analyze(source)
        var result = source
        var graph = try CompiledGraph(plan: plan, sampleRate: source.sampleRate, channelCount: source.channelCount)
        try graph.process(&result)
        var matchDB = 0.0
        var matchMethod = LoudnessMatchMethod.unavailable
        if plan.outputConstraints.loudnessMatchPreview {
            let renderedBeforeMatch = analyzer.analyze(result)
            let desired: Double
            if let originalLUFS = originalAnalysis.metrics["integrated_loudness_lufs"]?.value,
               let renderedLUFS = renderedBeforeMatch.metrics["integrated_loudness_lufs"]?.value {
                desired = pow(10, (originalLUFS - renderedLUFS) / 20)
                matchMethod = .bs1770Integrated
            } else {
                let originalRMS = rms(source), renderedRMS = rms(result)
                desired = renderedRMS > 1e-12 ? originalRMS / renderedRMS : 1
                matchMethod = renderedRMS > 1e-12 ? .rmsFallback : .unavailable
            }
            if matchMethod != .unavailable {
                let truePeakDBTP = renderedBeforeMatch.metrics["true_peak_dbtp"]?.value ?? -240
                let truePeak = pow(10, truePeakDBTP / 20)
                let ceiling = pow(10, plan.outputConstraints.maxTruePeakDB / 20)
                let peakSafe = truePeak > 0 ? ceiling / truePeak : desired
                let gain = max(0, min(desired, peakSafe))
                matchDB = 20 * log10(max(gain, 1e-12))
                for channel in result.channels.indices { for frame in result.channels[channel].indices { result.channels[channel][frame] *= Float(gain) } }
            }
        }
        let report = analyzer.analyze(result)
        var reasons: [String] = []
        var warnings: [String] = []
        let peakDB = report.metrics["true_peak_dbtp"]?.value ?? -240
        if peakDB > plan.outputConstraints.maxTruePeakDB + 0.05 { reasons.append("Estimated true peak exceeded the configured ceiling.") }
        if plan.outputConstraints.preserveMonoCompatibility,
           let correlation = report.metrics["stereo_correlation"]?.value, correlation < -0.2 { reasons.append("Stereo correlation violated the mono-compatibility constraint.") }
        if plan.goals.contains(where: { $0.attribute == .cymbalHarshness && $0.direction == .doNotIncrease }),
           let before = originalAnalysis.metrics["high_band_ratio"]?.value,
           let after = report.metrics["high_band_ratio"]?.value, after > before + 0.03 { reasons.append("High-band energy increased beyond the cymbal-harshness guardrail.") }
        let difference = differenceMetrics(original: source, rendered: result, originalAnalysis: originalAnalysis, renderedAnalysis: report)
        if difference.differenceRMSDBFS < -42 {
            warnings.append("The level-matched result may be difficult to distinguish; increase processing strength or choose a more representative capture.")
        }
        return RenderedPreview(
            id: UUID(), sourceSnapshotID: plan.sourceSnapshotID, plan: plan, audio: result, analysis: report,
            loudnessMatchGainDB: matchDB, loudnessMatchMethod: matchMethod, difference: difference,
            status: reasons.isEmpty ? .valid : .rejected, rejectionReasons: reasons, warnings: warnings
        )
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
