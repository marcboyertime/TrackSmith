import Foundation
import PlanSchema

public enum ProductionEvidenceClass: String, Codable, CaseIterable, Sendable {
    case standardsBacked
    case peerReviewedResearchBacked
    case professionalPracticeHeuristic
    case productHeuristic
}

public enum ProductionTerm: String, Codable, CaseIterable, Sendable {
    case warm, bright, dark, clear, muddy, boxy, harsh, sibilant, punchy
    case aggressive, intimate, distant, polished, raw, wide, narrow, energetic
    case smooth, controlled, dynamic, vintage, modern, airy, thin, boomy, tight
    case soft, forward, level

    // Explicit preservation concepts used by the representative workflows.
    case lowEndWeight, pickAttack, monoCompatibility, cymbalHarshness
}

public enum ProductionDSPStrategy: String, Codable, CaseIterable, Sendable {
    case subtractiveEQ
    case additiveEQ
    case dynamicEQOrDeEsser
    case gentleCompression
    case transientPreservingCompression
    case parallelCompression
    case levelAutomation
    case saturation
    case stereoWidth
    case panningOrIndependentLayers
    case ambienceOrDelay
    case ambienceReduction
    case sourceOrArrangementChange
    case preserveWithoutProcessing
    case clarification
    case listeningComparison
}

public struct ProductionIntentProvenance: Codable, Equatable, Sendable {
    public var sourceIdentity: String
    public var sourceVersion: String
    public var relevantSection: String
    public var evidenceClass: ProductionEvidenceClass
    public var consequence: String

    public init(
        sourceIdentity: String,
        sourceVersion: String,
        relevantSection: String,
        evidenceClass: ProductionEvidenceClass,
        consequence: String
    ) {
        self.sourceIdentity = sourceIdentity
        self.sourceVersion = sourceVersion
        self.relevantSection = relevantSection
        self.evidenceClass = evidenceClass
        self.consequence = consequence
    }
}

public struct SourceTermInterpretation: Codable, Equatable, Sendable {
    public var sourceTypes: [SourceType]
    public var possibleAcousticInterpretation: String
    public var supportingMetricIdentifiers: [String]
    public var contradictoryEvidence: [String]
    public var candidateDSPStrategies: [ProductionDSPStrategy]
    public var preservationRisks: [String]

    public init(
        sourceTypes: [SourceType],
        possibleAcousticInterpretation: String,
        supportingMetricIdentifiers: [String],
        contradictoryEvidence: [String],
        candidateDSPStrategies: [ProductionDSPStrategy],
        preservationRisks: [String]
    ) {
        self.sourceTypes = sourceTypes
        self.possibleAcousticInterpretation = possibleAcousticInterpretation
        self.supportingMetricIdentifiers = supportingMetricIdentifiers
        self.contradictoryEvidence = contradictoryEvidence
        self.candidateDSPStrategies = candidateDSPStrategies
        self.preservationRisks = preservationRisks
    }
}

public struct ProductionTermDefinition: Codable, Equatable, Sendable {
    public var term: ProductionTerm
    public var aliases: [String]
    public var applicableSourceTypes: [SourceType]
    public var interpretations: [SourceTermInterpretation]
    public var contextDependence: [String]
    public var supportingAnalysisEvidence: [String]
    public var contradictoryEvidence: [String]
    public var candidateDSPStrategies: [ProductionDSPStrategy]
    public var preservationRisks: [String]
    public var knownFailureCases: [String]
    public var provenance: [ProductionIntentProvenance]
    public var confidence: Double
    public var evidenceClass: ProductionEvidenceClass

    public init(
        term: ProductionTerm,
        aliases: [String],
        applicableSourceTypes: [SourceType],
        interpretations: [SourceTermInterpretation],
        contextDependence: [String],
        supportingAnalysisEvidence: [String],
        contradictoryEvidence: [String],
        candidateDSPStrategies: [ProductionDSPStrategy],
        preservationRisks: [String],
        knownFailureCases: [String],
        provenance: [ProductionIntentProvenance],
        confidence: Double,
        evidenceClass: ProductionEvidenceClass
    ) {
        self.term = term
        self.aliases = aliases
        self.applicableSourceTypes = applicableSourceTypes
        self.interpretations = interpretations
        self.contextDependence = contextDependence
        self.supportingAnalysisEvidence = supportingAnalysisEvidence
        self.contradictoryEvidence = contradictoryEvidence
        self.candidateDSPStrategies = candidateDSPStrategies
        self.preservationRisks = preservationRisks
        self.knownFailureCases = knownFailureCases
        self.provenance = provenance
        self.confidence = min(max(confidence, 0), 1)
        self.evidenceClass = evidenceClass
    }
}

