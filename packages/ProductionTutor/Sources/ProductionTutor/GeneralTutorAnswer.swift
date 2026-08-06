import Foundation
import PlanSchema

public enum GeneralAnswerMode: String, Codable, CaseIterable, Sendable {
    case groundedAnswer
    case clarificationNeeded
    case capabilityLimitation
    case weakCoverageWithResearchOffer
    case provisionalResearch
}

public enum AnswerConfidenceClass: String, Codable, CaseIterable, Sendable {
    case reviewedExactProcedure
    case sourceGroundedStrategy
    case professionalPracticeHeuristic
    case provisionalResearchResult
    case userConfirmedPersonalResult
    case unsupportedOrUnresolved
}

public struct GeneralStrategyOption: Codable, Equatable, Sendable {
    public var label: String
    public var purpose: String
    public var whenUseful: String
    public var whyItMayHelp: String
    public var tradeoffs: [String]
    public var preservationRisks: [String]
    public var simplestTest: String
    public var stoppingRule: String
    public var relatedProcedureIDs: [String]
    public var supportingKnowledgeIDs: [String]
    public var strategyID: String

    public init(
        label: String,
        purpose: String,
        whenUseful: String,
        whyItMayHelp: String,
        tradeoffs: [String],
        preservationRisks: [String],
        simplestTest: String,
        stoppingRule: String,
        relatedProcedureIDs: [String],
        supportingKnowledgeIDs: [String],
        strategyID: String
    ) {
        self.label = label
        self.purpose = purpose
        self.whenUseful = whenUseful
        self.whyItMayHelp = whyItMayHelp
        self.tradeoffs = tradeoffs
        self.preservationRisks = preservationRisks
        self.simplestTest = simplestTest
        self.stoppingRule = stoppingRule
        self.relatedProcedureIDs = relatedProcedureIDs
        self.supportingKnowledgeIDs = supportingKnowledgeIDs
        self.strategyID = strategyID
    }
}

/// Which measurements actually influenced the answer. Empty means the audio
/// did not change the recommendation, and the UI must say so.
public struct AudioInfluenceRecord: Codable, Equatable, Sendable {
    public var captureAvailable: Bool
    public var influencingMetricIdentifiers: [String]
    public var observedButNotResolving: [String]
    public var statement: String

    public init(
        captureAvailable: Bool,
        influencingMetricIdentifiers: [String],
        observedButNotResolving: [String],
        statement: String
    ) {
        self.captureAvailable = captureAvailable
        self.influencingMetricIdentifiers = influencingMetricIdentifiers
        self.observedButNotResolving = observedButNotResolving
        self.statement = statement
    }
}

public struct GeneralTutorAnswerContract: Codable, Equatable, Sendable {
    public var version: String
    public var questionID: UUID
    public var interpretedQuestion: String
    public var questionKind: GeneralQuestionKind
    public var domains: [ProductionDomain]
    public var answerMode: GeneralAnswerMode
    public var directAnswer: String
    public var assumptions: [String]
    public var clarificationQuestion: String?
    public var recommendedFirstMove: String?
    public var strategyOptions: [GeneralStrategyOption]
    public var exactProcedureIDs: [String]
    public var whatToListenFor: [String]
    public var preservationChecks: [String]
    public var stopConditions: [String]
    public var risksAndSideEffects: [String]
    public var alternatives: [String]
    public var nonDSPPossibilities: [String]
    public var currentContextLimitations: [String]
    public var relevantConceptIDs: [String]
    public var knowledgeClaimIDs: [String]
    public var sourceIDs: [String]
    public var contradictionIDs: [String]
    public var contradictionDisclosures: [String]
    public var confidenceClass: AnswerConfidenceClass
    public var listeningRemainsDecisive: Bool
    public var requiresCurrentResearch: Bool
    public var provisionalResearchStatus: String?
    public var unsupportedCapabilities: [String]
    public var audioInfluence: AudioInfluenceRecord
    public var teachingPrinciple: String?

