import Foundation

public enum TutorKnowledgeError: Error, Equatable, Sendable {
    case emptyCatalog
    case duplicateProcedureID(String)
    case duplicateStepID(String)
    case unknownEntryStep(procedure: String, step: String)
    case unknownBranchTarget(step: String, target: String)
    case unrecognizedProcessorIdentity(procedure: String, identity: String)
    case unrecognizedLocationProcessor(step: String, identity: String)
    case outOfRangeParameter(step: String, control: String)
    case missingRollback(step: String)
    case missingStopCondition(step: String)
    case missingListeningCue(step: String)
    case missingPreservationCheck(step: String)
    case missingUndo(step: String)
    case unversionedUILocation(step: String)
    case unsupportedSourceTypes(procedure: String)
    case falseExecutionAuthority(procedure: String)
    case coordinateContent(step: String)
    case keyCommandContent(step: String)
    case destructiveInstruction(step: String)
    case metricProvesSubjectiveClaim(step: String)
    case missingProvenance(procedure: String)
    case sweepWithoutExcursionBound(step: String, control: String)
    case emptyFeedback(step: String)
    case tooManyVisibleSubsteps(step: String)
}

/// Fail-closed structural validation of the tutor procedure catalog. The
/// Python audit script mirrors these rules on the reviewed source artifact;
/// this validator re-enforces them on the generated payload at runtime and in
/// tests so a hand-edited generated file cannot smuggle content in.
public struct TutorKnowledgeValidator: Sendable {
    public init() {}

    private static let coordinatePatterns = [
        #"\bx\s*=\s*\d+"#,
        #"\by\s*=\s*\d+"#,
        #"\b\d{2,4}\s*,\s*\d{2,4}\b"#,
        #"pixel"#,
        #"coordinate"#,
    ]

    private static let keyCommandPatterns = [
        "⌘", "⌥", "⇧⌘", "cmd+", "command+", "option+", "key command", "press command",
        "shortcut key",
    ]

    private static let destructivePatterns = [
        "bounce in place", "normalize the file", "flatten", "replace the file",
        "overwrite", "delete the region", "delete the file", "convert the region",
        "destructive",
    ]

    private static let falseProofPatterns = [
        "proves you are", "proved you are", "the analyzer proved", "measurement proves",
        "this proves the vocal is", "objectively nasal",
    ]

    public func validate(_ catalog: TutorProcedureCatalog) throws {
        guard !catalog.procedures.isEmpty else { throw TutorKnowledgeError.emptyCatalog }
        let recognized = Set(catalog.recognizedProcessorIdentities)
        var procedureIDs: Set<String> = []
        var stepIDs: Set<String> = []

        for procedure in catalog.procedures {
            guard procedureIDs.insert(procedure.id).inserted else {
                throw TutorKnowledgeError.duplicateProcedureID(procedure.id)
            }
            guard !procedure.supportedSourceTypes.isEmpty else {
                throw TutorKnowledgeError.unsupportedSourceTypes(procedure: procedure.id)
            }
            guard !procedure.grantsExecutionAuthority else {
                throw TutorKnowledgeError.falseExecutionAuthority(procedure: procedure.id)
            }
            guard !procedure.sourceReferences.isEmpty else {
                throw TutorKnowledgeError.missingProvenance(procedure: procedure.id)
            }
            for identity in procedure.processorIdentities where !recognized.contains(identity) {
                throw TutorKnowledgeError.unrecognizedProcessorIdentity(
                    procedure: procedure.id, identity: identity
                )
            }
            guard procedure.step(procedure.entryStepID) != nil else {
                throw TutorKnowledgeError.unknownEntryStep(
                    procedure: procedure.id, step: procedure.entryStepID
                )
            }
            let localStepIDs = Set(procedure.steps.map(\.id))
            for step in procedure.steps {
                guard stepIDs.insert(step.id).inserted else {
                    throw TutorKnowledgeError.duplicateStepID(step.id)
                }
                try validate(step, recognized: recognized, localStepIDs: localStepIDs)
            }
        }
    }

