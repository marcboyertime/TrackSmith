import AudioToolbox
@_spi(IntegrationTesting) import AudioUnitExtensionCore
import AVFoundation
import Darwin
import DSPCore
import Foundation
import PlanSchema
import PreviewWorkflow
import SessionCore
import SharedIPC

private enum ProbeFailure: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self { case let .message(message): message }
    }
}

private final class ConcurrentProbeFailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedMessage: String?

    func record(_ error: Error) {
        lock.lock()
        storedMessage = String(describing: error)
        lock.unlock()
    }

    var message: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedMessage
    }
}

private final class RealtimeHeapProbe {
    private typealias BeginFunction = @convention(c) () -> Void
    private typealias EndFunction = @convention(c) () -> UInt64
    private typealias CountFunction = @convention(c) () -> UInt64
    private typealias CallerFunction = @convention(c) () -> UInt
    private typealias KindFunction = @convention(c) () -> UInt32
    private typealias BacktraceFrameFunction = @convention(c) (UInt32) -> UInt

    private let beginFunction: BeginFunction
    private let endFunction: EndFunction
    private let allocationCountFunction: CountFunction
    private let deallocationCountFunction: CountFunction
    private let firstCallerFunction: CallerFunction
    private let firstKindFunction: KindFunction
    private let backtraceCountFunction: KindFunction
    private let backtraceFrameFunction: BacktraceFrameFunction

    init?() {
        guard let handle = dlopen(nil, RTLD_NOW),
              let beginSymbol = dlsym(handle, "laa_rt_heap_probe_begin"),
              let endSymbol = dlsym(handle, "laa_rt_heap_probe_end"),
              let allocationCountSymbol = dlsym(handle, "laa_rt_heap_probe_allocation_count"),
              let deallocationCountSymbol = dlsym(handle, "laa_rt_heap_probe_deallocation_count"),
              let firstCallerSymbol = dlsym(handle, "laa_rt_heap_probe_first_caller"),
              let firstKindSymbol = dlsym(handle, "laa_rt_heap_probe_first_kind"),
              let backtraceCountSymbol = dlsym(handle, "laa_rt_heap_probe_backtrace_count"),
              let backtraceFrameSymbol = dlsym(handle, "laa_rt_heap_probe_backtrace_frame") else {
            return nil
        }
        beginFunction = unsafeBitCast(beginSymbol, to: BeginFunction.self)
        endFunction = unsafeBitCast(endSymbol, to: EndFunction.self)
        allocationCountFunction = unsafeBitCast(allocationCountSymbol, to: CountFunction.self)
        deallocationCountFunction = unsafeBitCast(deallocationCountSymbol, to: CountFunction.self)
        firstCallerFunction = unsafeBitCast(firstCallerSymbol, to: CallerFunction.self)
        firstKindFunction = unsafeBitCast(firstKindSymbol, to: KindFunction.self)
        backtraceCountFunction = unsafeBitCast(backtraceCountSymbol, to: KindFunction.self)
        backtraceFrameFunction = unsafeBitCast(backtraceFrameSymbol, to: BacktraceFrameFunction.self)
    }

    @inline(__always)
    func begin() {
        beginFunction()
    }

    @inline(__always)
    func end() -> UInt64 {
        endFunction()
    }

    func failureDetail() -> String {
        let count = min(backtraceCountFunction(), 12)
        var symbols: [String] = []
        symbols.reserveCapacity(Int(count))
        for index in 0..<count {
            let address = backtraceFrameFunction(index)
            var information = Dl_info()
            if let pointer = UnsafeRawPointer(bitPattern: address), dladdr(pointer, &information) != 0 {
                let image = information.dli_fname.map { String(cString: $0) } ?? "unknown-image"
                let name = information.dli_sname.map { String(cString: $0) } ?? "unknown-symbol"
                symbols.append("0x\(String(address, radix: 16)) \(image):\(name)")
            } else {
                symbols.append("0x\(String(address, radix: 16)) unresolved")
            }
        }
        return "allocations=\(allocationCountFunction()) deallocations=\(deallocationCountFunction()) firstKind=\(firstKindFunction()) caller=0x\(String(firstCallerFunction(), radix: 16)) stack=[\(symbols.joined(separator: " | "))]"
    }
}

