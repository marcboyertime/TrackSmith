import CAtomics
import DSPCore
import Foundation

/// A bounded single-producer capture buffer. The render-side write path is lock-free and allocation-free.
public final class CaptureRingBuffer: @unchecked Sendable {
    public let capacityFrames: Int
    public let channelCount: Int
    public let sampleRate: Double
    private let storage: OpaquePointer
    private let storageFrameCount: Int
    private let overwriteGuardFrames: Int
    private let totalFramesWritten: OpaquePointer

    public init(capacityFrames: Int, channelCount: Int, sampleRate: Double) {
        precondition(capacityFrames > 0 && (channelCount == 1 || channelCount == 2))
        self.capacityFrames = capacityFrames; self.channelCount = channelCount; self.sampleRate = sampleRate
        overwriteGuardFrames = 8_192
        storageFrameCount = capacityFrames + overwriteGuardFrames
        guard let counter = laa_atomic_u64_create(0) else { fatalError("Unable to allocate capture counter") }
        totalFramesWritten = counter
        guard let samples = laa_atomic_f32_array_create(storageFrameCount * channelCount) else {
            laa_atomic_u64_destroy(counter)
            fatalError("Unable to allocate atomic capture storage")
        }
        storage = samples
    }

    deinit {
        laa_atomic_f32_array_destroy(storage)
        laa_atomic_u64_destroy(totalFramesWritten)
    }

    /// Call from exactly one producer (the audio render callback).
    public func write(_ buffer: AudioBuffer) {
        precondition(buffer.channelCount == channelCount && buffer.sampleRate == sampleRate)
        let start = laa_atomic_u64_load_relaxed(totalFramesWritten)
        for frame in 0..<buffer.frameCount {
            let destinationFrame = Int((start + UInt64(frame)) % UInt64(storageFrameCount))
            for channel in 0..<channelCount {
                laa_atomic_f32_array_store_relaxed(
                    storage,
                    destinationFrame * channelCount + channel,
                    buffer.channels[channel][frame]
                )
            }
        }
        laa_atomic_u64_store_release(totalFramesWritten, start + UInt64(buffer.frameCount))
    }

    /// Raw-pointer variant for an Audio Unit render callback. Supports noninterleaved mono/stereo Float32.
    public func write(left: UnsafePointer<Float>, right: UnsafePointer<Float>? = nil, frameCount: Int) {
        precondition(frameCount >= 0 && (channelCount == 1 || right != nil))
        let start = laa_atomic_u64_load_relaxed(totalFramesWritten)
        for frame in 0..<frameCount {
            let destinationFrame = Int((start + UInt64(frame)) % UInt64(storageFrameCount))
            laa_atomic_f32_array_store_relaxed(storage, destinationFrame * channelCount, left[frame])
            if channelCount == 2, let right {
                laa_atomic_f32_array_store_relaxed(storage, destinationFrame * channelCount + 1, right[frame])
            }
        }
        laa_atomic_u64_store_release(totalFramesWritten, start + UInt64(frameCount))
    }

    /// Call outside the render thread. Allocates an immutable snapshot for analysis.
    public func snapshot(maxFrames: Int? = nil) -> AudioBuffer {
        var channels = [[Float]]()
        for _ in 0..<3 {
            let end = laa_atomic_u64_load_acquire(totalFramesWritten)
            let available = min(Int(end), capacityFrames)
            let count = max(0, min(maxFrames ?? available, available))
            let start = end - UInt64(count)
            if channels.count != channelCount || channels.first?.count != count {
                channels = Array(repeating: Array(repeating: Float.zero, count: count), count: channelCount)
            }
            for frame in 0..<count {
                let sourceFrame = Int((start + UInt64(frame)) % UInt64(storageFrameCount))
                for channel in 0..<channelCount {
                    channels[channel][frame] = laa_atomic_f32_array_load_relaxed(
                        storage,
                        sourceFrame * channelCount + channel
                    )
                }
            }
            let endAfterCopy = laa_atomic_u64_load_acquire(totalFramesWritten)
            if endAfterCopy - end <= UInt64(overwriteGuardFrames) {
                return AudioBuffer(channels: channels, sampleRate: sampleRate)
            }
        }
        // Atomic payloads make this safe even if a severely delayed reader is overtaken.
        // A subsequent request will naturally use the newest published frame range.
        return AudioBuffer(channels: channels, sampleRate: sampleRate)
    }
}
