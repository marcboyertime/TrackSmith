import AgentCore
import CryptoKit
import Foundation
import PlanSchema

public enum ConversationTurnKind: String, Codable, CaseIterable, Sendable {
    case request
    case clarification
    case revision
    case selection
    case commit
    case providerFailure
}

public struct PersistedHypothesisSummary: Codable, Equatable, Sendable {
    public var identifier: String
    public var intendedOutcome: String
    public var supportingMetricIdentifiers: [String]
    public var contradictoryMetricIdentifiers: [String]
    public var strategyCategories: [ProductionDSPStrategy]
    public var risks: [String]
    public var provenance: [ProductionIntentProvenance]
    public var listeningRemainsDecisive: Bool

    public init(
        identifier: String,
        intendedOutcome: String,
        supportingMetricIdentifiers: [String],
        contradictoryMetricIdentifiers: [String],
        strategyCategories: [ProductionDSPStrategy],
        risks: [String],
        provenance: [ProductionIntentProvenance],
        listeningRemainsDecisive: Bool
    ) {
        self.identifier = identifier
        self.intendedOutcome = intendedOutcome
        self.supportingMetricIdentifiers = supportingMetricIdentifiers
        self.contradictoryMetricIdentifiers = contradictoryMetricIdentifiers
        self.strategyCategories = strategyCategories
        self.risks = risks
        self.provenance = provenance
        self.listeningRemainsDecisive = listeningRemainsDecisive
    }
}

public struct ProductionConversationTurn: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var kind: ConversationTurnKind
    public var userText: String?
    public var interpretation: ProductionIntentInterpretation?
    public var clarificationQuestion: String?
    public var hypotheses: [PersistedHypothesisSummary]
    public var references: [ModelConversationalReference]
    public var providerMetadata: ProviderExecutionMetadata?
    public var validationAudit: ModelValidationAudit?
    public var authority: ProductionAuthorityIdentity?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ConversationTurnKind,
        userText: String? = nil,
        interpretation: ProductionIntentInterpretation? = nil,
        clarificationQuestion: String? = nil,
        hypotheses: [PersistedHypothesisSummary] = [],
        references: [ModelConversationalReference] = [],
        providerMetadata: ProviderExecutionMetadata? = nil,
        validationAudit: ModelValidationAudit? = nil,
        authority: ProductionAuthorityIdentity? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.userText = userText
        self.interpretation = interpretation
        self.clarificationQuestion = clarificationQuestion
        self.hypotheses = hypotheses
        self.references = references
        self.providerMetadata = providerMetadata
        self.validationAudit = validationAudit
        self.authority = authority
    }
}

public struct ConversationSnapshotRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var parentSnapshotID: UUID?
    public var createdAt: Date
    public var label: String
    public var authority: ProductionAuthorityIdentity
    public var plan: ProcessingPlan?

    public init(
        id: UUID,
        parentSnapshotID: UUID? = nil,
        createdAt: Date = Date(),
        label: String,
        authority: ProductionAuthorityIdentity,
        plan: ProcessingPlan?
    ) {
        self.id = id
        self.parentSnapshotID = parentSnapshotID
        self.createdAt = createdAt
        self.label = label
        self.authority = authority
        self.plan = plan
    }
}

public struct ConversationPreviewRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var sourceSnapshotID: UUID
    public var hypothesisIdentifier: String?
    public var strength: PreviewStrength
    public var plan: ProcessingPlan
    public var selected: Bool

    public init(
        id: UUID,
        createdAt: Date = Date(),
        sourceSnapshotID: UUID,
        hypothesisIdentifier: String? = nil,
        strength: PreviewStrength,
        plan: ProcessingPlan,
        selected: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceSnapshotID = sourceSnapshotID
        self.hypothesisIdentifier = hypothesisIdentifier
        self.strength = strength
        self.plan = plan
        self.selected = selected
    }
}

public struct ConversationRevisionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var turnID: UUID
    public var parentRevisionID: UUID?
    public var basePreviewID: UUID?
    public var baseSnapshotID: UUID
    public var resultSnapshotID: UUID
    public var request: String
    public var references: [ModelConversationalReference]
    public var resultingPlanRequestID: UUID

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        turnID: UUID,
        parentRevisionID: UUID? = nil,
        basePreviewID: UUID? = nil,
        baseSnapshotID: UUID,
        resultSnapshotID: UUID,
        request: String,
        references: [ModelConversationalReference],
        resultingPlanRequestID: UUID
    ) {
        self.id = id
        self.createdAt = createdAt
        self.turnID = turnID
        self.parentRevisionID = parentRevisionID
        self.basePreviewID = basePreviewID
        self.baseSnapshotID = baseSnapshotID
        self.resultSnapshotID = resultSnapshotID
        self.request = request
        self.references = references
        self.resultingPlanRequestID = resultingPlanRequestID
    }
}

