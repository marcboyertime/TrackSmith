import CAtomics
import DSPCore
import Foundation

/// A bounded single-producer capture buffer. The render-side write path is lock-free and allocation-free.
public final class CaptureRingBuffer: @unchecked Sendable {
    public let capacityFrames: Int
    public let channelCount: Int
    public let sampleRate: Double
    private let storage: UnsafeMutablePointer<Float>
    private let totalFramesWritten: OpaquePointer

    public init(capacityFrames: Int, channelCount: Int, sampleRate: Double) {
        precondition(capacityFrames > 0 && (channelCount == 1 || channelCount == 2))
        self.capacityFrames = capacityFrames; self.channelCount = channelCount; self.sampleRate = sampleRate
        guard let counter = laa_atomic_u64_create(0) else { fatalError("Unable to allocate capture counter") }
        totalFramesWritten = counter
        storage = .allocate(capacity: capacityFrames * channelCount)
        storage.initialize(repeating: 0, count: capacityFrames * channelCount)
    }

    deinit { laa_atomic_u64_destroy(totalFramesWritten); storage.deinitialize(count: capacityFrames * channelCount); storage.deallocate() }

    /// Call from exactly one producer (the audio render callback).
    public func write(_ buffer: AudioBuffer) {
        precondition(buffer.channelCount == channelCount && buffer.sampleRate == sampleRate)
        let start = laa_atomic_u64_load_relaxed(totalFramesWritten)
        for frame in 0..<buffer.frameCount {
            let destinationFrame = Int((start + UInt64(frame)) % UInt64(capacityFrames))
            for channel in 0..<channelCount { storage[destinationFrame * channelCount + channel] = buffer.channels[channel][frame] }
        }
        laa_atomic_u64_store_release(totalFramesWritten, start + UInt64(buffer.frameCount))
    }

    /// Raw-pointer variant for an Audio Unit render callback. Supports noninterleaved mono/stereo Float32.
    public func write(left: UnsafePointer<Float>, right: UnsafePointer<Float>? = nil, frameCount: Int) {
        precondition(frameCount >= 0 && (channelCount == 1 || right != nil))
        let start = laa_atomic_u64_load_relaxed(totalFramesWritten)
        for frame in 0..<frameCount {
            let destinationFrame = Int((start + UInt64(frame)) % UInt64(capacityFrames))
            storage[destinationFrame * channelCount] = left[frame]
            if channelCount == 2, let right { storage[destinationFrame * channelCount + 1] = right[frame] }
        }
        laa_atomic_u64_store_release(totalFramesWritten, start + UInt64(frameCount))
    }

    /// Call outside the render thread. Allocates an immutable snapshot for analysis.
    public func snapshot(maxFrames: Int? = nil) -> AudioBuffer {
        let end = laa_atomic_u64_load_acquire(totalFramesWritten)
        let available = min(Int(end), capacityFrames)
        let count = min(maxFrames ?? available, available)
        let start = end - UInt64(count)
        var channels = Array(repeating: Array(repeating: Float.zero, count: count), count: channelCount)
        for frame in 0..<count {
            let sourceFrame = Int((start + UInt64(frame)) % UInt64(capacityFrames))
            for channel in 0..<channelCount { channels[channel][frame] = storage[sourceFrame * channelCount + channel] }
        }
        return AudioBuffer(channels: channels, sampleRate: sampleRate)
    }
}
