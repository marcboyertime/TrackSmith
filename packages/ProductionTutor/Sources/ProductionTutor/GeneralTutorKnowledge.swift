import CryptoKit
import Foundation
import PlanSchema

// MARK: - Review lifecycle

public enum KnowledgeReviewState: String, Codable, CaseIterable, Sendable {
    case discovered
    case acquired
    case machineExtracted
    case awaitingReview
    case reviewed
    case directlyVerified
    case disputed
    case superseded
    case rejected

    /// Only reviewed or directly verified knowledge may ground a material
    /// factual claim in an answer.
    public var isTrusted: Bool { self == .reviewed || self == .directlyVerified }
}

public enum SourceHandlingClass: String, Codable, CaseIterable, Sendable {
    case openDocumentation
    case licensedLocalReviewOnly
    case publicWebMetadataOnly
    case userOwnedLocalOnly
    case trackSmithGenerated
}

// MARK: - Source registry

public struct SourceRegistryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var type: String
    public var title: String
    public var creatorOrPublisher: String?
    public var locator: String?
    public var publicationDate: String?
    public var retrievalDate: String?
    public var exactVersion: String?
    public var rightsBasis: String
    public var handlingClass: SourceHandlingClass
    public var tier: SourceTier
    public var transcriptAvailable: Bool
    public var transcriptIsAutomatic: Bool
    public var requiresAudiovisualReview: Bool
    public var audiovisualReviewCompleted: Bool
    public var contentSHA256: [String]
    public var limitations: [String]
    public var supersededBy: String?

    public init(
        id: String,
        type: String,
        title: String,
        creatorOrPublisher: String? = nil,
        locator: String? = nil,
        publicationDate: String? = nil,
        retrievalDate: String? = nil,
        exactVersion: String? = nil,
        rightsBasis: String,
        handlingClass: SourceHandlingClass,
        tier: SourceTier,
        transcriptAvailable: Bool = false,
        transcriptIsAutomatic: Bool = false,
        requiresAudiovisualReview: Bool = false,
        audiovisualReviewCompleted: Bool = false,
        contentSHA256: [String] = [],
        limitations: [String] = [],
        supersededBy: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.creatorOrPublisher = creatorOrPublisher
        self.locator = locator
        self.publicationDate = publicationDate
        self.retrievalDate = retrievalDate
        self.exactVersion = exactVersion
        self.rightsBasis = rightsBasis
        self.handlingClass = handlingClass
        self.tier = tier
        self.transcriptAvailable = transcriptAvailable
        self.transcriptIsAutomatic = transcriptIsAutomatic
        self.requiresAudiovisualReview = requiresAudiovisualReview
        self.audiovisualReviewCompleted = audiovisualReviewCompleted
        self.contentSHA256 = contentSHA256
        self.limitations = limitations
        self.supersededBy = supersededBy
    }

    /// A source whose claims depend on hearing or seeing something, but whose
    /// audiovisual review has not happened, cannot ground a material claim.
    public var isUsableForMaterialClaims: Bool {
        if supersededBy != nil { return false }
        if requiresAudiovisualReview && !audiovisualReviewCompleted { return false }
        return true
    }
}

// MARK: - Knowledge cards

public struct ProductionKnowledgeClaim: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var version: String
    public var claimText: String
    public var domains: [ProductionDomain]
    public var applicableSourceTypes: [SourceType]
    public var applicableQuestionKinds: [GeneralQuestionKind]
    public var conditions: [String]
    public var evidenceClass: GeneralEvidenceClass
    public var sourceID: String
    public var sourceLocation: String?
    public var reviewState: KnowledgeReviewState
    public var contradictsClaimIDs: [String]
    public var limitations: [String]
    public var listeningRemainsDecisive: Bool
    public var containsNumericRange: Bool
    public var numericRangeKind: String?

    public init(
        id: String,
        version: String = "1.0",
        claimText: String,
        domains: [ProductionDomain],
        applicableSourceTypes: [SourceType] = [],
        applicableQuestionKinds: [GeneralQuestionKind] = [],
        conditions: [String] = [],
        evidenceClass: GeneralEvidenceClass,
        sourceID: String,
        sourceLocation: String? = nil,
        reviewState: KnowledgeReviewState,
        contradictsClaimIDs: [String] = [],
        limitations: [String] = [],
        listeningRemainsDecisive: Bool = true,
        containsNumericRange: Bool = false,
        numericRangeKind: String? = nil
    ) {
        self.id = id
        self.version = version
        self.claimText = claimText
        self.domains = domains
        self.applicableSourceTypes = applicableSourceTypes
        self.applicableQuestionKinds = applicableQuestionKinds
        self.conditions = conditions
        self.evidenceClass = evidenceClass
        self.sourceID = sourceID
        self.sourceLocation = sourceLocation
        self.reviewState = reviewState
        self.contradictsClaimIDs = contradictsClaimIDs
        self.limitations = limitations
        self.listeningRemainsDecisive = listeningRemainsDecisive
        self.containsNumericRange = containsNumericRange
        self.numericRangeKind = numericRangeKind
    }
}

