import Foundation
import PlanSchema

public enum VocalRevisionOperation: Codable, Equatable, Sendable {
    case clearerWordsKeepingMovement
    case lessReverbMoreWobble
    case changeScope(VocalCreativeScope)
    case inheritAspect(aspect: VocalAspect, fromCandidateID: UUID)
    case strangerPreservingIntelligibility
    case moreBrassLessVoice
    case lockAspect(VocalAspect)
    case unlockAspect(VocalAspect)
    case preserveAspects([VocalAspect])
    case exactRevert(candidateID: UUID)
}

public struct VocalRevisionCommand: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var originalProse: String
    public var operations: [VocalRevisionOperation]
    public var parsedAgainstCandidateIDs: [UUID]

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        originalProse: String,
        operations: [VocalRevisionOperation],
        parsedAgainstCandidateIDs: [UUID]
    ) {
        self.version = version
        self.id = id
        self.originalProse = originalProse
        self.operations = operations
        self.parsedAgainstCandidateIDs = parsedAgainstCandidateIDs
    }
}

public struct VocalRevisionReferenceAuthority: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var orderedCandidateIDs: [UUID]
    public var selectedCandidateID: UUID
    public var lastPhraseScope: VocalCreativeScope?
    public var explicitRevertCandidateID: UUID?

    public init(
        version: VocalSchemaVersion = .v1,
        orderedCandidateIDs: [UUID],
        selectedCandidateID: UUID,
        lastPhraseScope: VocalCreativeScope? = nil,
        explicitRevertCandidateID: UUID? = nil
    ) {
        self.version = version
        self.orderedCandidateIDs = orderedCandidateIDs
        self.selectedCandidateID = selectedCandidateID
        self.lastPhraseScope = lastPhraseScope
        self.explicitRevertCandidateID = explicitRevertCandidateID
    }
}

public enum VocalRevisionParserError: Error, Equatable, CustomStringConvertible, Sendable {
    case unsupportedProse
    case unsupportedCapability(String)
    case unresolvedReference(String)
    case contradictoryOperations(String)

    public var description: String {
        switch self {
        case .unsupportedProse: "Only the bounded Vocal v1 revision language can become a typed mutation command."
        case let .unsupportedCapability(reason): "Vocal v1 cannot execute this revision: \(reason)"
        case let .unresolvedReference(reference): "Vocal revision reference could not be resolved exactly: \(reference)."
        case let .contradictoryOperations(reason): "Contradictory vocal revision: \(reason)"
        }
    }
}

public struct VocalRevisionParser: Sendable {
    public init() {}

