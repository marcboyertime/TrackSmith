import CryptoKit
import DSPCore
import Foundation

@main
@MainActor
enum TestSignalGenerator {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.first == "--logic-measurement-suite" {
                guard arguments.count == 2 || arguments.count == 4 else {
                    throw GeneratorError.usage(
                        "usage: TestSignalGenerator --logic-measurement-suite OUTPUT_DIRECTORY "
                            + "[--sample-rate HZ]"
                    )
                }
                try configureSampleRate(arguments)
                try writeLogicMeasurementSuite(to: URL(fileURLWithPath: arguments[1], isDirectory: true))
                return
            }
            if arguments.first == "--logic-compressor-ballistics" {
                guard arguments.count == 2 || arguments.count == 4 else {
                    throw GeneratorError.usage(
                        "usage: TestSignalGenerator --logic-compressor-ballistics "
                            + "OUTPUT_DIRECTORY [--sample-rate HZ]"
                    )
                }
                try configureSampleRate(arguments)
                try writeLogicCompressorBallistics(
                    to: URL(fileURLWithPath: arguments[1], isDirectory: true)
                )
                return
            }
            if arguments.first == "--logic-deesser-event-suite" {
                guard arguments.count == 2 || arguments.count == 4 else {
                    throw GeneratorError.usage(
                        "usage: TestSignalGenerator --logic-deesser-event-suite "
                            + "OUTPUT_DIRECTORY [--sample-rate HZ]"
                    )
                }
                try configureSampleRate(arguments)
                try writeLogicDeEsserEventSuite(
                    to: URL(fileURLWithPath: arguments[1], isDirectory: true)
                )
                return
            }
            if arguments.first == "--logic-space-designer-ir-suite" {
                guard arguments.count == 2 || arguments.count == 4 else {
                    throw GeneratorError.usage(
                        "usage: TestSignalGenerator --logic-space-designer-ir-suite "
                            + "OUTPUT_DIRECTORY [--sample-rate HZ]"
                    )
                }
                try configureSampleRate(arguments)
                try writeLogicSpaceDesignerIRSuite(
                    to: URL(fileURLWithPath: arguments[1], isDirectory: true)
                )
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

    private static func configureSampleRate(_ arguments: [String]) throws {
        guard arguments.count == 4 else { return }
        guard arguments[2] == "--sample-rate",
              let requestedRate = Double(arguments[3]),
              requestedRate.isFinite,
              requestedRate.rounded() == requestedRate,
              (44_100 ... 192_000).contains(requestedRate)
        else {
            throw GeneratorError.usage(
                "--sample-rate must be an integer from 44100 through 192000 Hz"
            )
        }
        sampleRate = requestedRate
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
                "dc_offset_probe_mono.wav",
                "DC-removal and very-low-frequency preservation probe with separate silence, DC-only, DC-plus-30-Hz, and zero-mean-30-Hz sections.",
                makeDCOffsetProbe()
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

    private static func writeLogicCompressorBallistics(to directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileName = "compressor_ballistics_1khz_mono.wav"
        let url = directory.appendingPathComponent(fileName)
        let buffer = makeCompressorBallistics()
        try WAVFile.writePCM24(buffer, url: url)
        let stereoLinkFileName = "compressor_ballistics_1khz_stereo_link_probe.wav"
        let stereoLinkURL = directory.appendingPathComponent(stereoLinkFileName)
        let stereoLinkBuffer = makeCompressorStereoLinkProbe()
        try WAVFile.writePCM24(stereoLinkBuffer, url: stereoLinkURL)
        let levels = [-30.0, -6.0, -30.0, -6.0, -30.0, -6.0, -30.0]
        let manifest = CompressorBallisticsManifest(
            schemaVersion: "1.0",
            fixtureVersion: "logic-compressor-ballistics-v2",
            product: "TrackSmith",
            generatedBy: "TestSignalGenerator",
            fileName: fileName,
            sha256: try fileSHA256(url),
            stereoLinkProbeFileName: stereoLinkFileName,
            stereoLinkProbeSHA256: try fileSHA256(stereoLinkURL),
            sampleRate: Int(sampleRate),
            channelCount: buffer.channelCount,
            stereoLinkProbeChannelCount: stereoLinkBuffer.channelCount,
            frameCount: buffer.frameCount,
            durationSeconds: Double(buffer.frameCount) / buffer.sampleRate,
            encoding: "PCM signed 24-bit WAV",
            toneFrequencyHz: 1_000,
            segmentSeconds: 1,
            segmentPeakLevelsDBFS: levels,
            stereoLinkProbeChannelPeakLevelsDBFS: [
                levels,
                Array(repeating: -30.0, count: levels.count),
            ],
            transitionKinds: [
                "attack", "release", "attack", "release", "attack", "release",
            ],
            deterministic: true,
            epistemicBoundary: [
                "The fixture exposes level-step response under an exact recorded compressor state; it does not identify a private detector or gain-smoothing topology.",
                "Attack and release observations require the exact Logic version, processor mode, detector, threshold, ratio, knee, gain controls, routing, sample rate, render path, hashes, and repeated output.",
                "The stereo link probe holds the right channel at -30 dBFS while the left channel steps between -30 and -6 dBFS; correlated right-channel gain movement is evidence only for the exact tested stereo state.",
                "Objective settling behavior is not proof of musical usefulness or a preferred compressor sound.",
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        print("Wrote Logic Compressor ballistics fixture:")
        print(directory.standardizedFileURL.path)
        print(
            "fixture=\(fileName) sample_rate=\(Int(sampleRate)) "
                + "frames=\(buffer.frameCount) stereo_link_fixture=\(stereoLinkFileName) "
                + "manifest=manifest.json"
        )
    }

    private static func writeLogicDeEsserEventSuite(to directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fixtures: [(String, String, AudioBuffer)] = [
            (
                "deesser_level_mode_probe_mono.wav",
                "Same-ratio quiet/loud pairs plus bounded high-band levels for Relative/Absolute and Split/Wide comparisons.",
                makeDeEsserLevelModeProbe()
            ),
            (
                "deesser_event_probe_mono.wav",
                "Short 7 kHz events and static 7 kHz intervals over a controlled 500 Hz base for objective event/static comparisons.",
                makeDeEsserEventProbe(stereo: false)
            ),
            (
                "deesser_event_probe_stereo.wav",
                "Left-channel 7 kHz events over a two-channel 500 Hz base for bounded stereo-link and collateral-gain observations.",
                makeDeEsserEventProbe(stereo: true)
            ),
        ]
        var records: [MeasurementFixtureRecord] = []
        for (fileName, purpose, buffer) in fixtures {
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
        let manifest = DeEsserEventSuiteManifest(
            schemaVersion: "1.0",
            fixtureVersion: "logic-deesser-event-suite-v1",
            product: "TrackSmith",
            generatedBy: "TestSignalGenerator",
            sampleRate: Int(sampleRate),
            baseFrequencyHz: 500,
            detectorFrequencyHz: 7_000,
            segmentSeconds: 1,
            eventStartSecondsWithinSegment: 0.40,
            eventEndSecondsWithinSegment: 0.52,
            fixtures: records,
            epistemicBoundary: [
                "These synthetic tones expose gain behavior for exact recorded DeEsser 2 states; they are not speech, phonemes, or a listening-quality reference.",
                "Relative/Absolute, Split/Wide, filter, threshold, maximum reduction, channel format, sample rate, routing, render path, input hash, and output hash must be retained with every result.",
                "A detected 7 kHz change does not establish consonant intelligibility, breath preservation, air preservation, lisp avoidance, or musical usefulness.",
                "The stereo probe supports only channel-gain observations for the exact tested state; it does not reveal a private detector or linking topology.",
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        print("Wrote Logic DeEsser 2 event suite:")
        print(directory.standardizedFileURL.path)
        print(
            "fixtures=\(records.count) sample_rate=\(Int(sampleRate)) "
                + "manifest=manifest.json"
        )
    }

    private static func writeLogicSpaceDesignerIRSuite(to directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileName = "tracksmith_space_designer_sparse_diffuse_ir_mono.wav"
        let url = directory.appendingPathComponent(fileName)
        let buffer = makeSpaceDesignerCustomIR()
        try WAVFile.writePCM24(buffer, url: url)
        let tapTimesSeconds = [0.0, 0.010, 0.023, 0.047, 0.091, 0.143, 0.211]
        let manifest = SpaceDesignerIRSuiteManifest(
            schemaVersion: "1.0",
            fixtureVersion: "tracksmith-space-designer-ir-suite-v1",
            product: "TrackSmith",
            generatedBy: "TestSignalGenerator",
            fixtureDate: "2026-07-28",
            sampleRate: Int(sampleRate),
            ir: MeasurementFixtureRecord(
                fileName: fileName,
                sha256: try fileSHA256(url),
                purpose: "Identity-bearing mono convolution IR with sparse early taps and a bounded deterministic diffuse tail.",
                sampleRate: Int(buffer.sampleRate),
                channelCount: buffer.channelCount,
                frameCount: buffer.frameCount,
                durationSeconds: Double(buffer.frameCount) / buffer.sampleRate,
                encoding: "PCM signed 24-bit WAV",
                deterministic: true
            ),
            impulseTapFrames: tapTimesSeconds.map { Int(($0 * sampleRate).rounded()) },
            impulseTapAmplitudes: [0.5, 0.32, -0.24, 0.18, -0.12, 0.09, -0.07],
            diffuseTailStartFrame: Int((0.25 * sampleRate).rounded()),
            diffuseTailEndFrame: Int((1.5 * sampleRate).rounded()),
            diffuseTailMaximumAmplitude: 0.015,
            diffuseTailSeed: 0x5350414345444553,
            epistemicBoundary: [
                "This generated WAV identifies the exact IR asset supplied to Space Designer; it does not identify Logic's convolution implementation.",
                "Any accepted render must retain the Logic version/build, loaded IR filename and hash, channel format, quality, IR sample-rate/length state, envelope/filter/EQ state, latency compensation, routing, source/output hashes, and reload evidence.",
                "A convolution match or difference is evidence for the exact recorded state only and is not proof of realism, depth, preference, or musical usefulness.",
                "The diffuse tail is deterministic generator output, not a recording of a real acoustic space.",
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        print("Wrote Logic Space Designer custom IR suite:")
        print(directory.standardizedFileURL.path)
        print(
            "fixture=\(fileName) sample_rate=\(Int(sampleRate)) "
                + "frames=\(buffer.frameCount) manifest=manifest.json"
        )
    }

    private static var sampleRate = 48_000.0

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

    private static func makeSpaceDesignerCustomIR() -> AudioBuffer {
        let frameCount = Int(sampleRate * 2)
        var samples = Array(repeating: Float.zero, count: frameCount)
        let taps: [(Double, Float)] = [
            (0.0, 0.5),
            (0.010, 0.32),
            (0.023, -0.24),
            (0.047, 0.18),
            (0.091, -0.12),
            (0.143, 0.09),
            (0.211, -0.07),
        ]
        for (timeSeconds, amplitude) in taps {
            samples[Int((timeSeconds * sampleRate).rounded())] = amplitude
        }

        let tailStart = Int((0.25 * sampleRate).rounded())
        let tailEnd = Int((1.5 * sampleRate).rounded())
        var generator = LCG(state: 0x5350414345444553)
        for frame in tailStart..<tailEnd {
            let progress = Double(frame - tailStart) / Double(max(1, tailEnd - tailStart))
            let envelope = exp(-5 * progress)
            let noise = generator.nextUnit() * 2 - 1
            samples[frame] += Float(0.015 * envelope * noise)
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

    private static func makeDCOffsetProbe() -> AudioBuffer {
        let frameCount = Int(sampleRate * 8)
        var samples = Array(repeating: Float.zero, count: frameCount)
        for frame in samples.indices {
            let time = Double(frame) / sampleRate
            switch time {
            case 1..<3:
                samples[frame] = 0.125
            case 3..<5:
                samples[frame] = Float(0.125 + 0.2 * sin(2 * Double.pi * 30 * time))
            case 5..<7:
                samples[frame] = Float(0.2 * sin(2 * Double.pi * 30 * time))
            default:
                samples[frame] = 0
            }
        }
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeCompressorBallistics() -> AudioBuffer {
        let levels = [-30.0, -6.0, -30.0, -6.0, -30.0, -6.0, -30.0]
        let framesPerSegment = Int(sampleRate)
        var samples = Array(
            repeating: Float.zero,
            count: framesPerSegment * levels.count
        )
        for frame in samples.indices {
            let segment = min(frame / framesPerSegment, levels.count - 1)
            let time = Double(frame) / sampleRate
            samples[frame] = dbAmplitude(levels[segment])
                * Float(sin(2 * Double.pi * 1_000 * time))
        }
        applyFade(to: &samples, durationSeconds: 0.01)
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeCompressorStereoLinkProbe() -> AudioBuffer {
        let driver = makeCompressorBallistics().channels[0]
        var opposite = Array(repeating: Float.zero, count: driver.count)
        for frame in opposite.indices {
            let time = Double(frame) / sampleRate
            opposite[frame] = dbAmplitude(-30)
                * Float(sin(2 * Double.pi * 1_000 * time))
        }
        applyFade(to: &opposite, durationSeconds: 0.01)
        return AudioBuffer(channels: [driver, opposite], sampleRate: sampleRate)
    }

    private static func makeDeEsserLevelModeProbe() -> AudioBuffer {
        let baseLevelsDBFS = [-30.0, -30.0, -18.0, -18.0, -18.0, -18.0]
        let highLevelsDBFS: [Double?] = [nil, -18.0, nil, -6.0, -24.0, -6.0]
        let framesPerSegment = Int(sampleRate)
        var samples = Array(
            repeating: Float.zero,
            count: framesPerSegment * baseLevelsDBFS.count
        )
        for frame in samples.indices {
            let segment = min(frame / framesPerSegment, baseLevelsDBFS.count - 1)
            let time = Double(frame) / sampleRate
            let base = dbAmplitude(baseLevelsDBFS[segment])
                * Float(sin(2 * Double.pi * 500 * time))
            let high = highLevelsDBFS[segment].map {
                dbAmplitude($0) * Float(sin(2 * Double.pi * 7_000 * time))
            } ?? 0
            samples[frame] = base + high
        }
        applyFade(to: &samples, durationSeconds: 0.01)
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private static func makeDeEsserEventProbe(stereo: Bool) -> AudioBuffer {
        let segmentKinds = [
            "base_only",
            "event_minus_6",
            "static_minus_24",
            "event_minus_12",
            "static_minus_12",
            "event_minus_6_repeat",
        ]
        let framesPerSegment = Int(sampleRate)
        let frameCount = framesPerSegment * segmentKinds.count
        var left = Array(repeating: Float.zero, count: frameCount)
        var right = Array(repeating: Float.zero, count: frameCount)
        for frame in 0..<frameCount {
            let segment = min(frame / framesPerSegment, segmentKinds.count - 1)
            let localTime = Double(frame % framesPerSegment) / sampleRate
            let time = Double(frame) / sampleRate
            let base = dbAmplitude(-18)
                * Float(sin(2 * Double.pi * 500 * time))
            let highLevel: Double?
            switch segmentKinds[segment] {
            case "event_minus_6", "event_minus_6_repeat":
                highLevel = (0.40 ..< 0.52).contains(localTime) ? -6 : nil
            case "event_minus_12":
                highLevel = (0.40 ..< 0.52).contains(localTime) ? -12 : nil
            case "static_minus_24":
                highLevel = -24
            case "static_minus_12":
                highLevel = -12
            default:
                highLevel = nil
            }
            let high = highLevel.map {
                dbAmplitude($0) * Float(sin(2 * Double.pi * 7_000 * time))
            } ?? 0
            left[frame] = base + high
            right[frame] = base
        }
        applyFade(to: &left, durationSeconds: 0.01)
        if stereo {
            applyFade(to: &right, durationSeconds: 0.01)
            return AudioBuffer(channels: [left, right], sampleRate: sampleRate)
        }
        return AudioBuffer(channels: [left], sampleRate: sampleRate)
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

private struct CompressorBallisticsManifest: Codable {
    var schemaVersion: String
    var fixtureVersion: String
    var product: String
    var generatedBy: String
    var fileName: String
    var sha256: String
    var stereoLinkProbeFileName: String
    var stereoLinkProbeSHA256: String
    var sampleRate: Int
    var channelCount: Int
    var stereoLinkProbeChannelCount: Int
    var frameCount: Int
    var durationSeconds: Double
    var encoding: String
    var toneFrequencyHz: Int
    var segmentSeconds: Int
    var segmentPeakLevelsDBFS: [Double]
    var stereoLinkProbeChannelPeakLevelsDBFS: [[Double]]
    var transitionKinds: [String]
    var deterministic: Bool
    var epistemicBoundary: [String]
}

private struct DeEsserEventSuiteManifest: Codable {
    var schemaVersion: String
    var fixtureVersion: String
    var product: String
    var generatedBy: String
    var sampleRate: Int
    var baseFrequencyHz: Int
    var detectorFrequencyHz: Int
    var segmentSeconds: Int
    var eventStartSecondsWithinSegment: Double
    var eventEndSecondsWithinSegment: Double
    var fixtures: [MeasurementFixtureRecord]
    var epistemicBoundary: [String]
}

private struct SpaceDesignerIRSuiteManifest: Codable {
    var schemaVersion: String
    var fixtureVersion: String
    var product: String
    var generatedBy: String
    var fixtureDate: String
    var sampleRate: Int
    var ir: MeasurementFixtureRecord
    var impulseTapFrames: [Int]
    var impulseTapAmplitudes: [Double]
    var diffuseTailStartFrame: Int
    var diffuseTailEndFrame: Int
    var diffuseTailMaximumAmplitude: Double
    var diffuseTailSeed: UInt64
    var epistemicBoundary: [String]
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
