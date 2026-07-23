import DSPCore
import Foundation
import PlanSchema
import SharedIPC

/// Non-real-time service for the durable App Group mailbox. It is owned by the AU,
/// not its view controller, so capture and commits work while the compact UI is closed.
final class PluginSessionBridge: @unchecked Sendable {
    struct Status: Sendable {
        var sampleRate: Double?
        var channelCount: Int?
        var inputPeakDBFS: Double?
        var currentPlan: ProcessingPlan?
        var globalBypassEnabled = false
    }

    let instanceID = UUID()
    let runtimeEpoch = UUID()

    private let exchange: FileExchange
    private let queue = DispatchQueue(label: "com.marcboyer.logicaudioassistant.plugin-session", qos: .utility)
    private let timer: DispatchSourceTimer
    private let captureProvider: @Sendable (Double) -> AudioBuffer?
    private let planApplier: @Sendable (
        ProcessingPlan,
        ProcessingPlan?,
        Bool,
        UUID,
        Double,
        Int
    ) throws -> Void
    private let bypassApplier: @Sendable (Bool) throws -> Void
    private let statusProvider: @Sendable () -> Status
    private var processedMessageIDs: Set<UUID> = []
    private var lastHeartbeat = Date.distantPast
    private var lastMailboxMaintenance = Date.distantPast
    private var lastAppliedCommandID: UUID?
    private var lastAppliedPlanRequestID: UUID?
    private var lastProcessedCommandSequence: UInt64?
    /// Replies are retained on the bridge's serial utility queue until the
    /// mailbox accepts them. Commands are still marked consumed, preventing a
    /// graph or capture side effect from being repeated after a transient IPC
    /// write failure. Plan/bypass outcomes are additionally durable in the
    /// heartbeat for crash-time reconciliation.
    private var pendingTerminalResponses: [UUID: ExchangeMessage] = [:]

    static func makeIfEntitled(
        captureProvider: @escaping @Sendable (Double) -> AudioBuffer?,
        planApplier: @escaping @Sendable (
            ProcessingPlan,
            ProcessingPlan?,
            Bool,
            UUID,
            Double,
            Int
        ) throws -> Void,
        bypassApplier: @escaping @Sendable (Bool) throws -> Void,
        statusProvider: @escaping @Sendable () -> Status
    ) -> PluginSessionBridge? {
        guard let exchange = try? FileExchange(appGroup: .default) else { return nil }
        return PluginSessionBridge(
            exchange: exchange,
            captureProvider: captureProvider,
            planApplier: planApplier,
            bypassApplier: bypassApplier,
            statusProvider: statusProvider
        )
    }

