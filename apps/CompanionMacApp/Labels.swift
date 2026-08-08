import AgentCore
import Foundation
import PlanSchema
import ProductionTutor
import SharedIPC

func instanceSummary(_ instance: PluginInstanceRecord) -> String {
    guard let sampleRate = instance.sampleRate, let channels = instance.channelCount else {
        return "Waiting for host audio format"
    }
    return "\(Int(sampleRate)) Hz · \(channels == 1 ? "mono" : "stereo")"
}

func intentList(_ goals: [InterpretedProductionGoal]) -> String {
    goals.isEmpty
        ? "none"
        : goals.map { "\($0.direction.rawValue) \($0.term.rawValue)" }.joined(separator: ", ")
}

func evidenceText(_ observation: ProductionEvidenceObservation) -> String {
    let identifier = observation.metricIdentifier ?? "no measured metric"
    let measured: String
    if let value = observation.value {
        measured = String(format: "%.4g %@", value, observation.unit ?? "")
            .trimmingCharacters(in: .whitespaces)
    } else {
        measured = "unavailable"
    }
    return "\(identifier): \(measured) · confidence \(Int((observation.confidence * 100).rounded()))% · \(observation.relationship.rawValue)"
}

func sourceLabel(_ type: SourceType) -> String {
    switch type {
    case .vocal: "Vocal"
    case .vocalBus: "Vocal bus"
    case .drums: "Drums"
    case .drumBus: "Drum bus"
    case .bass: "Bass"
    case .guitar: "Guitar"
    case .keyboard: "Keyboard"
    case .synth: "Synth"
    case .fullMix: "Full mix"
    case .reference: "Reference"
    case .unknown: "Unknown"
    }
}

func processorLabel(_ processor: TutorReportedProcessor) -> String {
    switch processor {
    case .eq: "EQ"
    case .compressor: "Compressor"
    case .deEsser: "De-esser"
    case .gateOrExpander: "Gate/Expander"
    case .pitchProcessor: "Pitch"
    case .reverb: "Reverb"
    case .delay: "Delay"
    }
}

func hypothesisSymbol(_ status: TutorHypothesisStatus) -> String {
    switch status {
    case .open: "questionmark.circle"
    case .strengthened: "arrow.up.circle.fill"
    case .weakened: "arrow.down.circle"
    case .contraindicated: "xmark.circle"
    }
}

func hypothesisStatusLabel(_ status: TutorHypothesisStatus) -> String {
    switch status {
    case .open: ""
    case .strengthened: "Your feedback makes this more likely"
    case .weakened: "Your feedback makes this less likely"
    case .contraindicated: "Set aside for this session after a worse result"
    }
}

func progressLabel(_ step: TutorStep, lesson: TutorLessonState) -> String {
    let total = lesson.steps.count
    let index = (lesson.steps.firstIndex { $0.id == step.id } ?? 0) + 1
    return "STEP \(index) OF \(total) · EXPERIMENT \(max(lesson.attemptedProcedureIDs.count, 1))"
}

func feedbackLabel(_ feedback: TutorFeedback) -> String {
    switch feedback {
    case .better: "Better"
    case .worse: "Worse"
    case .noChange: "No change"
    case .notSure: "Not sure"
    case .notApplicable: "Not applicable"
    case .cannotFindControl: "Can't find it"
    case .done: "Done"
    case .undo: "Undo"
    }
}

func feedbackAccessibilityLabel(_ feedback: TutorFeedback) -> String {
    switch feedback {
    case .better: "The change made it better"
    case .worse: "The change made it worse"
    case .noChange: "No audible change"
    case .notSure: "Not sure yet"
    case .notApplicable: "This step does not apply"
    case .cannotFindControl: "I cannot find this control in Logic"
    case .done: "This step is done"
    case .undo: "Show me how to undo this step"
    }
}

func kindLabel(_ kind: GeneralQuestionKind) -> String {
    switch kind {
    case .troubleshootProblem: "Troubleshooting"
    case .achieveSoundOrFeeling: "Achieving a sound"
    case .explainConcept: "Concept"
    case .productionStrategy: "Strategy"
    case .compareOptions: "Comparing options"
    case .exactWorkflowHelp: "Workflow"
    case .planSession: "Planning"
    case .diagnoseTradeoff: "Tradeoff"
    case .researchUnfamiliar: "Needs current research"
    }
}

func confidenceLabel(_ confidence: AnswerConfidenceClass) -> String {
    switch confidence {
    case .reviewedExactProcedure: "reviewed exact procedure"
    case .sourceGroundedStrategy: "source-grounded strategy"
    case .professionalPracticeHeuristic: "professional practice"
    case .provisionalResearchResult: "provisional research"
    case .userConfirmedPersonalResult: "your confirmed result"
    case .unsupportedOrUnresolved: "unresolved"
    }
}

func evidenceLabel(_ evidence: GeneralEvidenceClass) -> String {
    switch evidence {
    case .documentedBehavior: "documented behavior"
    case .measuredBehavior: "measured"
    case .technicalInference: "inference"
    case .professionalPracticeHeuristic: "professional practice"
    case .subjectivePreference: "subjective preference"
    case .userConfirmedPersonalResult: "your result"
    case .provisionalResearch: "provisional"
    case .unresolvedOrDisputed: "disputed"
    }
}

func domainLabel(_ domain: ProductionDomain) -> String {
    domain.rawValue
        .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        .lowercased()
}