    public func parse(
        _ prose: String,
        authority: VocalRevisionReferenceAuthority,
        commandID: UUID = UUID()
    ) throws -> VocalRevisionCommand {
        let text = normalize(prose)
        var operations: [VocalRevisionOperation] = []

        if containsAny(text, ["clearer words while keeping the movement", "clearer words but keep the movement", "make the words clearer and keep the movement"]) {
            operations.append(.clearerWordsKeepingMovement)
        }
        if containsAny(text, ["less reverb more wobble", "less reverb and more wobble", "less space more wobble"]) {
            operations.append(.lessReverbMoreWobble)
        }
        if requestsLastPhraseScope(text) {
            guard let scope = authority.lastPhraseScope else {
                throw VocalRevisionParserError.unresolvedReference("last phrase scope")
            }
            operations.append(.changeScope(scope))
        }
        if containsAny(text, ["keep the space from candidate two", "use the space from candidate two", "keep space from candidate 2", "keep the space from version two", "use the space from version two"]) {
            operations.append(.inheritAspect(aspect: .space, fromCandidateID: try ordinal(2, authority)))
        }
        if containsAny(text, ["stranger without losing intelligibility", "make it stranger but keep intelligibility", "stranger while preserving intelligibility"]) {
            operations.append(.strangerPreservingIntelligibility)
        }
        if containsAny(text, ["more brass less voice", "more brass and less voice", "make it more trumpet less voice", "more trumpet less vocal"]) {
            operations.append(.moreBrassLessVoice)
        }
        if containsAny(text, [
            "keep consonants",
            "keep the consonants",
            "keep more consonants",
            "keep more of my consonants",
            "keep more of the consonants",
            "preserve consonants",
            "preserve the consonants",
            "retain consonants",
            "retain the consonants",
        ]) {
            operations.append(.lockAspect(.consonants))
        }
        let typedUnlocks: [(VocalAspect, [String])] = [
            (.consonants, ["unlock consonants", "unlock the consonants", "allow consonants to change"]),
            (.intelligibility, ["unlock intelligibility", "allow intelligibility to change"]),
            (.attack, ["unlock attack", "unlock the attack", "allow attack to change"]),
            (.space, ["unlock space", "unlock the space", "allow space to change"]),
            (.movement, ["unlock movement", "unlock the movement", "allow movement to change"]),
            (.dynamics, ["unlock dynamics", "unlock the dynamics", "allow dynamics to change"]),
            (.melody, ["unlock melody", "unlock the melody", "allow melody to change"]),
            (.voiceIdentity, ["unlock voice identity", "allow voice identity to change"]),
        ]
        for (aspect, phrases) in typedUnlocks where containsAny(text, phrases) {
            operations.append(.unlockAspect(aspect))
        }
        if containsAny(text, ["use attack from candidate one", "use the attack from candidate one", "keep attack from candidate 1", "use the attack from the first version", "use attack from version one"]) {
            operations.append(.inheritAspect(aspect: .attack, fromCandidateID: try ordinal(1, authority)))
        }
        if containsAny(text, [
            "preserve melody and dynamics",
            "preserve the melody and dynamics",
            "preserve the melody and the dynamics",
            "preserve melody/dynamics",
            "keep melody and dynamics",
            "keep the melody and dynamics",
            "keep the melody and the dynamics",
        ]) {
            operations.append(.preserveAspects([.melody, .dynamics]))
        } else if containsAny(text, [
            "keep the melody exactly the same",
            "keep melody exactly the same",
            "preserve the melody exactly",
            "preserve melody exactly",
            "leave the melody unchanged",
            "leave melody unchanged",
            "do not change the melody",
            "don't change the melody",
        ]) {
            operations.append(.preserveAspects([.melody]))
        }
        let naturalRecovery = requestsNaturalExactRevert(text)
        if text == "exact revert" || text == "revert exactly" || text.hasPrefix("revert exactly to") || text.hasPrefix("exactly revert to") || naturalRecovery {
            let target: UUID
            if text.contains("candidate one") || text.contains("candidate 1") {
                target = try ordinal(1, authority)
            } else if text.contains("candidate two") || text.contains("candidate 2") {
                target = try ordinal(2, authority)
            } else if text.contains("candidate three") || text.contains("candidate 3") {
                target = try ordinal(3, authority)
            } else if let exact = authority.explicitRevertCandidateID {
                target = exact
            } else {
                throw VocalRevisionParserError.unresolvedReference("exact revert target")
            }
            operations.append(.exactRevert(candidateID: target))
        }

        if containsAny(text, ["make the brass movement follow my dynamics", "brass movement follow the dynamics"]) {
            throw VocalRevisionParserError.unsupportedCapability(
                "The current bounded modulated-delay node has fixed deterministic rate/depth and no validated analysis-driven dynamics follower. The existing movement can be preserved, increased, or reduced, but it cannot honestly be claimed to follow vocal dynamics."
            )
        }

        guard !operations.isEmpty else { throw VocalRevisionParserError.unsupportedProse }
        let reverts = operations.filter {
            if case .exactRevert = $0 { return true }
            return false
        }
        if !reverts.isEmpty, operations.count != 1 {
            throw VocalRevisionParserError.contradictoryOperations(
                "Exact revert cannot be combined with additional edits."
            )
        }
        if operations.contains(where: {
            if case .changeScope = $0 { return true }
            return false
        }), operations.filter({
            if case .changeScope = $0 { return true }
            return false
        }).count > 1 {
            throw VocalRevisionParserError.contradictoryOperations("More than one new scope was requested.")
        }
        return VocalRevisionCommand(
            id: commandID,
            originalProse: prose,
            operations: operations,
            parsedAgainstCandidateIDs: authority.orderedCandidateIDs
        )
    }

    private func ordinal(
        _ ordinal: Int,
        _ authority: VocalRevisionReferenceAuthority
    ) throws -> UUID {
        let index = ordinal - 1
        guard authority.orderedCandidateIDs.indices.contains(index) else {
            throw VocalRevisionParserError.unresolvedReference("candidate \(ordinal)")
        }
        return authority.orderedCandidateIDs[index]
    }

    private func normalize(_ prose: String) -> String {
        prose
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func requestsLastPhraseScope(_ text: String) -> Bool {
        guard text.contains("last phrase") else { return false }
        return containsAny(text, [
            "last phrase only",
            "only the last phrase",
            "only make the last phrase",
            "apply it to the last phrase",
            "apply this to the last phrase",
            "apply that to the last phrase",
            "limit it to the last phrase",
            "limit this to the last phrase",
            "restrict it to the last phrase",
            "restrict this to the last phrase",
        ])
    }

    private func requestsNaturalExactRevert(_ text: String) -> Bool {
        [
            "go back to the version before ",
            "go back to before ",
            "return to the version before ",
            "return to before ",
        ].contains { text.hasPrefix($0) }
    }

    private func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }
}

public struct VocalRevisionApplicationIDs: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var resultCandidateID: UUID
    public var resultIntentID: UUID
    public var resultPlanRequestID: UUID
    public var insertedNodeIDs: [UUID]
    public var aspectLockIDs: [UUID]

    public init(
        version: VocalSchemaVersion = .v1,
        resultCandidateID: UUID,
        resultIntentID: UUID,
        resultPlanRequestID: UUID,
        insertedNodeIDs: [UUID] = [],
        aspectLockIDs: [UUID] = []
    ) {
        self.version = version
        self.resultCandidateID = resultCandidateID
        self.resultIntentID = resultIntentID
        self.resultPlanRequestID = resultPlanRequestID
        self.insertedNodeIDs = insertedNodeIDs
        self.aspectLockIDs = aspectLockIDs
    }
}

