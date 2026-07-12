import Foundation

public enum ProcessingTransactionState: String, Codable, Sendable {
    case proposed, validated, rendering, previewed, committed, rejected, failed
}

public struct ProcessingTransaction: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sourceSnapshotID: UUID
    public private(set) var state: ProcessingTransactionState
    public private(set) var failure: String?

    public init(id: UUID = UUID(), sourceSnapshotID: UUID, state: ProcessingTransactionState = .proposed) {
        self.id = id; self.sourceSnapshotID = sourceSnapshotID; self.state = state
    }

    public mutating func transition(to next: ProcessingTransactionState, failure: String? = nil) throws {
        let allowed: [ProcessingTransactionState: Set<ProcessingTransactionState>] = [
            .proposed: [.validated, .rejected, .failed], .validated: [.rendering, .rejected, .failed],
            .rendering: [.previewed, .failed], .previewed: [.committed, .rejected, .failed],
        ]
        guard allowed[state, default: []].contains(next) else { throw TransactionError.invalidTransition(from: state, to: next) }
        state = next; self.failure = failure
    }
}

public enum TransactionError: Error, Equatable, Sendable {
    case invalidTransition(from: ProcessingTransactionState, to: ProcessingTransactionState)
}
