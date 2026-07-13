import AudioToolbox
import AudioUnitExtensionCore
import AVFoundation
import Foundation
import PlanSchema

private enum ProbeFailure: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self { case let .message(message): message }
    }
}

@main
enum AudioUnitHostProbe {
    static func main() {
        do {
            try run()
            print("PASS Audio Unit instantiated and rendered mono/stereo host buffers")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: fourCC("LgAA"),
            componentManufacturer: fourCC("ExAI"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        AUAudioUnit.registerSubclass(
            AssistantAudioUnit.self,
            as: description,
            name: "Marc Boyer: Logic Audio Assistant",
            version: 0x0001_0000
        )

        try exercise(description: description, sampleRate: 44_100, channelCount: 1, frameCount: 257)
        try exercise(description: description, sampleRate: 96_000, channelCount: 2, frameCount: 1_024)
        try rejectMismatchedPlan(description: description)
    }

    private static func rejectMismatchedPlan(description: AudioComponentDescription) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: .init(kind: .pluginInput, channelFormat: .stereo, sourceType: .unknown),
            goals: [],
            nodes: []
        )
        try unit.setProcessingPlan(plan)
        let mono = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        try unit.inputBusses[0].setFormat(mono)
        try unit.outputBusses[0].setFormat(mono)
        var rejected = false
        do { try unit.allocateRenderResources() } catch { rejected = true }
        if unit.renderResourcesAllocated { unit.deallocateRenderResources() }
        guard rejected else {
            throw ProbeFailure.message("AU accepted a stereo plan on a mono host layout")
        }
    }

    private static func exercise(
        description: AudioComponentDescription,
        sampleRate: Double,
        channelCount: AVAudioChannelCount,
        frameCount: AVAudioFrameCount
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: ProcessingScope(
                kind: .pluginInput,
                channelFormat: channelCount == 1 ? .mono : .stereo,
                sourceType: .unknown
            ),
            goals: [],
            nodes: [
                ProcessingNode(
                    type: .polarity,
                    rationale: "Proves the serialized deterministic graph is active in the AU callback.",
                    confidence: 1,
                    category: .corrective
                )
            ]
        )
        try unit.setProcessingPlan(plan)
        let state = unit.fullState
        let restoredUnit = try AssistantAudioUnit(componentDescription: description)
        restoredUnit.fullState = state
        guard restoredUnit.currentProcessingPlan == plan else {
            throw ProbeFailure.message("processing plan did not survive AU fullState restoration")
        }
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else { throw ProbeFailure.message("could not create host format") }
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        unit.maximumFramesToRender = max(frameCount, 1_024)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }

        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let outputChannels = output.floatChannelData else {
            throw ProbeFailure.message("could not allocate host output")
        }
        output.frameLength = frameCount
        var source = [[Float]]()
        for channel in 0..<Int(channelCount) {
            let frequency = Double(220 + channel * 110)
            var samples = [Float]()
            samples.reserveCapacity(Int(frameCount))
            for frame in 0..<Int(frameCount) {
                let phase = 2 * Double.pi * frequency * Double(frame) / sampleRate
                samples.append(Float(0.2 * sin(phase)))
            }
            source.append(samples)
        }
        unit.parameterTree?.parameter(withAddress: 0)?.value = -6

        var flags: AudioUnitRenderActionFlags = []
        var timestamp = AudioTimeStamp(
            mSampleTime: 0,
            mHostTime: 0,
            mRateScalar: 0,
            mWordClockTime: 0,
            mSMPTETime: SMPTETime(),
            mFlags: .sampleTimeValid,
            mReserved: 0
        )
        let pullInput: AURenderPullInputBlock = { _, _, requestedFrames, _, outputData in
            guard requestedFrames == frameCount else { return kAudio_ParamError }
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            guard buffers.count == Int(channelCount) else { return kAudio_ParamError }
            for channel in 0..<Int(channelCount) {
                guard let destination = buffers[channel].mData?.assumingMemoryBound(to: Float.self) else {
                    return kAudio_ParamError
                }
                source[channel].withUnsafeBufferPointer { samples in
                    destination.update(from: samples.baseAddress!, count: Int(frameCount))
                }
            }
            return noErr
        }
        let status = unit.internalRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            output.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard status == noErr else { throw ProbeFailure.message("render returned OSStatus \(status)") }

        let expectedGain = Float(pow(10, -6.0 / 20.0))
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frameCount) {
                let expected = -source[channel][frame] * expectedGain
                guard abs(outputChannels[channel][frame] - expected) < 1e-6 else {
                    throw ProbeFailure.message("render mismatch at \(sampleRate) Hz channel \(channel) frame \(frame)")
                }
            }
        }

        guard let captured = unit.recentCapturedAudio(),
              captured.channelCount == Int(channelCount),
              captured.frameCount == Int(frameCount),
              captured.sampleRate == sampleRate else {
            throw ProbeFailure.message("captured input shape did not match host input")
        }
        for channel in 0..<Int(channelCount) {
            guard captured.channels[channel] == source[channel] else {
                throw ProbeFailure.message("capture did not preserve dry channel \(channel)")
            }
        }
    }

    private static func fourCC(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }
}
