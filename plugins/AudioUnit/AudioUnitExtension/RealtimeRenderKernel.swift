import AudioAnalysis
import AudioToolbox
import CAtomics
import CoreAudio
import DSPCore
import Foundation
import PlanSchema

public enum RealtimeInfrastructureError: Error, Equatable, Sendable, CustomStringConvertible {
    public enum Component: String, Equatable, Sendable {
        case outputGainParameter
        case inputPeakMeter
        case renderCycleCounter
        case globalBypassFlag
        case outputGainWriteGeneration
        case activeGraphPointer
        case resetGeneration
        case automationResetGeneration
        case graphActivationResetGeneration
        case defaultAudioFormat
    }

    case allocationFailed(Component)
    case atomicsNotLockFree(Component)
    case unavailable(Component)

    public var description: String {
        switch self {
        case let .allocationFailed(component):
            "Real-time storage allocation failed for \(component.rawValue)."
        case let .atomicsNotLockFree(component):
            "The current platform does not provide lock-free atomics for \(component.rawValue)."
        case let .unavailable(component):
            "The required real-time component is unavailable: \(component.rawValue)."
        }
    }
}

/// Owns all mutable render state. Preparation and snapshot extraction happen off the audio thread;
/// `process` performs only bounded pointer arithmetic, atomics, and deterministic DSP.
final class RealtimeRenderKernel: @unchecked Sendable {
    static let captureDurationSeconds = 30.0
    static let maximumPublishedGraphsPerAllocation = 128
    static let maximumCaptureStorageBytes = 24 * 1_024 * 1_024
    static let maximumParameterEventsPerRender = 256
    static let maximumSupportedFramesPerRender = 65_536

    private let activeGraphPointer: OpaquePointer
    private let resetGeneration: OpaquePointer
    private let automationResetGeneration: OpaquePointer
    private let publicationLock = NSLock()
    /// Owns every graph address visible to the callback. Retired graphs are reclaimed only
    /// after the host deallocates render resources, so ARC never destroys one on render.
    private var ownedGraphBoxes: [RealtimeGraphBox] = []
    /// Reserved outside the bounded publication pool so bypass and recovery remain available
    /// even after every normal graph-publication slot has been consumed.
    private var dryGraphBox: RealtimeGraphBox?
    private var capture: CaptureRingBuffer?
    private var ioScratch: RealtimeIOScratch?
    /// Written only by the render thread after `prepare` completes.
    private var appliedResetGeneration: UInt64 = 0
    private var appliedAutomationResetGeneration: UInt64 = 0
    private var smoothedOutputGain: Float = 1
    private var outputGainSmoothingCoefficient: Float = 1
    /// Scheduled AU automation is owned by the render thread. A ramp event is
    /// delivered only in its first block, so this state must persist until the
    /// requested duration completes in later callbacks.
    private var scheduledOutputGainActive = false
    private var scheduledOutputGainWriteGeneration: UInt64 = 0
    private var scheduledOutputGainTarget: Float = 1
    private var scheduledOutputGainMultiplier: Float = 1
    private var scheduledOutputGainFramesRemaining = 0
    private(set) var sampleRate = 0.0
    private(set) var channelCount = 0
    private var maximumFramesPerRender = 0

    init() throws {
        guard let pointer = laa_atomic_pointer_create(nil) else {
            throw RealtimeInfrastructureError.allocationFailed(.activeGraphPointer)
        }
        guard laa_atomic_pointer_is_lock_free(pointer) != 0 else {
            laa_atomic_pointer_destroy(pointer)
            throw RealtimeInfrastructureError.atomicsNotLockFree(.activeGraphPointer)
        }
        guard let resetCounter = laa_atomic_u64_create(0) else {
            laa_atomic_pointer_destroy(pointer)
            throw RealtimeInfrastructureError.allocationFailed(.resetGeneration)
        }
        guard laa_atomic_u64_is_lock_free(resetCounter) != 0 else {
            laa_atomic_u64_destroy(resetCounter)
            laa_atomic_pointer_destroy(pointer)
            throw RealtimeInfrastructureError.atomicsNotLockFree(.resetGeneration)
        }
        guard let automationResetCounter = laa_atomic_u64_create(0) else {
            laa_atomic_u64_destroy(resetCounter)
            laa_atomic_pointer_destroy(pointer)
            throw RealtimeInfrastructureError.allocationFailed(.automationResetGeneration)
        }
        guard laa_atomic_u64_is_lock_free(automationResetCounter) != 0 else {
            laa_atomic_u64_destroy(automationResetCounter)
            laa_atomic_u64_destroy(resetCounter)
            laa_atomic_pointer_destroy(pointer)
            throw RealtimeInfrastructureError.atomicsNotLockFree(.automationResetGeneration)
        }
        activeGraphPointer = pointer
        resetGeneration = resetCounter
        automationResetGeneration = automationResetCounter
    }

