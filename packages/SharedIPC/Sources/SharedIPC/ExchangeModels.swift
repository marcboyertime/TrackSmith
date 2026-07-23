import Foundation
import PlanSchema

public enum ExchangePeerRole: String, Codable, Sendable {
    case plugin
    case companion
    case probe
}

public enum ExchangeMessageKind: String, Codable, Hashable, Sendable {
    case pluginHeartbeat
    case companionRequest
    case captureRecentRequest
    case captureReady
    case planProposal
    case planCommitRequest
    case globalBypassRequest
    case acknowledgement
    case failure
}

public struct CaptureRequest: Codable, Equatable, Sendable {
    public var maxDurationSeconds: Double

    public init(maxDurationSeconds: Double = 15) {
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public struct GlobalBypassRequest: Codable, Equatable, Sendable {
    public var enabled: Bool

    public init(enabled: Bool) { self.enabled = enabled }
}

public struct CaptureArtifact: Codable, Equatable, Sendable {
    public var id: UUID
    public var relativePath: String
    public var sha256: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int
    public var createdAt: Date
    /// The AU instance that produced the immutable capture. Optional decoding
    /// keeps old capture history readable, but current commit requests require
    /// both origin fields and fail closed when either is absent.
    public var originatingInstanceID: UUID?
    public var originatingRuntimeEpoch: UUID?

    public init(
        id: UUID,
        relativePath: String,
        sha256: String,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int,
        createdAt: Date = Date(),
        originatingInstanceID: UUID? = nil,
        originatingRuntimeEpoch: UUID? = nil
    ) {
        self.id = id
        self.relativePath = relativePath
        self.sha256 = sha256
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.createdAt = createdAt.exchangeRounded
        self.originatingInstanceID = originatingInstanceID
        self.originatingRuntimeEpoch = originatingRuntimeEpoch
    }
}

/// A present value with `plan == nil` means "the AU must still be dry". This
/// wrapper deliberately distinguishes that state from an older message that
/// omitted the compare-and-swap precondition entirely.
public struct ExpectedCurrentPlanState: Codable, Equatable, Sendable {
    public var plan: ProcessingPlan?

    public init(plan: ProcessingPlan?) { self.plan = plan }
}

public struct ExchangeMessage: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = "1.1"

    public var schemaVersion: String
    public var id: UUID
    public var kind: ExchangeMessageKind
    /// The plug-in instance addressed by the message, including plug-in-originated replies.
    public var instanceID: UUID
    public var targetRuntimeEpoch: UUID?
    public var sender: ExchangePeerRole
    public var timestamp: Date
    public var expiresAt: Date?
    /// Monotonic within an Audio Unit runtime. Every companion command carries
    /// this value so the plug-in can resolve same-millisecond commands in the
    /// user's publication order rather than by a random UUID tie-break.
    public var commandSequence: UInt64?
    public var correlationID: UUID?
    public var text: String?
    public var captureRequest: CaptureRequest?
    public var captureArtifact: CaptureArtifact?
    public var plan: ProcessingPlan?
    public var expectedCurrentPlanState: ExpectedCurrentPlanState?
    public var globalBypassRequest: GlobalBypassRequest?
    /// Only an explicit user revert/removal command may override locked nodes.
    public var allowLockedNodeRemoval: Bool

    public init(
        schemaVersion: String = ExchangeMessage.currentSchemaVersion,
        id: UUID = UUID(),
        kind: ExchangeMessageKind,
        instanceID: UUID,
        targetRuntimeEpoch: UUID? = nil,
        sender: ExchangePeerRole = .probe,
        timestamp: Date = Date(),
        expiresAt: Date? = nil,
        commandSequence: UInt64? = nil,
        correlationID: UUID? = nil,
        text: String? = nil,
        captureRequest: CaptureRequest? = nil,
        captureArtifact: CaptureArtifact? = nil,
        plan: ProcessingPlan? = nil,
        expectedCurrentPlanState: ExpectedCurrentPlanState? = nil,
        globalBypassRequest: GlobalBypassRequest? = nil,
        allowLockedNodeRemoval: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.kind = kind
        self.instanceID = instanceID
        self.targetRuntimeEpoch = targetRuntimeEpoch
        self.sender = sender
        self.timestamp = timestamp.exchangeRounded
        self.expiresAt = expiresAt?.exchangeRounded
        self.commandSequence = commandSequence
        self.correlationID = correlationID
        self.text = text
        self.captureRequest = captureRequest
        self.captureArtifact = captureArtifact
        self.plan = plan
        self.expectedCurrentPlanState = expectedCurrentPlanState
        self.globalBypassRequest = globalBypassRequest
        self.allowLockedNodeRemoval = allowLockedNodeRemoval
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ExchangeError.unsupportedSchema(schemaVersion)
        }
        if let text, text.lengthOfBytes(using: .utf8) > 16_384 {
            throw ExchangeError.messageTooLarge
        }
        if let plan { try PlanValidator().validate(plan) }
        if let expectedPlan = expectedCurrentPlanState?.plan {
            try PlanValidator().validate(expectedPlan)
        }
        if let request = captureRequest,
           !request.maxDurationSeconds.isFinite || !(0.25...30).contains(request.maxDurationSeconds) {
            throw ExchangeError.invalidCaptureDuration
        }
        if let artifact = captureArtifact { try artifact.validate() }
        let commandKinds: Set<ExchangeMessageKind> = [
            .captureRecentRequest,
            .planCommitRequest,
            .globalBypassRequest,
        ]
        if commandKinds.contains(kind) {
            guard let expiresAt,
                  let commandSequence,
                  commandSequence > 0,
                  expiresAt >= timestamp,
                  expiresAt.timeIntervalSince(timestamp) <= 60 else {
                throw ExchangeError.invalidCommandLifetime
            }
        } else if commandSequence != nil {
            throw ExchangeError.invalidPayload(kind)
        }

        switch kind {
        case .captureRecentRequest:
            guard sender == .companion, targetRuntimeEpoch != nil,
                  captureRequest != nil, captureArtifact == nil, plan == nil,
                  expectedCurrentPlanState == nil, globalBypassRequest == nil,
                  !allowLockedNodeRemoval else {
                throw ExchangeError.invalidPayload(kind)
            }
        case .captureReady:
            guard sender == .plugin, let targetRuntimeEpoch, correlationID != nil,
                  let captureArtifact, plan == nil,
                  expectedCurrentPlanState == nil, globalBypassRequest == nil,
                  captureArtifact.originatingInstanceID == instanceID,
                  captureArtifact.originatingRuntimeEpoch == targetRuntimeEpoch,
                  !allowLockedNodeRemoval else {
                throw ExchangeError.invalidPayload(kind)
            }
        case .planCommitRequest:
            guard sender == .companion, let targetRuntimeEpoch,
                  let plan, let captureArtifact, expectedCurrentPlanState != nil,
                  captureRequest == nil, globalBypassRequest == nil,
                  captureArtifact.originatingInstanceID == instanceID,
                  captureArtifact.originatingRuntimeEpoch == targetRuntimeEpoch,
                  plan.sourceSnapshotID == captureArtifact.id else {
                throw ExchangeError.invalidPayload(kind)
            }
        case .globalBypassRequest:
            guard sender == .companion, targetRuntimeEpoch != nil,
                  globalBypassRequest != nil, captureRequest == nil,
                  captureArtifact == nil, plan == nil,
                  expectedCurrentPlanState == nil, !allowLockedNodeRemoval else {
                throw ExchangeError.invalidPayload(kind)
            }
        case .acknowledgement, .failure:
            guard sender == .plugin, targetRuntimeEpoch != nil, correlationID != nil,
                  captureRequest == nil, captureArtifact == nil, plan == nil,
                  globalBypassRequest == nil, expectedCurrentPlanState == nil,
                  !allowLockedNodeRemoval else { throw ExchangeError.invalidPayload(kind) }
        case .pluginHeartbeat:
            guard sender == .plugin, globalBypassRequest == nil,
                  expectedCurrentPlanState == nil,
                  !allowLockedNodeRemoval else { throw ExchangeError.invalidPayload(kind) }
        case .companionRequest, .planProposal:
            guard globalBypassRequest == nil,
                  expectedCurrentPlanState == nil,
                  !allowLockedNodeRemoval else { throw ExchangeError.invalidPayload(kind) }
        }
    }
}

