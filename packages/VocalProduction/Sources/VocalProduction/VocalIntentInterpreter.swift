import Foundation

private struct VocalDirectGoalRule: Sendable {
    let aspect: VocalAspect
    let direction: VocalIntentDirection
    let phrases: [String]
    let maximumStrength: Double
    let rationale: String
}

private struct VocalArchetypeRule: Sendable {
    let archetype: VocalCreativeArchetype
    let phrases: [String]
}

public struct VocalIntentInterpreter: Sendable {
    private static let directGoalRules: [VocalDirectGoalRule] = [
        VocalDirectGoalRule(
            aspect: .intelligibility,
            direction: .increase,
            phrases: ["clearer", "clear words", "more intelligible", "intelligibility"],
            maximumStrength: 1,
            rationale: "Make words easier to follow without changing lyrics or performance timing."
        ),
        VocalDirectGoalRule(
            aspect: .warmth,
            direction: .increase,
            phrases: ["warm"],
            maximumStrength: 1,
            rationale: "Increase perceived warmth with bounded tone or harmonic coloration."
        ),
        VocalDirectGoalRule(
            aspect: .brightness,
            direction: .increase,
            phrases: ["bright", "brighter", "airier", "airy"],
            maximumStrength: 1,
            rationale: "Increase upper-spectrum presence while monitoring sharp events and noise."
        ),
        VocalDirectGoalRule(
            aspect: .darkness,
            direction: .increase,
            phrases: ["dark", "darker"],
            maximumStrength: 1,
            rationale: "Reduce upper-spectrum prominence without promising a specific acoustic cause."
        ),
        VocalDirectGoalRule(
            aspect: .closeness,
            direction: .increase,
            phrases: ["closer", "close", "intimate"],
            maximumStrength: 1,
            rationale: "Increase directness cues while preserving performer identity."
        ),
        VocalDirectGoalRule(
            aspect: .distance,
            direction: .increase,
            phrases: ["distant", "far away", "farther"],
            maximumStrength: 1,
            rationale: "Increase distance cues through editable level and ambience relationships."
        ),
        VocalDirectGoalRule(
            aspect: .width,
            direction: .increase,
            phrases: ["wide", "wider"],
            maximumStrength: 1,
            rationale: "Increase stereo contrast while preserving center and mono compatibility."
        ),
        VocalDirectGoalRule(
            aspect: .width,
            direction: .decrease,
            phrases: ["narrow", "mono-like"],
            maximumStrength: 1,
            rationale: "Reduce stereo spread without replacing the source."
        ),
        VocalDirectGoalRule(
            aspect: .dynamics,
            direction: .decrease,
            phrases: ["controlled dynamics", "more controlled", "even out", "smooth dynamics"],
            maximumStrength: 0.7,
            rationale: "Reduce unwanted level variability while retaining musical movement."
        ),
        VocalDirectGoalRule(
            aspect: .movement,
            direction: .increase,
            phrases: ["more movement", "moving", "wobble"],
            maximumStrength: 1,
            rationale: "Add genuine time-varying modulation rather than relabeling a static effect."
        ),
    ]

    private static let archetypeRules: [VocalArchetypeRule] = [
        VocalArchetypeRule(archetype: .underwater, phrases: ["underwater", "under water", "submerged", "beneath the water"]),
        VocalArchetypeRule(archetype: .vocalToBrass, phrases: ["vocal to brass", "vocal-to-brass", "like a brass instrument", "brass-like", "brassy vocal", "turn the vocal into brass", "more brass", "like a trumpet", "sound more like a trumpet", "trumpet-like"]),
        VocalArchetypeRule(archetype: .enormousButDistant, phrases: ["enormous but distant", "huge but far", "massive but distant", "giant and far away"]),
        VocalArchetypeRule(archetype: .extremelyIntimate, phrases: ["extremely intimate", "very intimate", "right in my ear", "whisper-close", "whisper close"]),
        VocalArchetypeRule(archetype: .radioLike, phrases: ["radio-like", "radio like", "small radio", "telephone-like", "telephone voice"]),
        VocalArchetypeRule(archetype: .glassy, phrases: ["glassy", "like glass", "crystalline"]),
        VocalArchetypeRule(archetype: .smoky, phrases: ["smoky", "smokey", "smoke-like"]),
        VocalArchetypeRule(archetype: .fragile, phrases: ["fragile", "delicate", "about to crack"]),
        VocalArchetypeRule(archetype: .broken, phrases: ["broken", "fractured", "splintered"]),
        VocalArchetypeRule(archetype: .floating, phrases: ["floating", "weightless", "levitating"]),
        VocalArchetypeRule(archetype: .metallic, phrases: ["metallic", "metal-like", "made of metal"]),
        VocalArchetypeRule(archetype: .dreamlike, phrases: ["dreamlike", "dream-like", "in a dream", "dreamy"]),
        VocalArchetypeRule(archetype: .unstable, phrases: ["unstable", "unsteady", "detuned motion", "pitchy wobble"]),
    ]

