import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema

// MARK: - Corpus model

public struct TutorCorpusFeedbackExpectation: Codable, Equatable, Sendable {
    public var feedback: TutorFeedback
    public var expectStatus: TutorLessonStatus?
    public var expectProcedureID: String?
    public var expectActiveStepID: String?

    public init(
        feedback: TutorFeedback,
        expectStatus: TutorLessonStatus? = nil,
        expectProcedureID: String? = nil,
        expectActiveStepID: String? = nil
    ) {
        self.feedback = feedback
        self.expectStatus = expectStatus
        self.expectProcedureID = expectProcedureID
        self.expectActiveStepID = expectActiveStepID
    }
}

public enum TutorCorpusClarificationPolicy: String, Codable, Sendable {
    case required
    case forbidden
    case allowed
}

public struct TutorCorpusCase: Codable, Equatable, Sendable {
    public var caseID: String
    public var sourceType: SourceType
    public var userText: String
    public var captureAvailable: Bool
    public var chainStatus: TutorUserReportedChain.Status
    public var chainProcessors: [TutorReportedProcessor]
    public var expectedRequestKind: TutorRequestKind?
    public var expectedIssueIDs: [String]
    public var acceptableCauseIDs: [String]
    public var requiredMentions: [String]
    public var acceptableFirstProcedureIDs: [String]
    public var clarificationPolicy: TutorCorpusClarificationPolicy
    public var forbiddenClaims: [String]
    public var expectedEvidenceMode: TutorEvidenceMode
    public var expectedStatus: TutorLessonStatus?
    public var unsupportedCapabilityExpected: Bool
    public var provenanceClass: String
    public var feedbackSequence: [TutorCorpusFeedbackExpectation]

    public init(
        caseID: String,
        sourceType: SourceType,
        userText: String,
        captureAvailable: Bool,
        chainStatus: TutorUserReportedChain.Status = .unknown,
        chainProcessors: [TutorReportedProcessor] = [],
        expectedRequestKind: TutorRequestKind? = nil,
        expectedIssueIDs: [String] = [],
        acceptableCauseIDs: [String] = [],
        requiredMentions: [String] = [],
        acceptableFirstProcedureIDs: [String] = [],
        clarificationPolicy: TutorCorpusClarificationPolicy = .allowed,
        forbiddenClaims: [String] = [],
        expectedEvidenceMode: TutorEvidenceMode,
        expectedStatus: TutorLessonStatus? = nil,
        unsupportedCapabilityExpected: Bool = false,
        provenanceClass: String = "product_decision",
        feedbackSequence: [TutorCorpusFeedbackExpectation] = []
    ) {
        self.caseID = caseID
        self.sourceType = sourceType
        self.userText = userText
        self.captureAvailable = captureAvailable
        self.chainStatus = chainStatus
        self.chainProcessors = chainProcessors
        self.expectedRequestKind = expectedRequestKind
        self.expectedIssueIDs = expectedIssueIDs
        self.acceptableCauseIDs = acceptableCauseIDs
        self.requiredMentions = requiredMentions
        self.acceptableFirstProcedureIDs = acceptableFirstProcedureIDs
        self.clarificationPolicy = clarificationPolicy
        self.forbiddenClaims = forbiddenClaims
        self.expectedEvidenceMode = expectedEvidenceMode
        self.expectedStatus = expectedStatus
        self.unsupportedCapabilityExpected = unsupportedCapabilityExpected
        self.provenanceClass = provenanceClass
        self.feedbackSequence = feedbackSequence
    }
}

public struct TutorCorpus: Codable, Equatable, Sendable {
    public var version: String
    public var cases: [TutorCorpusCase]

    public init(version: String, cases: [TutorCorpusCase]) {
        self.version = version
        self.cases = cases
    }
}

// MARK: - Results

public struct TutorCaseResult: Codable, Equatable, Sendable {
    public var caseID: String
    public var passed: Bool
    public var failures: [String]
    public var recognizedIssues: [String]
    public var hypothesisCauses: [String]
    public var selectedProcedureID: String?
    public var finalStatus: TutorLessonStatus
    public var evidenceMode: TutorEvidenceMode
    public var feedbackTransitions: [String]

    public init(
        caseID: String,
        passed: Bool,
        failures: [String],
        recognizedIssues: [String],
        hypothesisCauses: [String],
        selectedProcedureID: String?,
        finalStatus: TutorLessonStatus,
        evidenceMode: TutorEvidenceMode,
        feedbackTransitions: [String]
    ) {
        self.caseID = caseID
        self.passed = passed
        self.failures = failures
        self.recognizedIssues = recognizedIssues
        self.hypothesisCauses = hypothesisCauses
        self.selectedProcedureID = selectedProcedureID
        self.finalStatus = finalStatus
        self.evidenceMode = evidenceMode
        self.feedbackTransitions = feedbackTransitions
    }
}

