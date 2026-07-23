import Foundation
import PlanSchema

public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case offline
    case openAI
    case gemini
    case local
    case other
}

public enum ProviderCapability: String, Codable, CaseIterable, Sendable {
    case semanticIntentInterpretation
    case ambiguityDetection
    case conversationalReferenceInterpretation
    case productionHypothesisGeneration
    case explanationGeneration
    case audioReasoning
}

public struct ModelProviderDescriptor: Codable, Equatable, Sendable {
    public var identifier: String
    public var displayName: String
    public var kind: ProviderKind
    public var modelIdentifier: String
    public var capabilities: Set<ProviderCapability>
    public var usesNetwork: Bool
    public var acceptsRawAudio: Bool

    public init(
        identifier: String,
        displayName: String,
        kind: ProviderKind,
        modelIdentifier: String,
        capabilities: Set<ProviderCapability>,
        usesNetwork: Bool,
        acceptsRawAudio: Bool = false
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.kind = kind
        self.modelIdentifier = modelIdentifier
        self.capabilities = capabilities
        self.usesNetwork = usesNetwork
        self.acceptsRawAudio = acceptsRawAudio
    }
}

public struct ProviderRequestBudget: Codable, Equatable, Sendable {
    public var maxContextUTF8Bytes: Int
    public var maxOutputTokens: Int
    public var maxAttempts: Int
    public var timeoutSeconds: Double

    public init(
        maxContextUTF8Bytes: Int = 48_000,
        maxOutputTokens: Int = 2_500,
        maxAttempts: Int = 1,
        timeoutSeconds: Double = 25
    ) {
        self.maxContextUTF8Bytes = maxContextUTF8Bytes
        self.maxOutputTokens = maxOutputTokens
        self.maxAttempts = maxAttempts
        self.timeoutSeconds = timeoutSeconds
    }
}

/// Exact local authority that owns an asynchronous interpretation request.
/// Results must match every non-nil identity before they may influence plans.
public struct ProductionAuthorityIdentity: Codable, Equatable, Sendable {
    public var instanceID: UUID?
    public var runtimeEpoch: UUID?
    public var captureSnapshotID: UUID
    public var currentPlanRequestID: UUID?
    public var conversationID: UUID
    public var turnID: UUID

    public init(
        instanceID: UUID? = nil,
        runtimeEpoch: UUID? = nil,
        captureSnapshotID: UUID,
        currentPlanRequestID: UUID? = nil,
        conversationID: UUID,
        turnID: UUID = UUID()
    ) {
        self.instanceID = instanceID
        self.runtimeEpoch = runtimeEpoch
        self.captureSnapshotID = captureSnapshotID
        self.currentPlanRequestID = currentPlanRequestID
        self.conversationID = conversationID
        self.turnID = turnID
    }
}

public enum ModelContextLabel: String, Codable, CaseIterable, Sendable {
    case userRequest = "USER_REQUEST"
    case measuredEvidence = "MEASURED_EVIDENCE"
    case derivedInterpretation = "DERIVED_INTERPRETATION"
    case researchBackedKnowledge = "RESEARCH_BACKED_KNOWLEDGE"
    case professionalPracticeHeuristic = "PROFESSIONAL_PRACTICE_HEURISTIC"
    case productHeuristic = "PRODUCT_HEURISTIC"
    case currentState = "CURRENT_STATE"
    case availableCapability = "AVAILABLE_CAPABILITY"
    case knownLimitation = "KNOWN_LIMITATION"
}

public struct ModelContextSection: Codable, Equatable, Sendable {
    public var label: ModelContextLabel
    public var identifier: String
    public var content: String

    public init(label: ModelContextLabel, identifier: String, content: String) {
        self.label = label
        self.identifier = identifier
        self.content = content
    }
}

public struct ModelContextEnvelope: Codable, Equatable, Sendable {
    public var version: String
    public var sections: [ModelContextSection]
    public var utf8ByteCount: Int
    public var omittedSectionCount: Int

