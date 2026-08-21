import CryptoKit
import Foundation

/// Immutable, content-addressed projection of unreviewed community packages.
/// Candidate cards can improve recall but never become reviewed knowledge or an
/// exact Logic procedure catalog merely by being present in this store.
public struct CommunityCandidateCorpusPackageDescriptor: Codable, Equatable, Sendable {
    public var packageID: String
    public var version: String
    public var packageSequence: Int
    public var domains: [String]
    public var resourceName: String
    public var resourceSHA256: String
    public var packageManifestSHA256: String
    public var canonicalCount: Int
    public var utteranceCount: Int
    public var contradictionCount: Int
    public var mythCount: Int
    public var scenarioCount: Int
    public var retrievalCaseCount: Int
    public var evaluationCaseCount: Int
    public var evaluationKindCounts: [String: Int]
    public var canonicalOriginalStatus: String
    public var utteranceOriginalStatus: String?
    public var contradictionOriginalStatus: String?
    public var mythOriginalStatus: String?
    public var claimOriginalStatus: String
    public var strategyOriginalStatus: String
    public var procedureOriginalStatus: String
    public var legacyCoreProjectionSHA256: String?
    /// P10 keeps raw utterance accounting in its descriptor/evaluation fixture
    /// while shipping a canonical-card-only resource with zero utterance text.
    public var runtimeCanonicalOnly: Bool = false
    /// Canonical-only is independent from provenance redaction: only packages
    /// that declare this capability omit card-level status fields at runtime.
    public var runtimeStatusFree: Bool = false
}

public struct CommunityCandidateCard: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var packageID: String
    public var version: String
    public var domain: String
    public var category: String
    /// Optional stable source topic; legacy package resources decode unchanged.
    public var topic: String?
    public var title: String
    public var question: String
    /// Status-free runtime packages intentionally omit per-card review/status
    /// keys. Their candidate boundary remains package-level in raw state.
    public var originalReviewStatus: String?
    public var sourceTypes: [String]
    public var evidenceClass: String
    public var logicVersion: String?
    public var currentContext: Bool
    public var tags: [String]
    public var clarificationQuestions: [String]
    public var competingHypotheses: [String]
    public var recommendedFirstExperiment: String
    public var rationale: String
    public var listeningCues: [String]
    public var stopOrUndo: [String]
    public var tradeoffs: [String]
    public var teachingPrinciple: String
    public var numericGuidancePolicy: String
    /// Package-3-only candidate metadata. Nil preserves Package 1/2 resource shape.
    public var packageSequence: Int?
    public var subcategory: String?
    public var tracksmithDomains: [String]?
    public var preservationGoals: [String]?
    public var nonDSPPossibilities: [String]?
    public var startingPoints: [String]?
    public var commonMistakes: [String]?
    public var rawCommunityDisagreementIDs: [String]?
    public var roleFacets: [String]?
    public var sectionFacets: [String]?
    /// Candidate-only Package 5 decision context. These fields intentionally
    /// omit every procedure body, navigation path, visual query, and step list.
    public var directCandidateAnswer: String?
    public var keyDistinction: String?
    public var firstExperiment: String?
    public var listenFor: String?
    public var nonAutomationPossibilities: [String]?
    /// Package-6 candidate hypotheses outside nonlinear/transient processing.
    public var nonProcessingPossibilities: [String]?
    public var evidenceNeeded: [String]?
    public var userIntent: String?
    public var procedureCandidateID: String?
    public var procedureVerificationStatus: String?
    /// Absent for runtime projections that intentionally exclude authority
    /// labels while retaining source provenance in non-runtime records.
    public var authoritativeSupportingSourceIDs: [String]?
    /// P9 standards remain a distinct provenance partition; absent in P1–P8.
    public var standardsSourceIDs: [String]?
    public var primaryResearchSourceIDs: [String]?
    public var professionalPracticeSourceIDs: [String]
    public var discoveryLanguageSourceIDs: [String]
    public var contradictions: [CommunityCandidateContradiction]
    public var myths: [CommunityCandidateMyth]
}

public struct CommunityCandidateContradiction: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var summary: String
    public var whatDecides: String
    public var tutorBehavior: String
    public var originalReviewStatus: String
    public var sourceIDs: [String]?
    public var sourceEvidenceClasses: [String]?
}

public struct CommunityCandidateMyth: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var myth: String
    public var correction: String
    public var originalReviewStatus: String
    public var sourceIDs: [String]?
    public var sourceEvidenceClasses: [String]?
}

public struct CommunityCandidateCorpusFilters: Equatable, Sendable {
    public var domain: String?; public var category: String?; public var sourceType: String?
    public var evidenceClass: String?; public var logicVersion: String?; public var currentContext: Bool?
    public var packageID: String?; public var packageVersion: String?; public var role: String?; public var section: String?
    public init(domain: String? = nil, category: String? = nil, sourceType: String? = nil, evidenceClass: String? = nil, logicVersion: String? = nil, currentContext: Bool? = nil, packageID: String? = nil, packageVersion: String? = nil, role: String? = nil, section: String? = nil) {
        self.domain=domain; self.category=category; self.sourceType=sourceType; self.evidenceClass=evidenceClass; self.logicVersion=logicVersion; self.currentContext=currentContext; self.packageID=packageID; self.packageVersion=packageVersion; self.role=role; self.section=section
    }
}
public struct CommunityCandidateCorpusRankedCard: Equatable, Sendable {
    public var card: CommunityCandidateCard
    /// A relative internal retrieval value, not an authority or confidence claim.
    public var score: Int
    public var deduplicatedCandidates: Int
    public var lexicalOverlap: Int = 0
    public var lexicalCoverage: Double = 0
    public var scoreMargin: Double = 0
    public var ambiguity: Bool = false
}

public struct CommunityCandidateUtterance: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var canonicalID: String
    public var text: String
    public var originalReviewStatus: String
}