public struct VocalRevisionRecord: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var baseCandidateID: UUID
    public var resultCandidateID: UUID
    public var exactAncestorCandidateIDs: [UUID]
    public var command: VocalRevisionCommand
    public var changedNodeIDs: [UUID]
    public var insertedNodeIDs: [UUID]
    public var removedNodeIDs: [UUID]
    public var inheritedReferences: [VocalExactReference]
    public var changedScopeOnly: Bool
    public var createdAt: Date

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        baseCandidateID: UUID,
        resultCandidateID: UUID,
        exactAncestorCandidateIDs: [UUID],
        command: VocalRevisionCommand,
        changedNodeIDs: [UUID],
        insertedNodeIDs: [UUID],
        removedNodeIDs: [UUID],
        inheritedReferences: [VocalExactReference],
        changedScopeOnly: Bool,
        createdAt: Date
    ) {
        self.version = version
        self.id = id
        self.baseCandidateID = baseCandidateID
        self.resultCandidateID = resultCandidateID
        self.exactAncestorCandidateIDs = exactAncestorCandidateIDs
        self.command = command
        self.changedNodeIDs = changedNodeIDs
        self.insertedNodeIDs = insertedNodeIDs
        self.removedNodeIDs = removedNodeIDs
        self.inheritedReferences = inheritedReferences
        self.changedScopeOnly = changedScopeOnly
        self.createdAt = createdAt
    }
}

public struct VocalRevisionResult: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var candidate: VocalCreativeCandidate
    public var record: VocalRevisionRecord

    public init(
        version: VocalSchemaVersion = .v1,
        candidate: VocalCreativeCandidate,
        record: VocalRevisionRecord
    ) {
        self.version = version
        self.candidate = candidate
        self.record = record
    }
}

public enum VocalRevisionError: Error, Equatable, CustomStringConvertible, Sendable {
    case baseCandidateNotInAuthority
    case duplicateCandidateID(UUID)
    case missingCandidate(UUID)
    case staleCandidate(UUID)
    case unsupportedForCandidate(String)
    case conflictingLock(VocalAspect)
    case lockedNodeModified(UUID)
    case exactRevertConflictsWithCurrentLocks(UUID)
    case missingDeterministicIdentity(String)
    case invalidResult(String)

    public var description: String {
        switch self {
        case .baseCandidateNotInAuthority: "The selected candidate is absent from the command's exact reference authority."
        case let .duplicateCandidateID(id): "Duplicate candidate identity in revision authority: \(id)."
        case let .missingCandidate(id): "Revision candidate \(id) is unavailable."
        case let .staleCandidate(id): "Revision candidate \(id) targets a different source or scope authority."
        case let .unsupportedForCandidate(reason): "This revision cannot be applied incrementally: \(reason)"
        case let .conflictingLock(aspect): "The revision conflicts with locked \(aspect.rawValue) under its exact lock."
        case let .lockedNodeModified(id): "The revision would modify or remove locked node \(id)."
        case let .exactRevertConflictsWithCurrentLocks(id): "Exact revert target \(id) does not preserve the current exact locks."
        case let .missingDeterministicIdentity(kind): "Revision requires a caller-supplied deterministic \(kind) identity."
        case let .invalidResult(reason): "Revised vocal candidate is invalid: \(reason)"
        }
    }
}

public struct VocalRevisionEngine: Sendable {
    public init() {}