public struct ConversationLockRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var turnID: UUID?
    public var nodeID: UUID
    public var locked: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        turnID: UUID? = nil,
        nodeID: UUID,
        locked: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.turnID = turnID
        self.nodeID = nodeID
        self.locked = locked
    }
}

public struct ProductionConversationState: Codable, Equatable, Sendable {
    public var version: String
    public var conversationID: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var authorityBinding: ProductionAuthorityIdentity?
    public var turns: [ProductionConversationTurn]
    public var snapshots: [ConversationSnapshotRecord]
    public var previews: [ConversationPreviewRecord]
    public var revisions: [ConversationRevisionRecord]
    public var lockHistory: [ConversationLockRecord]

    public init(
        version: String = "1.0",
        conversationID: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorityBinding: ProductionAuthorityIdentity? = nil,
        turns: [ProductionConversationTurn] = [],
        snapshots: [ConversationSnapshotRecord] = [],
        previews: [ConversationPreviewRecord] = [],
        revisions: [ConversationRevisionRecord] = [],
        lockHistory: [ConversationLockRecord] = []
    ) {
        self.version = version
        self.conversationID = conversationID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorityBinding = authorityBinding
        self.turns = turns
        self.snapshots = snapshots
        self.previews = previews
        self.revisions = revisions
        self.lockHistory = lockHistory
    }
}

public enum ConversationAuthorityStatus: String, Codable, CaseIterable, Sendable {
    case liveAuthoritative
    case historicalOnly
}

public struct ReconciledConversationState: Codable, Equatable, Sendable {
    public var state: ProductionConversationState
    public var authorityStatus: ConversationAuthorityStatus
    public var reason: String
    public var activeReferences: ModelReferenceRegistry

    public init(
        state: ProductionConversationState,
        authorityStatus: ConversationAuthorityStatus,
        reason: String,
        activeReferences: ModelReferenceRegistry
    ) {
        self.state = state
        self.authorityStatus = authorityStatus
        self.reason = reason
        self.activeReferences = activeReferences
    }
}

public struct ConversationStateReconciler: Sendable {
    public init() {}

    public func reconcile(
        _ state: ProductionConversationState,
        currentAuthority: ProductionAuthorityIdentity?,
        currentCommittedPlan: ProcessingPlan?
    ) -> ReconciledConversationState {
        guard let stored = state.authorityBinding, let currentAuthority else {
            return historical(state, reason: "No live Audio Unit authority is available; restored references are view-only.")
        }
        // A turn identity binds one asynchronous provider request. It is not
        // part of the durable AU/capture authority, otherwise every legitimate
        // new conversational turn would make all typed history stale.
        guard stored.instanceID == currentAuthority.instanceID,
              stored.runtimeEpoch == currentAuthority.runtimeEpoch,
              stored.captureSnapshotID == currentAuthority.captureSnapshotID,
              stored.currentPlanRequestID == currentAuthority.currentPlanRequestID,
              stored.conversationID == currentAuthority.conversationID else {
            return historical(state, reason: "The stored Audio Unit runtime or capture identity no longer matches the live insert.")
        }
        if let expectedPlanID = stored.currentPlanRequestID {
            guard currentCommittedPlan?.requestID == expectedPlanID,
                  currentCommittedPlan?.sourceSnapshotID == stored.captureSnapshotID else {
                return historical(state, reason: "The live committed graph does not match the stored conversation authority.")
            }
        } else if currentCommittedPlan != nil {
            return historical(state, reason: "The live insert has a committed graph absent from the stored authority binding.")
        }
        let nodeIDs = Set(currentCommittedPlan?.nodes.map(\.id) ?? [])
        let lockedIDs = Set(currentCommittedPlan?.nodes.filter(\.locked).map(\.id) ?? [])
        return ReconciledConversationState(
            state: state,
            authorityStatus: .liveAuthoritative,
            reason: "Stored state exactly matches the live AU runtime, capture, and committed graph authority.",
            activeReferences: .init(
                previewIDs: Set(state.previews.map(\.id)),
                snapshotIDs: Set(state.snapshots.map(\.id)),
                priorRequestIDs: Set(state.turns.map(\.id)),
                processingNodeIDs: nodeIDs,
                lockedProcessingNodeIDs: lockedIDs
            )
        )
    }