private struct CommunityCandidatePackageResource: Codable, Sendable {
    var schemaVersion: String
    var packageID: String
    var packageManifestSHA256: String
    var canonicalCards: [CommunityCandidateCard]
    var utterances: [CommunityCandidateUtterance]
    var contradictions: [CommunityCandidateContradiction]
    var myths: [CommunityCandidateMyth]
    var legacyCoreProjectionSHA256: String?
}

private struct CommunityCandidateRuntimeLeakProbe: Codable {
    var cards: [CommunityCandidateCard]
    var utterances: [CommunityCandidateUtterance]
    var contradictions: [CommunityCandidateContradiction]
    var myths: [CommunityCandidateMyth]
}

/// A unified view over independently versioned package resources. Scenarios and
/// retrieval cases deliberately live only in the TutorConversationTests bundle.
public struct CommunityCandidateCorpus: Equatable, Sendable {
    public var descriptors: [CommunityCandidateCorpusPackageDescriptor]
    public var canonicalCards: [CommunityCandidateCard]
    public var utterances: [CommunityCandidateUtterance]
    public var contradictions: [CommunityCandidateContradiction]
    public var myths: [CommunityCandidateMyth]
    private var exactUtteranceIDs: [String: [String]]
    private var cardTokens: [String: Set<String>]
    private var utteranceTokens: [String: Set<String>]
    private var tokenPostingIDs: [String: Set<String>]
    private var tokenPostingIDsByPackage: [String: [String: Set<String>]]
    private var utterancesByID: [String: CommunityCandidateUtterance]

    public func card(_ id: String) -> CommunityCandidateCard? {
        canonicalCards.first { $0.id == id }
    }

    public func descriptor(_ packageID: String) -> CommunityCandidateCorpusPackageDescriptor? {
        descriptors.first { $0.packageID == packageID }
    }

    public func containsExactNormalizedUtterance(_ query: String) -> Bool {
        // P16 reserves equality identity for the research/test-only index. The
        // runtime projection may retain ordinary utterance token postings for
        // lexical recall, but it must never expose an exact-alias authority.
        false
    }

    /// Internal migration-integrity seam used by the corpus evaluation harness.
    public func exactNormalizedCanonicalIDs(_ query: String) -> [String] {
        // Keep this compatibility seam deliberately empty in production. The
        // P16 development SQLite owns the corresponding test-only lookup.
        []
    }

    public static func loadValidated() throws -> CommunityCandidateCorpus {
        let descriptors = CommunityCandidateCorpusGenerated.descriptors
        guard !descriptors.isEmpty,
              Set(descriptors.map(\.packageID)).count == descriptors.count,
              Set(descriptors.map(\.resourceName)).count == descriptors.count else { throw CommunityCandidateCorpusError.missingResource("duplicate descriptors") }
        var packages: [CommunityCandidatePackageResource] = []
        for descriptor in descriptors.sorted(by: { $0.packageID < $1.packageID }) {
            let data = try resourceData(named: descriptor.resourceName)
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard actual == descriptor.resourceSHA256 else {
                throw CommunityCandidateCorpusError.checksumMismatch(expected: descriptor.resourceSHA256, actual: actual)
            }
            let package = try JSONDecoder().decode(CommunityCandidatePackageResource.self, from: data)
            guard package.packageID == descriptor.packageID,
                  package.packageManifestSHA256 == descriptor.packageManifestSHA256,
                  package.legacyCoreProjectionSHA256 == descriptor.legacyCoreProjectionSHA256 else {
                throw CommunityCandidateCorpusError.manifestMismatch(descriptor.packageID)
            }
            packages.append(package)
        }
        let corpus = CommunityCandidateCorpus(
            descriptors: descriptors.sorted { $0.packageID < $1.packageID },
            canonicalCards: packages.flatMap(\.canonicalCards).sorted { $0.id < $1.id },
            utterances: packages.flatMap(\.utterances).sorted { $0.id < $1.id },
            contradictions: packages.flatMap(\.contradictions).sorted { $0.id < $1.id },
            myths: packages.flatMap(\.myths).sorted { $0.id < $1.id },
            exactUtteranceIDs: [:], cardTokens: [:], utteranceTokens: [:], tokenPostingIDs: [:], tokenPostingIDsByPackage: [:], utterancesByID: [:]
        )
        try CommunityCandidateCorpusValidator().validate(corpus)
        return corpus.indexed()
    }