public struct PluginInstanceRecord: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = "1.0"

    public var schemaVersion: String
    public var id: UUID
    public var runtimeEpoch: UUID
    public var updatedAt: Date
    public var pluginVersion: String
    public var contextName: String?
    public var sampleRate: Double?
    public var channelCount: Int?
    public var inputPeakDBFS: Double?
    public var currentPlan: ProcessingPlan?
    /// Optional for backward-compatible decoding of heartbeats written by an
    /// older installed Audio Unit. Current plug-ins always publish a value.
    public var globalBypassEnabled: Bool?
    /// Reconciliation evidence written after a graph was successfully applied,
    /// before acknowledgement delivery is attempted.
    public var lastAppliedCommandID: UUID?
    public var lastAppliedPlanRequestID: UUID?
    /// Last command sequence consumed by this runtime, including rejected or
    /// expired commands. It gives a reconnecting companion a safe next value.
    public var lastProcessedCommandSequence: UInt64?

    public init(
        schemaVersion: String = PluginInstanceRecord.currentSchemaVersion,
        id: UUID,
        runtimeEpoch: UUID = UUID(),
        updatedAt: Date = Date(),
        pluginVersion: String,
        contextName: String? = nil,
        sampleRate: Double? = nil,
        channelCount: Int? = nil,
        inputPeakDBFS: Double? = nil,
        currentPlan: ProcessingPlan? = nil,
        globalBypassEnabled: Bool? = nil,
        lastAppliedCommandID: UUID? = nil,
        lastAppliedPlanRequestID: UUID? = nil,
        lastProcessedCommandSequence: UInt64? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.runtimeEpoch = runtimeEpoch
        self.updatedAt = updatedAt.exchangeRounded
        self.pluginVersion = pluginVersion
        self.contextName = contextName
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.inputPeakDBFS = inputPeakDBFS
        self.currentPlan = currentPlan
        self.globalBypassEnabled = globalBypassEnabled
        self.lastAppliedCommandID = lastAppliedCommandID
        self.lastAppliedPlanRequestID = lastAppliedPlanRequestID
        self.lastProcessedCommandSequence = lastProcessedCommandSequence
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ExchangeError.unsupportedSchema(schemaVersion)
        }
        if let contextName, contextName.lengthOfBytes(using: .utf8) > 1_024 {
            throw ExchangeError.messageTooLarge
        }
        if let sampleRate, !sampleRate.isFinite || !(8_000...768_000).contains(sampleRate) {
            throw ExchangeError.invalidInstanceRecord
        }
        if let channelCount, channelCount != 1 && channelCount != 2 {
            throw ExchangeError.invalidInstanceRecord
        }
        if let inputPeakDBFS, !inputPeakDBFS.isFinite || !(-200...48).contains(inputPeakDBFS) {
            throw ExchangeError.invalidInstanceRecord
        }
        if let currentPlan { try PlanValidator().validate(currentPlan) }
    }
}