    deinit {
        laa_atomic_pointer_store_release(activeGraphPointer, nil)
        laa_atomic_pointer_destroy(activeGraphPointer)
        laa_atomic_u64_destroy(resetGeneration)
        laa_atomic_u64_destroy(automationResetGeneration)
    }

    func prepare(
        sampleRate: Double,
        channelCount: Int,
        maximumFramesPerRender: Int,
        processingPlan: ProcessingPlan?,
        initialOutputGain: Float,
        initialOutputGainGeneration: UInt64
    ) throws {
        guard sampleRate.isFinite,
              (8_000...192_000).contains(sampleRate),
              sampleRate.rounded(.towardZero) == sampleRate else {
            throw RealtimeKernelError.invalidSampleRate(sampleRate)
        }
        guard channelCount == 1 || channelCount == 2 else {
            throw RealtimeKernelError.unsupportedChannelCount(channelCount)
        }
        guard maximumFramesPerRender > 0,
              maximumFramesPerRender <= Self.maximumSupportedFramesPerRender else {
            throw RealtimeKernelError.invalidMaximumFramesPerRender(maximumFramesPerRender)
        }
        if let processingPlan {
            let expectedFormat: ChannelFormat = channelCount == 1 ? .mono : .stereo
            guard processingPlan.scope.channelFormat == expectedFormat else {
                throw RealtimeKernelError.planChannelFormatMismatch
            }
        }
        let dryPlan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: ProcessingScope(
                kind: .pluginInput,
                channelFormat: channelCount == 1 ? .mono : .stereo,
                sourceType: .unknown
            ),
            goals: [],
            nodes: []
        )
        let dryGraph = try CompiledGraph(
            plan: dryPlan,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
        let reservedDryGraphBox = try RealtimeGraphBox(graph: dryGraph)
        let preparedGraphBox: RealtimeGraphBox? = try processingPlan.map {
            let graph = try CompiledGraph(
                plan: $0,
                sampleRate: sampleRate,
                channelCount: channelCount
            )
            return try RealtimeGraphBox(graph: graph)
        }
        let activeBox = preparedGraphBox ?? reservedDryGraphBox
        let bytesPerFrame = MemoryLayout<UInt32>.size * channelCount
        let maximumStorageFrames = Self.maximumCaptureStorageBytes / bytesPerFrame
        guard maximumFramesPerRender < maximumStorageFrames else {
            throw RealtimeKernelError.invalidMaximumFramesPerRender(maximumFramesPerRender)
        }
        let maximumFramesForStorage = maximumStorageFrames - maximumFramesPerRender
        let requestedCaptureFrames = max(
            1,
            Int((sampleRate * Self.captureDurationSeconds).rounded(.up))
        )
        let newCapture = try CaptureRingBuffer(
            capacityFrames: min(requestedCaptureFrames, maximumFramesForStorage),
            channelCount: channelCount,
            sampleRate: sampleRate,
            maximumWriteFrames: maximumFramesPerRender
        )
        let newIOScratch = RealtimeIOScratch(
            maximumFrames: maximumFramesPerRender,
            channelCount: channelCount
        )
        publicationLock.lock()
        defer { publicationLock.unlock() }
        ownedGraphBoxes = preparedGraphBox.map { [$0] } ?? []
        dryGraphBox = reservedDryGraphBox
        capture = newCapture
        ioScratch = newIOScratch
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.maximumFramesPerRender = maximumFramesPerRender
        smoothedOutputGain = initialOutputGain.isFinite ? initialOutputGain : 1
        outputGainSmoothingCoefficient = Float(1 - exp(-1 / max(sampleRate * 0.01, 1)))
        scheduledOutputGainActive = false
        scheduledOutputGainWriteGeneration = initialOutputGainGeneration
        scheduledOutputGainTarget = smoothedOutputGain
        scheduledOutputGainMultiplier = 1
        scheduledOutputGainFramesRemaining = 0
        appliedResetGeneration = laa_atomic_u64_load_acquire(resetGeneration)
        appliedAutomationResetGeneration = laa_atomic_u64_load_acquire(
            automationResetGeneration
        )
        laa_atomic_pointer_store_release(
            activeGraphPointer,
            Unmanaged.passUnretained(activeBox).toOpaque()
        )
    }

