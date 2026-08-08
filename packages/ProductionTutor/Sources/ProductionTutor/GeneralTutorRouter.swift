import Foundation
import PlanSchema

/// Routes an arbitrary production question into a typed intent.
///
/// The defining property: this router never requires an enum match to
/// respond. Unrecognized wording produces a low-confidence intent with
/// visible uncertainty, not a refusal. The Tutor v1 issue vocabulary is
/// consulted as a fast path and recorded when it matches, but it is never a
/// precondition.
public struct GeneralTutorRouter: Sendable {
    private let tutorVocabulary = TutorIssueVocabulary()

    public init() {}

    // MARK: - Lexicons

    /// Domain cue terms. Matching is word-boundary aware and additive: a
    /// question may legitimately touch many domains.
    private static let domainCues: [(ProductionDomain, [String])] = [
        (.vocals, ["vocal", "vocals", "voice", "singer", "singing", "lead vox", "vox"]),
        (.drumsAndPercussion, ["drum", "drums", "snare", "kick", "hi-hat", "hihat", "cymbal", "percussion", "toms", "tom"]),
        (.bass, ["bass", "sub", "808", "low end", "bassline", "kick has no weight", "no weight"]),
        (.guitar, ["guitar", "guitars", "strum", "amp", "pedal", "acoustic guitar", "electric guitar"]),
        (.pianoAndKeys, ["piano", "keys", "keyboard", "rhodes", "wurlitzer", "organ"]),
        (.synth, ["synth", "synthesizer", "pad", "arp", "lead synth"]),
        (.fullMix, ["mix", "my mix", "the mix", "full mix", "whole song", "track sounds"]),
        (.master, ["master", "mastering", "mastered", "final master"]),
        (.referenceTrack, ["reference", "reference track", "commercial track", "use a reference"]),

        (.microphonePlacement, ["mic", "microphone", "mic position", "mic placement", "distance from the mic", "off-axis", "proximity", "pop filter", "plosive", "plosives", "capture"]),
        (.roomAndReflections, ["room", "reflections", "untreated", "acoustics", "echo in the room"]),
        (.gainStaging, ["gain staging", "gain structure", "input level", "levels too hot", "headroom"]),
        (.interfacesAndMonitoring, ["interface", "monitors", "headphones", "monitoring"]),
        (.performanceCapture, ["record", "recording", "tracking", "take", "performance", "re-record", "repair it later", "before tracking", "headphone bleed", "on the way in", "sample rate should i record", "how many takes"]),
        (.latency, ["latency", "delay when i play", "monitoring delay", "buffer"]),
        (.noise, ["noise", "hiss", "hum", "buzz", "background noise", "noise floor", "headphone bleed", "bleed"]),
        (.clipping, ["clipping", "clipped", "distorting", "in the red", "overload"]),
        (.doublingAndLayering, ["double", "doubling", "layer", "layering", "stack"]),

        (.comping, ["comp", "comping", "best take", "take folder"]),
        (.timingEditing, ["timing", "off time", "out of time", "line up", "tighten"]),
        (.fades, ["fade", "crossfade", "click at the edit"]),
        (.cleanup, ["clean up", "cleanup", "breaths", "between phrases", "silence between"]),
        (.pitchEditing, ["pitch", "tuning", "out of tune", "flex pitch", "autotune", "auto-tune"]),
        (.vocalAlignment, ["align", "alignment", "tighten the doubles", "stacked vocals"]),
        (.drumEditing, ["drum edit", "quantize the drums", "drum timing"]),
        (.regionEditing, ["region", "regions", "split", "trim"]),

        (.quantization, ["quantize", "quantise", "quantization", "grid", "snap to grid"]),
        (.smartQuantize, ["smart quantize"]),
        (.groove, ["groove", "feel", "swing", "pocket", "human feel"]),
        (.velocity, ["velocity", "velocities", "too loud notes", "note dynamics", "programmed drums", "programmed hi-hats", "machine-gunned", "sounds fake"]),
        (.noteLength, ["note length", "note lengths", "legato", "staccato"]),
        (.sustainPedal, ["sustain pedal", "pedal", "cc64"]),
        (.tempoMapping, ["tempo map", "tempo mapping", "beat mapping", "smart tempo", "tempo follow", "tempo change"]),
        (.rubato, ["rubato", "expressive timing", "free time", "breathe"]),
        (.handIndependence, ["left hand", "right hand", "both hands"]),
        (.humanization, ["humanize", "humanise", "robotic", "mechanical", "too perfect", "less static", "machine-gunned", "sounds fake", "stiff", "feel natural"]),
        (.articulation, ["articulation", "phrasing"]),

        (.gain, ["gain", "volume", "level", "louder", "quieter", "clip gain"]),
        (.polarityAndPhase, ["phase", "polarity", "out of phase", "phase cancellation", "flip the phase", "collapse", "collapses", "cancellation"]),
        (.eqAndFiltering, ["eq", "equalizer", "equaliser", "high pass", "low pass", "filter", "frequency", "boost", "cut", "what does q", "q mean", "what is q", "bandwidth"]),
        (.compression, ["compress", "compression", "compressor", "threshold", "ratio", "attack", "release", "makeup gain", "on the way in", "sit in a loud mix"]),
        (.expansionAndGating, ["gate", "gating", "expander", "noise gate"]),
        (.deEssing, ["de-ess", "deess", "de esser", "sibilance", "sibilant", "harsh s"]),
        (.dynamicEQ, ["dynamic eq"]),
        (.multiband, ["multiband", "multi-band"]),
        (.saturation, ["saturation", "saturate", "tape", "warmth", "harmonics", "drive"]),
        (.distortion, ["distortion", "distort", "fuzz", "overdrive"]),
        (.transientShaping, ["transient", "attack of the", "punch", "punchy", "snap", "hit harder", "hits harder", "more impact", "crack"]),
        (.pitchEffects, ["pitch shift", "harmonizer", "formant"]),
        (.modulation, ["chorus effect", "flanger", "phaser", "modulation", "tremolo", "vibrato"]),
        (.stereoImaging, ["stereo", "wide", "wider", "width", "imaging", "pan", "panning", "mid-side", "mid side"]),
        (.limiting, ["limiter", "limiting", "ceiling", "true peak", "distorting on the loud", "loud parts"]),
        (.metering, ["meter", "metering", "lufs", "rms", "peak meter"]),

        (.reverb, ["reverb", "verb", "chromaverb", "space designer", "room sound", "hall", "plate", "detached from the track", "feels detached"]),
        (.delay, ["delay", "echo", "throw", "slapback", "tape delay", "stereo delay"]),
        (.preDelay, ["pre-delay", "predelay", "pre delay"]),
        (.earlyReflections, ["early reflections"]),
        (.depth, ["depth", "far away", "distant", "close", "closer", "intimate", "in your face", "front to back", "disappear", "disappears", "pushed back", "too far back", "detached from the track"]),
        (.monoCompatibility, ["mono", "mono compatibility", "in mono", "mono collapse", "collapses in mono"]),

        (.buses, ["bus", "buses", "busses", "aux"]),
        (.sends, ["send", "sends", "return"]),
        (.parallelProcessing, ["parallel", "parallel compression", "new york compression", "blend in"]),
        (.sidechains, ["sidechain", "side-chain", "ducking", "duck", "bass and kick", "kick and bass"]),
        (.groupProcessing, ["group", "grouping", "stem", "submix"]),
        (.channelStripOrder, ["order", "before or after", "signal chain", "chain order", "plugin order"]),
        (.wetDryTopology, ["wet", "dry", "wet/dry", "mix knob", "blend"]),

        (.effectAutomation, ["automate a plug-in", "automate a plugin", "plug-in parameter", "plugin parameter", "automate the effect", "automate a delay"]),
        (.logicAutomation, ["automation in logic", "automate a plug-in", "plug-in parameter", "automation lane"]),
        (.drops, ["drop", "drops", "drop hit harder"]),
        (.roomProblems, ["trust my room", "my room", "room problems", "untreated room"]),
        (.levelAutomation, ["automation", "automate", "ride the level", "volume automation", "fader ride", "uneven in level", "uneven level", "across the verse"]),
        (.delayThrows, ["delay throw", "throw on the last word"]),
        (.sectionChanges, ["section change", "into the chorus", "transition into"]),

        (.mixDepth, ["create depth", "depth in a mix", "depth in the mix", "front to back in the mix", "front-to-back depth", "front to back depth"]),
        (.intros, ["intro", "intros", "opening", "pulls people in"]),
        (.headphonesVersusMonitors, ["headphones or monitors", "headphones versus monitors", "on headphones", "on monitors", "trust my room", "room or my headphones"]),
        (.peaks, ["peaks", "peaking", "distorting on the loud", "clipping the master"]),
        (.contrast, ["feels the same", "same all the way through", "no contrast", "hit harder", "feels like a repeat", "use silence", "second verse"]),
        (.density, ["density", "busy", "crowded", "cluttered", "too much going on", "sparse", "feels the same", "same all the way", "nothing stands out", "cluttering", "support without", "busy arrangement", "what to cut"]),
        (.contrast, ["contrast", "dynamics between sections", "same energy", "explode", "bigger", "lift", "arrival", "build energy"]),
        (.verseChorusDevelopment, ["chorus", "verse", "chorus feel", "bigger chorus", "chorus smaller"]),
        (.bridges, ["bridge"]),
        (.builds, ["build", "builds", "riser", "energy", "lift"]),
        (.transitions, ["transition", "transitions", "feel natural", "smooth versus abrupt", "tempo change"]),
        (.registerAllocation, ["register", "frequency range", "space for each", "fighting for the same", "same range", "fit two", "around a vocal"]),
        (.orchestration, ["arrangement", "arrange", "orchestration", "instrumentation", "parts", "support without", "busy arrangement", "what to cut"]),

        (.balance, ["balance", "too loud in the mix", "buried", "not cutting through", "sits behind", "sit under", "sit behind", "nothing stands out", "stands out", "sit in a loud mix", "sit in the mix", "vanishes in the mix", "support without", "fit two", "around a vocal", "stand out"]),
        (.masking, ["masking", "masked", "muddy together", "fighting", "clashing", "work together", "sit under", "sit behind", "no weight", "clear in solo", "vanishes in the mix", "fighting in the same", "same range", "cluttering", "around a vocal", "in solo", "fine alone", "alone but", "disappears under", "disappear under", "buried under", "lost under"]),
        (.tonalDistribution, ["tonal balance", "too bright", "too dark", "dull", "muddy", "boomy", "thin", "harsh", "boxy", "different between verses"]),
        (.translation, ["translate", "translation", "sounds different in the car", "different on speakers", "every system", "on a phone speaker", "small speakers"]),
        (.orderOfOperations, ["order of operations", "what first", "where do i start", "first thing", "how should i approach", "approach this mix", "start when mixing"]),

        (.loudness, ["loudness", "lufs", "streaming level", "how loud", "do i need to master", "only releasing online", "quieter than commercial"]),
        (.formatAndExport, ["export", "bounce", "render", "file format", "wav", "mp3"]),
        (.streamingDelivery, ["spotify", "apple music", "streaming", "normalization", "releasing online", "only releasing"]),

        (.listeningLevel, ["listening level", "monitor level", "loud when i turn it up", "quiet listening", "mixing quietly", "quietly actually help"]),
        (.earFatigue, ["ear fatigue", "ears tired", "fatiguing", "ears get tired", "after an hour", "listening breaks", "take breaks"]),
        (.comparisonBias, ["louder sounds better", "bias", "level matched", "level matching", "listen for when comparing", "when comparing"]),
        (.references, ["reference track", "use a reference", "reference properly", "against a reference", "comparing two masters", "two masters", "smaller than my reference", "than my reference", "commercial tracks"]),

        (.logicTools, ["logic tool", "tool menu", "marquee", "scissors", "flex tool", "freeze a track", "save cpu", "which tool"]),
        (.logicEditors, ["piano roll", "editor", "step editor", "event list", "score editor"]),
        (.flex, ["flex time", "flex", "flex pitch"]),
        (.smartTempo, ["smart tempo"]),
        (.pluginOperation, ["how do i open", "where is the", "plug-in window", "plugin window"]),
        (.projectAlternatives, ["project alternative", "alternatives", "version of the project", "two versions", "compare two versions"]),
        (.bounceAndExport, ["bounce in place", "freeze", "flatten"]),

        (.whatToTryFirst, ["what should i try", "what do i do first", "where do i start", "i am stuck", "i'm stuck", "stuck", "what should i fix first", "what should i fix", "try next", "first when", "should fix first", "advice on what"]),
        (.comparingApproaches, ["should i use", "or should i", "which is better", "versus", " vs ", "second-guessing", "trust my room", "tone or balance"]),
        (.knowingWhenToStop, ["when do i stop", "when should i stop", "how do i know when", "second-guessing", "over-eqing", "is finished", "when to stop", "take listening breaks"]),
        (.preservingIntent, ["without losing", "without ruining", "keep the character", "still sound like"]),
        (.sourceVersusProcessingDecision, ["re-record", "rerecord", "fix it in the mix", "at the source"]),
    ]

