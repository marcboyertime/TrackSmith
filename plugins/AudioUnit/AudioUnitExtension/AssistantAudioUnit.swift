import AudioAnalysis
import AudioToolbox
import AVFoundation
import CAtomics
import DSPCore
import Foundation
import PlanSchema
import SharedIPC

final class RealtimeParameters: @unchecked Sendable {
    private let outputGainBits: OpaquePointer
    private let outputGainWriteGeneration: OpaquePointer
    private let inputPeakBits: OpaquePointer
    private let renderCycleCount: OpaquePointer
    private let globalBypassBits: OpaquePointer
    init() throws {
        var allocated: [OpaquePointer] = []
        var committed = false
        defer {
            if !committed {
                for pointer in allocated { laa_atomic_u64_destroy(pointer) }
            }
        }
        func makeAtomic(
            initialValue: UInt64,
            component: RealtimeInfrastructureError.Component
        ) throws -> OpaquePointer {
            guard let pointer = laa_atomic_u64_create(initialValue) else {
                throw RealtimeInfrastructureError.allocationFailed(component)
            }
            allocated.append(pointer)
            guard laa_atomic_u64_is_lock_free(pointer) != 0 else {
                throw RealtimeInfrastructureError.atomicsNotLockFree(component)
            }
            return pointer
        }

        let outputGainBits = try makeAtomic(
            initialValue: UInt64(Float(1).bitPattern),
            component: .outputGainParameter
        )
        let inputPeakBits = try makeAtomic(
            initialValue: UInt64(Float.zero.bitPattern),
            component: .inputPeakMeter
        )
        let renderCycleCount = try makeAtomic(
            initialValue: 0,
            component: .renderCycleCounter
        )
        let globalBypassBits = try makeAtomic(
            initialValue: 0,
            component: .globalBypassFlag
        )
        let outputGainWriteGeneration = try makeAtomic(
            initialValue: 0,
            component: .outputGainWriteGeneration
        )
        self.outputGainBits = outputGainBits
        self.outputGainWriteGeneration = outputGainWriteGeneration
        self.inputPeakBits = inputPeakBits
        self.renderCycleCount = renderCycleCount
        self.globalBypassBits = globalBypassBits
        committed = true
    }
    deinit {
        laa_atomic_u64_destroy(outputGainBits)
        laa_atomic_u64_destroy(outputGainWriteGeneration)
        laa_atomic_u64_destroy(inputPeakBits)
        laa_atomic_u64_destroy(renderCycleCount)
        laa_atomic_u64_destroy(globalBypassBits)
    }
    func setOutputGain(decibels: Float) {
        // AUParameter metadata does not clamp programmatic host writes. This
        // post-limiter trim must never add gain or store a nonfinite value.
        let boundedDB = decibels.isFinite ? min(max(decibels, -24), 0) : 0
        laa_atomic_u64_store_relaxed(
            outputGainBits,
            UInt64(pow(10, boundedDB / 20).bitPattern)
        )
        _ = laa_atomic_u64_fetch_add_release(outputGainWriteGeneration, 1)
    }
    func outputGain() -> Float { Float(bitPattern: UInt32(laa_atomic_u64_load_relaxed(outputGainBits))) }
    func outputGainGeneration() -> UInt64 {
        laa_atomic_u64_load_acquire(outputGainWriteGeneration)
    }
    func setInputPeak(_ peak: Float) { laa_atomic_u64_store_relaxed(inputPeakBits, UInt64(peak.bitPattern)) }
    func inputPeak() -> Float { Float(bitPattern: UInt32(laa_atomic_u64_load_relaxed(inputPeakBits))) }
    func markRenderCycle() {
        let current = laa_atomic_u64_load_relaxed(renderCycleCount)
        laa_atomic_u64_store_relaxed(renderCycleCount, current &+ 1)
    }
    func renderCycles() -> UInt64 { laa_atomic_u64_load_relaxed(renderCycleCount) }
    func setGlobalBypass(_ enabled: Bool) {
        laa_atomic_u64_store_release(globalBypassBits, enabled ? 1 : 0)
    }
    func globalBypassEnabled() -> Bool {
        laa_atomic_u64_load_acquire(globalBypassBits) != 0
    }
}