    public init(
        version: String = "1.0",
        questionID: UUID,
        interpretedQuestion: String,
        questionKind: GeneralQuestionKind,
        domains: [ProductionDomain],
        answerMode: GeneralAnswerMode,
        directAnswer: String,
        assumptions: [String] = [],
        clarificationQuestion: String? = nil,
        recommendedFirstMove: String? = nil,
        strategyOptions: [GeneralStrategyOption] = [],
        exactProcedureIDs: [String] = [],
        whatToListenFor: [String] = [],
        preservationChecks: [String] = [],
        stopConditions: [String] = [],
        risksAndSideEffects: [String] = [],
        alternatives: [String] = [],
        nonDSPPossibilities: [String] = [],
        currentContextLimitations: [String] = [],
        relevantConceptIDs: [String] = [],
        knowledgeClaimIDs: [String] = [],
        sourceIDs: [String] = [],
        contradictionIDs: [String] = [],
        contradictionDisclosures: [String] = [],
        confidenceClass: AnswerConfidenceClass,
        listeningRemainsDecisive: Bool = true,
        requiresCurrentResearch: Bool = false,
        provisionalResearchStatus: String? = nil,
        unsupportedCapabilities: [String] = [],
        audioInfluence: AudioInfluenceRecord,
        teachingPrinciple: String? = nil
    ) {
        self.version = version
        self.questionID = questionID
        self.interpretedQuestion = interpretedQuestion
        self.questionKind = questionKind
        self.domains = domains
        self.answerMode = answerMode
        self.directAnswer = directAnswer
        self.assumptions = assumptions
        self.clarificationQuestion = clarificationQuestion
        self.recommendedFirstMove = recommendedFirstMove
        self.strategyOptions = strategyOptions
        self.exactProcedureIDs = exactProcedureIDs
        self.whatToListenFor = whatToListenFor
        self.preservationChecks = preservationChecks
        self.stopConditions = stopConditions
        self.risksAndSideEffects = risksAndSideEffects
        self.alternatives = alternatives
        self.nonDSPPossibilities = nonDSPPossibilities
        self.currentContextLimitations = currentContextLimitations
        self.relevantConceptIDs = relevantConceptIDs
        self.knowledgeClaimIDs = knowledgeClaimIDs
        self.sourceIDs = sourceIDs
        self.contradictionIDs = contradictionIDs
        self.contradictionDisclosures = contradictionDisclosures
        self.confidenceClass = confidenceClass
        self.listeningRemainsDecisive = listeningRemainsDecisive
        self.requiresCurrentResearch = requiresCurrentResearch
        self.provisionalResearchStatus = provisionalResearchStatus
        self.unsupportedCapabilities = unsupportedCapabilities
        self.audioInfluence = audioInfluence
        self.teachingPrinciple = teachingPrinciple
    }
}

// MARK: - Validation

public enum GeneralAnswerValidationError: Error, Equatable, Sendable {
    case unknownClaimID(String)
    case unknownSourceID(String)
    case unknownConceptID(String)
    case unknownContradictionID(String)
    case unknownProcedureID(String)
    case uncitedNumericRecommendation(String)
    case forbiddenClaim(phrase: String)
    case citationMissingForGroundedAnswer
    case audioInfluenceOverstated
    case clarificationModeWithoutQuestion
    case exactProcedureWithoutValidatedSource
    case undisclosedMaterialContradiction(String)
    case personalResultPresentedAsUniversal
}

/// Validates a materialized answer before it may be shown.
///
/// The rules that matter most: every referenced ID resolves, every numeric
/// recommendation is either cited or explicitly user-entered, no forbidden
/// claim appears, and the answer may not say the audio informed it when no
/// measurement influenced anything.
public struct GeneralTutorAnswerValidator: Sendable {
    public static let forbiddenPhrases: [String] = [
        "i changed the", "i adjusted", "i clicked", "i opened logic",
        "logic is currently set to", "i can see your", "i listened to",
        "i heard the", "trackSmith heard", "the analyzer proved",
        "this proves", "guaranteed to fix", "will definitely",
        "professionals always", "the correct setting is",
        "this is how everyone", "always use", "never use",
        "matches the artist exactly", "will sound professional",
    ]