    private static func resourceData(named name: String) throws -> Data {
        let ns = name as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: CommunityCandidateBundleLocator.self)
        #endif
        if let url = bundle.url(forResource: base, withExtension: ext) {
            return try Data(contentsOf: url)
        }
        // Package 018 keeps the JSON ranker as a test oracle only. Production
        // bundles never contain these resources; a test executable must opt in
        // with the explicit directory set by its fixture harness.
        if let directory = ProcessInfo.processInfo.environment["TRACKSMITH_LEGACY_TEST_ORACLE_DIRECTORY"],
           directory.hasPrefix("/"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent(name)) {
            return data
        }
        throw CommunityCandidateCorpusError.missingResource(name)
    }

    public func rank(query: String, filters: CommunityCandidateCorpusFilters = .init()) -> CommunityCandidateCorpusRankedCard? {
        let normalized = query.normalizedCandidateCorpusText
        let tokens = normalized.candidateCorpusTokens
        guard !tokens.isEmpty else { return nil }
        let filtered = canonicalCards.filter { card in
            (filters.domain == nil || card.domain == filters.domain) && (filters.category == nil || card.category == filters.category) &&
            (filters.sourceType == nil || card.sourceTypes.contains(filters.sourceType!)) && (filters.evidenceClass == nil || card.evidenceClass == filters.evidenceClass) &&
            (filters.logicVersion == nil || card.logicVersion?.localizedCaseInsensitiveContains(filters.logicVersion!) == true) &&
            (filters.currentContext == nil || card.currentContext == filters.currentContext) && (filters.packageID == nil || card.packageID == filters.packageID) && (filters.packageVersion == nil || card.version == filters.packageVersion) &&
            (filters.role == nil || card.roleFacets?.contains(filters.role!) == true) && (filters.section == nil || card.sectionFacets?.contains(filters.section!) == true)
        }
        let allowed = Set(filtered.map(\.id)); guard !allowed.isEmpty else { return nil }
        // P16 intentionally has no equality/alias fast path.  Exact fixtures
        // and collisions are test-only development-index data; normal runtime
        // retrieval continues below with bounded lexical/context evidence.
        let hasStructuralCue = !tokens.intersection(candidateCorpusStructuralCueTokens).isEmpty
        let causeFirstTokens = hasStructuralCue
            ? tokens.subtracting(candidateCorpusProcessorSolutionTokens)
            : tokens
        let nonExactScoringTokens = causeFirstTokens.subtracting(candidateCorpusLexicalStopwords)
        guard !nonExactScoringTokens.isEmpty else { return nil }
        var scores = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, tokenScore(nonExactScoringTokens, cardTokens[$0.id] ?? [])) })
        // A package-filtered canonical-only resource has no shipped utterance
        // postings of its own.  Do not scan unrelated packages' utterance index
        // for that narrow query; unfiltered and ordinary package ranking retain
        // the established global posting behavior.
        let canonicalOnlyPackageFilter = filters.packageID.flatMap { descriptor($0) }?.runtimeCanonicalOnly == true
        if !canonicalOnlyPackageFilter {
            // Preserve established cross-package token-posting semantics before
            // applying the allowed-card filter below. A package filter narrows
            // the result, not the evidence considered while scoring ties.
            let posted = nonExactScoringTokens.reduce(into: Set<String>()) { $0.formUnion(tokenPostingIDs[$1] ?? []) }
            for utteranceID in posted {
                guard let utterance = utterancesByID[utteranceID], allowed.contains(utterance.canonicalID) else { continue }
                scores[utterance.canonicalID] = max(scores[utterance.canonicalID] ?? 0, tokenScore(nonExactScoringTokens, utteranceTokens[utterance.id] ?? []))
            }
        }
        // A query that explicitly names exactly one P4 processor is ordinarily
        // asking about that processor. Give its diagnostic family a bounded
        // preference, while leaving reverb-vs-delay comparison language (both
        // nouns) to the normal lexical/cause scoring path.
        let p4ProcessorNouns = tokens.intersection(Set(["reverb", "delay"]))
        if p4ProcessorNouns.count == 1, let namedDomain = p4ProcessorNouns.first {
            for card in filtered where card.domain == namedDomain {
                scores[card.id, default: 0] += 4
            }
        }
        // Several concrete low-end/allocation cues diagnose a frequency-space
        // question before they diagnose an effect on one of its sources. This
        // keeps a P4 source-specific card from displacing the cross-package
        // frequency family merely because both mention kick or bass.
        if nonExactScoringTokens.intersection(candidateCorpusFrequencyAllocationCueTokens).count >= 3 {
            for card in filtered where card.domain == "frequency_allocation" {
                scores[card.id, default: 0] += 6
            }
        }
        // Explicit source/performance/recording language asks for the recorded
        // cause before ambience or arrangement treatment. This is a family cue
        // only; it does not select a canonical card or infer a processor.
        if nonExactScoringTokens.contains("source"),
           !nonExactScoringTokens.intersection(candidateCorpusSourceFirstCueTokens).isEmpty {
            for card in filtered where card.domain == "vocal_production" {
                scores[card.id, default: 0] += 6
            }
        }
        // Multiple arrangement-state cues make the arrangement the cause to
        // test before treating an effect return that merely reveals it.
        if nonExactScoringTokens.intersection(candidateCorpusArrangementCauseCueTokens).count >= 3 {
            for card in filtered where card.domain == "arrangement" {
                scores[card.id, default: 0] += 6
            }
        }
        // A structurally explicit masking/role question is cause-first.  P6
        // nonlinear and transient cards remain eligible only when the user
        // affirmatively names that processing family; generic "harder" or
        // level language is not an affirmative nonlinear intent.
        if nonExactScoringTokens.intersection(candidateCorpusStructuralMaskingCueTokens).count >= 3,
           nonExactScoringTokens.intersection(candidateCorpusAffirmativeNonlinearIntentTokens).isEmpty {
            for card in filtered where card.packageID == "tracksmith-corpus-006-saturation-transient-shaping" {
                scores[card.id, default: 0] -= 12
            }
        }
        // Automation is a time-varying control decision, not the default
        // answer to masking or voicing. If the musician supplies neither an
        // automation control/mode/gesture cue nor automation language, retain
        // the prior cause-first diagnostic family for a masking/voicing query.
        if nonExactScoringTokens.intersection(candidateCorpusAutomationIntentTokens).isEmpty,
           !nonExactScoringTokens.intersection(candidateCorpusMaskingOrVoicingCueTokens).isEmpty {
            for card in filtered where card.packageID == "tracksmith-corpus-005-automation" {
                scores[card.id, default: 0] -= 8
            }
        }
        // A musician who explicitly describes a level-control attempt together
        // with a buried/foreground hierarchy problem is asking first about
        // balance.  Do not reinterpret that as bus processing unless they name
        // routing (bus, aux, group, VCA, summing, or a send/return).  This is a
        // domain-level diagnostic preference, not an ID/package special case.
        if !nonExactScoringTokens.intersection(candidateCorpusLevelControlCueTokens).isEmpty,
           nonExactScoringTokens.intersection(candidateCorpusBuriedHierarchyCueTokens).count >= 2,
           nonExactScoringTokens.intersection(candidateCorpusRoutingIntentTokens).isEmpty {
            for card in filtered where card.domain == "level_balancing" {
                scores[card.id, default: 0] += 8
            }
            for card in filtered where card.domain == "bus_processing" {
                scores[card.id, default: 0] -= 4
            }
        }
        // A tempo-map question with performance/drift/local-hit evidence is a
        // timing diagnosis before it is a tempo-synced delay effect.  Require
        // both tempo-map language and a timing cue, and leave explicit repeat
        // or echo questions to their ordinary delay scoring.
        if candidateCorpusTempoMapTokens.isSubset(of: nonExactScoringTokens),
           !nonExactScoringTokens.intersection(candidateCorpusTempoMapContextTokens).isEmpty,
           nonExactScoringTokens.intersection(candidateCorpusDelayEffectTokens).isEmpty {
            for card in filtered where card.domain == "editing" { scores[card.id, default: 0] += 4 }
            for card in filtered where card.domain == "delay" { scores[card.id, default: 0] -= 6 }
        }
        // Original-versus-derived identity must be retained whenever multiple
        // identity cues occur.  This uses a card's declared evidence-needed
        // metadata, rather than a package or record identity, so derived audio
        // is never presented as proof of an untouched source.
        if nonExactScoringTokens.intersection(candidateCorpusOriginalDerivedIdentityTokens).count >= 3 {
            var namedTechnicalDomains: Set<String> = []
            if !nonExactScoringTokens.intersection(candidateCorpusPhasePolarityIntentTokens).isEmpty { namedTechnicalDomains.insert("phase_polarity") }
            if !nonExactScoringTokens.intersection(candidateCorpusPanningIntentTokens).isEmpty { namedTechnicalDomains.insert("panning") }
            if !nonExactScoringTokens.intersection(candidateCorpusStereoImagingIntentTokens).isEmpty { namedTechnicalDomains.insert("stereo_imaging") }
            for card in filtered where (card.evidenceNeeded ?? []).contains(where: { $0.localizedCaseInsensitiveContains("original-versus-derived") }) && (namedTechnicalDomains.isEmpty || namedTechnicalDomains.contains(card.domain)) {
                scores[card.id, default: 0] += 6
            }
        }
        // Waveform appearance alone does not decide a relationship.  Pair/two-
        // source mono-thinning or cancellation evidence asks about phase before
        // edit placement, while ordinary boundary/waveform edit queries lack
        // these relationship cues and keep their existing path.
        if nonExactScoringTokens.contains("waveform"),
           !nonExactScoringTokens.intersection(candidateCorpusWaveformRelationshipSourceTokens).isEmpty,
           !nonExactScoringTokens.intersection(candidateCorpusWaveformRelationshipOutcomeTokens).isEmpty {
            for card in filtered where card.domain == "phase_polarity" { scores[card.id, default: 0] += 6 }
            for card in filtered where card.domain == "editing" { scores[card.id, default: 0] -= 2 }
        }
        // Position/movement plus width is a placement-versus-extent question,
        // not a layering role question.  Both cues are required so a general
        // request for a wide texture or a layer's role remains unaffected.
        if !nonExactScoringTokens.intersection(candidateCorpusPositionCueTokens).isEmpty,
           !nonExactScoringTokens.intersection(candidateCorpusWidthCueTokens).isEmpty {
            for card in filtered where card.domain == "panning" || card.domain == "stereo_imaging" { scores[card.id, default: 0] += 5 }
            for card in filtered where card.domain == "layering" { scores[card.id, default: 0] -= 2 }
        }
        // An explicit vocal-performance alignment action is an editing decision
        // before it is a layering-role decision.  Require both an edit action
        // and a vocal/double/phrase/consonant context so phase/sample alignment,
        // drum-layer questions, and width/role questions without an edit action
        // continue through ordinary scoring.
        if !nonExactScoringTokens.intersection(candidateCorpusPerformanceAlignmentActionTokens).isEmpty,
           !nonExactScoringTokens.intersection(candidateCorpusPerformanceAlignmentContextTokens).isEmpty {
            for card in filtered where card.domain == "editing" {
                scores[card.id, default: 0] += 4
            }
            for card in filtered where card.domain == "layering" {
                scores[card.id, default: 0] -= 2
            }
        }
        // A combined recorded-audio/Flex and MIDI-note/piano-roll timing
        // comparison is a cross-domain timing/quantization distinction, not a
        // transient-source-editing request.  Keep this post-exact, domain-only,
        // and unfiltered so an explicit package/domain filter retains its
        // established behavior and ordinary audio-only transient questions are
        // untouched.
        let hasRecordedAudioFlexContext = !nonExactScoringTokens.intersection(candidateCorpusRecordedAudioTokens).isEmpty &&
            !nonExactScoringTokens.intersection(candidateCorpusFlexTimeTokens).isEmpty
        let hasMIDINoteContext = !nonExactScoringTokens.intersection(candidateCorpusMIDINoteTokens).isEmpty ||
            candidateCorpusPianoRollTokens.isSubset(of: nonExactScoringTokens)
        let hasTimingCorrectionIntent = !nonExactScoringTokens.intersection(candidateCorpusTimingCorrectionTokens).isEmpty
        if filters.packageID == nil && filters.domain == nil &&
            hasRecordedAudioFlexContext && hasMIDINoteContext && hasTimingCorrectionIntent {
            for card in filtered where card.domain == "flex_time_manual_timing" || card.domain == "quantization_and_timing" {
                scores[card.id, default: 0] += 12
            }
            for card in filtered where card.domain == "transient_shaping" && card.category == "source_editing" {
                scores[card.id, default: 0] -= 12
            }
        }
        // A named Q-Strength/Q-Range/Q-Swing comparison is a MIDI
        // quantization-control question. Require all three control cues plus
        // quantization language so ordinary arrangement "strength" wording
        // and velocity editing retain their established lexical paths.
        let hasQuantizationControlComparison = ["strength", "range", "swing"].allSatisfy(nonExactScoringTokens.contains) &&
            !nonExactScoringTokens.intersection(["quantize", "quantization", "midi", "piano", "roll"]).isEmpty
        if filters.packageID == nil && filters.domain == nil && hasQuantizationControlComparison {
            for card in filtered where card.domain == "midi_quantization_groove" { scores[card.id, default: 0] += 12 }
            for card in filtered where card.domain == "midi_velocity_musical_dynamics" || card.domain == "arrangement" { scores[card.id, default: 0] -= 8 }
        }
        // Transform selection scope is distinct from velocity editing when a
        // user explicitly contrasts note events with multiple controller-event
        // types. This is a post-exact semantic family cue, never a record ID.
        let controllerKinds = nonExactScoringTokens.intersection(candidateCorpusControllerEventTokens)
        if filters.packageID == nil && filters.domain == nil &&
            nonExactScoringTokens.contains("transform") &&
            !nonExactScoringTokens.intersection(["select", "selection", "selected", "scope"]).isEmpty &&
            controllerKinds.count >= 2 {
            for card in filtered where card.domain == "midi_transform_humanize_batch_editing" { scores[card.id, default: 0] += 12 }
            for card in filtered where card.domain == "midi_velocity_musical_dynamics" { scores[card.id, default: 0] -= 8 }
        }
        let candidates = filtered.filter { (scores[$0.id] ?? 0) > 0 }
        let sequenceByPackage = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.packageID, $0.packageSequence) })
        let meaningfulQueryTokens = nonExactScoringTokens.subtracting(candidateCorpusLexicalStopwords)
        let primaryTieScores = Dictionary(uniqueKeysWithValues: candidates.map { card in
            let primary = [card.id, card.title, card.question].joined(separator: " ")
                .normalizedCandidateCorpusText.candidateCorpusTokens
                .subtracting(candidateCorpusLexicalStopwords)
            return (card.id, meaningfulQueryTokens.intersection(primary).count)
        })
        let groups = Dictionary(grouping: candidates, by: { $0.question.nearEquivalentCandidateCorpusKey })
        let representatives = groups.values.compactMap { group in group.sorted { a,b in
            let left=scores[a.id] ?? 0, right=scores[b.id] ?? 0
            if left != right { return left > right }; let aPrimary=primaryTieScores[a.id] ?? 0, bPrimary=primaryTieScores[b.id] ?? 0; if aPrimary != bPrimary { return aPrimary > bPrimary }; let aSequence=sequenceByPackage[a.packageID] ?? Int.max, bSequence=sequenceByPackage[b.packageID] ?? Int.max; if aSequence != bSequence { return aSequence < bSequence }; if a.packageID != b.packageID { return a.packageID < b.packageID }; return a.id < b.id
        }.first }
        guard let selected = representatives.sorted(by: { a,b in let left=scores[a.id] ?? 0, right=scores[b.id] ?? 0; if left != right { return left > right }; let aPrimary=primaryTieScores[a.id] ?? 0, bPrimary=primaryTieScores[b.id] ?? 0; if aPrimary != bPrimary { return aPrimary > bPrimary }; let aSequence=sequenceByPackage[a.packageID] ?? Int.max, bSequence=sequenceByPackage[b.packageID] ?? Int.max; return aSequence == bSequence ? a.id < b.id : aSequence < bSequence }).first else { return nil }
        return .init(card: selected, score: scores[selected.id] ?? 0, deduplicatedCandidates: candidates.count - representatives.count)
    }

    /// P16's aggregate candidate selection.  This deliberately has no exact
    /// identity path: it starts with the established contextual ranker, then
    /// admits only lexically relevant, non-duplicate alternatives under fixed
    /// package/domain diversity limits.
    public func ranked(
        query: String,
        filters: CommunityCandidateCorpusFilters = .init(),
        limit: Int = 4
    ) -> [CommunityCandidateCorpusRankedCard] {
        let maximum = min(max(limit, 0), 4)
        guard maximum > 0, let primary = rank(query: query, filters: filters) else { return [] }
        let tokens = query.normalizedCandidateCorpusText.candidateCorpusTokens.subtracting(candidateCorpusLexicalStopwords)
        guard !tokens.isEmpty else { return [primary] }
        let eligible = canonicalCards.filter { card in
            (filters.domain == nil || card.domain == filters.domain) &&
            (filters.category == nil || card.category == filters.category) &&
            (filters.sourceType == nil || card.sourceTypes.contains(filters.sourceType!)) &&
            (filters.evidenceClass == nil || card.evidenceClass == filters.evidenceClass) &&
            (filters.logicVersion == nil || card.logicVersion?.localizedCaseInsensitiveContains(filters.logicVersion!) == true) &&
            (filters.currentContext == nil || card.currentContext == filters.currentContext) &&
            (filters.packageID == nil || card.packageID == filters.packageID) &&
            (filters.packageVersion == nil || card.version == filters.packageVersion) &&
            (filters.role == nil || card.roleFacets?.contains(filters.role!) == true) &&
            (filters.section == nil || card.sectionFacets?.contains(filters.section!) == true)
        }.compactMap { card -> CommunityCandidateCorpusRankedCard? in
            let score = tokenScore(tokens, cardTokens[card.id] ?? [])
            return score > 0 ? .init(card: card, score: score, deduplicatedCandidates: 0) : nil
        }.sorted { left, right in
            left.score == right.score ? left.card.id < right.card.id : left.score > right.score
        }
        var output = [primary]
        var packages = [primary.card.packageID: 1]
        var domains = [primary.card.domain: 1]
        var equivalent = Set([primary.card.question.nearEquivalentCandidateCorpusKey])
        for candidate in eligible where output.count < maximum {
            let card = candidate.card
            guard card.id != primary.card.id,
                  packages[card.packageID, default: 0] < 2,
                  domains[card.domain, default: 0] < 2,
                  equivalent.insert(card.question.nearEquivalentCandidateCorpusKey).inserted else { continue }
            output.append(candidate)
            packages[card.packageID, default: 0] += 1
            domains[card.domain, default: 0] += 1
        }
        return output
    }

    private func indexed() -> CommunityCandidateCorpus {
        var copy=self, cards:[String:Set<String>] = [:], utterancesIndex:[String:Set<String>] = [:], postings:[String:Set<String>] = [:], packagePostings:[String:[String:Set<String>]] = [:], utteranceMap:[String:CommunityCandidateUtterance] = [:]
        for card in canonicalCards {
            let supportsRichCandidateIndex = card.packageSequence == 3 || card.packageID == "community-reverb-delay-v1" || (card.packageSequence ?? 0) >= 5
            if !supportsRichCandidateIndex {
                cards[card.id] = ([card.id,card.title,card.question,card.category,card.domain] + card.clarificationQuestions + card.competingHypotheses).joined(separator:" ").normalizedCandidateCorpusText.candidateCorpusTokens
                continue
            }
            var structuredFields: [String] = []
            structuredFields.reserveCapacity(
                3 + (card.tracksmithDomains?.count ?? 0) + (card.preservationGoals?.count ?? 0)
                    + (card.nonDSPPossibilities?.count ?? 0) + (card.startingPoints?.count ?? 0)
                    + (card.commonMistakes?.count ?? 0) + (card.roleFacets?.count ?? 0)
                    + (card.sectionFacets?.count ?? 0)
            )
            structuredFields.append(card.subcategory ?? "")
            structuredFields.append(card.rationale)
            structuredFields.append(card.recommendedFirstExperiment)
            structuredFields.append(contentsOf: card.tracksmithDomains ?? [])
            structuredFields.append(contentsOf: card.preservationGoals ?? [])
            structuredFields.append(contentsOf: card.nonDSPPossibilities ?? [])
            structuredFields.append(contentsOf: card.startingPoints ?? [])
            structuredFields.append(contentsOf: card.commonMistakes ?? [])
            structuredFields.append(contentsOf: card.roleFacets ?? [])
            structuredFields.append(contentsOf: card.sectionFacets ?? [])
            cards[card.id] = ([card.id,card.title,card.question,card.category,card.domain] + card.tags + card.clarificationQuestions + card.competingHypotheses + card.listeningCues + structuredFields).joined(separator:" ").normalizedCandidateCorpusText.candidateCorpusTokens
        }
        let packageByCard=Dictionary(uniqueKeysWithValues: canonicalCards.map { ($0.id,$0.packageID) })
        for utterance in utterances { let normalized=utterance.text.normalizedCandidateCorpusText; let tokens=normalized.candidateCorpusTokens; utterancesIndex[utterance.id]=tokens; utteranceMap[utterance.id]=utterance; for value in tokens { postings[value,default:[]].insert(utterance.id); if let package=packageByCard[utterance.canonicalID] { packagePostings[package,default:[:]][value,default:[]].insert(utterance.id) } } }
        copy.exactUtteranceIDs=[:]; copy.cardTokens=cards; copy.utteranceTokens=utterancesIndex; copy.tokenPostingIDs=postings; copy.tokenPostingIDsByPackage=packagePostings; copy.utterancesByID=utteranceMap; return copy
    }
}

