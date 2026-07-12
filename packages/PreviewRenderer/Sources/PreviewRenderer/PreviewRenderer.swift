import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema

public enum PreviewStatus: String, Codable, Sendable { case valid, rejected }

public struct RenderedPreview: Sendable {
    public var id: UUID
    public var sourceSnapshotID: UUID
    public var plan: ProcessingPlan
    public var audio: AudioBuffer
    public var analysis: AnalysisReport
    public var loudnessMatchGainDB: Double
    public var status: PreviewStatus
    public var rejectionReasons: [String]
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
        if plan.outputConstraints.loudnessMatchPreview {
            let originalRMS = rms(source), renderedRMS = rms(result)
            if renderedRMS > 1e-12 {
                let desired = originalRMS / renderedRMS
                let peak = result.channels.flatMap { $0 }.map { abs(Double($0)) }.max() ?? 0
                let ceiling = pow(10, plan.outputConstraints.maxTruePeakDB / 20)
                let peakSafe = peak > 0 ? ceiling / peak : desired
                let gain = min(desired, peakSafe)
                matchDB = 20 * log10(max(gain, 1e-12))
                for channel in result.channels.indices { for frame in result.channels[channel].indices { result.channels[channel][frame] *= Float(gain) } }
            }
        }
        let report = analyzer.analyze(result)
        var reasons: [String] = []
        let peakDB = report.metrics["peak_dbfs"]?.value ?? -240
        if peakDB > plan.outputConstraints.maxTruePeakDB + 0.05 { reasons.append("Sample peak exceeded the configured ceiling.") }
        if plan.outputConstraints.preserveMonoCompatibility,
           let correlation = report.metrics["stereo_correlation"]?.value, correlation < -0.2 { reasons.append("Stereo correlation violated the mono-compatibility constraint.") }
        if plan.goals.contains(where: { $0.attribute == .cymbalHarshness && $0.direction == .doNotIncrease }),
           let before = originalAnalysis.metrics["high_band_ratio"]?.value,
           let after = report.metrics["high_band_ratio"]?.value, after > before + 0.03 { reasons.append("High-band energy increased beyond the cymbal-harshness guardrail.") }
        return RenderedPreview(
            id: UUID(), sourceSnapshotID: plan.sourceSnapshotID, plan: plan, audio: result, analysis: report,
            loudnessMatchGainDB: matchDB, status: reasons.isEmpty ? .valid : .rejected, rejectionReasons: reasons
        )
    }

    private func rms(_ buffer: AudioBuffer) -> Double {
        var energy = 0.0, count = 0
        for channel in buffer.channels { for sample in channel { energy += Double(sample * sample); count += 1 } }
        return count > 0 ? sqrt(energy / Double(count)) : 0
    }
}