/// A decision pattern, not a preset. Strategy cards are what let the tutor
/// answer broadly without inventing exact settings.
public struct ProductionStrategyCard: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var version: String
    public var label: String
    public var problemOrOutcome: String
    public var domains: [ProductionDomain]
    public var applicableSourceTypes: [SourceType]
    public var applicableQuestionKinds: [GeneralQuestionKind]
    public var usefulWhen: [String]
    public var notUsefulWhen: [String]
    public var competingInterpretations: [String]
    public var recommendedFirstExperiment: String
    public var whyItMayHelp: String
    public var expectedAudibleConsequences: [String]
    public var preservationConcerns: [String]
    public var tradeoffs: [String]
    public var stoppingRules: [String]
    public var signsStrategyIsWrong: [String]
    public var nonDSPAlternatives: [String]
    public var relatedProcedureIDs: [String]
    public var supportingClaimIDs: [String]
    public var contradictingClaimIDs: [String]
    public var evidenceClass: GeneralEvidenceClass
    public var reviewState: KnowledgeReviewState

    public init(
        id: String,
        version: String = "1.0",
        label: String,
        problemOrOutcome: String,
        domains: [ProductionDomain],
        applicableSourceTypes: [SourceType] = [],
        applicableQuestionKinds: [GeneralQuestionKind] = [],
        usefulWhen: [String] = [],
        notUsefulWhen: [String] = [],
        competingInterpretations: [String] = [],
        recommendedFirstExperiment: String,
        whyItMayHelp: String,
        expectedAudibleConsequences: [String] = [],
        preservationConcerns: [String] = [],
        tradeoffs: [String] = [],
        stoppingRules: [String] = [],
        signsStrategyIsWrong: [String] = [],
        nonDSPAlternatives: [String] = [],
        relatedProcedureIDs: [String] = [],
        supportingClaimIDs: [String] = [],
        contradictingClaimIDs: [String] = [],
        evidenceClass: GeneralEvidenceClass,
        reviewState: KnowledgeReviewState
    ) {
        self.id = id
        self.version = version
        self.label = label
        self.problemOrOutcome = problemOrOutcome
        self.domains = domains
        self.applicableSourceTypes = applicableSourceTypes
        self.applicableQuestionKinds = applicableQuestionKinds
        self.usefulWhen = usefulWhen
        self.notUsefulWhen = notUsefulWhen
        self.competingInterpretations = competingInterpretations
        self.recommendedFirstExperiment = recommendedFirstExperiment
        self.whyItMayHelp = whyItMayHelp
        self.expectedAudibleConsequences = expectedAudibleConsequences
        self.preservationConcerns = preservationConcerns
        self.tradeoffs = tradeoffs
        self.stoppingRules = stoppingRules
        self.signsStrategyIsWrong = signsStrategyIsWrong
        self.nonDSPAlternatives = nonDSPAlternatives
        self.relatedProcedureIDs = relatedProcedureIDs
        self.supportingClaimIDs = supportingClaimIDs
        self.contradictingClaimIDs = contradictingClaimIDs
        self.evidenceClass = evidenceClass
        self.reviewState = reviewState
    }
}

public struct ProductionConceptCard: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var version: String
    public var term: String
    public var aliases: [String]
    public var domains: [ProductionDomain]
    public var simpleExplanation: String
    public var causalExplanation: String
    public var technicalExplanation: String
    public var practicalExample: String
    public var commonMisunderstanding: String
    public var whereItMatters: [String]
    public var relatedProcedureIDs: [String]
    public var sourceIDs: [String]
    public var reviewState: KnowledgeReviewState

    public init(
        id: String,
        version: String = "1.0",
        term: String,
        aliases: [String] = [],
        domains: [ProductionDomain],
        simpleExplanation: String,
        causalExplanation: String,
        technicalExplanation: String,
        practicalExample: String,
        commonMisunderstanding: String,
        whereItMatters: [String] = [],
        relatedProcedureIDs: [String] = [],
        sourceIDs: [String] = [],
        reviewState: KnowledgeReviewState
    ) {
        self.id = id
        self.version = version
        self.term = term
        self.aliases = aliases
        self.domains = domains
        self.simpleExplanation = simpleExplanation
        self.causalExplanation = causalExplanation
        self.technicalExplanation = technicalExplanation
        self.practicalExample = practicalExample
        self.commonMisunderstanding = commonMisunderstanding
        self.whereItMatters = whereItMatters
        self.relatedProcedureIDs = relatedProcedureIDs
        self.sourceIDs = sourceIDs
        self.reviewState = reviewState
    }
}