    private static let conceptCues = [
        "what is", "what are", "what does", "what's the difference", "difference between",
        "explain", "how does", "why does", "what actually", "meaning of",
    ]
    /// Workflow questions ask where something is or how to operate the host.
    /// A bare "how do i" is deliberately absent: "how do I make the snare hit
    /// harder" is a production strategy question, not a menu-location question.
    private static let workflowCues = [
        "where is", "where do i find", "where can i find", "which tool", "what tool",
        "how do i create", "how do i set up", "how do i open", "how do i make a tempo map",
        "how do i automate", "how do i use", "how do i add", "how do i enable",
        "how do i export", "how do i bounce", "how do i quantize", "how do i fix uneven",
        "how do i compare", "steps to", "how to set up", "how to create",
    ]
    private static let compareCues = [
        "should i use", "or should i", "which should", "which is better", "versus", " vs ",
        "better to", "instead of", "compare",
    ]
    private static let planCues = [
        "how should i record", "before tracking", "order of operations", "plan",
        "what should i check before", "how should i approach", "session",
    ]
    private static let tradeoffCues = [
        "but also", "but it", "however it", "at the cost of", "tradeoff", "trade-off",
        "helps but", "better but", "clearer but", "though it",
    ]
    private static let strategyCues = [
        "what should i try", "what are three", "ways to", "how should i approach",
        "what do i do first", "where do i start", "i am stuck", "i'm stuck",
        "strategy", "approach",
    ]
    private static let achieveCues = [
        "make it", "make the", "make my", "i want", "how do i get", "feel more",
        "sound more", "give it", "more open", "bigger", "warmer", "wider",
    ]
    private static let researchCues = [
        "new logic", "latest version", "just released", "new feature",
        "recently added", "current version", "newest", "logic 12.4", "logic 13",
    ]
    private static let exactInstructionCues = [
        "exactly", "step by step", "step-by-step", "how do i", "where is",
        "which menu", "walk me through", "show me how",
    ]
    private static let projectWideCues = [
        "my mix", "the mix", "other tracks", "the arrangement", "chorus", "verse",
        "bridge", "the song", "kick and bass", "together", "in the mix",
    ]