@main
enum AudioUnitHostProbe {
    static func main() async {
        do {
            try await run()
            print("PASS Audio Unit rendered, captured, previewed, committed, and reverted")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
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

        try verifyFormatContract(description: description)
        try verifyMaximumFeedbackTailBound()
        try verifyHostBufferContracts(description: description)
        try rejectMismatchedBusAllocations(description: description)
        try verifyAtomicCommitGuards(description: description)
        try exercise(description: description, sampleRate: 44_100, channelCount: 1, frameCount: 257)
        try exercise(description: description, sampleRate: 96_000, channelCount: 2, frameCount: 1_024)
        try exercise(description: description, sampleRate: 48_000, channelCount: 1, frameCount: 16_384)
        try verifyVocalModulatedDelayHostLifecycle(description: description)
        try rejectMismatchedPlan(description: description)
        try verifyEmergencyBypassAfterPublicationExhaustion(description: description)
        try verifyGlobalBypassNonfiniteSanitization(description: description)
        try verifyOutputSilenceFlagContract(description: description)
        try verifyScheduledParameterAutomation(description: description)
        try verifyConcurrentPublicationWithScheduledEvents(description: description)
        try verifyOutputGainAutomationSmoothing(description: description)
        try measureRealtimePerformance(description: description)
        try await verifyCaptureLifecycle(description: description)
        try await exerciseSessionRoundTrip(description: description)
        try await exerciseTwoInstanceIsolation(description: description)
    }

    private static func exerciseSessionRoundTrip(description: AudioComponentDescription) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let unit = try AssistantAudioUnit(componentDescription: description)
        let instanceID = try unit.attachSessionBridgeForTesting(directory: root)
        defer { unit.detachSessionBridgeForTesting() }

        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 512
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let outputChannel = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate session probe buffer")
        }
        output.frameLength = frameCount
        var source = [Float](repeating: 0, count: Int(frameCount))
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
            guard requestedFrames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            destination.update(from: source, count: Int(frameCount))
            return noErr
        }
        func renderBlock(blockIndex: Int) throws {
            for frame in source.indices {
                let absoluteFrame = blockIndex * Int(frameCount) + frame
                source[frame] = Float(0.22 * sin(2 * .pi * 220 * Double(absoluteFrame) / sampleRate)
                    + 0.06 * sin(2 * .pi * 3_200 * Double(absoluteFrame) / sampleRate))
            }
            timestamp.mSampleTime = Float64(blockIndex * Int(frameCount))
            let status = unit.internalRenderBlock(
                &flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pullInput
            )
            guard status == noErr else { throw ProbeFailure.message("session render returned \(status)") }
        }
        for block in 0..<96 { try renderBlock(blockIndex: block) }

        let exchange = try FileExchange(directory: root)
        let client = CompanionSessionClient(exchange: exchange)
        let instance = try await waitForInstance(client: client, id: instanceID)
        let captureRequestID = try await client.requestRecentCapture(instance: instance, durationSeconds: 2)
        let (artifact, _) = try await waitForCapture(
            client: client,
            requestID: captureRequestID,
            instanceID: instanceID
        )
        guard artifact.frameCount == 96 * Int(frameCount) else {
            throw ProbeFailure.message("captured frame count did not match rendered playback")
        }
        let previews = try await client.renderPreviews(
            artifact: artifact,
            prompt: "make this clearer and more controlled",
            sourceType: .vocal
        )
        guard previews.manifest.validVariantCount == 3,
              let balanced = previews.manifest.variants.first(where: { $0.strength == .balanced }) else {
            throw ProbeFailure.message("session did not produce three valid previews")
        }
        let commitID = try await client.commit(
            plan: balanced.plan,
            artifact: artifact,
            originatingInstance: instance,
            expectedCurrentPlan: instance.currentPlan
        )
        _ = try await waitForTerminal(client: client, requestID: commitID, instanceID: instanceID)

        var nextBlockIndex = 97
        func renderAndAssert(_ plan: ProcessingPlan, label: String) throws {
            try renderBlock(blockIndex: nextBlockIndex)
            nextBlockIndex += 1
            var expected = AudioBuffer(channels: [source], sampleRate: sampleRate)
            var graph = try CompiledGraph(plan: plan, sampleRate: sampleRate, channelCount: 1)
            try graph.process(&expected)
            for frame in source.indices
            where abs(outputChannel[frame] - expected.channels[0][frame]) > 1e-6 {
                throw ProbeFailure.message("\(label) diverged from offline graph at frame \(frame)")
            }
        }
        func renderAndAssertDry(label: String) throws {
            try renderBlock(blockIndex: nextBlockIndex)
            nextBlockIndex += 1
            for frame in source.indices where outputChannel[frame] != source[frame] {
                throw ProbeFailure.message("\(label) was not bit-exact at frame \(frame)")
            }
        }
        try renderAndAssert(balanced.plan, label: "balanced AU commit")

        // Lock the exact EQ nodes in a materialized working-plan preview before
        // asking for a conversational compression-only revision. This makes the
        // lock an active compare-and-swap precondition, not merely UI metadata.
        var eqLockCandidate = balanced.plan
        eqLockCandidate.requestID = UUID()
        eqLockCandidate.nodes = eqLockCandidate.nodes.map { node in
            var copy = node
            if copy.type == .parametricEQ { copy.locked = true }
            return copy
        }
        guard eqLockCandidate.nodes.contains(where: { $0.type == .parametricEQ && $0.locked }) else {
            throw ProbeFailure.message("balanced vocal plan did not contain a parametric EQ to lock")
        }
        let lockedPreview = try await client.renderWorkingPlanPreview(
            artifact: artifact,
            plan: eqLockCandidate
        )
        guard lockedPreview.variant.status == .valid else {
            throw ProbeFailure.message(
                "EQ-lock preview was rejected: \(lockedPreview.variant.rejectionReasons.joined(separator: " "))"
            )
        }
        let lockedPlan = lockedPreview.variant.plan
        guard lockedPlan.nodes.filter({ $0.type == .parametricEQ }).allSatisfy(\.locked) else {
            throw ProbeFailure.message("materialized EQ-lock preview did not retain every EQ lock")
        }
        let lockCommitID = try await client.commit(
            plan: lockedPlan,
            artifact: artifact,
            originatingInstance: instance,
            expectedCurrentPlan: balanced.plan
        )
        _ = try await waitForTerminal(
            client: client,
            requestID: lockCommitID,
            instanceID: instanceID
        )
        guard unit.currentProcessingPlan == lockedPlan else {
            throw ProbeFailure.message("capture-bound EQ-lock commit did not become the active graph")
        }
        try renderAndAssert(lockedPlan, label: "locked EQ AU commit")

        let revisionPreview = try await client.renderRevisionPreview(
            artifact: artifact,
            basePlan: lockedPlan,
            request: "use less compression"
        )
        guard revisionPreview.variant.status == .valid,
              let revisionAudioURL = revisionPreview.audioURL else {
            throw ProbeFailure.message(
                "compression revision was rejected: \(revisionPreview.variant.rejectionReasons.joined(separator: " "))"
            )
        }
        let revisedPlan = revisionPreview.variant.plan
        guard revisedPlan.sourceSnapshotID == artifact.id,
              artifact.originatingInstanceID == instance.id,
              artifact.originatingRuntimeEpoch == instance.runtimeEpoch else {
            throw ProbeFailure.message("revision lost its immutable capture/runtime binding")
        }
        let encodedRevisionPlan = try Data(contentsOf: revisionPreview.planURL)
        guard try JSONDecoder().decode(ProcessingPlan.self, from: encodedRevisionPlan) == revisedPlan else {
            throw ProbeFailure.message("revision plan artifact was not the exact materialized graph")
        }

        let lockedProductionNodes = lockedPlan.nodes.filter {
            $0.type != .compressor && $0.type != .loudnessMatch
        }
        for lockedNode in lockedProductionNodes {
            guard revisedPlan.nodes.first(where: { $0.id == lockedNode.id }) == lockedNode else {
                throw ProbeFailure.message(
                    "compression revision changed unrelated node \(lockedNode.id) (\(lockedNode.type.rawValue))"
                )
            }
        }
        guard revisedPlan.nodes.filter({ $0.type == .parametricEQ }).allSatisfy(\.locked) else {
            throw ProbeFailure.message("compression revision changed or removed a locked EQ")
        }
        let compressorsBefore = lockedPlan.nodes.filter { $0.type == .compressor && !$0.locked }
        guard !compressorsBefore.isEmpty else {
            throw ProbeFailure.message("balanced vocal plan did not contain an unlocked compressor")
        }
        for before in compressorsBefore {
            guard let after = revisedPlan.nodes.first(where: { $0.id == before.id }),
                  after.type == .compressor,
                  after.parameters[.ratio, default: 1] < before.parameters[.ratio, default: 1],
                  after.parameters[.thresholdDB, default: -60]
                    > before.parameters[.thresholdDB, default: -60] else {
                throw ProbeFailure.message("less-compression revision did not reduce compressor \(before.id)")
            }
        }

        // The persisted revision JSON, audition WAV, and in-memory graph must
        // describe the same deterministic render of the immutable capture.
        let capturedAudio = try await client.loadCapturedAudio(artifact)
        let revisionAudio = try WAVFile.read(url: revisionAudioURL)
        var exactRevisionAudio = capturedAudio
        var exactRevisionGraph = try CompiledGraph(
            plan: revisedPlan,
            sampleRate: capturedAudio.sampleRate,
            channelCount: capturedAudio.channelCount
        )
        try exactRevisionGraph.process(&exactRevisionAudio)
        try assertAudioEqual(
            revisionAudio,
            exactRevisionAudio,
            tolerance: 0,
            label: "materialized conversational revision"
        )

        let revisionCommitID = try await client.commit(
            plan: revisedPlan,
            artifact: artifact,
            originatingInstance: instance,
            expectedCurrentPlan: lockedPlan
        )
        _ = try await waitForTerminal(
            client: client,
            requestID: revisionCommitID,
            instanceID: instanceID
        )
        guard unit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("capture-bound revision commit did not become the active graph")
        }
        try renderAndAssert(revisedPlan, label: "revised AU commit")

        // Undo and redo are explicit graph transactions. Undo is allowed to
        // remove the user lock because it restores a named prior snapshot; redo
        // then compares against that exact Balanced graph before reapplying the
        // capture-bound materialized revision.
        let undoID = try await client.commit(
            plan: balanced.plan,
            artifact: artifact,
            originatingInstance: instance,
            expectedCurrentPlan: revisedPlan,
            allowLockedNodeRemoval: true
        )
        _ = try await waitForTerminal(client: client, requestID: undoID, instanceID: instanceID)
        guard unit.currentProcessingPlan == balanced.plan else {
            throw ProbeFailure.message("undo did not restore the exact Balanced graph")
        }
        try renderAndAssert(balanced.plan, label: "Balanced undo")

        let redoID = try await client.commit(
            plan: revisedPlan,
            artifact: artifact,
            originatingInstance: instance,
            expectedCurrentPlan: balanced.plan
        )
        _ = try await waitForTerminal(client: client, requestID: redoID, instanceID: instanceID)
        guard unit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("redo did not restore the exact conversational revision")
        }
        try renderAndAssert(revisedPlan, label: "conversational revision redo")

        // Persist the graph committed through companion IPC, restore it into a fresh AU,
        // allocate host resources, and prove the new callback renders the same plan.
        let committedState = unit.fullState
        let reloadedUnit = try AssistantAudioUnit(componentDescription: description)
        reloadedUnit.detachSessionBridgeForTesting()
        reloadedUnit.fullState = committedState
        guard reloadedUnit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("IPC-committed graph did not survive AU fullState serialization")
        }
        try reloadedUnit.inputBusses[0].setFormat(format)
        try reloadedUnit.outputBusses[0].setFormat(format)
        try reloadedUnit.allocateRenderResources()
        defer { reloadedUnit.deallocateRenderResources() }
        guard let reloadedOutput = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let reloadedChannel = reloadedOutput.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate reloaded session probe buffer")
        }
        reloadedOutput.frameLength = frameCount
        var reloadedFlags: AudioUnitRenderActionFlags = []
        var reloadedTimestamp = timestamp
        let reloadedStatus = reloadedUnit.internalRenderBlock(
            &reloadedFlags,
            &reloadedTimestamp,
            frameCount,
            0,
            reloadedOutput.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard reloadedStatus == noErr else {
            throw ProbeFailure.message("reloaded committed graph returned \(reloadedStatus)")
        }
        var reloadedExpected = AudioBuffer(channels: [source], sampleRate: sampleRate)
        var reloadedGraph = try CompiledGraph(
            plan: revisedPlan,
            sampleRate: sampleRate,
            channelCount: 1
        )
        try reloadedGraph.process(&reloadedExpected)
        for frame in source.indices where abs(reloadedChannel[frame] - reloadedExpected.channels[0][frame]) > 1e-6 {
            throw ProbeFailure.message("reloaded IPC graph diverged at frame \(frame)")
        }

        // Global bypass is an independent, non-destructive state: the plug-in
        // must retain the committed graph while returning the exact pulled input.
        let bypassID = try await client.setGlobalBypass(enabled: true, instance: instance)
        _ = try await waitForTerminal(client: client, requestID: bypassID, instanceID: instanceID)
        guard unit.globalBypassEnabled, unit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("global bypass replaced or lost the committed graph")
        }
        try renderAndAssertDry(label: "global bypass")

        // A newly created companion client represents a companion relaunch.
        // Its only source of truth is the plug-in heartbeat, which must expose
        // the persisted bypass state and the still-committed graph.
        let reconnectedClient = CompanionSessionClient(exchange: exchange)
        let bypassedInstance = try await waitForBypassState(
            client: reconnectedClient,
            id: instanceID,
            enabled: true
        )
        guard bypassedInstance.currentPlan == revisedPlan else {
            throw ProbeFailure.message("bypassed heartbeat did not retain the committed graph")
        }

        // Saving while bypassed and restoring into a fresh AU must remain dry
        // until bypass is explicitly disabled, without discarding the graph.
        let bypassedState = unit.fullState
        let bypassedReloadedUnit = try AssistantAudioUnit(componentDescription: description)
        bypassedReloadedUnit.detachSessionBridgeForTesting()
        bypassedReloadedUnit.fullState = bypassedState
        guard bypassedReloadedUnit.globalBypassEnabled,
              bypassedReloadedUnit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("bypassed AU state did not survive fullState serialization")
        }
        try bypassedReloadedUnit.inputBusses[0].setFormat(format)
        try bypassedReloadedUnit.outputBusses[0].setFormat(format)
        try bypassedReloadedUnit.allocateRenderResources()
        defer { bypassedReloadedUnit.deallocateRenderResources() }
        guard let bypassedReloadedOutput = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ), let bypassedReloadedChannel = bypassedReloadedOutput.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate bypassed reload probe buffer")
        }
        bypassedReloadedOutput.frameLength = frameCount
        var bypassedReloadedFlags: AudioUnitRenderActionFlags = []
        var bypassedReloadedTimestamp = timestamp
        let bypassedReloadedStatus = bypassedReloadedUnit.internalRenderBlock(
            &bypassedReloadedFlags,
            &bypassedReloadedTimestamp,
            frameCount,
            0,
            bypassedReloadedOutput.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard bypassedReloadedStatus == noErr else {
            throw ProbeFailure.message("bypassed reloaded AU returned \(bypassedReloadedStatus)")
        }
        for frame in source.indices where bypassedReloadedChannel[frame] != source[frame] {
            throw ProbeFailure.message("bypassed reloaded AU was not bit-exact at frame \(frame)")
        }

        bypassedReloadedUnit.setGlobalBypass(false)
        bypassedReloadedTimestamp.mSampleTime += Float64(frameCount)
        let directlyRestoredStatus = bypassedReloadedUnit.internalRenderBlock(
            &bypassedReloadedFlags,
            &bypassedReloadedTimestamp,
            frameCount,
            0,
            bypassedReloadedOutput.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard directlyRestoredStatus == noErr,
              !bypassedReloadedUnit.globalBypassEnabled,
              bypassedReloadedUnit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("direct bypass restore did not reactivate the retained graph")
        }
        var directlyRestoredExpected = AudioBuffer(channels: [source], sampleRate: sampleRate)
        var directlyRestoredGraph = try CompiledGraph(
            plan: revisedPlan,
            sampleRate: sampleRate,
            channelCount: 1
        )
        try directlyRestoredGraph.process(&directlyRestoredExpected)
        for frame in source.indices where abs(
            bypassedReloadedChannel[frame] - directlyRestoredExpected.channels[0][frame]
        ) > 1e-6 {
            throw ProbeFailure.message("direct bypass restore diverged at frame \(frame)")
        }

        let restoreID = try await reconnectedClient.setGlobalBypass(
            enabled: false,
            instance: bypassedInstance
        )
        _ = try await waitForTerminal(
            client: reconnectedClient,
            requestID: restoreID,
            instanceID: instanceID
        )
        guard !unit.globalBypassEnabled, unit.currentProcessingPlan == revisedPlan else {
            throw ProbeFailure.message("IPC bypass restore did not retain the committed graph")
        }
        try renderAndAssert(revisedPlan, label: "IPC bypass restore")

        let dryPlan = ProcessingPlan(
            sourceSnapshotID: artifact.id,
            scope: revisedPlan.scope,
            goals: [],
            nodes: []
        )
        let revertID = try await reconnectedClient.commit(
            plan: dryPlan,
            artifact: artifact,
            originatingInstance: bypassedInstance,
            expectedCurrentPlan: revisedPlan,
            allowLockedNodeRemoval: true
        )
        _ = try await waitForTerminal(client: reconnectedClient, requestID: revertID, instanceID: instanceID)
        try renderAndAssertDry(label: "explicit revert")
    }

    /// Two Audio Units share one durable exchange exactly as multiple inserts in
    /// Logic do. Every command remains bound to both the instance identifier and
    /// its runtime epoch; captures, graph publication, bypass, audio, and saved
    /// state must stay isolated when the peer instance is targeted.
    private static func exerciseTwoInstanceIsolation(
        description: AudioComponentDescription
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let unitA = try AssistantAudioUnit(componentDescription: description)
        let unitB = try AssistantAudioUnit(componentDescription: description)
        let instanceIDA = try unitA.attachSessionBridgeForTesting(directory: root)
        let instanceIDB = try unitB.attachSessionBridgeForTesting(directory: root)
        defer {
            unitA.detachSessionBridgeForTesting()
            unitB.detachSessionBridgeForTesting()
        }
        guard instanceIDA != instanceIDB else {
            throw ProbeFailure.message("two Audio Units published the same instance identifier")
        }

        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 512
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        for unit in [unitA, unitB] {
            try unit.inputBusses[0].setFormat(format)
            try unit.outputBusses[0].setFormat(format)
            try unit.allocateRenderResources()
        }
        defer {
            unitA.deallocateRenderResources()
            unitB.deallocateRenderResources()
        }

        guard let outputA = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let outputB = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelA = outputA.floatChannelData?[0],
              let channelB = outputB.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate two-instance probe buffers")
        }
        outputA.frameLength = frameCount
        outputB.frameLength = frameCount
        var sourceA = [Float](repeating: 0, count: Int(frameCount))
        var sourceB = [Float](repeating: 0, count: Int(frameCount))
        var flagsA: AudioUnitRenderActionFlags = []
        var flagsB: AudioUnitRenderActionFlags = []
        var timestampA = AudioTimeStamp(
            mSampleTime: 0,
            mHostTime: 0,
            mRateScalar: 0,
            mWordClockTime: 0,
            mSMPTETime: SMPTETime(),
            mFlags: .sampleTimeValid,
            mReserved: 0
        )
        var timestampB = timestampA
        let pullA: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            destination.update(from: sourceA, count: Int(frameCount))
            return noErr
        }
        let pullB: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            destination.update(from: sourceB, count: Int(frameCount))
            return noErr
        }
        func renderA(_ blockIndex: Int) throws {
            for frame in sourceA.indices {
                let absoluteFrame = blockIndex * Int(frameCount) + frame
                sourceA[frame] = Float(
                    0.18 * sin(2 * .pi * 173 * Double(absoluteFrame) / sampleRate)
                        + 0.035 * sin(2 * .pi * 2_200 * Double(absoluteFrame) / sampleRate)
                )
            }
            timestampA.mSampleTime = Float64(blockIndex * Int(frameCount))
            let status = unitA.internalRenderBlock(
                &flagsA,
                &timestampA,
                frameCount,
                0,
                outputA.mutableAudioBufferList,
                nil,
                pullA
            )
            guard status == noErr else {
                throw ProbeFailure.message("instance A render returned \(status)")
            }
        }
        func renderB(_ blockIndex: Int) throws {
            for frame in sourceB.indices {
                let absoluteFrame = blockIndex * Int(frameCount) + frame
                sourceB[frame] = Float(
                    0.11 * sin(2 * .pi * 521 * Double(absoluteFrame) / sampleRate + 0.3)
                        + 0.07 * sin(2 * .pi * 4_700 * Double(absoluteFrame) / sampleRate)
                )
            }
            timestampB.mSampleTime = Float64(blockIndex * Int(frameCount))
            let status = unitB.internalRenderBlock(
                &flagsB,
                &timestampB,
                frameCount,
                0,
                outputB.mutableAudioBufferList,
                nil,
                pullB
            )
            guard status == noErr else {
                throw ProbeFailure.message("instance B render returned \(status)")
            }
        }
        func assertDry(
            _ rendered: UnsafeMutablePointer<Float>,
            source: [Float],
            label: String
        ) throws {
            for frame in source.indices where rendered[frame] != source[frame] {
                throw ProbeFailure.message("\(label) was not bit-exact at frame \(frame)")
            }
        }
        func assertProcessed(
            _ rendered: UnsafeMutablePointer<Float>,
            source: [Float],
            plan: ProcessingPlan,
            label: String
        ) throws {
            var expected = AudioBuffer(channels: [source], sampleRate: sampleRate)
            var graph = try CompiledGraph(plan: plan, sampleRate: sampleRate, channelCount: 1)
            try graph.process(&expected)
            for frame in source.indices
            where abs(rendered[frame] - expected.channels[0][frame]) > 1e-6 {
                throw ProbeFailure.message("\(label) diverged at frame \(frame)")
            }
        }

        for block in 0..<96 {
            try renderA(block)
            try renderB(block)
        }

        let exchange = try FileExchange(directory: root)
        let client = CompanionSessionClient(exchange: exchange)
        let instanceA = try await waitForInstance(client: client, id: instanceIDA)
        let instanceB = try await waitForInstance(client: client, id: instanceIDB)
        guard instanceA.runtimeEpoch != instanceB.runtimeEpoch else {
            throw ProbeFailure.message("two Audio Units published the same runtime epoch")
        }
        try assertPersistedState(
            unitB,
            expectedPlan: nil,
            expectedBypass: false,
            label: "instance B initial state"
        )

        let captureRequestA = try await client.requestRecentCapture(
            instance: instanceA,
            durationSeconds: 1
        )
        let captureRequestB = try await client.requestRecentCapture(
            instance: instanceB,
            durationSeconds: 1
        )
        let (artifactA, _) = try await waitForCapture(
            client: client,
            requestID: captureRequestA,
            instanceID: instanceIDA
        )
        let (artifactB, _) = try await waitForCapture(
            client: client,
            requestID: captureRequestB,
            instanceID: instanceIDB
        )
        guard artifactA.id != artifactB.id,
              artifactA.sha256 != artifactB.sha256,
              artifactA.originatingInstanceID == instanceIDA,
              artifactA.originatingRuntimeEpoch == instanceA.runtimeEpoch,
              artifactB.originatingInstanceID == instanceIDB,
              artifactB.originatingRuntimeEpoch == instanceB.runtimeEpoch else {
            throw ProbeFailure.message("two captures did not retain distinct instance/runtime origins")
        }

        let scope = ProcessingScope(
            kind: .pluginInput,
            channelFormat: .mono,
            sourceType: .unknown
        )
        let planA = ProcessingPlan(
            sourceSnapshotID: artifactA.id,
            scope: scope,
            goals: [],
            nodes: [
                ProcessingNode(
                    type: .polarity,
                    rationale: "Instance-isolation graph A.",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ],
            outputConstraints: .init(loudnessMatchPreview: false)
        )
        let planB = ProcessingPlan(
            sourceSnapshotID: artifactB.id,
            scope: scope,
            goals: [],
            nodes: [
                ProcessingNode(
                    type: .inputTrim,
                    parameters: [.gainDB: -6],
                    rationale: "Instance-isolation graph B.",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ],
            outputConstraints: .init(loudnessMatchPreview: false)
        )

        // Target instance A first. B must stay dry in its live graph, callback,
        // bypass flag, and serialized project state.
        let commitA = try await client.commit(
            plan: planA,
            artifact: artifactA,
            originatingInstance: instanceA,
            expectedCurrentPlan: nil
        )
        _ = try await waitForTerminal(client: client, requestID: commitA, instanceID: instanceIDA)
        try assertPersistedState(
            unitA,
            expectedPlan: planA,
            expectedBypass: false,
            label: "instance A committed state"
        )
        try assertPersistedState(
            unitB,
            expectedPlan: nil,
            expectedBypass: false,
            label: "instance B after A commit"
        )
        try renderA(96)
        try renderB(96)
        try assertProcessed(channelA, source: sourceA, plan: planA, label: "instance A commit")
        try assertDry(channelB, source: sourceB, label: "instance B after A commit")

        let bypassA = try await client.setGlobalBypass(enabled: true, instance: instanceA)
        _ = try await waitForTerminal(client: client, requestID: bypassA, instanceID: instanceIDA)
        try assertPersistedState(
            unitA,
            expectedPlan: planA,
            expectedBypass: true,
            label: "instance A bypassed state"
        )
        try assertPersistedState(
            unitB,
            expectedPlan: nil,
            expectedBypass: false,
            label: "instance B after A bypass"
        )
        try renderA(97)
        try renderB(97)
        try assertDry(channelA, source: sourceA, label: "instance A targeted bypass")
        try assertDry(channelB, source: sourceB, label: "instance B after A bypass")

        // Now target B while A remains bypassed with graph A retained. The
        // commands, output, and persisted state must cross neither instance.
        let commitB = try await client.commit(
            plan: planB,
            artifact: artifactB,
            originatingInstance: instanceB,
            expectedCurrentPlan: nil
        )
        _ = try await waitForTerminal(client: client, requestID: commitB, instanceID: instanceIDB)
        try assertPersistedState(
            unitA,
            expectedPlan: planA,
            expectedBypass: true,
            label: "instance A after B commit"
        )
        try assertPersistedState(
            unitB,
            expectedPlan: planB,
            expectedBypass: false,
            label: "instance B committed state"
        )
        try renderA(98)
        try renderB(98)
        try assertDry(channelA, source: sourceA, label: "instance A while B committed")
        try assertProcessed(channelB, source: sourceB, plan: planB, label: "instance B commit")

        let bypassB = try await client.setGlobalBypass(enabled: true, instance: instanceB)
        _ = try await waitForTerminal(client: client, requestID: bypassB, instanceID: instanceIDB)
        try assertPersistedState(
            unitA,
            expectedPlan: planA,
            expectedBypass: true,
            label: "instance A after B bypass"
        )
        try assertPersistedState(
            unitB,
            expectedPlan: planB,
            expectedBypass: true,
            label: "instance B bypassed state"
        )
        try renderA(99)
        try renderB(99)
        try assertDry(channelA, source: sourceA, label: "instance A while B bypassed")
        try assertDry(channelB, source: sourceB, label: "instance B targeted bypass")

        let restoreB = try await client.setGlobalBypass(enabled: false, instance: instanceB)
        _ = try await waitForTerminal(client: client, requestID: restoreB, instanceID: instanceIDB)
        try assertPersistedState(
            unitA,
            expectedPlan: planA,
            expectedBypass: true,
            label: "instance A after B restore"
        )
        try assertPersistedState(
            unitB,
            expectedPlan: planB,
            expectedBypass: false,
            label: "instance B restored state"
        )
        try renderB(100)
        try assertProcessed(channelB, source: sourceB, plan: planB, label: "instance B restore")

        let restoreA = try await client.setGlobalBypass(enabled: false, instance: instanceA)
        _ = try await waitForTerminal(client: client, requestID: restoreA, instanceID: instanceIDA)
        try assertPersistedState(
            unitA,
            expectedPlan: planA,
            expectedBypass: false,
            label: "instance A restored state"
        )
        try assertPersistedState(
            unitB,
            expectedPlan: planB,
            expectedBypass: false,
            label: "instance B after A restore"
        )
        try renderA(101)
        try assertProcessed(channelA, source: sourceA, plan: planA, label: "instance A restore")
    }

    private static func assertAudioEqual(
        _ actual: DSPCore.AudioBuffer,
        _ expected: DSPCore.AudioBuffer,
        tolerance: Float,
        label: String
    ) throws {
        guard actual.sampleRate == expected.sampleRate,
              actual.channelCount == expected.channelCount,
              actual.frameCount == expected.frameCount else {
            throw ProbeFailure.message("\(label) shape did not match the deterministic render")
        }
        for channel in actual.channels.indices {
            for frame in actual.channels[channel].indices
            where abs(actual.channels[channel][frame] - expected.channels[channel][frame]) > tolerance {
                throw ProbeFailure.message(
                    "\(label) diverged at channel \(channel) frame \(frame)"
                )
            }
        }
    }

    private static func assertPersistedState(
        _ unit: AssistantAudioUnit,
        expectedPlan: ProcessingPlan?,
        expectedBypass: Bool,
        label: String
    ) throws {
        guard unit.currentProcessingPlan == expectedPlan,
              unit.globalBypassEnabled == expectedBypass else {
            throw ProbeFailure.message("\(label) live state did not match")
        }
        let state = unit.fullState
        let planKey = "com.marcboyer.logicaudioassistant.processing-plan-v1"
        let bypassKey = "com.marcboyer.logicaudioassistant.global-bypass-v1"
        guard state?[bypassKey] as? Bool == expectedBypass else {
            throw ProbeFailure.message("\(label) serialized bypass did not match")
        }
        if let expectedPlan {
            guard let planData = state?[planKey] as? Data,
                  try JSONDecoder().decode(ProcessingPlan.self, from: planData) == expectedPlan else {
                throw ProbeFailure.message("\(label) serialized graph did not match")
            }
        } else if state?[planKey] != nil {
            throw ProbeFailure.message("\(label) serialized state unexpectedly contained a graph")
        }
    }

    private static func waitForInstance(
        client: CompanionSessionClient,
        id: UUID
    ) async throws -> PluginInstanceRecord {
        for _ in 0..<60 {
            if let instance = try await client.activeInstances().instances.first(where: {
                $0.id == id && $0.sampleRate != nil && $0.channelCount != nil
            }) {
                return instance
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ProbeFailure.message("plug-in bridge did not publish an instance heartbeat")
    }

    private static func waitForBypassState(
        client: CompanionSessionClient,
        id: UUID,
        enabled: Bool
    ) async throws -> PluginInstanceRecord {
        for _ in 0..<80 {
            if let instance = try await client.activeInstances().instances.first(where: {
                $0.id == id && $0.globalBypassEnabled == enabled
            }) {
                return instance
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ProbeFailure.message("plug-in heartbeat did not publish global bypass=\(enabled)")
    }

    private static func waitForCapture(
        client: CompanionSessionClient,
        requestID: UUID,
        instanceID: UUID
    ) async throws -> (CaptureArtifact, URL) {
        for _ in 0..<80 {
            if let capture = try await client.captureReply(requestID: requestID, instanceID: instanceID) {
                return capture
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ProbeFailure.message("plug-in bridge did not publish the capture")
    }

    private static func waitForTerminal(
        client: CompanionSessionClient,
        requestID: UUID,
        instanceID: UUID
    ) async throws -> ExchangeMessage {
        for _ in 0..<80 {
            if let reply = try await client.terminalReply(requestID: requestID, instanceID: instanceID) {
                guard reply.kind == .acknowledgement else {
                    throw ProbeFailure.message(reply.text ?? "plug-in command failed")
                }
                return reply
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ProbeFailure.message("plug-in bridge did not acknowledge the command")
    }

    private static func verifyCaptureLifecycle(
        description: AudioComponentDescription
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let unit = try AssistantAudioUnit(componentDescription: description)
        let instanceID = try unit.attachSessionBridgeForTesting(directory: root)
        defer {
            if unit.renderResourcesAllocated { unit.deallocateRenderResources() }
            unit.detachSessionBridgeForTesting()
        }
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 128
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ProbeFailure.message("could not allocate capture-lifecycle buffer")
        }
        output.frameLength = frameCount
        var source = Array(repeating: Float(0.125), count: Int(frameCount))
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
            guard requestedFrames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            destination.update(from: source, count: source.count)
            return noErr
        }
        func render() throws {
            let status = unit.internalRenderBlock(
                &flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pullInput
            )
            guard status == noErr else {
                throw ProbeFailure.message("capture-lifecycle render returned \(status)")
            }
            timestamp.mSampleTime += Float64(frameCount)
        }

        try render()
        guard unit.recentCapturedAudio(maxDurationSeconds: 1)?.channels[0] == source else {
            throw ProbeFailure.message("allocated AU did not expose its current capture")
        }
        let exchange = try FileExchange(directory: root)
        let client = CompanionSessionClient(exchange: exchange)
        let allocatedInstance = try await waitForInstance(client: client, id: instanceID)

        unit.deallocateRenderResources()
        guard unit.recentCapturedAudio(maxDurationSeconds: 1) == nil else {
            throw ProbeFailure.message("deallocated AU exposed stale capture audio")
        }
        let rejectedCaptureID = try await client.requestRecentCapture(
            instance: allocatedInstance,
            durationSeconds: 1
        )
        var sawFailure = false
        for _ in 0..<80 {
            if let terminal = try await client.terminalReply(
                requestID: rejectedCaptureID,
                instanceID: instanceID
            ) {
                guard terminal.kind == .failure else {
                    throw ProbeFailure.message("deallocated capture request was acknowledged")
                }
                sawFailure = true
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard sawFailure else {
            throw ProbeFailure.message("deallocated capture request did not fail")
        }
        let staleWAVs = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .allObjects as? [URL] ?? []).filter { $0.pathExtension.lowercased() == "wav" }
        guard staleWAVs.isEmpty else {
            throw ProbeFailure.message("deallocated capture request published an audio artifact")
        }

        try unit.allocateRenderResources()
        guard unit.recentCapturedAudio(maxDurationSeconds: 1) == nil else {
            throw ProbeFailure.message("reallocated AU resurrected its previous capture")
        }
        source = (0..<Int(frameCount)).map { frame in
            Float(0.2 * sin(2 * .pi * 701 * Double(frame) / sampleRate))
        }
        try render()
        guard unit.recentCapturedAudio(maxDurationSeconds: 1)?.channels[0] == source else {
            throw ProbeFailure.message("reallocated AU capture did not contain only new playback")
        }
        let newCaptureID = try await client.requestRecentCapture(
            instance: allocatedInstance,
            durationSeconds: 1
        )
        let (newArtifact, newURL) = try await waitForCapture(
            client: client,
            requestID: newCaptureID,
            instanceID: instanceID
        )
        let captured = try WAVFile.read(url: newURL)
        guard newArtifact.frameCount == source.count,
              captured.channels[0] == source else {
            throw ProbeFailure.message("post-reallocation IPC capture contained stale samples")
        }
    }

    private static func verifyFormatContract(description: AudioComponentDescription) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        guard unit.channelCapabilities?.map(\.intValue) == [1, 1, 2, 2] else {
            throw ProbeFailure.message("AU did not advertise only mono-to-mono and stereo-to-stereo")
        }
        guard let outputGain = unit.parameterTree?.parameter(withAddress: 0),
              outputGain.minValue == -24,
              outputGain.maxValue == 0,
              outputGain.flags.contains(.flag_CanRamp) else {
            throw ProbeFailure.message("post-limiter output trim could add unvalidated gain")
        }
        guard unit.tailTime == PlanValidator.conservativeTailTimeSeconds else {
            throw ProbeFailure.message("AU did not report its static conservative IIR tail bound")
        }
        guard let fractionalFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100.5,
            channels: 1,
            interleaved: false
        ), !unit.shouldChange(to: fractionalFormat, for: unit.inputBusses[0]) else {
            throw ProbeFailure.message("AU accepted a fractional sample rate that WAV capture cannot represent")
        }

        let fractionalUnit = try AssistantAudioUnit(componentDescription: description)
        var fractionalAllocationRejected = false
        do {
            try fractionalUnit.inputBusses[0].setFormat(fractionalFormat)
            try fractionalUnit.outputBusses[0].setFormat(fractionalFormat)
            try fractionalUnit.allocateRenderResources()
        } catch {
            fractionalAllocationRejected = true
        }
        if fractionalUnit.renderResourcesAllocated { fractionalUnit.deallocateRenderResources() }
        guard fractionalAllocationRejected else {
            throw ProbeFailure.message("AU allocation did not defensively reject a fractional sample rate")
        }
    }

    /// Couples the validator's maximum aggregate feedback-delay graph to the
    /// AU's static tail declaration. The final one-second window must be below
    /// the declared -120 dB amplitude threshold after a unit impulse.
    private static func verifyMaximumFeedbackTailBound() throws {
        let sampleRate = 8_000.0
        let durationSeconds = PlanValidator.conservativeTailTimeSeconds + 1
        let frameCount = Int(durationSeconds * sampleRate)
        let delayNodes: [ProcessingNode] = [
            ProcessingNode(
                type: .delay,
                parameters: [
                    .algorithmVersion: 1, .delayTimeMS: 2_000,
                    .feedback: PlanValidator.maximumFeedback, .damping: 0,
                    .stereoCrossfeed: 0, .mix: 1,
                ],
                rationale: "Maximum legal feedback-delay tail bound.",
                confidence: 1,
                category: .creative
            ),
            ProcessingNode(
                type: .delay,
                parameters: [
                    .algorithmVersion: 1, .delayTimeMS: 1_978,
                    .feedback: PlanValidator.maximumFeedback, .damping: 0,
                    .stereoCrossfeed: 0, .mix: 1,
                ],
                rationale: "Maximum aggregate delay tail bound.",
                confidence: 1,
                category: .creative
            ),
            ProcessingNode(
                type: .modulatedDelay,
                parameters: [
                    .algorithmVersion: 1, .delayTimeMS: 1,
                    .feedback: PlanValidator.maximumFeedback, .damping: 0, .mix: 1,
                    .modulationDepthMS: 10, .modulationRateHz: 0.05,
                    .stereoPhaseDegrees: 0,
                ],
                rationale: "Maximum-feedback Vocal modulation tail bound.",
                confidence: 1,
                category: .creative
            ),
            ProcessingNode(
                type: .modulatedDelay,
                parameters: [
                    .algorithmVersion: 1, .delayTimeMS: 1,
                    .feedback: PlanValidator.maximumFeedback, .damping: 0, .mix: 1,
                    .modulationDepthMS: 10, .modulationRateHz: 5,
                    .stereoPhaseDegrees: 180,
                ],
                rationale: "Maximum aggregate Vocal modulation tail bound.",
                confidence: 1,
                category: .creative
            ),
        ]
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: ProcessingScope(
                kind: .pluginInput,
                channelFormat: .mono,
                sourceType: .vocal
            ),
            goals: [],
            nodes: delayNodes + [finalSafetyLimiter()]
        )
        try PlanValidator().validateForRealtimeActivation(plan)
        var samples = [Float](repeating: 0, count: frameCount)
        samples[0] = 1
        var audio = AudioBuffer(channels: [samples], sampleRate: sampleRate)
        var graph = try CompiledGraph(plan: plan, sampleRate: sampleRate, channelCount: 1)
        try graph.process(&audio)
        let tailStart = Int(PlanValidator.conservativeTailTimeSeconds * sampleRate)
        let tailPeak = audio.channels[0][tailStart...]
            .reduce(Float.zero) { max($0, abs($1)) }
        guard tailPeak <= Float(PlanValidator.tailSilenceAmplitude) else {
            throw ProbeFailure.message(
                "maximum feedback-delay tail peak \(tailPeak) exceeded the declared threshold"
            )
        }
    }

    private static func verifyHostBufferContracts(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        // Hosts are allowed to cache this block before negotiating the final
        // maximum frame count. The closure must consult allocation-time state.
        let earlyRenderBlock = unit.internalRenderBlock
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 2_048
        let frameCountInt = Int(frameCount)
        let byteCount = UInt32(frameCountInt * MemoryLayout<Float>.size)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        unit.maximumFramesToRender = frameCount
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }

        let source = UnsafeMutablePointer<Float>.allocate(capacity: frameCountInt)
        let hostOutput = UnsafeMutablePointer<Float>.allocate(capacity: frameCountInt)
        defer {
            source.deallocate()
            hostOutput.deallocate()
        }
        for frame in 0..<frameCountInt {
            source[frame] = Float(frame - frameCountInt / 2) / Float(frameCountInt * 2)
            hostOutput[frame] = 99
        }
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
        let replacingPull: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount else { return kAudio_ParamError }
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            guard buffers.count == 1 else { return kAudio_ParamError }
            buffers[0].mNumberChannels = 1
            buffers[0].mDataByteSize = byteCount
            buffers[0].mData = UnsafeMutableRawPointer(source)
            return noErr
        }

        let hostList = AudioBufferList.allocate(maximumBuffers: 1)
        defer { hostList.unsafeMutablePointer.deallocate() }
        hostList.unsafeMutablePointer.pointee.mNumberBuffers = 1
        hostList[0] = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: byteCount,
            mData: UnsafeMutableRawPointer(hostOutput)
        )
        var status = earlyRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            hostList.unsafeMutablePointer,
            nil,
            replacingPull
        )
        guard status == noErr else {
            throw ProbeFailure.message("cached pre-allocation render block rejected negotiated frames")
        }
        for frame in 0..<frameCountInt where hostOutput[frame] != source[frame] {
            throw ProbeFailure.message("upstream mData replacement lost the host output buffer")
        }
        guard let captured = unit.recentCapturedAudio(
            maxDurationSeconds: Double(frameCount) / sampleRate
        ), captured.frameCount == frameCountInt else {
            throw ProbeFailure.message("replacement-pointer input was not captured")
        }
        for frame in 0..<frameCountInt where captured.channels[0][frame] != source[frame] {
            throw ProbeFailure.message("capture did not use the upstream replacement pointer")
        }
        guard unit.recentCapturedAudio(maxDurationSeconds: .nan) == nil,
              unit.recentCapturedAudio(maxDurationSeconds: .infinity) == nil,
              unit.recentCapturedAudio(maxDurationSeconds: -1) == nil else {
            throw ProbeFailure.message("capture duration API accepted a nonfinite or negative bound")
        }

        let nullOutputList = AudioBufferList.allocate(maximumBuffers: 1)
        defer { nullOutputList.unsafeMutablePointer.deallocate() }
        nullOutputList.unsafeMutablePointer.pointee.mNumberBuffers = 1
        nullOutputList[0] = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: byteCount,
            mData: nil
        )
        timestamp.mSampleTime += Float64(frameCount)
        status = earlyRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            nullOutputList.unsafeMutablePointer,
            nil,
            replacingPull
        )
        guard status == noErr,
              let ownedOutput = nullOutputList[0].mData?.assumingMemoryBound(to: Float.self) else {
            throw ProbeFailure.message("AU did not supply preallocated storage for null host output")
        }
        for frame in 0..<frameCountInt where ownedOutput[frame] != source[frame] {
            throw ProbeFailure.message("null host output storage did not contain pulled audio")
        }
        let firstOwnedAddress = nullOutputList[0].mData
        timestamp.mSampleTime += Float64(frameCount)
        status = earlyRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            nullOutputList.unsafeMutablePointer,
            nil,
            replacingPull
        )
        guard status == noErr, nullOutputList[0].mData == firstOwnedAddress else {
            throw ProbeFailure.message("null-output storage was not stable across callbacks")
        }

        hostList[0].mDataByteSize = byteCount - UInt32(MemoryLayout<Float>.size)
        timestamp.mSampleTime += Float64(frameCount)
        status = earlyRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            hostList.unsafeMutablePointer,
            nil,
            replacingPull
        )
        guard status == kAudio_ParamError else {
            throw ProbeFailure.message("AU accepted an undersized host output buffer")
        }

        hostList[0].mDataByteSize = byteCount
        let undersizedPull: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount else { return kAudio_ParamError }
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            buffers[0].mNumberChannels = 1
            buffers[0].mDataByteSize = byteCount - UInt32(MemoryLayout<Float>.size)
            buffers[0].mData = UnsafeMutableRawPointer(source)
            return noErr
        }
        timestamp.mSampleTime += Float64(frameCount)
        status = earlyRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            hostList.unsafeMutablePointer,
            nil,
            undersizedPull
        )
        guard status == kAudio_ParamError else {
            throw ProbeFailure.message("AU accepted an undersized pulled input buffer")
        }
    }

    private static func rejectMismatchedBusAllocations(
        description: AudioComponentDescription
    ) throws {
        for (inputChannels, outputChannels) in [(1, 2), (2, 1)] {
            let unit = try AssistantAudioUnit(componentDescription: description)
            guard let inputFormat = AVAudioFormat(
                standardFormatWithSampleRate: 48_000,
                channels: AVAudioChannelCount(inputChannels)
            ), let outputFormat = AVAudioFormat(
                standardFormatWithSampleRate: 48_000,
                channels: AVAudioChannelCount(outputChannels)
            ) else {
                throw ProbeFailure.message("could not create mismatched AU bus formats")
            }
            try unit.inputBusses[0].setFormat(inputFormat)
            try unit.outputBusses[0].setFormat(outputFormat)

            var allocationRejected = false
            do {
                try unit.allocateRenderResources()
            } catch {
                allocationRejected = true
            }
            if unit.renderResourcesAllocated {
                unit.deallocateRenderResources()
            }
            guard allocationRejected, !unit.renderResourcesAllocated else {
                throw ProbeFailure.message(
                    "AU allocated unsupported \(inputChannels)-input/\(outputChannels)-output resources"
                )
            }
        }
    }

    private static func verifyAtomicCommitGuards(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        defer {
            if unit.renderResourcesAllocated { unit.deallocateRenderResources() }
        }
        let format48 = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        try unit.inputBusses[0].setFormat(format48)
        try unit.outputBusses[0].setFormat(format48)
        try unit.allocateRenderResources()

        let snapshotID = UUID()
        func plan(_ node: ProcessingNode) -> ProcessingPlan {
            ProcessingPlan(
                sourceSnapshotID: snapshotID,
                scope: .init(kind: .pluginInput, channelFormat: .mono, sourceType: .vocal),
                goals: [],
                nodes: [node, finalSafetyLimiter()]
            )
        }
        let planA = plan(.init(
            type: .inputTrim,
            parameters: [.gainDB: -1],
            rationale: "atomic CAS A",
            confidence: 1,
            category: .corrective
        ))
        let planB = plan(.init(
            type: .polarity,
            rationale: "atomic CAS B",
            confidence: 1,
            category: .corrective
        ))
        let planC = plan(.init(
            type: .inputTrim,
            parameters: [.gainDB: -6],
            rationale: "atomic CAS C",
            confidence: 1,
            category: .corrective
        ))
        let planD = plan(.init(
            type: .inputTrim,
            parameters: [.gainDB: -9],
            rationale: "atomic format control",
            confidence: 1,
            category: .corrective
        ))

        try unit.applyProcessingPlan(planA)
        // Simulate a host fullState/graph change after the companion observed A
        // but before its commit transaction reaches the AU.
        try unit.applyProcessingPlan(planB)
        let stateKey = "com.marcboyer.logicaudioassistant.processing-plan-v1"
        func serializedPlan() throws -> ProcessingPlan? {
            guard let data = unit.fullState?[stateKey] as? Data else { return nil }
            return try JSONDecoder().decode(ProcessingPlan.self, from: data)
        }
        let stateBeforeStaleCommit = try serializedPlan()
        var staleRejected = false
        do {
            try unit.commitProcessingPlanForTesting(
                planC,
                expectedCurrentPlan: planA,
                capturedSnapshotID: snapshotID,
                capturedSampleRate: 48_000,
                capturedChannelCount: 1
            )
        } catch { staleRejected = true }
        let stateAfterStaleCommit = try serializedPlan()
        guard staleRejected,
              unit.currentProcessingPlan == planB,
              stateAfterStaleCommit == stateBeforeStaleCommit else {
            throw ProbeFailure.message(
                "atomic graph CAS overwrote a newer host state "
                    + "rejected=\(staleRejected) planPreserved=\(unit.currentProcessingPlan == planB) "
                    + "statePreserved=\(stateAfterStaleCommit == stateBeforeStaleCommit)"
            )
        }
        try assertUnitRender(
            unit,
            plan: planB,
            format: format48,
            label: "stale-CAS rejection"
        )

        let stateBeforeSnapshotMismatch = try serializedPlan()
        var snapshotMismatchRejected = false
        do {
            try unit.commitProcessingPlanForTesting(
                planC,
                expectedCurrentPlan: planB,
                capturedSnapshotID: UUID(),
                capturedSampleRate: 48_000,
                capturedChannelCount: 1
            )
        } catch { snapshotMismatchRejected = true }
        guard snapshotMismatchRejected,
              unit.currentProcessingPlan == planB,
              try serializedPlan() == stateBeforeSnapshotMismatch else {
            throw ProbeFailure.message("captured snapshot mismatch changed AU state")
        }

        try unit.commitProcessingPlanForTesting(
            planC,
            expectedCurrentPlan: planB,
            capturedSnapshotID: snapshotID,
            capturedSampleRate: 48_000,
            capturedChannelCount: 1
        )
        guard unit.currentProcessingPlan == planC else {
            throw ProbeFailure.message("same-state atomic commit control did not publish")
        }

        unit.deallocateRenderResources()
        var deallocatedRejected = false
        do {
            try unit.commitProcessingPlanForTesting(
                planD,
                expectedCurrentPlan: planC,
                capturedSnapshotID: snapshotID,
                capturedSampleRate: 48_000,
                capturedChannelCount: 1
            )
        } catch { deallocatedRejected = true }
        guard deallocatedRejected, unit.currentProcessingPlan == planC else {
            throw ProbeFailure.message("commit while deallocated changed AU state")
        }

        let format44 = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        try unit.inputBusses[0].setFormat(format44)
        try unit.outputBusses[0].setFormat(format44)
        try unit.allocateRenderResources()
        let stateBeforeFormatMismatch = try serializedPlan()
        var formatRejected = false
        do {
            try unit.commitProcessingPlanForTesting(
                planD,
                expectedCurrentPlan: planC,
                capturedSnapshotID: snapshotID,
                capturedSampleRate: 48_000,
                capturedChannelCount: 1
            )
        } catch { formatRejected = true }
        let stateAfterFormatMismatch = try serializedPlan()
        guard formatRejected,
              unit.currentProcessingPlan == planC,
              stateAfterFormatMismatch == stateBeforeFormatMismatch else {
            throw ProbeFailure.message("capture from the previous sample rate changed AU state")
        }
        try assertUnitRender(
            unit,
            plan: planC,
            format: format44,
            label: "runtime-format rejection"
        )
        try unit.commitProcessingPlanForTesting(
            planD,
            expectedCurrentPlan: planC,
            capturedSnapshotID: snapshotID,
            capturedSampleRate: 44_100,
            capturedChannelCount: 1
        )
        guard unit.currentProcessingPlan == planD else {
            throw ProbeFailure.message("same-format atomic commit control did not publish")
        }
    }

    private static func assertUnitRender(
        _ unit: AssistantAudioUnit,
        plan: ProcessingPlan,
        format: AVAudioFormat,
        label: String
    ) throws {
        let frameCount: AVAudioFrameCount = 128
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate \(label) buffer")
        }
        output.frameLength = frameCount
        let source = (0..<Int(frameCount)).map { frame in
            Float(0.21 * sin(2 * .pi * 337 * Double(frame) / format.sampleRate))
        }
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
            guard requestedFrames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            source.withUnsafeBufferPointer {
                destination.update(from: $0.baseAddress!, count: source.count)
            }
            return noErr
        }
        let status = unit.internalRenderBlock(
            &flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pullInput
        )
        guard status == noErr else {
            throw ProbeFailure.message("\(label) render returned \(status)")
        }
        var expected = AudioBuffer(channels: [source], sampleRate: format.sampleRate)
        var graph = try CompiledGraph(plan: plan, sampleRate: format.sampleRate, channelCount: 1)
        try graph.process(&expected)
        for frame in source.indices where abs(rendered[frame] - expected.channels[0][frame]) > 1e-6 {
            throw ProbeFailure.message("\(label) changed audio at frame \(frame)")
        }
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
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard unit.currentProcessingPlan == nil else {
            throw ProbeFailure.message("AU retained an incompatible stereo plan on a mono host layout")
        }
    }

    private static func verifyEmergencyBypassAfterPublicationExhaustion(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        let statefulPlan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: .init(kind: .pluginInput, channelFormat: .mono, sourceType: .unknown),
            goals: [],
            nodes: [
                .init(
                    type: .inputTrim,
                    parameters: [.gainDB: -12],
                    rationale: "Stateful gain-smoothing publication probe",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ]
        )
        let alternatePlan = ProcessingPlan(
            sourceSnapshotID: statefulPlan.sourceSnapshotID,
            scope: statefulPlan.scope,
            goals: [],
            nodes: [
                .init(
                    type: .polarity,
                    rationale: "Inactive-graph publication probe",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ]
        )
        let frameCount: AVAudioFrameCount = 64
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate publication-exhaustion output")
        }
        output.frameLength = frameCount
        let source = (0..<Int(frameCount)).map { frame in
            Float(0.35 * sin(2 * .pi * 440 * Double(frame) / format.sampleRate))
        }
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
            guard requestedFrames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            source.withUnsafeBufferPointer {
                destination.update(from: $0.baseAddress!, count: Int(frameCount))
            }
            return noErr
        }
        func renderNextBlock() throws {
            let status = unit.internalRenderBlock(
                &flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pullInput
            )
            guard status == noErr else {
                throw ProbeFailure.message("publication-exhaustion render returned \(status)")
            }
            timestamp.mSampleTime += Float64(frameCount)
        }

        // Mutate graph A's gain smoother, then switch to and render graph B so
        // A is inactive with observable retained state before the pool fills.
        try unit.applyProcessingPlan(statefulPlan)
        for _ in 0..<16 { try renderNextBlock() }
        try unit.applyProcessingPlan(alternatePlan)
        try renderNextBlock()

        var exhausted = false
        for _ in 0..<256 {
            var uniquePlan = alternatePlan
            uniquePlan.requestID = UUID()
            do {
                try unit.applyProcessingPlan(uniquePlan)
            }
            catch {
                exhausted = true
                break
            }
        }
        guard exhausted else {
            throw ProbeFailure.message("graph-publication budget did not enforce its bound")
        }
        try unit.applyProcessingPlan(statefulPlan)
        guard unit.currentProcessingPlan == statefulPlan else {
            throw ProbeFailure.message("publication-exhausted kernel could not reselect a retained snapshot")
        }
        var freshExpected = AudioBuffer(channels: [source], sampleRate: format.sampleRate)
        var freshGraph = try CompiledGraph(
            plan: statefulPlan,
            sampleRate: format.sampleRate,
            channelCount: 1
        )
        try freshGraph.process(&freshExpected)
        try renderNextBlock()
        for frame in source.indices where abs(
            rendered[frame] - freshExpected.channels[0][frame]
        ) > 1e-6 {
            throw ProbeFailure.message(
                "publication-cap reselect retained stale DSP state at frame \(frame)"
            )
        }

        try unit.applyProcessingPlan(nil)
        guard unit.currentProcessingPlan == nil else {
            throw ProbeFailure.message("emergency bypass did not clear serialized processing state")
        }
        try renderNextBlock()
        for frame in source.indices where rendered[frame] != source[frame] {
            throw ProbeFailure.message("publication-exhausted bypass was not bit-exact dry")
        }
    }

    /// Measures the complete host callback path: pull, input metering, bounded capture,
    /// representative graph DSP, sanitization, and output trim. The percentile assertion
    /// avoids treating a process-scheduler outlier as DSP work while still enforcing the
    /// actual 128-frame deadline.
    private static func measureRealtimePerformance(
        description: AudioComponentDescription
    ) throws {
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 128
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        let excludedPerformanceNodes = Set(
            ProcessInfo.processInfo.environment["TRACKSMITH_HOST_PROBE_EXCLUDE_NODES", default: ""]
                .split(separator: ",")
                .map(String.init)
        )
        let representativeNodes: [ProcessingNode] = [
            .init(type: .inputTrim, parameters: [.gainDB: -1], rationale: "performance", confidence: 1, category: .corrective),
            .init(type: .highPass, parameters: [.frequencyHz: 70, .q: 0.707], rationale: "performance", confidence: 1, category: .corrective),
            .init(type: .parametricEQ, parameters: [.frequencyHz: 2_800, .q: 1.1, .gainDB: 2], rationale: "performance", confidence: 1, category: .corrective),
            .init(type: .compressor, parameters: [.thresholdDB: -20, .ratio: 3, .attackMS: 12, .releaseMS: 100, .makeupGainDB: 1, .kneeDB: 5, .mix: 0.8], rationale: "performance", confidence: 1, category: .corrective),
            .init(type: .expander, parameters: [.algorithmVersion: 1, .thresholdDB: -52, .ratio: 2, .attackMS: 4, .releaseMS: 100, .holdMS: 30, .hysteresisDB: 4, .rangeDB: 12, .mix: 0.35], rationale: "performance", confidence: 1, category: .corrective),
            .init(type: .deEsser, parameters: [.frequencyHz: 6_000, .thresholdDB: -28, .ratio: 3, .attackMS: 1, .releaseMS: 60, .mix: 0.7], rationale: "performance", confidence: 1, category: .corrective),
            .init(type: .saturation, parameters: [.driveDB: 2, .mix: 0.2], rationale: "performance", confidence: 1, category: .creative),
            .init(type: .stereoWidth, parameters: [.width: 1.1, .mix: 0.6], rationale: "performance", confidence: 1, category: .creative),
            .init(type: .delay, parameters: [.algorithmVersion: 1, .delayTimeMS: 90, .feedback: 0.2, .damping: 0.35, .stereoCrossfeed: 0.15, .mix: 0.1], rationale: "performance", confidence: 1, category: .creative),
            .init(type: .modulatedDelay, parameters: [.algorithmVersion: 1, .delayTimeMS: 14, .feedback: 0.12, .damping: 0.4, .mix: 0.18, .modulationDepthMS: 4, .modulationRateHz: 0.6, .stereoPhaseDegrees: 90], rationale: "performance", confidence: 1, category: .creative),
            .init(type: .reverb, parameters: [.algorithmVersion: 1, .preDelayMS: 12, .decayTimeSeconds: 0.7, .roomSize: 0.4, .damping: 0.45, .diffusion: 0.6, .mix: 0.1], rationale: "performance", confidence: 1, category: .creative),
            .init(type: .limiter, parameters: [.ceilingDB: -1, .releaseMS: 80, .lookaheadMS: 0], rationale: "performance", confidence: 1, category: .loudness),
        ].filter { !excludedPerformanceNodes.contains($0.type.rawValue) }
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: .init(kind: .pluginInput, channelFormat: .stereo, sourceType: .vocalBus),
            goals: [],
            nodes: representativeNodes
        )
        try unit.setProcessingPlan(plan)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard unit.latency == 0 else {
            throw ProbeFailure.message("representative zero-lookahead graph reported nonzero latency")
        }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ProbeFailure.message("could not allocate performance buffer")
        }
        output.frameLength = frameCount
        let sourceFrameCount = Int(frameCount)
        var sourceLeft: [Float] = []
        var sourceRight: [Float] = []
        sourceLeft.reserveCapacity(sourceFrameCount)
        sourceRight.reserveCapacity(sourceFrameCount)
        for frame in 0..<sourceFrameCount {
            let sampleIndex = Double(frame)
            let leftPhase = 2 * Double.pi * 220 * sampleIndex / sampleRate
            let rightPhase = 2 * Double.pi * 330 * sampleIndex / sampleRate + 0.1
            sourceLeft.append(Float(0.2 * sin(leftPhase)))
            sourceRight.append(Float(0.18 * sin(rightPhase)))
        }
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
            guard buffers.count == 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else {
                return kAudio_ParamError
            }
            sourceLeft.withUnsafeBufferPointer { left.update(from: $0.baseAddress!, count: Int(frameCount)) }
            sourceRight.withUnsafeBufferPointer { right.update(from: $0.baseAddress!, count: Int(frameCount)) }
            return noErr
        }
        let realtimeRenderBlock = unit.internalRenderBlock
        // AVAudioBuffer lazily allocates its mutable ABL wrapper. A real host passes
        // the ABL into the callback, so materialize this host-side object before the
        // render-thread heap probe is armed.
        let outputBufferList = output.mutableAudioBufferList
        let heapProbe = RealtimeHeapProbe()
        let heapProbeRequired = ProcessInfo.processInfo.environment["LAA_REQUIRE_RT_HEAP_PROBE"] == "1"
        if heapProbeRequired, heapProbe == nil {
            throw ProbeFailure.message("required real-time heap interposer was not loaded")
        }
        func render() throws {
            heapProbe?.begin()
            let status = realtimeRenderBlock(
                &flags, &timestamp, frameCount, 0, outputBufferList, nil, pullInput
            )
            let heapOperations = heapProbe?.end() ?? 0
            guard heapOperations == 0 else {
                throw ProbeFailure.message(
                    "render callback performed \(heapOperations) malloc/free operations; \(heapProbe?.failureDetail() ?? "probe unavailable")"
                )
            }
            guard status == noErr else {
                throw ProbeFailure.message("performance render returned \(status)")
            }
            timestamp.mSampleTime += Float64(frameCount)
        }
        for _ in 0..<256 { try render() }
        let iterations = 4_000
        var durations = [UInt64]()
        durations.reserveCapacity(iterations)
        var total: UInt64 = 0
        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            try render()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            durations.append(elapsed)
            total &+= elapsed
        }
        durations.sort()
        let percentile99 = durations[min(durations.count - 1, Int(Double(durations.count) * 0.99))]
        let maximum = durations.last ?? 0
        let mean = Double(total) / Double(iterations)
        let deadline = Double(frameCount) / sampleRate * 1_000_000_000
        print(String(
            format: "PERF callback frames=128 rate=48000 mean=%.1f us p99=%.1f us max=%.1f us deadline=%.1f us",
            mean / 1_000,
            Double(percentile99) / 1_000,
            Double(maximum) / 1_000,
            deadline / 1_000
        ))
        if heapProbe != nil {
            print("RT_HEAP callback iterations=\(iterations) operations=0")
        }
        guard Double(percentile99) < deadline else {
            throw ProbeFailure.message("representative callback p99 exceeded its 128-frame deadline")
        }

        let resetGroup = DispatchGroup()
        resetGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<1_000 { unit.reset() }
            resetGroup.leave()
        }
        for _ in 0..<4_000 { try render() }
        resetGroup.wait()
        guard let left = output.floatChannelData?[0],
              let right = output.floatChannelData?[1] else {
            throw ProbeFailure.message("reset stress lost output channels")
        }
        for frame in 0..<Int(frameCount)
        where !left[frame].isFinite || !right[frame].isFinite {
            throw ProbeFailure.message("concurrent reset stress produced nonfinite output")
        }
    }

    private static func verifyGlobalBypassNonfiniteSanitization(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 32
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: .init(kind: .pluginInput, channelFormat: .mono, sourceType: .unknown),
            goals: [],
            nodes: [
                .init(
                    type: .polarity,
                    rationale: "Prove global bypass skips an audible graph.",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ]
        )
        try unit.setProcessingPlan(plan)
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        unit.shouldBypassEffect = true
        guard unit.shouldBypassEffect, unit.globalBypassEnabled else {
            throw ProbeFailure.message("native AU shouldBypassEffect did not enter global bypass")
        }

        var source = (0..<Int(frameCount)).map { frame in
            Float(frame - 16) / 64
        }
        source[3] = .nan
        source[5] = 1e10
        source[11] = .infinity
        source[23] = -.infinity
        let expected = source.map { $0.isFinite ? $0 : 0 }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate nonfinite-bypass probe buffer")
        }
        output.frameLength = frameCount
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
        let pull: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            source.withUnsafeBufferPointer {
                destination.update(from: $0.baseAddress!, count: Int(frameCount))
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
            pull
        )
        guard status == noErr else {
            throw ProbeFailure.message("nonfinite bypass render returned \(status)")
        }
        for frame in expected.indices {
            guard rendered[frame].isFinite, rendered[frame] == expected[frame] else {
                throw ProbeFailure.message(
                    "global bypass did not sanitize/preserve input at frame \(frame)"
                )
            }
        }
        guard let captured = unit.recentCapturedAudio(
            maxDurationSeconds: Double(frameCount) / sampleRate
        ), captured.channelCount == 1, captured.frameCount == Int(frameCount) else {
            throw ProbeFailure.message("nonfinite bypass capture had the wrong shape")
        }
        for frame in expected.indices {
            let sample = captured.channels[0][frame]
            guard sample.isFinite, sample == expected[frame] else {
                throw ProbeFailure.message(
                    "capture retained nonfinite or changed finite input at frame \(frame)"
                )
            }
        }
        guard unit.inputPeakDBFS == 48 else {
            throw ProbeFailure.message("extreme finite input escaped the heartbeat meter bound")
        }
        unit.shouldBypassEffect = false
        guard !unit.shouldBypassEffect, !unit.globalBypassEnabled else {
            throw ProbeFailure.message("native AU shouldBypassEffect did not leave global bypass")
        }
    }

    private static func verifyOutputSilenceFlagContract(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 64
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: .init(kind: .pluginInput, channelFormat: .mono, sourceType: .unknown),
            goals: [],
            nodes: [
                .init(
                    type: .highPass,
                    parameters: [.frequencyHz: 120, .q: 0.707],
                    rationale: "produce a bounded IIR tail",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ]
        )
        try unit.setProcessingPlan(plan)
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate silence-flag probe buffer")
        }
        output.frameLength = frameCount
        var renderIndex = 0
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
        let pull: AURenderPullInputBlock = { pullFlags, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            if renderIndex == 0 {
                destination.initialize(repeating: 0, count: Int(frameCount))
                destination[0] = 1
            } else {
                // A conforming upstream may assert silence without touching its
                // buffer. The AU must not reuse stale scratch input.
                pullFlags.pointee.insert(.unitRenderAction_OutputIsSilence)
            }
            return noErr
        }
        let block = unit.internalRenderBlock
        var status = block(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pull)
        guard status == noErr else { throw ProbeFailure.message("impulse render failed") }
        renderIndex = 1
        timestamp.mSampleTime += Float64(frameCount)
        flags = []
        status = block(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pull)
        guard status == noErr else { throw ProbeFailure.message("tail render failed") }
        guard (0..<Int(frameCount)).contains(where: { abs(rendered[$0]) > 1e-8 }) else {
            throw ProbeFailure.message("IIR probe did not produce an output tail")
        }
        guard !flags.contains(.unitRenderAction_OutputIsSilence) else {
            throw ProbeFailure.message("AU forwarded a false output-is-silence flag over an audible tail")
        }
    }

    private static func verifyScheduledParameterAutomation(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 128
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate scheduled-automation probe buffer")
        }
        output.frameLength = frameCount
        let source = [Float](repeating: 0.5, count: Int(frameCount))
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
        let pull: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            source.withUnsafeBufferPointer {
                destination.update(from: $0.baseAddress!, count: Int(frameCount))
            }
            return noErr
        }
        let render = unit.renderBlock
        let schedule = unit.scheduleParameterBlock
        schedule(32, 0, 0, -12)
        var status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr else { throw ProbeFailure.message("scheduled immediate render failed") }
        let minusTwelveGain = Float(pow(10, -12.0 / 20.0))
        guard abs(rendered[31] - 0.5) < 1e-6,
              abs(rendered[32] - 0.5 * minusTwelveGain) < 1e-5 else {
            throw ProbeFailure.message("scheduled immediate event was not sample-accurate")
        }

        schedule(128, 192, 0, 0)
        timestamp.mSampleTime = 128
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr else { throw ProbeFailure.message("scheduled ramp start render failed") }
        guard abs(rendered[0] - 0.5 * minusTwelveGain) < 1e-5 else {
            throw ProbeFailure.message("scheduled ramp did not begin from the current value")
        }

        timestamp.mSampleTime = 256
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr else { throw ProbeFailure.message("scheduled ramp continuation render failed") }
        guard abs(rendered[64] - 0.5) < 1e-5,
              abs(rendered[127] - 0.5) < 1e-5 else {
            throw ProbeFailure.message("scheduled ramp did not persist across blocks and hold its target")
        }

        // A scheduled event is delivered only in its first block. Bypass must
        // advance the hidden timeline so restoring the insert cannot resurrect
        // a stale ramp value.
        schedule(384, 384, 0, -24)
        timestamp.mSampleTime = 384
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr, rendered[127] < rendered[0] else {
            throw ProbeFailure.message("scheduled bypass-ramp setup did not descend")
        }
        unit.shouldBypassEffect = true
        for blockStart in [512.0, 640.0] {
            timestamp.mSampleTime = blockStart
            flags = []
            status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
            guard status == noErr else {
                throw ProbeFailure.message("scheduled ramp failed while globally bypassed")
            }
            for frame in 0..<Int(frameCount) where rendered[frame] != 0.5 {
                throw ProbeFailure.message("global bypass was not bit-exact during a hidden ramp")
            }
        }
        unit.shouldBypassEffect = false
        timestamp.mSampleTime = 768
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        let minusTwentyFourGain = Float(pow(10, -24.0 / 20.0))
        guard status == noErr,
              abs(rendered[0] - 0.5 * minusTwentyFourGain) < 1e-5,
              abs(rendered[127] - 0.5 * minusTwentyFourGain) < 1e-5 else {
            throw ProbeFailure.message("bypass did not preserve the scheduled automation timeline")
        }

        // By contrast, a host reset represents a timeline discontinuity and
        // must discard an in-flight scheduled ramp.
        schedule(896, 384, 0, 0)
        timestamp.mSampleTime = 896
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr, rendered[127] > rendered[0] else {
            throw ProbeFailure.message("host-reset ramp setup did not ascend")
        }
        unit.reset()
        timestamp.mSampleTime = 1_024
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr,
              abs(rendered[0] - 0.5) < 1e-6,
              abs(rendered[127] - 0.5) < 1e-6 else {
            throw ProbeFailure.message("host reset retained stale scheduled automation")
        }

        // A control write away and back to the ramp's original baseline can be
        // value-identical at the next callback. Its write generation must still
        // cancel scheduled ownership, retaining continuity through the de-zipper.
        schedule(1_152, 384, 0, -24)
        timestamp.mSampleTime = 1_152
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        let beforeCancellation = rendered[127]
        guard status == noErr, beforeCancellation < rendered[0] else {
            throw ProbeFailure.message("external-cancellation ramp setup did not descend")
        }
        let outputGain = unit.parameterTree?.parameter(withAddress: 0)
        outputGain?.value = -1
        outputGain?.value = 0
        timestamp.mSampleTime = 1_280
        flags = []
        status = render(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, pull)
        guard status == noErr,
              abs(rendered[0] - beforeCancellation) < 0.01,
              rendered[127] > rendered[0] else {
            throw ProbeFailure.message(
                "value-identical external write did not smoothly cancel scheduled automation"
            )
        }
    }

    private static func verifyConcurrentPublicationWithScheduledEvents(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 16_384
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let scope = ProcessingScope(
            kind: .pluginInput,
            channelFormat: .mono,
            sourceType: .unknown
        )
        let dryPlan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: scope,
            goals: [],
            nodes: []
        )
        let invertedPlan = ProcessingPlan(
            sourceSnapshotID: dryPlan.sourceSnapshotID,
            scope: scope,
            goals: [],
            nodes: [
                .init(
                    type: .polarity,
                    rationale: "prove one graph is retained for a complete callback",
                    confidence: 1,
                    category: .corrective
                ),
                finalSafetyLimiter(),
            ]
        )
        try unit.setProcessingPlan(dryPlan)
        unit.maximumFramesToRender = frameCount
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate concurrent-publication buffer")
        }
        output.frameLength = frameCount
        let source = [Float](repeating: 0.25, count: Int(frameCount))
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
        var publicationStart: DispatchSemaphore?
        let pull: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            source.withUnsafeBufferPointer {
                destination.update(from: $0.baseAddress!, count: Int(frameCount))
            }
            publicationStart?.signal()
            return noErr
        }
        let render = unit.renderBlock
        let schedule = unit.scheduleParameterBlock
        let failureBox = ConcurrentProbeFailureBox()
        var sawPositiveBlock = false
        var sawNegativeBlock = false
        for iteration in 0..<32 {
            let start = DispatchSemaphore(value: 0)
            publicationStart = start
            let completion = DispatchGroup()
            let nextPlan = iteration.isMultiple(of: 2) ? invertedPlan : dryPlan
            completion.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                start.wait()
                do { try unit.applyProcessingPlan(nextPlan) }
                catch { failureBox.record(error) }
                completion.leave()
            }
            let blockStart = AUEventSampleTime(timestamp.mSampleTime)
            let midpoint = blockStart + AUEventSampleTime(frameCount / 2)
            schedule(midpoint, 0, 0, iteration.isMultiple(of: 2) ? -6 : 0)
            flags = []
            let status = render(
                &flags,
                &timestamp,
                frameCount,
                0,
                output.mutableAudioBufferList,
                pull
            )
            completion.wait()
            if let message = failureBox.message {
                throw ProbeFailure.message("concurrent graph publication failed: \(message)")
            }
            guard status == noErr else {
                throw ProbeFailure.message("concurrent-publication render returned \(status)")
            }
            let firstSign = rendered[0] > 0
            for frame in 1..<Int(frameCount) where (rendered[frame] > 0) != firstSign {
                throw ProbeFailure.message(
                    "graph changed inside a callback at iteration \(iteration), frame \(frame)"
                )
            }
            sawPositiveBlock = sawPositiveBlock || firstSign
            sawNegativeBlock = sawNegativeBlock || !firstSign
            timestamp.mSampleTime += Float64(frameCount)
        }
        publicationStart = nil
        guard sawPositiveBlock, sawNegativeBlock else {
            throw ProbeFailure.message("concurrent publication did not exercise both graph polarities")
        }
    }

    private static func verifyOutputGainAutomationSmoothing(
        description: AudioComponentDescription
    ) throws {
        let unit = try AssistantAudioUnit(componentDescription: description)
        unit.detachSessionBridgeForTesting()
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 128
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let rendered = output.floatChannelData?[0] else {
            throw ProbeFailure.message("could not allocate automation-smoothing buffer")
        }
        output.frameLength = frameCount
        let source = [Float](repeating: 0.5, count: Int(frameCount))
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
        let pull: AURenderPullInputBlock = { _, _, frames, _, outputData in
            guard frames == frameCount,
                  let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                    .mData?.assumingMemoryBound(to: Float.self) else { return kAudio_ParamError }
            source.withUnsafeBufferPointer {
                destination.update(from: $0.baseAddress!, count: Int(frameCount))
            }
            return noErr
        }
        let block = unit.internalRenderBlock
        func render() throws {
            let status = block(&flags, &timestamp, frameCount, 0, output.mutableAudioBufferList, nil, pull)
            guard status == noErr else { throw ProbeFailure.message("automation render returned \(status)") }
            timestamp.mSampleTime += Float64(frameCount)
        }
        try render()
        guard let outputGain = unit.parameterTree?.parameter(withAddress: 0) else {
            throw ProbeFailure.message("output-gain parameter disappeared")
        }
        for hostileValue: AUValue in [12, .nan, .infinity, -.infinity] {
            outputGain.value = hostileValue
            try render()
            for frame in 0..<Int(frameCount) {
                guard rendered[frame].isFinite, abs(rendered[frame]) <= 0.500_001 else {
                    throw ProbeFailure.message(
                        "hostile output-gain write added gain or emitted nonfinite audio"
                    )
                }
            }
        }
        outputGain.value = 0
        try render()
        outputGain.value = -24
        try render()
        let firstDown = rendered[0]
        let lastDown = rendered[Int(frameCount) - 1]
        guard firstDown > 0.45, lastDown < firstDown - 0.05 else {
            throw ProbeFailure.message("output automation stepped instead of smoothing downward")
        }
        for _ in 0..<100 { try render() }
        let settled = Float(0.5 * pow(10, -24.0 / 20.0))
        guard abs(rendered[Int(frameCount) - 1] - settled) < 1e-4 else {
            throw ProbeFailure.message("output automation did not settle at its bounded target")
        }
        outputGain.value = 0
        try render()
        guard rendered[0] < 0.05,
              rendered[Int(frameCount) - 1] > rendered[0] + 0.05 else {
            throw ProbeFailure.message("output automation stepped instead of smoothing upward")
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
                ),
                finalSafetyLimiter(),
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
        try restoredUnit.inputBusses[0].setFormat(format)
        try restoredUnit.outputBusses[0].setFormat(format)
        restoredUnit.maximumFramesToRender = max(frameCount, 1_024)
        restoredUnit.parameterTree?.parameter(withAddress: 0)?.value = -6
        try restoredUnit.allocateRenderResources()
        defer { restoredUnit.deallocateRenderResources() }
        guard restoredUnit.latency == 0 else {
            throw ProbeFailure.message("AU reported nonzero latency for its zero-lookahead graph")
        }

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
        let status = restoredUnit.internalRenderBlock(
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
                guard abs(outputChannels[channel][frame] - expected) < 1e-5 else {
                    throw ProbeFailure.message("render mismatch at \(sampleRate) Hz channel \(channel) frame \(frame)")
                }
            }
        }

        restoredUnit.fullState = nil
        let dryStatus = restoredUnit.internalRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            output.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard dryStatus == noErr, restoredUnit.currentProcessingPlan == nil else {
            throw ProbeFailure.message("live empty fullState did not activate the dry graph")
        }
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frameCount) {
                let expected = source[channel][frame] * expectedGain
                guard abs(outputChannels[channel][frame] - expected) < 1e-6 else {
                    throw ProbeFailure.message("live dry-state render mismatch at channel \(channel) frame \(frame)")
                }
            }
        }

        restoredUnit.fullState = state
        let restoredStatus = restoredUnit.internalRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            output.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard restoredStatus == noErr, restoredUnit.currentProcessingPlan == plan else {
            throw ProbeFailure.message("live fullState did not republish the restored graph")
        }
        let restoredGainDB = restoredUnit.parameterTree?.parameter(withAddress: 0)?.value ?? 0
        let restoredGain = Float(pow(10, Double(restoredGainDB) / 20))
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frameCount) {
                let dryMagnitude = abs(source[channel][frame])
                guard outputChannels[channel][frame].isFinite,
                      dryMagnitude < 1e-7 ||
                        (outputChannels[channel][frame] * source[channel][frame] <= 0 &&
                         abs(outputChannels[channel][frame]) <= dryMagnitude * 1.000_001) else {
                    throw ProbeFailure.message(
                        "live restored-state transition was unsafe at channel \(channel) frame \(frame)"
                    )
                }
            }
        }
        // Superclass state restored output gain from -6 dB to 0 dB while live.
        // The graph must switch at the block boundary, while the post-graph
        // control intentionally de-zippers instead of clicking to the target.
        let settlingRenders = max(
            1,
            Int(ceil(sampleRate * 0.15 / Double(frameCount)))
        )
        for _ in 0..<settlingRenders {
            timestamp.mSampleTime += Float64(frameCount)
            let settlingStatus = restoredUnit.internalRenderBlock(
                &flags,
                &timestamp,
                frameCount,
                0,
                output.mutableAudioBufferList,
                nil,
                pullInput
            )
            guard settlingStatus == noErr else {
                throw ProbeFailure.message("live restored-state settling render failed")
            }
        }
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frameCount) {
                let expected = -source[channel][frame] * restoredGain
                guard abs(outputChannels[channel][frame] - expected) < 1e-5 else {
                    throw ProbeFailure.message(
                        "live restored-state did not settle at channel \(channel) frame \(frame)"
                    )
                }
            }
        }

        guard let captured = restoredUnit.recentCapturedAudio(
            maxDurationSeconds: Double(frameCount) / sampleRate
        ),
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

        let dryPlan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: plan.scope,
            goals: [],
            nodes: []
        )
        try restoredUnit.applyProcessingPlan(dryPlan)
        timestamp.mSampleTime += Float64(frameCount)
        let publishedStatus = restoredUnit.internalRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            output.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard publishedStatus == noErr else {
            throw ProbeFailure.message("render after live graph publication returned \(publishedStatus)")
        }
        guard restoredUnit.currentProcessingPlan == dryPlan else {
            throw ProbeFailure.message("live graph publication did not update serialized state")
        }
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frameCount) {
                let expected = source[channel][frame] * restoredGain
                guard abs(outputChannels[channel][frame] - expected) < 1e-5 else {
                    throw ProbeFailure.message(
                        "live graph did not activate at the next block: rate=\(sampleRate) " +
                        "channel=\(channel) frame=\(frame) actual=\(outputChannels[channel][frame]) " +
                        "expected=\(expected) parameterDB=\(restoredGainDB)"
                    )
                }
            }
        }

        var corruptState = state ?? [:]
        corruptState["com.marcboyer.logicaudioassistant.processing-plan-v1"] = Data([0xFF, 0x00])
        corruptState["com.marcboyer.logicaudioassistant.global-bypass-v1"] = true
        restoredUnit.fullState = corruptState
        guard restoredUnit.currentProcessingPlan == nil else {
            throw ProbeFailure.message("corrupt AU fullState did not select the dry recovery state")
        }
        guard !restoredUnit.globalBypassEnabled else {
            throw ProbeFailure.message("corrupt AU fullState left global bypass latched")
        }
        guard restoredUnit.fullState?["com.marcboyer.logicaudioassistant.processing-plan-v1"] == nil else {
            throw ProbeFailure.message("corrupt custom state survived dry recovery serialization")
        }
        guard restoredUnit.fullState?["com.marcboyer.logicaudioassistant.global-bypass-v1"] as? Bool == false else {
            throw ProbeFailure.message("corrupt bypass state survived dry recovery serialization")
        }
        timestamp.mSampleTime += Float64(frameCount)
        let recoveredStatus = restoredUnit.internalRenderBlock(
            &flags,
            &timestamp,
            frameCount,
            0,
            output.mutableAudioBufferList,
            nil,
            pullInput
        )
        guard recoveredStatus == noErr else {
            throw ProbeFailure.message("corrupt-state dry recovery render returned \(recoveredStatus)")
        }
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frameCount) {
                let expected = source[channel][frame] * restoredGain
                guard abs(outputChannels[channel][frame] - expected) < 1e-6 else {
                    throw ProbeFailure.message("corrupt-state recovery was not dry at channel \(channel) frame \(frame)")
                }
            }
        }
    }

    /// Host-edge regression for the only new Vocal v1 render processor. This
    /// is independently authored TrackSmith coverage informed by the audit's
    /// validator/host-scenario lesson; it does not import pluginval, JUCE,
    /// iPlug2, chowdsp_utils, or any third-party implementation.
    private static func verifyVocalModulatedDelayHostLifecycle(
        description: AudioComponentDescription
    ) throws {
        let sampleRate = 48_000.0
        let frameCount: AVAudioFrameCount = 257
        let blockCount = 12
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let plan = ProcessingPlan(
            sourceSnapshotID: UUID(),
            scope: ProcessingScope(
                kind: .pluginInput,
                channelFormat: .mono,
                sourceType: .vocal
            ),
            goals: [],
            nodes: [
                ProcessingNode(
                    type: .modulatedDelay,
                    parameters: [
                        .algorithmVersion: 1,
                        .delayTimeMS: 14,
                        .feedback: 0.18,
                        .damping: 0.42,
                        .mix: 0.22,
                        .modulationDepthMS: 4,
                        .modulationRateHz: 0.63,
                        .stereoPhaseDegrees: 90,
                    ],
                    rationale: "Exercise the bounded Vocal movement path through AU lifecycle transitions.",
                    confidence: 1,
                    category: .creative
                ),
                finalSafetyLimiter(),
            ]
        )

        func configuredUnit(restoring state: [String: Any]? = nil) throws -> AssistantAudioUnit {
            let unit = try AssistantAudioUnit(componentDescription: description)
            unit.detachSessionBridgeForTesting()
            unit.maximumFramesToRender = frameCount
            if let state {
                unit.fullState = state
            } else {
                try unit.setProcessingPlan(plan)
            }
            guard unit.currentProcessingPlan == plan else {
                throw ProbeFailure.message("Vocal modulation plan did not stage or restore exactly")
            }
            try unit.inputBusses[0].setFormat(format)
            try unit.outputBusses[0].setFormat(format)
            try unit.allocateRenderResources()
            return unit
        }

        func renderImpulseSequence(
            _ unit: AssistantAudioUnit,
            expectDry: Bool = false
        ) throws -> [Float] {
            guard let output = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            ), let rendered = output.floatChannelData?[0] else {
                throw ProbeFailure.message("could not allocate Vocal lifecycle output")
            }
            output.frameLength = frameCount
            var source = [Float](repeating: 0, count: Int(frameCount))
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
            let pull: AURenderPullInputBlock = { _, _, frames, _, outputData in
                guard frames == frameCount,
                      let destination = UnsafeMutableAudioBufferListPointer(outputData)[0]
                        .mData?.assumingMemoryBound(to: Float.self) else {
                    return kAudio_ParamError
                }
                source.withUnsafeBufferPointer {
                    destination.update(from: $0.baseAddress!, count: Int(frameCount))
                }
                return noErr
            }
            let renderBlock = unit.internalRenderBlock
            var result: [Float] = []
            result.reserveCapacity(Int(frameCount) * blockCount)
            for blockIndex in 0..<blockCount {
                source.withUnsafeMutableBufferPointer { samples in
                    samples.initialize(repeating: 0)
                }
                if blockIndex == 0 { source[0] = 0.4 }
                let status = renderBlock(
                    &flags,
                    &timestamp,
                    frameCount,
                    0,
                    output.mutableAudioBufferList,
                    nil,
                    pull
                )
                guard status == noErr else {
                    throw ProbeFailure.message("Vocal lifecycle render returned \(status)")
                }
                for frame in 0..<Int(frameCount) {
                    let value = rendered[frame]
                    guard value.isFinite, abs(value) <= 1.000_001 else {
                        throw ProbeFailure.message("Vocal lifecycle render emitted unsafe audio")
                    }
                    if expectDry {
                        let expected: Float = blockIndex == 0 && frame == 0 ? 0.4 : 0
                        guard value == expected else {
                            throw ProbeFailure.message("Vocal global bypass was not bit-exact dry")
                        }
                    }
                    result.append(value)
                }
                timestamp.mSampleTime += Float64(frameCount)
            }
            return result
        }

        let unit = try configuredUnit()
        defer { if unit.renderResourcesAllocated { unit.deallocateRenderResources() } }
        let serializedState = unit.fullState

        unit.reset()
        let baseline = try renderImpulseSequence(unit)
        guard baseline.dropFirst().contains(where: { abs($0) > 1e-7 }) else {
            throw ProbeFailure.message("Vocal modulation plan produced no bounded tail")
        }

        unit.reset()
        let resetReplay = try renderImpulseSequence(unit)
        guard resetReplay == baseline else {
            throw ProbeFailure.message("Vocal modulation reset changed deterministic replay")
        }

        unit.setGlobalBypass(true)
        _ = try renderImpulseSequence(unit, expectDry: true)
        unit.setGlobalBypass(false)
        let bypassRestore = try renderImpulseSequence(unit)
        guard bypassRestore == baseline,
              unit.currentProcessingPlan == plan,
              !unit.globalBypassEnabled else {
            throw ProbeFailure.message("Vocal modulation bypass/restore lost exact graph state")
        }

        unit.deallocateRenderResources()
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        let reallocated = try renderImpulseSequence(unit)
        guard reallocated == baseline else {
            throw ProbeFailure.message("Vocal modulation deallocate/reallocate changed replay")
        }

        let restored = try configuredUnit(restoring: serializedState)
        defer { restored.deallocateRenderResources() }
        let restoredReplay = try renderImpulseSequence(restored)
        guard restoredReplay == baseline,
              restored.currentProcessingPlan == plan,
              restored.tailTime == PlanValidator.conservativeTailTimeSeconds else {
            throw ProbeFailure.message("Vocal modulation fullState restore or tail contract failed")
        }
    }

    private static func fourCC(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }

    private static func finalSafetyLimiter() -> ProcessingNode {
        ProcessingNode(
            type: .limiter,
            parameters: [.ceilingDB: -1, .releaseMS: 80, .lookaheadMS: 0],
            rationale: "Final real-time safety stage.",
            confidence: 1,
            category: .loudness
        )
    }
}
