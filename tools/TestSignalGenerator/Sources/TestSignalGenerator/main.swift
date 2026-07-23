import CryptoKit
import DSPCore
import Foundation

@main
enum TestSignalGenerator {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.first == "--logic-measurement-suite" {
                guard arguments.count == 2 else {
                    throw GeneratorError.usage(
                        "usage: TestSignalGenerator --logic-measurement-suite OUTPUT_DIRECTORY"
                    )
                }
                try writeLogicMeasurementSuite(to: URL(fileURLWithPath: arguments[1], isDirectory: true))
                return
            }

            let path = arguments.first ?? "fixtures/generated/demo-vocal.wav"
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let buffer = makeVocalLikeFixture()
            try WAVFile.writePCM24(buffer, url: url)
            print("Wrote deterministic PCM24 fixture:")
            print(url.standardizedFileURL.path)
            print(
                "duration=\(String(format: "%.2f", Double(buffer.frameCount) / buffer.sampleRate))s "
                    + "sample_rate=\(Int(buffer.sampleRate)) channels=\(buffer.channelCount)"
            )
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(2)
        }
    }

    private static func writeLogicMeasurementSuite(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let signals: [(String, String, AudioBuffer)] = [
            (
                "silence_mono.wav",
                "Noise-floor, self-noise, modulation-tail, denormal, and false-output check.",
                makeSilence()
            ),
            (
                "single_impulse_mono.wav",
                "Linear impulse response, latency, polarity, delay, early-reflection, and tail inspection at a conservative level.",
                makeSingleImpulse()
            ),
            (
                "impulse_level_ladder_mono.wav",
                "Level-dependent impulse response and nonlinear state comparison without assuming one transfer function.",
                makeImpulseLevelLadder()
            ),
            (
                "log_sweep_20hz_20khz_mono.wav",
                "Broadband frequency-response, time variance, resonance, distortion-product, and tail characterization.",
                makeLogSweep()
            ),
            (
                "amplitude_ladder_1khz_mono.wav",
                "Input/output curve, threshold, knee, gain staging, clipping, gating, and level-dependent tone characterization.",
                makeAmplitudeLadder()
            ),
            (
                "multitone_mono.wav",
                "Steady broadband response and intermodulation inspection under simultaneous partials.",
                makeMultitone()
            ),
            (
                "smpte_imd_60hz_7khz_mono.wav",
                "SMPTE-style intermodulation probe using a 4:1 low/high-frequency amplitude relationship.",
                makeTwoTone(lowFrequency: 60, highFrequency: 7_000, lowAmplitude: 0.20, highAmplitude: 0.05)
            ),
            (
                "ccif_imd_19khz_20khz_mono.wav",
                "High-frequency two-tone difference-product and alias/nonlinearity probe.",
                makeTwoTone(lowFrequency: 19_000, highFrequency: 20_000, lowAmplitude: 0.10, highAmplitude: 0.10)
            ),
            (
                "deterministic_noise_bursts_mono.wav",
                "Attack/release, envelope, gate, transient, diffusion, and tail behavior over repeated dynamic bursts.",
                makeNoiseBursts()
            ),
            (
                "guitar_like_dynamic_plucks_mono.wav",
                "Musically structured guitar-range audition probe with multiple pitches and input levels; not a substitute for real guitar fixtures.",
                makePluckedFixture(frequencies: [82.4069, 110, 146.832, 195.998, 246.942, 329.628])
            ),
            (
                "bass_like_dynamic_plucks_mono.wav",
                "Musically structured bass-range audition probe with multiple pitches and input levels; not a substitute for real bass fixtures.",
                makePluckedFixture(frequencies: [41.2034, 55, 73.4162, 97.9989, 123.471, 164.814])
            ),
            (
                "vocal_like_mono.wav",
                "Deterministic speech-like harmonic/noise envelope for production-chain regression; not a perceptual-quality reference.",
                makeVocalLikeFixture()
            ),
            (
                "stereo_in_phase.wav",
                "Unity-width, balance, channel equality, and mono-sum baseline.",
                makeStereoInPhase()
            ),
            (
                "stereo_left_only.wav",
                "Left-input transfer, crossfeed, channel mapping, and stereo-matrix identification.",
                makeStereoOneSided(leftOnly: true)
            ),
            (
                "stereo_right_only.wav",
                "Right-input transfer, crossfeed, channel mapping, and stereo-matrix identification.",
                makeStereoOneSided(leftOnly: false)
            ),
            (
                "stereo_anti_phase.wav",
                "Side-only/mono-cancellation and phase-sensitive processor behavior check.",
                makeStereoAntiPhase()
            ),
            (
                "stereo_one_sample_offset.wav",
                "Interchannel latency, phase rotation, width, and mono-compatibility sensitivity check.",
                makeStereoOneSampleOffset()
            ),
            (
                "stereo_mid_low_side_high.wav",
                "Frequency-dependent stereo processing check with mono low frequencies and anti-phase high frequencies.",
                makeStereoMidLowSideHigh()
            ),
        ]

        var records: [MeasurementFixtureRecord] = []
        for (fileName, purpose, buffer) in signals {
            let url = directory.appendingPathComponent(fileName)
            try WAVFile.writePCM24(buffer, url: url)
            records.append(
                MeasurementFixtureRecord(
                    fileName: fileName,
                    sha256: try fileSHA256(url),
                    purpose: purpose,
                    sampleRate: Int(buffer.sampleRate),
                    channelCount: buffer.channelCount,
                    frameCount: buffer.frameCount,
                    durationSeconds: Double(buffer.frameCount) / buffer.sampleRate,
                    encoding: "PCM signed 24-bit WAV",
                    deterministic: true
                )
            )
        }

        let manifest = LogicMeasurementSuiteManifest(
            schemaVersion: "1.0",
            suiteVersion: "logic-native-measurement-suite-v1",
            product: "TrackSmith",
            generatedBy: "TestSignalGenerator",
            fixtureDate: "2026-07-16",
            sampleRate: Int(sampleRate),
            epistemicBoundary: [
                "These fixtures make transfer measurements reproducible; they do not by themselves establish musical suitability.",
                "A rendered result is attributable only when the exact Logic version/build, channel format, plug-in identity, preset, every parameter, routing, gain stage, sample rate, buffer mode, latency mode, render path, input hash, and output hash are recorded.",
                "Time-varying, stochastic, adaptive, look-ahead, oversampled, analog-modeled, and signal-dependent processors require repeated trials and cannot be reduced to one static response.",
                "Real legally usable vocals, drums, bass, guitar, keys/synth, and mixes plus controlled listening tests remain required for production conclusions.",
            ],
            fixtures: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        print("Wrote Logic-native empirical measurement suite:")
        print(directory.standardizedFileURL.path)
        print("fixtures=\(records.count) sample_rate=\(Int(sampleRate)) manifest=manifest.json")
    }

    private static let sampleRate = 48_000.0

    private static func makeSilence() -> AudioBuffer {
        AudioBuffer(channels: [Array(repeating: 0, count: Int(sampleRate * 4))], sampleRate: sampleRate)
    }

    private static func makeSingleImpulse() -> AudioBuffer {
        var samples = Array(repeating: Float.zero, count: Int(sampleRate * 6))
        samples[Int(sampleRate)] = dbAmplitude(-12)
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeImpulseLevelLadder() -> AudioBuffer {
        var samples = Array(repeating: Float.zero, count: Int(sampleRate * 10))
        let levels: [Double] = [-48, -36, -24, -18, -12, -6, -1]
        for (index, level) in levels.enumerated() {
            samples[Int(sampleRate * Double(index + 1))] = dbAmplitude(level)
        }
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeLogSweep() -> AudioBuffer {
        let duration = 12.0
        let frameCount = Int(sampleRate * duration)
        let low = 20.0
        let high = 20_000.0
        let logRatio = log(high / low)
        var samples = Array(repeating: Float.zero, count: frameCount)
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let phase = 2 * Double.pi * low * duration / logRatio
                * (exp(time * logRatio / duration) - 1)
            samples[frame] = dbAmplitude(-12) * Float(sin(phase))
        }
        applyFade(to: &samples, durationSeconds: 0.05)
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeAmplitudeLadder() -> AudioBuffer {
        let levels: [Double] = [-60, -48, -36, -30, -24, -18, -12, -6, -3, -1]
        let segmentDuration = 0.8
        let frameCount = Int(sampleRate * segmentDuration * Double(levels.count))
        var samples = Array(repeating: Float.zero, count: frameCount)
        for (segment, level) in levels.enumerated() {
            let start = Int(Double(segment) * segmentDuration * sampleRate)
            let end = Int(Double(segment + 1) * segmentDuration * sampleRate)
            for frame in start..<end {
                let localTime = Double(frame - start) / sampleRate
                let envelope = edgeEnvelope(
                    localTime: localTime,
                    duration: segmentDuration,
                    edge: 0.02
                )
                samples[frame] = dbAmplitude(level) * Float(envelope * sin(2 * Double.pi * 1_000 * localTime))
            }
        }
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeMultitone() -> AudioBuffer {
        let frequencies = [31.5, 63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
        let frameCount = Int(sampleRate * 8)
        var random = LCG(state: 0x7472_6163_6b73_6d69)
        let phases = frequencies.map { _ in random.nextUnit() * 2 * Double.pi }
        var samples = Array(repeating: Float.zero, count: frameCount)
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            var value = 0.0
            for (frequency, phase) in zip(frequencies, phases) {
                value += sin(2 * Double.pi * frequency * time + phase)
            }
            samples[frame] = Float(value / Double(frequencies.count))
        }
        applyFade(to: &samples, durationSeconds: 0.05)
        return AudioBuffer(channels: [normalizePeak(samples, target: dbAmplitude(-9))], sampleRate: sampleRate)
    }

    private static func makeTwoTone(
        lowFrequency: Double,
        highFrequency: Double,
        lowAmplitude: Float,
        highAmplitude: Float
    ) -> AudioBuffer {
        let duration = 8.0
        let frameCount = Int(sampleRate * duration)
        var samples = Array(repeating: Float.zero, count: frameCount)
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            samples[frame] = lowAmplitude * Float(sin(2 * Double.pi * lowFrequency * time))
                + highAmplitude * Float(sin(2 * Double.pi * highFrequency * time))
        }
        applyFade(to: &samples, durationSeconds: 0.05)
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeNoiseBursts() -> AudioBuffer {
        let duration = 10.0
        let frameCount = Int(sampleRate * duration)
        var samples = Array(repeating: Float.zero, count: frameCount)
        var random = LCG(state: 0x6e6f_6973_655f_7631)
        let levels: [Float] = [0.04, 0.08, 0.16, 0.28, 0.45, 0.16, 0.32, 0.08]
        for (burst, level) in levels.enumerated() {
            let start = Int(sampleRate * (Double(burst) + 1))
            let length = Int(sampleRate * 0.35)
            for offset in 0..<length where start + offset < samples.count {
                let time = Double(offset) / sampleRate
                let envelope = (1 - exp(-time / 0.0015)) * exp(-time / 0.075)
                let noise = random.nextUnit() * 2 - 1
                let body = sin(2 * Double.pi * 110 * time) * exp(-time / 0.16)
                samples[start + offset] = level * Float(envelope * noise + 0.45 * body)
            }
        }
        return AudioBuffer(channels: [normalizePeak(samples, target: dbAmplitude(-3))], sampleRate: sampleRate)
    }

    private static func makePluckedFixture(frequencies: [Double]) -> AudioBuffer {
        let segmentDuration = 1.25
        let frameCount = Int(sampleRate * segmentDuration * Double(frequencies.count + 1))
        var samples = Array(repeating: Float.zero, count: frameCount)
        let levels: [Double] = [-24, -18, -12, -9, -6, -3]
        for (note, frequency) in frequencies.enumerated() {
            let start = Int(Double(note) * segmentDuration * sampleRate)
            for offset in 0..<Int(sampleRate) {
                let time = Double(offset) / sampleRate
                var value = 0.0
                for harmonic in 1...10 {
                    let harmonicFrequency = frequency * Double(harmonic)
                    if harmonicFrequency >= sampleRate / 2 { break }
                    value += sin(2 * Double.pi * harmonicFrequency * time)
                        / pow(Double(harmonic), 1.18)
                }
                let pick = exp(-time / 0.006) * sin(2 * Double.pi * 3_400 * time)
                let envelope = (1 - exp(-time / 0.001)) * exp(-time / 0.42)
                samples[start + offset] += dbAmplitude(levels[note]) * Float((value * envelope + 0.12 * pick) / 2.2)
            }
        }
        return AudioBuffer(channels: [normalizePeak(samples, target: dbAmplitude(-3))], sampleRate: sampleRate)
    }

    private static func makeStereoBase() -> [Float] {
        makeMultitone().channels[0]
    }

    private static func makeStereoInPhase() -> AudioBuffer {
        let left = makeStereoBase()
        return AudioBuffer(channels: [left, left], sampleRate: sampleRate)
    }

    private static func makeStereoOneSided(leftOnly: Bool) -> AudioBuffer {
        let signal = makeStereoBase()
        let silence = Array(repeating: Float.zero, count: signal.count)
        return AudioBuffer(
            channels: leftOnly ? [signal, silence] : [silence, signal],
            sampleRate: sampleRate
        )
    }

    private static func makeStereoAntiPhase() -> AudioBuffer {
        let left = makeStereoBase()
        return AudioBuffer(channels: [left, left.map { -$0 }], sampleRate: sampleRate)
    }

    private static func makeStereoOneSampleOffset() -> AudioBuffer {
        let left = makeStereoBase()
        var right = Array(repeating: Float.zero, count: left.count)
        if left.count > 1 {
            right.replaceSubrange(1..<left.count, with: left.dropLast())
        }
        return AudioBuffer(channels: [left, right], sampleRate: sampleRate)
    }

    private static func makeStereoMidLowSideHigh() -> AudioBuffer {
        let frameCount = Int(sampleRate * 8)
        var left = Array(repeating: Float.zero, count: frameCount)
        var right = Array(repeating: Float.zero, count: frameCount)
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let low = 0.18 * sin(2 * Double.pi * 100 * time)
            let high = 0.08 * sin(2 * Double.pi * 5_000 * time)
            left[frame] = Float(low + high)
            right[frame] = Float(low - high)
        }
        applyFade(to: &left, durationSeconds: 0.05)
        applyFade(to: &right, durationSeconds: 0.05)
        return AudioBuffer(channels: [left, right], sampleRate: sampleRate)
    }

    private static func makeVocalLikeFixture() -> AudioBuffer {
        let duration = 8.0
        let frames = Int(sampleRate * duration)
        var samples = Array(repeating: Float.zero, count: frames)
        var random = LCG(state: 0x5eed_f00d)
        for frame in 0..<frames {
            let time = Double(frame) / sampleRate
            let phrasePosition = time.truncatingRemainder(dividingBy: 2)
            let active = phrasePosition < 1.55
            guard active else { continue }
            let edge = min(min(phrasePosition / 0.06, (1.55 - phrasePosition) / 0.12), 1)
            let phraseGain = max(edge, 0) * (0.62 + 0.18 * sin(2 * .pi * 0.31 * time))
            let fundamental = 145 + 5 * sin(2 * .pi * 5.1 * time) + 12 * sin(2 * .pi * 0.23 * time)
            var voice = 0.24 * sin(2 * .pi * fundamental * time)
            voice += 0.12 * sin(2 * .pi * fundamental * 2 * time)
            voice += 0.06 * sin(2 * .pi * fundamental * 3 * time)
            voice += 0.10 * sin(2 * .pi * 320 * time)
            voice += 0.025 * sin(2 * .pi * 3_200 * time)
            let sibilantWindow = phrasePosition > 0.62 && phrasePosition < 0.77
            let noise = (random.nextUnit() * 2 - 1) * (sibilantWindow ? 0.045 : 0.004)
            samples[frame] = Float((voice + noise) * phraseGain)
        }
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func applyFade(to samples: inout [Float], durationSeconds: Double) {
        let fadeFrames = min(Int(sampleRate * durationSeconds), samples.count / 2)
        guard fadeFrames > 0 else { return }
        for frame in 0..<fadeFrames {
            let gain = Float(Double(frame) / Double(fadeFrames))
            samples[frame] *= gain
            samples[samples.count - frame - 1] *= gain
        }
    }

    private static func edgeEnvelope(localTime: Double, duration: Double, edge: Double) -> Double {
        max(0, min(1, min(localTime / edge, (duration - localTime) / edge)))
    }

    private static func normalizePeak(_ samples: [Float], target: Float) -> [Float] {
        let peak = samples.reduce(Float.zero) { max($0, abs($1)) }
        guard peak > 0 else { return samples }
        let gain = target / peak
        return samples.map { $0 * gain }
    }

    private static func dbAmplitude(_ decibels: Double) -> Float {
        Float(pow(10, decibels / 20))
    }

    private static func fileSHA256(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct LogicMeasurementSuiteManifest: Codable {
    var schemaVersion: String
    var suiteVersion: String
    var product: String
    var generatedBy: String
    var fixtureDate: String
    var sampleRate: Int
    var epistemicBoundary: [String]
    var fixtures: [MeasurementFixtureRecord]
}

private struct MeasurementFixtureRecord: Codable {
    var fileName: String
    var sha256: String
    var purpose: String
    var sampleRate: Int
    var channelCount: Int
    var frameCount: Int
    var durationSeconds: Double
    var encoding: String
    var deterministic: Bool
}

private enum GeneratorError: Error, CustomStringConvertible {
    case usage(String)

    var description: String {
        switch self {
        case let .usage(message): message
        }
    }
}

private struct LCG {
    var state: UInt64
    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}