public struct TutorEvaluationReport: Codable, Equatable, Sendable {
    public var corpusVersion: String
    public var caseCount: Int
    public var passedCount: Int
    public var results: [TutorCaseResult]

    public init(corpusVersion: String, results: [TutorCaseResult]) {
        self.corpusVersion = corpusVersion
        self.caseCount = results.count
        self.passedCount = results.filter(\.passed).count
        self.results = results
    }
}

// MARK: - Harness

/// Deterministic corpus evaluation of the offline tutor path. No network, no
/// credential, no raw audio in the output.
public struct TutorEvaluationHarness: Sendable {
    private let planner: TutorPlanner
    private let reducer: TutorFeedbackReducer

    public init(planner: TutorPlanner) {
        self.planner = planner
        self.reducer = TutorFeedbackReducer(planner: planner)
    }

    /// One deterministic synthetic capture analysis shared by all
    /// capture-available cases. It exists to exercise the audio-grounded
    /// path; it makes no claim about real vocals.
    public static func syntheticVocalAnalysis() -> SourceAwareAnalysisReport {
        let sampleRate = 48_000.0
        let frames = Int(sampleRate)
        var samples = [Float](repeating: 0, count: frames)
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            // A vocal-ish deterministic mixture: fundamental plus harmonics.
            let value = 0.30 * sin(2 * .pi * 220 * time)
                + 0.18 * sin(2 * .pi * 440 * time)
                + 0.12 * sin(2 * .pi * 1_320 * time)
                + 0.05 * sin(2 * .pi * 3_300 * time)
            samples[index] = Float(value)
        }
        let buffer = DSPCore.AudioBuffer(channels: [samples], sampleRate: sampleRate)
        return SourceAwareAudioAnalyzer().analyze(buffer, as: .vocal)
    }

    public func run(_ corpus: TutorCorpus) -> TutorEvaluationReport {
        let analysis = Self.syntheticVocalAnalysis()
        let results = corpus.cases.map { evaluate($0, analysis: analysis) }
        return TutorEvaluationReport(corpusVersion: corpus.version, results: results)
    }

    public func evaluate(
        _ corpusCase: TutorCorpusCase,
        analysis: SourceAwareAnalysisReport
    ) -> TutorCaseResult {
        var failures: [String] = []
        let capture: TutorCaptureContext? = corpusCase.captureAvailable
            ? TutorCaptureContext(
                analysis: analysis,
                authority: TutorAuthorityReference(
                    instanceID: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001"),
                    runtimeEpoch: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002"),
                    captureSnapshotID: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003"),
                    sourceType: corpusCase.sourceType
                )
            )
            : nil
        let request = TutorRequest(
            text: corpusCase.userText,
            sourceType: corpusCase.sourceType,
            capture: capture,
            userReportedChain: TutorUserReportedChain(
                status: corpusCase.chainStatus,
                processors: corpusCase.chainProcessors
            )
        )

        let lesson: TutorLessonState
        do {
            lesson = try planner.makeLesson(for: request)
        } catch {
            return TutorCaseResult(
                caseID: corpusCase.caseID,
                passed: false,
                failures: ["Planner threw: \(error)"],
                recognizedIssues: [],
                hypothesisCauses: [],
                selectedProcedureID: nil,
                finalStatus: .abandoned,
                evidenceMode: .userReportedOnly,
                feedbackTransitions: []
            )
        }

        // Expectations on the initial lesson.
        if let expected = corpusCase.expectedRequestKind, lesson.requestKind != expected {
            failures.append("requestKind \(lesson.requestKind.rawValue) expected \(expected.rawValue)")
        }
        for issue in corpusCase.expectedIssueIDs
            where !lesson.reportedIssues.map(\.rawValue).contains(issue) {
            failures.append("missing expected issue \(issue)")
        }
        if !corpusCase.acceptableCauseIDs.isEmpty {
            let acceptable = Set(corpusCase.acceptableCauseIDs + [TutorCauseCategory.unknown.rawValue])
            for hypothesis in lesson.hypotheses
                where !acceptable.contains(hypothesis.causeCategory.rawValue) {
                failures.append("unacceptable cause \(hypothesis.causeCategory.rawValue)")
            }
        }
        if !corpusCase.acceptableFirstProcedureIDs.isEmpty {
            if let selected = lesson.selectedProcedureID {
                if !corpusCase.acceptableFirstProcedureIDs.contains(selected) {
                    failures.append("first procedure \(selected) not acceptable")
                }
            } else {
                failures.append("no procedure selected but one was expected")
            }
        }
        switch corpusCase.clarificationPolicy {
        case .required where lesson.status != .awaitingClarification:
            failures.append("clarification was required")
        case .forbidden where lesson.status == .awaitingClarification:
            failures.append("clarification was forbidden")
        default:
            break
        }
        if lesson.evidenceMode != corpusCase.expectedEvidenceMode {
            failures.append("evidenceMode \(lesson.evidenceMode.rawValue) expected \(corpusCase.expectedEvidenceMode.rawValue)")
        }
        if let expectedStatus = corpusCase.expectedStatus, lesson.status != expectedStatus {
            failures.append("status \(lesson.status.rawValue) expected \(expectedStatus.rawValue)")
        }
        if corpusCase.unsupportedCapabilityExpected, lesson.status != .limitedNoSafeProcedure {
            failures.append("expected an explicit capability limitation")
        }

        var transitions: [String] = []
        var current = lesson
        let corpusText = lessonText(current)
        for claim in corpusCase.forbiddenClaims where corpusText.contains(claim.lowercased()) {
            failures.append("forbidden claim present: \(claim)")
        }
        for mention in corpusCase.requiredMentions where !corpusText.contains(mention.lowercased()) {
            failures.append("required mention absent: \(mention)")
        }

        for expectation in corpusCase.feedbackSequence {
            current = reducer.reduce(current, feedback: expectation.feedback)
            transitions.append("\(expectation.feedback.rawValue)→\(current.status.rawValue):\(current.activeStepID ?? "-")")
            if let expected = expectation.expectStatus, current.status != expected {
                failures.append("after \(expectation.feedback.rawValue): status \(current.status.rawValue) expected \(expected.rawValue)")
            }
            if let expected = expectation.expectProcedureID, current.selectedProcedureID != expected {
                failures.append("after \(expectation.feedback.rawValue): procedure \(current.selectedProcedureID ?? "nil") expected \(expected)")
            }
            if let expected = expectation.expectActiveStepID, current.activeStepID != expected {
                failures.append("after \(expectation.feedback.rawValue): step \(current.activeStepID ?? "nil") expected \(expected)")
            }
            let text = lessonText(current)
            for claim in corpusCase.forbiddenClaims where text.contains(claim.lowercased()) {
                failures.append("forbidden claim after \(expectation.feedback.rawValue): \(claim)")
            }
        }

        // Universal invariants: validated lesson, no execution authority.
        do { try planner.validate(current) } catch {
            failures.append("final lesson failed validation: \(error)")
        }

        return TutorCaseResult(
            caseID: corpusCase.caseID,
            passed: failures.isEmpty,
            failures: failures,
            recognizedIssues: lesson.reportedIssues.map(\.rawValue),
            hypothesisCauses: lesson.hypotheses.map(\.causeCategory.rawValue),
            selectedProcedureID: lesson.selectedProcedureID,
            finalStatus: current.status,
            evidenceMode: lesson.evidenceMode,
            feedbackTransitions: transitions
        )
    }

    private func lessonText(_ lesson: TutorLessonState) -> String {
        var parts: [String] = [lesson.statusNote, lesson.clarificationQuestion ?? ""]
        parts.append(contentsOf: lesson.unresolvedLimitations)
        parts.append(contentsOf: lesson.hypotheses.map(\.summary))
        parts.append(contentsOf: lesson.hypotheses.flatMap(\.evidence).map(\.statement))
        parts.append(contentsOf: lesson.contextEvidence.map(\.statement))
        for step in lesson.steps {
            parts.append(contentsOf: [
                step.title, step.instruction, step.reason, step.technicalExplanation,
                step.listenFor, step.expectedResult, step.commonSideEffect,
                step.stopCondition, step.undoInstruction,
            ])
            parts.append(contentsOf: step.substeps)
        }
        if let summary = lesson.finalSummary {
            parts.append(contentsOf: [
                summary.whatChanged, summary.likelyCause, summary.principleToRemember,
            ])
            parts.append(contentsOf: summary.whatDidNotHelp)
            parts.append(contentsOf: summary.whatWasPreserved)
            parts.append(contentsOf: summary.remainingUncertainty)
        }
        return parts.joined(separator: " ").lowercased()
    }
}
