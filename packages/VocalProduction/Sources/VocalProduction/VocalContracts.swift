import Foundation
import PlanSchema

public enum VocalSchemaVersion: String, Codable, CaseIterable, Sendable {
    case v1 = "1.0"
}

public enum VocalEvidenceKind: String, Codable, CaseIterable, Sendable {
    case measurementSupported
    case userReported
    case listeningOnly
    case professionalPracticeHeuristic
    case productHeuristic
    case unknown
}

public struct VocalProvenance: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var identifier: String
    public var evidenceKind: VocalEvidenceKind
    public var sourceVersion: String?
    public var statement: String
    public var limitations: [String]
    public var confidence: Double

    public init(
        version: VocalSchemaVersion = .v1,
        identifier: String,
        evidenceKind: VocalEvidenceKind,
        sourceVersion: String? = nil,
        statement: String,
        limitations: [String] = [],
        confidence: Double
    ) {
        self.version = version
        self.identifier = identifier
        self.evidenceKind = evidenceKind
        self.sourceVersion = sourceVersion
        self.statement = statement
        self.limitations = limitations
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
    }
}

public enum VocalIntentKind: String, Codable, CaseIterable, Sendable {
    case corrective
    case creative
    case correctiveAndCreative
}

public enum VocalLanguageDimension: String, Codable, CaseIterable, Sendable {
    case directTechnical
    case sensory
    case emotional
    case material
    case motion
    case metaphorical
}

public struct VocalLanguageCue: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var text: String
    public var dimension: VocalLanguageDimension
    public var confidence: Double

    public init(
        version: VocalSchemaVersion = .v1,
        text: String,
        dimension: VocalLanguageDimension,
        confidence: Double
    ) {
        self.version = version
        self.text = text
        self.dimension = dimension
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
    }
}

public enum VocalAspect: String, Codable, CaseIterable, Sendable {
    case pitch
    case timing
    case melody
    case dynamics
    case voiceIdentity
    case articulation
    case consonants
    case intelligibility
    case breath
    case attack
    case tone
    case body
    case air
    case brightness
    case darkness
    case warmth
    case closeness
    case distance
    case space
    case movement
    case wobble
    case instability
    case fragility
    case broken
    case distortion
    case width
    case loudness
    case metallicCharacter
    case smokyCharacter
    case glassyCharacter
    case brassLikeColoration
    case underwaterColoration
    case floating
    case radioLike
}

public enum VocalIntentDirection: String, Codable, CaseIterable, Sendable {
    case increase
    case decrease
    case preserve
    case prohibit
}

public struct VocalAspectIntent: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var aspect: VocalAspect
    public var direction: VocalIntentDirection
    public var strength: Double
    public var rationale: String

    public init(
        version: VocalSchemaVersion = .v1,
        aspect: VocalAspect,
        direction: VocalIntentDirection,
        strength: Double,
        rationale: String
    ) {
        self.version = version
        self.aspect = aspect
        self.direction = direction
        self.strength = min(max(strength.isFinite ? strength : 0, 0), 1)
        self.rationale = rationale
    }
}

public enum VocalScopeKind: String, Codable, CaseIterable, Sendable {
    case fullSource
    case seconds
    case namedSection
}

public struct VocalCreativeScope: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var kind: VocalScopeKind
    public var seconds: TimeRangeSeconds?
    public var sectionID: String?
    public var sectionName: String?

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        kind: VocalScopeKind,
        seconds: TimeRangeSeconds? = nil,
        sectionID: String? = nil,
        sectionName: String? = nil
    ) {
        self.version = version
        self.id = id
        self.kind = kind
        self.seconds = seconds
        self.sectionID = sectionID
        self.sectionName = sectionName
    }

    public static func fullSource(id: UUID) -> VocalCreativeScope {
        VocalCreativeScope(id: id, kind: .fullSource)
    }

    public static func seconds(id: UUID, start: Double, end: Double) -> VocalCreativeScope {
        VocalCreativeScope(id: id, kind: .seconds, seconds: .init(start: start, end: end))
    }

    public static func namedSection(
        id: UUID,
        sectionID: String,
        name: String,
        seconds: TimeRangeSeconds
    ) -> VocalCreativeScope {
        VocalCreativeScope(
            id: id,
            kind: .namedSection,
            seconds: seconds,
            sectionID: sectionID,
            sectionName: name
        )
    }

    public func processingScope(channelFormat: ChannelFormat, sourceType: SourceType) -> ProcessingScope {
        ProcessingScope(
            kind: .importedFile,
            channelFormat: channelFormat,
            sourceType: sourceType,
            timeRangeSeconds: kind == .fullSource ? nil : seconds
        )
    }
}

public enum VocalEditability: String, Codable, CaseIterable, Sendable {
    case editableDeterministicDSP
    case editableAnalysisDrivenResynthesis
    case renderedAssetWithEditableSourcePlan
}