    public init(
        version: String = "1.0",
        sections: [ModelContextSection],
        utf8ByteCount: Int,
        omittedSectionCount: Int
    ) {
        self.version = version
        self.sections = sections
        self.utf8ByteCount = utf8ByteCount
        self.omittedSectionCount = omittedSectionCount
    }
}

public enum ConversationalReferenceKind: String, Codable, CaseIterable, Sendable {
    case preview
    case snapshot
    case priorRequest
    case productionAttribute
    case processingNode
}

public enum ReferenceMergeBehavior: String, Codable, CaseIterable, Sendable {
    case replace
    case merge
    case preserve
    case remove
    case lock
    case unlock
    case undo
    case revert
}

/// An untrusted symbolic reference. The identifier must resolve against the
/// request's explicit reference registry; prose history is never authority.
public struct ModelConversationalReference: Codable, Equatable, Sendable {
    public var kind: ConversationalReferenceKind
    public var identifier: String
    public var mergeBehavior: ReferenceMergeBehavior
    public var referencedAttribute: ProductionTerm?

    public init(
        kind: ConversationalReferenceKind,
        identifier: String,
        mergeBehavior: ReferenceMergeBehavior,
        referencedAttribute: ProductionTerm? = nil
    ) {
        self.kind = kind
        self.identifier = identifier
        self.mergeBehavior = mergeBehavior
        self.referencedAttribute = referencedAttribute
    }
}

/// Locally generated language-to-identity grounding. Aliases and summaries help
/// a provider interpret phrases such as "version two" or "the compressor", but
/// this descriptor is never authority: every emitted identifier must still
/// resolve through the registry's exact typed ID sets.
public struct ModelReferenceDescriptor: Codable, Equatable, Sendable {
    public var kind: ConversationalReferenceKind
    public var identifier: String
    public var aliases: [String]
    public var summary: String?
    public var ordinal: Int?
    public var selected: Bool
    public var locked: Bool
    public var nodeType: NodeType?
    public var parentIdentifier: String?
    public var baseIdentifier: String?
    public var resultIdentifier: String?

    public init(
        kind: ConversationalReferenceKind,
        identifier: String,
        aliases: [String] = [],
        summary: String? = nil,
        ordinal: Int? = nil,
        selected: Bool = false,
        locked: Bool = false,
        nodeType: NodeType? = nil,
        parentIdentifier: String? = nil,
        baseIdentifier: String? = nil,
        resultIdentifier: String? = nil
    ) {
        self.kind = kind
        self.identifier = identifier
        self.aliases = aliases
        self.summary = summary
        self.ordinal = ordinal
        self.selected = selected
        self.locked = locked
        self.nodeType = nodeType
        self.parentIdentifier = parentIdentifier
        self.baseIdentifier = baseIdentifier
        self.resultIdentifier = resultIdentifier
    }
}

public struct ModelReferenceRegistry: Codable, Equatable, Sendable {
    public var previewIDs: Set<UUID>
    public var snapshotIDs: Set<UUID>
    public var priorRequestIDs: Set<UUID>
    public var processingNodeIDs: Set<UUID>
    public var lockedProcessingNodeIDs: Set<UUID>
    public var productionAttributes: Set<ProductionTerm>
    public var catalog: [ModelReferenceDescriptor]

    public init(
        previewIDs: Set<UUID> = [],
        snapshotIDs: Set<UUID> = [],
        priorRequestIDs: Set<UUID> = [],
        processingNodeIDs: Set<UUID> = [],
        lockedProcessingNodeIDs: Set<UUID> = [],
        productionAttributes: Set<ProductionTerm> = Set(ProductionTerm.allCases),
        catalog: [ModelReferenceDescriptor] = []
    ) {
        self.previewIDs = previewIDs
        self.snapshotIDs = snapshotIDs
        self.priorRequestIDs = priorRequestIDs
        self.processingNodeIDs = processingNodeIDs
        self.lockedProcessingNodeIDs = lockedProcessingNodeIDs
        self.productionAttributes = productionAttributes
        self.catalog = catalog
    }