    // MARK: - Routing

    public func route(
        question: String,
        sourceType: SourceType,
        context: GeneralTutorUserContext = .empty,
        audioAvailable: Bool = false,
        explanationDepth: TutorExplanationDepth = .simple
    ) -> GeneralTutorQuestionIntent {
        let raw = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalize(raw)

        // Tutor v1 fast path: recorded when it matches, never required.
        let parsed = tutorVocabulary.parse(raw, sourceType: sourceType)

        var domains = matchedDomains(lowered)
        // The declared source type is itself a domain signal.
        if let sourceDomain = domain(for: sourceType), !domains.contains(sourceDomain) {
            domains.insert(sourceDomain, at: 0)
        }

        let kind = classify(lowered, parsed: parsed, domains: domains)
        let preservation = extractPreservation(lowered, raw: raw)
        let comparisons = extractComparisons(raw: raw, lowered: lowered)

        var uncertainty: [String] = []
        if domains.isEmpty {
            uncertainty.append(
                "TrackSmith could not confidently identify which production area this question is about, so the answer stays general."
            )
        }
        if !parsed.recognizedIssues.isEmpty, kind == .troubleshootProblem {
            // Recognized fast path; no extra uncertainty.
        } else if kind == .troubleshootProblem, parsed.recognizedIssues.isEmpty {
            uncertainty.append(
                "The reported problem is not one of the bounded issues TrackSmith recognizes exactly, so guidance is strategy-level rather than a validated step-by-step procedure."
            )
        }

        let requiresProjectWide = Self.projectWideCues.contains { contains(lowered, $0) }
        let requestsExact = Self.exactInstructionCues.contains { contains(lowered, $0) }
        let requiresResearch = Self.researchCues.contains { contains(lowered, $0) }

        // Clarification only when the question is genuinely too thin to route.
        let wordCount = lowered.split(separator: " ").count
        let tooThin = wordCount < 4 && domains.isEmpty && parsed.recognizedIssues.isEmpty
        let clarification = tooThin
            ? "Tell me a bit more: which part of the song or which instrument, and what you are hearing that bothers you?"
            : nil

        // Primary domains are the strongest signals; the rest are secondary.
        let primary = Array(domains.prefix(3))
        let secondary = Array(domains.dropFirst(3).prefix(6))

        return GeneralTutorQuestionIntent(
            questionKind: kind,
            primaryDomains: primary,
            secondaryDomains: secondary,
            sourceType: sourceType,
            problemSummary: raw,
            desiredOutcome: extractDesiredOutcome(raw: raw, lowered: lowered, kind: kind),
            namedEntities: extractNamedEntities(raw: raw),
            userContext: context,
            preservationConstraints: preservation,
            prohibitedOutcomes: [],
            comparisonAlternatives: comparisons,
            explanationDepth: explanationDepth,
            temporalScope: extractSection(lowered),
            audioAvailable: audioAvailable,
            requiresProjectWideContext: requiresProjectWide,
            requestsExactLogicInstructions: requestsExact,
            requiresCurrentResearch: requiresResearch,
            uncertainty: uncertainty,
            requiresClarification: clarification != nil,
            clarificationQuestion: clarification,
            recognizedTutorIssues: parsed.recognizedIssues.map(\.kind),
            unsupportedRequests: parsed.unsupported
        )
    }