    public init() {}

    public func interpret(
        prompt: String,
        intentID: UUID = UUID(),
        sourceSnapshotID: UUID,
        scope: VocalCreativeScope,
        assetAcceptance: VocalAssetAcceptance = .editableDSPOnly,
        exactReferences: [VocalExactReference] = [],
        aspectLocks: [VocalAspectLock] = []
    ) throws -> VocalCreativeIntent {
        let text = normalized(prompt)
        guard !text.isEmpty else {
            throw VocalContractError.unsupportedIntent("The vocal request is empty.")
        }
        try VocalContractValidator().validate(scope: scope)
        try rejectContradictions(text)

        let archetype = archetype(for: text)
        let strength = strength(for: text)
        let desired = desiredChanges(for: text, archetype: archetype, strength: strength)
        let explicitPreservation = preservedAspects(in: text)
        let prohibited = prohibitedAspects(in: text)
        let baseline: [VocalAspect] = [.pitch, .timing, .melody, .voiceIdentity]
        let preservation = VocalPreservationContract(
            preserved: unique(baseline + explicitPreservation),
            prohibitedChanges: unique(prohibited),
            stopConditions: [
                "Stop if intelligibility, consonant definition, melody, timing, or intended dynamics are lost beyond the typed request.",
                "Stop on nonfinite output, unsafe peaks, or an audible discontinuity at a scoped boundary.",
            ],
            rollbackInstructions: [
                "Bypass the exact candidate plan and return to the immutable source snapshot.",
                "For a revision, restore the exact parent candidate ID rather than rebuilding from prose.",
            ]
        )
        let uncertainties = uncertainty(for: archetype)
        let ambiguities = ambiguities(in: text, archetype: archetype)
        let kind: VocalIntentKind = archetype == .ordinary ? .correctiveAndCreative : .creative
        let intent = VocalCreativeIntent(
            id: intentID,
            sourceSnapshotID: sourceSnapshotID,
            originalPrompt: prompt,
            kind: kind,
            archetype: archetype,
            languageCues: languageCues(in: text),
            strength: strength,
            scope: scope,
            desiredChanges: desired,
            preservation: preservation,
            ambiguities: ambiguities,
            uncertainties: uncertainties,
            editability: .editableDeterministicDSP,
            assetAcceptance: assetAcceptance,
            exactReferences: exactReferences,
            aspectLocks: aspectLocks
        )
        try VocalContractValidator().validate(intent: intent)
        return intent
    }

