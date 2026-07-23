import AgentCore
import Foundation
import PlanSchema

public enum LogicKnowledgeReviewStatus: String, Codable, Sendable {
    case indexedOnlyNotReviewEvidence
    case deepFullRelevantSectionRead
}

public enum LogicNativeExecutionBoundary: String, Codable, Sendable {
    case advisoryOnlyNoTrackSmithExecutionAuthority
}

public enum LogicNativeEmpiricalStatus: String, Codable, Sendable {
    case notRun
    case partial
    case complete
}

/// A reviewed description of a Logic-native tool. Deliberately contains no
/// `NodeType`, parameter map, automation command, host action, or executable
/// payload. It can inform a hypothesis or manual recipe but cannot become DSP.
public struct LogicNativeToolKnowledge: Codable, Equatable, Sendable {
    public var identifier: String
    public var name: String
    public var family: String
    public var manualPages: String
    public var aliases: [String]
    public var applicableSourceTypes: Set<SourceType>
    public var semanticTags: Set<ProductionTerm>
    public var documentedMechanism: String
    public var productionConsequence: String
    public var empiricalStatus: LogicNativeEmpiricalStatus
    public var measuredRunIDs: [String]
    public var empiricalEvidenceSummary: String?
    public let executionBoundary: LogicNativeExecutionBoundary
    public let subjectiveListeningDecisive: Bool

    public init(
        identifier: String,
        name: String,
        family: String,
        manualPages: String,
        aliases: [String],
        applicableSourceTypes: Set<SourceType>,
        semanticTags: Set<ProductionTerm>,
        documentedMechanism: String,
        productionConsequence: String,
        empiricalStatus: LogicNativeEmpiricalStatus = .notRun,
        measuredRunIDs: [String] = [],
        empiricalEvidenceSummary: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.family = family
        self.manualPages = manualPages
        self.aliases = aliases
        self.applicableSourceTypes = applicableSourceTypes
        self.semanticTags = semanticTags
        self.documentedMechanism = documentedMechanism
        self.productionConsequence = productionConsequence
        self.empiricalStatus = empiricalStatus
        self.measuredRunIDs = measuredRunIDs
        self.empiricalEvidenceSummary = empiricalEvidenceSummary
        executionBoundary = .advisoryOnlyNoTrackSmithExecutionAuthority
        subjectiveListeningDecisive = true
    }
}

public enum LogicNativeToolKnowledgeError: Error, Equatable, Sendable {
    case wrongEntryCount(expected: Int, actual: Int)
    case duplicateIdentifier(String)
    case malformedEntry(String)
    case unsupportedSourceType(String)
    case unsafeScripterAuthority
}

public enum LogicNativeInstrumentKnowledgeError: Error, Equatable, Sendable {
    case wrongEntryCount(expected: Int, actual: Int)
    case invalidCatalog(LogicNativeToolKnowledgeError)
}

public struct LogicNativeToolContext: Codable, Equatable, Sendable {
    public var identifier: String
    public var name: String
    public var family: String
    public var manualPages: String
    public var documentedMechanism: String
    public var productionConsequence: String
    public var mechanismEvidenceClass: String
    public var consequenceEvidenceClass: String
    public var executionBoundary: LogicNativeExecutionBoundary
    public var mayBecomeProcessingNode: Bool
    public var mayControlLogicOrAutomation: Bool
    public var exactImplementationInternalsKnown: Bool
    public var empiricalTransferCharacterizationStatus: String
    public var measuredRunIDs: [String]
    public var empiricalEvidenceSummary: String?
    public var coreProductionPriorityRank: Int?
    public var productionPriorityEvidenceBoundary: String?
    public var subjectiveListeningDecisive: Bool