    /// Releases state owned by one host render-resource allocation. The host
    /// has already stopped callbacks before this method is called, so graph and
    /// capture storage can be reclaimed off the real-time thread. Clearing the
    /// capture is essential: a request during a deallocated interval must never
    /// publish audio retained from the previous host format or timeline.
    func deallocatePreparedState() {
        publicationLock.lock()
        laa_atomic_pointer_store_release(activeGraphPointer, nil)
        ownedGraphBoxes.removeAll(keepingCapacity: true)
        dryGraphBox = nil
        capture = nil
        ioScratch = nil
        sampleRate = 0
        channelCount = 0
        maximumFramesPerRender = 0
        smoothedOutputGain = 1
        outputGainSmoothingCoefficient = 1
        scheduledOutputGainActive = false
        scheduledOutputGainWriteGeneration = 0
        scheduledOutputGainTarget = 1
        scheduledOutputGainMultiplier = 1
        scheduledOutputGainFramesRemaining = 0
        publicationLock.unlock()
    }

    /// Host timeline discontinuities clear both DSP history and transitory
    /// scheduled automation at the next block boundary.
    func requestReset() {
        _ = laa_atomic_u64_fetch_add_release(resetGeneration, 1)
        _ = laa_atomic_u64_fetch_add_release(automationResetGeneration, 1)
    }

    /// Bypass transitions clear compressor/filter history while preserving the
    /// host's scheduled parameter timeline. Ramp events are delivered once and
    /// must continue to advance invisibly while bypassed.
    func requestGraphReset() {
        _ = laa_atomic_u64_fetch_add_release(resetGeneration, 1)
    }