    /// Replaces processing-node reference authority with the exact graph that
    /// a conversational revision will edit. A reconciled conversation may
    /// still expose node identities from the committed AU graph while the
    /// companion is editing an uncommitted preview graph. Unioning those two
    /// identity sets makes validation broader than the resolver and can admit
    /// a committed-node UUID that does not exist in the working graph.
    ///
    /// Preview, snapshot, and prior-request authority are deliberately left
    /// unchanged. Stale processing-node descriptors are removed so descriptive
    /// context and exact authority cannot disagree.
    public mutating func replaceProcessingNodeAuthority(with nodes: [ProcessingNode]) {
        processingNodeIDs = Set(nodes.map(\.id))
        lockedProcessingNodeIDs = Set(nodes.filter(\.locked).map(\.id))
        catalog.removeAll { descriptor in
            guard descriptor.kind == .processingNode,
                  let identifier = UUID(uuidString: descriptor.identifier) else {
                return descriptor.kind == .processingNode
            }
            return !processingNodeIDs.contains(identifier)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case previewIDs, snapshotIDs, priorRequestIDs, processingNodeIDs
        case lockedProcessingNodeIDs, productionAttributes, catalog
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        previewIDs = Set(try container.decodeIfPresent([UUID].self, forKey: .previewIDs) ?? [])
        snapshotIDs = Set(try container.decodeIfPresent([UUID].self, forKey: .snapshotIDs) ?? [])
        priorRequestIDs = Set(try container.decodeIfPresent([UUID].self, forKey: .priorRequestIDs) ?? [])
        processingNodeIDs = Set(try container.decodeIfPresent([UUID].self, forKey: .processingNodeIDs) ?? [])
        lockedProcessingNodeIDs = Set(
            try container.decodeIfPresent([UUID].self, forKey: .lockedProcessingNodeIDs) ?? []
        )
        productionAttributes = Set(
            try container.decodeIfPresent([ProductionTerm].self, forKey: .productionAttributes)
                ?? ProductionTerm.allCases
        )
        catalog = try container.decodeIfPresent([ModelReferenceDescriptor].self, forKey: .catalog) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let sortedUUIDs: (Set<UUID>) -> [UUID] = {
            $0.sorted { $0.uuidString < $1.uuidString }
        }
        try container.encode(sortedUUIDs(previewIDs), forKey: .previewIDs)
        try container.encode(sortedUUIDs(snapshotIDs), forKey: .snapshotIDs)
        try container.encode(sortedUUIDs(priorRequestIDs), forKey: .priorRequestIDs)
        try container.encode(sortedUUIDs(processingNodeIDs), forKey: .processingNodeIDs)
        try container.encode(sortedUUIDs(lockedProcessingNodeIDs), forKey: .lockedProcessingNodeIDs)
        try container.encode(
            productionAttributes.sorted { $0.rawValue < $1.rawValue },
            forKey: .productionAttributes
        )
        try container.encode(catalog, forKey: .catalog)
    }
}

public struct ModelSemanticAttribute: Codable, Equatable, Sendable {
    public var term: ProductionTerm
    public var direction: ProductionIntentDirection
    public var strength: Double
    public var confidence: Double
    public var interpretation: String

    public init(
        term: ProductionTerm,
        direction: ProductionIntentDirection,
        strength: Double,
        confidence: Double,
        interpretation: String
    ) {
        self.term = term
        self.direction = direction
        self.strength = strength
        self.confidence = confidence
        self.interpretation = interpretation
    }
}

public struct ModelHypothesisProposal: Codable, Equatable, Sendable {
    public var identifier: String
    public var intendedOutcome: String
    public var strategyCategories: [ProductionDSPStrategy]
    public var relevantMetricIdentifiers: [String]
    public var risks: [String]
    public var listeningRemainsDecisive: Bool