    // MARK: - Classification

    private func classify(
        _ lowered: String,
        parsed: TutorParsedRequest,
        domains: [ProductionDomain]
    ) -> GeneralQuestionKind {
        // Capability refusals are routed as troubleshooting so the answer layer
        // can state the boundary rather than silently reclassifying.
        if !parsed.unsupported.isEmpty { return .troubleshootProblem }

        if Self.researchCues.contains(where: { contains(lowered, $0) }) { return .researchUnfamiliar }
        if Self.compareCues.contains(where: { contains(lowered, $0) }) { return .compareOptions }
        if Self.tradeoffCues.contains(where: { contains(lowered, $0) }) { return .diagnoseTradeoff }
        if Self.conceptCues.contains(where: { contains(lowered, $0) }) {
            // "how does X work" is a concept question; "how do i X" is workflow.
            if !contains(lowered, "how do i") { return .explainConcept }
        }
        if Self.planCues.contains(where: { contains(lowered, $0) }) { return .planSession }
        if Self.workflowCues.contains(where: { contains(lowered, $0) }) { return .exactWorkflowHelp }
        if Self.strategyCues.contains(where: { contains(lowered, $0) }) { return .productionStrategy }

        // A recognized bounded issue, or explicit problem language, is troubleshooting.
        if !parsed.recognizedIssues.isEmpty { return .troubleshootProblem }
        let problemLanguage = ["why does", "why is", "why do", "problem", "wrong", "sounds bad",
                               "doesn't sound", "does not sound", "too ", "not enough"]
        if problemLanguage.contains(where: { contains(lowered, $0) }) { return .troubleshootProblem }

        if Self.achieveCues.contains(where: { contains(lowered, $0) }) { return .achieveSoundOrFeeling }

        return domains.isEmpty ? .productionStrategy : .troubleshootProblem
    }

