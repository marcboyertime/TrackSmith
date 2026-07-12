import AudioAnalysis
import AudioToolbox
import AVFoundation
import CAtomics
import Foundation

final class RealtimeParameters: @unchecked Sendable {
    private let outputGainBits: OpaquePointer
    init() { outputGainBits = laa_atomic_u64_create(UInt64(Float(1).bitPattern))! }
    deinit { laa_atomic_u64_destroy(outputGainBits) }
    func setOutputGain(decibels: Float) { laa_atomic_u64_store_relaxed(outputGainBits, UInt64(pow(10, decibels / 20).bitPattern)) }
    func outputGain() -> Float { Float(bitPattern: UInt32(laa_atomic_u64_load_relaxed(outputGainBits))) }
}

public final class AssistantAudioUnit: AUAudioUnit {
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!
    private let realtimeParameters = RealtimeParameters()
    private let capture = CaptureRingBuffer(capacityFrames: 48_000 * 30, channelCount: 2, sampleRate: 48_000)
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
        guard inputBus.format.channelCount == outputBus.format.channelCount,
              inputBus.format.sampleRate == outputBus.format.sampleRate else { throw AUError.formatNotSupported }
        try super.allocateRenderResources()
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let parameters = realtimeParameters
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, _, pullInputBlock in
            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }
            let status = pullInputBlock(actionFlags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            let gain = parameters.outputGain()
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for frame in 0..<Int(frameCount) { data[frame] *= gain }
            }
            return noErr
        }
    }
}

private enum AUError: Error { case formatNotSupported }
