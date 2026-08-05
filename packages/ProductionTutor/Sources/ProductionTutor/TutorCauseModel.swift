import Foundation
import PlanSchema

/// Maps a perceived issue plus qualifiers and the user-reported chain to a
/// bounded, ordered set of competing cause hypotheses. The mapping is a
/// TrackSmith product heuristic informed by professional practice; it never
/// collapses to one cause prematurely, and it never claims measurement proof.
public struct TutorCauseModel: Sendable {
    public init() {}

    public func candidateCauses(
        for issue: TutorIssueKind,
        qualifiers: TutorRequestQualifiers,
        chain: TutorUserReportedChain
    ) -> [TutorCauseHypothesis] {
        var hypotheses: [TutorCauseHypothesis] = []

        func add(
            _ category: TutorCauseCategory,
            _ summary: String,
            weight: Double,
            evidence: [TutorEvidenceStatement] = []
        ) {
            hypotheses.append(.init(
                causeCategory: category,
                summary: summary,
                evidence: evidence,
                plausibilityWeight: weight
            ))
        }

        switch issue {
        case .nasalOrHonky, .congested:
            if chain.mayContain(.compressor) {
                add(
                    .dynamicsInteraction,
                    "Existing compression may be holding a midrange resonance prominent for more of each phrase, making an existing quality more obvious.",
                    weight: qualifiers.afterCompression ? 0.9 : 0.6,
                    evidence: qualifiers.afterCompression ? [
                        .init(
                            statement: "You reported that the quality appeared or worsened after compression.",
                            provenanceClass: .userReported,
                            relationship: .supports,
                            confidence: 0.7
                        ),
                    ] : []
                )
            }
            add(
                qualifiers.vowelSpecific ? .timeVaryingResonance : .staticSpectralResonance,
                qualifiers.vowelSpecific
                    ? "The resonance may move with specific vowels, which a fixed EQ cut cannot follow without side effects."
                    : "A midrange resonance may be emphasized fairly consistently across the phrase; a restrained static EQ cut can then help.",
                weight: qualifiers.vowelSpecific ? 0.85 : 0.65
            )
            add(
                .performanceOrVowelFormation,
                "Vowel formation, jaw opening, or a congested delivery can create the same perceived quality at the source, before any processing.",
                weight: 0.55
            )
            add(
                .microphonePositionOrCapture,
                "Microphone distance and angle change how much of this quality is captured; a small position change can matter more than processing.",
                weight: 0.5
            )
        case .boxy, .muddy:
            add(.staticSpectralResonance, "Low-mid energy concentration may be masking the source.", weight: 0.6)
            add(.roomOrReflection, "Room reflections in the capture can create the same congestion.", weight: 0.5)
            add(.arrangementOrMasking, "Another source in the arrangement may be responsible for the perceived congestion.", weight: 0.45)
        case .harsh:
            add(.staticSpectralResonance, "Upper-mid energy may be concentrated or event-dependent.", weight: 0.55)
            add(.dynamicsInteraction, "Compression or saturation may be emphasizing the fatiguing band.", weight: 0.5)
            add(.monitoringOrLevelBias, "Listening level and monitoring can exaggerate perceived harshness.", weight: 0.35)
        case .sibilant:
            add(.staticSpectralResonance, "Consonant-band bursts on s/sh sounds may be prominent for this microphone and position.", weight: 0.6)
            add(.dynamicsInteraction, "Compression can bring sibilant events forward.", weight: 0.5)
        case .thin:
            add(.microphonePositionOrCapture, "Distance and off-axis capture reduce low-mid body.", weight: 0.55)
            add(.staticSpectralResonance, "Existing filtering or EQ may have removed body.", weight: 0.5)
            add(.arrangementOrMasking, "Other sources may be masking the body that exists.", weight: 0.4)
        case .boomy:
            add(.roomOrReflection, "Room modes or close proximity can create low-frequency buildup.", weight: 0.55)
            add(.staticSpectralResonance, "A low-frequency concentration may dominate sustain.", weight: 0.5)
        case .dull:
            add(.existingProcessing, "Previous corrective moves may have removed openness.", weight: 0.55)
            add(.microphonePositionOrCapture, "Off-axis or distant capture reduces high-frequency detail.", weight: 0.5)
        case .inconsistentLevel:
            add(.performanceOrVowelFormation, "Performance dynamics and mic technique commonly drive level variation.", weight: 0.6)
            add(.dynamicsInteraction, "Existing dynamics settings may be mistimed for the phrase.", weight: 0.45)
        case .overcompressed:
            add(.existingProcessing, "Current compression settings may be stronger or faster than the phrase needs.", weight: 0.75)
            add(.monitoringOrLevelBias, "A loudness difference can masquerade as over-compression.", weight: 0.35)
        case .tooDry:
            add(.ambienceInteraction, "The balance of direct sound to ambience may be leaving the source exposed.", weight: 0.65)
        case .tooWet:
            add(.ambienceInteraction, "Existing reverb or delay may be washing over articulation.", weight: 0.7)
        case .tooDistant:
            add(.ambienceInteraction, "Ambience, level, and tone all contribute distance cues.", weight: 0.55)
            add(.arrangementOrMasking, "Masking by other sources can push a part backward.", weight: 0.45)
        case .noisyBetweenPhrases:
            add(.microphonePositionOrCapture, "The capture chain or room may contribute a noise floor audible in gaps.", weight: 0.6)
            add(.dynamicsInteraction, "Compression make-up gain raises the floor between phrases.", weight: 0.55)
        case .plosive:
            add(.microphonePositionOrCapture, "Plosives are usually a capture-stage problem of air hitting the capsule.", weight: 0.75)
        case .clippingOrOverload:
            add(.microphonePositionOrCapture, "Overload commonly happens at the capture or gain stage; later processing cannot restore it.", weight: 0.7)
            add(.existingProcessing, "A processor's input or output stage may be overloading.", weight: 0.45)
        case .unclearOrBuried:
            add(.arrangementOrMasking, "Other sources may be masking this one.", weight: 0.6)
            add(.monitoringOrLevelBias, "Balance and monitoring may explain the perception.", weight: 0.4)
            add(.staticSpectralResonance, "Congestion in a shared band can reduce intelligibility.", weight: 0.4)
        }

        hypotheses.append(.init(
            causeCategory: .unknown,
            summary: "The reported quality may also be part of the natural character of this source rather than a defect; listening and your feedback remain decisive.",
            plausibilityWeight: 0.3
        ))

        // Deterministic ordering: weight descending, then category name.
        return hypotheses.sorted {
            if $0.plausibilityWeight != $1.plausibilityWeight {
                return $0.plausibilityWeight > $1.plausibilityWeight
            }
            return $0.causeCategory.rawValue < $1.causeCategory.rawValue
        }
    }
}
