import Foundation

public enum VocalEvidenceClass: String, Codable, Sendable {
    /// One product-owner judgment is useful formative evidence, not expert or population evidence.
    case singleListenerFormativeEvidence = "SINGLE_LISTENER_FORMATIVE_EVIDENCE"
}

public struct VocalEvaluationSource: Codable, Equatable, Sendable {
    public var sourceID: String
    public var captureID: String
    public var sourceAudioSHA256: String

    public init(sourceID: String, captureID: String, sourceAudioSHA256: String) {
        self.sourceID = sourceID
        self.captureID = captureID
        self.sourceAudioSHA256 = sourceAudioSHA256
    }
}

public struct VocalEvaluationCandidate: Codable, Equatable, Sendable {
    /// This identity is kept only in the private answer key until judgment is finalized.
    public var candidateID: String
    public var candidateSHA256: String
    public var processingPlanID: String
    public var processingPlanSHA256: String
    public var previewID: String
    public var assetID: String?
    public var assetManifestSHA256: String?
    public var renderedAudioSHA256: String
    public var sourceAudioSHA256: String
    public var originalSourceUnmodified: Bool
    public var renderIsReproducibleDerivative: Bool

    public init(
        candidateID: String,
        candidateSHA256: String,
        processingPlanID: String,
        processingPlanSHA256: String,
        previewID: String,
        assetID: String? = nil,
        assetManifestSHA256: String? = nil,
        renderedAudioSHA256: String,
        sourceAudioSHA256: String,
        originalSourceUnmodified: Bool = true,
        renderIsReproducibleDerivative: Bool = true
    ) {
        self.candidateID = candidateID
        self.candidateSHA256 = candidateSHA256
        self.processingPlanID = processingPlanID
        self.processingPlanSHA256 = processingPlanSHA256
        self.previewID = previewID
        self.assetID = assetID
        self.assetManifestSHA256 = assetManifestSHA256
        self.renderedAudioSHA256 = renderedAudioSHA256
        self.sourceAudioSHA256 = sourceAudioSHA256
        self.originalSourceUnmodified = originalSourceUnmodified
        self.renderIsReproducibleDerivative = renderIsReproducibleDerivative
    }
}

public struct VocalBlindedStudyPlan: Codable, Equatable, Sendable {
    public static let schemaVersion = "1.0.0"

    public var schemaVersion: String
    public var studyID: String
    public var targetDescription: String
    public var source: VocalEvaluationSource
    public var candidates: [VocalEvaluationCandidate]
    public var deterministicSeed: UInt64
    public var levelMatchingRequired: Bool
    public var maximumLevelMismatchDB: Double
    public var evidenceClass: VocalEvidenceClass

    public init(
        studyID: String,
        targetDescription: String,
        source: VocalEvaluationSource,
        candidates: [VocalEvaluationCandidate],
        deterministicSeed: UInt64,
        levelMatchingRequired: Bool = true,
        maximumLevelMismatchDB: Double = 0.25
    ) {
        self.schemaVersion = Self.schemaVersion
        self.studyID = studyID
        self.targetDescription = targetDescription
        self.source = source
        self.candidates = candidates
        self.deterministicSeed = deterministicSeed
        self.levelMatchingRequired = levelMatchingRequired
        self.maximumLevelMismatchDB = maximumLevelMismatchDB
        self.evidenceClass = .singleListenerFormativeEvidence
    }
}

/// Participant-facing candidate metadata contains no TrackSmith candidate identity.
public struct VocalBlindCandidate: Codable, Equatable, Sendable {
    public var blindCode: String
    public var renderedAudioSHA256: String
    public var sourceAudioSHA256: String

    public init(blindCode: String, renderedAudioSHA256: String, sourceAudioSHA256: String) {
        self.blindCode = blindCode
        self.renderedAudioSHA256 = renderedAudioSHA256
        self.sourceAudioSHA256 = sourceAudioSHA256
    }
}

public struct VocalBlindedStudyPackage: Codable, Equatable, Sendable {
    public static let schemaVersion = "1.0.0"

    public var schemaVersion: String
    public var studyID: String
    public var targetDescription: String
    public var source: VocalEvaluationSource
    public var candidates: [VocalBlindCandidate]
    public var deterministicSeed: UInt64
    public var levelMatchingRequired: Bool
    public var maximumLevelMismatchDB: Double
    public var evidenceClass: VocalEvidenceClass
    public var packageFingerprint: String

    public init(
        studyID: String,
        targetDescription: String,
        source: VocalEvaluationSource,
        candidates: [VocalBlindCandidate],
        deterministicSeed: UInt64,
        levelMatchingRequired: Bool,
        maximumLevelMismatchDB: Double,
        evidenceClass: VocalEvidenceClass,
        packageFingerprint: String
    ) {
        self.schemaVersion = Self.schemaVersion
        self.studyID = studyID
        self.targetDescription = targetDescription
        self.source = source
        self.candidates = candidates
        self.deterministicSeed = deterministicSeed
        self.levelMatchingRequired = levelMatchingRequired
        self.maximumLevelMismatchDB = maximumLevelMismatchDB
        self.evidenceClass = evidenceClass
        self.packageFingerprint = packageFingerprint
    }
}