    public init(
        identifier: String,
        intendedOutcome: String,
        strategyCategories: [ProductionDSPStrategy],
        relevantMetricIdentifiers: [String],
        risks: [String],
        listeningRemainsDecisive: Bool = true
    ) {
        self.identifier = identifier
        self.intendedOutcome = intendedOutcome
        self.strategyCategories = strategyCategories
        self.relevantMetricIdentifiers = relevantMetricIdentifiers
        self.risks = risks
        self.listeningRemainsDecisive = listeningRemainsDecisive
    }
}

/// Versioned semantic output accepted from an untrusted model. It contains no
/// executable node types, raw parameters, paths, tools, or host commands.
public struct ModelIntentContract: Codable, Equatable, Sendable {
    public var version: String
    public var sourceType: SourceType
    public var desiredChanges: [ModelSemanticAttribute]
    public var preservedAttributes: [ModelSemanticAttribute]
    public var prohibitedChanges: [ModelSemanticAttribute]
    public var uncertainty: [String]
    public var ambiguities: [String]
    public var requiresClarification: Bool
    public var clarificationQuestion: String?
    public var explicitUserAssumptions: [String]
    public var temporalScope: TimeRangeSeconds?
    public var references: [ModelConversationalReference]
    public var hypothesisProposals: [ModelHypothesisProposal]

    public init(
        version: String = "1.0",
        sourceType: SourceType,
        desiredChanges: [ModelSemanticAttribute],
        preservedAttributes: [ModelSemanticAttribute],
        prohibitedChanges: [ModelSemanticAttribute],
        uncertainty: [String],
        ambiguities: [String],
        requiresClarification: Bool,
        clarificationQuestion: String? = nil,
        explicitUserAssumptions: [String] = [],
        temporalScope: TimeRangeSeconds? = nil,
        references: [ModelConversationalReference] = [],
        hypothesisProposals: [ModelHypothesisProposal] = []
    ) {
        self.version = version
        self.sourceType = sourceType
        self.desiredChanges = desiredChanges
        self.preservedAttributes = preservedAttributes
        self.prohibitedChanges = prohibitedChanges
        self.uncertainty = uncertainty
        self.ambiguities = ambiguities
        self.requiresClarification = requiresClarification
        self.clarificationQuestion = clarificationQuestion
        self.explicitUserAssumptions = explicitUserAssumptions
        self.temporalScope = temporalScope
        self.references = references
        self.hypothesisProposals = hypothesisProposals
    }
}

public struct ModelInterpretationRequest: Codable, Equatable, Sendable {
    public var version: String
    public var requestID: UUID
    public var userRequest: String
    public var scope: ProcessingScope
    public var authority: ProductionAuthorityIdentity
    public var references: ModelReferenceRegistry
    public var context: ModelContextEnvelope
    public var budget: ProviderRequestBudget

    public init(
        version: String = "1.0",
        requestID: UUID = UUID(),
        userRequest: String,
        scope: ProcessingScope,
        authority: ProductionAuthorityIdentity,
        references: ModelReferenceRegistry,
        context: ModelContextEnvelope,
        budget: ProviderRequestBudget = .init()
    ) {
        self.version = version
        self.requestID = requestID
        self.userRequest = userRequest
        self.scope = scope
        self.authority = authority
        self.references = references
        self.context = context
        self.budget = budget
    }
}

public struct ProviderExecutionMetadata: Codable, Equatable, Sendable {
    public var providerIdentifier: String
    /// The exact model alias configured locally and bound to the provider
    /// descriptor. Validation authority uses this value.
    public var modelIdentifier: String
    /// The model identity reported by the authenticated provider response. A
    /// provider may resolve a stable alias to a dated snapshot, so this is
    /// evidence rather than local capability authority.
    public var providerReportedModelIdentifier: String?
    /// Provider response identity when supplied; a provider adapter may use a
    /// clearly prefixed local envelope fingerprint when a stateless API omits
    /// a server-side ID. The raw response is never retained for this purpose.
    public var providerResponseID: String?
    public var attemptCount: Int
    public var latencyMilliseconds: Int
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var retainedByProvider: Bool?