    /// Compiles and retains a complete graph off render, then publishes only its stable address.
    /// The next callback observes either the previous graph or the complete new graph.
    func publish(_ plan: ProcessingPlan) throws {
        publicationLock.lock()
        defer { publicationLock.unlock() }
        guard sampleRate > 0, channelCount == 1 || channelCount == 2 else {
            throw RealtimeKernelError.notPrepared
        }
        let expectedFormat: ChannelFormat = channelCount == 1 ? .mono : .stereo
        guard plan.scope.channelFormat == expectedFormat else {
            throw RealtimeKernelError.planChannelFormatMismatch
        }
        if plan.nodes.allSatisfy({ !$0.enabled || $0.type == .meter }),
           let dryGraphBox {
            laa_atomic_pointer_store_release(
                activeGraphPointer,
                Unmanaged.passUnretained(dryGraphBox).toOpaque()
            )
            return
        }
        if ownedGraphBoxes.count >= Self.maximumPublishedGraphsPerAllocation {
            if let retained = ownedGraphBoxes.last(where: { $0.sourcePlan == plan }) {
                // The retained box may contain filter, detector, limiter, or gain
                // history from an earlier activation. Mark that box specifically;
                // the render thread resets it after observing this publication and
                // immediately before its first reactivated processing block.
                retained.requestResetBeforeNextProcess()
                laa_atomic_pointer_store_release(
                    activeGraphPointer,
                    Unmanaged.passUnretained(retained).toOpaque()
                )
                return
            }
            throw RealtimeKernelError.publicationLimitReached
        }
        let compiledGraph = try CompiledGraph(
            plan: plan,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
        let graphBox = try RealtimeGraphBox(graph: compiledGraph)
        ownedGraphBoxes.append(graphBox)
        laa_atomic_pointer_store_release(
            activeGraphPointer,
            Unmanaged.passUnretained(graphBox).toOpaque()
        )
    }

    /// Atomically selects the precompiled dry graph without consuming a publication slot.
    /// This path is intentionally non-allocating and cannot be blocked by publication limits.
    @discardableResult
    func activateDry() -> Bool {
        publicationLock.lock()
        defer { publicationLock.unlock() }
        guard let dryGraphBox else { return false }
        laa_atomic_pointer_store_release(
            activeGraphPointer,
            Unmanaged.passUnretained(dryGraphBox).toOpaque()
        )
        return true
    }

    /// Captures and processes the graph exactly once per host callback, retaining
    /// one graph pointer/reset snapshot for the complete block. The bounded event
    /// list controls only the post-graph output-gain stage sample by sample, so
    /// scheduled ramps are accurate without allowing mid-block graph activation.
    @inline(__always)
    func process(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int,
        blockStartSampleTime: Double,
        realtimeEventListHead: UnsafePointer<AURenderEvent>?,
        outputGain: Float,
        outputGainWriteGeneration: UInt64,
        globallyBypassed: Bool
    ) -> RealtimeProcessStatus {
        guard frameCount >= 0, frameCount <= maximumFramesPerRender else { return .invalidFrameCount }
        guard (channelCount == 1 && right == nil) || (channelCount == 2 && right != nil) else {
            return .channelMismatch
        }

        let captureRight: UnsafePointer<Float>? = if let right { UnsafePointer(right) } else { nil }
        let graphBox = activeGraph()
        // `requestReset` publishes graph reset before automation reset. Acquire
        // the latter first so observing a host discontinuity also orders the
        // preceding graph-reset ticket into this same callback.
        let requestedAutomationReset = laa_atomic_u64_load_acquire(
            automationResetGeneration
        )
        let requestedReset = laa_atomic_u64_load_acquire(resetGeneration)
        if requestedReset != appliedResetGeneration {
            graphBox?.reset()
            appliedResetGeneration = requestedReset
        }
        if requestedAutomationReset != appliedAutomationResetGeneration {
            smoothedOutputGain = outputGain.isFinite ? outputGain : 1
            scheduledOutputGainActive = false
            scheduledOutputGainFramesRemaining = 0
            scheduledOutputGainMultiplier = 1
            appliedAutomationResetGeneration = requestedAutomationReset
        }
        _ = graphBox?.consumePendingActivationReset()
        guard capture?.write(
            left: UnsafePointer(left),
            right: captureRight,
            frameCount: frameCount
        ) != false else { return .invalidFrameCount }
        // The host-owned buffers still contain the exact pulled input here.
        // Global bypass deliberately skips graph DSP and post-graph output trim;
        // capture and reset bookkeeping remain active without allocating.
        if !globallyBypassed {
            let status = graphBox?.process(
                left: left,
                right: right,
                frameCount: frameCount
            ) ?? .channelMismatch
            guard status == .processed else { return status }
        }
        applyOutputGainAndEvents(
            left: left,
            right: right,
            frameCount: frameCount,
            blockStart: safeEventSampleTime(blockStartSampleTime),
            realtimeEventListHead: realtimeEventListHead,
            externalOutputGain: outputGain,
            externalOutputGainWriteGeneration: outputGainWriteGeneration,
            applyToAudio: !globallyBypassed
        )
        return .processed
    }

    @inline(__always)
    private func handle(
        event: AURenderEvent,
        outputGainWriteGeneration: UInt64
    ) {
        guard event.head.eventType == .parameter || event.head.eventType == .parameterRamp,
              event.parameter.parameterAddress == 0 else { return }
        let decibels = event.parameter.value
        guard decibels.isFinite else { return }
        let clampedDB = min(max(decibels, -24), 0)
        let targetGain = pow(10, clampedDB / 20)
        scheduledOutputGainActive = true
        scheduledOutputGainWriteGeneration = outputGainWriteGeneration
        scheduledOutputGainTarget = targetGain
        let duration = event.head.eventType == .parameterRamp
            ? Int(event.parameter.rampDurationSampleFrames)
            : 0
        guard duration > 0,
              smoothedOutputGain.isFinite,
              smoothedOutputGain > 0,
              targetGain > 0 else {
            smoothedOutputGain = targetGain
            scheduledOutputGainMultiplier = 1
            scheduledOutputGainFramesRemaining = 0
            return
        }
        scheduledOutputGainMultiplier = pow(
            targetGain / smoothedOutputGain,
            1 / Float(duration)
        )
        scheduledOutputGainFramesRemaining = duration
    }

    @inline(__always)
    private func applyOutputGainAndEvents(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int,
        blockStart: AUEventSampleTime,
        realtimeEventListHead: UnsafePointer<AURenderEvent>?,
        externalOutputGain: Float,
        externalOutputGainWriteGeneration: UInt64,
        applyToAudio: Bool
    ) {
        let target = externalOutputGain.isFinite ? externalOutputGain : 1
        cancelScheduledAutomationIfExternallyChanged(
            writeGeneration: externalOutputGainWriteGeneration
        )
        var nextEvent = realtimeEventListHead
        var handledEventCount = 0
        guard nextEvent != nil || scheduledOutputGainActive || target != 1 || smoothedOutputGain != 1 else {
            return
        }
        for frame in 0..<frameCount {
            while let event = nextEvent,
                  handledEventCount < Self.maximumParameterEventsPerRender,
                  eventFrameOffset(
                    event.pointee.head.eventSampleTime,
                    blockStart: blockStart,
                    frameCount: frameCount
                  ) <= frame {
                handle(
                    event: event.pointee,
                    outputGainWriteGeneration: externalOutputGainWriteGeneration
                )
                nextEvent = event.pointee.head.next.map { UnsafePointer($0) }
                handledEventCount += 1
            }
            if handledEventCount >= Self.maximumParameterEventsPerRender {
                // A cyclic or overlong host list is ignored after a fixed amount
                // of work, while the block continues with the last valid state.
                nextEvent = nil
            }
            if scheduledOutputGainActive {
                if applyToAudio {
                    left[frame] = safeOutput(left[frame] * smoothedOutputGain)
                    if let right { right[frame] = safeOutput(right[frame] * smoothedOutputGain) }
                }
                advanceScheduledOutputGainOneFrame()
            } else {
                smoothedOutputGain += outputGainSmoothingCoefficient * (target - smoothedOutputGain)
                if applyToAudio {
                    left[frame] = safeOutput(left[frame] * smoothedOutputGain)
                    if let right { right[frame] = safeOutput(right[frame] * smoothedOutputGain) }
                }
            }
        }
    }

    @inline(__always)
    private func cancelScheduledAutomationIfExternallyChanged(
        writeGeneration: UInt64
    ) {
        guard scheduledOutputGainActive,
              writeGeneration != scheduledOutputGainWriteGeneration else { return }
        scheduledOutputGainActive = false
        scheduledOutputGainFramesRemaining = 0
        scheduledOutputGainMultiplier = 1
        // Retain the instantaneous scheduled value and let the normal 10 ms
        // de-zipper approach the new control target on subsequent samples.
    }

    @inline(__always)
    private func advanceScheduledOutputGainOneFrame() {
        guard scheduledOutputGainFramesRemaining > 0 else { return }
        smoothedOutputGain *= scheduledOutputGainMultiplier
        scheduledOutputGainFramesRemaining -= 1
        if scheduledOutputGainFramesRemaining == 0 {
            smoothedOutputGain = scheduledOutputGainTarget
            scheduledOutputGainMultiplier = 1
        }
    }

    @inline(__always)
    private func safeEventSampleTime(_ value: Double) -> AUEventSampleTime {
        guard value.isFinite else { return 0 }
        if value >= Double(Int64.max) { return Int64.max }
        if value <= Double(Int64.min) { return Int64.min }
        return AUEventSampleTime(value.rounded(.towardZero))
    }

    @inline(__always)
    private func eventFrameOffset(
        _ eventTime: AUEventSampleTime,
        blockStart: AUEventSampleTime,
        frameCount: Int
    ) -> Int {
        let (delta, overflow) = eventTime.subtractingReportingOverflow(blockStart)
        if overflow { return eventTime < blockStart ? 0 : frameCount }
        if delta <= 0 { return 0 }
        if delta >= AUEventSampleTime(frameCount) { return frameCount }
        return Int(delta)
    }

    @inline(__always)
    private func safeOutput(_ sample: Float) -> Float {
        guard sample.isFinite else { return 0 }
        if abs(sample) < 1e-30 { return 0 }
        return min(max(sample, -8), 8)
    }

    /// Resets the preallocated input ABL before every pull. The upstream unit is
    /// allowed to replace its mData pointers, so this cannot be done only once at
    /// allocation time.
    @inline(__always)
    var isPrepared: Bool { ioScratch != nil && maximumFramesPerRender > 0 }

    @inline(__always)
    func accepts(frameCount: Int) -> Bool {
        frameCount >= 0 && frameCount <= maximumFramesPerRender && ioScratch != nil
    }

    @inline(__always)
    func preparePullInput(frameCount: Int) -> UnsafeMutablePointer<AudioBufferList>? {
        ioScratch?.prepareInput(frameCount: frameCount)
    }

    @inline(__always)
    func replacePulledInputWithSilence(frameCount: Int) -> Bool {
        ioScratch?.prepareSilence(frameCount: frameCount) != nil
    }

    /// Copies pulled input into the host's nonnull outputs or into preallocated
    /// owned output storage when the host supplied null pointers. The pull ABL is
    /// separate from outputData, so upstream pointer replacement cannot lose the
    /// host's output addresses.
    @inline(__always)
    func copyPulledInputToOutput(
        _ outputData: UnsafeMutablePointer<AudioBufferList>,
        frameCount: Int
    ) -> RealtimeIOChannelPointers? {
        ioScratch?.copyPulledInput(to: outputData, frameCount: frameCount)
    }

    /// Must be called outside the audio callback. The returned value owns its storage.
    func recentCapture(maxDurationSeconds: Double? = nil) -> DSPCore.AudioBuffer? {
        publicationLock.lock()
        guard let retainedCapture = capture else {
            publicationLock.unlock()
            return nil
        }
        publicationLock.unlock()
        let requestedFrames: Int?
        if let duration = maxDurationSeconds {
            guard duration.isFinite, duration >= 0 else { return nil }
            let boundedFrames = min(
                Double(retainedCapture.capacityFrames),
                (duration * retainedCapture.sampleRate).rounded(.up)
            )
            requestedFrames = Int(max(0, boundedFrames))
        } else {
            requestedFrames = nil
        }
        guard let snapshot = retainedCapture.snapshot(maxFrames: requestedFrames),
              snapshot.frameCount > 0 else { return nil }
        return snapshot
    }

    @inline(__always)
    private func activeGraph() -> RealtimeGraphBox? {
        guard let pointer = laa_atomic_pointer_load_acquire(activeGraphPointer) else { return nil }
        return Unmanaged<RealtimeGraphBox>.fromOpaque(pointer).takeUnretainedValue()
    }
}

struct RealtimeIOChannelPointers {
    let left: UnsafeMutablePointer<Float>
    let right: UnsafeMutablePointer<Float>?
}

/// Allocation and Objective-C-free buffer ownership for the render callback.
/// Constructed/released only while host render resources are stopped.
private final class RealtimeIOScratch: @unchecked Sendable {
    private let maximumFrames: Int
    private let channelCount: Int
    private let inputList: UnsafeMutableAudioBufferListPointer
    private let inputLeft: UnsafeMutablePointer<Float>
    private let inputRight: UnsafeMutablePointer<Float>?
    private let outputLeft: UnsafeMutablePointer<Float>
    private let outputRight: UnsafeMutablePointer<Float>?