    private func matchedDomains(_ lowered: String) -> [ProductionDomain] {
        var scored: [(ProductionDomain, Int, Int)] = []
        for (domain, cues) in Self.domainCues {
            var hits = 0
            var longest = 0
            for cue in cues where contains(lowered, cue) {
                hits += 1
                longest = max(longest, cue.count)
            }
            if hits > 0 { scored.append((domain, hits, longest)) }
        }
        // Deterministic: more hits, then longer cue, then declaration order.
        let order = Dictionary(uniqueKeysWithValues: ProductionDomain.allCases.enumerated().map { ($1, $0) })
        return scored.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return (order[$0.0] ?? 0) < (order[$1.0] ?? 0)
        }.map(\.0)
    }

    private func domain(for sourceType: SourceType) -> ProductionDomain? {
        switch sourceType {
        case .vocal, .vocalBus: .vocals
        case .drums, .drumBus: .drumsAndPercussion
        case .bass: .bass
        case .guitar: .guitar
        case .keyboard: .pianoAndKeys
        case .synth: .synth
        case .fullMix: .fullMix
        case .reference: .referenceTrack
        case .unknown: nil
        }
    }

    // MARK: - Extraction

    private func extractPreservation(_ lowered: String, raw: String) -> [String] {
        var out: [String] = []
        let markers = ["without losing", "without making", "without ruining", "while keeping",
                       "but keep", "but still", "without getting", "keep the"]
        for marker in markers {
            guard let range = raw.lowercased().range(of: marker) else { continue }
            let tail = raw[range.lowerBound...]
            let clause = tail.prefix(120)
                .split(whereSeparator: { ".!?;".contains($0) })
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespaces)
            if let clause, !clause.isEmpty, !out.contains(clause) { out.append(clause) }
        }
        return Array(out.prefix(4))
    }

    private func extractComparisons(raw: String, lowered: String) -> [String] {
        // "A or B" / "A versus B" phrasing, kept as display-only strings.
        for separator in [" or ", " versus ", " vs "] {
            guard contains(lowered, separator.trimmingCharacters(in: .whitespaces)) else { continue }
            let parts = raw.components(separatedBy: separator)
            guard parts.count == 2 else { continue }
            let left = parts[0].split(whereSeparator: { ",?.".contains($0) }).last.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? parts[0]
            let right = parts[1].split(whereSeparator: { ",?.".contains($0) }).first.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? parts[1]
            if !left.isEmpty, !right.isEmpty, left.count < 60, right.count < 60 {
                return [left, right]
            }
        }
        return []
    }

    private func extractDesiredOutcome(raw: String, lowered: String, kind: GeneralQuestionKind) -> String {
        for marker in ["i want ", "make it ", "make the ", "make my ", "so that "] {
            guard let range = lowered.range(of: marker) else { continue }
            let tail = String(raw[range.lowerBound...]).prefix(160)
            return tail.trimmingCharacters(in: .whitespaces)
        }
        return kind == .achieveSoundOrFeeling ? raw : ""
    }

    private func extractSection(_ lowered: String) -> String? {
        for section in ["chorus", "verse", "bridge", "intro", "outro", "pre-chorus", "drop"] {
            if contains(lowered, section) { return section }
        }
        return nil
    }

    /// Recognizes quoted strings and known Logic processor names only. Never
    /// invents an identity, and never treats an extracted name as authority.
    private func extractNamedEntities(raw: String) -> [String] {
        var out: [String] = []
        let known = ["Channel EQ", "Compressor", "DeEsser 2", "Noise Gate", "ChromaVerb",
                     "Space Designer", "Stereo Delay", "Tape Delay", "Smart Quantize",
                     "Flex Time", "Flex Pitch", "Smart Tempo", "Adaptive Limiter"]
        let lowered = raw.lowercased()
        for name in known where lowered.contains(name.lowercased()) { out.append(name) }
        return Array(out.prefix(6))
    }

    // MARK: - Helpers

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func contains(_ text: String, _ phrase: String) -> Bool {
        let needle = phrase.lowercased()
        // Leading/trailing spaces in a cue are intentional boundary markers.
        if needle.hasPrefix(" ") || needle.hasSuffix(" ") { return text.contains(needle) }
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        guard let expression = try? NSRegularExpression(pattern: "\\b\(escaped)") else {
            return text.contains(needle)
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }
}
