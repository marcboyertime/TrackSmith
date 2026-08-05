import Foundation

public enum TutorLessonValidationError: Error, Equatable, Sendable {
    case unknownProcedure(String)
    case unknownStep(String)
    case stepNotFromSelectedProcedure(String)
    case parameterOutsideCatalogBounds(step: String, control: String)
    case forbiddenClaim(step: String, phrase: String)
    case forbiddenActor(step: String)
    case audioGroundedWithoutAuthority
    case activeStepMissing
    case clarificationMissingQuestion
}

/// Staged validation of a materialized lesson before it becomes user-visible:
/// knowledge references must resolve to the catalog, numeric values must stay
/// within catalog bounds, actors must stay user-mediated, and forbidden-claim
/// phrases must be absent from every user-visible string.
public struct TutorLessonValidator: Sendable {
    private let catalog: TutorProcedureCatalog

    /// Phrases the tutor must never present. These are honesty violations:
    /// false proof, false authority, false action claims, or fake guarantees.
    public static let forbiddenClaimPhrases: [String] = [
        "the analyzer proved",
        "analysis proved you",
        "proves you are nasal",
        "proved you are nasal",
        "vocals are nasal at",
        "is the correct compressor setting",
        "professionals always",
        "this is how professionals always",
        "logic is currently set to",
        "i changed the plug-in",
        "i changed the plugin",
        "i adjusted logic",
        "trackSmith changed your",
        "will make the vocal professional",
        "will sound professional",
        "a louder comparison is better",
        "matches the artist exactly",
        "guaranteed to fix",
    ]

    public init(catalog: TutorProcedureCatalog) {
        self.catalog = catalog
    }

    public func validate(_ lesson: TutorLessonState) throws {
        if lesson.evidenceMode == .audioGrounded, lesson.authority == nil {
            throw TutorLessonValidationError.audioGroundedWithoutAuthority
        }
        if lesson.status == .awaitingClarification, lesson.clarificationQuestion == nil {
            throw TutorLessonValidationError.clarificationMissingQuestion
        }

        if let procedureID = lesson.selectedProcedureID {
            guard let procedure = catalog.procedure(procedureID) else {
                throw TutorLessonValidationError.unknownProcedure(procedureID)
            }
            for step in lesson.steps {
                guard let catalogStep = procedure.step(step.id) else {
                    throw TutorLessonValidationError.unknownStep(step.id)
                }
                guard step.procedureID == procedure.id else {
                    throw TutorLessonValidationError.stepNotFromSelectedProcedure(step.id)
                }
                guard step.actor != .trackSmithPreviewDemonstration || step.parameters.isEmpty else {
                    // Preview demonstrations may not carry Logic control values.
                    throw TutorLessonValidationError.forbiddenActor(step: step.id)
                }
                try validateParameters(of: step, against: catalogStep)
                try scanForbiddenClaims(in: step)
            }
            if lesson.status == .activeStep {
                guard let activeID = lesson.activeStepID,
                      lesson.steps.contains(where: { $0.id == activeID }) else {
                    throw TutorLessonValidationError.activeStepMissing
                }
            }
        }

        for text in [lesson.statusNote, lesson.clarificationQuestion ?? ""]
            + lesson.unresolvedLimitations
            + lesson.hypotheses.map(\.summary)
            + lesson.contextEvidence.map(\.statement) {
            try scanForbiddenClaims(text: text, step: "lesson")
        }
        if let summary = lesson.finalSummary {
            for text in [
                summary.whatChanged, summary.likelyCause, summary.principleToRemember,
            ] + summary.whatDidNotHelp + summary.whatWasPreserved
                + summary.userEnteredSettings + summary.remainingUncertainty {
                try scanForbiddenClaims(text: text, step: "summary")
            }
        }
    }

    private func validateParameters(of step: TutorStep, against catalogStep: TutorStep) throws {
        for parameter in step.parameters {
            guard let reference = catalogStep.parameters.first(where: {
                $0.controlIdentity == parameter.controlIdentity
            }) else {
                throw TutorLessonValidationError.parameterOutsideCatalogBounds(
                    step: step.id, control: parameter.controlIdentity
                )
            }
            if let minimum = reference.minimumValue, let value = parameter.safeStartingValue,
               value < minimum {
                throw TutorLessonValidationError.parameterOutsideCatalogBounds(
                    step: step.id, control: parameter.controlIdentity
                )
            }
            if let maximum = reference.maximumValue, let value = parameter.safeStartingValue,
               value > maximum {
                throw TutorLessonValidationError.parameterOutsideCatalogBounds(
                    step: step.id, control: parameter.controlIdentity
                )
            }
        }
    }

    private func scanForbiddenClaims(in step: TutorStep) throws {
        let corpus = ([
            step.title, step.instruction, step.reason, step.technicalExplanation,
            step.listenFor, step.expectedResult, step.commonSideEffect,
            step.stopCondition, step.undoInstruction,
        ] + step.substeps).joined(separator: " ")
        try scanForbiddenClaims(text: corpus, step: step.id)
    }

    private func scanForbiddenClaims(text: String, step: String) throws {
        let lowered = text.lowercased()
        for phrase in Self.forbiddenClaimPhrases where lowered.contains(phrase.lowercased()) {
            throw TutorLessonValidationError.forbiddenClaim(step: step, phrase: phrase)
        }
    }
}