/// An explicitly preserved disagreement. Contradictions are disclosed, never
/// silently resolved by picking a winner.
public struct ContradictionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var topic: String
    public var domains: [ProductionDomain]
    public var positionAClaimIDs: [String]
    public var positionASummary: String
    public var positionBClaimIDs: [String]
    public var positionBSummary: String
    public var whatDeterminesWhichApplies: String
    public var resolvedByEvidence: Bool

    public init(
        id: String,
        topic: String,
        domains: [ProductionDomain],
        positionAClaimIDs: [String],
        positionASummary: String,
        positionBClaimIDs: [String],
        positionBSummary: String,
        whatDeterminesWhichApplies: String,
        resolvedByEvidence: Bool = false
    ) {
        self.id = id
        self.topic = topic
        self.domains = domains
        self.positionAClaimIDs = positionAClaimIDs
        self.positionASummary = positionASummary
        self.positionBClaimIDs = positionBClaimIDs
        self.positionBSummary = positionBSummary
        self.whatDeterminesWhichApplies = whatDeterminesWhichApplies
        self.resolvedByEvidence = resolvedByEvidence
    }
}

/// A result the user explicitly confirmed for their own material. Never
/// generalized, never presented as universal production truth.
public struct PersonalOutcomeRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var recordedAt: Date
    public var question: String
    public var sourceType: SourceType
    public var contextSummary: String
    public var procedureID: String?
    public var strategyID: String?
    public var feedback: TutorFeedback
    public var userEnteredSettings: [String]
    public var whatImproved: String?
    public var whatDidNot: String?
    public var whatWasPreserved: String?
    public var userAskedToRemember: Bool

    public init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        question: String,
        sourceType: SourceType,
        contextSummary: String = "",
        procedureID: String? = nil,
        strategyID: String? = nil,
        feedback: TutorFeedback,
        userEnteredSettings: [String] = [],
        whatImproved: String? = nil,
        whatDidNot: String? = nil,
        whatWasPreserved: String? = nil,
        userAskedToRemember: Bool
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.question = question
        self.sourceType = sourceType
        self.contextSummary = contextSummary
        self.procedureID = procedureID
        self.strategyID = strategyID
        self.feedback = feedback
        self.userEnteredSettings = userEnteredSettings
        self.whatImproved = whatImproved
        self.whatDidNot = whatDidNot
        self.whatWasPreserved = whatWasPreserved
        self.userAskedToRemember = userAskedToRemember
    }
}

// MARK: - Knowledge base

public struct GeneralTutorKnowledgeBase: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var builtAt: String
    public var sources: [SourceRegistryEntry]
    public var claims: [ProductionKnowledgeClaim]
    public var strategies: [ProductionStrategyCard]
    public var concepts: [ProductionConceptCard]
    public var contradictions: [ContradictionRecord]

    public init(
        schemaVersion: String,
        builtAt: String,
        sources: [SourceRegistryEntry],
        claims: [ProductionKnowledgeClaim],
        strategies: [ProductionStrategyCard],
        concepts: [ProductionConceptCard],
        contradictions: [ContradictionRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.builtAt = builtAt
        self.sources = sources
        self.claims = claims
        self.strategies = strategies
        self.concepts = concepts
        self.contradictions = contradictions
    }

    public func source(_ id: String) -> SourceRegistryEntry? { sources.first { $0.id == id } }
    public func claim(_ id: String) -> ProductionKnowledgeClaim? { claims.first { $0.id == id } }
    public func strategy(_ id: String) -> ProductionStrategyCard? { strategies.first { $0.id == id } }
    public func concept(_ id: String) -> ProductionConceptCard? { concepts.first { $0.id == id } }

    public static func loadValidated() throws -> GeneralTutorKnowledgeBase {
        let payload = Data(GeneralTutorKnowledgeGenerated.knowledgeJSON.utf8)
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        guard digest == GeneralTutorKnowledgeGenerated.sourceArtifactSHA256 else {
            throw GeneralTutorKnowledgeError.checksumMismatch(
                expected: GeneralTutorKnowledgeGenerated.sourceArtifactSHA256, actual: digest
            )
        }
        let base = try JSONDecoder().decode(GeneralTutorKnowledgeBase.self, from: payload)
        try GeneralTutorKnowledgeValidator().validate(base)
        return base
    }
}