    public func apply(
        _ command: VocalRevisionCommand,
        to base: VocalCreativeCandidate,
        availableCandidates: [VocalCreativeCandidate],
        ids: VocalRevisionApplicationIDs,
        createdAt: Date
    ) throws -> VocalRevisionResult {
        guard command.parsedAgainstCandidateIDs.contains(base.id) else {
            throw VocalRevisionError.baseCandidateNotInAuthority
        }
        let candidateMap = try exactCandidateMap(availableCandidates + [base])
        guard ids.resultCandidateID != base.id else {
            throw VocalRevisionError.duplicateCandidateID(ids.resultCandidateID)
        }

        if command.operations.count == 1,
           case let .exactRevert(targetID) = command.operations[0] {
            guard command.parsedAgainstCandidateIDs.contains(targetID) else {
                throw VocalRevisionError.missingCandidate(targetID)
            }
            guard let target = candidateMap[targetID] else { throw VocalRevisionError.missingCandidate(targetID) }
            try validateCompatible(reference: target, base: base, allowDifferentScope: true)
            try validateLocksFrom(base: base, surviveIn: target)
            var result = target
            result.id = ids.resultCandidateID
            result.parentCandidateID = base.id
            result.revisionID = command.id
            result.revertedToCandidateID = target.id
            result.interpretationIndex = base.interpretationIndex
            result.createdAt = createdAt
            result.previewID = nil
            result.assetID = nil
            let record = VocalRevisionRecord(
                id: command.id,
                baseCandidateID: base.id,
                resultCandidateID: result.id,
                exactAncestorCandidateIDs: uniqueIDs(
                    ancestry(for: base, candidateMap: candidateMap) + [target.id]
                ),
                command: command,
                changedNodeIDs: symmetricChangedNodeIDs(base.plan.nodes, target.plan.nodes),
                insertedNodeIDs: target.plan.nodes.filter { targetNode in !base.plan.nodes.contains(where: { $0.id == targetNode.id }) }.map(\.id),
                removedNodeIDs: base.plan.nodes.filter { baseNode in !target.plan.nodes.contains(where: { $0.id == baseNode.id }) }.map(\.id),
                inheritedReferences: [reference(for: target, aspect: nil)],
                changedScopeOnly: false,
                createdAt: createdAt
            )
            return VocalRevisionResult(candidate: result, record: record)
        }

        var result = base
        result.id = ids.resultCandidateID
        result.parentCandidateID = base.id
        result.revisionID = command.id
        result.revertedToCandidateID = nil
        result.createdAt = createdAt
        result.previewID = nil
        result.assetID = nil
        result.plan.requestID = ids.resultPlanRequestID
        result.intent.id = ids.resultIntentID
        var insertedIndex = 0
        var lockIndex = 0
        var changed = Set<UUID>()
        var inserted: [UUID] = []
        var removed: [UUID] = []
        var inherited: [VocalExactReference] = []
        var onlyScopeChanged = true

        func nextInsertedNodeID() throws -> UUID {
            guard ids.insertedNodeIDs.indices.contains(insertedIndex) else {
                throw VocalRevisionError.missingDeterministicIdentity("inserted-node")
            }
            defer { insertedIndex += 1 }
            return ids.insertedNodeIDs[insertedIndex]
        }
        func nextLockID() throws -> UUID {
            guard ids.aspectLockIDs.indices.contains(lockIndex) else {
                throw VocalRevisionError.missingDeterministicIdentity("aspect-lock")
            }
            defer { lockIndex += 1 }
            return ids.aspectLockIDs[lockIndex]
        }

        for operation in command.operations {
            switch operation {
            case .clearerWordsKeepingMovement:
                try assertUnlocked([.intelligibility, .consonants, .brightness, .tone], candidate: result)
                let movementBefore = exactNodes(for: [.movement, .wobble], in: result)
                var didChange = false
                result.plan.nodes = result.plan.nodes.map { node in
                    guard !node.locked else { return node }
                    var copy = node
                    switch node.type {
                    case .lowPass:
                        copy.parameters[.frequencyHz] = min(12_000, node.parameters[.frequencyHz, default: 5_000] * 1.18)
                        copy.rationale = "Open the existing upper boundary one bounded step for clearer words while keeping the movement path exact."
                        didChange = copy != node
                    case .parametricEQ where node.parameters[.frequencyHz, default: 0] >= 1_500:
                        copy.parameters[.gainDB] = min(4, node.parameters[.gainDB, default: 0] + 0.75)
                        copy.rationale = "Increase the existing presence relationship one bounded step while preserving movement."
                        didChange = copy != node
                    default:
                        break
                    }
                    if copy != node { changed.insert(node.id) }
                    return copy
                }
                if !didChange {
                    let nodeID = try nextInsertedNodeID()
                    let newNode = ProcessingNode(
                        id: nodeID,
                        type: .parametricEQ,
                        parameters: [.frequencyHz: 3_200, .q: 0.9, .gainDB: 0.75],
                        rationale: "Add one bounded editable presence band because the base candidate has no suitable unlocked clarity node.",
                        confidence: 0.55,
                        category: .corrective
                    )
                    insertBeforeLimiter(newNode, in: &result.plan.nodes)
                    inserted.append(nodeID)
                }
                try assertExact(movementBefore, survivesIn: result.plan.nodes)
                addPreservedAspect(.movement, to: &result.intent)
                onlyScopeChanged = false

            case .lessReverbMoreWobble:
                try assertUnlocked([.space, .movement, .wobble], candidate: result)
                var changedSpace = false
                var changedWobble = false
                result.plan.nodes = result.plan.nodes.map { node in
                    guard !node.locked else { return node }
                    var copy = node
                    if node.type == .reverb || node.type == .delay {
                        copy.parameters[.mix] = node.parameters[.mix, default: 0.2] * 0.6
                        copy.rationale = "Reduce the existing space path without rebuilding the chain."
                        changedSpace = copy != node
                    } else if node.type == .modulatedDelay {
                        copy.parameters[.modulationDepthMS] = min(20, node.parameters[.modulationDepthMS, default: 2] * 1.25 + 0.5)
                        copy.parameters[.modulationRateHz] = min(5, node.parameters[.modulationRateHz, default: 0.3] * 1.12)
                        copy.rationale = "Increase real time-varying wobble within the existing modulated-delay node."
                        changedWobble = copy != node
                    }
                    if copy != node { changed.insert(node.id) }
                    return copy
                }
                guard changedSpace, changedWobble else {
                    throw VocalRevisionError.unsupportedForCandidate(
                        "Less reverb/more wobble requires an unlocked space node and an existing modulatedDelay node."
                    )
                }
                onlyScopeChanged = false

            case let .changeScope(scope):
                try VocalContractValidator().validate(scope: scope)
                if let locked = result.intent.aspectLocks.first(where: { $0.scopePolicy == .exactScope && $0.reference.scopeID != scope.id }) {
                    throw VocalRevisionError.conflictingLock(locked.aspect)
                }
                result.intent.scope = scope
                result.plan.scope.timeRangeSeconds = scope.kind == .fullSource ? nil : scope.seconds
                result.intent.exactReferences = result.intent.exactReferences.map { existing in
                    var copy = existing
                    copy.scopeID = scope.id
                    return copy
                }

            case let .inheritAspect(aspect, referenceID):
                try assertUnlocked([aspect], candidate: result)
                guard command.parsedAgainstCandidateIDs.contains(referenceID) else {
                    throw VocalRevisionError.missingCandidate(referenceID)
                }
                guard let referenceCandidate = candidateMap[referenceID] else {
                    throw VocalRevisionError.missingCandidate(referenceID)
                }
                try validateCompatible(reference: referenceCandidate, base: base, allowDifferentScope: false)
                let outcome = try inheritAspect(
                    aspect,
                    from: referenceCandidate,
                    into: result
                )
                result = outcome.result
                changed.formUnion(outcome.changed)
                inserted.append(contentsOf: outcome.inserted)
                removed.append(contentsOf: outcome.removed)
                inherited.append(reference(for: referenceCandidate, aspect: aspect))
                onlyScopeChanged = false

            case .strangerPreservingIntelligibility:
                try assertUnlocked([.distortion, .movement, .instability], candidate: result)
                let intelligibilityBefore = exactNodes(for: [.intelligibility, .consonants], in: result)
                var didChange = false
                result.plan.nodes = result.plan.nodes.map { node in
                    guard !node.locked else { return node }
                    var copy = node
                    if node.type == .saturation || node.type == .softClipper {
                        copy.parameters[.driveDB] = min(30, node.parameters[.driveDB, default: 3] + 3)
                        copy.parameters[.mix] = min(0.7, node.parameters[.mix, default: 0.15] + 0.10)
                        copy.rationale = "Increase the existing strange harmonic texture while retaining the exact intelligibility path."
                    } else if node.type == .modulatedDelay {
                        copy.parameters[.modulationDepthMS] = min(20, node.parameters[.modulationDepthMS, default: 2] + 2)
                        copy.rationale = "Increase the existing strange motion without changing pitch or timing authority."
                    }
                    if copy != node { changed.insert(node.id); didChange = true }
                    return copy
                }
                if !didChange {
                    let nodeID = try nextInsertedNodeID()
                    let newNode = ProcessingNode(
                        id: nodeID,
                        type: .saturation,
                        parameters: [.driveDB: 6, .mix: 0.18],
                        rationale: "Add one bounded parallel strange texture; no existing chain is rebuilt.",
                        confidence: 0.58,
                        category: .creative
                    )
                    insertBeforeLimiter(newNode, in: &result.plan.nodes)
                    inserted.append(nodeID)
                }
                try assertExact(intelligibilityBefore, survivesIn: result.plan.nodes)
                let lockID = try nextLockID()
                addLock(
                    .intelligibility,
                    lockID: lockID,
                    exactNodes: intelligibilityBefore,
                    candidateID: base.id,
                    to: &result.intent
                )
                onlyScopeChanged = false

            case .moreBrassLessVoice:
                guard result.intent.archetype == .vocalToBrass else {
                    throw VocalRevisionError.unsupportedForCandidate(
                        "More brass/less voice requires a vocalToBrass candidate."
                    )
                }
                if result.intent.aspectLocks.contains(where: { $0.aspect == .voiceIdentity }) {
                    throw VocalRevisionError.conflictingLock(.voiceIdentity)
                }
                try assertUnlocked([.brassLikeColoration, .metallicCharacter, .tone], candidate: result)
                var didChange = false
                result.plan.nodes = result.plan.nodes.map { node in
                    guard !node.locked else { return node }
                    var copy = node
                    if node.type == .parametricEQ,
                       node.parameters[.gainDB, default: 0] > 0 {
                        copy.parameters[.gainDB] = min(5, node.parameters[.gainDB, default: 0] + 0.9)
                        copy.rationale = "Increase the existing brass-like resonance one bounded step."
                    } else if node.type == .saturation {
                        copy.parameters[.driveDB] = min(32, node.parameters[.driveDB, default: 4] + 3)
                        copy.parameters[.mix] = min(0.72, node.parameters[.mix, default: 0.2] + 0.10)
                        copy.rationale = "Increase the existing brass-like harmonic coloration while retaining the vocal source."
                    } else if node.type == .modulatedDelay {
                        copy.parameters[.mix] = min(0.45, node.parameters[.mix, default: 0.12] + 0.06)
                        copy.rationale = "Increase the existing animated brass-hybrid layer."
                    }
                    if copy != node { changed.insert(node.id); didChange = true }
                    return copy
                }
                guard didChange else {
                    throw VocalRevisionError.unsupportedForCandidate("No unlocked brass-color node is available.")
                }
                result.limitations.append(
                    "More brass/less voice increases editable coloration only; the source remains a vocal and no acoustic trumpet reconstruction is claimed."
                )
                onlyScopeChanged = false

            case let .lockAspect(aspect):
                let exact = exactNodes(for: [aspect], in: result)
                let lockID = try nextLockID()
                addLock(aspect, lockID: lockID, exactNodes: exact, candidateID: base.id, to: &result.intent)
                addPreservedAspect(aspect, to: &result.intent)
                onlyScopeChanged = false

            case let .unlockAspect(aspect):
                guard result.intent.aspectLocks.contains(where: { $0.aspect == aspect }) else {
                    throw VocalRevisionError.unsupportedForCandidate(
                        "The \(aspect.rawValue) aspect is not currently locked."
                    )
                }
                result.intent.aspectLocks.removeAll { $0.aspect == aspect }
                if let attribute = processingGoalAttribute(for: aspect),
                   !result.intent.aspectLocks.contains(where: {
                       processingGoalAttribute(for: $0.aspect) == attribute
                   }),
                   let index = result.plan.goals.firstIndex(where: { $0.attribute == attribute }) {
                    result.plan.goals[index].locked = false
                }
                onlyScopeChanged = false

            case let .preserveAspects(aspects):
                for aspect in aspects {
                    let exact = exactNodes(for: [aspect], in: result)
                    let lockID = try nextLockID()
                    addLock(aspect, lockID: lockID, exactNodes: exact, candidateID: base.id, to: &result.intent)
                    addPreservedAspect(aspect, to: &result.intent)
                }
                onlyScopeChanged = false

            case .exactRevert:
                throw VocalRevisionError.invalidResult("Exact revert must be the only command operation.")
            }
        }

        do {
            let nodesBeforePreservation = result.plan.nodes
            let preservation = try VocalDSPPreservationMatrix.constrainedNodes(
                result.plan.nodes,
                preservation: result.intent.preservation,
                lockedAspects: result.intent.aspectLocks.map(\.aspect)
            )
            result.plan.nodes = preservation.nodes
            for (before, after) in zip(nodesBeforePreservation, result.plan.nodes)
                where before != after {
                changed.insert(after.id)
            }
            if !preservation.adjustments.isEmpty {
                result.limitations.append(contentsOf: preservation.adjustments.map {
                    "Revision was conservatively bounded: \($0) The requested perceptual result still requires audition."
                })
            }
        } catch {
            throw VocalRevisionError.invalidResult(String(describing: error))
        }

        result.plan.goals = processingGoalsAfterRevision(result.intent, fallback: result.plan.goals)
        result.aspectBindings = rebuildBindings(previous: result.aspectBindings, nodes: result.plan.nodes, inherited: inherited)
        result.authorityStatus = .locallyValidated
        result.realtimeActivatable = result.intent.scope.kind == .fullSource
        if result.realtimeActivatable {
            result.boundary = result.plan.nodes.contains(where: { $0.type == .modulatedDelay })
                ? .editableModulationDSP
                : .editableDeterministicDSP
        } else {
            result.boundary = .scopedEditablePlanForOfflineRender
        }
        try validateLockedNodes(from: base, in: result)
        try validateAspectLocks(from: base, in: result)
        do {
            if result.realtimeActivatable {
                try PlanValidator().validateForRealtimeActivation(
                    result.plan,
                    currentSnapshotID: base.intent.sourceSnapshotID,
                    basePlan: base.plan
                )
            } else {
                try PlanValidator().validate(
                    result.plan,
                    currentSnapshotID: base.intent.sourceSnapshotID,
                    basePlan: base.plan
                )
            }
            try VocalContractValidator().validate(candidate: result)
        } catch let error as VocalRevisionError {
            throw error
        } catch {
            throw VocalRevisionError.invalidResult(String(describing: error))
        }
        let record = VocalRevisionRecord(
            id: command.id,
            baseCandidateID: base.id,
            resultCandidateID: result.id,
            exactAncestorCandidateIDs: ancestry(for: base, candidateMap: candidateMap),
            command: command,
            changedNodeIDs: changed.sorted { $0.uuidString < $1.uuidString },
            insertedNodeIDs: inserted,
            removedNodeIDs: removed,
            inheritedReferences: inherited,
            changedScopeOnly: onlyScopeChanged && result.plan.nodes == base.plan.nodes,
            createdAt: createdAt
        )
        return VocalRevisionResult(candidate: result, record: record)
    }