    public init(_ knowledge: LogicNativeToolKnowledge) {
        identifier = knowledge.identifier
        name = knowledge.name
        family = knowledge.family
        manualPages = knowledge.manualPages
        documentedMechanism = knowledge.documentedMechanism
        productionConsequence = knowledge.productionConsequence
        mechanismEvidenceClass = "APPLE_DOCUMENTED_BEHAVIOR"
        consequenceEvidenceClass = "DERIVED_TECHNICAL_INTERPRETATION_AND_PROFESSIONAL_PRACTICE_HEURISTIC"
        executionBoundary = knowledge.executionBoundary
        mayBecomeProcessingNode = false
        mayControlLogicOrAutomation = false
        exactImplementationInternalsKnown = false
        switch knowledge.empiricalStatus {
        case .notRun:
            empiricalTransferCharacterizationStatus =
                "DOCUMENTED_BEHAVIOR_REVIEWED_EXACT_TRANSFER_NOT_YET_MEASURED"
        case .partial:
            empiricalTransferCharacterizationStatus =
                "PARTIAL_DIRECT_HOST_EVIDENCE_EXACT_TRANSFER_NOT_CHARACTERIZED"
        case .complete:
            empiricalTransferCharacterizationStatus =
                "DECLARED_CAMPAIGN_DIMENSIONS_COMPLETE_PRIVATE_IMPLEMENTATION_NOT_CLAIMED"
        }
        measuredRunIDs = knowledge.measuredRunIDs
        empiricalEvidenceSummary = knowledge.empiricalEvidenceSummary
        coreProductionPriorityRank = LogicCoreEffectPriority.rankByName[knowledge.name]
        productionPriorityEvidenceBoundary = coreProductionPriorityRank == nil
            ? nil : LogicCoreEffectPriority.evidenceBoundary
        subjectiveListeningDecisive = knowledge.subjectiveListeningDecisive
    }
}

public struct LogicNativeToolKnowledgeCatalog: Sendable {
    public static let expectedLogicPro12_3EffectsEntryCount = 142
    /// Retained for source compatibility with the original effects-only catalog.
    public static let expectedLogicPro12_3EntryCount = expectedLogicPro12_3EffectsEntryCount

    public var sourceSHA256: String
    public var reviewStatus: LogicKnowledgeReviewStatus
    public var entries: [LogicNativeToolKnowledge]

    public init(
        sourceSHA256: String,
        reviewStatus: LogicKnowledgeReviewStatus,
        entries: [LogicNativeToolKnowledge]
    ) {
        self.sourceSHA256 = sourceSHA256
        self.reviewStatus = reviewStatus
        self.entries = entries
    }

