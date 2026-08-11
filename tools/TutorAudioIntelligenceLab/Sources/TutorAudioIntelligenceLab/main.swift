import CryptoKit
import DSPCore
import Foundation
import PlanSchema
import TutorConversation

@main
struct TutorAudioIntelligenceLab {
    struct ProviderAssertion: Codable {
        var name: String
        var passed: Bool
        var observedIdentifiers: [String]
        var bindingStatus: String?
    }

    struct FixtureResult: Codable {
        var id: String
        var task: String
        var passed: Bool
        var detail: String
        var wavSHA256: String
        var providerAssertions: [ProviderAssertion]
    }

    struct Manifest: Codable {
        var schemaVersion = "1.0"
        var suite = "tracksmith-tutor-audio-intelligence-deterministic-v1"
        var scope = "Synthetic WAV fixtures validate deterministic measurement behavior only; they do not validate Tutor decision quality, model listening, Logic runtime, or owner listening."
        var fixtures: [FixtureResult]
    }

    static func main() async throws {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--output"), args.indices.contains(flag + 1) else {
            throw LabError.usage
        }
        let output = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        let fixtureDirectory = output.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)

        let rate = 48_000.0
        let frameCount = 48_000
        let base = tone(rate: rate, frames: frameCount, frequency: 440, amplitude: 0.25)
        let fixtures: [(String, String, AudioBuffer, String)] = [
            ("null-identity", "identity", base, "Exact WAV identity and decode reach the named production provider."),
            ("gain-loudness", "gainLoudness", scaled(base, 2), "Named provider emits bounded local WAV measurements for gain/loudness fixture."),
            ("tonal-tilt", "tonalTilt", tonalTilt(rate: rate, frames: frameCount), "Named provider emits bounded local WAV measurements for tonal fixture."),
            ("dynamics", "dynamics", dynamics(rate: rate, frames: frameCount), "Named provider emits bounded local WAV measurements for dynamics fixture."),
            ("stereo-width-relation", "stereoRelation", stereoWide(rate: rate, frames: frameCount), "Named provider emits bounded local WAV measurements for stereo fixture."),
        ]
        var results: [FixtureResult] = []
        let specialist = LocalWaveformSpecialist()
        var baselineProviderResult: TutorAudioIntelligenceResult?
        for (id, task, buffer, detail) in fixtures {
            let file = fixtureDirectory.appendingPathComponent("\(id).wav")
            try WAVFile.writeFloat32(buffer, url: file)
            let decoded = try WAVFile.read(url: file)
            let data = try Data(contentsOf: file)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let capture = TutorCaptureSnapshot(
                sourceType: .fullMix, instanceID: UUID(), runtimeEpoch: UUID(), captureSnapshotID: UUID(), sha256: digest,
                capturedAt: Date(timeIntervalSince1970: 0), durationSeconds: Double(decoded.frameCount) / decoded.sampleRate,
                scopeDescription: "Synthetic deterministic lab fixture", formatDescription: "48000 Hz \(decoded.channelCount == 1 ? "mono" : "stereo") WAV",
                isLive: true, metrics: [], localAnalysisLimitations: []
            )
            let providerResult = await specialist.analyze(wavData: data, capture: capture)
            let bindingPass = providerResult.waveformBindingStatus == .captureBoundExactWAV
            let observationsPass = !providerResult.observations.isEmpty && providerResult.observations.allSatisfy { $0.evidence == .localMeasurement }
            if id == "null-identity" { baselineProviderResult = providerResult }
            let taskAssertion = providerTaskAssertion(task: task, baseline: baselineProviderResult, result: providerResult)
            let providerAssertions = [
                ProviderAssertion(name: "capture-bound-exact-wav", passed: bindingPass, observedIdentifiers: providerResult.observations.map(\.identifier), bindingStatus: providerResult.waveformBindingStatus?.rawValue),
                ProviderAssertion(name: "provider-local-observations", passed: observationsPass, observedIdentifiers: providerResult.observations.map(\.identifier), bindingStatus: providerResult.waveformBindingStatus?.rawValue),
                ProviderAssertion(name: "provider-task-measurement", passed: taskAssertion, observedIdentifiers: providerResult.observations.map(\.identifier), bindingStatus: providerResult.waveformBindingStatus?.rawValue),
            ]
            results.append(FixtureResult(
                id: id, task: task, passed: providerAssertions.allSatisfy(\.passed), detail: detail,
                wavSHA256: digest, providerAssertions: providerAssertions
            ))
        }
        let malformedCapture = TutorCaptureSnapshot(sourceType: .fullMix, instanceID: UUID(), runtimeEpoch: UUID(), captureSnapshotID: UUID(), sha256: SHA256.hash(data: Data("not wav".utf8)).map { String(format: "%02x", $0) }.joined(), capturedAt: .distantPast, durationSeconds: 0, scopeDescription: "Synthetic malformed fixture", formatDescription: "unknown", isLive: true, metrics: [], localAnalysisLimitations: [])
        let malformed = await specialist.analyze(wavData: Data("not wav".utf8), capture: malformedCapture)
        guard malformed.waveformBindingStatus == .bytesReceivedUndecodable, malformed.failure != nil else { throw LabError.fixtureFailure }
        var mismatched = malformedCapture; mismatched.sha256 = String(repeating: "0", count: 64)
        let mismatch = await specialist.analyze(wavData: Data("not wav".utf8), capture: mismatched)
        guard mismatch.waveformBindingStatus == .bytesReceivedHashMismatch, mismatch.failure != nil else { throw LabError.fixtureFailure }
        guard results.allSatisfy(\.passed) else { throw LabError.fixtureFailure }
        let manifest = Manifest(fixtures: results)
        try write(manifest, to: output.appendingPathComponent("fixture-manifest.json"))
        let matrix: [String: Any] = [
            "schemaVersion": "1.0",
            "provider": "tracksmith-local-waveform-specialist-v1",
            "calibratedTasks": results.filter(\.passed).map(\.task),
            "notCalibrated": ["wholeMixMasking", "subjectiveImprovement", "modelListening", "ownerListening", "sourceSeparation", "musicStructure"],
            "scope": "Calibration covers named production provider-path exact-WAV decode and local-observation availability on synthetic fixtures only; it does not establish perceptual direction or Tutor decision quality.",
            "negativeProviderAssertions": ["hashMismatch", "undecodableWAV"],
        ]
        let matrixData = try JSONSerialization.data(withJSONObject: matrix, options: [.prettyPrinted, .sortedKeys])
        try matrixData.write(to: output.appendingPathComponent("capability-calibration-matrix.json"), options: .atomic)
        print("TutorAudioIntelligenceLab: \(results.count)/\(results.count) deterministic fixtures passed")
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    static func providerTaskAssertion(task: String, baseline: TutorAudioIntelligenceResult?, result: TutorAudioIntelligenceResult) -> Bool {
        guard let baseline else { return false }
        func value(_ input: TutorAudioIntelligenceResult, _ id: String) -> Double? { input.observations.first(where: { $0.identifier == id })?.value }
        switch task {
        case "identity": return result.waveformBindingStatus == .captureBoundExactWAV && !result.observations.isEmpty
        case "gainLoudness": return (value(result, "integrated_loudness_lufs") ?? -.infinity) > (value(baseline, "integrated_loudness_lufs") ?? .infinity)
        case "tonalTilt": return (value(result, "mix_above_4_khz_energy_ratio") ?? 0) > (value(baseline, "mix_above_4_khz_energy_ratio") ?? 1)
        case "dynamics": return (value(result, "mix_crest_factor_p90") ?? 0) > (value(baseline, "mix_crest_factor_p90") ?? .infinity)
        case "stereoRelation": return (value(result, "side_energy_share") ?? 0) > (value(baseline, "side_energy_share") ?? 1)
        default: return false
        }
    }

    static func tone(rate: Double, frames: Int, frequency: Double, amplitude: Float) -> AudioBuffer {
        let samples = (0..<frames).map { Float(sin(2 * Double.pi * frequency * Double($0) / rate)) * amplitude }
        return AudioBuffer(channels: [samples], sampleRate: rate)
    }
    static func scaled(_ buffer: AudioBuffer, _ factor: Float) -> AudioBuffer { AudioBuffer(channels: buffer.channels.map { $0.map { $0 * factor } }, sampleRate: buffer.sampleRate) }
    static func tonalTilt(rate: Double, frames: Int) -> AudioBuffer {
        let low = tone(rate: rate, frames: frames, frequency: 440, amplitude: 0.20).channels[0]
        let high = tone(rate: rate, frames: frames, frequency: 6_000, amplitude: 0.24).channels[0]
        return AudioBuffer(channels: [zip(low, high).map(+)], sampleRate: rate)
    }
    static func dynamics(rate: Double, frames: Int) -> AudioBuffer {
        let source = tone(rate: rate, frames: frames, frequency: 440, amplitude: 0.12).channels[0]
        return AudioBuffer(channels: [source.enumerated().map { index, value in index % 600 < 12 ? value * 7 : value }], sampleRate: rate)
    }
    static func stereoWide(rate: Double, frames: Int) -> AudioBuffer {
        let left = tone(rate: rate, frames: frames, frequency: 440, amplitude: 0.25).channels[0]
        let right = tone(rate: rate, frames: frames, frequency: 880, amplitude: 0.25).channels[0]
        return AudioBuffer(channels: [left, right], sampleRate: rate)
    }
    static func identical(_ lhs: AudioBuffer, _ rhs: AudioBuffer) -> Bool { lhs == rhs }
    static func rms(_ buffer: AudioBuffer) -> Double { sqrt(buffer.channels.flatMap { $0 }.reduce(0) { $0 + Double($1 * $1) } / Double(max(1, buffer.frameCount * buffer.channelCount))) }
    static func crest(_ buffer: AudioBuffer) -> Double { Double(buffer.channels.flatMap { $0 }.map { abs($0) }.max() ?? 0) / max(rms(buffer), 1e-12) }
    /// A deterministic high-frequency proxy for the synthetic tonal fixture.
    static func highBandEnergy(_ buffer: AudioBuffer) -> Double {
        Double(buffer.channels.flatMap { $0 }.dropFirst().enumerated().reduce(0) { count, item in
            let previous = buffer.channels.flatMap { $0 }[item.offset]
            return count + ((previous.sign != item.element.sign) ? 1 : 0)
        })
    }
    static func correlation(_ buffer: AudioBuffer) -> Double {
        guard buffer.channelCount == 2 else { return 1 }
        let l = buffer.channels[0], r = buffer.channels[1]
        let dot = zip(l, r).reduce(0.0) { $0 + Double($1.0 * $1.1) }
        return dot / sqrt(l.reduce(0.0) { $0 + Double($1 * $1) } * r.reduce(0.0) { $0 + Double($1 * $1) })
    }
    enum LabError: Error { case usage, fixtureFailure }
}