public struct VocalBlindIdentityMapping: Codable, Equatable, Sendable {
    public var blindCode: String
    public var candidateID: String
    public var candidateSHA256: String
    public var processingPlanID: String
    public var processingPlanSHA256: String
    public var previewID: String
    public var assetID: String?
    public var assetManifestSHA256: String?
    public var renderedAudioSHA256: String

    public init(
        blindCode: String,
        candidateID: String,
        candidateSHA256: String,
        processingPlanID: String,
        processingPlanSHA256: String,
        previewID: String,
        assetID: String? = nil,
        assetManifestSHA256: String? = nil,
        renderedAudioSHA256: String
    ) {
        self.blindCode = blindCode
        self.candidateID = candidateID
        self.candidateSHA256 = candidateSHA256
        self.processingPlanID = processingPlanID
        self.processingPlanSHA256 = processingPlanSHA256
        self.previewID = previewID
        self.assetID = assetID
        self.assetManifestSHA256 = assetManifestSHA256
        self.renderedAudioSHA256 = renderedAudioSHA256
    }
}

/// Store this separately from participant-facing files. It is consumed only after a complete,
/// finalized response passes validation.
public struct VocalPrivateAnswerKey: Codable, Equatable, Sendable {
    public static let schemaVersion = "1.0.0"

    public var schemaVersion: String
    public var studyID: String
    public var packageFingerprint: String
    public var mappings: [VocalBlindIdentityMapping]
    public var keepSealedUntilJudgment: Bool
    /// Deterministic integrity checksum over the private mappings; artifact identities remain SHA-256.
    public var answerKeyChecksum: String

    public init(
        studyID: String,
        packageFingerprint: String,
        mappings: [VocalBlindIdentityMapping],
        keepSealedUntilJudgment: Bool = true,
        answerKeyChecksum: String
    ) {
        self.schemaVersion = Self.schemaVersion
        self.studyID = studyID
        self.packageFingerprint = packageFingerprint
        self.mappings = mappings
        self.keepSealedUntilJudgment = keepSealedUntilJudgment
        self.answerKeyChecksum = answerKeyChecksum
    }
}

public struct PreparedVocalBlindedStudy: Equatable, Sendable {
    public var participantPackage: VocalBlindedStudyPackage
    public var privateAnswerKey: VocalPrivateAnswerKey

    public init(
        participantPackage: VocalBlindedStudyPackage,
        privateAnswerKey: VocalPrivateAnswerKey
    ) {
        self.participantPackage = participantPackage
        self.privateAnswerKey = privateAnswerKey
    }
}

public enum VocalListeningTransducer: String, Codable, Sendable {
    case headphones
    case studioMonitors = "studio_monitors"
    case consumerSpeakers = "consumer_speakers"
    case unknown
}

public enum VocalListeningEnvironment: String, Codable, Sendable {
    case quietTreated = "quiet_treated"
    case quietUntreated = "quiet_untreated"
    case typicalRoom = "typical_room"
    case unknown
}

public struct VocalListeningConditions: Codable, Equatable, Sendable {
    public var transducer: VocalListeningTransducer
    public var environment: VocalListeningEnvironment
    public var outputDeviceDescription: String
    public var levelMatched: Bool
    public var measuredMaximumLevelMismatchDB: Double
    public var listeningMinutes: Int
    public var fatigueBefore: Int
    public var fatigueAfter: Int

    public init(
        transducer: VocalListeningTransducer,
        environment: VocalListeningEnvironment,
        outputDeviceDescription: String,
        levelMatched: Bool,
        measuredMaximumLevelMismatchDB: Double,
        listeningMinutes: Int,
        fatigueBefore: Int,
        fatigueAfter: Int
    ) {
        self.transducer = transducer
        self.environment = environment
        self.outputDeviceDescription = outputDeviceDescription
        self.levelMatched = levelMatched
        self.measuredMaximumLevelMismatchDB = measuredMaximumLevelMismatchDB
        self.listeningMinutes = listeningMinutes
        self.fatigueBefore = fatigueBefore
        self.fatigueAfter = fatigueAfter
    }
}

/// All dimensions use the same bounded 1...7 ordinal scale.
public struct VocalCandidateScores: Codable, Equatable, Sendable {
    public var targetRelevance: Int
    public var sourcePreservation: Int
    public var naturalness: Int
    public var intelligibility: Int
    public var temporalCoherence: Int
    public var usefulness: Int

    public init(
        targetRelevance: Int,
        sourcePreservation: Int,
        naturalness: Int,
        intelligibility: Int,
        temporalCoherence: Int,
        usefulness: Int
    ) {
        self.targetRelevance = targetRelevance
        self.sourcePreservation = sourcePreservation
        self.naturalness = naturalness
        self.intelligibility = intelligibility
        self.temporalCoherence = temporalCoherence
        self.usefulness = usefulness
    }
}