    private func exactCandidateMap(
        _ candidates: [VocalCreativeCandidate]
    ) throws -> [UUID: VocalCreativeCandidate] {
        var result: [UUID: VocalCreativeCandidate] = [:]
        for candidate in candidates {
            if let prior = result[candidate.id], prior != candidate {
                throw VocalRevisionError.duplicateCandidateID(candidate.id)
            }
            result[candidate.id] = candidate
        }
        return result
    }

    private func validateCompatible(
        reference: VocalCreativeCandidate,
        base: VocalCreativeCandidate,
        allowDifferentScope: Bool
    ) throws {
        guard reference.intent.sourceSnapshotID == base.intent.sourceSnapshotID,
              reference.plan.sourceSnapshotID == base.plan.sourceSnapshotID else {
            throw VocalRevisionError.staleCandidate(reference.id)
        }
        guard allowDifferentScope || reference.intent.scope == base.intent.scope else {
            throw VocalRevisionError.staleCandidate(reference.id)
        }
    }

    private func assertUnlocked(
        _ aspects: [VocalAspect],
        candidate: VocalCreativeCandidate
    ) throws {
        if let lock = candidate.intent.aspectLocks.first(where: { aspects.contains($0.aspect) }) {
            throw VocalRevisionError.conflictingLock(lock.aspect)
        }
    }