public enum VocalAssetAcceptance: String, Codable, CaseIterable, Sendable {
    case editableDSPOnly
    case allowLocalRenderedAsset
    case requireLocalRenderedAsset
    case rejectRenderedAssets
}

public enum VocalProcessingBoundary: String, Codable, CaseIterable, Sendable {
    case editableDeterministicDSP
    case editableModulationDSP
    case analysisDrivenResynthesis
    case scopedEditablePlanForOfflineRender
    case renderedAsset
}

public struct VocalExactReference: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var sourceSnapshotID: UUID
    public var scopeID: UUID
    public var candidateID: UUID?
    public var nodeIDs: [UUID]
    public var previewID: UUID?
    public var assetID: UUID?
    public var aspect: VocalAspect?

    public init(
        version: VocalSchemaVersion = .v1,
        sourceSnapshotID: UUID,
        scopeID: UUID,
        candidateID: UUID? = nil,
        nodeIDs: [UUID] = [],
        previewID: UUID? = nil,
        assetID: UUID? = nil,
        aspect: VocalAspect? = nil
    ) {
        self.version = version
        self.sourceSnapshotID = sourceSnapshotID
        self.scopeID = scopeID
        self.candidateID = candidateID
        self.nodeIDs = nodeIDs
        self.previewID = previewID
        self.assetID = assetID
        self.aspect = aspect
    }
}

public enum VocalAspectLockScopePolicy: String, Codable, CaseIterable, Sendable {
    case exactScope
    case contentRelative
}

public struct VocalAspectLock: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var aspect: VocalAspect
    public var reference: VocalExactReference
    public var exactNodes: [ProcessingNode]
    public var scopePolicy: VocalAspectLockScopePolicy
    public var reason: String

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        aspect: VocalAspect,
        reference: VocalExactReference,
        exactNodes: [ProcessingNode] = [],
        scopePolicy: VocalAspectLockScopePolicy = .contentRelative,
        reason: String
    ) {
        self.version = version
        self.id = id
        self.aspect = aspect
        self.reference = reference
        self.exactNodes = exactNodes
        self.scopePolicy = scopePolicy
        self.reason = reason
    }
}

public struct VocalPreservationContract: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var preserved: [VocalAspect]
    public var prohibitedChanges: [VocalAspect]
    public var stopConditions: [String]
    public var rollbackInstructions: [String]

    public init(
        version: VocalSchemaVersion = .v1,
        preserved: [VocalAspect],
        prohibitedChanges: [VocalAspect] = [],
        stopConditions: [String] = [],
        rollbackInstructions: [String] = []
    ) {
        self.version = version
        self.preserved = Self.unique(preserved)
        self.prohibitedChanges = Self.unique(prohibitedChanges)
        self.stopConditions = stopConditions
        self.rollbackInstructions = rollbackInstructions
    }

    private static func unique(_ input: [VocalAspect]) -> [VocalAspect] {
        var seen = Set<VocalAspect>()
        return input.filter { seen.insert($0).inserted }
    }
}

public enum VocalCreativeArchetype: String, Codable, CaseIterable, Sendable {
    case ordinary
    case underwater
    case vocalToBrass
    case glassy
    case smoky
    case enormousButDistant
    case fragile
    case broken
    case floating
    case metallic
    case radioLike
    case dreamlike
    case unstable
    case extremelyIntimate
}

/// A bounded question that must be resolved before Vocal v1 may construct an
/// executable plan. This is intentionally separate from `ambiguities`, which
/// can document honest, nonblocking interpretation uncertainty (for example,
/// the possible meanings of a brass-like coloration request).
public enum VocalBlockingClarificationReason: String, Codable, CaseIterable, Sendable {
    case missingDesiredChanges
}

public struct VocalBlockingClarification: Codable, Equatable, Sendable {
    public var reason: VocalBlockingClarificationReason
    public var prompt: String

    public init(reason: VocalBlockingClarificationReason, prompt: String) {
        self.reason = reason
        self.prompt = prompt
    }
}