    private func validate(
        _ step: TutorStep,
        recognized: Set<String>,
        localStepIDs: Set<String>
    ) throws {
        let trimmedUndo = step.undoInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStop = step.stopCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedListen = step.listenFor.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedStop.isEmpty else { throw TutorKnowledgeError.missingStopCondition(step: step.id) }
        guard !trimmedListen.isEmpty else { throw TutorKnowledgeError.missingListeningCue(step: step.id) }
        guard !trimmedUndo.isEmpty else { throw TutorKnowledgeError.missingUndo(step: step.id) }
        guard step.substeps.count <= 4 else {
            throw TutorKnowledgeError.tooManyVisibleSubsteps(step: step.id)
        }
        guard !step.supportedFeedback.isEmpty else {
            throw TutorKnowledgeError.emptyFeedback(step: step.id)
        }

        let mutating: Set<TutorActionKind> = [
            .bypassProcessor, .enableProcessor, .setControl, .sweepControl,
        ]
        if mutating.contains(step.actionKind) {
            guard !step.preservationChecks.isEmpty else {
                throw TutorKnowledgeError.missingPreservationCheck(step: step.id)
            }
            guard trimmedUndo.count >= 8 else {
                throw TutorKnowledgeError.missingRollback(step: step.id)
            }
        }

        if let location = step.location {
            guard !location.logicVersion.isEmpty, !location.navigationLabels.isEmpty,
                  !location.sourceReferences.isEmpty else {
                throw TutorKnowledgeError.unversionedUILocation(step: step.id)
            }
            if let processor = location.processorIdentity, !recognized.contains(processor) {
                throw TutorKnowledgeError.unrecognizedLocationProcessor(
                    step: step.id, identity: processor
                )
            }
        } else if [.openNativeProcessor, .setControl, .sweepControl, .bypassProcessor].contains(step.actionKind) {
            throw TutorKnowledgeError.unversionedUILocation(step: step.id)
        }

        for parameter in step.parameters {
            if let minimum = parameter.minimumValue, let maximum = parameter.maximumValue {
                guard minimum <= maximum else {
                    throw TutorKnowledgeError.outOfRangeParameter(step: step.id, control: parameter.controlIdentity)
                }
                if let start = parameter.safeStartingValue {
                    guard start >= minimum, start <= maximum else {
                        throw TutorKnowledgeError.outOfRangeParameter(step: step.id, control: parameter.controlIdentity)
                    }
                }
            }
            guard !parameter.rollbackValueDescription.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw TutorKnowledgeError.missingRollback(step: step.id)
            }
            guard !parameter.stopCondition.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw TutorKnowledgeError.missingStopCondition(step: step.id)
            }
            if parameter.adjustmentMethod == .slowContinuousSweep
                || parameter.adjustmentMethod == .steppedAdjustment {
                guard parameter.maximumRecommendedExcursion != nil else {
                    throw TutorKnowledgeError.sweepWithoutExcursionBound(
                        step: step.id, control: parameter.controlIdentity
                    )
                }
            }
        }

        for branch in step.branches {
            if let target = branch.nextStepID, !localStepIDs.contains(target) {
                throw TutorKnowledgeError.unknownBranchTarget(step: step.id, target: target)
            }
        }

        let corpus = ([
            step.title, step.instruction, step.reason, step.technicalExplanation,
            step.listenFor, step.expectedResult, step.commonSideEffect,
            step.stopCondition, step.undoInstruction,
        ] + step.substeps).joined(separator: " ").lowercased()

        for pattern in Self.coordinatePatterns {
            if corpus.range(of: pattern, options: .regularExpression) != nil {
                throw TutorKnowledgeError.coordinateContent(step: step.id)
            }
        }
        for pattern in Self.keyCommandPatterns where corpus.contains(pattern) {
            throw TutorKnowledgeError.keyCommandContent(step: step.id)
        }
        for pattern in Self.destructivePatterns where corpus.contains(pattern) {
            throw TutorKnowledgeError.destructiveInstruction(step: step.id)
        }
        for pattern in Self.falseProofPatterns where corpus.contains(pattern) {
            throw TutorKnowledgeError.metricProvesSubjectiveClaim(step: step.id)
        }
    }
}