    private func exactNodes(
        for aspects: [VocalAspect],
        in candidate: VocalCreativeCandidate
    ) -> [ProcessingNode] {
        let ids = Set(candidate.aspectBindings.filter { aspects.contains($0.aspect) }.flatMap(\.nodeIDs))
        return candidate.plan.nodes.filter { ids.contains($0.id) }
    }

    private func assertExact(
        _ exact: [ProcessingNode],
        survivesIn nodes: [ProcessingNode]
    ) throws {
        let current = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in exact where current[node.id] != node {
            throw VocalRevisionError.lockedNodeModified(node.id)
        }
    }

    private struct InheritanceOutcome {
        var result: VocalCreativeCandidate
        var changed: Set<UUID>
        var inserted: [UUID]
        var removed: [UUID]
    }

    private func inheritAspect(
        _ aspect: VocalAspect,
        from reference: VocalCreativeCandidate,
        into input: VocalCreativeCandidate
    ) throws -> InheritanceOutcome {
        var result = input
        let referenceNodes = exactNodes(for: [aspect], in: reference)
        guard !referenceNodes.isEmpty else {
            throw VocalRevisionError.unsupportedForCandidate(
                "Candidate \(reference.id) has no exact \(aspect.rawValue) node binding."
            )
        }
        if aspect == .attack {
            let referenceAttack = referenceNodes.first(where: { $0.parameters[.attackMS] != nil })
            guard let attack = referenceAttack?.parameters[.attackMS] else {
                throw VocalRevisionError.unsupportedForCandidate("The reference candidate has no attack parameter.")
            }
            guard let targetIndex = result.plan.nodes.firstIndex(where: {
                !$0.locked && $0.parameters[.attackMS] != nil
            }) else {
                throw VocalRevisionError.unsupportedForCandidate("The base candidate has no unlocked attack parameter.")
            }
            let old = result.plan.nodes[targetIndex]
            result.plan.nodes[targetIndex].parameters[.attackMS] = attack
            result.plan.nodes[targetIndex].rationale = "Use the exact attack value from candidate \(reference.id.uuidString.lowercased()) while preserving every other parameter in this node."
            result.aspectBindings.removeAll { $0.aspect == .attack }
            result.aspectBindings.append(VocalAspectBinding(
                aspect: .attack,
                nodeIDs: [result.plan.nodes[targetIndex].id],
                inheritedFromCandidateID: reference.id,
                limitations: ["Only attackMS is inherited; this does not claim transient or consonant recognition."]
            ))
            return InheritanceOutcome(
                result: result,
                changed: old == result.plan.nodes[targetIndex] ? [] : [old.id],
                inserted: [],
                removed: []
            )
        }

        let currentIDs = Set(result.aspectBindings.filter { $0.aspect == aspect }.flatMap(\.nodeIDs))
        let lockedIDs = Set(result.plan.nodes.filter(\.locked).map(\.id))
        if let conflicting = currentIDs.intersection(lockedIDs).first {
            throw VocalRevisionError.lockedNodeModified(conflicting)
        }
        let removed = result.plan.nodes.filter { currentIDs.contains($0.id) }.map(\.id)
        result.plan.nodes.removeAll { currentIDs.contains($0.id) }
        let remainingIDs = Set(result.plan.nodes.map(\.id))
        if let collision = referenceNodes.first(where: { remainingIDs.contains($0.id) }) {
            throw VocalRevisionError.invalidResult("Inherited node ID collides with retained node \(collision.id).")
        }
        for referenceNode in referenceNodes { insertBeforeLimiter(referenceNode, in: &result.plan.nodes) }
        result.aspectBindings.removeAll { $0.aspect == aspect }
        result.aspectBindings.append(VocalAspectBinding(
            aspect: aspect,
            nodeIDs: referenceNodes.map(\.id),
            inheritedFromCandidateID: reference.id,
            limitations: ["The exact bound nodes are inherited from the exact candidate ID; perception still requires audition."]
        ))
        return InheritanceOutcome(
            result: result,
            changed: Set(removed),
            inserted: referenceNodes.map(\.id),
            removed: removed
        )
    }