public enum ProductionVocabularyError: Error, Equatable, Sendable {
    case missingTerm(ProductionTerm)
    case incompleteDefinition(ProductionTerm)
    case missingSourceInterpretation(ProductionTerm, SourceType)
}

public struct ProductionIntentVocabulary: Codable, Equatable, Sendable {
    public var version: String
    public var definitions: [ProductionTerm: ProductionTermDefinition]

    public init(version: String = "1.0") {
        self.version = version
        definitions = Dictionary(uniqueKeysWithValues: ProductionTerm.allCases.map { term in
            (term, Self.makeDefinition(term))
        })
    }

    public func definition(for term: ProductionTerm) -> ProductionTermDefinition {
        // The catalogue is constructed from every enum case and validated by
        // tests; this fallback keeps decoding of a damaged external payload safe.
        definitions[term] ?? Self.makeDefinition(term)
    }

    public func interpretations(for term: ProductionTerm, sourceType: SourceType) -> [SourceTermInterpretation] {
        definition(for: term).interpretations.filter { $0.sourceTypes.contains(sourceType) }
    }

    public func validate() throws {
        let requiredSources: [SourceType] = [.vocal, .drums, .bass, .guitar, .synth, .fullMix]
        for term in ProductionTerm.allCases {
            guard let definition = definitions[term] else { throw ProductionVocabularyError.missingTerm(term) }
            guard !definition.aliases.isEmpty,
                  !definition.interpretations.isEmpty,
                  !definition.contextDependence.isEmpty,
                  !definition.supportingAnalysisEvidence.isEmpty,
                  !definition.contradictoryEvidence.isEmpty,
                  !definition.candidateDSPStrategies.isEmpty,
                  !definition.preservationRisks.isEmpty,
                  !definition.knownFailureCases.isEmpty,
                  !definition.provenance.isEmpty else {
                throw ProductionVocabularyError.incompleteDefinition(term)
            }
            for source in requiredSources where definition.applicableSourceTypes.contains(source) {
                guard definition.interpretations.contains(where: { $0.sourceTypes.contains(source) }) else {
                    throw ProductionVocabularyError.missingSourceInterpretation(term, source)
                }
            }
        }
    }

    private static let productionSources: [SourceType] = [
        .vocal, .vocalBus, .drums, .drumBus, .bass, .guitar, .keyboard, .synth, .fullMix,
    ]

