import Foundation

/// Deterministic lesson-state transitions. Feedback is an immutable event;
/// identical histories always produce identical lessons. The reducer never
/// invents an instruction: every activated step comes from the validated
/// catalog, and lesson-level transitions follow a fixed policy.
public struct TutorFeedbackReducer: Sendable {
    private let planner: TutorPlanner
    private let formatter = TutorExplanationFormatter()

    public init(planner: TutorPlanner) {
        self.planner = planner
    }

    public func reduce(_ lesson: TutorLessonState, feedback: TutorFeedback) -> TutorLessonState {
        var next = lesson
        next.feedbackEvents.append(.init(stepID: lesson.activeStepID, feedback: feedback))
        next.updatedAt = Date()

        guard lesson.status == .activeStep, let step = lesson.activeStep else {
            next.statusNote = "This lesson is no longer running an experiment; start a new lesson to continue."
            return next
        }
        guard step.supportedFeedback.contains(feedback) else {
            next.statusNote = "That response is not one of this step's choices."
            return next
        }

        next.conceptsPracticed = merged(next.conceptsPracticed, step.concepts)

        // Step-local branch first: the catalog can route directly.
        if let branch = step.branches.first(where: { $0.feedback == feedback }),
           let target = branch.nextStepID,
           lesson.steps.contains(where: { $0.id == target }) {
            if feedback == .notApplicable {
                next.skippedStepIDs.append(step.id)
            } else {
                next.completedStepIDs.append(step.id)
            }
            next.activeStepID = target
            next.statusNote = branch.effectSummary
            return next
        }

        // Lesson-level resolution.
        switch feedback {
        case .better:
            return complete(next, after: step, improved: true)
        case .worse:
            next = markCause(next, of: step.procedureID, as: .contraindicated)
            if !next.contraindicatedProcedureIDs.contains(step.procedureID) {
                next.contraindicatedProcedureIDs.append(step.procedureID)
            }
            next.statusNote = "That made it worse, so undo it now: \(step.undoInstruction) This branch is set aside for this session."
            return advance(next, from: step)
        case .noChange:
            next = markCause(next, of: step.procedureID, as: .weakened)
            next.statusNote = "No audible change, so remove the unnecessary processing: \(step.undoInstruction) The tutor moves to the next possible cause."
            return advance(next, from: step)
        case .notSure:
            return simplifyComparison(next, from: step)
        case .notApplicable:
            next.skippedStepIDs.append(step.id)
            next.statusNote = "Skipped without counting for or against any cause."
            return advance(next, from: step, skippedProcedure: true)
        case .cannotFindControl:
            next.statusNote = navigationNote(for: step)
            return next
        case .done:
            if step.actionKind == .stopAndPreserve {
                return complete(next, after: step, improved: false)
            }
            if next.hypotheses.contains(where: { $0.status == .strengthened }) {
                return complete(next, after: step, improved: true)
            }
            next.completedStepIDs.append(step.id)
            return advance(next, from: step)
        case .undo:
            next.statusNote = "To undo this step exactly: \(step.undoInstruction)"
            return next
        }
    }

    // MARK: - Transitions

    private func advance(
        _ lesson: TutorLessonState,
        from step: TutorStep,
        skippedProcedure: Bool = false
    ) -> TutorLessonState {
        var next = lesson
        if !skippedProcedure, !next.completedStepIDs.contains(step.id) {
            next.completedStepIDs.append(step.id)
        }

        let parsed = planner.reparse(lesson)
        guard let issue = lesson.reportedIssues.first else {
            return finishWithoutResolution(next)
        }
        let candidates = planner.orderedCandidateProcedureIDs(
            issue: issue,
            qualifiers: parsed.qualifiers,
            chain: lesson.userReportedChain,
            sourceType: lesson.sourceType
        ).filter {
            !next.attemptedProcedureIDs.contains($0)
                && !next.contraindicatedProcedureIDs.contains($0)
        }

        guard let nextID = candidates.first,
              let procedure = planner.procedureCatalog.procedure(nextID) else {
            return finishWithoutResolution(next)
        }
        let rollbackNote = next.statusNote
        next = planner.activate(procedure: procedure, in: next)
        if !rollbackNote.isEmpty {
            next.statusNote = rollbackNote + " Next experiment: a different possible cause."
        }
        return next
    }