public struct VocalCreativeIntent: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var sourceSnapshotID: UUID
    public var originalPrompt: String
    public var kind: VocalIntentKind
    public var archetype: VocalCreativeArchetype
    public var languageCues: [VocalLanguageCue]
    public var strength: Double
    public var scope: VocalCreativeScope
    public var desiredChanges: [VocalAspectIntent]
    public var preservation: VocalPreservationContract
    public var ambiguities: [String]
    public var uncertainties: [String]
    public var editability: VocalEditability
    public var assetAcceptance: VocalAssetAcceptance
    public var exactReferences: [VocalExactReference]
    public var aspectLocks: [VocalAspectLock]

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        sourceSnapshotID: UUID,
        originalPrompt: String,
        kind: VocalIntentKind,
        archetype: VocalCreativeArchetype,
        languageCues: [VocalLanguageCue],
        strength: Double,
        scope: VocalCreativeScope,
        desiredChanges: [VocalAspectIntent],
        preservation: VocalPreservationContract,
        ambiguities: [String] = [],
        uncertainties: [String] = [],
        editability: VocalEditability = .editableDeterministicDSP,
        assetAcceptance: VocalAssetAcceptance = .editableDSPOnly,
        exactReferences: [VocalExactReference] = [],
        aspectLocks: [VocalAspectLock] = []
    ) {
        self.version = version
        self.id = id
        self.sourceSnapshotID = sourceSnapshotID
        self.originalPrompt = originalPrompt
        self.kind = kind
        self.archetype = archetype
        self.languageCues = languageCues
        self.strength = min(max(strength.isFinite ? strength : 0, 0), 1)
        self.scope = scope
        self.desiredChanges = desiredChanges
        self.preservation = preservation
        self.ambiguities = ambiguities
        self.uncertainties = uncertainties
        self.editability = editability
        self.assetAcceptance = assetAcceptance
        self.exactReferences = exactReferences
        self.aspectLocks = aspectLocks
    }

    /// Returns a typed, single bounded question for an ordinary request that
    /// does not name any executable vocal change. Archetypal transformations
    /// can retain nonblocking ambiguity because their desired changes are
    /// explicitly represented in the typed intent.
    public var blockingClarification: VocalBlockingClarification? {
        guard archetype == .ordinary, desiredChanges.isEmpty else { return nil }
        return VocalBlockingClarification(
            reason: .missingDesiredChanges,
            prompt: "Which single vocal change should take priority: clarity, warmth, brightness, dynamics, closeness, distance, or width?"
        )
    }

    /// A display-ready form of `blockingClarification` for the app layer.
    public var clarificationPrompt: String? {
        blockingClarification?.prompt
    }

    public var requiresBlockingClarification: Bool {
        blockingClarification != nil
    }
}

public struct VocalAspectBinding: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var aspect: VocalAspect
    public var nodeIDs: [UUID]
    public var inheritedFromCandidateID: UUID?
    public var limitations: [String]

    public init(
        version: VocalSchemaVersion = .v1,
        aspect: VocalAspect,
        nodeIDs: [UUID],
        inheritedFromCandidateID: UUID? = nil,
        limitations: [String] = []
    ) {
        self.version = version
        self.aspect = aspect
        self.nodeIDs = nodeIDs
        self.inheritedFromCandidateID = inheritedFromCandidateID
        self.limitations = limitations
    }
}

public enum VocalCandidateAuthorityStatus: String, Codable, CaseIterable, Sendable {
    case locallyValidated
    case staleSourceReadOnly
    case refused
}

public struct VocalCreativeCandidate: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var parentCandidateID: UUID?
    public var revisionID: UUID?
    public var revertedToCandidateID: UUID?
    public var title: String
    public var summary: String
    public var interpretationIndex: Int
    public var intent: VocalCreativeIntent
    public var plan: ProcessingPlan
    public var boundary: VocalProcessingBoundary
    public var aspectBindings: [VocalAspectBinding]
    public var limitations: [String]
    public var previewID: UUID?
    public var assetID: UUID?
    public var realtimeActivatable: Bool
    public var authorityStatus: VocalCandidateAuthorityStatus
    public var createdAt: Date

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        parentCandidateID: UUID? = nil,
        revisionID: UUID? = nil,
        revertedToCandidateID: UUID? = nil,
        title: String,
        summary: String,
        interpretationIndex: Int,
        intent: VocalCreativeIntent,
        plan: ProcessingPlan,
        boundary: VocalProcessingBoundary,
        aspectBindings: [VocalAspectBinding],
        limitations: [String],
        previewID: UUID? = nil,
        assetID: UUID? = nil,
        realtimeActivatable: Bool,
        authorityStatus: VocalCandidateAuthorityStatus = .locallyValidated,
        createdAt: Date
    ) {
        self.version = version
        self.id = id
        self.parentCandidateID = parentCandidateID
        self.revisionID = revisionID
        self.revertedToCandidateID = revertedToCandidateID
        self.title = title
        self.summary = summary
        self.interpretationIndex = interpretationIndex
        self.intent = intent
        self.plan = plan
        self.boundary = boundary
        self.aspectBindings = aspectBindings
        self.limitations = limitations
        self.previewID = previewID
        self.assetID = assetID
        self.realtimeActivatable = realtimeActivatable
        self.authorityStatus = authorityStatus
        self.createdAt = createdAt
    }
}

public struct VocalDeterministicIDs: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var candidateIDs: [UUID]
    public var planRequestIDs: [UUID]
    public var nodeIDsByCandidate: [[UUID]]
    public var lockIDs: [UUID]

    public init(
        version: VocalSchemaVersion = .v1,
        candidateIDs: [UUID] = [],
        planRequestIDs: [UUID] = [],
        nodeIDsByCandidate: [[UUID]] = [],
        lockIDs: [UUID] = []
    ) {
        self.version = version
        self.candidateIDs = candidateIDs
        self.planRequestIDs = planRequestIDs
        self.nodeIDsByCandidate = nodeIDsByCandidate
        self.lockIDs = lockIDs
    }
}

