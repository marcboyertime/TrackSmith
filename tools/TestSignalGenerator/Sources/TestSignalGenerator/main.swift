import DSPCore
import Foundation

@main
enum TestSignalGenerator {
    static func main() {
        do {
            let path = CommandLine.arguments.dropFirst().first ?? "fixtures/generated/demo-vocal.wav"
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let buffer = makeVocalLikeFixture()
            try WAVFile.writePCM24(buffer, url: url)
            print("Wrote deterministic PCM24 fixture:")
            print(url.standardizedFileURL.path)
            print("duration=\(String(format: "%.2f", Double(buffer.frameCount) / buffer.sampleRate))s sample_rate=\(Int(buffer.sampleRate)) channels=\(buffer.channelCount)")
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(2)
        }
    }

    private static func makeVocalLikeFixture() -> AudioBuffer {
        let sampleRate = 48_000.0
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
}

private struct LCG {
    var state: UInt64
    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}
