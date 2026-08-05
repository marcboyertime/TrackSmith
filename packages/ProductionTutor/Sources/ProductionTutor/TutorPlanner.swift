import AudioAnalysis
import Foundation
import PlanSchema

public struct TutorCaptureContext: Equatable, Sendable {
    public var analysis: SourceAwareAnalysisReport
    public var authority: TutorAuthorityReference

    public init(analysis: SourceAwareAnalysisReport, authority: TutorAuthorityReference) {
        self.analysis = analysis
        self.authority = authority
    }
}

public struct TutorRequest: Equatable, Sendable {
    public var text: String
    public var sourceType: SourceType
    public var capture: TutorCaptureContext?
    public var userReportedChain: TutorUserReportedChain
    public var explanationDepth: TutorExplanationDepth

    public init(
        text: String,
        sourceType: SourceType,
        capture: TutorCaptureContext? = nil,
        userReportedChain: TutorUserReportedChain = .unknown,
        explanationDepth: TutorExplanationDepth = .simple
    ) {
        self.text = text
        self.sourceType = sourceType
        self.capture = capture
        self.userReportedChain = userReportedChain
        self.explanationDepth = explanationDepth
    }
}

public enum TutorPlannerError: Error, Equatable, Sendable {
    case emptyRequest
    case lessonValidationFailed(String)
}

/// Deterministic lesson construction. The planner recognizes issues with the
/// local vocabulary, builds competing cause hypotheses, selects a validated
/// procedure from the catalog, and materializes the lesson. No provider text
/// ever reaches an exact-step card.
public struct TutorPlanner: Sendable {
    private let vocabulary = TutorIssueVocabulary()
    private let causeModel = TutorCauseModel()
    private let contextBuilder = TutorContextBuilder()
    private let catalog: TutorProcedureCatalog

    public init(catalog: TutorProcedureCatalog) {
        self.catalog = catalog
    }

    public init() throws {
        self.catalog = try TutorProcedureCatalog.loadValidated()
    }

    public var procedureCatalog: TutorProcedureCatalog { catalog }

    // MARK: - Lesson construction

    public func makeLesson(for request: TutorRequest) throws -> TutorLessonState {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TutorPlannerError.emptyRequest }

        let parsed = vocabulary.parse(text, sourceType: request.sourceType)
        let context = contextBuilder.build(
            sourceType: request.sourceType,
            analysis: request.capture?.analysis,
            authority: request.capture?.authority,
            chain: request.userReportedChain
        )

        if !parsed.unsupported.isEmpty {
            return limitedLesson(
                request: request,
                parsed: parsed,
                context: context
            )
        }

        if parsed.requestKind == .explainConcept,
           let concept = explainableConcept(in: text) {
            return conceptLesson(request: request, parsed: parsed, context: context, concept: concept)
        }

        guard let primary = primaryIssue(parsed.recognizedIssues) else {
            return clarificationLesson(request: request, parsed: parsed, context: context)
        }

        var hypotheses = causeModel.candidateCauses(
            for: primary,
            qualifiers: parsed.qualifiers,
            chain: request.userReportedChain
        )
        // Keep the presentation short: at most three competing causes plus
        // the explicit "may be natural character" possibility.
        if hypotheses.count > 4 { hypotheses = Array(hypotheses.prefix(4)) }

        var lesson = TutorLessonState(
            requestKind: parsed.requestKind,
            requestText: text,
            sourceType: request.sourceType,
            evidenceMode: context.evidenceMode,
            authority: context.authority,
            reportedIssues: parsed.recognizedIssues.map(\.kind),
            hypotheses: hypotheses,
            contextEvidence: context.evidence,
            userReportedChain: request.userReportedChain,
            status: .activeStep
        )

        let candidates = orderedCandidateProcedureIDs(
            issue: primary,
            qualifiers: parsed.qualifiers,
            chain: request.userReportedChain,
            sourceType: request.sourceType
        )
        if parsed.qualifiers.vowelSpecific {
            lesson.unresolvedLimitations.append(
                "The problem may follow specific vowels. A fixed EQ cut affects every word all the time, so static EQ is deprioritized here. Safe exact handling of a vowel-dependent resonance is not in the current validated knowledge and is recorded as a requirement for Vocal Module v1."
            )
        }
        if parsed.qualifiers.sectionSpecific {
            lesson.unresolvedLimitations.append(
                "You reported the problem only in one section. TrackSmith cannot see Logic sections; experiments should loop a phrase from that section specifically."
            )
        }