    private func addLock(
        _ aspect: VocalAspect,
        lockID: UUID,
        exactNodes: [ProcessingNode],
        candidateID: UUID,
        to intent: inout VocalCreativeIntent
    ) {
        guard !intent.aspectLocks.contains(where: { $0.aspect == aspect }) else { return }
        let reference = VocalExactReference(
            sourceSnapshotID: intent.sourceSnapshotID,
            scopeID: intent.scope.id,
            candidateID: candidateID,
            nodeIDs: exactNodes.map(\.id),
            aspect: aspect
        )
        intent.aspectLocks.append(VocalAspectLock(
            id: lockID,
            aspect: aspect,
            reference: reference,
            exactNodes: exactNodes,
            reason: "Explicit typed vocal revision lock."
        ))
    }

    private func addPreservedAspect(
        _ aspect: VocalAspect,
        to intent: inout VocalCreativeIntent
    ) {
        if !intent.preservation.preserved.contains(aspect) {
            intent.preservation.preserved.append(aspect)
        }
    }

    private func insertBeforeLimiter(
        _ node: ProcessingNode,
        in nodes: inout [ProcessingNode]
    ) {
        if let limiter = nodes.lastIndex(where: { $0.enabled && $0.type == .limiter }) {
            nodes.insert(node, at: limiter)
        } else {
            nodes.append(node)
        }
    }

    private func validateLockedNodes(
        from base: VocalCreativeCandidate,
        in result: VocalCreativeCandidate
    ) throws {
        let current = Dictionary(uniqueKeysWithValues: result.plan.nodes.map { ($0.id, $0) })
        for node in base.plan.nodes where node.locked && current[node.id] != node {
            throw VocalRevisionError.lockedNodeModified(node.id)
        }
    }