private func tokenScore(_ query: Set<String>, _ document: Set<String>) -> Int { query.reduce(0) { $0 + (document.contains($1) ? 2 : 0) } }
/// Only breaks equal base lexical scores, never normalization, exact-utterance
/// identity, or base scoring. This prevents generic question grammar from
/// choosing an alphabetical winner over canonical diagnostic wording.
private let candidateCorpusLexicalStopwords: Set<String> = [
    "a", "after", "an", "and", "are", "at", "be", "before", "but", "can", "could", "do", "does", "even", "for", "from", "had", "has", "have", "how", "i", "in", "is", "it", "just", "keep", "me", "my", "of", "on", "only", "or", "our", "out", "really", "should", "still", "that", "than", "the", "their", "then", "these", "this", "those", "to", "too", "under", "very", "was", "we", "were", "what", "when", "which", "why", "will", "with", "would", "you", "your"
]
private let candidateCorpusStructuralCueTokens: Set<String> = [
    "arrangement", "density", "register", "voicing", "timing", "articulation", "hierarchy", "role", "roles", "source", "selection", "layers", "layering", "mask", "masking"
]
private let candidateCorpusProcessorSolutionTokens: Set<String> = [
    "compress", "compression", "compressor", "compressed", "eq", "equalization"
]
private let candidateCorpusFrequencyAllocationCueTokens: Set<String> = [
    "bass", "filter", "frequency", "high", "kick", "low", "pass", "sub"
]
private let candidateCorpusSourceFirstCueTokens: Set<String> = [
    "performance", "recording", "take"
]
private let candidateCorpusArrangementCauseCueTokens: Set<String> = [
    "arrangement", "chorus", "density", "fills", "layer", "layers", "remove", "section"
]
private let candidateCorpusAutomationIntentTokens: Set<String> = [
    "automation", "automate", "automating", "curve", "fader", "latch",
    "point", "points", "read", "ride", "touch", "write"
]
private let candidateCorpusLevelControlCueTokens: Set<String> = [
    "balance", "balancing", "fader", "gain", "level", "lower", "lowering", "raise", "raising", "trim", "volume"
]
private let candidateCorpusBuriedHierarchyCueTokens: Set<String> = [
    "background", "backing", "buried", "bury", "foreground", "hierarchy", "lead", "focal"
]
private let candidateCorpusRoutingIntentTokens: Set<String> = [
    "aux", "bus", "buses", "group", "groups", "return", "returns", "route", "routing", "send", "sends", "stack", "subgroup", "sum", "summing", "vca"
]
private let candidateCorpusMaskingOrVoicingCueTokens: Set<String> = [
    "mask", "masking", "voicing"
]
private let candidateCorpusStructuralMaskingCueTokens: Set<String> = [
    "arrangement", "dense", "density", "guitar", "guitars", "mask", "masking", "remove", "role", "roles", "vocal", "vocals", "vanishes", "voicing"
]
private let candidateCorpusTempoMapTokens: Set<String> = ["tempo", "map"]
private let candidateCorpusTempoMapContextTokens: Set<String> = ["drift", "drummer", "hit", "local", "performance", "timing"]
private let candidateCorpusDelayEffectTokens: Set<String> = ["delay", "echo", "repeat", "repeats"]
private let candidateCorpusOriginalDerivedIdentityTokens: Set<String> = [
    "original", "derived", "separated", "estimate", "repaired", "consolidated", "resampled", "resampling"
]
private let candidateCorpusPhasePolarityIntentTokens: Set<String> = ["phase", "polarity"]
private let candidateCorpusPanningIntentTokens: Set<String> = ["pan", "panning"]
private let candidateCorpusStereoImagingIntentTokens: Set<String> = ["stereo", "imaging"]
private let candidateCorpusWaveformRelationshipSourceTokens: Set<String> = ["pair", "two"]
private let candidateCorpusWaveformRelationshipOutcomeTokens: Set<String> = ["mono", "thins", "cancellation", "cancel"]
private let candidateCorpusPositionCueTokens: Set<String> = ["move", "moved", "moving", "movement", "position", "reposition", "repositioned", "repositioning"]
private let candidateCorpusWidthCueTokens: Set<String> = ["width", "wide", "wider"]
private let candidateCorpusPerformanceAlignmentActionTokens: Set<String> = [
    "align", "aligned", "alignment", "tighten", "tightened", "tightening"
]
private let candidateCorpusPerformanceAlignmentContextTokens: Set<String> = [
    "vocal", "vocals", "double", "doubles", "harmony", "harmonies", "phrase", "phrases", "consonant", "consonants"
]
private let candidateCorpusRecordedAudioTokens: Set<String> = ["audio", "recorded", "waveform"]
private let candidateCorpusFlexTimeTokens: Set<String> = ["flex"]
private let candidateCorpusMIDINoteTokens: Set<String> = ["midi", "note", "notes", "event", "events"]
private let candidateCorpusPianoRollTokens: Set<String> = ["piano", "roll"]
private let candidateCorpusTimingCorrectionTokens: Set<String> = ["correct", "correction", "quantize", "quantization", "timing"]
private let candidateCorpusControllerEventTokens: Set<String> = ["controller", "controllers", "pitch", "bend", "aftertouch", "keyswitch", "keyswitches"]
private let candidateCorpusAffirmativeNonlinearIntentTokens: Set<String> = [
    "aliasing", "clip", "clipping", "distortion", "envelope", "harmonic", "harmonics", "intermodulation", "nonlinear", "saturation", "transient", "transients", "waveshaping"
]
private extension String {
    var normalizedCandidateCorpusText: String { lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator:" ") }
    var candidateCorpusTokens: Set<String> {
        // Token-only correction: exact normalized lookup remains an untouched
        // identity index, while scored retrieval recognizes a common spelling
        // error without changing fixture/accounting equivalence.
        Set(normalizedCandidateCorpusText.split(separator:" ").map { token in
            token == "revrb" ? "reverb" : String(token)
        }.filter { $0.count > 1 })
    }
    var nearEquivalentCandidateCorpusKey: String { candidateCorpusTokens.filter { $0.count > 2 }.sorted().joined(separator:" ") }
}