    private static let sourceGroups: [(types: [SourceType], label: String, metrics: [String], risks: [String])] = [
        (
            [.vocal, .vocalBus],
            "vocal consonants, formants, breath, proximity, level contour, and wet/dry depth",
            ["vocal_120_350_hz_energy_ratio", "vocal_200_500_hz_energy_ratio", "vocal_5_10_khz_energy_ratio", "vocal_10_20_khz_energy_ratio", "vocal_high_frequency_burst_density_per_second", "level_variability_p90_p10_db"],
            ["Intelligibility, air, natural consonants, and intimacy can be lost"]
        ),
        (
            [.drums, .drumBus],
            "drum onset, body, post-onset sustain, cymbal energy, room contribution, and groove",
            ["drums_positive_spectral_flux_p90", "drums_onset_candidate_density_per_second", "drums_crest_factor_p90", "drums_post_onset_sustain_ratio", "drums_transient_20_200_hz_energy_ratio", "drums_transient_5_10_khz_energy_ratio"],
            ["Leading transients, cymbal smoothness, room coherence, and groove can be damaged"]
        ),
        (
            [.bass],
            "bass fundamental movement, sub allocation, low-mid density, transient definition, and kick relationship",
            ["bass_sub_share_20_120_hz", "bass_120_350_hz_energy_ratio", "bass_positive_spectral_flux_p90", "bass_crest_factor_p90", "level_variability_p90_p10_db"],
            ["Low-end weight, note-to-note balance, pitch audibility, and kick separation can be damaged"]
        ),
        (
            [.guitar],
            "guitar role, pick/strum onset, amp or pedal nonlinearity, spectral density, and arrangement masking",
            ["spectral_occupied_bin_fraction", "maximum_third_octave_concentration_ratio", "source_2_5_khz_energy_ratio", "source_positive_spectral_flux_p90", "level_variability_p90_p10_db"],
            ["Pick attack, articulation, intended amp character, and arrangement position can be damaged"]
        ),
        (
            [.keyboard, .synth],
            "keyboard or synth voicing, filter motion, envelope, layer density, stereo modulation, and musical role",
            ["spectral_occupied_bin_fraction", "maximum_third_octave_concentration_ratio", "source_2_5_khz_energy_ratio", "source_positive_spectral_flux_p90", "side_energy_share", "mono_sum_energy_ratio", "low_band_side_energy_share"],
            ["Filter movement, envelope, stereo animation, low-end focus, and mono translation can be damaged"]
        ),
        (
            [.fullMix],
            "mix-wide tonal distribution, section dynamics, crest behavior, stereo/mono translation, and source balance",
            ["mix_below_250_hz_energy_ratio", "mix_250_hz_4_khz_energy_ratio", "mix_above_4_khz_energy_ratio", "mix_spectral_slope_db_per_octave", "maximum_short_term_loudness_lufs", "loudness_range_lu", "mix_crest_factor_p90", "side_energy_share", "mono_sum_energy_ratio", "low_band_side_energy_share"],
            ["Source balance, dynamics, transients, tonal identity, and mono translation can be damaged"]
        ),
    ]

    private static let logicEffects = ProductionIntentProvenance(
        sourceIdentity: "Apple Logic Pro Effects User Guide",
        sourceVersion: "current payload retrieved 2026-07-14; SHA-256 b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819",
        relevantSection: "Dynamics; EQ; distortion; delay; reverb; imaging; metering",
        evidenceClass: .professionalPracticeHeuristic,
        consequence: "Defines processor behavior and Logic vocabulary; creative recommendations remain source-dependent heuristics."
    )

    private static let mixingGuide = ProductionIntentProvenance(
        sourceIdentity: "iZotope Mixing Guide: Principles, Tips, and Techniques",
        sourceVersion: "2014 edition; SHA-256 285fd062e781d9ead2735309e47d1b1ef088e173a2d3c6fbbdda715bda882373",
        relevantSection: "EQ, dynamics, stereo, ambience, distortion, and complete source-specific mixing chapters",
        evidenceClass: .professionalPracticeHeuristic,
        consequence: "Supplies candidate production interpretations while repeatedly requiring source, arrangement, client intent, and listening context."
    )

    private static let compressorResearch = ProductionIntentProvenance(
        sourceIdentity: "Giannoulis, Massberg, and Reiss, Digital Dynamic Range Compressor Design",
        sourceVersion: "JAES 60(6), 2012; SHA-256 dd65e1f91e8fafd855cc994246bfe957d671254a271b83ba8fab2239f7b23b44",
        relevantSection: "Static characteristics, detector topologies, ballistics, and implementation tradeoffs",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Supports bounded dynamics strategies, not semantic claims that compression makes audio polished, punchy, or warm."
    )

    private static let perceptualCaution = ProductionIntentProvenance(
        sourceIdentity: "Wilson and Fazenda, Perception & Evaluation of Audio Quality in Music Production",
        sourceVersion: "2013; SHA-256 6809079a119e9d78e47d408223c49b66425ec450f8811260d1826728a0d5b2dd",
        relevantSection: "Open-ended attributes, descriptor correlations, regressions, and limitations",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "No single descriptor or post-hoc frequency band proves a production adjective or quality."
    )

