import Foundation
import PlanSchema

public struct GeneralCorpusCase: Codable, Equatable, Sendable {
    public var caseID: String
    public var question: String
    public var sourceType: SourceType
    public var provenance: String
    public var expectedAnyDomain: [String]
    public var expectedKind: String?
    public var captureAvailable: Bool
    public var mustNotContain: [String]
    public var requireAssumptions: Bool
    public var requireLimitationDisclosure: Bool
    public var adversarialCategory: String?
    public var expectedAnswerMode: String?
    /// Multi-turn membership. Turns of one conversation share an ID and are
    /// ordered by index; each must independently produce a validated answer.
    public var conversationID: String?
    public var turnIndex: Int?
}

/// A retrieval precision/recall case: cards that must be retrievable for a
/// question, and cards that must not dominate it.
public struct GeneralRetrievalCase: Codable, Equatable, Sendable {
    public var caseID: String
    public var question: String
    public var sourceType: SourceType
    public var expectConceptIDs: [String]?
    public var forbidConceptIDs: [String]?
    public var expectStrategyIDs: [String]?
    public var forbidStrategyIDs: [String]?
}

public struct GeneralRetrievalResult: Codable, Equatable, Sendable {
    public var caseID: String
    public var passed: Bool
    public var failures: [String]
    public var retrievedConceptIDs: [String]
    public var retrievedStrategyIDs: [String]
}

public struct GeneralCorpus: Codable, Equatable, Sendable {
    public var version: String
    public var caseCount: Int
    public var cases: [GeneralCorpusCase]
    public var retrievalCases: [GeneralRetrievalCase]?
}

public struct GeneralCaseResult: Codable, Equatable, Sendable {
    public var caseID: String
    public var passed: Bool
    public var failures: [String]
    public var routedKind: String
    public var routedDomains: [String]
    public var answerMode: String
    public var confidenceClass: String
    public var citedClaimCount: Int
    public var citedSourceCount: Int
    public var strategyOptionCount: Int
    public var exactProcedureIDs: [String]
    public var contradictionIDs: [String]
    public var audioInfluenced: Bool
    public var coverage: String
}

public struct GeneralEvaluationReport: Codable, Equatable, Sendable {
    public var corpusVersion: String
    public var caseCount: Int
    public var passedCount: Int
    public var answerModeCounts: [String: Int]
    public var domainsExercised: [String]
    public var questionKindsExercised: [String]
    public var conversationCount: Int
    public var multiTurnTurnCount: Int
    public var retrievalCaseCount: Int
    public var retrievalPassedCount: Int
    public var results: [GeneralCaseResult]
    public var retrievalResults: [GeneralRetrievalResult]
}

/// Deterministic offline evaluation of the open-domain path.
///
/// Every case is routed, retrieved, synthesized, and validated exactly as the
/// product would do it. No network, no provider, no raw audio in the report.
public struct GeneralTutorEvaluationHarness: Sendable {
    private let coordinator: GeneralTutorCoordinator

    public init(coordinator: GeneralTutorCoordinator) {
        self.coordinator = coordinator
    }

    public init() throws {
        self.coordinator = try GeneralTutorCoordinator()
    }

    public func run(_ corpus: GeneralCorpus) -> GeneralEvaluationReport {
        var results: [GeneralCaseResult] = []
        var modes: [String: Int] = [:]
        var domains = Set<String>()
        var kinds = Set<String>()

        var conversations = Set<String>()
        var multiTurnTurns = 0

        // Multi-turn cases are evaluated in conversation order so a later turn
        // is exercised only after its predecessors have been answered.
        let ordered = corpus.cases.sorted { left, right in
            switch (left.conversationID, right.conversationID) {
            case let (l?, r?) where l == r: return (left.turnIndex ?? 0) < (right.turnIndex ?? 0)
            default: return left.caseID < right.caseID
            }
        }
        for testCase in ordered {
            let result = evaluate(testCase)
            modes[result.answerMode, default: 0] += 1
            domains.formUnion(result.routedDomains)
            kinds.insert(result.routedKind)
            if let conversation = testCase.conversationID {
                conversations.insert(conversation)
                multiTurnTurns += 1
            }
            results.append(result)
        }

        let retrievalResults = (corpus.retrievalCases ?? []).map(evaluateRetrieval)

        return GeneralEvaluationReport(
            corpusVersion: corpus.version,
            caseCount: results.count,
            passedCount: results.filter(\.passed).count,
            answerModeCounts: modes,
            domainsExercised: domains.sorted(),
            questionKindsExercised: kinds.sorted(),
            conversationCount: conversations.count,
            multiTurnTurnCount: multiTurnTurns,
            retrievalCaseCount: retrievalResults.count,
            retrievalPassedCount: retrievalResults.filter(\.passed).count,
            results: results,
            retrievalResults: retrievalResults
        )
    }

