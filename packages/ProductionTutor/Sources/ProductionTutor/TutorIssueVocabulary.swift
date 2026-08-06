import Foundation
import PlanSchema

/// Perceived tutor problems. Deliberately separate from the closed
/// `ProductionTerm` enum: a reported issue is a perception, not a proven cause
/// and not an executable intent.
public enum TutorIssueKind: String, Codable, CaseIterable, Sendable {
    case nasalOrHonky
    case congested
    case boxy
    case muddy
    case harsh
    case sibilant
    case thin
    case boomy
    case dull
    case inconsistentLevel
    case overcompressed
    case tooDry
    case tooWet
    case tooDistant
    case noisyBetweenPhrases
    case plosive
    case clippingOrOverload
    case unclearOrBuried
}

public struct TutorIssueRecognition: Codable, Equatable, Sendable {
    public var kind: TutorIssueKind
    public var matchedPhrase: String

    public init(kind: TutorIssueKind, matchedPhrase: String) {
        self.kind = kind
        self.matchedPhrase = matchedPhrase
    }
}

/// Structured qualifiers recognized alongside issues. Aliases are recognition
/// evidence only; they are never proof of cause.
public struct TutorRequestQualifiers: Codable, Equatable, Sendable {
    public var vowelSpecific: Bool
    public var afterCompression: Bool
    public var sectionSpecific: Bool
    public var preserveCharacter: Bool
    public var preserveClarity: Bool
    public var wantsOpenNotDull: Bool
    public var unsureOfCause: Bool

    public init(
        vowelSpecific: Bool = false,
        afterCompression: Bool = false,
        sectionSpecific: Bool = false,
        preserveCharacter: Bool = false,
        preserveClarity: Bool = false,
        wantsOpenNotDull: Bool = false,
        unsureOfCause: Bool = false
    ) {
        self.vowelSpecific = vowelSpecific
        self.afterCompression = afterCompression
        self.sectionSpecific = sectionSpecific
        self.preserveCharacter = preserveCharacter
        self.preserveClarity = preserveClarity
        self.wantsOpenNotDull = wantsOpenNotDull
        self.unsureOfCause = unsureOfCause
    }
}

/// Requests the tutor must refuse or bound rather than serve.
public enum TutorUnsupportedRequest: String, Codable, CaseIterable, Sendable {
    case hostAutomationRequested
    case destructiveActionRequested
    case namedArtistCloningRequested
}

public struct TutorParsedRequest: Codable, Equatable, Sendable {
    public var requestKind: TutorRequestKind
    public var recognizedIssues: [TutorIssueRecognition]
    public var qualifiers: TutorRequestQualifiers
    public var unsupported: [TutorUnsupportedRequest]

    public init(
        requestKind: TutorRequestKind,
        recognizedIssues: [TutorIssueRecognition],
        qualifiers: TutorRequestQualifiers,
        unsupported: [TutorUnsupportedRequest]
    ) {
        self.requestKind = requestKind
        self.recognizedIssues = recognizedIssues
        self.qualifiers = qualifiers
        self.unsupported = unsupported
    }
}

public struct TutorIssueDefinition: Codable, Equatable, Sendable {
    public var kind: TutorIssueKind
    public var aliases: [String]
    public var applicableSourceTypes: [SourceType]
    public var recognitionBoundary: String

    public init(
        kind: TutorIssueKind,
        aliases: [String],
        applicableSourceTypes: [SourceType],
        recognitionBoundary: String
    ) {
        self.kind = kind
        self.aliases = aliases
        self.applicableSourceTypes = applicableSourceTypes
        self.recognitionBoundary = recognitionBoundary
    }
}

public enum TutorIssueVocabularyError: Error, Equatable, Sendable {
    case missingDefinition(TutorIssueKind)
    case emptyAliases(TutorIssueKind)
    case duplicateAlias(String)
}

public struct TutorIssueVocabulary: Sendable {
    public let version = "1.0"
    public let definitions: [TutorIssueDefinition]

    private static let vocalish: [SourceType] = [.vocal, .vocalBus]
    private static let broad: [SourceType] = [
        .vocal, .vocalBus, .drums, .drumBus, .bass, .guitar, .keyboard, .synth, .fullMix,
    ]