private final class CommunityCandidateBundleLocator {}

public enum CommunityCandidateCorpusError: Error, Equatable, Sendable {
    case missingResource(String)
    case checksumMismatch(expected: String, actual: String)
    case manifestMismatch(String)
    case duplicateID(String)
    case invalidCount(String, expected: Int, actual: Int)
    case missingCanonicalLink(String)
    case unreviewedStatusChanged(String)
    case unreachable(String)
    case forbiddenProcedureField
}

public struct CommunityCandidateCorpusValidator: Sendable {
    public init() {}
    public func validate(_ corpus: CommunityCandidateCorpus) throws {
        var ids = Set<String>(), cardIDs = Set<String>()
        guard Set(corpus.descriptors.map(\.packageSequence)) == Set(1...corpus.descriptors.count) else { throw CommunityCandidateCorpusError.manifestMismatch("package sequences") }
        let canonicalOnlyPackageIDs = Set(corpus.descriptors.filter(\.runtimeCanonicalOnly).map(\.packageID))
        // A descriptor may declare a status-free runtime projection.  For
        // older resources that predate the descriptor capability, the decoded
        // status-free card shape is the compatibility signal.  This remains
        // package-capability/data driven and never depends on a package ID.
        let statusFreePackageIDs = Set(corpus.descriptors.compactMap { descriptor in
            let cards = corpus.canonicalCards.filter { $0.packageID == descriptor.packageID }
            return descriptor.runtimeStatusFree || (!cards.isEmpty && cards.allSatisfy { $0.originalReviewStatus == nil })
                ? descriptor.packageID
                : nil
        })
        for descriptor in corpus.descriptors {
            let cards = corpus.canonicalCards.filter { $0.packageID == descriptor.packageID }
            let runtimeStatusFree = statusFreePackageIDs.contains(descriptor.packageID)
            let ownCardIDs = Set(cards.map(\.id))
            let utterances = corpus.utterances.filter { ownCardIDs.contains($0.canonicalID) }
            let attachedContradictionIDs = Set(cards.flatMap(\.contradictions).map(\.id))
            let attachedMythIDs = Set(cards.flatMap(\.myths).map(\.id))
            guard cards.count == descriptor.canonicalCount else { throw CommunityCandidateCorpusError.invalidCount(descriptor.packageID + ":canonical", expected: descriptor.canonicalCount, actual: cards.count) }
            guard descriptor.packageSequence > 0 else { throw CommunityCandidateCorpusError.manifestMismatch(descriptor.packageID) }
            if runtimeStatusFree {
                guard cards.allSatisfy({ $0.originalReviewStatus == nil }) else { throw CommunityCandidateCorpusError.unreviewedStatusChanged(descriptor.packageID + ":canonical-status-leak") }
            } else {
                guard cards.allSatisfy({ $0.originalReviewStatus == descriptor.canonicalOriginalStatus }) else { throw CommunityCandidateCorpusError.unreviewedStatusChanged(descriptor.packageID + ":canonical") }
            }
            let expectedRuntimeUtterances = descriptor.runtimeCanonicalOnly ? 0 : descriptor.utteranceCount
            let expectedRuntimeContradictions = descriptor.runtimeCanonicalOnly ? 0 : descriptor.contradictionCount
            let expectedRuntimeMyths = descriptor.runtimeCanonicalOnly ? 0 : descriptor.mythCount
            guard utterances.count == expectedRuntimeUtterances else { throw CommunityCandidateCorpusError.invalidCount(descriptor.packageID + ":utterances", expected: expectedRuntimeUtterances, actual: utterances.count) }
            guard attachedContradictionIDs.count == expectedRuntimeContradictions else { throw CommunityCandidateCorpusError.invalidCount(descriptor.packageID + ":contradictions", expected: expectedRuntimeContradictions, actual: attachedContradictionIDs.count) }
            guard attachedMythIDs.count == expectedRuntimeMyths else { throw CommunityCandidateCorpusError.invalidCount(descriptor.packageID + ":myths", expected: expectedRuntimeMyths, actual: attachedMythIDs.count) }
            if descriptor.utteranceOriginalStatus != nil {
                guard utterances.allSatisfy({ $0.originalReviewStatus == descriptor.utteranceOriginalStatus }),
                      corpus.contradictions.filter({ attachedContradictionIDs.contains($0.id) }).allSatisfy({ $0.originalReviewStatus == descriptor.contradictionOriginalStatus }),
                      corpus.myths.filter({ attachedMythIDs.contains($0.id) }).allSatisfy({ $0.originalReviewStatus == descriptor.mythOriginalStatus }) else {
                    throw CommunityCandidateCorpusError.unreviewedStatusChanged(descriptor.packageID)
                }
            }
        }
        for card in corpus.canonicalCards {
            guard ids.insert(card.id).inserted, cardIDs.insert(card.id).inserted else { throw CommunityCandidateCorpusError.duplicateID(card.id) }
            if statusFreePackageIDs.contains(card.packageID) {
                guard card.originalReviewStatus == nil else { throw CommunityCandidateCorpusError.unreviewedStatusChanged(card.id) }
            } else {
                guard card.originalReviewStatus == "candidate_not_yet_human_reviewed" else { throw CommunityCandidateCorpusError.unreviewedStatusChanged(card.id) }
            }
            guard card.contradictions.count <= 3, card.myths.count <= 2,
                  card.contradictions.count + card.myths.count <= 4 else {
                throw CommunityCandidateCorpusError.invalidCount(card.id + ":attachments", expected: 4, actual: card.contradictions.count + card.myths.count)
            }
            if card.packageID == "community-compression-arrangement-frequency-allocation-v1" {
                guard card.packageSequence == 3,
                      card.rawCommunityDisagreementIDs.map({ Set($0).isSubset(of: Set(corpus.contradictions.map(\.id)) ) }) == true else {
                    throw CommunityCandidateCorpusError.manifestMismatch(card.id)
                }
            }
            if card.packageID == "tracksmith-corpus-005-automation" {
                guard card.packageSequence == 5, card.directCandidateAnswer != nil,
                      card.keyDistinction != nil, card.firstExperiment != nil,
                      card.listenFor != nil, card.nonAutomationPossibilities?.isEmpty == false,
                      card.evidenceNeeded?.isEmpty == false, card.userIntent != nil,
                      card.procedureCandidateID?.hasPrefix("pkg005.procedure.") == true,
                      card.procedureVerificationStatus == "candidate_unverified_on_installed_logic" else {
                    throw CommunityCandidateCorpusError.manifestMismatch(card.id)
                }
            }
            if (card.packageSequence ?? 0) >= 6 && !canonicalOnlyPackageIDs.contains(card.packageID) {
                guard card.directCandidateAnswer != nil,
                      card.keyDistinction != nil, card.firstExperiment != nil,
                      card.listenFor != nil, card.nonProcessingPossibilities?.isEmpty == false,
                      card.procedureVerificationStatus == "candidate_unverified_on_installed_logic",
                      card.primaryResearchSourceIDs != nil else {
                    throw CommunityCandidateCorpusError.manifestMismatch(card.id)
                }
            }
        }
        for utterance in corpus.utterances {
            guard ids.insert("utterance:" + utterance.id).inserted, cardIDs.contains(utterance.canonicalID) else { throw CommunityCandidateCorpusError.missingCanonicalLink(utterance.id) }
        }
        let attachedContradictions = Set(corpus.canonicalCards.flatMap(\.contradictions).map(\.id))
        let attachedMyths = Set(corpus.canonicalCards.flatMap(\.myths).map(\.id))
        guard attachedContradictions == Set(corpus.contradictions.map(\.id)) else { throw CommunityCandidateCorpusError.unreachable("contradiction") }
        guard attachedMyths == Set(corpus.myths.map(\.id)) else { throw CommunityCandidateCorpusError.unreachable("myth") }
        let protectedPackageIDs = Set(corpus.descriptors.filter { $0.packageSequence >= 3 }.map(\.packageID))
        let protectedCards = corpus.canonicalCards.filter { protectedPackageIDs.contains($0.packageID) }
        let protectedIDs = Set(protectedCards.map(\.id))
        let encoded = try JSONEncoder().encode(CommunityCandidateRuntimeLeakProbe(cards: protectedCards, utterances: corpus.utterances.filter { protectedIDs.contains($0.canonicalID) }, contradictions: corpus.contradictions.filter { contradiction in protectedCards.contains { $0.contradictions.contains { $0.id == contradiction.id } } }, myths: corpus.myths.filter { myth in protectedCards.contains { $0.myths.contains { $0.id == myth.id } } }))
        let text = String(decoding: encoded, as: UTF8.self)
        let lower = text.lowercased()
        let forbidden = ["logic_pro_steps", "logicsteps", "procedure_candidates", "procedurecandidates", "procedure_steps", "proceduresteps", "procedure_body", "procedurebody", "audio track editor", "piano roll", "audio fx", "channel strip", "region inspector", "menu path", "quantize menu", "flex mode menu"]
        if forbidden.contains(where: lower.contains) { throw CommunityCandidateCorpusError.forbiddenProcedureField }
    }
}
