import AgentCore
import Foundation
import PlanSchema

public enum AbstractLanguageResolutionPolicy: String, Codable, CaseIterable, Sendable {
    case singleBoundedHypothesis
    case multipleNamedHypotheses
    case clarificationWhenMaterial
    case nonDSPAdvisory
}

public enum AbstractLanguageKnowledgeReviewStatus: String, Codable, Sendable {
    /// Primary sources support the role/scope/ambiguity architecture. The
    /// production senses themselves remain professional-practice hypotheses.
    case primaryRoleResearchDeepReadProductionSensesRemainHeuristic
}

public enum AbstractLanguageExecutionBoundary: String, Codable, Sendable {
    case advisoryOnlyNoTrackSmithExecutionAuthority
}

public struct AbstractMusicianLanguageSense: Codable, Equatable, Sendable {
    public var sourceTypes: Set<SourceType>
    public var interpretation: String
    public var supportingEvidenceCategories: [String]
    public var contradictoryEvidence: [String]
    public var candidateStrategyCategories: Set<ProductionDSPStrategy>
    public var unsupportedOrNonDSPConsiderations: [String]

    public init(
        sourceTypes: Set<SourceType>,
        interpretation: String,
        supportingEvidenceCategories: [String],
        contradictoryEvidence: [String],
        candidateStrategyCategories: Set<ProductionDSPStrategy>,
        unsupportedOrNonDSPConsiderations: [String]
    ) {
        self.sourceTypes = sourceTypes
        self.interpretation = interpretation
        self.supportingEvidenceCategories = supportingEvidenceCategories
        self.contradictoryEvidence = contradictoryEvidence
        self.candidateStrategyCategories = candidateStrategyCategories
        self.unsupportedOrNonDSPConsiderations = unsupportedOrNonDSPConsiderations
    }
}

/// A bounded interpretation aid for language such as “expensive,” “alive,” or
/// “bedroom-recorded.” This type intentionally contains no NodeType, raw
/// parameter, host action, automation instruction, or executable payload.
public struct AbstractMusicianLanguageKnowledge: Codable, Equatable, Sendable {
    public var identifier: String
    public var surfaceForm: String
    public var aliases: [String]
    public var applicableSourceTypes: Set<SourceType>
    public var canonicalCandidateTerms: Set<ProductionTerm>
    public var resolutionPolicy: AbstractLanguageResolutionPolicy
    public var possibleSenses: [AbstractMusicianLanguageSense]
    public var preservationRisks: [String]
    public var provenanceReferences: [String]
    public var confidence: Double
    public var prohibitedMapping: String
    public let evidenceClass: ProductionEvidenceClass
    public let executionBoundary: AbstractLanguageExecutionBoundary
    public let subjectiveListeningDecisive: Bool

    public init(
        identifier: String,
        surfaceForm: String,
        aliases: [String],
        applicableSourceTypes: Set<SourceType>,
        canonicalCandidateTerms: Set<ProductionTerm>,
        resolutionPolicy: AbstractLanguageResolutionPolicy,
        possibleSenses: [AbstractMusicianLanguageSense],
        preservationRisks: [String],
        provenanceReferences: [String],
        confidence: Double,
        prohibitedMapping: String
    ) {
        self.identifier = identifier
        self.surfaceForm = surfaceForm
        self.aliases = aliases
        self.applicableSourceTypes = applicableSourceTypes
        self.canonicalCandidateTerms = canonicalCandidateTerms
        self.resolutionPolicy = resolutionPolicy
        self.possibleSenses = possibleSenses
        self.preservationRisks = preservationRisks
        self.provenanceReferences = provenanceReferences
        self.confidence = min(max(confidence, 0), 1)
        self.prohibitedMapping = prohibitedMapping
        evidenceClass = .professionalPracticeHeuristic
        executionBoundary = .advisoryOnlyNoTrackSmithExecutionAuthority
        subjectiveListeningDecisive = true
    }
}