    /// Checks that the retriever surfaces the cards a question needs and does
    /// not let unrelated cards dominate it.
    public func evaluateRetrieval(_ testCase: GeneralRetrievalCase) -> GeneralRetrievalResult {
        var failures: [String] = []
        let outcome = try? coordinator.answer(
            GeneralTutorRequest(question: testCase.question, sourceType: testCase.sourceType)
        )
        guard let outcome else {
            return GeneralRetrievalResult(
                caseID: testCase.caseID, passed: false,
                failures: ["coordinator threw"], retrievedConceptIDs: [], retrievedStrategyIDs: []
            )
        }
        let concepts = outcome.retrieved.concepts.map(\.id)
        let strategies = outcome.retrieved.strategies.map(\.id)

        for id in testCase.expectConceptIDs ?? [] where !concepts.contains(id) {
            failures.append("expected concept not retrieved: \(id)")
        }
        for id in testCase.forbidConceptIDs ?? [] where concepts.first == id {
            failures.append("forbidden concept ranked first: \(id)")
        }
        for id in testCase.expectStrategyIDs ?? [] where !strategies.contains(id) {
            failures.append("expected strategy not retrieved: \(id)")
        }
        for id in testCase.forbidStrategyIDs ?? [] where strategies.first == id {
            failures.append("forbidden strategy ranked first: \(id)")
        }
        return GeneralRetrievalResult(
            caseID: testCase.caseID,
            passed: failures.isEmpty,
            failures: failures,
            retrievedConceptIDs: concepts,
            retrievedStrategyIDs: strategies
        )
    }

    public func evaluate(_ testCase: GeneralCorpusCase) -> GeneralCaseResult {
        var failures: [String] = []
        let request = GeneralTutorRequest(
            question: testCase.question,
            sourceType: testCase.sourceType,
            explanationDepth: .standard
        )

        let outcome: GeneralTutorOutcome
        do { outcome = try coordinator.answer(request) }
        catch {
            return GeneralCaseResult(
                caseID: testCase.caseID, passed: false,
                failures: ["coordinator threw: \(error)"],
                routedKind: "-", routedDomains: [], answerMode: "-", confidenceClass: "-",
                citedClaimCount: 0, citedSourceCount: 0, strategyOptionCount: 0,
                exactProcedureIDs: [], contradictionIDs: [], audioInfluenced: false,
                coverage: "-"
            )
        }

        let answer = outcome.answer
        let intent = outcome.intent

        // Expected routing, when the case declares it.
        if let expected = testCase.expectedKind, intent.questionKind.rawValue != expected {
            failures.append("kind \(intent.questionKind.rawValue) expected \(expected)")
        }
        // At least one expected domain must be routed. Requiring all of them
        // would assert taxonomy precision the product does not need.
        let routed = Set(intent.allDomains.map(\.rawValue))
        if !testCase.expectedAnyDomain.isEmpty,
           routed.isDisjoint(with: Set(testCase.expectedAnyDomain)) {
            failures.append("routed none of the expected domains \(testCase.expectedAnyDomain)")
        }
        if let mode = testCase.expectedAnswerMode, answer.answerMode.rawValue != mode {
            failures.append("answerMode \(answer.answerMode.rawValue) expected \(mode)")
        }

        // Universal honesty invariants applied to every case.
        let prose = ([answer.directAnswer, answer.recommendedFirstMove ?? "",
                      answer.teachingPrinciple ?? ""] + answer.assumptions
                     + answer.currentContextLimitations).joined(separator: " ").lowercased()
        for banned in testCase.mustNotContain where prose.contains(banned.lowercased()) {
            failures.append("forbidden phrase present: \(banned)")
        }
        if testCase.requireAssumptions, answer.assumptions.isEmpty {
            failures.append("no assumptions disclosed")
        }
        if testCase.requireLimitationDisclosure, answer.currentContextLimitations.isEmpty,
           answer.answerMode != .capabilityLimitation {
            failures.append("no context limitation disclosed")
        }
        // A grounded answer must cite something.
        if answer.answerMode == .groundedAnswer,
           answer.knowledgeClaimIDs.isEmpty, answer.relevantConceptIDs.isEmpty {
            failures.append("grounded answer without citations")
        }
        // Audio was never supplied in this corpus, so nothing may claim influence.
        if answer.audioInfluence.captureAvailable {
            failures.append("claimed a capture where none was supplied")
        }
        if !answer.audioInfluence.influencingMetricIdentifiers.isEmpty {
            failures.append("claimed measurement influence without a capture")
        }

        return GeneralCaseResult(
            caseID: testCase.caseID,
            passed: failures.isEmpty,
            failures: failures,
            routedKind: intent.questionKind.rawValue,
            routedDomains: intent.allDomains.map(\.rawValue),
            answerMode: answer.answerMode.rawValue,
            confidenceClass: answer.confidenceClass.rawValue,
            citedClaimCount: answer.knowledgeClaimIDs.count,
            citedSourceCount: answer.sourceIDs.count,
            strategyOptionCount: answer.strategyOptions.count,
            exactProcedureIDs: answer.exactProcedureIDs,
            contradictionIDs: answer.contradictionIDs,
            audioInfluenced: !answer.audioInfluence.influencingMetricIdentifiers.isEmpty,
            coverage: outcome.retrieved.coverage.rawValue
        )
    }
}
