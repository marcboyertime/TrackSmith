import Foundation

/// Deterministic user-facing text. This formatter is the reliable offline
/// default; any future provider rephrasing is display-only and never replaces
/// these materialized facts.
public struct TutorExplanationFormatter: Sendable {
    public init() {}

    /// The explanation for a step at the chosen depth. Simple is one plain
    /// sentence; standard adds the causal reason; technical adds the deeper
    /// explanation and uncertainty.
    public func explanation(for step: TutorStep, depth: TutorExplanationDepth) -> String {
        switch depth {
        case .simple:
            return step.reason
        case .standard:
            return step.reason + " Listen for: " + step.listenFor
        case .technical:
            var parts = [step.reason, step.technicalExplanation]
            if !step.uncertainty.isEmpty {
                parts.append("Uncertainty: " + step.uncertainty.joined(separator: " "))
            }
            return parts.joined(separator: "\n\n")
        }
    }

    public func hypothesisIntro(for lesson: TutorLessonState) -> String {
        let issueList = lesson.reportedIssues.map(issueLabel).joined(separator: ", ")
        let grounding = lesson.evidenceMode == .audioGrounded
            ? (lesson.audioEvidenceIsHistorical
                ? "A capture was analyzed earlier, but it no longer matches the live session, so measured statements are historical."
                : "A recent capture was analyzed locally; measurements are descriptive and cannot prove a cause.")
            : "No recent capture is available, so this guidance is general and not grounded in your current audio."
        return "You reported: \(issueList). \(grounding) Several causes are possible; one experiment at a time will help distinguish them."
    }

    public func conceptLabel(_ concept: TutorConceptID) -> String {
        switch concept {
        case .levelMatchedComparison: "Level-matched comparison — compare sounds at equal loudness, because louder almost always seems better"
        case .resonance: "Resonance — a narrow region of emphasized frequencies that colors a sound"
        case .frequency: "Frequency — where in the low-to-high spectrum a control acts"
        case .gain: "Gain — how much level is added or removed"
        case .qBandwidth: "Q — how narrow or wide an EQ band is"
        case .highPassFilter: "High-pass filter — removes energy below a chosen frequency"
        case .threshold: "Threshold — the level where a dynamics processor starts acting"
        case .ratio: "Ratio — how strongly level above the threshold is reduced"
        case .attack: "Attack — how fast a dynamics processor reacts"
        case .release: "Release — how fast it lets go"
        case .makeupGain: "Make-up gain — restores level removed by compression"
        case .dynamicVersusStaticProcessing: "Dynamic versus static — a processor that reacts to the signal versus one that is always the same"
        case .sibilance: "Sibilance — sharp s-like consonant energy"
        case .wetDry: "Wet/dry — the balance between processed and unprocessed signal"
        case .preDelay: "Pre-delay — the gap before a reverb starts"
        case .feedback: "Feedback — how much of a delay is fed back into itself"
        case .gainStaging: "Gain staging — keeping healthy levels at every stage"
        case .sourceVersusProcessing: "Source versus processing — fixing the recording or performance can beat any plug-in"
        case .monitoringBias: "Monitoring bias — level and listening conditions change what you think you hear"
        }
    }

    public func issueLabel(_ issue: TutorIssueKind) -> String {
        switch issue {
        case .nasalOrHonky: "a pinched or honky (nasal) quality"
        case .congested: "a congested quality"
        case .boxy: "a boxy quality"
        case .muddy: "muddiness"
        case .harsh: "harshness"
        case .sibilant: "sharp s-sounds"
        case .thin: "thinness"
        case .boomy: "boominess"
        case .dull: "dullness"
        case .inconsistentLevel: "uneven level"
        case .overcompressed: "over-compression"
        case .tooDry: "too little space"
        case .tooWet: "too much ambience"
        case .tooDistant: "too much distance"
        case .noisyBetweenPhrases: "noise between phrases"
        case .plosive: "plosive thumps"
        case .clippingOrOverload: "clipping or overload"
        case .unclearOrBuried: "an unclear or buried sound"
        }
    }

    /// Completion summary: what changed, the likely cause, what did not help,
    /// what was preserved, the reusable principle, and remaining uncertainty.
    public func summary(for lesson: TutorLessonState) -> TutorLessonSummary {
        let strengthened = lesson.hypotheses.filter { $0.status == .strengthened }
        let weakened = lesson.hypotheses.filter { $0.status == .weakened || $0.status == .contraindicated }

        let whatChanged: String
        switch lesson.status {
        case .stoppedPreserved:
            whatChanged = "Nothing was changed. You decided the quality is part of this performance's character, which is a deliberate production decision."
        case .completed:
            whatChanged = strengthened.isEmpty
                ? "You completed the experiments; any change you kept is one you chose and performed yourself."
                : "You kept the change from the experiment that you reported as better. You performed every action; TrackSmith changed nothing in Logic."
        default:
            whatChanged = "No change was confirmed as an improvement. Everything you rolled back is documented, and the original state is preserved."
        }

        let likelyCause: String
        if let cause = strengthened.first {
            likelyCause = "Your feedback makes this cause more likely: \(cause.summary) This is strengthened evidence from your own experiment, not proof."
        } else {
            likelyCause = "No single cause was confirmed. The experiments narrowed the possibilities without settling them; that is a normal diagnostic outcome."
        }

        let didNotHelp = weakened.map {
            "Less likely after testing: \($0.summary)"
        }

        let preserved = [
            "The original recording was never modified.",
            "Every experiment ended with an exact undo path, and nothing was committed by TrackSmith.",
        ]

        let principle: String
        if let concept = lesson.conceptsPracticed.first {
            principle = "Principle to remember: \(conceptLabel(concept)). You practiced " +
                lesson.conceptsPracticed.map { conceptLabel($0).components(separatedBy: " — ")[0] }
                    .joined(separator: ", ") + "."
        } else {
            principle = "Principle to remember: change one thing at a time, compare at matched loudness, and keep the smallest move that works."
        }

        var uncertainty = [
            "Listening remains decisive; none of these measurements or experiments proves a cause.",
        ]
        uncertainty.append(contentsOf: lesson.unresolvedLimitations)

        return TutorLessonSummary(
            whatChanged: whatChanged,
            likelyCause: likelyCause,
            whatDidNotHelp: didNotHelp,
            whatWasPreserved: preserved,
            principleToRemember: principle,
            userEnteredSettings: [],
            remainingUncertainty: uncertainty
        )
    }
}
