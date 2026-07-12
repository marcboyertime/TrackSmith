import Foundation
import PlanSchema

public enum CommitStatus: String, Codable, Sendable { case proposed, committed, rejected }

public struct ProcessingSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var parentID: UUID?
    public var plan: ProcessingPlan
    public var analysisVersion: String
    public var sourceIdentity: String
    public var sourceContentHash: String?
    public var structuredGoals: [ProcessingGoal]
    public var previewReferences: [UUID]
    public var modelVersion: String?
    public var promptVersion: String?
    public var pluginVersion: String
    public var timestamp: Date
    public var commitStatus: CommitStatus

    public init(
        id: UUID = UUID(), parentID: UUID?, plan: ProcessingPlan, analysisVersion: String,
        sourceIdentity: String, sourceContentHash: String? = nil, structuredGoals: [ProcessingGoal],
        previewReferences: [UUID] = [], modelVersion: String? = nil, promptVersion: String? = nil,
        pluginVersion: String = "0.1.0", timestamp: Date = Date(), commitStatus: CommitStatus
    ) {
        self.id = id; self.parentID = parentID; self.plan = plan; self.analysisVersion = analysisVersion
        self.sourceIdentity = sourceIdentity; self.sourceContentHash = sourceContentHash; self.structuredGoals = structuredGoals
        self.previewReferences = previewReferences; self.modelVersion = modelVersion; self.promptVersion = promptVersion
        self.pluginVersion = pluginVersion; self.timestamp = timestamp; self.commitStatus = commitStatus
    }
}

public enum SnapshotStoreError: Error, Equatable, Sendable { case missingSnapshot(UUID), noUndo, noRedo }

public actor SnapshotStore {
    private var snapshots: [UUID: ProcessingSnapshot] = [:]
    private var currentID: UUID?
    private var redoIDs: [UUID] = []

    public init() {}

    @discardableResult
    public func add(_ snapshot: ProcessingSnapshot, makeCurrent: Bool = true) -> UUID {
        snapshots[snapshot.id] = snapshot
        if makeCurrent { currentID = snapshot.id; redoIDs.removeAll(keepingCapacity: true) }
        return snapshot.id
    }

    public func current() -> ProcessingSnapshot? { currentID.flatMap { snapshots[$0] } }
    public func snapshot(id: UUID) -> ProcessingSnapshot? { snapshots[id] }
    public func all() -> [ProcessingSnapshot] { snapshots.values.sorted { $0.timestamp < $1.timestamp } }

    public func commit(id: UUID) throws {
        guard var snapshot = snapshots[id] else { throw SnapshotStoreError.missingSnapshot(id) }
        snapshot.commitStatus = .committed; snapshots[id] = snapshot; currentID = id
    }

    @discardableResult
    public func undo() throws -> ProcessingSnapshot {
        guard let id = currentID, let current = snapshots[id], let parentID = current.parentID, let parent = snapshots[parentID] else { throw SnapshotStoreError.noUndo }
        redoIDs.append(id); currentID = parentID; return parent
    }

    @discardableResult
    public func redo() throws -> ProcessingSnapshot {
        guard let id = redoIDs.popLast(), let snapshot = snapshots[id] else { throw SnapshotStoreError.noRedo }
        currentID = id; return snapshot
    }
}