    public func validate(expectedEntryCount: Int? = nil) throws {
        if let expectedEntryCount, entries.count != expectedEntryCount {
            throw LogicNativeToolKnowledgeError.wrongEntryCount(
                expected: expectedEntryCount,
                actual: entries.count
            )
        }
        var identifiers = Set<String>()
        for entry in entries {
            guard !entry.identifier.isEmpty,
                  !entry.name.isEmpty,
                  !entry.family.isEmpty,
                  !entry.manualPages.isEmpty,
                  !entry.documentedMechanism.isEmpty,
                  !entry.productionConsequence.isEmpty,
                  entry.identifier.utf8.count <= 128,
                  entry.name.utf8.count <= 128,
                  entry.documentedMechanism.utf8.count <= 2_048,
                  entry.productionConsequence.utf8.count <= 2_048 else {
                throw LogicNativeToolKnowledgeError.malformedEntry(entry.identifier)
            }
            guard identifiers.insert(entry.identifier).inserted else {
                throw LogicNativeToolKnowledgeError.duplicateIdentifier(entry.identifier)
            }
            guard !entry.applicableSourceTypes.contains(.reference),
                  !entry.applicableSourceTypes.contains(.unknown) else {
                throw LogicNativeToolKnowledgeError.unsupportedSourceType(entry.identifier)
            }
            guard entry.executionBoundary == .advisoryOnlyNoTrackSmithExecutionAuthority,
                  entry.subjectiveListeningDecisive else {
                throw LogicNativeToolKnowledgeError.malformedEntry(entry.identifier)
            }
            guard entry.measuredRunIDs.count == Set(entry.measuredRunIDs).count,
                  entry.measuredRunIDs.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 160 }) else {
                throw LogicNativeToolKnowledgeError.malformedEntry(entry.identifier)
            }
            switch entry.empiricalStatus {
            case .notRun:
                guard entry.measuredRunIDs.isEmpty,
                      entry.empiricalEvidenceSummary == nil else {
                    throw LogicNativeToolKnowledgeError.malformedEntry(entry.identifier)
                }
            case .partial, .complete:
                guard !entry.measuredRunIDs.isEmpty,
                      let summary = entry.empiricalEvidenceSummary,
                      !summary.isEmpty,
                      summary.utf8.count <= 2_048 else {
                    throw LogicNativeToolKnowledgeError.malformedEntry(entry.identifier)
                }
            }
            if entry.name == "Scripter" {
                let normalized = (entry.documentedMechanism + " " + entry.productionConsequence)
                    .lowercased()
                guard normalized.contains("javascript"),
                      normalized.contains("never"),
                      normalized.contains("authority") else {
                    throw LogicNativeToolKnowledgeError.unsafeScripterAuthority
                }
            }
        }
    }

    /// Deterministic bounded retrieval. Explicit tool names/aliases dominate;
    /// source/family and semantic terms only rank reviewed candidates. The
    /// returned values remain advisory-only typed knowledge.
    public func select(
        request: String,
        sourceType: SourceType,
        semanticTerms: [ProductionTerm],
        maximumCount: Int
    ) -> [LogicNativeToolKnowledge] {
        guard maximumCount > 0 else { return [] }
        let normalizedRequest = Self.normalizedPhrase(request)
        let requestTokens = Set(Self.tokens(request))
        let requestedTerms = Set(semanticTerms)

        return entries.compactMap { entry -> (LogicNativeToolKnowledge, Int)? in
            guard entry.applicableSourceTypes.contains(sourceType) else { return nil }
            var score = Self.sourceFamilyScore(entry.family, sourceType: sourceType)
            let semanticMatchCount = entry.semanticTags.intersection(requestedTerms).count
            let normalizedName = Self.normalizedPhrase(entry.name)
            var explicitIdentityMatch = false
            if !normalizedName.isEmpty, normalizedRequest.contains(normalizedName) {
                score += 1_000
                explicitIdentityMatch = true
            }
            for alias in entry.aliases {
                let normalizedAlias = Self.normalizedPhrase(alias)
                if !normalizedAlias.isEmpty, normalizedRequest.contains(normalizedAlias) {
                    score += 900
                    explicitIdentityMatch = true
                }
            }
            guard explicitIdentityMatch || Self.allowsImplicitSelection(
                entryName: entry.name,
                normalizedRequest: normalizedRequest,
                requestTokens: requestTokens,
                requestedTerms: requestedTerms
            ) else {
                return nil
            }
            let identityTokens = Set(Self.tokens(entry.name + " " + entry.aliases.joined(separator: " ")))
            let discriminatingIdentityTokens = identityTokens.subtracting(Self.genericIdentityTokens)
            score += discriminatingIdentityTokens.intersection(requestTokens).count * 140
            score += semanticMatchCount * 24
            if semanticMatchCount > 0 {
                score += Self.coreProductionPriorityBonus(entry.name)
            }
            return score > 0 ? (entry, score) : nil
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.identifier < rhs.0.identifier
        }.prefix(min(maximumCount, 8)).map(\.0)
    }

    private static func normalizedPhrase(_ value: String) -> String {
        tokens(value).joined(separator: " ")
    }

    private static func tokens(_ value: String) -> [String] {
        value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Source identity is already supplied as a typed field. These broad words
    /// cannot be allowed to masquerade as an explicit plug-in reference merely
    /// because a tool name or alias repeats the source name (for example,
    /// "guitar" in "Guitar Amp Pro"). Multiword exact name/alias matching above
    /// still resolves an actual request for "guitar amp" or another named tool.
    private static let genericIdentityTokens: Set<String> = [
        "a", "add", "an", "and", "audio", "bass", "but", "bus", "drum",
        "drums", "effect", "effects", "for", "give", "guitar", "guitars",
        "instrument", "it", "its", "keep", "keyboard", "keys", "less",
        "little", "logic", "make", "master", "mix", "more", "my", "not",
        "of", "or", "our", "plugin", "preserve", "slightly", "sound", "synth",
        "synthesizer", "that", "the", "this", "to", "track", "try", "use",
        "vocal", "vocals", "voice", "while", "with", "without", "your",
    ]

    /// Some processors solve narrow evidence-dependent problems. A broad
    /// descriptor such as `airy`, `controlled`, or `polished` must not retrieve
    /// de-essing, gating, pitch correction, limiting, or a delivery meter unless
    /// the request contains the corresponding production concept. Explicit
    /// reviewed names/aliases bypass this gate above.
    private static func allowsImplicitSelection(
        entryName: String,
        normalizedRequest: String,
        requestTokens: Set<String>,
        requestedTerms: Set<ProductionTerm>
    ) -> Bool {
        func containsAny(_ tokens: Set<String>) -> Bool {
            !requestTokens.isDisjoint(with: tokens)
        }

        switch entryName {
        case "DeEsser", "DeEsser 2":
            return requestedTerms.contains(.sibilant)
                || containsAny(["deess", "essing", "ess", "esses", "fricative", "sibilance", "sibilant"])
        case "Noise Gate", "Silver Gate":
            return containsAny([
                "bleed", "buzz", "chatter", "duck", "ducking", "gate", "gating",
                "hiss", "hum", "leakage", "noise", "noisy",
            ]) || normalizedRequest.contains("clean up")
                || normalizedRequest.contains("between phrases")
                || normalizedRequest.contains("between notes")
        case "Pitch Correction":
            return containsAny([
                "autotune", "flat", "intonation", "key", "note", "notes", "pitch",
                "scale", "sharp", "tune", "tuned", "tuning",
            ])
        case "Limiter", "Adaptive Limiter":
            return containsAny([
                "ceiling", "clip", "clipping", "delivery", "limit", "limiter",
                "limiting", "loud", "louder", "loudness", "master", "mastering",
                "overs", "peak", "peaks", "streaming",
            ])
        case "Loudness Meter":
            return containsAny([
                "delivery", "level", "loudness", "lufs", "measure", "meter",
                "streaming", "target",
            ])
        case "MultiMeter":
            return containsAny([
                "correlation", "goniometer", "level", "loudness", "meter", "mono",
                "peak", "phase", "spectrum", "truepeak", "width",
            ])
        default:
            return true
        }
    }

    private static func sourceFamilyScore(_ family: String, sourceType: SourceType) -> Int {
        let priorities: [String]
        switch sourceType {
        case .vocal, .vocalBus:
            priorities = ["dynamics", "equalizer", "pitch", "reverb", "delay", "specialized", "distortion"]
        case .drums, .drumBus:
            priorities = ["dynamics", "equalizer", "reverb", "delay", "distortion", "specialized", "multi_effect", "pedalboard"]
        case .bass:
            priorities = ["equalizer", "dynamics", "amp", "distortion", "specialized", "filter", "reverb", "delay", "pedalboard"]
        case .guitar:
            priorities = ["equalizer", "dynamics", "amp", "delay", "reverb", "distortion", "pedalboard"]
        case .keyboard, .synth:
            priorities = ["equalizer", "dynamics", "filter", "modulation", "imaging", "reverb", "delay", "multi_effect", "distortion", "pedalboard"]
        case .fullMix:
            priorities = ["mastering", "equalizer", "dynamics", "imaging", "metering", "reverb"]
        case .reference, .unknown:
            return 0
        }
        let baseFamily = family.hasPrefix("pedalboard_") ? "pedalboard" : family
        guard let index = priorities.firstIndex(of: family) ?? priorities.firstIndex(of: baseFamily) else {
            return 0
        }
        return 80 - index * 10
    }

    /// A bounded tie-breaker derived from TrackSmith's 58 deeply curated
    /// professional cases. It is deliberately applied only when the effect's
    /// semantic tags match the interpreted request. This is neither global DAW
    /// insertion telemetry nor a fixed processing order, and an explicit native
    /// effect name/alias still dominates with the identity scores above.
    private static func coreProductionPriorityBonus(_ name: String) -> Int {
        guard let rank = LogicCoreEffectPriority.rankByName[name] else { return 0 }
        return max(4, 42 - rank * 2)
    }
}