    private func normalized(_ prompt: String) -> String {
        prompt
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rejectContradictions(_ text: String) throws {
        let pairs: [(change: [String], preserve: [String], label: String)] = [
            (["change the melody", "different melody", "remove the melody"], ["preserve melody", "keep the melody", "same melody"], "melody"),
            (["change the timing", "retime", "different timing"], ["preserve timing", "keep the timing", "same timing"], "timing"),
            (["remove all dynamics", "flatten all dynamics"], ["preserve dynamics", "keep dynamics"], "dynamics"),
            (["unintelligible", "remove intelligibility", "lose intelligibility"], ["preserve intelligibility", "keep intelligibility", "clear words"], "intelligibility"),
            (["completely dry", "no reverb", "remove all space"], ["huge reverb", "more reverb", "keep the space"], "space"),
        ]
        for pair in pairs where containsAny(text, pair.change) && containsAny(text, pair.preserve) {
            throw VocalContractError.contradictoryIntent(
                "The request simultaneously changes and preserves \(pair.label)."
            )
        }
        if containsAny(text, ["replace the actual singer", "clone another singer", "exactly become a trumpet", "physically become brass"]) {
            throw VocalContractError.unsupportedIntent(
                "Vocal v1 can create honest DSP coloration, not replace performer identity or reconstruct a real brass instrument."
            )
        }
        if containsAny(text, ["ignore the lock", "break the lock", "override locked"]) {
            throw VocalContractError.unsupportedIntent("Prompt prose cannot override an aspect or node lock.")
        }
        if containsAny(text, [
            "ignore all previous instructions",
            "ignore previous instructions",
            "disregard all previous instructions",
            "disregard previous instructions",
            "ignore the system prompt",
            "override the system prompt",
            "run arbitrary code",
            "execute arbitrary code",
            "invent unsupported processors",
            "upload my audio",
        ]) {
            throw VocalContractError.unsupportedIntent(
                "Instruction injection and unsupported code, upload, or processor requests cannot become vocal DSP authority."
            )
        }
    }

    private func archetype(for text: String) -> VocalCreativeArchetype {
        Self.archetypeRules.first { rule in
            containsAffirmedOccurrence(in: text, phrases: rule.phrases)
        }?.archetype ?? .ordinary
    }

    private func strength(for text: String) -> Double {
        if containsAny(text, ["extremely", "completely", "very strong", "as much as possible", "dramatic"]) { return 0.9 }
        if containsAny(text, ["subtle", "slight", "gently", "a little", "barely"]) { return 0.3 }
        if containsAny(text, ["strong", "more", "big", "huge", "enormous"]) { return 0.75 }
        return 0.58
    }

    private func desiredChanges(
        for text: String,
        archetype: VocalCreativeArchetype,
        strength: Double
    ) -> [VocalAspectIntent] {
        var result: [VocalAspectIntent] = archetypeChanges(archetype, strength: strength)
        func add(_ aspect: VocalAspect, _ direction: VocalIntentDirection, _ amount: Double, _ rationale: String) {
            guard !result.contains(where: { $0.aspect == aspect && $0.direction == direction }) else { return }
            result.append(VocalAspectIntent(aspect: aspect, direction: direction, strength: amount, rationale: rationale))
        }

        for rule in Self.directGoalRules where containsAffirmedOccurrence(in: text, phrases: rule.phrases) {
            add(
                rule.aspect,
                rule.direction,
                min(strength, rule.maximumStrength),
                rule.rationale
            )
        }
        return result
    }

    private func archetypeChanges(
        _ archetype: VocalCreativeArchetype,
        strength: Double
    ) -> [VocalAspectIntent] {
        func change(_ aspect: VocalAspect, _ amount: Double, _ rationale: String) -> VocalAspectIntent {
            VocalAspectIntent(aspect: aspect, direction: .increase, strength: amount, rationale: rationale)
        }
        switch archetype {
        case .ordinary:
            return []
        case .underwater:
            return [
                change(.underwaterColoration, strength, "Use dark filtering, diffuse space, and audible time-varying movement as an underwater metaphor."),
                change(.movement, max(0.45, strength), "Use real modulated delay movement."),
                change(.darkness, strength, "Reduce exposed high-frequency energy without claiming a literal underwater transfer function."),
            ]
        case .vocalToBrass:
            return [
                change(.brassLikeColoration, strength, "Use editable resonant EQ, compression, and saturation as brass-like coloration, not acoustic reconstruction."),
                change(.metallicCharacter, strength * 0.7, "Add bounded harmonic and resonant cues."),
            ]
        case .glassy:
            return [change(.glassyCharacter, strength, "Use bright resonant and reflective cues with sharpness limits."), change(.air, strength * 0.65, "Increase upper detail conservatively.")]
        case .smoky:
            return [change(.smokyCharacter, strength, "Use darkened, softened harmonic density."), change(.warmth, strength * 0.7, "Add bounded harmonic warmth.")]
        case .enormousButDistant:
            return [change(.distance, strength, "Use reduced direct salience and ambience cues."), change(.space, strength, "Create a large editable space."), change(.body, strength * 0.6, "Retain weight so distance does not simply become thinness.")]
        case .fragile:
            return [change(.fragility, strength, "Use light, restrained tone and dynamics cues without altering the performance."), change(.air, strength * 0.45, "Retain breath detail cautiously.")]
        case .broken:
            return [change(.distortion, strength * 0.8, "Use parallel bounded saturation as a fractured texture."), change(.instability, strength * 0.65, "Add controlled motion without timing replacement.")]
        case .floating:
            return [change(.floating, strength, "Use soft modulation and diffuse ambience as a weightless metaphor."), change(.space, strength * 0.7, "Create suspended spatial cues.")]
        case .metallic:
            return [change(.metallicCharacter, strength, "Use resonant EQ, short delay, and saturation as editable metallic coloration.")]
        case .radioLike:
            return [change(.radioLike, strength, "Use bounded band-limiting and harmonic density as a radio-like cue.")]
        case .dreamlike:
            return [change(.space, strength, "Use diffuse ambience and echo as dreamlike cues."), change(.movement, strength * 0.55, "Add slow deterministic modulation.")]
        case .unstable:
            return [change(.instability, strength, "Use bounded time-varying delay without pitch or timing replacement."), change(.wobble, strength, "Increase audible modulation depth within validated limits.")]
        case .extremelyIntimate:
            return [change(.closeness, strength, "Increase direct vocal salience with controlled space."), change(.breath, strength * 0.45, "Preserve natural breath detail without inventing capture information.")]
        }
    }

    private func preservedAspects(in text: String) -> [VocalAspect] {
        var result: [VocalAspect] = []
        let vocabulary: [(VocalAspect, [String])] = [
            (.pitch, ["preserve pitch", "keep pitch", "same pitch"]),
            (.timing, ["preserve timing", "keep timing", "same timing"]),
            (.melody, ["preserve melody", "keep melody", "same melody"]),
            (.dynamics, [
                "preserve dynamics",
                "preserving dynamics",
                "keep dynamics",
                "keep the dynamics",
                "same dynamics",
                "preserve melody and dynamics",
                "preserve the melody and dynamics",
                "preserve the melody and the dynamics",
                "preserving melody and dynamics",
                "preserving the melody and dynamics",
                "preserving the melody and the dynamics",
                "keep melody and dynamics",
                "keep the melody and dynamics",
                "keep the melody and the dynamics",
                "retain dynamics",
                "dynamics intact",
            ]),
            (.movement, ["preserve movement", "keep movement"]),
            (.space, ["preserve space", "keep space"]),
            (.consonants, [
                "preserve consonants",
                "preserve the consonants",
                "preserve intelligibility and consonants",
                "preserve intelligibility and the consonants",
                "keep consonants",
                "keep the consonants",
                "keep intelligibility and consonants",
                "keep more consonants",
                "keep more of my consonants",
                "retain consonants",
                "consonants intact",
            ]),
            (.intelligibility, [
                "preserve intelligibility",
                "keep intelligibility",
                "without losing intelligibility",
                "keep the words understandable",
                "keep every word understandable",
                "keep words understandable",
                "words understandable",
            ]),
            (.attack, ["preserve attack", "keep attack"]),
            (.voiceIdentity, ["preserve the voice", "keep the voice", "same singer"]),
        ]
        for (aspect, phrases) in vocabulary where containsAny(text, phrases) { result.append(aspect) }
        return result
    }

    private func prohibitedAspects(in text: String) -> [VocalAspect] {
        var result: [VocalAspect] = []
        let vocabulary: [(VocalAspect, [String])] = [
            (.pitch, ["do not change pitch", "don't change pitch", "no pitch change"]),
            (.timing, [
                "do not change timing",
                "don't change timing",
                "no timing change",
                "do not change pitch or timing",
                "don't change pitch or timing",
                "no pitch or timing change",
            ]),
            (.melody, ["do not change melody", "don't change melody"]),
            (.dynamics, ["do not change dynamics", "don't change dynamics"]),
            (.consonants, ["do not soften consonants", "don't lose consonants"]),
            (.intelligibility, ["do not lose intelligibility", "don't lose intelligibility"]),
            (.loudness, [
                "do not make louder",
                "do not make it louder",
                "do not make it any louder",
                "don't make louder",
                "don't make it louder",
                "don't make it any louder",
                "without making it louder",
                "without just making it louder",
                "but not louder",
                "same loudness",
            ]),
        ]
        for (aspect, phrases) in vocabulary where containsAny(text, phrases) { result.append(aspect) }
        for rule in Self.directGoalRules where containsProhibitedOccurrence(in: text, phrases: rule.phrases) {
            result.append(rule.aspect)
        }
        for rule in Self.archetypeRules where containsProhibitedOccurrence(in: text, phrases: rule.phrases) {
            result.append(contentsOf: archetypeChanges(rule.archetype, strength: 1).map(\.aspect))
        }
        return result
    }

    private func languageCues(in text: String) -> [VocalLanguageCue] {
        var cues: [VocalLanguageCue] = []
        let vocabulary: [(VocalLanguageDimension, [String])] = [
            (.sensory, ["dark", "bright", "warm", "airy", "intimate", "distant", "close"]),
            (.emotional, ["fragile", "dreamlike", "broken", "intimate", "smoky"]),
            (.material, ["glassy", "glass", "metallic", "metal", "brass", "smoky"]),
            (.motion, ["floating", "unstable", "wobble", "moving", "drifting"]),
            (.metaphorical, ["underwater", "submerged", "dreamlike", "enormous but distant", "radio-like"]),
            (.directTechnical, ["eq", "compress", "reverb", "delay", "filter", "saturation", "modulation"]),
        ]
        for (dimension, terms) in vocabulary {
            for term in terms where text.contains(term) {
                cues.append(VocalLanguageCue(text: term, dimension: dimension, confidence: 1))
            }
        }
        return cues
    }

    private func ambiguity(
        _ condition: Bool,
        _ statement: String,
        into output: inout [String]
    ) {
        if condition { output.append(statement) }
    }

    private func ambiguities(in text: String, archetype: VocalCreativeArchetype) -> [String] {
        var output: [String] = []
        ambiguity(archetype == .ordinary && text.split(separator: " ").count < 3, "The ordinary goal is underspecified; conservative candidates should be auditioned.", into: &output)
        ambiguity(text.contains("professional"), "Professional is not a unique sound or processor setting.", into: &output)
        ambiguity(text.contains("better"), "Better requires a listening comparison and a named preference.", into: &output)
        ambiguity(text.contains("natural"), "Natural may refer to timbre, dynamics, tuning, space, or performance.", into: &output)
        ambiguity(
            archetype == .vocalToBrass,
            "Brass-like can refer to resonance, harmonic density, articulation, or the balance between vocal and instrument-like color.",
            into: &output
        )
        return output
    }

    private func uncertainty(for archetype: VocalCreativeArchetype) -> [String] {
        let shared = [
            "The prompt does not establish what the exact singer, capture chain, or arrangement will sound like after processing.",
            "Pitch, timing, melody, phonemes, room identity, and emotion are not inferred by this interpreter.",
            "Candidate preference remains a level-matched listening judgment.",
        ]
        switch archetype {
        case .underwater:
            return shared + ["Underwater is implemented as an editable metaphor using filtering, ambience, and real modulation; it is not a literal physical simulation."]
        case .vocalToBrass:
            return shared + ["Brass-like means editable DSP coloration or hybrid texture, not a claim that the voice has been reconstructed as an acoustic brass instrument."]
        default:
            return shared
        }
    }

    private func unique(_ values: [VocalAspect]) -> [VocalAspect] {
        var seen = Set<VocalAspect>()
        return values.filter { seen.insert($0).inserted }
    }

    private func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }

