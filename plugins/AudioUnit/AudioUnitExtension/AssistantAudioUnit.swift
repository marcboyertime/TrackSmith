import AudioAnalysis
import AudioToolbox
import AVFoundation
import CAtomics
import DSPCore
import Foundation
import PlanSchema

final class RealtimeParameters: @unchecked Sendable {
    private let outputGainBits: OpaquePointer
    private let inputPeakBits: OpaquePointer
    private let renderCycleCount: OpaquePointer
    init() {
        outputGainBits = laa_atomic_u64_create(UInt64(Float(1).bitPattern))!
        inputPeakBits = laa_atomic_u64_create(UInt64(Float.zero.bitPattern))!
        renderCycleCount = laa_atomic_u64_create(0)!
    }
    deinit {
        laa_atomic_u64_destroy(outputGainBits)
        laa_atomic_u64_destroy(inputPeakBits)
        laa_atomic_u64_destroy(renderCycleCount)
    }
    func setOutputGain(decibels: Float) { laa_atomic_u64_store_relaxed(outputGainBits, UInt64(pow(10, decibels / 20).bitPattern)) }
    func outputGain() -> Float { Float(bitPattern: UInt32(laa_atomic_u64_load_relaxed(outputGainBits))) }
    func setInputPeak(_ peak: Float) { laa_atomic_u64_store_relaxed(inputPeakBits, UInt64(peak.bitPattern)) }
    func inputPeak() -> Float { Float(bitPattern: UInt32(laa_atomic_u64_load_relaxed(inputPeakBits))) }
    func markRenderCycle() {
        let current = laa_atomic_u64_load_relaxed(renderCycleCount)
        laa_atomic_u64_store_relaxed(renderCycleCount, current &+ 1)
    }
    func renderCycles() -> UInt64 { laa_atomic_u64_load_relaxed(renderCycleCount) }
}

public final class AssistantAudioUnit: AUAudioUnit {
    private static let processingPlanStateKey = "com.marcboyer.logicaudioassistant.processing-plan-v1"
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!
    private let realtimeParameters = RealtimeParameters()
    private let renderKernel = RealtimeRenderKernel()
    private let stateLock = NSLock()
    private var stagedProcessingPlan: ProcessingPlan?
    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        inputBus = try AUAudioUnitBus(format: format); outputBus = try AUAudioUnitBus(format: format)
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        let outputGain = AUParameterTree.createParameter(withIdentifier: "outputGain", name: "Output Gain", address: 0, min: -24, max: 12, unit: .decibels, unitName: nil, flags: [.flag_IsWritable, .flag_IsReadable], valueStrings: nil, dependentParameters: nil)
        outputGain.value = 0
        parameterTree = AUParameterTree.createTree(withChildren: [outputGain])
        parameterTree?.implementorValueObserver = { [realtimeParameters] parameter, value in
            if parameter.address == 0 { realtimeParameters.setOutputGain(decibels: value) }
        }
        maximumFramesToRender = 1_024
    }

    public override func allocateRenderResources() throws {
        let inputFormat = inputBus.format
        let outputFormat = outputBus.format
        guard inputFormat.channelCount == outputFormat.channelCount,
              inputFormat.sampleRate == outputFormat.sampleRate,
              inputFormat.channelCount == 1 || inputFormat.channelCount == 2,
              inputFormat.commonFormat == .pcmFormatFloat32,
              outputFormat.commonFormat == .pcmFormatFloat32,
              !inputFormat.isInterleaved,
              !outputFormat.isInterleaved else { throw AUError.formatNotSupported }
        try super.allocateRenderResources()
        do {
            stateLock.lock()
            let processingPlan = stagedProcessingPlan
            stateLock.unlock()
            try renderKernel.prepare(
                sampleRate: inputFormat.sampleRate,
                channelCount: Int(inputFormat.channelCount),
                processingPlan: processingPlan
            )
        } catch {
            super.deallocateRenderResources()
            throw error
        }
    }

    public override func reset() {
        renderKernel.reset()
        super.reset()
    }

    /// Copies recent dry plug-in input for analysis. Never call this from the render thread.
    public func recentCapturedAudio(maxDurationSeconds: Double? = nil) -> DSPCore.AudioBuffer? {
        renderKernel.recentCapture(maxDurationSeconds: maxDurationSeconds)
    }

    /// Stages a validated graph while rendering is stopped. The host activates it on the next allocation.
    public func setProcessingPlan(_ plan: ProcessingPlan?) throws {
        guard !renderResourcesAllocated else { throw AUError.renderResourcesMustBeDeallocated }
        if let plan { try PlanValidator().validate(plan) }
        stateLock.lock()
        stagedProcessingPlan = plan
        stateLock.unlock()
    }

    public var currentProcessingPlan: ProcessingPlan? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return stagedProcessingPlan
    }

    public var inputPeakDBFS: Float {
        let peak = realtimeParameters.inputPeak()
        return peak > 0 ? 20 * log10(peak) : -160
    }

    public var completedRenderCycleCount: UInt64 { realtimeParameters.renderCycles() }

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            if let plan = currentProcessingPlan,
               let encoded = try? JSONEncoder().encode(plan) {
                state[Self.processingPlanStateKey] = encoded
            }
            return state
        }
        set {
            super.fullState = newValue
            guard let encoded = newValue?[Self.processingPlanStateKey] as? Data,
                  let plan = try? JSONDecoder().decode(ProcessingPlan.self, from: encoded),
                  (try? PlanValidator().validate(plan)) != nil else { return }
            stateLock.lock()
            stagedProcessingPlan = plan
            stateLock.unlock()
        }
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let parameters = realtimeParameters
        let kernel = renderKernel
        let maximumFrames = maximumFramesToRender
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, _, pullInputBlock in
            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }
            guard frameCount <= maximumFrames else { return kAudioUnitErr_TooManyFramesToProcess }
            let status = pullInputBlock(actionFlags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            guard buffers.count == kernel.channelCount,
                  buffers[0].mNumberChannels == 1,
                  buffers[0].mData != nil,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            if kernel.channelCount == 2,
               (buffers[1].mNumberChannels != 1 || buffers[1].mData == nil) { return noErr }
            let right = kernel.channelCount == 2
                ? buffers[1].mData?.assumingMemoryBound(to: Float.self)
                : nil
            var inputPeak: Float = 0
            for frame in 0..<Int(frameCount) {
                inputPeak = max(inputPeak, abs(left[frame]))
                if let right { inputPeak = max(inputPeak, abs(right[frame])) }
            }
            parameters.setInputPeak(inputPeak)
            parameters.markRenderCycle()
            _ = kernel.process(
                left: left,
                right: right,
                frameCount: Int(frameCount),
                outputGain: parameters.outputGain()
            )
            return noErr
        }
    }
}

private enum AUError: Error {
    case formatNotSupported
    case renderResourcesMustBeDeallocated
}