public struct VocalSourceAuthority: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var sourceSnapshotID: UUID
    public var immutableSourceID: String
    public var contentHashSHA256: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int
    public var capturedAt: Date

    public init(
        version: VocalSchemaVersion = .v1,
        sourceSnapshotID: UUID,
        immutableSourceID: String,
        contentHashSHA256: String,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int,
        capturedAt: Date
    ) {
        self.version = version
        self.sourceSnapshotID = sourceSnapshotID
        self.immutableSourceID = immutableSourceID
        self.contentHashSHA256 = contentHashSHA256.lowercased()
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.capturedAt = capturedAt
    }
}

public enum VocalContractError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidScope(String)
    case invalidStrength(Double)
    case invalidSourceType(SourceType)
    case contradictoryIntent(String)
    case unsupportedIntent(String)
    case blockingClarificationRequired(VocalBlockingClarification)
    case insufficientDeterministicIDs(String)
    case staleSource(expected: UUID, actual: UUID)
    case scopedRealtimeActivationForbidden
    case missingReference(UUID)
    case conflictingLock(VocalAspect)
    case lockedNodeModified(UUID)
    case preservationConstraintViolation(aspect: VocalAspect, detail: String)
    case validationFailed(String)

    public var description: String {
        switch self {
        case let .invalidScope(reason): "Invalid vocal scope: \(reason)"
        case let .invalidStrength(value): "Vocal strength \(value) must be finite and inside 0...1."
        case let .invalidSourceType(type): "Vocal production cannot target source type \(type.rawValue)."
        case let .contradictoryIntent(reason): "Contradictory vocal intent: \(reason)"
        case let .unsupportedIntent(reason): "Unsupported vocal intent: \(reason)"
        case let .blockingClarificationRequired(clarification): "Vocal planning requires clarification: \(clarification.prompt)"
        case let .insufficientDeterministicIDs(reason): "Deterministic identity set is incomplete: \(reason)"
        case let .staleSource(expected, actual): "Vocal authority expects source \(expected), received \(actual)."
        case .scopedRealtimeActivationForbidden: "A seconds or named-section vocal plan cannot be activated as a whole-stream AU graph; use the explicit offline scoped workflow."
        case let .missingReference(id): "Referenced vocal object \(id) is unavailable."
        case let .conflictingLock(aspect): "The requested change conflicts with the locked \(aspect.rawValue) aspect."
        case let .lockedNodeModified(id): "Locked vocal processing node \(id) was modified or removed."
        case let .preservationConstraintViolation(aspect, detail):
            "The candidate exceeds the bounded \(aspect.rawValue) preservation constraint: \(detail)"
        case let .validationFailed(reason): "Vocal contract validation failed: \(reason)"
        }
    }
}

/// A deliberately small, local matrix for the aspects where the current DSP
/// graph can enforce a *process* boundary. It is not a perceptual model: a
/// passing graph still requires matched listening to establish intelligibility,
/// identity, or musical preservation.
public struct VocalDSPAspectConstraint: Equatable, Sendable {
    public var aspect: VocalAspect
    public var forbiddenNodeTypes: Set<NodeType>
    public var parameterBounds: [NodeType: [ParameterID: ClosedRange<Double>]]
    public var limitation: String

    public init(
        aspect: VocalAspect,
        forbiddenNodeTypes: Set<NodeType> = [],
        parameterBounds: [NodeType: [ParameterID: ClosedRange<Double>]] = [:],
        limitation: String
    ) {
        self.aspect = aspect
        self.forbiddenNodeTypes = forbiddenNodeTypes
        self.parameterBounds = parameterBounds
        self.limitation = limitation
    }
}

public struct VocalDSPPreservationViolation: Equatable, Sendable {
    public var aspect: VocalAspect
    public var nodeID: UUID
    public var detail: String

    public init(aspect: VocalAspect, nodeID: UUID, detail: String) {
        self.aspect = aspect
        self.nodeID = nodeID
        self.detail = detail
    }
}

/// The result of deterministic planner-side clamping. Validation never clamps:
/// persisted or revised candidates must already satisfy the same matrix.
public struct VocalPreservationEnforcement: Equatable, Sendable {
    public var nodes: [ProcessingNode]
    public var constrainedAspects: [VocalAspect]
    public var adjustments: [String]

    public init(
        nodes: [ProcessingNode],
        constrainedAspects: [VocalAspect],
        adjustments: [String]
    ) {
        self.nodes = nodes
        self.constrainedAspects = constrainedAspects
        self.adjustments = adjustments
    }
}