    private static func makeDefinition(_ term: ProductionTerm) -> ProductionTermDefinition {
        let aliases = aliases(for: term)
        let strategies = strategies(for: term)
        let positive = positiveInterpretation(for: term)
        let contradiction = contradictionFor(term)
        let applicability = applicableSources(for: term)
        let interpretations = sourceGroups.filter { group in
            group.types.contains(where: applicability.contains)
        }.map { group in
            SourceTermInterpretation(
                sourceTypes: group.types,
                possibleAcousticInterpretation: "For \(group.label), ‘\(term.rawValue)’ may request \(positive). This is one hypothesis, not a measured fact.",
                supportingMetricIdentifiers: group.metrics,
                contradictoryEvidence: [contradiction, "The named metrics may already move opposite the requested direction or may be inapplicable to the musical role."],
                candidateDSPStrategies: sourceAdjustedStrategies(strategies, term: term, sourceTypes: group.types),
                preservationRisks: group.risks
            )
        }
        let evidenceClass: ProductionEvidenceClass = [.polished, .vintage, .modern, .professionalLike].contains(term.syntheticGrouping)
            ? .productHeuristic
            : .professionalPracticeHeuristic
        return ProductionTermDefinition(
            term: term,
            aliases: aliases,
            applicableSourceTypes: applicability,
            interpretations: interpretations,
            contextDependence: [
                "Source type and its role in the arrangement",
                "Current measured state and metric confidence",
                "Existing processing and capture chain",
                "User preservation/prohibition constraints",
                "Musical context, monitoring, and requested strength",
            ],
            supportingAnalysisEvidence: Array(Set(interpretations.flatMap(\.supportingMetricIdentifiers))).sorted(),
            contradictoryEvidence: [
                contradiction,
                "Another source, section, or reference may require the opposite move.",
                "A perceptually successful result can move an objective descriptor in an unexpected direction.",
            ],
            candidateDSPStrategies: strategies,
            preservationRisks: Array(Set(interpretations.flatMap(\.preservationRisks))).sorted(),
            knownFailureCases: [
                "Treating the term as a fixed frequency, processor, preset, or target",
                "Acting on one low-confidence metric without listening or contradictory evidence",
                "Ignoring source role, existing processing, or a preservation constraint",
            ],
            provenance: [mixingGuide, logicEffects, compressorResearch, perceptualCaution],
            confidence: evidenceClass == .productHeuristic ? 0.42 : 0.58,
            evidenceClass: evidenceClass
        )
    }

    private static func applicableSources(for term: ProductionTerm) -> [SourceType] {
        switch term {
        case .pickAttack: [.guitar]
        case .cymbalHarshness: [.drums, .drumBus]
        case .lowEndWeight: [.drums, .drumBus, .bass, .keyboard, .synth, .fullMix]
        case .monoCompatibility: [.vocalBus, .drums, .drumBus, .bass, .guitar, .keyboard, .synth, .fullMix]
        default: productionSources
        }
    }

    private static func aliases(for term: ProductionTerm) -> [String] {
        switch term {
        case .warm: ["warm", "warmer", "warmth", "fuller"]
        case .bright: ["bright", "brighter", "brightness", "sparkly", "crisp"]
        case .dark: ["dark", "darker", "dull", "muffled"]
        case .clear: ["clear", "clearer", "clarity", "unclouded"]
        case .muddy: ["muddy", "mud", "muddiness", "cloudy"]
        case .boxy: ["boxy", "boxiness", "papery", "hollow"]
        case .harsh: ["harsh", "harsher", "harshness", "brash", "abrasive"]
        case .sibilant: ["sibilant", "sibilance", "de-ess", "deess", "essing"]
        case .punchy: ["punchy", "punchier", "punch", "hit harder", "impact"]
        case .aggressive: ["aggressive", "more aggressive", "bite", "edgy"]
        case .intimate: ["intimate", "closer", "close", "up close"]
        case .distant: ["distant", "farther", "further back", "recessed"]
        case .polished: ["polished", "professional", "finished", "radio ready"]
        case .raw: ["raw", "natural", "unprocessed", "rough"]
        case .wide: ["wide", "wider", "width", "spacious"]
        case .narrow: ["narrow", "narrower", "focused", "mono-ish"]
        case .energetic: ["energetic", "energy", "exciting", "lively"]
        case .smooth: ["smooth", "smoother", "gentle", "silky"]
        case .controlled: ["controlled", "more controlled", "even", "consistent"]
        case .dynamic: ["dynamic", "more dynamic", "preserve dynamics", "keep the dynamics"]
        case .vintage: ["vintage", "retro", "old school", "analog"]
        case .modern: ["modern", "contemporary", "current"]
        case .airy: ["airy", "air", "open", "breathy"]
        case .thin: ["thin", "thinner", "weak", "lightweight"]
        case .boomy: ["boomy", "boom", "tubby", "bloated"]
        case .tight: ["tight", "tighter", "less sustain", "focused low end"]
        case .soft: ["soft", "softer", "less hard", "gentler"]
        case .forward: ["forward", "more forward", "up front", "present"]
        case .level: ["level", "overall level", "volume", "louder", "quieter", "turn it up", "turn it down", "added level"]
        case .lowEndWeight: ["low-end weight", "low end weight", "bottom end", "sub weight"]
        case .pickAttack: ["pick attack", "pluck", "articulation", "leading transient"]
        case .monoCompatibility: ["mono compatibility", "mono compatible", "mono translation", "in mono"]
        case .cymbalHarshness: ["cymbal harshness", "harsh cymbals", "cymbals harsher", "brash cymbals"]
        }
    }