public enum ExchangeError: Error, Equatable, CustomStringConvertible, Sendable {
    case appGroupUnavailable(String)
    case invalidDirectory
    case invalidMailboxPolicy
    case mailboxLockUnavailable
    case mailboxFull
    case nonCanonicalMailboxEntry(String)
    case invalidInstanceRecord
    case invalidPayload(ExchangeMessageKind)
    case invalidCaptureDuration
    case invalidCommandLifetime
    case invalidArtifactPath
    case artifactTooLarge
    case artifactHashMismatch
    case messageCollision(UUID)
    case messageNotFound(UUID)
    case messageTooLarge
    case malformedMessage(String)
    case unsupportedSchema(String)

    public var description: String {
        switch self {
        case let .appGroupUnavailable(identifier): "The shared App Group container is unavailable: \(identifier)."
        case .invalidDirectory: "The exchange directory is invalid."
        case .invalidMailboxPolicy: "The mailbox policy is invalid."
        case .mailboxLockUnavailable: "The shared mailbox lock is unavailable."
        case .mailboxFull: "The shared mailbox is full of retained protocol state."
        case let .nonCanonicalMailboxEntry(name): "Mailbox entry \(name) does not match its encoded identifier."
        case .invalidInstanceRecord: "The plug-in instance record is invalid."
        case let .invalidPayload(kind): "The payload is invalid for message kind \(kind.rawValue)."
        case .invalidCaptureDuration: "Capture duration must be finite and between 0.25 and 30 seconds."
        case .invalidCommandLifetime: "Companion commands must expire within 60 seconds of publication."
        case .invalidArtifactPath: "The artifact path is outside the controlled exchange directory."
        case .artifactTooLarge: "The artifact exceeds the 128 MiB exchange limit."
        case .artifactHashMismatch: "The artifact content hash does not match its descriptor."
        case let .messageCollision(id): "Message ID \(id) already exists with different content."
        case let .messageNotFound(id): "Message \(id) was not found."
        case .messageTooLarge: "The message exceeds the 1 MiB exchange limit."
        case let .malformedMessage(name): "The exchange contains a malformed message: \(name)."
        case let .unsupportedSchema(version): "Unsupported IPC schema version \(version)."
        }
    }
}

extension CaptureArtifact {
    func validate() throws {
        guard id.uuidString.count == 36,
              !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("\\"),
              relativePath.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }),
              sha256.count == 64,
              sha256.allSatisfy({ $0.isHexDigit }),
              sampleRate.isFinite,
              (8_000...768_000).contains(sampleRate),
              channelCount == 1 || channelCount == 2,
              frameCount > 0 else { throw ExchangeError.invalidArtifactPath }
        if let originatingInstanceID {
            let expectedPath = "artifacts/\(originatingInstanceID.uuidString)/\(id.uuidString).wav"
            guard relativePath == expectedPath else { throw ExchangeError.invalidArtifactPath }
        }
        if originatingRuntimeEpoch != nil, originatingInstanceID == nil {
            throw ExchangeError.invalidArtifactPath
        }
    }
}

private extension Date {
    var exchangeRounded: Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 * 1_000).rounded() / 1_000)
    }
}