/// Bounded aspect-to-DSP capability matrix used by both planning and contract
/// validation. Values are intentionally conservative process limits, not
/// assertions about an unmeasured listener outcome.
public enum VocalDSPPreservationMatrix {
    public static let constraints: [VocalAspect: VocalDSPAspectConstraint] = [
        .pitch: VocalDSPAspectConstraint(
            aspect: .pitch,
            parameterBounds: temporalBounds(
                maxDelayMS: 300,
                maxModulationDepthMS: 12,
                maxModulationRateHz: 2,
                maxFeedback: 0.35,
                maxMix: 0.30
            ),
            limitation: "No pitch-replacement processor is available; delays remain bounded wet support rather than pitch authority."
        ),
        .timing: VocalDSPAspectConstraint(
            aspect: .timing,
            parameterBounds: temporalBounds(
                maxDelayMS: 300,
                maxModulationDepthMS: 12,
                maxModulationRateHz: 2,
                maxFeedback: 0.35,
                maxMix: 0.30
            ),
            limitation: "No retiming processor is available; delayed material remains bounded so it cannot become timing authority."
        ),
        .melody: VocalDSPAspectConstraint(
            aspect: .melody,
            parameterBounds: temporalBounds(
                maxDelayMS: 300,
                maxModulationDepthMS: 12,
                maxModulationRateHz: 2,
                maxFeedback: 0.35,
                maxMix: 0.30
            ),
            limitation: "No melody replacement or synthesis path is available; temporal effects stay bounded support only."
        ),
        .voiceIdentity: VocalDSPAspectConstraint(
            aspect: .voiceIdentity,
            parameterBounds: identityBounds(),
            limitation: "The graph has no voice-conversion or resynthesis node; tone, density, and time effects are kept within bounded editable ranges."
        ),
        .intelligibility: VocalDSPAspectConstraint(
            aspect: .intelligibility,
            parameterBounds: intelligibilityBounds(),
            limitation: "The graph limits masking-prone filtering, nonlinear density, and wet time effects; it does not measure phonemes or certify word understanding."
        ),
        .consonants: VocalDSPAspectConstraint(
            aspect: .consonants,
            parameterBounds: consonantBounds(),
            limitation: "The graph limits consonant-masking paths; consonant preservation is still decided by listening, not a DSP metric."
        ),
        .articulation: VocalDSPAspectConstraint(
            aspect: .articulation,
            parameterBounds: consonantBounds(),
            limitation: "The graph uses the same conservative process limits as consonant preservation; articulation remains a listening judgment."
        ),
        .dynamics: VocalDSPAspectConstraint(
            aspect: .dynamics,
            parameterBounds: [
                .compressor: [.ratio: 1...3.5, .mix: 0...0.80, .attackMS: 10...500],
                .expander: [.ratio: 1...2.5, .mix: 0...0.45],
                .saturation: [.mix: 0...0.45],
                .softClipper: [.mix: 0...0.30],
            ],
            limitation: "Dynamics controls remain bounded parallel relationships; musical dynamics are not measured or guaranteed."
        ),
        .attack: VocalDSPAspectConstraint(
            aspect: .attack,
            parameterBounds: [
                .compressor: [.attackMS: 10...500, .mix: 0...0.80, .ratio: 1...3.5],
                .modulatedDelay: [.mix: 0...0.22, .modulationDepthMS: 0...10],
                .delay: [.mix: 0...0.20, .feedback: 0...0.20],
                .reverb: [.mix: 0...0.22, .decayTimeSeconds: 0.1...2.4],
            ],
            limitation: "Attack-sensitive paths use bounded parallel control and ambience; no transient measurement claim is made."
        ),
        .width: VocalDSPAspectConstraint(
            aspect: .width,
            parameterBounds: [
                .stereoWidth: [.width: 0.75...1.40, .mix: 0...0.50],
                .delay: [.stereoCrossfeed: 0...0.60, .mix: 0...0.25],
                .modulatedDelay: [.stereoPhaseDegrees: 0...150, .mix: 0...0.25],
            ],
            limitation: "Width processing stays bounded and the executable plan retains its mono-compatibility output constraint."
        ),
        .loudness: VocalDSPAspectConstraint(
            aspect: .loudness,
            parameterBounds: [
                .inputTrim: [.gainDB: -60...0],
                .outputTrim: [.gainDB: -60...0],
                .loudnessMatch: [.gainDB: -60...0],
                .compressor: [.makeupGainDB: -24...0],
            ],
            limitation: "No positive linear makeup or trim is allowed under a loudness preservation/prohibition request; preview matching remains required."
        ),
    ]

