import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema

/// Owns all mutable render state. Preparation and snapshot extraction happen off the audio thread;
/// `process` performs only bounded pointer arithmetic, atomics, and deterministic DSP.
final class RealtimeRenderKernel: @unchecked Sendable {
    static let captureDurationSeconds = 30.0

    private var graph: CompiledGraph?
    private var capture: CaptureRingBuffer?
    private(set) var sampleRate = 0.0
    private(set) var channelCount = 0

    func prepare(sampleRate: Double, channelCount: Int, processingPlan: ProcessingPlan?) throws {
        precondition(channelCount == 1 || channelCount == 2)
        if let processingPlan {
            let expectedFormat: ChannelFormat = channelCount == 1 ? .mono : .stereo
            guard processingPlan.scope.channelFormat == expectedFormat else {
                throw RealtimeKernelError.planChannelFormatMismatch
            }
        }
        let plan = processingPlan ?? ProcessingPlan(
                sourceSnapshotID: UUID(),
                scope: ProcessingScope(
                    kind: .pluginInput,
                    channelFormat: channelCount == 1 ? .mono : .stereo,
                    sourceType: .unknown
                ),
                goals: [],
                nodes: []
            )
        graph = try CompiledGraph(plan: plan, sampleRate: sampleRate, channelCount: channelCount)
        capture = CaptureRingBuffer(
            capacityFrames: max(1, Int((sampleRate * Self.captureDurationSeconds).rounded(.up))),
            channelCount: channelCount,
            sampleRate: sampleRate
        )
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    func reset() {
        graph?.reset()
    }

    /// Captures the dry plug-in input first, then processes the same host-owned buffers in place.
    /// Invalid layouts fail to dry audio and never emit an error from the render callback.
    @inline(__always)
    func process(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int,
        outputGain: Float
    ) -> RealtimeProcessStatus {
        guard frameCount >= 0 else { return .invalidFrameCount }
        guard (channelCount == 1 && right == nil) || (channelCount == 2 && right != nil) else {
            return .channelMismatch
        }

        let captureRight: UnsafePointer<Float>? = if let right { UnsafePointer(right) } else { nil }
        capture?.write(left: UnsafePointer(left), right: captureRight, frameCount: frameCount)
        let status = graph?.processRealtime(left: left, right: right, frameCount: frameCount) ?? .channelMismatch
        guard status == .processed else { return status }

        if outputGain != 1 {
            for frame in 0..<frameCount {
                left[frame] *= outputGain
                if let right { right[frame] *= outputGain }
            }
        }
        return .processed
    }

    /// Must be called outside the audio callback. The returned value owns its storage.
    func recentCapture(maxDurationSeconds: Double? = nil) -> AudioBuffer? {
        guard let capture else { return nil }
        let requestedFrames = maxDurationSeconds.map {
            max(0, min(capture.capacityFrames, Int(($0 * capture.sampleRate).rounded(.up))))
        }
        return capture.snapshot(maxFrames: requestedFrames)
    }
}

private enum RealtimeKernelError: Error {
    case planChannelFormatMismatch
}
