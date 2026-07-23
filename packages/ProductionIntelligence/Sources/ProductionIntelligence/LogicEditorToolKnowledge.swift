import Foundation

/// Reviewed host-editor knowledge. It contains descriptions only: no key
/// command, UI action, Accessibility instruction, project mutation, or DSP.
public struct LogicEditorToolKnowledge: Codable, Equatable, Sendable {
    public var identifier: String
    public var name: String
    public var areas: [String]
    public var manualPages: String
    public var documentedBehavior: String
    public var stateScope: String
    public var productionConsequenceAndRisk: String
    public let executionBoundary: LogicNativeExecutionBoundary

    public init(
        identifier: String,
        name: String,
        areas: [String],
        manualPages: String,
        documentedBehavior: String,
        stateScope: String,
        productionConsequenceAndRisk: String
    ) {
        self.identifier = identifier
        self.name = name
        self.areas = areas
        self.manualPages = manualPages
        self.documentedBehavior = documentedBehavior
        self.stateScope = stateScope
        self.productionConsequenceAndRisk = productionConsequenceAndRisk
        executionBoundary = .advisoryOnlyNoTrackSmithExecutionAuthority
    }
}

public struct LogicEditorToolContext: Codable, Equatable, Sendable {
    public var identifier: String
    public var name: String
    public var areas: [String]
    public var manualPages: String
    public var documentedBehavior: String
    public var stateScope: String
    public var productionConsequenceAndRisk: String
    public var mechanismEvidenceClass: String
    public var consequenceEvidenceClass: String
    public var executionBoundary: LogicNativeExecutionBoundary
    public var mayControlLogic: Bool
    public var mayEmitAccessibilityActions: Bool
    public var mayBecomeProcessingNode: Bool
    public var exactImplementationInternalsKnown: Bool

    public init(_ knowledge: LogicEditorToolKnowledge) {
        identifier = knowledge.identifier
        name = knowledge.name
        areas = knowledge.areas
        manualPages = knowledge.manualPages
        documentedBehavior = knowledge.documentedBehavior
        stateScope = knowledge.stateScope
        productionConsequenceAndRisk = knowledge.productionConsequenceAndRisk
        mechanismEvidenceClass = "APPLE_DOCUMENTED_BEHAVIOR"
        consequenceEvidenceClass = "DERIVED_TECHNICAL_INTERPRETATION_AND_PROFESSIONAL_PRACTICE_HEURISTIC"
        executionBoundary = knowledge.executionBoundary
        mayControlLogic = false
        mayEmitAccessibilityActions = false
        mayBecomeProcessingNode = false
        exactImplementationInternalsKnown = false
    }
}

public enum LogicEditorToolKnowledgeError: Error, Equatable, Sendable {
    case wrongEntryCount(expected: Int, actual: Int)
    case invalidSourceHash
    case duplicateIdentifier(String)
    case malformedEntry(String)
    case unsafeExecutionAuthority(String)
}

public struct LogicEditorToolKnowledgeCatalog: Sendable {
    public static let expectedLogicPro12_3EntryCount = 30

    public var sourceSHA256: String
    public var reviewStatus: LogicKnowledgeReviewStatus
    public var entries: [LogicEditorToolKnowledge]

    public init(
        sourceSHA256: String,
        reviewStatus: LogicKnowledgeReviewStatus,
        entries: [LogicEditorToolKnowledge]
    ) {
        self.sourceSHA256 = sourceSHA256
        self.reviewStatus = reviewStatus
        self.entries = entries
    }

    public func validate(expectedEntryCount: Int? = nil) throws {
        if let expectedEntryCount, entries.count != expectedEntryCount {
            throw LogicEditorToolKnowledgeError.wrongEntryCount(
                expected: expectedEntryCount,
                actual: entries.count
            )
        }
        guard sourceSHA256.count == 64,
              sourceSHA256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw LogicEditorToolKnowledgeError.invalidSourceHash
        }
        var identifiers = Set<String>()
        for entry in entries {
            guard !entry.identifier.isEmpty,
                  !entry.name.isEmpty,
                  !entry.areas.isEmpty,
                  entry.areas.allSatisfy({ !$0.isEmpty }),
                  !entry.manualPages.isEmpty,
                  !entry.documentedBehavior.isEmpty,
                  !entry.stateScope.isEmpty,
                  !entry.productionConsequenceAndRisk.isEmpty,
                  entry.identifier.utf8.count <= 128,
                  entry.name.utf8.count <= 128,
                  entry.documentedBehavior.utf8.count <= 2_048,
                  entry.productionConsequenceAndRisk.utf8.count <= 2_048 else {
                throw LogicEditorToolKnowledgeError.malformedEntry(entry.identifier)
            }
            guard identifiers.insert(entry.identifier).inserted else {
                throw LogicEditorToolKnowledgeError.duplicateIdentifier(entry.identifier)
            }
            guard entry.executionBoundary == .advisoryOnlyNoTrackSmithExecutionAuthority else {
                throw LogicEditorToolKnowledgeError.unsafeExecutionAuthority(entry.identifier)
            }
        }
    }

    /// Returns editor knowledge only for explicit tool-language constructions.
    /// Generic words such as "gain", "move", "line", or "volume" never select
    /// a host tool merely because they occur in a production request.
    public func selectExplicitlyReferenced(
        request: String,
        maximumCount: Int
    ) -> [LogicEditorToolKnowledge] {
        guard maximumCount > 0 else { return [] }
        let normalized = Self.normalizedPhrase(request)
        return entries.compactMap { entry -> (LogicEditorToolKnowledge, Int)? in
            let name = Self.normalizedPhrase(entry.name)
            let patterns = [
                "\(name) tool",
                "tool \(name)",
                "use the \(name)",
                "using the \(name)",
                "with the \(name)",
                "select the \(name)",
            ]
            guard patterns.contains(where: normalized.contains) else { return nil }
            let score = normalized.contains("\(name) tool") ? 1_000 : 900
            return (entry, score)
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.identifier < rhs.0.identifier
        }.prefix(min(maximumCount, 4)).map(\.0)
    }

    private static func normalizedPhrase(_ value: String) -> String {
        value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .joined(separator: " ")
    }
}