    /// A number followed by a unit inside prose. Any such recommendation must
    /// be backed by a cited claim or come from the validated procedure catalog.
    private static let numericPattern = #"\b\d+(\.\d+)?\s*(dB|Hz|kHz|ms|:1|%|LUFS|dBFS)\b"#

    private let base: GeneralTutorKnowledgeBase
    private let procedureIDs: Set<String>

    public init(base: GeneralTutorKnowledgeBase, procedureIDs: Set<String>) {
        self.base = base
        self.procedureIDs = procedureIDs
    }

    public func validate(_ answer: GeneralTutorAnswerContract) throws {
        for id in answer.knowledgeClaimIDs where base.claim(id) == nil {
            throw GeneralAnswerValidationError.unknownClaimID(id)
        }
        for id in answer.sourceIDs where base.source(id) == nil {
            throw GeneralAnswerValidationError.unknownSourceID(id)
        }
        for id in answer.relevantConceptIDs where base.concept(id) == nil {
            throw GeneralAnswerValidationError.unknownConceptID(id)
        }
        let contradictionIDs = Set(base.contradictions.map(\.id))
        for id in answer.contradictionIDs where !contradictionIDs.contains(id) {
            throw GeneralAnswerValidationError.unknownContradictionID(id)
        }
        // Exact procedures may only ever come from the validated catalog.
        for id in answer.exactProcedureIDs where !procedureIDs.contains(id) {
            throw GeneralAnswerValidationError.unknownProcedureID(id)
        }
        for option in answer.strategyOptions {
            for id in option.relatedProcedureIDs where !procedureIDs.contains(id) {
                throw GeneralAnswerValidationError.unknownProcedureID(id)
            }
            for id in option.supportingKnowledgeIDs where base.claim(id) == nil {
                throw GeneralAnswerValidationError.unknownClaimID(id)
            }
        }

        if answer.answerMode == .clarificationNeeded, answer.clarificationQuestion == nil {
            throw GeneralAnswerValidationError.clarificationModeWithoutQuestion
        }

        // A grounded answer must cite something.
        if answer.answerMode == .groundedAnswer,
           answer.knowledgeClaimIDs.isEmpty,
           answer.relevantConceptIDs.isEmpty,
           answer.exactProcedureIDs.isEmpty {
            throw GeneralAnswerValidationError.citationMissingForGroundedAnswer
        }

        // Exact procedures require a reviewed-procedure confidence class.
        if !answer.exactProcedureIDs.isEmpty,
           answer.confidenceClass == .provisionalResearchResult {
            throw GeneralAnswerValidationError.exactProcedureWithoutValidatedSource
        }

        // A personal result must never be dressed as universal knowledge.
        if answer.confidenceClass == .userConfirmedPersonalResult {
            let text = answer.directAnswer.lowercased()
            for marker in ["in general", "for everyone", "always", "universally"]
            where text.contains(marker) {
                throw GeneralAnswerValidationError.personalResultPresentedAsUniversal
            }
        }

        try scanProse(answer)
        try validateAudioInfluence(answer)
        try validateContradictionDisclosure(answer)
    }

    private func proseFields(_ answer: GeneralTutorAnswerContract) -> [String] {
        var out = [answer.directAnswer, answer.recommendedFirstMove ?? "",
                   answer.clarificationQuestion ?? "", answer.teachingPrinciple ?? ""]
        out += answer.assumptions + answer.whatToListenFor + answer.preservationChecks
        out += answer.stopConditions + answer.risksAndSideEffects + answer.alternatives
        out += answer.nonDSPPossibilities + answer.currentContextLimitations
        out += answer.contradictionDisclosures
        for option in answer.strategyOptions {
            out += [option.label, option.purpose, option.whenUseful, option.whyItMayHelp,
                    option.simplestTest, option.stoppingRule]
            out += option.tradeoffs + option.preservationRisks
        }
        return out
    }