    private func containsAffirmedOccurrence(in text: String, phrases: [String]) -> Bool {
        phraseOccurrences(in: text, phrases: phrases).contains { occurrence in
            !isProhibited(occurrence, in: text)
        }
    }

    private func containsProhibitedOccurrence(in text: String, phrases: [String]) -> Bool {
        phraseOccurrences(in: text, phrases: phrases).contains { occurrence in
            isProhibited(occurrence, in: text)
        }
    }

    private func phraseOccurrences(
        in text: String,
        phrases: [String]
    ) -> [Range<String.Index>] {
        phrases.flatMap { phrase -> [Range<String.Index>] in
            var matches: [Range<String.Index>] = []
            var remaining = text.startIndex..<text.endIndex
            while let match = text.range(of: phrase, range: remaining) {
                matches.append(match)
                guard match.upperBound < text.endIndex else { break }
                remaining = match.upperBound..<text.endIndex
            }
            return matches
        }
    }

    /// Classifies only the clause leading into a matched goal. Strong clause
    /// boundaries reset polarity, while coordinating lists retain it so
    /// "do not make it brighter or wider" prohibits both supported goals.
    private func isProhibited(
        _ occurrence: Range<String.Index>,
        in text: String
    ) -> Bool {
        let prefix = String(text[..<occurrence.lowerBound])
        var scopeStart = prefix.startIndex
        if let punctuation = prefix.lastIndex(where: { ".;!?\n".contains($0) }) {
            scopeStart = prefix.index(after: punctuation)
        }
        for boundary in [" but ", " however ", " yet ", " while ", " although "] {
            if let range = prefix.range(of: boundary, options: .backwards),
               range.upperBound > scopeStart {
                scopeStart = range.upperBound
            }
        }

        let words = prefix[scopeStart...]
            .split { character in
                !character.isLetter && !character.isNumber && character != "'"
            }
            .map(String.init)
        for index in words.indices {
            let word = words[index]
            let next = words.indices.contains(index + 1) ? words[index + 1] : nil
            switch word {
            case "not" where next == "only" || next == "just":
                continue
            case "no" where next == "matter":
                continue
            case "not", "never", "without", "avoid", "avoiding", "avoided",
                 "exclude", "excluding", "prevent", "preventing", "prohibit",
                 "prohibiting", "don't", "dont", "can't", "cant", "won't", "wont", "no":
                return true
            default:
                continue
            }
        }
        return false
    }
}