    private func historical(
        _ state: ProductionConversationState,
        reason: String
    ) -> ReconciledConversationState {
        ReconciledConversationState(
            state: state,
            authorityStatus: .historicalOnly,
            reason: reason,
            // Production terms remain valid knowledge, but no historical AU,
            // preview, snapshot, request, or node identity is live authority.
            activeReferences: .init()
        )
    }
}

public enum ConversationStoreError: Error, Equatable, Sendable {
    case unsafeRoot
    case stateTooLarge
    case unsupportedVersion(String)
    case corruptState
    case fileOperation(String)
}

public struct ConversationLoadResult: Sendable {
    public var state: ProductionConversationState
    public var migratedFromVersion: String?

    public init(state: ProductionConversationState, migratedFromVersion: String? = nil) {
        self.state = state
        self.migratedFromVersion = migratedFromVersion
    }
}

public struct ProductionConversationStore: @unchecked Sendable {
    public static let maximumFileBytes = 4 * 1_024 * 1_024
    public static let maximumTurns = 200
    public static let maximumSnapshots = 120
    public static let maximumPreviews = 120
    public static let maximumRevisions = 240
    public static let maximumLockEvents = 500
    public static let maximumHistoryFiles = 20

    public var rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public init(fileManager: FileManager = .default) throws {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { throw ConversationStoreError.fileOperation("Application Support is unavailable.") }
        self.init(
            rootURL: applicationSupport
                .appendingPathComponent("com.marcboyer.tracksmith", isDirectory: true)
                .appendingPathComponent("ProductionIntelligence", isDirectory: true),
            fileManager: fileManager
        )
    }