    private func scanProse(_ answer: GeneralTutorAnswerContract) throws {
        let fields = proseFields(answer)
        let joined = fields.joined(separator: " ").lowercased()
        for phrase in Self.forbiddenPhrases where joined.contains(phrase.lowercased()) {
            throw GeneralAnswerValidationError.forbiddenClaim(phrase: phrase)
        }

        // Any numeric recommendation must be traceable. A validated procedure
        // licenses numbers outright; otherwise each number must appear
        // verbatim in the text of a cited claim, so it came from a reviewed
        // source rather than being synthesized into the prose.
        let hasProcedure = !answer.exactProcedureIDs.isEmpty
            || answer.strategyOptions.contains { !$0.relatedProcedureIDs.isEmpty }
        guard !hasProcedure else { return }

        // Traceable source text = every cited claim, plus every reviewed
        // strategy card the answer presents by ID. Both are provenance-backed
        // knowledge, so a figure quoted from either is attributable.
        var traceable = answer.knowledgeClaimIDs.compactMap { base.claim($0)?.claimText }
        for option in answer.strategyOptions {
            guard let strategy = base.strategy(option.strategyID) else { continue }
            traceable.append(contentsOf: [
                strategy.label, strategy.problemOrOutcome,
                strategy.recommendedFirstExperiment, strategy.whyItMayHelp,
            ])
            traceable.append(contentsOf: strategy.usefulWhen)
            traceable.append(contentsOf: strategy.notUsefulWhen)
            traceable.append(contentsOf: strategy.competingInterpretations)
            traceable.append(contentsOf: strategy.expectedAudibleConsequences)
            traceable.append(contentsOf: strategy.preservationConcerns)
            traceable.append(contentsOf: strategy.tradeoffs)
            traceable.append(contentsOf: strategy.stoppingRules)
            traceable.append(contentsOf: strategy.signsStrategyIsWrong)
            traceable.append(contentsOf: strategy.nonDSPAlternatives)
        }
        for id in answer.relevantConceptIDs {
            guard let concept = base.concept(id) else { continue }
            traceable.append(contentsOf: [
                concept.simpleExplanation, concept.causalExplanation,
                concept.technicalExplanation, concept.practicalExample,
                concept.commonMisunderstanding,
            ])
        }
        let citedText = traceable.joined(separator: " ").lowercased()

        guard let expression = try? NSRegularExpression(pattern: Self.numericPattern) else { return }
        for field in fields where !field.isEmpty {
            let range = NSRange(field.startIndex..<field.endIndex, in: field)
            for match in expression.matches(in: field, range: range) {
                guard let matched = Range(match.range, in: field) else { continue }
                let literal = String(field[matched])
                // Traceable when the exact figure is present in cited source text.
                if citedText.contains(literal.lowercased()) { continue }
                throw GeneralAnswerValidationError.uncitedNumericRecommendation(literal)
            }
        }
    }

    private func validateAudioInfluence(_ answer: GeneralTutorAnswerContract) throws {
        let claimsInfluence = answer.audioInfluence.statement.lowercased()
        let assertsInfluence = claimsInfluence.contains("informed")
            || claimsInfluence.contains("influenced")
            || claimsInfluence.contains("based on your capture")
        if assertsInfluence && answer.audioInfluence.influencingMetricIdentifiers.isEmpty {
            throw GeneralAnswerValidationError.audioInfluenceOverstated
        }
        if !answer.audioInfluence.captureAvailable
            && !answer.audioInfluence.influencingMetricIdentifiers.isEmpty {
            throw GeneralAnswerValidationError.audioInfluenceOverstated
        }
    }

    private func validateContradictionDisclosure(_ answer: GeneralTutorAnswerContract) throws {
        // If a contradiction touches the cited claims, it must be disclosed.
        let cited = Set(answer.knowledgeClaimIDs)
        for record in base.contradictions {
            let touches = !Set(record.positionAClaimIDs).isDisjoint(with: cited)
                && !Set(record.positionBClaimIDs).isDisjoint(with: cited)
            if touches && !answer.contradictionIDs.contains(record.id) {
                throw GeneralAnswerValidationError.undisclosedMaterialContradiction(record.id)
            }
        }
    }
}