    init(
        exchange: FileExchange,
        captureProvider: @escaping @Sendable (Double) -> AudioBuffer?,
        planApplier: @escaping @Sendable (
            ProcessingPlan,
            ProcessingPlan?,
            Bool,
            UUID,
            Double,
            Int
        ) throws -> Void,
        bypassApplier: @escaping @Sendable (Bool) throws -> Void,
        statusProvider: @escaping @Sendable () -> Status
    ) {
        self.exchange = exchange
        self.captureProvider = captureProvider
        self.planApplier = planApplier
        self.bypassApplier = bypassApplier
        self.statusProvider = statusProvider
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(250), leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.pollOnce() }
        timer.resume()
    }

    deinit {
        timer.setEventHandler {}
        timer.cancel()
    }

    /// Exposed internally for deterministic integration tests without sleeping.
    func pollOnce() {
        let now = Date()
        if now.timeIntervalSince(lastMailboxMaintenance) >= 60 {
            lastMailboxMaintenance = now
            _ = try? exchange.performMailboxMaintenance(now: now)
        }
        flushPendingTerminalResponses()
        publishHeartbeatIfNeeded()
        guard let scan = try? exchange.scan(instanceID: instanceID, sender: .companion) else { return }
        // Retain deduplication only for commands that still exist. FileExchange
        // quotas therefore provide a hard upper bound without LRU-evicting a
        // command that could otherwise execute twice.
        processedMessageIDs.formIntersection(Set(scan.messages.map(\.id)))
        let orderedCommands = scan.messages.sorted {
            let lhs = $0.commandSequence ?? UInt64.max
            let rhs = $1.commandSequence ?? UInt64.max
            if lhs != rhs { return lhs < rhs }
            return $0.id.uuidString < $1.id.uuidString
        }
        for message in orderedCommands where !processedMessageIDs.contains(message.id) {
            guard message.targetRuntimeEpoch == runtimeEpoch else {
                sendFailure(correlationID: message.id, error: PluginSessionBridgeError.staleRuntime)
                processedMessageIDs.insert(message.id)
                continue
            }
            guard let commandSequence = message.commandSequence else {
                sendFailure(correlationID: message.id, error: PluginSessionBridgeError.missingCommandSequence)
                processedMessageIDs.insert(message.id)
                continue
            }
            if let lastProcessedCommandSequence, commandSequence <= lastProcessedCommandSequence {
                sendFailure(correlationID: message.id, error: PluginSessionBridgeError.staleCommandSequence)
                processedMessageIDs.insert(message.id)
                continue
            }
            guard message.expiresAt.map({ $0 >= Date() }) ?? false else {
                lastProcessedCommandSequence = commandSequence
                sendFailure(correlationID: message.id, error: PluginSessionBridgeError.expiredCommand)
                publishHeartbeatIfNeeded(force: true)
                processedMessageIDs.insert(message.id)
                continue
            }
            // Record consumption before invoking a state-changing handler. Its
            // forced heartbeat (and the one below for capture/failure paths)
            // then gives a restarted companion the next safe sequence instead
            // of inviting it to reuse this command number.
            lastProcessedCommandSequence = commandSequence
            switch message.kind {
            case .captureRecentRequest:
                handleCapture(message)
                processedMessageIDs.insert(message.id)
            case .planCommitRequest:
                handlePlanCommit(message)
                processedMessageIDs.insert(message.id)
            case .globalBypassRequest:
                handleGlobalBypass(message)
                processedMessageIDs.insert(message.id)
            default:
                sendFailure(correlationID: message.id, error: PluginSessionBridgeError.unsupportedCommand)
                processedMessageIDs.insert(message.id)
            }
            publishHeartbeatIfNeeded(force: true)
        }
    }

    private func publishHeartbeatIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastHeartbeat) >= 1 else { return }
        lastHeartbeat = now
        let status = statusProvider()
        let record = PluginInstanceRecord(
            id: instanceID,
            runtimeEpoch: runtimeEpoch,
            updatedAt: now,
            pluginVersion: "1.0.0",
            contextName: nil,
            sampleRate: status.sampleRate,
            channelCount: status.channelCount,
            inputPeakDBFS: status.inputPeakDBFS,
            currentPlan: status.currentPlan,
            globalBypassEnabled: status.globalBypassEnabled,
            lastAppliedCommandID: lastAppliedCommandID,
            lastAppliedPlanRequestID: lastAppliedPlanRequestID,
            lastProcessedCommandSequence: lastProcessedCommandSequence
        )
        try? exchange.publishInstance(record)
    }

    private func handleCapture(_ message: ExchangeMessage) {
        do {
            guard let request = message.captureRequest,
                  let audio = captureProvider(request.maxDurationSeconds),
                  audio.frameCount > 0 else {
                throw PluginSessionBridgeError.noCapturedAudio
            }
            let reservation = try exchange.reserveWAVArtifact(instanceID: instanceID)
            defer { try? FileManager.default.removeItem(at: reservation.temporaryURL) }
            try WAVFile.writeFloat32(audio, url: reservation.temporaryURL)
            let artifact = try exchange.publishArtifact(
                reservation,
                sampleRate: audio.sampleRate,
                channelCount: audio.channelCount,
                frameCount: audio.frameCount,
                runtimeEpoch: runtimeEpoch
            )
            queueTerminalResponse(ExchangeMessage(
                kind: .captureReady,
                instanceID: instanceID,
                targetRuntimeEpoch: runtimeEpoch,
                sender: .plugin,
                correlationID: message.id,
                captureArtifact: artifact
            ))
        } catch {
            sendFailure(correlationID: message.id, error: error)
        }
    }

    private func handlePlanCommit(_ message: ExchangeMessage) {
        let plan: ProcessingPlan
        let expectedCurrentPlan: ProcessingPlan?
        let allowLockedNodeRemoval: Bool
        let capturedSnapshotID: UUID
        let capturedSampleRate: Double
        let capturedChannelCount: Int
        do {
            guard let candidate = message.plan else { throw PluginSessionBridgeError.missingPlan }
            guard let artifact = message.captureArtifact else {
                throw PluginSessionBridgeError.missingCaptureArtifact
            }
            guard let expected = message.expectedCurrentPlanState else {
                throw PluginSessionBridgeError.missingExpectedCurrentPlan
            }
            guard artifact.originatingInstanceID == instanceID,
                  artifact.originatingRuntimeEpoch == runtimeEpoch,
                  candidate.sourceSnapshotID == artifact.id else {
                throw PluginSessionBridgeError.captureBindingMismatch
            }
            let artifactURL = try exchange.resolveArtifact(artifact)
            let captured = try WAVFile.read(url: artifactURL)
            guard captured.sampleRate == artifact.sampleRate,
                  captured.channelCount == artifact.channelCount,
                  captured.frameCount == artifact.frameCount else {
                throw PluginSessionBridgeError.captureMetadataMismatch
            }
            // This is only a preliminary structural check. The AU repeats
            // snapshot, lock, runtime-format, and graph validation together
            // with publication under one lifecycle lock below.
            try PlanValidator().validateForRealtimeActivation(
                candidate,
                currentSnapshotID: artifact.id
            )
            plan = candidate
            expectedCurrentPlan = expected.plan
            allowLockedNodeRemoval = message.allowLockedNodeRemoval
            capturedSnapshotID = artifact.id
            capturedSampleRate = artifact.sampleRate
            capturedChannelCount = artifact.channelCount
        } catch {
            sendFailure(correlationID: message.id, error: error)
            return
        }

        do {
            try planApplier(
                plan,
                expectedCurrentPlan,
                allowLockedNodeRemoval,
                capturedSnapshotID,
                capturedSampleRate,
                capturedChannelCount
            )
        } catch {
            sendFailure(correlationID: message.id, error: error)
            return
        }

        // Applying and acknowledging are separate transactions. Record the
        // durable result first so a missing acknowledgement is reconcilable
        // from the next heartbeat and can never be mislabeled as rejection.
        lastAppliedCommandID = message.id
        lastAppliedPlanRequestID = plan.requestID
        publishHeartbeatIfNeeded(force: true)
        queueTerminalResponse(ExchangeMessage(
                kind: .acknowledgement,
                instanceID: instanceID,
                targetRuntimeEpoch: runtimeEpoch,
                sender: .plugin,
                correlationID: message.id,
                text: "Validated graph published for the next audio block."
            ))
    }

    private func handleGlobalBypass(_ message: ExchangeMessage) {
        let request: GlobalBypassRequest
        do {
            guard let candidate = message.globalBypassRequest else {
                throw PluginSessionBridgeError.missingBypassRequest
            }
            request = candidate
            try bypassApplier(request.enabled)
        } catch {
            sendFailure(correlationID: message.id, error: error)
            return
        }

        lastAppliedCommandID = message.id
        lastAppliedPlanRequestID = nil
        publishHeartbeatIfNeeded(force: true)
        queueTerminalResponse(ExchangeMessage(
                kind: .acknowledgement,
                instanceID: instanceID,
                targetRuntimeEpoch: runtimeEpoch,
                sender: .plugin,
                correlationID: message.id,
                text: request.enabled
                    ? "Global bypass enabled; the committed graph remains loaded."
                    : "Global bypass disabled; the committed graph was restored."
            ))
    }

    private func sendFailure(correlationID: UUID, error: Error) {
        let description = String(describing: error)
        queueTerminalResponse(ExchangeMessage(
            kind: .failure,
            instanceID: instanceID,
            targetRuntimeEpoch: runtimeEpoch,
            sender: .plugin,
            correlationID: correlationID,
            text: String(description.prefix(4_096))
        ))
    }

    private func queueTerminalResponse(_ message: ExchangeMessage) {
        guard let correlationID = message.correlationID else { return }
        pendingTerminalResponses[correlationID] = message
        flushPendingTerminalResponses()
    }

    private func flushPendingTerminalResponses() {
        for correlationID in pendingTerminalResponses.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let message = pendingTerminalResponses[correlationID] else { continue }
            if (try? exchange.send(message)) != nil {
                pendingTerminalResponses.removeValue(forKey: correlationID)
            }
        }
    }
}