    init(maximumFrames: Int, channelCount: Int) {
        self.maximumFrames = maximumFrames
        self.channelCount = channelCount
        inputList = AudioBufferList.allocate(maximumBuffers: channelCount)
        inputLeft = .allocate(capacity: maximumFrames)
        outputLeft = .allocate(capacity: maximumFrames)
        if channelCount == 2 {
            inputRight = .allocate(capacity: maximumFrames)
            outputRight = .allocate(capacity: maximumFrames)
        } else {
            inputRight = nil
            outputRight = nil
        }
    }

    deinit {
        inputLeft.deallocate()
        inputRight?.deallocate()
        outputLeft.deallocate()
        outputRight?.deallocate()
        inputList.unsafeMutablePointer.deallocate()
    }

    @inline(__always)
    func prepareInput(frameCount: Int) -> UnsafeMutablePointer<AudioBufferList>? {
        guard frameCount >= 0, frameCount <= maximumFrames else { return nil }
        inputList.unsafeMutablePointer.pointee.mNumberBuffers = UInt32(channelCount)
        let byteCount = UInt32(frameCount * MemoryLayout<Float>.size)
        inputList[0] = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: byteCount,
            mData: UnsafeMutableRawPointer(inputLeft)
        )
        if channelCount == 2, let inputRight {
            inputList[1] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: byteCount,
                mData: UnsafeMutableRawPointer(inputRight)
            )
        }
        return inputList.unsafeMutablePointer
    }

    @inline(__always)
    func prepareSilence(frameCount: Int) -> UnsafeMutablePointer<AudioBufferList>? {
        guard let list = prepareInput(frameCount: frameCount) else { return nil }
        inputLeft.update(repeating: 0, count: frameCount)
        inputRight?.update(repeating: 0, count: frameCount)
        return list
    }

    @inline(__always)
    func copyPulledInput(
        to outputData: UnsafeMutablePointer<AudioBufferList>,
        frameCount: Int
    ) -> RealtimeIOChannelPointers? {
        guard frameCount >= 0,
              frameCount <= maximumFrames,
              inputList.count == channelCount else { return nil }
        let outputs = UnsafeMutableAudioBufferListPointer(outputData)
        guard outputs.count == channelCount else { return nil }
        let byteCount = UInt32(frameCount * MemoryLayout<Float>.size)
        var renderedLeft: UnsafeMutablePointer<Float>?
        var renderedRight: UnsafeMutablePointer<Float>?
        for channel in 0..<channelCount {
            guard inputList[channel].mNumberChannels == 1,
                  inputList[channel].mDataByteSize >= byteCount,
                  let sourceData = inputList[channel].mData else { return nil }
            let source = sourceData.assumingMemoryBound(to: Float.self)
            guard outputs[channel].mNumberChannels == 1 else { return nil }
            let ownedOutput = channel == 0 ? outputLeft : outputRight
            let destination: UnsafeMutablePointer<Float>
            if let hostOutput = outputs[channel].mData?.assumingMemoryBound(to: Float.self) {
                guard outputs[channel].mDataByteSize >= byteCount else { return nil }
                destination = hostOutput
            } else {
                guard let ownedOutput else { return nil }
                destination = ownedOutput
            }
            if destination != source {
                destination.update(from: source, count: frameCount)
            }
            outputs[channel].mData = UnsafeMutableRawPointer(destination)
            outputs[channel].mDataByteSize = byteCount
            if channel == 0 { renderedLeft = destination } else { renderedRight = destination }
        }
        guard let renderedLeft,
              channelCount == 1 || renderedRight != nil else { return nil }
        return RealtimeIOChannelPointers(left: renderedLeft, right: renderedRight)
    }
}