    private static func strategies(for term: ProductionTerm) -> [ProductionDSPStrategy] {
        switch term {
        case .warm: [.saturation, .additiveEQ, .subtractiveEQ, .listeningComparison]
        case .bright, .airy, .forward: [.additiveEQ, .subtractiveEQ, .saturation, .listeningComparison]
        case .dark, .harsh, .sibilant, .cymbalHarshness: [.subtractiveEQ, .dynamicEQOrDeEsser, .listeningComparison]
        case .clear, .muddy, .boxy, .thin, .boomy: [.subtractiveEQ, .additiveEQ, .sourceOrArrangementChange, .listeningComparison]
        case .punchy, .energetic, .aggressive: [.transientPreservingCompression, .parallelCompression, .saturation, .levelAutomation, .listeningComparison]
        case .controlled, .tight, .smooth: [.gentleCompression, .levelAutomation, .subtractiveEQ, .listeningComparison]
        case .dynamic, .raw, .soft: [.preserveWithoutProcessing, .levelAutomation, .transientPreservingCompression, .listeningComparison]
        case .intimate, .distant: [.ambienceOrDelay, .ambienceReduction, .levelAutomation, .additiveEQ, .listeningComparison]
        case .level: [.levelAutomation, .listeningComparison]
        case .wide, .narrow, .monoCompatibility: [.stereoWidth, .panningOrIndependentLayers, .preserveWithoutProcessing, .listeningComparison]
        case .polished, .vintage, .modern: [.clarification, .subtractiveEQ, .gentleCompression, .saturation, .ambienceOrDelay, .listeningComparison]
        case .lowEndWeight: [.preserveWithoutProcessing, .additiveEQ, .saturation, .listeningComparison]
        case .pickAttack: [.preserveWithoutProcessing, .transientPreservingCompression, .additiveEQ, .listeningComparison]
        }
    }

    private static func sourceAdjustedStrategies(
        _ base: [ProductionDSPStrategy],
        term: ProductionTerm,
        sourceTypes: [SourceType]
    ) -> [ProductionDSPStrategy] {
        var result = base
        if sourceTypes.contains(.vocal), term == .sibilant { result = [.dynamicEQOrDeEsser, .levelAutomation, .listeningComparison] }
        if sourceTypes.contains(.drums), term == .punchy { result = [.transientPreservingCompression, .parallelCompression, .saturation, .listeningComparison] }
        if sourceTypes.contains(.bass), term == .tight { result = [.gentleCompression, .levelAutomation, .subtractiveEQ, .listeningComparison] }
        if sourceTypes.contains(.guitar), term == .harsh { result = [.subtractiveEQ, .dynamicEQOrDeEsser, .listeningComparison] }
        if sourceTypes.contains(.synth), term == .wide { result = [.panningOrIndependentLayers, .stereoWidth, .listeningComparison] }
        if sourceTypes.contains(.fullMix), term == .clear { result = [.sourceOrArrangementChange, .subtractiveEQ, .gentleCompression, .listeningComparison] }
        return result
    }