/// Host lifecycle and state transitions are externally serialized by AUAudioUnit. The render
/// kernel and bridge use explicit atomic/non-real-time boundaries for their shared data.
public final class AssistantAudioUnit: AUAudioUnit, @unchecked Sendable {
    private static let processingPlanStateKey = "com.marcboyer.logicaudioassistant.processing-plan-v1"
    private static let globalBypassStateKey = "com.marcboyer.logicaudioassistant.global-bypass-v1"
    private static let supportedChannelCapabilities: [NSNumber] = [1, 1, 2, 2]
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!
    private let realtimeParameters: RealtimeParameters
    private let renderKernel: RealtimeRenderKernel
    /// Serializes Logic's render-resource lifecycle with companion graph publication.
    /// Neither side takes this lock from the audio callback.
    private let lifecycleLock = NSLock()
    private let stateLock = NSLock()
    private var stagedProcessingPlan: ProcessingPlan?
    private var stagedGlobalBypassEnabled = false
    private var sessionBridge: PluginSessionBridge?
    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }
    public override var channelCapabilities: [NSNumber]? { Self.supportedChannelCapabilities }
    /// Hosts may cache this property, so it cannot safely vary with graph
    /// publication. The bound covers the validator's aggregate delay budget at
    /// maximum feedback, two maximum-decay rooms, filter state and margin down
    /// to the declared -120 dB amplitude threshold. A max-bound impulse test
    /// keeps this declaration coupled to the executable DSP contract.
    public override var tailTime: TimeInterval {
        PlanValidator.conservativeTailTimeSeconds
    }

    /// Logic and other hosts use this AUAudioUnit property for native insert
    /// bypass. Route it through the same atomic, serialized state used by the
    /// companion so host bypass, project restoration and the compact UI agree.
    public override var shouldBypassEffect: Bool {
        get { realtimeParameters.globalBypassEnabled() }
        set { setGlobalBypass(newValue) }
    }

    private static func supportsCaptureSampleRate(_ sampleRate: Double) -> Bool {
        sampleRate.isFinite &&
            (8_000...192_000).contains(sampleRate) &&
            sampleRate.rounded(.towardZero) == sampleRate
    }

    public override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        guard !renderResourcesAllocated,
              bus === inputBus || bus === outputBus,
              Self.supportsCaptureSampleRate(format.sampleRate),
              format.channelCount == 1 || format.channelCount == 2,
              format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved else { return false }
        return true
    }

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        realtimeParameters = try RealtimeParameters()
        renderKernel = try RealtimeRenderKernel()
        try super.init(componentDescription: componentDescription, options: options)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw RealtimeInfrastructureError.unavailable(.defaultAudioFormat)
        }
        inputBus = try AUAudioUnitBus(format: format); outputBus = try AUAudioUnitBus(format: format)
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        // This host-automatable trim is post-graph, so it may attenuate but never add gain
        // after the graph's safety limiter. Positive makeup belongs in the validated graph.
        let outputGain = AUParameterTree.createParameter(withIdentifier: "outputGain", name: "Output Gain", address: 0, min: -24, max: 0, unit: .decibels, unitName: nil, flags: [.flag_IsWritable, .flag_IsReadable, .flag_CanRamp], valueStrings: nil, dependentParameters: nil)
        outputGain.value = 0
        parameterTree = AUParameterTree.createTree(withChildren: [outputGain])
        parameterTree?.implementorValueObserver = { [realtimeParameters] parameter, value in
            if parameter.address == 0 { realtimeParameters.setOutputGain(decibels: value) }
        }
        maximumFramesToRender = 1_024
        sessionBridge = makeSessionBridge()
    }

    private func makeSessionBridge(exchange: FileExchange? = nil) -> PluginSessionBridge? {
        let resolvedExchange: FileExchange
        if let exchange { resolvedExchange = exchange }
        else {
            guard let appGroupExchange = try? FileExchange(appGroup: .default) else { return nil }
            resolvedExchange = appGroupExchange
        }
        return PluginSessionBridge(
            exchange: resolvedExchange,
            captureProvider: { [weak self] duration in
                self?.recentCapturedAudio(maxDurationSeconds: duration)
            },
            planApplier: { [weak self] plan, expectedPlan, allowLockedNodeRemoval, snapshotID, sampleRate, channelCount in
                guard let self else { throw AUError.instanceUnavailable }
                try self.commitProcessingPlan(
                    plan,
                    expectedCurrentPlan: expectedPlan,
                    allowLockedNodeRemoval: allowLockedNodeRemoval,
                    capturedSnapshotID: snapshotID,
                    capturedSampleRate: sampleRate,
                    capturedChannelCount: channelCount
                )
            },
            bypassApplier: { [weak self] enabled in
                guard let self else { throw AUError.instanceUnavailable }
                self.setGlobalBypass(enabled)
            },
            statusProvider: { [weak self] in
                self?.sessionStatus() ?? PluginSessionBridge.Status()
            }
        )
    }

    /// The bridge polls on a utility queue while Logic owns render-resource
    /// transitions. Snapshot host-owned format state under the same lifecycle
    /// lock used by allocation and graph publication.
    private func sessionStatus() -> PluginSessionBridge.Status {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let allocated = renderResourcesAllocated
        stateLock.lock()
        let plan = stagedProcessingPlan
        let globalBypassEnabled = stagedGlobalBypassEnabled
        stateLock.unlock()
        return PluginSessionBridge.Status(
            sampleRate: allocated ? inputBus.format.sampleRate : nil,
            channelCount: allocated ? Int(inputBus.format.channelCount) : nil,
            inputPeakDBFS: Double(inputPeakDBFS),
            currentPlan: plan,
            globalBypassEnabled: globalBypassEnabled
        )
    }

    @_spi(IntegrationTesting)
    public func attachSessionBridgeForTesting(directory: URL) throws -> UUID {
        let exchange = try FileExchange(directory: directory)
        guard let bridge = makeSessionBridge(exchange: exchange) else { throw AUError.instanceUnavailable }
        sessionBridge = bridge
        return bridge.instanceID
    }

    @_spi(IntegrationTesting)
    public func detachSessionBridgeForTesting() { sessionBridge = nil }

    public override func allocateRenderResources() throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let inputFormat = inputBus.format
        let outputFormat = outputBus.format
        guard inputFormat.channelCount == outputFormat.channelCount,
              inputFormat.sampleRate == outputFormat.sampleRate,
              Self.supportsCaptureSampleRate(inputFormat.sampleRate),
              inputFormat.channelCount == 1 || inputFormat.channelCount == 2,
              inputFormat.commonFormat == .pcmFormatFloat32,
              outputFormat.commonFormat == .pcmFormatFloat32,
              !inputFormat.isInterleaved,
              !outputFormat.isInterleaved else { throw AUError.formatNotSupported }
        try super.allocateRenderResources()
        do {
            stateLock.lock()
            let processingPlan = stagedProcessingPlan
            let globalBypassEnabled = stagedGlobalBypassEnabled
            stateLock.unlock()
            do {
                try renderKernel.prepare(
                    sampleRate: inputFormat.sampleRate,
                    channelCount: Int(inputFormat.channelCount),
                    maximumFramesPerRender: Int(maximumFramesToRender),
                    processingPlan: processingPlan,
                    initialOutputGain: realtimeParameters.outputGain(),
                    initialOutputGainGeneration: realtimeParameters.outputGainGeneration()
                )
                realtimeParameters.setGlobalBypass(globalBypassEnabled)
            } catch {
                // A project can be reopened with a changed channel layout, sample rate, or
                // obsolete graph. Host allocation must remain safe: prepare the reserved dry
                // graph and discard the incompatible state instead of failing Logic's insert.
                try renderKernel.prepare(
                    sampleRate: inputFormat.sampleRate,
                    channelCount: Int(inputFormat.channelCount),
                    maximumFramesPerRender: Int(maximumFramesToRender),
                    processingPlan: nil,
                    initialOutputGain: realtimeParameters.outputGain(),
                    initialOutputGainGeneration: realtimeParameters.outputGainGeneration()
                )
                stateLock.lock()
                stagedProcessingPlan = nil
                stagedGlobalBypassEnabled = false
                stateLock.unlock()
                realtimeParameters.setGlobalBypass(false)
            }
        } catch {
            super.deallocateRenderResources()
            renderKernel.deallocatePreparedState()
            throw error
        }
    }

    public override func reset() {
        renderKernel.requestReset()
        super.reset()
    }

    public override func deallocateRenderResources() {
        lifecycleLock.lock()
        super.deallocateRenderResources()
        renderKernel.deallocatePreparedState()
        realtimeParameters.setInputPeak(0)
        lifecycleLock.unlock()
    }

    /// Copies recent dry plug-in input for analysis. Never call this from the render thread.
    public func recentCapturedAudio(maxDurationSeconds: Double? = nil) -> DSPCore.AudioBuffer? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard renderResourcesAllocated else { return nil }
        return renderKernel.recentCapture(maxDurationSeconds: maxDurationSeconds)
    }

    /// Stages a validated graph while rendering is stopped. The host activates it on the next allocation.
    public func setProcessingPlan(_ plan: ProcessingPlan?) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard !renderResourcesAllocated else { throw AUError.renderResourcesMustBeDeallocated }
        if let plan { try PlanValidator().validateForRealtimeActivation(plan) }
        stateLock.lock()
        stagedProcessingPlan = plan
        stateLock.unlock()
    }

    /// Validates and compiles off render, then atomically activates the graph at a block boundary.
    /// The previous graph remains active if any preparation step fails.
    public func applyProcessingPlan(_ plan: ProcessingPlan?) throws {
        if let plan { try PlanValidator().validateForRealtimeActivation(plan) }
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        try applyProcessingPlanLocked(plan)
    }

    /// Performs the companion commit as one compare-and-swap transaction.
    /// Runtime format, expected graph, locked-node preservation, compilation,
    /// publication, and serialized state advance while the same lifecycle lock
    /// excludes host deallocation and fullState restoration.
    private func commitProcessingPlan(
        _ plan: ProcessingPlan,
        expectedCurrentPlan: ProcessingPlan?,
        allowLockedNodeRemoval: Bool,
        capturedSnapshotID: UUID,
        capturedSampleRate: Double,
        capturedChannelCount: Int
    ) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard renderResourcesAllocated else { throw AUError.renderResourcesUnavailable }
        let inputFormat = inputBus.format
        let outputFormat = outputBus.format
        guard inputFormat.sampleRate == capturedSampleRate,
              outputFormat.sampleRate == capturedSampleRate,
              Int(inputFormat.channelCount) == capturedChannelCount,
              Int(outputFormat.channelCount) == capturedChannelCount else {
            throw AUError.captureFormatChanged(
                capturedSampleRate: capturedSampleRate,
                capturedChannelCount: capturedChannelCount,
                currentSampleRate: inputFormat.sampleRate,
                currentChannelCount: Int(inputFormat.channelCount)
            )
        }
        stateLock.lock()
        let currentPlan = stagedProcessingPlan
        stateLock.unlock()
        guard currentPlan == expectedCurrentPlan else { throw AUError.staleActiveGraph }
        try PlanValidator().validateForRealtimeActivation(
            plan,
            currentSnapshotID: capturedSnapshotID,
            basePlan: allowLockedNodeRemoval ? nil : currentPlan
        )
        try applyProcessingPlanLocked(plan)
    }

    @_spi(IntegrationTesting)
    public func commitProcessingPlanForTesting(
        _ plan: ProcessingPlan,
        expectedCurrentPlan: ProcessingPlan?,
        allowLockedNodeRemoval: Bool = false,
        capturedSnapshotID: UUID,
        capturedSampleRate: Double,
        capturedChannelCount: Int
    ) throws {
        try commitProcessingPlan(
            plan,
            expectedCurrentPlan: expectedCurrentPlan,
            allowLockedNodeRemoval: allowLockedNodeRemoval,
            capturedSnapshotID: capturedSnapshotID,
            capturedSampleRate: capturedSampleRate,
            capturedChannelCount: capturedChannelCount
        )
    }

    /// Changes only the global audition state. The committed graph remains
    /// retained, serialized, and available for an exact block-boundary restore.
    public func setGlobalBypass(_ enabled: Bool) {
        lifecycleLock.lock()
        applyGlobalBypassLocked(enabled)
        lifecycleLock.unlock()
    }

    /// Requires `lifecycleLock`. Publication and serialized state advance while
    /// readers are excluded, so `fullState` cannot observe a hybrid revision.
    private func applyProcessingPlanLocked(_ plan: ProcessingPlan?) throws {
        if renderResourcesAllocated {
            if let plan {
                try renderKernel.publish(plan)
            } else if !renderKernel.activateDry() {
                throw AUError.instanceUnavailable
            }
        }
        stateLock.lock()
        stagedProcessingPlan = plan
        stateLock.unlock()
    }

    /// Requires `lifecycleLock`. The audio thread consumes the atomic flag and
    /// reset request without taking a lock or replacing the active graph.
    private func applyGlobalBypassLocked(_ enabled: Bool) {
        stateLock.lock()
        stagedGlobalBypassEnabled = enabled
        stateLock.unlock()
        // Publishing the reset request first means an acquire-load that sees
        // bypass disabled must also see the reset generation. The first restored
        // block can never process stale compressor/filter history.
        renderKernel.requestGraphReset()
        realtimeParameters.setGlobalBypass(enabled)
    }

    public var currentProcessingPlan: ProcessingPlan? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        stateLock.lock()
        defer { stateLock.unlock() }
        return stagedProcessingPlan
    }

    public var globalBypassEnabled: Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        stateLock.lock()
        defer { stateLock.unlock() }
        return stagedGlobalBypassEnabled
    }

    public var inputPeakDBFS: Float {
        let peak = realtimeParameters.inputPeak()
        let measured = peak > 0 ? 20 * log10(peak) : -160
        return min(max(measured.isFinite ? measured : -160, -200), 48)
    }

    public var completedRenderCycleCount: UInt64 { realtimeParameters.renderCycles() }

    public override var fullState: [String: Any]? {
        get {
            // AUAudioUnit's implementation may consult shouldBypassEffect. Call
            // it before taking our non-recursive lifecycle lock because the
            // overridden setter/getter is also part of the host bypass path.
            var state = super.fullState ?? [:]
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            // Never let a superclass-preserved unknown key resurrect stale or
            // corrupt custom state after recovery.
            state.removeValue(forKey: Self.processingPlanStateKey)
            state.removeValue(forKey: Self.globalBypassStateKey)
            stateLock.lock()
            let plan = stagedProcessingPlan
            let globalBypassEnabled = stagedGlobalBypassEnabled
            stateLock.unlock()
            if let plan,
               let encoded = try? JSONEncoder().encode(plan) {
                state[Self.processingPlanStateKey] = encoded
            }
            state[Self.globalBypassStateKey] = globalBypassEnabled
            return state
        }
        set {
            let restoredPlan: ProcessingPlan?
            let restoredGlobalBypass: Bool
            do {
                restoredPlan = if let encoded = newValue?[Self.processingPlanStateKey] as? Data {
                    try JSONDecoder().decode(ProcessingPlan.self, from: encoded)
                } else {
                    nil
                }
                if let restoredPlan {
                    try PlanValidator().validateForRealtimeActivation(restoredPlan)
                }
                if let encodedBypass = newValue?[Self.globalBypassStateKey] {
                    guard let bypass = encodedBypass as? Bool else {
                        throw AUError.invalidGlobalBypassState
                    }
                    restoredGlobalBypass = bypass
                } else {
                    restoredGlobalBypass = false
                }
            } catch {
                super.fullState = nil
                lifecycleLock.lock()
                activateDryFallbackLocked()
                lifecycleLock.unlock()
                return
            }

            // The superclass may route its native bypass field through our
            // override, so apply it outside lifecycleLock. The custom graph and
            // custom bypass key are then advanced together under that lock.
            super.fullState = newValue
            lifecycleLock.lock()
            var clearSuperclassState = false
            do {
                try applyProcessingPlanLocked(restoredPlan)
                applyGlobalBypassLocked(restoredGlobalBypass)
            } catch {
                // External state is untrusted. Invalid data, an incompatible graph, or a
                // saturated publication pool must never leave the previously active graph
                // masquerading as restored state.
                activateDryFallbackLocked()
                clearSuperclassState = true
            }
            lifecycleLock.unlock()
            if clearSuperclassState { super.fullState = nil }
        }
    }

    private func activateDryFallbackLocked() {
        if renderResourcesAllocated { _ = renderKernel.activateDry() }
        renderKernel.requestReset()
        stateLock.lock()
        stagedProcessingPlan = nil
        stagedGlobalBypassEnabled = false
        stateLock.unlock()
        realtimeParameters.setGlobalBypass(false)
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let parameters = realtimeParameters
        let kernel = renderKernel
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in
            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }
            guard outputBusNumber == 0 else { return kAudioUnitErr_InvalidElement }
            guard kernel.isPrepared else { return kAudioUnitErr_Uninitialized }
            guard kernel.accepts(frameCount: Int(frameCount)) else {
                return kAudioUnitErr_TooManyFramesToProcess
            }
            guard let pullBufferList = kernel.preparePullInput(frameCount: Int(frameCount)) else {
                return kAudioUnitErr_Uninitialized
            }
            let status = pullInputBlock(actionFlags, timestamp, frameCount, 0, pullBufferList)
            guard status == noErr else { return status }
            if actionFlags.pointee.contains(.unitRenderAction_OutputIsSilence),
               !kernel.replacePulledInputWithSilence(frameCount: Int(frameCount)) {
                return kAudio_ParamError
            }
            guard let rendered = kernel.copyPulledInputToOutput(
                outputData,
                frameCount: Int(frameCount)
            ) else { return kAudio_ParamError }
            let left = rendered.left
            let right = rendered.right
            var inputPeak: Float = 0
            for frame in 0..<Int(frameCount) {
                // A malformed host/upstream plug-in must not inject NaN or
                // infinity into the capture buffer, a bypassed output, or the
                // stateful graph. Finite input remains sample-exact in bypass.
                if left[frame].isFinite { inputPeak = max(inputPeak, abs(left[frame])) }
                else { left[frame] = 0 }
                if let right {
                    if right[frame].isFinite { inputPeak = max(inputPeak, abs(right[frame])) }
                    else { right[frame] = 0 }
                }
            }
            parameters.setInputPeak(inputPeak)
            parameters.markRenderCycle()
            let processStatus = kernel.process(
                left: left,
                right: right,
                frameCount: Int(frameCount),
                blockStartSampleTime: timestamp.pointee.mSampleTime,
                realtimeEventListHead: realtimeEventListHead,
                outputGain: parameters.outputGain(),
                outputGainWriteGeneration: parameters.outputGainGeneration(),
                globallyBypassed: parameters.globalBypassEnabled()
            )
            switch processStatus {
            case .processed:
                break
            case .invalidFrameCount:
                return kAudioUnitErr_TooManyFramesToProcess
            case .channelMismatch:
                return kAudio_ParamError
            }
            // Upstream silence describes the pulled input, not necessarily this
            // effect's output: IIR/filter state can emit a tail. Clearing the hint
            // conservatively is always safe; leaving a false hint may let a host
            // discard audible output.
            actionFlags.pointee.remove(.unitRenderAction_OutputIsSilence)
            return noErr
        }
    }
}