    public static func constrainedNodes(
        _ input: [ProcessingNode],
        preservation: VocalPreservationContract,
        lockedAspects: [VocalAspect] = []
    ) throws -> VocalPreservationEnforcement {
        let aspects = protectedAspects(in: preservation, lockedAspects: lockedAspects)
        var nodes = input
        var adjustments: [String] = []
        var constrained: [VocalAspect] = []

        for aspect in aspects {
            guard let constraint = constraints[aspect] else { continue }
            constrained.append(aspect)
            for index in nodes.indices {
                let node = nodes[index]
                guard node.enabled else { continue }
                if constraint.forbiddenNodeTypes.contains(node.type) {
                    throw VocalContractError.preservationConstraintViolation(
                        aspect: aspect,
                        detail: "\(node.type.rawValue) has no approved bounded path."
                    )
                }
                guard let bounds = constraint.parameterBounds[node.type] else { continue }
                for parameter in bounds.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                    guard let permitted = bounds[parameter] else { continue }
                    let explicit = nodes[index].parameters[parameter]
                    guard let current = explicit ?? effectiveDefault(nodeType: node.type, parameter: parameter) else {
                        continue
                    }
                    guard current.isFinite else {
                        throw VocalContractError.preservationConstraintViolation(
                            aspect: aspect,
                            detail: "\(node.type.rawValue).\(parameter.rawValue) is nonfinite."
                        )
                    }
                    let replacement = min(max(current, permitted.lowerBound), permitted.upperBound)
                    guard replacement != current else { continue }
                    nodes[index].parameters[parameter] = replacement
                    let source = explicit == nil ? "effective default" : "value"
                    adjustments.append(
                        "\(aspect.rawValue) guard bounded \(node.type.rawValue).\(parameter.rawValue) \(source) from \(format(current)) to \(format(replacement))."
                    )
                }
            }
        }