    private func simplifyComparison(
        _ lesson: TutorLessonState,
        from step: TutorStep
    ) -> TutorLessonState {
        var next = lesson
        let comparisonID = "tutor.vocal.level-matched-bypass-comparison.v1"
        if step.procedureID != comparisonID,
           !next.attemptedProcedureIDs.contains(comparisonID),
           let procedure = planner.procedureCatalog.procedure(comparisonID) {
            next = planner.activate(procedure: procedure, in: next)
            next.statusNote = "Not sure is a normal answer. Before anything else, make the comparison honest: match the loudness first, then judge again."
            return next
        }
        next.statusNote = "Still unsure after a matched comparison counts as no change; the tutor moves on rather than over-processing."
        next = markCause(next, of: step.procedureID, as: .weakened)
        return advance(next, from: step)
    }

    private func complete(
        _ lesson: TutorLessonState,
        after step: TutorStep,
        improved: Bool
    ) -> TutorLessonState {
        var next = lesson
        if !next.completedStepIDs.contains(step.id) {
            next.completedStepIDs.append(step.id)
        }
        if improved {
            next = markCause(next, of: step.procedureID, as: .strengthened)
        }
        next.status = step.actionKind == .stopAndPreserve ? .stoppedPreserved : .completed
        next.activeStepID = nil
        next.finalSummary = formatter.summary(for: next)
        next.statusNote = "Lesson complete. The summary below records what worked, what did not, and the principle to reuse."
        return next
    }

    private func finishWithoutResolution(_ lesson: TutorLessonState) -> TutorLessonState {
        var next = lesson
        next.status = .limitedNoSafeProcedure
        next.activeStepID = nil
        next.unresolvedLimitations.append(
            "The validated experiments for this report are exhausted without a confirmed improvement. The honest options are re-recording, accepting the current character, or waiting for a future TrackSmith capability rather than guessing."
        )
        next.finalSummary = formatter.summary(for: next)
        next.statusNote = "No validated experiment remains for this report; the limitation is recorded honestly."
        return next
    }

    private func markCause(
        _ lesson: TutorLessonState,
        of procedureID: String,
        as status: TutorHypothesisStatus
    ) -> TutorLessonState {
        var next = lesson
        guard let procedure = planner.procedureCatalog.procedure(procedureID) else { return next }
        let causes = Set(procedure.candidateCauses)
        next.hypotheses = next.hypotheses.map { hypothesis in
            var hypothesis = hypothesis
            if causes.contains(hypothesis.causeCategory), hypothesis.status == .open {
                hypothesis.status = status
            }
            return hypothesis
        }
        return next
    }

    private func navigationNote(for step: TutorStep) -> String {
        guard let location = step.location else {
            return "This step has no Logic control to find; choose one of its other responses."
        }
        var parts: [String] = []
        parts.append("Navigation (Logic Pro \(location.logicVersion), \(location.verification == .documentary ? "from Apple documentation, not yet re-verified on this machine" : "directly verified")):")
        parts.append("Area: \(location.workArea).")
        parts.append("Path: " + location.navigationLabels.joined(separator: " → ") + ".")
        parts.append(location.requiredFocusOrSelection)
        if !location.prerequisites.isEmpty {
            parts.append("First: " + location.prerequisites.joined(separator: " "))
        }
        parts.append("If it is still not visible, the control may not be present in your project; answer Not applicable instead — the tutor never assumes it exists.")
        return parts.joined(separator: " ")
    }

    private func merged(_ existing: [TutorConceptID], _ added: [TutorConceptID]) -> [TutorConceptID] {
        var result = existing
        for concept in added where !result.contains(concept) {
            result.append(concept)
        }
        return result
    }
}