public struct VocalCandidateJudgment: Codable, Equatable, Sendable {
    public var blindCode: String
    public var scores: VocalCandidateScores
    public var note: String?

    public init(blindCode: String, scores: VocalCandidateScores, note: String? = nil) {
        self.blindCode = blindCode
        self.scores = scores
        self.note = note
    }
}

public enum VocalPreferenceKind: String, Codable, Sendable {
    case candidate
    case none
    case noPreference = "no_preference"
}

public struct VocalPreference: Codable, Equatable, Sendable {
    public var kind: VocalPreferenceKind
    public var blindCode: String?

    public init(kind: VocalPreferenceKind, blindCode: String? = nil) {
        self.kind = kind
        self.blindCode = blindCode
    }

    public static func candidate(_ blindCode: String) -> Self {
        Self(kind: .candidate, blindCode: blindCode)
    }

    public static let none = Self(kind: .none)
    public static let noPreference = Self(kind: .noPreference)
}

public struct VocalFormativeResponse: Codable, Equatable, Sendable {
    public static let schemaVersion = "1.0.0"

    public var schemaVersion: String
    public var studyID: String
    public var packageFingerprint: String
    public var evidenceClass: VocalEvidenceClass
    public var listenerCount: Int
    public var identitiesRemainedBlindDuringJudgment: Bool
    public var conditions: VocalListeningConditions
    public var judgments: [VocalCandidateJudgment]
    public var preference: VocalPreference
    public var confidence: Int
    public var finalized: Bool
    public var responseChecksum: String

    public init(
        studyID: String,
        packageFingerprint: String,
        conditions: VocalListeningConditions,
        judgments: [VocalCandidateJudgment],
        preference: VocalPreference,
        confidence: Int,
        responseChecksum: String
    ) {
        self.schemaVersion = Self.schemaVersion
        self.studyID = studyID
        self.packageFingerprint = packageFingerprint
        self.evidenceClass = .singleListenerFormativeEvidence
        self.listenerCount = 1
        self.identitiesRemainedBlindDuringJudgment = true
        self.conditions = conditions
        self.judgments = judgments
        self.preference = preference
        self.confidence = confidence
        self.finalized = true
        self.responseChecksum = responseChecksum
    }
}

public struct VocalUnblindedCandidateResult: Codable, Equatable, Sendable {
    public var blindCode: String
    public var candidateID: String
    public var candidateSHA256: String
    public var processingPlanID: String
    public var processingPlanSHA256: String
    public var previewID: String
    public var assetID: String?
    public var assetManifestSHA256: String?
    public var renderedAudioSHA256: String
    public var scores: VocalCandidateScores
    public var note: String?

    public init(
        blindCode: String,
        candidateID: String,
        candidateSHA256: String,
        processingPlanID: String,
        processingPlanSHA256: String,
        previewID: String,
        assetID: String? = nil,
        assetManifestSHA256: String? = nil,
        renderedAudioSHA256: String,
        scores: VocalCandidateScores,
        note: String?
    ) {
        self.blindCode = blindCode
        self.candidateID = candidateID
        self.candidateSHA256 = candidateSHA256
        self.processingPlanID = processingPlanID
        self.processingPlanSHA256 = processingPlanSHA256
        self.previewID = previewID
        self.assetID = assetID
        self.assetManifestSHA256 = assetManifestSHA256
        self.renderedAudioSHA256 = renderedAudioSHA256
        self.scores = scores
        self.note = note
    }
}

public struct VocalSingleListenerFormativeEvidence: Codable, Equatable, Sendable {
    public var studyID: String
    public var packageFingerprint: String
    public var evidenceClass: VocalEvidenceClass
    public var claimBoundary: String
    public var conditions: VocalListeningConditions
    public var results: [VocalUnblindedCandidateResult]
    public var preferredCandidateID: String?
    public var preferenceKind: VocalPreferenceKind
    public var confidence: Int

    public init(
        studyID: String,
        packageFingerprint: String,
        evidenceClass: VocalEvidenceClass,
        claimBoundary: String,
        conditions: VocalListeningConditions,
        results: [VocalUnblindedCandidateResult],
        preferredCandidateID: String?,
        preferenceKind: VocalPreferenceKind,
        confidence: Int
    ) {
        self.studyID = studyID
        self.packageFingerprint = packageFingerprint
        self.evidenceClass = evidenceClass
        self.claimBoundary = claimBoundary
        self.conditions = conditions
        self.results = results
        self.preferredCandidateID = preferredCandidateID
        self.preferenceKind = preferenceKind
        self.confidence = confidence
    }
}

public enum VocalEvaluationError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalid(String)

    public var description: String {
        switch self {
        case let .invalid(reason): reason
        }
    }
}