        return VocalPreservationEnforcement(
            nodes: nodes,
            constrainedAspects: constrained,
            adjustments: adjustments
        )
    }

    public static func violations(
        in nodes: [ProcessingNode],
        preservation: VocalPreservationContract,
        lockedAspects: [VocalAspect] = []
    ) -> [VocalDSPPreservationViolation] {
        var result: [VocalDSPPreservationViolation] = []
        for aspect in protectedAspects(in: preservation, lockedAspects: lockedAspects) {
            guard let constraint = constraints[aspect] else { continue }
            for node in nodes where node.enabled {
                if constraint.forbiddenNodeTypes.contains(node.type) {
                    result.append(VocalDSPPreservationViolation(
                        aspect: aspect,
                        nodeID: node.id,
                        detail: "\(node.type.rawValue) has no approved bounded path."
                    ))
                }
                guard let bounds = constraint.parameterBounds[node.type] else { continue }
                for parameter in bounds.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                    guard let permitted = bounds[parameter],
                          let value = node.parameters[parameter]
                            ?? effectiveDefault(nodeType: node.type, parameter: parameter),
                          !value.isFinite || !permitted.contains(value) else { continue }
                    let source = node.parameters[parameter] == nil ? "effective default " : ""
                    result.append(VocalDSPPreservationViolation(
                        aspect: aspect,
                        nodeID: node.id,
                        detail: "\(node.type.rawValue).\(parameter.rawValue) \(source)=\(format(value)) is outside \(format(permitted.lowerBound))...\(format(permitted.upperBound))."
                    ))
                }
            }
        }
        return result
    }

    public static func protectedAspects(
        in preservation: VocalPreservationContract,
        lockedAspects: [VocalAspect] = []
    ) -> [VocalAspect] {
        Array(Set(preservation.preserved + preservation.prohibitedChanges + lockedAspects))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private static func temporalBounds(
        maxDelayMS: Double,
        maxModulationDepthMS: Double,
        maxModulationRateHz: Double,
        maxFeedback: Double,
        maxMix: Double
    ) -> [NodeType: [ParameterID: ClosedRange<Double>]] {
        [
            .delay: [
                .delayTimeMS: 1...maxDelayMS,
                .feedback: 0...maxFeedback,
                .mix: 0...maxMix,
            ],
            .modulatedDelay: [
                .delayTimeMS: 1...maxDelayMS,
                .modulationDepthMS: 0...maxModulationDepthMS,
                .modulationRateHz: 0.05...maxModulationRateHz,
                .feedback: 0...maxFeedback,
                .mix: 0...maxMix,
            ],
            .reverb: [.mix: 0...maxMix],
        ]
    }

    private static func identityBounds() -> [NodeType: [ParameterID: ClosedRange<Double>]] {
        [
            .highPass: [.frequencyHz: 10...180],
            .lowPass: [.frequencyHz: 3_500...24_000],
            .parametricEQ: [.gainDB: -5...5],
            .compressor: [.ratio: 1...4, .mix: 0...0.85],
            .expander: [.ratio: 1...3, .rangeDB: 0...24, .mix: 0...0.45],
            .deEsser: [.frequencyHz: 3_000...12_000, .ratio: 1...6, .mix: 0...0.70],
            .saturation: [.driveDB: 0...18, .mix: 0...0.65],
            .softClipper: [.driveDB: 0...12, .mix: 0...0.45],
            .stereoWidth: [.width: 0.70...1.50, .mix: 0...0.60],
            .delay: [.delayTimeMS: 1...350, .feedback: 0...0.35, .mix: 0...0.35],
            .modulatedDelay: [
                .modulationDepthMS: 0...12,
                .modulationRateHz: 0.05...2,
                .feedback: 0...0.35,
                .mix: 0...0.35,
            ],
            .reverb: [.decayTimeSeconds: 0.1...3.5, .mix: 0...0.40],
        ]
    }

    private static func intelligibilityBounds() -> [NodeType: [ParameterID: ClosedRange<Double>]] {
        [
            .highPass: [.frequencyHz: 10...160],
            .lowPass: [.frequencyHz: 5_200...24_000],
            .parametricEQ: [.gainDB: -3...4],
            .compressor: [.ratio: 1...3, .mix: 0...0.82],
            .expander: [.ratio: 1...2.5, .rangeDB: 0...18, .mix: 0...0.35],
            .deEsser: [.frequencyHz: 3_500...12_000, .ratio: 1...5, .mix: 0...0.60],
            .saturation: [.driveDB: 0...12, .mix: 0...0.45],
            .softClipper: [.driveDB: 0...8, .mix: 0...0.25],
            .delay: [.delayTimeMS: 1...220, .feedback: 0...0.20, .mix: 0...0.18],
            .modulatedDelay: [
                .modulationDepthMS: 0...10,
                .modulationRateHz: 0.05...2,
                .feedback: 0...0.20,
                .mix: 0...0.22,
            ],
            .reverb: [.decayTimeSeconds: 0.1...2.4, .mix: 0...0.22],
        ]
    }

    private static func consonantBounds() -> [NodeType: [ParameterID: ClosedRange<Double>]] {
        [
            .highPass: [.frequencyHz: 10...150],
            .lowPass: [.frequencyHz: 5_800...24_000],
            .parametricEQ: [.gainDB: -2.5...3.5],
            .compressor: [.ratio: 1...3, .mix: 0...0.82, .attackMS: 10...500],
            .expander: [.ratio: 1...2.25, .rangeDB: 0...15, .mix: 0...0.30],
            .deEsser: [.frequencyHz: 4_000...12_000, .ratio: 1...4, .mix: 0...0.50],
            .saturation: [.driveDB: 0...12, .mix: 0...0.45],
            .softClipper: [.driveDB: 0...7, .mix: 0...0.20],
            .delay: [.delayTimeMS: 1...180, .feedback: 0...0.18, .mix: 0...0.16],
            .modulatedDelay: [
                .modulationDepthMS: 0...9,
                .modulationRateHz: 0.05...2,
                .feedback: 0...0.18,
                .mix: 0...0.20,
            ],
            .reverb: [.decayTimeSeconds: 0.1...2.1, .mix: 0...0.20],
        ]
    }

    /// Mirrors only the executable defaults needed by this local matrix. A
    /// missing wet/mix parameter must not evade a preservation bound merely
    /// because the DSP engine supplies its value at compile time.
    private static func effectiveDefault(
        nodeType: NodeType,
        parameter: ParameterID
    ) -> Double? {
        switch (nodeType, parameter) {
        case (.inputTrim, .gainDB), (.outputTrim, .gainDB), (.loudnessMatch, .gainDB): 0
        case (.highPass, .frequencyHz): 80
        case (.lowPass, .frequencyHz): 18_000
        case (.parametricEQ, .gainDB): 0
        case (.compressor, .ratio): 2
        case (.compressor, .attackMS): 20
        case (.compressor, .makeupGainDB): 0
        case (.compressor, .mix): 1
        case (.expander, .ratio): 4
        case (.expander, .rangeDB): 30
        case (.expander, .mix): 1
        case (.deEsser, .frequencyHz): 6_500
        case (.deEsser, .ratio): 3
        case (.deEsser, .mix): 1
        case (.saturation, .driveDB), (.softClipper, .driveDB): 0
        case (.saturation, .mix), (.softClipper, .mix), (.stereoWidth, .mix): 1
        case (.stereoWidth, .width): 1
        case (.delay, .delayTimeMS): 250
        case (.delay, .feedback): 0.25
        case (.delay, .stereoCrossfeed): 0
        case (.delay, .mix): 0.20
        case (.modulatedDelay, .delayTimeMS): 15
        case (.modulatedDelay, .modulationDepthMS): 3
        case (.modulatedDelay, .modulationRateHz): 0.35
        case (.modulatedDelay, .stereoPhaseDegrees): 90
        case (.modulatedDelay, .feedback): 0.15
        case (.modulatedDelay, .mix): 0.35
        case (.reverb, .decayTimeSeconds): 1.2
        case (.reverb, .mix): 0.15
        default: nil
        }
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

public struct VocalContractValidator: Sendable {
    public init() {}

    public func validate(scope: VocalCreativeScope) throws {
        switch scope.kind {
        case .fullSource:
            guard scope.seconds == nil, scope.sectionID == nil, scope.sectionName == nil else {
                throw VocalContractError.invalidScope("A full-source scope cannot carry section metadata.")
            }
        case .seconds:
            guard let seconds = scope.seconds,
                  seconds.start.isFinite,
                  seconds.end.isFinite,
                  seconds.start >= 0,
                  seconds.end > seconds.start,
                  scope.sectionID == nil,
                  scope.sectionName == nil else {
                throw VocalContractError.invalidScope("A seconds scope requires one finite increasing range and no named-section identity.")
            }
        case .namedSection:
            guard let seconds = scope.seconds,
                  seconds.start.isFinite,
                  seconds.end.isFinite,
                  seconds.start >= 0,
                  seconds.end > seconds.start,
                  let sectionID = scope.sectionID,
                  !sectionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let sectionName = scope.sectionName,
                  !sectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw VocalContractError.invalidScope("A named section requires an exact ID, name, and finite increasing range.")
            }
        }
    }

    public func validate(intent: VocalCreativeIntent) throws {
        try validate(scope: intent.scope)
        guard intent.strength.isFinite, (0...1).contains(intent.strength) else {
            throw VocalContractError.invalidStrength(intent.strength)
        }
        let changed = Set(intent.desiredChanges.map(\.aspect))
        let preserved = Set(intent.preservation.preserved)
        let prohibited = Set(intent.preservation.prohibitedChanges)
        if let contradiction = changed.intersection(prohibited).first {
            throw VocalContractError.contradictoryIntent(
                "\(contradiction.rawValue) is both requested and prohibited."
            )
        }
        for lock in intent.aspectLocks {
            guard lock.aspect == lock.reference.aspect else {
                throw VocalContractError.validationFailed("Aspect lock and exact reference disagree.")
            }
            guard lock.reference.sourceSnapshotID == intent.sourceSnapshotID else {
                throw VocalContractError.staleSource(
                    expected: intent.sourceSnapshotID,
                    actual: lock.reference.sourceSnapshotID
                )
            }
            if !lock.exactNodes.isEmpty {
                guard Set(lock.exactNodes.map(\.id)) == Set(lock.reference.nodeIDs),
                      Set(lock.exactNodes.map(\.id)).count == lock.exactNodes.count else {
                    throw VocalContractError.validationFailed(
                        "Aspect lock exact node snapshots and exact node references disagree."
                    )
                }
            }
        }
        _ = preserved
    }

    public func validate(candidate: VocalCreativeCandidate) throws {
        try validate(intent: candidate.intent)
        guard candidate.plan.scope.sourceType == .vocal
                || candidate.plan.scope.sourceType == .vocalBus else {
            throw VocalContractError.invalidSourceType(candidate.plan.scope.sourceType)
        }
        if candidate.realtimeActivatable, candidate.intent.scope.kind != .fullSource {
            throw VocalContractError.scopedRealtimeActivationForbidden
        }
        guard candidate.plan.sourceSnapshotID == candidate.intent.sourceSnapshotID else {
            throw VocalContractError.staleSource(
                expected: candidate.intent.sourceSnapshotID,
                actual: candidate.plan.sourceSnapshotID
            )
        }
        guard candidate.plan.scope.timeRangeSeconds == (
            candidate.intent.scope.kind == .fullSource ? nil : candidate.intent.scope.seconds
        ) else {
            throw VocalContractError.invalidScope("Typed creative scope and executable plan scope differ.")
        }
        do {
            if candidate.realtimeActivatable {
                try PlanValidator().validateForRealtimeActivation(
                    candidate.plan,
                    currentSnapshotID: candidate.intent.sourceSnapshotID
                )
            } else {
                try PlanValidator().validate(
                    candidate.plan,
                    currentSnapshotID: candidate.intent.sourceSnapshotID
                )
            }
        } catch {
            throw VocalContractError.validationFailed(String(describing: error))
        }
        if let violation = VocalDSPPreservationMatrix.violations(
            in: candidate.plan.nodes,
            preservation: candidate.intent.preservation,
            lockedAspects: candidate.intent.aspectLocks.map(\.aspect)
        ).first {
            throw VocalContractError.preservationConstraintViolation(
                aspect: violation.aspect,
                detail: violation.detail
            )
        }
    }

    /// Explicit AU/whole-stream gate. `PlanValidator` understands graph
    /// structure but intentionally does not give `timeRangeSeconds` scheduling
    /// semantics to an audio callback, so Vocal adds this authority check.
    public func validateForRealtimeActivation(_ candidate: VocalCreativeCandidate) throws {
        guard candidate.realtimeActivatable,
              candidate.intent.scope.kind == .fullSource,
              candidate.plan.scope.timeRangeSeconds == nil else {
            throw VocalContractError.scopedRealtimeActivationForbidden
        }
        try validate(candidate: candidate)
        do {
            try PlanValidator().validateForRealtimeActivation(
                candidate.plan,
                currentSnapshotID: candidate.intent.sourceSnapshotID
            )
        } catch {
            throw VocalContractError.validationFailed(String(describing: error))
        }
    }
}