private final class RealtimeGraphBox: @unchecked Sendable {
    private var graph: CompiledGraph
    private let activationResetGeneration: OpaquePointer
    /// Read and written only by the serialized render callback.
    private var appliedActivationResetGeneration: UInt64 = 0
    let sourcePlan: ProcessingPlan

    init(graph: CompiledGraph) throws {
        guard let resetGeneration = laa_atomic_u64_create(0) else {
            throw RealtimeInfrastructureError.allocationFailed(.graphActivationResetGeneration)
        }
        guard laa_atomic_u64_is_lock_free(resetGeneration) != 0 else {
            laa_atomic_u64_destroy(resetGeneration)
            throw RealtimeInfrastructureError.atomicsNotLockFree(
                .graphActivationResetGeneration
            )
        }
        activationResetGeneration = resetGeneration
        sourcePlan = graph.sourcePlan
        self.graph = graph
    }

    deinit { laa_atomic_u64_destroy(activationResetGeneration) }

    @inline(__always)
    func process(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) -> RealtimeProcessStatus {
        graph.processRealtime(left: left, right: right, frameCount: frameCount)
    }

    /// Called off render before publishing a previously used graph box.
    func requestResetBeforeNextProcess() {
        _ = laa_atomic_u64_fetch_add_release(activationResetGeneration, 1)
    }

    /// Called only by the render thread after acquiring the active box pointer.
    /// The reset happens at the block boundary, never on the publisher thread.
    @inline(__always)
    func consumePendingActivationReset() -> Bool {
        let requested = laa_atomic_u64_load_acquire(activationResetGeneration)
        guard requested != appliedActivationResetGeneration else { return false }
        graph.reset()
        appliedActivationResetGeneration = requested
        return true
    }

    func reset() { graph.reset() }
}

enum RealtimeKernelError: Error {
    case planChannelFormatMismatch
    case notPrepared
    case publicationLimitReached
    case unsupportedChannelCount(Int)
    case invalidMaximumFramesPerRender(Int)
    case invalidSampleRate(Double)
}