        guard let procedureID = candidates.first,
              let procedure = catalog.procedure(procedureID) else {
            lesson.status = .limitedNoSafeProcedure
            lesson.statusNote = "No validated procedure in the current tutor knowledge safely covers this report. That limitation is recorded rather than improvised around."
            lesson.unresolvedLimitations.append(
                "No validated procedure covers issue \(primary.rawValue) for source \(request.sourceType.rawValue) in the current catalog."
            )
            return lesson
        }

        lesson = activate(procedure: procedure, in: lesson)
        try validate(lesson)
        return lesson
    }

    // MARK: - Procedure ordering

    /// Deterministic candidate order for the primary issue. The reducer uses
    /// the same order when an experiment ends without improvement.
    public func orderedCandidateProcedureIDs(
        issue: TutorIssueKind,
        qualifiers: TutorRequestQualifiers,
        chain: TutorUserReportedChain,
        sourceType: SourceType
    ) -> [String] {
        var ordered: [String] = []
        switch issue {
        case .nasalOrHonky, .congested:
            if chain.mayContain(.compressor) {
                ordered.append("tutor.vocal.compression-emphasis-check.v1")
            }
            if qualifiers.vowelSpecific {
                ordered.append("tutor.vocal.performance-openness-experiment.v1")
                ordered.append("tutor.vocal.microphone-position-experiment.v1")
            } else {
                ordered.append("tutor.vocal.channel-eq-resonance-search.v1")
                ordered.append("tutor.vocal.microphone-position-experiment.v1")
                ordered.append("tutor.vocal.performance-openness-experiment.v1")
            }
            ordered.append("tutor.vocal.no-processing-decision.v1")
        case .sibilant:
            ordered.append("tutor.vocal.deesser-sibilance-check.v1")
            ordered.append("tutor.vocal.microphone-position-experiment.v1")
        case .harsh:
            if chain.mayContain(.compressor) {
                ordered.append("tutor.vocal.compression-emphasis-check.v1")
            }
            ordered.append("tutor.vocal.channel-eq-resonance-search.v1")
            ordered.append("tutor.vocal.no-processing-decision.v1")
        case .thin, .dull:
            ordered.append("tutor.vocal.microphone-position-experiment.v1")
            ordered.append("tutor.vocal.broad-body-clarity-rebalance.v1")
            ordered.append("tutor.vocal.no-processing-decision.v1")
        case .overcompressed:
            ordered.append("tutor.vocal.compression-emphasis-check.v1")
        case .boxy, .muddy, .boomy:
            ordered.append("tutor.vocal.channel-eq-resonance-search.v1")
            ordered.append("tutor.vocal.microphone-position-experiment.v1")
        case .unclearOrBuried:
            ordered.append("tutor.vocal.level-matched-bypass-comparison.v1")
            ordered.append("tutor.vocal.channel-eq-resonance-search.v1")
        case .plosive:
            ordered.append("tutor.vocal.microphone-position-experiment.v1")
        case .inconsistentLevel:
            ordered.append("tutor.vocal.compression-emphasis-check.v1")
        default:
            break
        }
        // A procedure must actually declare support for the issue and source.
        return ordered.filter { identifier in
            guard let procedure = catalog.procedure(identifier) else { return false }
            return procedure.supportedIssues.contains(issue)
                && procedure.supportedSourceTypes.contains(sourceType)
        }
    }

    // MARK: - Activation helpers shared with the reducer

    public func activate(procedure: TutorProcedure, in lesson: TutorLessonState) -> TutorLessonState {
        var next = lesson
        next.selectedProcedureID = procedure.id
        if !next.attemptedProcedureIDs.contains(procedure.id) {
            next.attemptedProcedureIDs.append(procedure.id)
        }
        next.steps = procedure.steps
        next.activeStepID = procedure.entryStepID
        next.status = .activeStep
        next.statusNote = "One experiment at a time. Every change in this procedure has an exact undo."
        next.updatedAt = Date()
        return next
    }

    public func validate(_ lesson: TutorLessonState) throws {
        do {
            try TutorLessonValidator(catalog: catalog).validate(lesson)
        } catch {
            throw TutorPlannerError.lessonValidationFailed(String(describing: error))
        }
    }

    public func reparse(_ lesson: TutorLessonState) -> TutorParsedRequest {
        vocabulary.parse(lesson.requestText, sourceType: lesson.sourceType)
    }

    // MARK: - Special lessons

    private func primaryIssue(_ recognitions: [TutorIssueRecognition]) -> TutorIssueKind? {
        // Priority: the vocal vertical-slice issue first, then declaration order.
        if let nasal = recognitions.first(where: { $0.kind == .nasalOrHonky }) {
            return nasal.kind
        }
        return recognitions.first?.kind
    }

    /// The small explainConcept set supported in v1.
    private func explainableConcept(in text: String) -> TutorConceptID? {
        let lowered = text.lowercased()
        let mapping: [(String, TutorConceptID)] = [
            ("level match", .levelMatchedComparison),
            ("level-match", .levelMatchedComparison),
            ("resonance", .resonance),
            ("threshold", .threshold),
            ("attack", .attack),
            ("release", .release),
            ("wet/dry", .wetDry),
            ("wet dry", .wetDry),
            ("ratio", .ratio),
            ("what is q", .qBandwidth),
            ("what does q mean", .qBandwidth),
        ]
        return mapping.first { lowered.contains($0.0) }?.1
    }

    private func conceptLesson(
        request: TutorRequest,
        parsed: TutorParsedRequest,
        context: TutorLessonContext,
        concept: TutorConceptID
    ) -> TutorLessonState {
        let formatter = TutorExplanationFormatter()
        return TutorLessonState(
            requestKind: .explainConcept,
            requestText: request.text,
            sourceType: request.sourceType,
            evidenceMode: context.evidenceMode,
            authority: context.authority,
            contextEvidence: context.evidence,
            userReportedChain: request.userReportedChain,
            status: .completed,
            statusNote: formatter.conceptLabel(concept) + ". Ask about a specific problem and the tutor will show you where this matters in practice.",
            conceptsPracticed: [concept]
        )
    }

    private func clarificationLesson(
        request: TutorRequest,
        parsed: TutorParsedRequest,
        context: TutorLessonContext
    ) -> TutorLessonState {
        TutorLessonState(
            requestKind: parsed.requestKind,
            requestText: request.text,
            sourceType: request.sourceType,
            evidenceMode: context.evidenceMode,
            authority: context.authority,
            contextEvidence: context.evidence,
            userReportedChain: request.userReportedChain,
            status: .awaitingClarification,
            clarificationQuestion: "Which quality bothers you most when you listen back — for example pinched or honky, harsh, muddy, too sharp on s-sounds, uneven in level, or something else? One short phrase describing it is enough.",
            statusNote: "One clarification at a time keeps the next experiment focused."
        )
    }

    private func limitedLesson(
        request: TutorRequest,
        parsed: TutorParsedRequest,
        context: TutorLessonContext
    ) -> TutorLessonState {
        var limitations: [String] = []
        for unsupported in parsed.unsupported {
            switch unsupported {
            case .hostAutomationRequested:
                limitations.append(
                    "TrackSmith does not operate Logic Pro. It cannot click controls, press keys, or change Logic settings for you; it tells you exactly what to try, and you stay in control."
                )
            case .destructiveActionRequested:
                limitations.append(
                    "Destructive actions such as bouncing in place, replacing, flattening, or normalizing files are outside the tutor's guidance. The tutor only proposes reversible experiments."
                )
            case .namedArtistCloningRequested:
                limitations.append(
                    "Making a voice match a named artist exactly is not something TrackSmith can honestly promise; the result depends on the voice, performance, capture, and taste. The tutor can help with specific qualities you can describe."
                )
            }
        }
        return TutorLessonState(
            requestKind: parsed.requestKind,
            requestText: request.text,
            sourceType: request.sourceType,
            evidenceMode: context.evidenceMode,
            authority: context.authority,
            reportedIssues: parsed.recognizedIssues.map(\.kind),
            contextEvidence: context.evidence,
            userReportedChain: request.userReportedChain,
            status: .limitedNoSafeProcedure,
            statusNote: "This request includes something the tutor deliberately does not do.",
            unresolvedLimitations: limitations
        )
    }
}