public enum GeneralTutorKnowledgeError: Error, Equatable, Sendable {
    case checksumMismatch(expected: String, actual: String)
    case duplicateID(String)
    case unknownSource(card: String, source: String)
    case unusableSourceForMaterialClaim(card: String, source: String)
    case tierCSourceForTrustedClaim(card: String, source: String)
    case untrustedClaimInTrustedStrategy(strategy: String, claim: String)
    case unknownClaimReference(card: String, claim: String)
    case unknownContradictionClaim(record: String, claim: String)
    case emptyKnowledgeBase
}

/// Fail-closed structural validation of the knowledge base.
public struct GeneralTutorKnowledgeValidator: Sendable {
    public init() {}

    public func validate(_ base: GeneralTutorKnowledgeBase) throws {
        guard !base.claims.isEmpty || !base.strategies.isEmpty else {
            throw GeneralTutorKnowledgeError.emptyKnowledgeBase
        }
        var ids = Set<String>()
        for source in base.sources {
            guard ids.insert("src:" + source.id).inserted else {
                throw GeneralTutorKnowledgeError.duplicateID(source.id)
            }
        }
        let claimIDs = Set(base.claims.map(\.id))

        for claim in base.claims {
            guard ids.insert("claim:" + claim.id).inserted else {
                throw GeneralTutorKnowledgeError.duplicateID(claim.id)
            }
            guard let source = base.source(claim.sourceID) else {
                throw GeneralTutorKnowledgeError.unknownSource(card: claim.id, source: claim.sourceID)
            }
            // A trusted claim may not rest on a source that still needs
            // audiovisual review or has been superseded.
            if claim.reviewState.isTrusted, !source.isUsableForMaterialClaims {
                throw GeneralTutorKnowledgeError.unusableSourceForMaterialClaim(
                    card: claim.id, source: source.id
                )
            }
            // Community/discovery sources can teach retrieval language and
            // candidate hypotheses, never ground trusted material claims.
            if claim.reviewState.isTrusted, source.tier == .tierCDiscoveryOrAnecdotal {
                throw GeneralTutorKnowledgeError.tierCSourceForTrustedClaim(
                    card: claim.id, source: source.id
                )
            }
            for reference in claim.contradictsClaimIDs where !claimIDs.contains(reference) {
                throw GeneralTutorKnowledgeError.unknownClaimReference(card: claim.id, claim: reference)
            }
        }

        for strategy in base.strategies {
            guard ids.insert("strategy:" + strategy.id).inserted else {
                throw GeneralTutorKnowledgeError.duplicateID(strategy.id)
            }
            for reference in strategy.supportingClaimIDs + strategy.contradictingClaimIDs {
                guard let claim = base.claim(reference) else {
                    throw GeneralTutorKnowledgeError.unknownClaimReference(
                        card: strategy.id, claim: reference
                    )
                }
                // A reviewed strategy cannot be supported by unreviewed material.
                if strategy.reviewState.isTrusted,
                   strategy.supportingClaimIDs.contains(reference),
                   !claim.reviewState.isTrusted {
                    throw GeneralTutorKnowledgeError.untrustedClaimInTrustedStrategy(
                        strategy: strategy.id, claim: reference
                    )
                }
            }
        }

        for concept in base.concepts {
            guard ids.insert("concept:" + concept.id).inserted else {
                throw GeneralTutorKnowledgeError.duplicateID(concept.id)
            }
            for reference in concept.sourceIDs where base.source(reference) == nil {
                throw GeneralTutorKnowledgeError.unknownSource(card: concept.id, source: reference)
            }
        }

        for record in base.contradictions {
            guard ids.insert("contradiction:" + record.id).inserted else {
                throw GeneralTutorKnowledgeError.duplicateID(record.id)
            }
            for reference in record.positionAClaimIDs + record.positionBClaimIDs
            where !claimIDs.contains(reference) {
                throw GeneralTutorKnowledgeError.unknownContradictionClaim(
                    record: record.id, claim: reference
                )
            }
        }
    }
}