private enum PluginSessionBridgeError: Error, CustomStringConvertible {
    case noCapturedAudio
    case missingPlan
    case missingCaptureArtifact
    case missingExpectedCurrentPlan
    case missingBypassRequest
    case captureBindingMismatch
    case captureMetadataMismatch
    case staleRuntime
    case expiredCommand
    case missingCommandSequence
    case staleCommandSequence
    case unsupportedCommand

    var description: String {
        switch self {
        case .noCapturedAudio: "No captured plug-in input is available yet. Play audio through the insert first."
        case .missingPlan: "The commit request did not contain a processing plan."
        case .missingCaptureArtifact: "The commit request was not bound to an immutable capture artifact."
        case .missingExpectedCurrentPlan: "The commit request omitted its expected current graph state."
        case .missingBypassRequest: "The global bypass command did not contain a typed bypass state."
        case .captureBindingMismatch: "The commit capture does not belong to this Audio Unit runtime or source snapshot."
        case .captureMetadataMismatch: "The commit capture WAV no longer matches its immutable descriptor."
        case .staleRuntime: "The command targets a stale Audio Unit runtime epoch."
        case .expiredCommand: "The command expired before the Audio Unit could safely process it."
        case .missingCommandSequence: "The command did not include a monotonic sequence."
        case .staleCommandSequence: "The command sequence is older than this Audio Unit runtime's processed state."
        case .unsupportedCommand: "The Audio Unit does not support this companion command."
        }
    }
}