    public init(
        providerIdentifier: String,
        modelIdentifier: String,
        providerReportedModelIdentifier: String? = nil,
        providerResponseID: String? = nil,
        attemptCount: Int,
        latencyMilliseconds: Int,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        retainedByProvider: Bool? = nil
    ) {
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.providerReportedModelIdentifier = providerReportedModelIdentifier
        self.providerResponseID = providerResponseID
        self.attemptCount = attemptCount
        self.latencyMilliseconds = latencyMilliseconds
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.retainedByProvider = retainedByProvider
    }
}

public struct ModelInterpretationResponse: Codable, Equatable, Sendable {
    public var requestID: UUID
    public var authority: ProductionAuthorityIdentity
    public var contract: ModelIntentContract
    public var metadata: ProviderExecutionMetadata

    public init(
        requestID: UUID,
        authority: ProductionAuthorityIdentity,
        contract: ModelIntentContract,
        metadata: ProviderExecutionMetadata
    ) {
        self.requestID = requestID
        self.authority = authority
        self.contract = contract
        self.metadata = metadata
    }
}

public enum ModelProviderFailure: Error, Equatable, Sendable {
    case unavailable
    case credentialMissing
    case credentialStoreUnavailable
    case credentialRejected
    case consentRequired
    case timedOut
    case cancelled
    case network(String)
    case rateLimited(retryAfterSeconds: Double?)
    case malformedResponse(String)
    case providerRejected(String)
    case responseTooLarge
    case duplicateResponse
    case staleResult
}

public protocol ModelProvider: Sendable {
    var descriptor: ModelProviderDescriptor { get }
    func interpret(_ request: ModelInterpretationRequest) async throws -> ModelInterpretationResponse
}

public extension ModelProvider {
    var identifier: String { descriptor.identifier }
}

/// Deterministic offline regression oracle. It shares the frontier-provider
/// contract while retaining the established bounded parser and never networks.
public struct MockModelProvider: ModelProvider {
    public let descriptor = ModelProviderDescriptor(
        identifier: "mock-offline-1",
        displayName: "TrackSmith Offline",
        kind: .offline,
        modelIdentifier: "deterministic-intent-v1",
        capabilities: [.semanticIntentInterpretation, .ambiguityDetection],
        usesNetwork: false
    )

    public init() {}

    public func interpret(_ request: ModelInterpretationRequest) async throws -> ModelInterpretationResponse {
        let start = ContinuousClock.now
        let interpretation = try ProductionIntentEngine().interpret(
            request: request.userRequest,
            scope: request.scope
        )
        func semantic(_ goal: InterpretedProductionGoal) -> ModelSemanticAttribute {
            .init(
                term: goal.term,
                direction: goal.direction,
                strength: goal.strength,
                confidence: goal.confidence,
                interpretation: goal.interpretation
            )
        }
        let contract = ModelIntentContract(
            sourceType: interpretation.sourceType,
            desiredChanges: interpretation.desiredChanges.map(semantic),
            preservedAttributes: interpretation.preservedAttributes.map(semantic),
            prohibitedChanges: interpretation.prohibitedChanges.map(semantic),
            uncertainty: ["Offline interpretation is limited to the checked-in deterministic vocabulary parser."],
            ambiguities: interpretation.unresolvedAmbiguities,
            requiresClarification: interpretation.requiresClarification
        )
        let elapsed = start.duration(to: .now)
        let milliseconds = Int(elapsed.components.seconds * 1_000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        return ModelInterpretationResponse(
            requestID: request.requestID,
            authority: request.authority,
            contract: contract,
            metadata: .init(
                providerIdentifier: descriptor.identifier,
                modelIdentifier: descriptor.modelIdentifier,
                attemptCount: 1,
                latencyMilliseconds: max(0, milliseconds),
                retainedByProvider: false
            )
        )
    }

    /// Compatibility helper for the original deterministic provider surface.
    public func goals(for prompt: String, sourceType: SourceType) async throws -> [ProcessingGoal] {
        try DeterministicPlanner().parseGoals(prompt: prompt, sourceType: sourceType)
    }
}
