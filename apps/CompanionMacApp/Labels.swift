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

func instanceSummaryIsMeasured(_ instance: PluginInstanceRecord) -> Bool {
    instance.sampleRate != nil && instance.channelCount != nil
}

func intentList(_ goals: [InterpretedProductionGoal]) -> String {
    goals.isEmpty
        ? "none"
        : goals.map { "\($0.direction.rawValue) \($0.term.rawValue)" }.joined(separator: ", ")
}

struct EvidenceDisplay {
    let name: String
    let measuredValue: String
    let isMeasuredValue: Bool
    let inspectionText: String
}

func evidenceDisplay(for observation: ProductionEvidenceObservation) -> EvidenceDisplay {
    let identifier = observation.metricIdentifier ?? "no measured metric"
    let confidence = Int((observation.confidence * 100).rounded())
    let measuredValue: String
    if let value = observation.value {
        measuredValue = String(format: "%.4g %@", value, observation.unit ?? "")
            .trimmingCharacters(in: .whitespaces)
    } else {
        measuredValue = "unavailable"
    }
    return EvidenceDisplay(
        name: observation.metricIdentifier.flatMap(metricDisplayName) ?? identifier,
        measuredValue: measuredValue,
        isMeasuredValue: observation.value != nil,
        inspectionText: "\(identifier) · confidence \(confidence)%"
    )
}

/// These names expand only tokens that are present in the identifier; unknown
/// identifiers stay raw so the display cannot imply an interpretation.
func metricDisplayName(_ identifier: String) -> String? {
    switch identifier {
    case "vocal_120_350_hz_energy_ratio", "bass_120_350_hz_energy_ratio":
        "Low-mid energy ratio (120–350 Hz)"
    case "vocal_200_500_hz_energy_ratio":
        "200–500 Hz energy ratio"
    case "vocal_5_10_khz_energy_ratio":
        "5–10 kHz energy ratio"
    case "vocal_10_20_khz_energy_ratio":
        "10–20 kHz energy ratio"
    case "vocal_high_frequency_burst_density_per_second", "vocal_low_frequency_burst_density_per_second":
        identifier.contains("high_frequency")
            ? "High-frequency burst density (per second)"
            : "Low-frequency burst density (per second)"
    case "level_variability_p90_p10_db":
        "Level variability (P90–P10)"
    case "drums_positive_spectral_flux_p90", "bass_positive_spectral_flux_p90", "source_positive_spectral_flux_p90":
        "Positive spectral flux (P90)"
    case "drums_onset_candidate_density_per_second":
        "Onset candidate density (per second)"
    case "drums_crest_factor_p90", "bass_crest_factor_p90", "mix_crest_factor_p90":
        "Crest factor (P90)"
    case "drums_post_onset_sustain_ratio":
        "Post-onset sustain ratio"
    case "drums_transient_20_200_hz_energy_ratio":
        "Transient energy ratio (20–200 Hz)"
    case "drums_transient_5_10_khz_energy_ratio":
        "Transient energy ratio (5–10 kHz)"
    case "drums_2_5_khz_energy_ratio", "source_2_5_khz_energy_ratio":
        "2–5 kHz energy ratio"
    case "bass_sub_share_20_120_hz":
        "Sub share (20–120 Hz)"
    case "spectral_occupied_bin_fraction":
        "Spectral occupied-bin fraction"
    case "maximum_third_octave_concentration_ratio":
        "Maximum third-octave concentration ratio"
    case "side_energy_share":
        "Side energy share"
    case "mono_sum_energy_ratio":
        "Mono-sum energy ratio"
    case "low_band_side_energy_share":
        "Low-band side energy share"
    case "mix_below_250_hz_energy_ratio":
        "Below 250 Hz energy ratio"
    case "mix_250_hz_4_khz_energy_ratio":
        "250 Hz–4 kHz energy ratio"
    case "mix_above_4_khz_energy_ratio":
        "Above 4 kHz energy ratio"
    case "mix_spectral_slope_db_per_octave":
        "Spectral slope (dB per octave)"
    case "maximum_short_term_loudness_lufs":
        "Maximum short-term loudness (LUFS)"
    case "loudness_range_lu":
        "Loudness range (LU)"
    default:
        nil
    }
}

let hypothesisDisclaimer = "This is one hypothesis, not a measured fact."

func hypothesisProse(_ fragment: String) -> String {
    let withoutDisclaimer = fragment.replacingOccurrences(of: hypothesisDisclaimer, with: "")
    guard withoutDisclaimer != fragment else { return fragment }
    var prose = withoutDisclaimer
    var joiners = CharacterSet.whitespacesAndNewlines
    joiners.insert(charactersIn: "|·—–:;")
    prose = prose.trimmingCharacters(in: joiners)
    return prose
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