    private static func positiveInterpretation(for term: ProductionTerm) -> String {
        switch term {
        case .warm: "greater low/low-mid body or harmonic density without obscuring articulation or air"
        case .bright: "greater upper-spectrum prominence without excessive bursts, fatigue, or thinness"
        case .dark: "less upper-spectrum prominence while preserving intelligibility and articulation"
        case .clear: "reduced masking or excess density while preserving desired brightness and body"
        case .muddy: "less overlapping low-mid density without removing power or warmth"
        case .boxy: "less narrow midrange coloration without hollowing the source"
        case .harsh: "less fatiguing or event-specific upper-mid energy without burying attack or intelligibility"
        case .sibilant: "reduced consonant-like high-frequency bursts without lisping or loss of air"
        case .punchy: "a more salient leading event relative to body or sustain, with groove preserved"
        case .aggressive: "greater attack, density, or forward spectral energy, bounded against fatigue"
        case .intimate: "greater direct-source salience and closeness, often with controlled ambience"
        case .distant: "more depth or reduced direct salience, potentially through level and ambience cues"
        case .polished: "resolution of the specifically identified tonal, dynamic, spatial, or artifact issue"
        case .raw: "preservation or restoration of performance variation, transients, and unembellished space"
        case .wide: "greater side/spatial contrast while preserving center focus and mono translation"
        case .narrow: "less side energy or spatial spread while preserving balance and interest"
        case .energetic: "greater event contrast, motion, density, or section lift without only becoming louder"
        case .smooth: "reduced abrupt spectral or level events while preserving life and definition"
        case .controlled: "reduced unwanted variability or peaks without erasing musical dynamics"
        case .dynamic: "preserved or increased meaningful level and transient variation"
        case .vintage: "a user-specified historical production cue, not a universal analog processor chain"
        case .modern: "a user-specified contemporary reference cue, not a universal brightness/loudness target"
        case .airy: "greater very-high-frequency openness without added sibilance or noise"
        case .thin: "more body or density without creating boom, mud, or reduced headroom"
        case .boomy: "less excessive low-frequency sustain or concentration without losing weight"
        case .tight: "more consistent low/body decay or event separation without reducing low-end weight"
        case .soft: "less attack, density, or upper-mid prominence without losing intelligibility"
        case .forward: "greater perceptual salience through balance, presence, density, or reduced ambience"
        case .level: "an explicit direct-signal gain change without treating loudness, dynamics, tone, or production quality as interchangeable"
        case .lowEndWeight: "preserved useful low-frequency body and fundamentals"
        case .pickAttack: "preserved leading guitar transient and articulation"
        case .monoCompatibility: "preserved level, spectral balance, and source audibility after mono collapse"
        case .cymbalHarshness: "no increase in fatiguing cymbal-band bursts while other drum attributes change"
        }
    }

    private static func contradictionFor(_ term: ProductionTerm) -> String {
        switch term {
        case .bright, .airy: "Upper-frequency energy or event density may already be strong, and boosting can increase sibilance, cymbal harshness, or noise."
        case .warm, .thin, .lowEndWeight: "Low/low-mid density may already obscure the source or conflict with kick and mix headroom."
        case .dark, .harsh, .sibilant, .cymbalHarshness: "The same band may carry necessary consonants, pick attack, cymbal articulation, or perceived detail."
        case .clear, .muddy, .boxy, .boomy, .tight: "The requested problem may arise from arrangement, ambience, note sustain, or another source rather than the target's static spectrum."
        case .punchy, .aggressive, .energetic, .forward, .pickAttack: "The source may already have high crest/flux or the requested salience may be a level or arrangement issue."
        case .controlled, .smooth, .soft: "Low measured variability or already-reduced crest can argue against additional compression or transient reduction."
        case .dynamic, .raw: "Uncontrolled peaks, noise, edits, or inconsistent performance can masquerade as desirable dynamics or rawness."
        case .wide, .narrow, .monoCompatibility: "Current side energy may be intentional, while mono retention or low-band side energy can prohibit further widening or narrowing."
        case .intimate, .distant: "Level, direct-to-reverberant balance, predelay, timbre, performance, and arrangement offer conflicting distance cues."
        case .level: "The audible difference may be monitoring gain, preview loudness compensation, automation outside TrackSmith's scope, or another source in the arrangement rather than this graph's trim."
        case .polished, .vintage, .modern: "The term does not identify a unique acoustic defect, target, era, or processor behavior and may require clarification."
        }
    }
}

private enum SyntheticProductionGrouping {
    case polished, vintage, modern, professionalLike, other
}

private extension ProductionTerm {
    var syntheticGrouping: SyntheticProductionGrouping {
        switch self {
        case .polished: .polished
        case .vintage: .vintage
        case .modern: .modern
        default: .other
        }
    }
}