/// The instrument manual is a separate immutable source from the effects
/// manual. Instrument knowledge therefore has a distinct catalog and source
/// hash instead of being blended into the effects provenance ledger.
public struct LogicNativeInstrumentKnowledgeCatalog: Sendable {
    public static let expectedLogicPro12_3EntryCount = 28

    public var sourceSHA256: String
    public var supplementalSourceSHA256s: [String]
    public var reviewStatus: LogicKnowledgeReviewStatus
    public var entries: [LogicNativeToolKnowledge]

    public init(
        sourceSHA256: String,
        supplementalSourceSHA256s: [String] = [],
        reviewStatus: LogicKnowledgeReviewStatus,
        entries: [LogicNativeToolKnowledge]
    ) {
        self.sourceSHA256 = sourceSHA256
        self.supplementalSourceSHA256s = supplementalSourceSHA256s
        self.reviewStatus = reviewStatus
        self.entries = entries
    }

    public func validate(expectedEntryCount: Int? = nil) throws {
        if let expectedEntryCount, entries.count != expectedEntryCount {
            throw LogicNativeInstrumentKnowledgeError.wrongEntryCount(
                expected: expectedEntryCount,
                actual: entries.count
            )
        }
        guard supplementalSourceSHA256s.allSatisfy({
            $0.count == 64 && $0.allSatisfy { $0.isHexDigit && !$0.isUppercase }
        }), Set(supplementalSourceSHA256s).count == supplementalSourceSHA256s.count else {
            throw LogicNativeInstrumentKnowledgeError.invalidCatalog(.malformedEntry("supplemental-source-provenance"))
        }
        do {
            try LogicNativeToolKnowledgeCatalog(
                sourceSHA256: sourceSHA256,
                reviewStatus: reviewStatus,
                entries: entries
            ).validate()
        } catch let error as LogicNativeToolKnowledgeError {
            throw LogicNativeInstrumentKnowledgeError.invalidCatalog(error)
        }
    }