private enum AUError: Error, CustomStringConvertible {
    case formatNotSupported
    case renderResourcesMustBeDeallocated
    case instanceUnavailable
    case invalidGlobalBypassState
    case renderResourcesUnavailable
    case staleActiveGraph
    case captureFormatChanged(
        capturedSampleRate: Double,
        capturedChannelCount: Int,
        currentSampleRate: Double,
        currentChannelCount: Int
    )

    var description: String {
        switch self {
        case .formatNotSupported: "The host audio format is not supported."
        case .renderResourcesMustBeDeallocated: "Render resources must be deallocated for this operation."
        case .instanceUnavailable: "The Audio Unit instance is no longer available."
        case .invalidGlobalBypassState: "The saved global bypass state is invalid."
        case .renderResourcesUnavailable:
            "The Audio Unit is not currently allocated for audio. Play or reactivate the insert, then capture again."
        case .staleActiveGraph:
            "The active Audio Unit graph changed after this commit was proposed. Capture or refresh before retrying."
        case let .captureFormatChanged(capturedRate, capturedChannels, currentRate, currentChannels):
            "The Audio Unit format changed after capture (captured \(capturedRate) Hz/\(capturedChannels) ch; current \(currentRate) Hz/\(currentChannels) ch). Capture again before committing."
        }
    }
}
