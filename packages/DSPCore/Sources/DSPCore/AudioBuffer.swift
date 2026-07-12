import Foundation

public struct AudioBuffer: Equatable, Sendable {
    public var channels: [[Float]]
    public var sampleRate: Double

    public init(channels: [[Float]], sampleRate: Double) {
        precondition(!channels.isEmpty && channels.count <= 2, "Initial DSP core supports mono or stereo")
        precondition(sampleRate.isFinite && sampleRate > 0)
        let frameCount = channels[0].count
        precondition(channels.allSatisfy { $0.count == frameCount })
        self.channels = channels
        self.sampleRate = sampleRate
    }

    public var channelCount: Int { channels.count }
    public var frameCount: Int { channels.first?.count ?? 0 }

    public static func silence(channelCount: Int, frameCount: Int, sampleRate: Double) -> AudioBuffer {
        AudioBuffer(channels: Array(repeating: Array(repeating: 0, count: frameCount), count: channelCount), sampleRate: sampleRate)
    }
}