    /// Instrument advice is retrieved only when the request explicitly names
    /// an instrument or reviewed alias. A generic recorded-synth request does
    /// not establish which Logic instrument created the audio.
    public func selectExplicitlyReferenced(
        request: String,
        sourceType: SourceType,
        maximumCount: Int
    ) -> [LogicNativeToolKnowledge] {
        guard maximumCount > 0 else { return [] }
        let normalizedRequest = Self.normalizedPhrase(request)
        return entries.compactMap { entry -> (LogicNativeToolKnowledge, Int)? in
            guard entry.applicableSourceTypes.contains(sourceType) else { return nil }
            let normalizedName = Self.normalizedPhrase(entry.name)
            var score = !normalizedName.isEmpty && normalizedRequest.contains(normalizedName)
                ? 1_000 : 0
            for alias in entry.aliases {
                let normalizedAlias = Self.normalizedPhrase(alias)
                if !normalizedAlias.isEmpty, normalizedRequest.contains(normalizedAlias) {
                    score = max(score, 900)
                }
            }
            return score > 0 ? (entry, score) : nil
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.identifier < rhs.0.identifier
        }.prefix(min(maximumCount, 4)).map(\.0)
    }

    private static func normalizedPhrase(_ value: String) -> String {
        value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .joined(separator: " ")
    }
}