    public func save(_ unboundedState: ProductionConversationState) throws -> URL {
        try prepareRoot()
        var state = boundedAndSanitized(unboundedState)
        state.version = "1.0"
        state.updatedAt = Date()
        var stateData = try canonicalEncoder().encode(state)
        while stateData.count > Self.maximumFileBytes / 2, trimOldest(from: &state) {
            stateData = try canonicalEncoder().encode(state)
        }
        guard stateData.count <= Self.maximumFileBytes / 2 else { throw ConversationStoreError.stateTooLarge }
        let checksum = SHA256.hash(data: stateData).map { String(format: "%02x", $0) }.joined()
        let envelope = PersistedConversationEnvelope(
            envelopeVersion: "1.0",
            checksumSHA256: checksum,
            state: state
        )
        let encoder = canonicalEncoder()
        encoder.outputFormatting.insert(.prettyPrinted)
        let data = try encoder.encode(envelope)
        guard data.count <= Self.maximumFileBytes else { throw ConversationStoreError.stateTooLarge }

        let destination = stateURL(state.conversationID)
        if fileManager.fileExists(atPath: destination.path) {
            try preserveHistory(of: destination, conversationID: state.conversationID)
        }
        do {
            try data.write(to: destination, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch {
            throw ConversationStoreError.fileOperation("Conversation state could not be written atomically.")
        }
        return destination
    }

    public func load(conversationID: UUID) throws -> ConversationLoadResult {
        try prepareRoot()
        let url = stateURL(conversationID)
        do {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true,
                  (values.fileSize ?? Self.maximumFileBytes + 1) <= Self.maximumFileBytes else {
                try quarantine(url)
                throw ConversationStoreError.corruptState
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let envelope = try? decoder.decode(PersistedConversationEnvelope.self, from: data) {
                guard envelope.envelopeVersion == "1.0", envelope.state.version == "1.0" else {
                    throw ConversationStoreError.unsupportedVersion(envelope.state.version)
                }
                let canonical = try canonicalEncoder().encode(envelope.state)
                let checksum = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
                guard checksum == envelope.checksumSHA256,
                      envelope.state.conversationID == conversationID else {
                    try quarantine(url)
                    throw ConversationStoreError.corruptState
                }
                return ConversationLoadResult(state: envelope.state)
            }
            // Explicit migration lane for early companion prototypes that
            // persisted the state directly before checksummed envelopes.
            if var legacy = try? decoder.decode(ProductionConversationState.self, from: data),
               legacy.version == "0.9", legacy.conversationID == conversationID {
                legacy.version = "1.0"
                legacy.updatedAt = Date()
                return ConversationLoadResult(
                    state: boundedAndSanitized(legacy),
                    migratedFromVersion: "0.9"
                )
            }
            try quarantine(url)
            throw ConversationStoreError.corruptState
        } catch let error as ConversationStoreError {
            throw error
        } catch {
            try? quarantine(url)
            throw ConversationStoreError.corruptState
        }
    }

    public func stateURL(_ conversationID: UUID) -> URL {
        rootURL.appendingPathComponent("conversation-\(conversationID.uuidString.lowercased()).json")
    }

    private func prepareRoot() throws {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let values = try rootURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw ConversationStoreError.unsafeRoot
            }
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        } catch let error as ConversationStoreError {
            throw error
        } catch {
            throw ConversationStoreError.fileOperation("Conversation storage is unavailable.")
        }
    }

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func boundedAndSanitized(_ input: ProductionConversationState) -> ProductionConversationState {
        var state = input
        state.turns = Array(state.turns.suffix(Self.maximumTurns)).map { turn in
            var turn = turn
            turn.userText = turn.userText.map(redactSecrets)
            turn.clarificationQuestion = turn.clarificationQuestion.map(redactSecrets)
            return turn
        }
        state.snapshots = Array(state.snapshots.suffix(Self.maximumSnapshots)).map { snapshot in
            var snapshot = snapshot
            snapshot.label = redactSecrets(snapshot.label)
            return snapshot
        }
        state.previews = Array(state.previews.suffix(Self.maximumPreviews))
        state.revisions = Array(state.revisions.suffix(Self.maximumRevisions)).map { revision in
            var revision = revision
            revision.request = redactSecrets(revision.request)
            return revision
        }
        state.lockHistory = Array(state.lockHistory.suffix(Self.maximumLockEvents))
        return state
    }

    private func trimOldest(from state: inout ProductionConversationState) -> Bool {
        if state.turns.count > 1 { state.turns.removeFirst(); return true }
        if state.revisions.count > 1 { state.revisions.removeFirst(); return true }
        if state.lockHistory.count > 1 { state.lockHistory.removeFirst(); return true }
        if state.previews.count > 1 { state.previews.removeFirst(); return true }
        if state.snapshots.count > 1 { state.snapshots.removeFirst(); return true }
        return false
    }

    private func redactSecrets(_ text: String) -> String {
        var result = text
        let patterns = [
            #"sk-[A-Za-z0-9_-]{8,}"#,
            #"AIza[A-Za-z0-9_-]{16,}"#,
            #"(?i)(api[_ -]?key|authorization|bearer)\s*[:=]?\s*[A-Za-z0-9._-]{8,}"#,
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "[REDACTED CREDENTIAL]"
            )
        }
        while result.utf8.count > 8_192, !result.isEmpty { result.removeLast() }
        return result
    }

    private func preserveHistory(of current: URL, conversationID: UUID) throws {
        let history = rootURL.appendingPathComponent("history", isDirectory: true)
            .appendingPathComponent(conversationID.uuidString.lowercased(), isDirectory: true)
        try fileManager.createDirectory(at: history, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: history.path)
        let data = try Data(contentsOf: current)
        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let destination = history.appendingPathComponent("\(Date().timeIntervalSince1970)-\(checksum.prefix(12)).json")
        if !fileManager.fileExists(atPath: destination.path) {
            // Existence is checked first and the history filename is
            // content-addressed. Foundation does not support combining
            // `.atomic` and `.withoutOverwriting` and traps if both are set.
            try data.write(to: destination, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        }
        let entries = try fileManager.contentsOfDirectory(
            at: history,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).sorted {
            let left = try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let right = try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return (left ?? .distantPast) < (right ?? .distantPast)
        }
        for entry in entries.dropLast(Self.maximumHistoryFiles) { try? fileManager.removeItem(at: entry) }
    }

    private func quarantine(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let quarantine = rootURL.appendingPathComponent(
            "quarantine-\(Date().timeIntervalSince1970)-\(UUID().uuidString.lowercased()).json"
        )
        do { try fileManager.moveItem(at: url, to: quarantine) }
        catch { throw ConversationStoreError.fileOperation("Corrupt state could not be quarantined.") }
    }
}

private struct PersistedConversationEnvelope: Codable {
    var envelopeVersion: String
    var checksumSHA256: String
    var state: ProductionConversationState
}