    public init() {
        definitions = [
            .init(
                kind: .nasalOrHonky,
                aliases: [
                    "nasal", "nasally", "nasality", "honky", "honk", "pinched",
                    "singing through my nose", "sound like i am singing through my nose",
                    "sounds like it is coming through the nose", "through my nose",
                    "sound nasal", "sounds nasal", "sounding nasal",
                ],
                applicableSourceTypes: Self.vocalish,
                recognitionBoundary: "A perceived pinched or honky midrange quality. The cause may be performance, capture, room, processing, or a static or vowel-dependent resonance; recognition proves none of these."
            ),
            .init(
                kind: .congested,
                aliases: ["congested", "stuffed up", "stuffy", "blocked up", "cold-sounding voice"],
                applicableSourceTypes: Self.vocalish,
                recognitionBoundary: "A perceived closed or blocked quality, often overlapping nasal or muddy reports."
            ),
            .init(
                kind: .boxy,
                aliases: ["boxy", "boxiness", "papery", "hollow", "cardboard"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "A perceived narrow midrange coloration; not interchangeable with nasal or honky."
            ),
            .init(
                kind: .muddy,
                aliases: ["muddy", "mud", "muddiness", "cloudy", "thick and unclear"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived low-mid congestion or masking; arrangement or another source may be responsible."
            ),
            .init(
                kind: .harsh,
                aliases: ["harsh", "harshness", "abrasive", "brash", "hurts my ears", "fatiguing"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived fatiguing upper-mid energy; events may be sparse or continuous."
            ),
            .init(
                kind: .sibilant,
                aliases: [
                    "sibilant", "sibilance", "essy", "harsh s sounds", "s sounds too sharp",
                    "s sounds are too sharp", "sharp s sounds", "de-ess", "deess",
                ],
                applicableSourceTypes: Self.vocalish,
                recognitionBoundary: "Perceived consonant-band bursts on s/sh/t sounds; distinct from broadband harshness."
            ),
            .init(
                kind: .thin,
                aliases: ["thin", "thinner", "weak", "no body", "lightweight", "small-sounding"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived lack of body; sometimes misdescribed as nasal when low-mid support is missing."
            ),
            .init(
                kind: .boomy,
                aliases: ["boomy", "boom", "tubby", "bloated", "too much bass on my voice"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived excessive low-frequency sustain or concentration."
            ),
            .init(
                kind: .dull,
                aliases: ["dull", "muffled", "dark and lifeless", "no air", "lost its sparkle"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived missing upper-spectrum openness; can result from over-correction."
            ),
            .init(
                kind: .inconsistentLevel,
                aliases: [
                    "inconsistent level", "uneven volume", "some words disappear",
                    "jumps out then disappears", "level is all over the place", "uneven levels",
                ],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived word-to-word or phrase-to-phrase loudness variation."
            ),
            .init(
                kind: .overcompressed,
                aliases: [
                    "overcompressed", "over compressed", "squashed", "pumping",
                    "lifeless and flat", "compression is too much",
                ],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived loss of dynamics or pumping attributed to compression; attribution is unverified."
            ),
            .init(
                kind: .tooDry,
                aliases: ["too dry", "dry", "needs space", "no ambience", "sounds dead"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived lack of ambience or depth."
            ),
            .init(
                kind: .tooWet,
                aliases: ["too wet", "too much reverb", "drowning in reverb", "washy", "swimming"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived excessive ambience or delay wash."
            ),
            .init(
                kind: .tooDistant,
                aliases: ["too distant", "far away", "recessed", "buried in the back", "not up front"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived excessive distance; level, ambience, tone, and arrangement all contribute."
            ),
            .init(
                kind: .noisyBetweenPhrases,
                aliases: [
                    "noisy between phrases", "hiss between lines", "room noise between words",
                    "breaths and noise between phrases", "noise when i stop singing",
                ],
                applicableSourceTypes: Self.vocalish,
                recognitionBoundary: "Perceived noise floor audible in gaps; gating decisions risk cutting breaths and tails."
            ),
            .init(
                kind: .plosive,
                aliases: ["plosive", "plosives", "p pops", "popping p sounds", "wind thumps on words"],
                applicableSourceTypes: Self.vocalish,
                recognitionBoundary: "Perceived low-frequency thumps on p/b consonants."
            ),
            .init(
                kind: .clippingOrOverload,
                aliases: ["clipping", "clipped", "overloaded", "distorting", "crackling when loud", "in the red"],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived overload artifacts; capture-stage clipping cannot be repaired by later processing."
            ),
            .init(
                kind: .unclearOrBuried,
                aliases: [
                    "unclear", "buried", "can't hear the words", "cannot hear the words",
                    "lost in the mix", "not cutting through",
                ],
                applicableSourceTypes: Self.broad,
                recognitionBoundary: "Perceived intelligibility or masking problem; often an arrangement or balance question."
            ),
        ]
    }

    public func validate() throws {
        var seen: Set<String> = []
        for kind in TutorIssueKind.allCases {
            guard let definition = definitions.first(where: { $0.kind == kind }) else {
                throw TutorIssueVocabularyError.missingDefinition(kind)
            }
            guard !definition.aliases.isEmpty else {
                throw TutorIssueVocabularyError.emptyAliases(kind)
            }
            for alias in definition.aliases {
                guard seen.insert(alias.lowercased()).inserted else {
                    throw TutorIssueVocabularyError.duplicateAlias(alias)
                }
            }
        }
    }

    // MARK: - Parsing

    public func parse(_ text: String, sourceType: SourceType) -> TutorParsedRequest {
        let lowered = normalized(text)
        var recognitions: [TutorIssueRecognition] = []
        for definition in definitions
            where definition.applicableSourceTypes.contains(sourceType) {
            // Longest alias first so "too much reverb" wins over "reverb"-adjacent phrasing.
            for alias in definition.aliases.sorted(by: { $0.count > $1.count }) {
                guard let range = phraseRange(lowered, phrase: alias) else { continue }
                // "without making me dull" is a preservation concern, not a
                // reported dullness problem. A negated alias never becomes an
                // issue report.
                if isNegated(lowered, before: range) { continue }
                recognitions.append(.init(kind: definition.kind, matchedPhrase: alias))
                break
            }
        }

        let qualifiers = TutorRequestQualifiers(
            vowelSpecific: containsAny(lowered, [
                "vowel", "vowels", "ee sound", "ee sounds", "certain sounds stick out",
                "only on some words", "certain words",
            ]),
            afterCompression: containsAny(lowered, [
                "after compression", "after i compressed", "after compressing",
                "when i compress", "since i added the compressor", "became nasal after",
            ]),
            sectionSpecific: containsAny(lowered, [
                "only in the chorus", "only in the verse", "just the chorus",
                "in the chorus", "one section", "certain sections",
            ]),
            preserveCharacter: containsAny(lowered, [
                "keep the character", "recognizable character", "keep my voice",
                "still sound like me", "keep the identity", "natural character",
            ]),
            preserveClarity: containsAny(lowered, [
                "preserve clarity", "keep the clarity", "without losing clarity",
                "keep it clear", "but keep clarity",
            ]),
            wantsOpenNotDull: containsAny(lowered, [
                "more open", "without making me dull", "without getting dull",
                "open and full", "not dull", "without dulling",
            ]),
            unsureOfCause: containsAny(lowered, [
                "don't know whether", "do not know whether", "not sure if it is the mic",
                "not sure what is causing", "no idea what causes", "mic or eq",
                "microphone or eq", "don't know if", "do not know if",
            ])
        )

        var unsupported: [TutorUnsupportedRequest] = []
        if containsAny(lowered, [
            "click the", "click on logic", "press the button for me", "change it for me in logic",
            "control logic for me", "move the fader for me", "open logic and change",
            "do it in logic for me", "adjust logic yourself", "click logic",
            "fix my mix automatically", "fix it automatically", "just fix my mix",
            "fix my mix for me", "do it automatically", "automatically fix",
        ]) {
            unsupported.append(.hostAutomationRequested)
        }
        if containsAny(lowered, [
            "bounce in place", "replace the file", "overwrite the file", "flatten",
            "normalize the file", "delete the original", "destructively", "replace my recording",
            "convert the region",
        ]) {
            unsupported.append(.destructiveActionRequested)
        }
        if containsAny(lowered, [
            "exactly like", "sound exactly the same as", "clone the voice", "identical to the record",
            "copy the artist", "make me sound like ",
        ]) {
            unsupported.append(.namedArtistCloningRequested)
        }

        let kind = classifyKind(lowered, hasIssues: !recognitions.isEmpty)
        return TutorParsedRequest(
            requestKind: kind,
            recognizedIssues: recognitions,
            qualifiers: qualifiers,
            unsupported: unsupported
        )
    }

    private func classifyKind(_ lowered: String, hasIssues: Bool) -> TutorRequestKind {
        if containsAny(lowered, [
            "what is q", "what does q mean", "explain", "what is a threshold",
            "what does attack", "what does release", "what is level matching",
            "what is wet/dry", "what is wet dry", "what is resonance",
        ]) {
            return .explainConcept
        }
        if containsAny(lowered, ["where is", "how do i open", "how do i find", "where do i find"]) {
            return .workflowHelp
        }
        if hasIssues { return .troubleshootProblem }
        return .achieveSound
    }

    private func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { containsPhrase(text, phrase: $0) }
    }

    /// Word-boundary-aware containment so "dry" does not match inside "laundry".
    private func containsPhrase(_ text: String, phrase: String) -> Bool {
        phraseRange(text, phrase: phrase) != nil
    }

    private func phraseRange(_ text: String, phrase: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: phrase.lowercased())
        guard let expression = try? NSRegularExpression(pattern: "\\b\(escaped)\\b") else {
            return text.range(of: phrase.lowercased())
        }
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: full) else { return nil }
        return Range(match.range, in: text)
    }

    private static let negationMarkers = [
        "without", "avoid", "don't want", "do not want", "not become", "not becoming",
        "not turn", "not make", "not making", "never", "keep it from", "stop it from",
        "prevent", "instead of", "but not",
    ]

    /// True when a short window before the matched alias contains a negation
    /// marker, so the phrase reads as a preservation concern.
    private func isNegated(_ text: String, before range: Range<String.Index>) -> Bool {
        let windowStart = text.index(
            range.lowerBound,
            offsetBy: -36,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let window = String(text[windowStart..<range.lowerBound])
        return Self.negationMarkers.contains { window.contains($0) }
    }
}
