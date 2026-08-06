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
}

public struct GeneralCorpus: Codable, Equatable, Sendable {
    public var version: String
    public var caseCount: Int
    public var cases: [GeneralCorpusCase]
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
    public var results: [GeneralCaseResult]
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

        for testCase in corpus.cases {
            let result = evaluate(testCase)
            modes[result.answerMode, default: 0] += 1
            domains.formUnion(result.routedDomains)
            kinds.insert(result.routedKind)
            results.append(result)
        }

        return GeneralEvaluationReport(
            corpusVersion: corpus.version,
            caseCount: results.count,
            passedCount: results.filter(\.passed).count,
            answerModeCounts: modes,
            domainsExercised: domains.sorted(),
            questionKindsExercised: kinds.sorted(),
            results: results
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
