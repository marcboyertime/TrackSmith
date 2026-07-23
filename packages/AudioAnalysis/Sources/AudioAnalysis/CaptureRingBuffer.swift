import CAtomics
import DSPCore
import Foundation

public enum CaptureRingBufferError: Error, Equatable, Sendable {
    case allocationFailed
    case atomicsNotLockFree
    case invalidConfiguration
}

/// A bounded single-producer capture buffer. The render-side write path is lock-free and allocation-free.
public final class CaptureRingBuffer: @unchecked Sendable {
    public let capacityFrames: Int
    public let channelCount: Int
    public let sampleRate: Double
    public let maximumWriteFrames: Int
    private let storage: OpaquePointer
    private let storageFrameCount: Int
    private let overwriteGuardFrames: Int
    private let totalFramesWritten: OpaquePointer

    public init(
        capacityFrames: Int,
        channelCount: Int,
        sampleRate: Double,
        maximumWriteFrames: Int = 8_192
    ) throws {
        guard capacityFrames > 0,
              channelCount == 1 || channelCount == 2,
              sampleRate.isFinite,
              sampleRate > 0,
              maximumWriteFrames > 0,
              capacityFrames <= Int.max - maximumWriteFrames,
              capacityFrames + maximumWriteFrames <= Int.max / channelCount else {
            throw CaptureRingBufferError.invalidConfiguration
        }
        self.capacityFrames = capacityFrames
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.maximumWriteFrames = maximumWriteFrames
        overwriteGuardFrames = maximumWriteFrames
        storageFrameCount = capacityFrames + overwriteGuardFrames
        guard let counter = laa_atomic_u64_create(0) else {
            throw CaptureRingBufferError.allocationFailed
        }
        totalFramesWritten = counter
        guard let samples = laa_atomic_f32_array_create(storageFrameCount * channelCount) else {
            laa_atomic_u64_destroy(counter)
            throw CaptureRingBufferError.allocationFailed
        }
        guard laa_atomic_u64_is_lock_free(counter) != 0,
              laa_atomic_f32_array_is_lock_free(samples) != 0 else {
            laa_atomic_f32_array_destroy(samples)
            laa_atomic_u64_destroy(counter)
            throw CaptureRingBufferError.atomicsNotLockFree
        }
        storage = samples
    }

    deinit {
        laa_atomic_f32_array_destroy(storage)
        laa_atomic_u64_destroy(totalFramesWritten)
    }

    /// Call from exactly one producer (the audio render callback).
    @discardableResult
    public func write(_ buffer: AudioBuffer) -> Bool {
        guard buffer.channelCount == channelCount,
              buffer.sampleRate == sampleRate,
              buffer.frameCount <= maximumWriteFrames else { return false }
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
        return true
    }

    /// Raw-pointer variant for an Audio Unit render callback. Supports noninterleaved mono/stereo Float32.
    @discardableResult
    public func write(left: UnsafePointer<Float>, right: UnsafePointer<Float>? = nil, frameCount: Int) -> Bool {
        guard frameCount >= 0,
              frameCount <= maximumWriteFrames,
              channelCount == 1 || right != nil else { return false }
        let start = laa_atomic_u64_load_relaxed(totalFramesWritten)
        for frame in 0..<frameCount {
            let destinationFrame = Int((start + UInt64(frame)) % UInt64(storageFrameCount))
            laa_atomic_f32_array_store_relaxed(storage, destinationFrame * channelCount, left[frame])
            if channelCount == 2, let right {
                laa_atomic_f32_array_store_relaxed(storage, destinationFrame * channelCount + 1, right[frame])
            }
        }
        laa_atomic_u64_store_release(totalFramesWritten, start + UInt64(frameCount))
        return true
    }

    /// Call outside the render thread. Allocates an immutable snapshot for analysis.
    public func snapshot(maxFrames: Int? = nil) -> AudioBuffer? {
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
        // Atomic payloads prevent a memory race, but they cannot make an overtaken
        // multi-frame copy chronologically coherent. Fail closed and let the caller
        // request a newer capture instead of presenting mixed-time audio as valid.
        return nil
    }
}