    private func validateAspectLocks(
        from base: VocalCreativeCandidate,
        in result: VocalCreativeCandidate
    ) throws {
        let baseNodes = Dictionary(uniqueKeysWithValues: base.plan.nodes.map { ($0.id, $0) })
        let resultNodes = Dictionary(uniqueKeysWithValues: result.plan.nodes.map { ($0.id, $0) })
        for lock in base.intent.aspectLocks {
            if lock.scopePolicy == .exactScope, result.intent.scope.id != lock.reference.scopeID {
                throw VocalRevisionError.conflictingLock(lock.aspect)
            }
            for nodeID in lock.reference.nodeIDs {
                guard let original = baseNodes[nodeID], resultNodes[nodeID] == original else {
                    throw VocalRevisionError.lockedNodeModified(nodeID)
                }
            }
        }
    }

    private func validateLocksFrom(
        base: VocalCreativeCandidate,
        surviveIn target: VocalCreativeCandidate
    ) throws {
        do {
            try validateLockedNodes(from: base, in: target)
            try validateAspectLocks(from: base, in: target)
        } catch {
            throw VocalRevisionError.exactRevertConflictsWithCurrentLocks(target.id)
        }
    }

    private func reference(
        for candidate: VocalCreativeCandidate,
        aspect: VocalAspect?
    ) -> VocalExactReference {
        let bindingIDs = aspect.map { selected in
            candidate.aspectBindings.filter { $0.aspect == selected }.flatMap(\.nodeIDs)
        } ?? candidate.plan.nodes.map(\.id)
        return VocalExactReference(
            sourceSnapshotID: candidate.intent.sourceSnapshotID,
            scopeID: candidate.intent.scope.id,
            candidateID: candidate.id,
            nodeIDs: bindingIDs,
            previewID: candidate.previewID,
            assetID: candidate.assetID,
            aspect: aspect
        )
    }

    /// Resolves every retained ancestor instead of recording only the immediate
    /// parent. Callers may still validate a single legacy branch head when an
    /// older parent object is unavailable, but a complete candidate graph
    /// produces a complete root-to-head chain suitable for exact recovery and
    /// save/reload validation.
    private func ancestry(
        for candidate: VocalCreativeCandidate,
        candidateMap: [UUID: VocalCreativeCandidate]
    ) -> [UUID] {
        var reverseChain: [UUID] = []
        var visited = Set<UUID>()
        var cursor = candidate

        while visited.insert(cursor.id).inserted {
            reverseChain.append(cursor.id)
            guard let parentID = cursor.parentCandidateID else { break }
            guard let parent = candidateMap[parentID] else {
                if visited.insert(parentID).inserted {
                    reverseChain.append(parentID)
                }
                break
            }
            cursor = parent
        }
        return reverseChain.reversed()
    }

    private func uniqueIDs(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func symmetricChangedNodeIDs(
        _ left: [ProcessingNode],
        _ right: [ProcessingNode]
    ) -> [UUID] {
        let leftMap = Dictionary(uniqueKeysWithValues: left.map { ($0.id, $0) })
        let rightMap = Dictionary(uniqueKeysWithValues: right.map { ($0.id, $0) })
        return Set(leftMap.keys).union(rightMap.keys).filter { leftMap[$0] != rightMap[$0] }
            .sorted { $0.uuidString < $1.uuidString }
    }

    private func rebuildBindings(
        previous: [VocalAspectBinding],
        nodes: [ProcessingNode],
        inherited: [VocalExactReference]
    ) -> [VocalAspectBinding] {
        let live = Set(nodes.map(\.id))
        let identityOnlyAspects: Set<VocalAspect> = [
            .pitch, .timing, .melody, .voiceIdentity, .consonants, .intelligibility,
        ]
        var result: [VocalAspectBinding] = previous.map { binding in
            var copy = binding
            copy.nodeIDs = binding.nodeIDs.filter { live.contains($0) }
            return copy
        }.filter { (binding: VocalAspectBinding) -> Bool in
            !binding.nodeIDs.isEmpty || identityOnlyAspects.contains(binding.aspect)
        }
        for reference in inherited {
            guard let aspect = reference.aspect else { continue }
            result.removeAll { $0.aspect == aspect }
            result.append(VocalAspectBinding(
                aspect: aspect,
                nodeIDs: reference.nodeIDs.filter { live.contains($0) },
                inheritedFromCandidateID: reference.candidateID,
                limitations: ["Inherited by exact candidate and node identity."]
            ))
        }
        return result
    }

    private func processingGoalsAfterRevision(
        _ intent: VocalCreativeIntent,
        fallback: [ProcessingGoal]
    ) -> [ProcessingGoal] {
        var goals = fallback
        func preserve(_ attribute: GoalAttribute) {
            if let index = goals.firstIndex(where: { $0.attribute == attribute }) {
                goals[index].locked = true
            } else {
                goals.append(ProcessingGoal(attribute: attribute, direction: .preserve, strength: 1, locked: true))
            }
        }
        for aspect in intent.aspectLocks.map(\.aspect) {
            switch aspect {
            case .dynamics: preserve(.dynamicControl)
            case .intelligibility, .consonants, .articulation: preserve(.clarity)
            case .space: preserve(.closeness)
            case .width: preserve(.width)
            case .loudness: preserve(.loudness)
            default: break
            }
        }
        return goals
    }

    private func processingGoalAttribute(for aspect: VocalAspect) -> GoalAttribute? {
        switch aspect {
        case .dynamics: .dynamicControl
        case .intelligibility, .consonants, .articulation: .clarity
        case .space: .closeness
        case .width: .width
        case .loudness: .loudness
        default: nil
        }
    }
}