public enum AbstractMusicianLanguageKnowledgeError: Error, Equatable, Sendable {
    case wrongEntryCount(expected: Int, actual: Int)
    case duplicateIdentifier(String)
    case malformedEntry(String)
    case unsupportedSourceType(String)
    case unsupportedStrategy(String, ProductionDSPStrategy)
    case missingSourceSense(String, SourceType)
}

/// Provider context form. The explicit false authority fields are deliberate:
/// an untrusted model can read this advisory but cannot promote it into a fact,
/// capability, measurement, node, or host command.
public struct AbstractMusicianLanguageContext: Codable, Equatable, Sendable {
    public var identifier: String
    public var surfaceForm: String
    public var possibleInterpretations: [String]
    public var candidateCanonicalTerms: [ProductionTerm]
    public var supportingEvidenceCategories: [String]
    public var contradictoryEvidence: [String]
    public var candidateStrategyCategories: [ProductionDSPStrategy]
    public var unsupportedOrNonDSPConsiderations: [String]
    public var preservationRisks: [String]
    public var resolutionPolicy: AbstractLanguageResolutionPolicy
    public var evidenceClass: ProductionEvidenceClass
    public var provenanceReferences: [String]
    public var confidence: Double
    public var prohibitedMapping: String
    public var executionBoundary: AbstractLanguageExecutionBoundary
    public var mayBecomeProcessingNode: Bool
    public var mayControlLogicOrAutomation: Bool
    public var mayCreateMeasuredEvidence: Bool
    public var mayOverrideUserConstraints: Bool
    public var subjectiveListeningDecisive: Bool

    public init(_ knowledge: AbstractMusicianLanguageKnowledge, sourceType: SourceType) {
        let senses = knowledge.possibleSenses.filter { $0.sourceTypes.contains(sourceType) }
        identifier = knowledge.identifier
        surfaceForm = knowledge.surfaceForm
        possibleInterpretations = senses.map(\.interpretation)
        candidateCanonicalTerms = knowledge.canonicalCandidateTerms.sorted { $0.rawValue < $1.rawValue }
        supportingEvidenceCategories = senses.flatMap(\.supportingEvidenceCategories).uniqued().sorted()
        contradictoryEvidence = senses.flatMap(\.contradictoryEvidence).uniqued().sorted()
        candidateStrategyCategories = senses.flatMap(\.candidateStrategyCategories)
            .uniqued().sorted { $0.rawValue < $1.rawValue }
        unsupportedOrNonDSPConsiderations = senses.flatMap(\.unsupportedOrNonDSPConsiderations)
            .uniqued().sorted()
        preservationRisks = knowledge.preservationRisks
        resolutionPolicy = knowledge.resolutionPolicy
        evidenceClass = knowledge.evidenceClass
        provenanceReferences = knowledge.provenanceReferences
        confidence = knowledge.confidence
        prohibitedMapping = knowledge.prohibitedMapping
        executionBoundary = knowledge.executionBoundary
        mayBecomeProcessingNode = false
        mayControlLogicOrAutomation = false
        mayCreateMeasuredEvidence = false
        mayOverrideUserConstraints = false
        subjectiveListeningDecisive = knowledge.subjectiveListeningDecisive
    }
}

public struct AbstractMusicianLanguageKnowledgeCatalog: Sendable {
    public static let expectedTrackSmithV1EntryCount = 14

    public var sourceSHA256: String
    public var ontologyVersion: String
    public var reviewStatus: AbstractLanguageKnowledgeReviewStatus
    public var entries: [AbstractMusicianLanguageKnowledge]

    public init(
        sourceSHA256: String,
        ontologyVersion: String,
        reviewStatus: AbstractLanguageKnowledgeReviewStatus,
        entries: [AbstractMusicianLanguageKnowledge]
    ) {
        self.sourceSHA256 = sourceSHA256
        self.ontologyVersion = ontologyVersion
        self.reviewStatus = reviewStatus
        self.entries = entries
    }

    public func validate(expectedEntryCount: Int? = nil) throws {
        if let expectedEntryCount, entries.count != expectedEntryCount {
            throw AbstractMusicianLanguageKnowledgeError.wrongEntryCount(
                expected: expectedEntryCount,
                actual: entries.count
            )
        }
        var identifiers = Set<String>()
        for entry in entries {
            guard !entry.identifier.isEmpty,
                  entry.identifier.utf8.count <= 96,
                  !entry.surfaceForm.isEmpty,
                  entry.surfaceForm.utf8.count <= 128,
                  !entry.aliases.isEmpty,
                  entry.aliases.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }),
                  !entry.applicableSourceTypes.isEmpty,
                  !entry.canonicalCandidateTerms.isEmpty,
                  !entry.possibleSenses.isEmpty,
                  !entry.preservationRisks.isEmpty,
                  !entry.provenanceReferences.isEmpty,
                  !entry.prohibitedMapping.isEmpty,
                  entry.prohibitedMapping.utf8.count <= 1_024,
                  (0...1).contains(entry.confidence),
                  entry.evidenceClass == .professionalPracticeHeuristic,
                  entry.executionBoundary == .advisoryOnlyNoTrackSmithExecutionAuthority,
                  entry.subjectiveListeningDecisive else {
                throw AbstractMusicianLanguageKnowledgeError.malformedEntry(entry.identifier)
            }
            guard identifiers.insert(entry.identifier).inserted else {
                throw AbstractMusicianLanguageKnowledgeError.duplicateIdentifier(entry.identifier)
            }
            guard !entry.applicableSourceTypes.contains(.reference),
                  !entry.applicableSourceTypes.contains(.unknown) else {
                throw AbstractMusicianLanguageKnowledgeError.unsupportedSourceType(entry.identifier)
            }
            for sourceType in entry.applicableSourceTypes where !entry.possibleSenses.contains(
                where: { $0.sourceTypes.contains(sourceType) }
            ) {
                throw AbstractMusicianLanguageKnowledgeError.missingSourceSense(
                    entry.identifier,
                    sourceType
                )
            }
            for sense in entry.possibleSenses {
                guard !sense.sourceTypes.isEmpty,
                      sense.sourceTypes.isSubset(of: entry.applicableSourceTypes),
                      !sense.interpretation.isEmpty,
                      sense.interpretation.utf8.count <= 2_048,
                      !sense.supportingEvidenceCategories.isEmpty,
                      !sense.contradictoryEvidence.isEmpty,
                      !sense.candidateStrategyCategories.isEmpty,
                      !sense.unsupportedOrNonDSPConsiderations.isEmpty else {
                    throw AbstractMusicianLanguageKnowledgeError.malformedEntry(entry.identifier)
                }
                for strategy in sense.candidateStrategyCategories
                where !ModelOutputValidator.defaultSupportedStrategies.contains(strategy) {
                    throw AbstractMusicianLanguageKnowledgeError.unsupportedStrategy(
                        entry.identifier,
                        strategy
                    )
                }
            }
        }
    }

    /// Exact bounded phrase retrieval only. No embedding, provider output, file
    /// metadata, or inferred synonym can introduce an entry.
    public func select(
        request: String,
        sourceType: SourceType,
        maximumCount: Int
    ) -> [AbstractMusicianLanguageKnowledge] {
        guard maximumCount > 0 else { return [] }
        let normalizedRequest = Self.normalizedPhrase(request)
        let paddedRequest = " \(normalizedRequest) "
        return entries.compactMap { entry -> (AbstractMusicianLanguageKnowledge, Int)? in
            guard entry.applicableSourceTypes.contains(sourceType) else { return nil }
            let phrases = ([entry.surfaceForm] + entry.aliases).map(Self.normalizedPhrase)
                .filter { !$0.isEmpty }
            let matched = phrases.filter { paddedRequest.contains(" \($0) ") }
            guard !matched.isEmpty else { return nil }
            let longest = matched.map(\.count).max() ?? 0
            let surfaceBonus = matched.contains(Self.normalizedPhrase(entry.surfaceForm)) ? 400 : 0
            return (entry, 1_000 + surfaceBonus + longest)
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.identifier < rhs.0.identifier
        }.prefix(maximumCount).map(\.0)
    }

    private static func normalizedPhrase(_ value: String) -> String {
        value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .joined(separator: " ")
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
