import AgentCore
import Foundation
import PlanSchema

public enum ModelValidationStage: String, Codable, CaseIterable, Sendable {
    case decoding
    case schema
    case semantic
    case capability
    case stateReference
    case constraint
}

public enum ModelOutputValidationError: Error, Equatable, Sendable {
    case rejected(stage: ModelValidationStage, reason: String)
}

public struct ModelValidationAudit: Codable, Equatable, Sendable {
    public var version: String
    public var requestID: UUID
    public var providerIdentifier: String
    public var completedStages: [ModelValidationStage]
    public var repairAttempted: Bool

    public init(
        version: String = "1.0",
        requestID: UUID,
        providerIdentifier: String,
        completedStages: [ModelValidationStage],
        repairAttempted: Bool = false
    ) {
        self.version = version
        self.requestID = requestID
        self.providerIdentifier = providerIdentifier
        self.completedStages = completedStages
        self.repairAttempted = repairAttempted
    }
}

public struct ValidatedModelInterpretation: Codable, Equatable, Sendable {
    public var interpretation: ProductionIntentInterpretation
    public var references: [ModelConversationalReference]
    public var hypothesisProposals: [ModelHypothesisProposal]
    public var uncertainty: [String]
    public var explicitUserAssumptions: [String]
    public var clarificationQuestion: String?
    public var metadata: ProviderExecutionMetadata
    public var audit: ModelValidationAudit

    public init(
        interpretation: ProductionIntentInterpretation,
        references: [ModelConversationalReference],
        hypothesisProposals: [ModelHypothesisProposal],
        uncertainty: [String],
        explicitUserAssumptions: [String],
        clarificationQuestion: String?,
        metadata: ProviderExecutionMetadata,
        audit: ModelValidationAudit
    ) {
        self.interpretation = interpretation
        self.references = references
        self.hypothesisProposals = hypothesisProposals
        self.uncertainty = uncertainty
        self.explicitUserAssumptions = explicitUserAssumptions
        self.clarificationQuestion = clarificationQuestion
        self.metadata = metadata
        self.audit = audit
    }
}

public struct ModelValidationEnvironment: Sendable {
    public var currentAuthority: ProductionAuthorityIdentity
    public var availableMetricIdentifiers: Set<String>
    public var supportedStrategies: Set<ProductionDSPStrategy>
    public var expectedProvider: ModelProviderDescriptor

    public init(
        currentAuthority: ProductionAuthorityIdentity,
        availableMetricIdentifiers: Set<String>,
        supportedStrategies: Set<ProductionDSPStrategy> = ModelOutputValidator.defaultSupportedStrategies,
        expectedProvider: ModelProviderDescriptor
    ) {
        self.currentAuthority = currentAuthority
        self.availableMetricIdentifiers = availableMetricIdentifiers
        self.supportedStrategies = supportedStrategies
        self.expectedProvider = expectedProvider
    }
}

/// Converts untrusted model semantics into TrackSmith-owned vocabulary entries.
/// No provider prose or hypothesis proposal is ever translated into raw DSP.
public struct ModelOutputValidator: Sendable {
    public static let maximumResponseBytes = 128_000
    public static let maximumAttributesPerCategory = 16
    public static let maximumAmbiguities = 12
    public static let maximumAssumptions = 12
    public static let maximumReferences = 24
    public static let maximumHypotheses = 6
    public static let maximumStringBytes = 2_048

    public static let defaultSupportedStrategies: Set<ProductionDSPStrategy> = [
        .subtractiveEQ, .additiveEQ, .dynamicEQOrDeEsser,
        .gentleCompression, .transientPreservingCompression, .parallelCompression,
        .levelAutomation, .saturation, .stereoWidth, .ambienceOrDelay, .preserveWithoutProcessing,
        .clarification, .listeningComparison,
    ]

    public var vocabulary: ProductionIntentVocabulary

    public init(vocabulary: ProductionIntentVocabulary = .init()) {
        self.vocabulary = vocabulary
    }

    public func validate(
        _ response: ModelInterpretationResponse,
        for request: ModelInterpretationRequest,
        environment: ModelValidationEnvironment
    ) throws -> ValidatedModelInterpretation {
        var completed: [ModelValidationStage] = [.decoding]
        try validateSchema(response, request: request, environment: environment)
        completed.append(.schema)
        var normalizedContract = normalizeCompatibleConstraintRedundancy(response.contract)
        normalizedContract = preserveExplicitDirectLevelRequest(
            in: normalizedContract,
            request: request
        )
        normalizedContract = bindUniqueExplicitUserBaseReference(
            in: normalizedContract,
            request: request
        )
        let repairAttempted = normalizedContract != response.contract
        try validateSemantics(normalizedContract, request: request)
        completed.append(.semantic)
        try validateCapabilities(normalizedContract, environment: environment)
        completed.append(.capability)
        try validateReferences(normalizedContract.references, request: request)
        completed.append(.stateReference)
        try validateConstraints(normalizedContract, request: request)
        completed.append(.constraint)

        let interpretation = trustedInterpretation(from: normalizedContract, request: request)
        return ValidatedModelInterpretation(
            interpretation: interpretation,
            references: normalizedContract.references,
            hypothesisProposals: normalizedContract.hypothesisProposals,
            uncertainty: normalizedContract.uncertainty,
            explicitUserAssumptions: normalizedContract.explicitUserAssumptions,
            clarificationQuestion: normalizedContract.clarificationQuestion,
            metadata: response.metadata,
            audit: .init(
                requestID: request.requestID,
                providerIdentifier: response.metadata.providerIdentifier,
                completedStages: completed,
                repairAttempted: repairAttempted
            )
        )
    }

    /// Applies only bounded, meaning-preserving normalizations before semantic
    /// validation. Within the explicitly prohibited bucket, an action polarity
    /// is deterministically negated (`increase` -> `doNotIncrease`, `decrease`
    /// -> `doNotDecrease`), while an explicit `preserve` attribute is moved to
    /// the preserved bucket. Logically redundant constraints are then removed
    /// when their stronger meaning is already present. This never invents an
    /// attribute, repairs an identifier, or resolves semantic ambiguity.
    private func normalizeCompatibleConstraintRedundancy(
        _ contract: ModelIntentContract
    ) -> ModelIntentContract {
        var normalized = contract

        // Cloud providers occasionally preserve the correct typed direction
        // but place the attribute in the wrong semantic bucket. Moving an
        // already-typed preserve/do-not instruction is meaning-preserving: it
        // invents neither a term nor a polarity. If the bounded destination is
        // full, leave the value where it is so semantic validation fails
        // closed instead of silently dropping a user constraint.
        let misplacedDesiredPreservations = normalized.desiredChanges.filter {
            $0.direction == .preserve
        }
        for attribute in misplacedDesiredPreservations {
            if normalized.preservedAttributes.contains(where: {
                $0.term == attribute.term && $0.direction == attribute.direction
            }) {
                normalized.desiredChanges.removeAll { $0 == attribute }
            } else if normalized.preservedAttributes.count < Self.maximumAttributesPerCategory {
                normalized.desiredChanges.removeAll { $0 == attribute }
                normalized.preservedAttributes.append(attribute)
            }
        }

        let misplacedDesiredProhibitions = normalized.desiredChanges.filter {
            $0.direction == .doNotIncrease || $0.direction == .doNotDecrease
        }
        for attribute in misplacedDesiredProhibitions {
            if normalized.prohibitedChanges.contains(where: {
                $0.term == attribute.term && $0.direction == attribute.direction
            }) {
                normalized.desiredChanges.removeAll { $0 == attribute }
            } else if normalized.prohibitedChanges.count < Self.maximumAttributesPerCategory {
                normalized.desiredChanges.removeAll { $0 == attribute }
                normalized.prohibitedChanges.append(attribute)
            }
        }

        let misplacedProhibitions = normalized.preservedAttributes.filter {
            $0.direction == .doNotIncrease || $0.direction == .doNotDecrease
        }
        for attribute in misplacedProhibitions {
            if normalized.prohibitedChanges.contains(where: {
                $0.term == attribute.term && $0.direction == attribute.direction
            }) {
                normalized.preservedAttributes.removeAll { $0 == attribute }
            } else if normalized.prohibitedChanges.count < Self.maximumAttributesPerCategory {
                normalized.preservedAttributes.removeAll { $0 == attribute }
                normalized.prohibitedChanges.append(attribute)
            }
        }
        normalized.prohibitedChanges = normalized.prohibitedChanges.map { attribute in
            var attribute = attribute
            switch attribute.direction {
            case .increase: attribute.direction = .doNotIncrease
            case .decrease: attribute.direction = .doNotDecrease
            case .preserve, .doNotIncrease, .doNotDecrease: break
            }
            return attribute
        }
        let misplacedPreservations = normalized.prohibitedChanges.filter { $0.direction == .preserve }
        for attribute in misplacedPreservations {
            if normalized.preservedAttributes.contains(where: {
                $0.term == attribute.term && $0.direction == attribute.direction
            }) {
                normalized.prohibitedChanges.removeAll { $0 == attribute }
            } else if normalized.preservedAttributes.count < Self.maximumAttributesPerCategory {
                normalized.prohibitedChanges.removeAll { $0 == attribute }
                normalized.preservedAttributes.append(attribute)
            }
        }

        let preserved = Set(normalized.preservedAttributes.map(\.term))
        let desiredWithoutPreserved = normalized.desiredChanges.filter { !preserved.contains($0.term) }
        // Prefer an explicit preservation constraint over one conflicting
        // inferred target only when another actionable target remains. A sole
        // "change and preserve X" request stays contradictory and fails.
        if !desiredWithoutPreserved.isEmpty {
            normalized.desiredChanges = desiredWithoutPreserved
        }
        let desiredDirections = Dictionary(grouping: normalized.desiredChanges, by: \.term)
            .mapValues { Set($0.map(\.direction)) }
        normalized.prohibitedChanges = normalized.prohibitedChanges.filter { prohibition in
            if preserved.contains(prohibition.term) { return false }
            let desired = desiredDirections[prohibition.term] ?? []
            if desired.contains(.increase), prohibition.direction == .doNotDecrease { return false }
            if desired.contains(.decrease), prohibition.direction == .doNotIncrease { return false }
            return true
        }
        return normalized
    }

    /// Preserves a narrow class of unambiguous user-authored gain requests
    /// against provider semantic drift. A provider may incorrectly map
    /// “turn the output down” or “pull the added level back” to compression or
    /// dynamics even though TrackSmith's contract reserves `level` for direct
    /// gain. Only USER_REQUEST text is considered here; context, metadata,
    /// measurements, prior provider output, and raw parameters are ignored.
    ///
    /// If the user also says “only,” unrelated desired changes and provider
    /// hypothesis proposals are removed. That preserves the explicit
    /// no-collateral-processing constraint rather than trusting model prose.
    private func preserveExplicitDirectLevelRequest(
        in contract: ModelIntentContract,
        request: ModelInterpretationRequest
    ) -> ModelIntentContract {
        let text = request.userRequest.lowercased()
        let directLevelLanguage = [
            "output level", "overall level", "added level", "direct level",
            "turn it down", "turn it up", "quieter", "louder",
            "lower the volume", "raise the volume", "reduce the volume",
            "increase the volume", "less volume", "more volume",
        ]
        guard directLevelLanguage.contains(where: text.contains) else { return contract }

        let decreaseLanguage = [
            "turn it down", "quieter", "lower", "reduce", "decrease",
            "pull", "back off", "less level", "less volume",
        ]
        let increaseLanguage = [
            "turn it up", "louder", "raise", "increase",
            "more level", "more volume",
        ]
        let asksForDecrease = decreaseLanguage.contains(where: text.contains)
        let asksForIncrease = increaseLanguage.contains(where: text.contains)
        guard asksForDecrease != asksForIncrease else { return contract }

        let strength: Double
        if ["slightly", "a little", "a bit", "gently"].contains(where: text.contains) {
            strength = 0.35
        } else if ["much", "a lot", "significantly", "way down", "way up"].contains(where: text.contains) {
            strength = 0.8
        } else {
            strength = 0.6
        }
        let level = ModelSemanticAttribute(
            term: .level,
            direction: asksForDecrease ? .decrease : .increase,
            strength: strength,
            confidence: 1,
            interpretation: "Explicit direct output-level change preserved from USER_REQUEST."
        )

        var normalized = contract
        if text.contains("only") {
            normalized.desiredChanges = [level]
            normalized.hypothesisProposals = []
        } else {
            normalized.desiredChanges.removeAll { $0.term == .level }
            normalized.desiredChanges.append(level)
        }
        return normalized
    }

    /// Binds only an exact, unique, user-authored whole-state reference such
    /// as “version two was closest” to a locally catalogued UUID. This does
    /// not fuzzy-match, invent a node, infer an attribute merge, alter an
    /// existing provider reference, or consult untrusted context sections.
    /// Ambiguous or malformed catalog entries remain unresolved.
    private func bindUniqueExplicitUserBaseReference(
        in contract: ModelIntentContract,
        request: ModelInterpretationRequest
    ) -> ModelIntentContract {
        guard contract.references.count < Self.maximumReferences else { return contract }
        let baseKinds: Set<ConversationalReferenceKind> = [.preview, .snapshot, .priorRequest]
        let baseBehaviors: Set<ReferenceMergeBehavior> = [.replace, .undo, .revert]
        guard !contract.references.contains(where: {
            baseKinds.contains($0.kind) && baseBehaviors.contains($0.mergeBehavior)
        }) else { return contract }

        let userText = normalizedReferenceLanguage(request.userRequest)
        guard !userText.isEmpty else { return contract }
        var matched: [ModelReferenceDescriptor] = []
        var seen = Set<String>()
        for descriptor in request.references.catalog where baseKinds.contains(descriptor.kind) {
            guard referenceExists(descriptor, in: request.references) else { continue }
            let explicitlySelected = descriptor.aliases.contains { rawAlias in
                let alias = normalizedReferenceLanguage(rawAlias)
                guard !alias.isEmpty else { return false }
                let relations = [
                    "\(alias) was closest",
                    "\(alias) was the closest",
                    "\(alias) is closest",
                    "\(alias) is the closest",
                    "go back to \(alias)",
                    "use \(alias)",
                    "restore \(alias)",
                ]
                return relations.contains { containsWordSequence($0, in: userText) }
            }
            let key = "\(descriptor.kind.rawValue)|\(descriptor.identifier.lowercased())"
            if explicitlySelected, seen.insert(key).inserted { matched.append(descriptor) }
        }
        guard matched.count == 1, let descriptor = matched.first else { return contract }
        // A provider-authored reference to this same state, including an
        // invalid unscoped merge, must still pass or fail on its own merits.
        guard !contract.references.contains(where: {
            $0.kind == descriptor.kind
                && $0.identifier.caseInsensitiveCompare(descriptor.identifier) == .orderedSame
        }) else { return contract }

        var normalized = contract
        normalized.references.append(.init(
            kind: descriptor.kind,
            identifier: descriptor.identifier,
            mergeBehavior: .replace
        ))
        return normalized
    }

    private func normalizedReferenceLanguage(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func containsWordSequence(_ phrase: String, in text: String) -> Bool {
        " \(text) ".contains(" \(phrase) ")
    }

    private func referenceExists(
        _ descriptor: ModelReferenceDescriptor,
        in registry: ModelReferenceRegistry
    ) -> Bool {
        guard let identifier = UUID(uuidString: descriptor.identifier) else { return false }
        return switch descriptor.kind {
        case .preview: registry.previewIDs.contains(identifier)
        case .snapshot: registry.snapshotIDs.contains(identifier)
        case .priorRequest: registry.priorRequestIDs.contains(identifier)
        case .processingNode: registry.processingNodeIDs.contains(identifier)
        case .productionAttribute: false
        }
    }

    private func validateSchema(
        _ response: ModelInterpretationResponse,
        request: ModelInterpretationRequest,
        environment: ModelValidationEnvironment
    ) throws {
        let size = (try? JSONEncoder().encode(response).count) ?? Int.max
        guard size <= Self.maximumResponseBytes else {
            throw reject(.schema, "The decoded provider response exceeds the local byte limit.")
        }
        guard request.version == "1.0", response.contract.version == "1.0" else {
            throw reject(.schema, "Unsupported provider contract version.")
        }
        guard response.requestID == request.requestID else {
            throw reject(.schema, "The provider response belongs to a different request.")
        }
        guard response.authority == request.authority,
              response.authority == environment.currentAuthority else {
            throw reject(.schema, "The provider response authority is stale or belongs to a different runtime/capture.")
        }
        guard response.metadata.providerIdentifier == environment.expectedProvider.identifier,
              response.metadata.modelIdentifier == environment.expectedProvider.modelIdentifier else {
            throw reject(.schema, "Provider or model identity does not match the selected adapter.")
        }
        if let reportedModel = response.metadata.providerReportedModelIdentifier,
           !isSafeProviderMetadataIdentifier(reportedModel, maximumUTF8Bytes: 128) {
            throw reject(.schema, "The provider-reported model identity is malformed or unbounded.")
        }
        if let responseID = response.metadata.providerResponseID,
           !isSafeProviderMetadataIdentifier(responseID, maximumUTF8Bytes: 256) {
            throw reject(.schema, "The provider response identity is malformed or unbounded.")
        }
        let reportedTokens = [response.metadata.inputTokens, response.metadata.outputTokens].compactMap { $0 }
        guard reportedTokens.allSatisfy({ (0...10_000_000).contains($0) }) else {
            throw reject(.schema, "Provider token metadata is negative or unbounded.")
        }
        let maximumLatencyMilliseconds = Int(request.budget.timeoutSeconds * 1_000) + 5_000
        guard response.metadata.attemptCount >= 1,
              response.metadata.attemptCount <= request.budget.maxAttempts,
              response.metadata.latencyMilliseconds >= 0,
              response.metadata.latencyMilliseconds <= maximumLatencyMilliseconds else {
            throw reject(.schema, "Provider attempt or latency metadata is outside the request budget.")
        }
        guard response.contract.sourceType == request.scope.sourceType else {
            throw reject(.schema, "The provider changed the explicit source class.")
        }
        guard response.contract.desiredChanges.count <= Self.maximumAttributesPerCategory,
              response.contract.preservedAttributes.count <= Self.maximumAttributesPerCategory,
              response.contract.prohibitedChanges.count <= Self.maximumAttributesPerCategory,
              response.contract.ambiguities.count <= Self.maximumAmbiguities,
              response.contract.explicitUserAssumptions.count <= Self.maximumAssumptions,
              response.contract.references.count <= Self.maximumReferences,
              response.contract.hypothesisProposals.count <= Self.maximumHypotheses else {
            throw reject(.schema, "One or more provider arrays exceed their deterministic bounds.")
        }
    }

    /// Provider metadata is persisted and may be displayed or exported as
    /// evidence. Permit bounded visible ASCII so dated model paths remain
    /// representable while control characters and multiline log injection fail
    /// closed. This field never grants model or processing authority.
    private func isSafeProviderMetadataIdentifier(
        _ value: String,
        maximumUTF8Bytes: Int
    ) -> Bool {
        let bytes = value.utf8
        guard !bytes.isEmpty, bytes.count <= maximumUTF8Bytes else { return false }
        return bytes.allSatisfy { (0x21...0x7e).contains($0) }
    }

    private func validateSemantics(
        _ contract: ModelIntentContract,
        request: ModelInterpretationRequest
    ) throws {
        for attribute in contract.desiredChanges {
            guard attribute.direction == .increase || attribute.direction == .decrease else {
                throw reject(.semantic, "Desired attributes must increase or decrease.")
            }
            try validate(attribute, sourceType: request.scope.sourceType)
        }
        for attribute in contract.preservedAttributes {
            guard attribute.direction == .preserve else {
                throw reject(.semantic, "Preserved attributes must use the preserve direction.")
            }
            try validate(attribute, sourceType: request.scope.sourceType)
        }
        for attribute in contract.prohibitedChanges {
            guard attribute.direction == .doNotIncrease || attribute.direction == .doNotDecrease else {
                throw reject(.semantic, "Prohibited attributes must use a do-not direction.")
            }
            try validate(attribute, sourceType: request.scope.sourceType)
        }
        for text in contract.uncertainty + contract.ambiguities + contract.explicitUserAssumptions {
            try validateBoundedText(text, stage: .semantic)
        }
        if let question = contract.clarificationQuestion {
            try validateBoundedText(question, stage: .semantic)
        }
        guard !contract.desiredChanges.isEmpty || !contract.references.isEmpty || contract.requiresClarification else {
            throw reject(.semantic, "The response contains no actionable change or typed reference and did not request clarification.")
        }
        if let temporal = contract.temporalScope {
            guard temporal.start.isFinite, temporal.end.isFinite,
                  temporal.start >= 0, temporal.end > temporal.start else {
                throw reject(.semantic, "The temporal scope is invalid.")
            }
            if let available = request.scope.timeRangeSeconds,
               temporal.start < available.start || temporal.end > available.end {
                throw reject(.semantic, "The temporal scope exceeds the captured material.")
            }
        }
    }

    private func validate(
        _ attribute: ModelSemanticAttribute,
        sourceType: SourceType
    ) throws {
        guard attribute.strength.isFinite, (0...1).contains(attribute.strength),
              attribute.confidence.isFinite, (0...1).contains(attribute.confidence) else {
            throw reject(.semantic, "Attribute strength or confidence is outside 0...1.")
        }
        try validateBoundedText(attribute.interpretation, stage: .semantic)
        let definition = vocabulary.definition(for: attribute.term)
        guard definition.applicableSourceTypes.contains(sourceType) else {
            throw reject(.semantic, "Attribute \(attribute.term.rawValue) is not supported for \(sourceType.rawValue).")
        }
    }

    private func validateCapabilities(
        _ contract: ModelIntentContract,
        environment: ModelValidationEnvironment
    ) throws {
        if !contract.references.isEmpty,
           !environment.expectedProvider.capabilities.contains(.conversationalReferenceInterpretation) {
            throw reject(.capability, "The selected provider did not declare conversational-reference capability.")
        }
        if !contract.hypothesisProposals.isEmpty,
           !environment.expectedProvider.capabilities.contains(.productionHypothesisGeneration) {
            throw reject(.capability, "The selected provider did not declare production-hypothesis capability.")
        }
        for hypothesis in contract.hypothesisProposals {
            try validateBoundedText(hypothesis.identifier, stage: .capability)
            try validateBoundedText(hypothesis.intendedOutcome, stage: .capability)
            for risk in hypothesis.risks { try validateBoundedText(risk, stage: .capability) }
            guard Set(hypothesis.strategyCategories).isSubset(of: environment.supportedStrategies) else {
                throw reject(.capability, "A hypothesis requests a strategy unavailable to the deterministic engine.")
            }
            guard Set(hypothesis.relevantMetricIdentifiers).isSubset(of: environment.availableMetricIdentifiers) else {
                throw reject(.capability, "A hypothesis invented or referenced an unavailable measurement.")
            }
        }
    }

    private func validateReferences(
        _ references: [ModelConversationalReference],
        request: ModelInterpretationRequest
    ) throws {
        for reference in references {
            try validateBoundedText(reference.identifier, stage: .stateReference)
            // Every accepted reference/verb pair must correspond to an
            // implemented deterministic resolver transition. In particular,
            // a preview merge is meaningful only when it names the one
            // production attribute to import; an unscoped merge must not pass
            // validation and fail later in graph construction.
            switch reference.kind {
            case .preview:
                switch reference.mergeBehavior {
                case .merge:
                    guard reference.referencedAttribute != nil else {
                        throw reject(.stateReference, "A preview merge requires an explicit production attribute.")
                    }
                case .replace, .undo, .revert:
                    guard reference.referencedAttribute == nil else {
                        throw reject(.stateReference, "A whole-preview replacement cannot also name an attribute merge.")
                    }
                case .preserve, .remove, .lock, .unlock:
                    throw reject(.stateReference, "The requested preview reference action is not implemented.")
                }
            case .snapshot, .priorRequest:
                guard [.replace, .undo, .revert].contains(reference.mergeBehavior),
                      reference.referencedAttribute == nil else {
                    throw reject(.stateReference, "Snapshot and prior-request references support only whole-state replacement, undo, or revert.")
                }
            case .productionAttribute:
                guard [.preserve, .lock, .remove].contains(reference.mergeBehavior),
                      reference.referencedAttribute == nil else {
                    throw reject(.stateReference, "The requested production-attribute reference action is not implemented.")
                }
            case .processingNode:
                guard [.preserve, .lock, .unlock, .remove, .undo, .revert].contains(reference.mergeBehavior),
                      reference.referencedAttribute == nil else {
                    throw reject(.stateReference, "The requested processing-node reference action is not implemented.")
                }
            }
            if let attribute = reference.referencedAttribute,
               !request.references.productionAttributes.contains(attribute) {
                throw reject(.stateReference, "The provider associated a reference with an unknown production attribute.")
            }
            switch reference.kind {
            case .productionAttribute:
                guard let term = ProductionTerm(rawValue: reference.identifier),
                      request.references.productionAttributes.contains(term) else {
                    throw reject(.stateReference, "The provider referenced an unknown production attribute.")
                }
            case .preview, .snapshot, .priorRequest, .processingNode:
                guard let identifier = UUID(uuidString: reference.identifier) else {
                    throw reject(.stateReference, "A provider state reference is not a valid typed identity.")
                }
                let exists: Bool = switch reference.kind {
                case .preview: request.references.previewIDs.contains(identifier)
                case .snapshot: request.references.snapshotIDs.contains(identifier)
                case .priorRequest: request.references.priorRequestIDs.contains(identifier)
                case .processingNode: request.references.processingNodeIDs.contains(identifier)
                case .productionAttribute: false
                }
                guard exists else {
                    throw reject(.stateReference, "The provider referenced state that does not exist in this conversation/runtime.")
                }
                if reference.kind == .processingNode,
                   request.references.lockedProcessingNodeIDs.contains(identifier),
                   [.replace, .remove, .undo, .revert].contains(reference.mergeBehavior) {
                    throw reject(.stateReference, "The provider attempted to modify or remove a locked processing node.")
                }
                if reference.mergeBehavior == .unlock,
                   !request.userRequest.lowercased().contains("unlock") {
                    throw reject(.stateReference, "The provider inferred an unlock that the user did not explicitly request.")
                }
            }
        }
    }

    private func validateConstraints(
        _ contract: ModelIntentContract,
        request: ModelInterpretationRequest
    ) throws {
        let desired = Dictionary(grouping: contract.desiredChanges, by: \.term)
        for (term, attributes) in desired {
            let directions = Set(attributes.map(\.direction))
            if directions.contains(.increase), directions.contains(.decrease) {
                throw reject(.constraint, "The response both increases and decreases \(term.rawValue).")
            }
        }
        let preserved = Set(contract.preservedAttributes.map(\.term))
        let prohibited = Set(contract.prohibitedChanges.map(\.term))
        let changed = Set(contract.desiredChanges.map(\.term))
        let changedAndPreserved = changed.intersection(preserved).map(\.rawValue).sorted()
        guard changedAndPreserved.isEmpty else {
            throw reject(
                .constraint,
                "The response changes and preserves the same attribute(s): \(changedAndPreserved.joined(separator: ", "))."
            )
        }
        let changedAndProhibited = changed.intersection(prohibited).map(\.rawValue).sorted()
        guard changedAndProhibited.isEmpty else {
            throw reject(
                .constraint,
                "The response requests and prohibits conflicting direction(s) for: \(changedAndProhibited.joined(separator: ", "))."
            )
        }
        guard preserved.isDisjoint(with: prohibited) else {
            throw reject(
                .constraint,
                "The response repeats an unchanged attribute as both preserved and prohibited; preservation must be represented once."
            )
        }
        let prohibitedDirections = Dictionary(grouping: contract.prohibitedChanges, by: \.term)
        for (term, attributes) in prohibitedDirections {
            let directions = Set(attributes.map(\.direction))
            guard !(directions.contains(.doNotIncrease) && directions.contains(.doNotDecrease)) else {
                throw reject(
                    .constraint,
                    "The response prohibits both directions for \(term.rawValue); an unchanged attribute must be represented as preserved."
                )
            }
        }
        guard !contract.requiresClarification || contract.clarificationQuestion != nil || !contract.ambiguities.isEmpty else {
            throw reject(.constraint, "Clarification was requested without a question or stated ambiguity.")
        }
        if contract.references.contains(where: { $0.mergeBehavior == .unlock }),
           !request.userRequest.lowercased().contains("unlock") {
            throw reject(.constraint, "An implicit unlock is forbidden.")
        }
    }

    private func trustedInterpretation(
        from contract: ModelIntentContract,
        request: ModelInterpretationRequest
    ) -> ProductionIntentInterpretation {
        func trusted(_ attribute: ModelSemanticAttribute) -> InterpretedProductionGoal {
            let definition = vocabulary.definition(for: attribute.term)
            let sourceInterpretation = vocabulary.interpretations(
                for: attribute.term,
                sourceType: request.scope.sourceType
            ).first?.possibleAcousticInterpretation
                ?? "This term is context-dependent and has no unique acoustic mapping."
            return InterpretedProductionGoal(
                term: attribute.term,
                matchedPhrase: attribute.term.rawValue,
                direction: attribute.direction,
                strength: attribute.strength,
                sourceType: request.scope.sourceType,
                interpretation: sourceInterpretation,
                confidence: min(attribute.confidence, definition.confidence),
                evidenceClass: definition.evidenceClass,
                provenance: definition.provenance
            )
        }
        return ProductionIntentInterpretation(
            originalRequest: request.userRequest,
            sourceType: request.scope.sourceType,
            desiredChanges: contract.desiredChanges.map(trusted),
            preservedAttributes: contract.preservedAttributes.map(trusted),
            prohibitedChanges: contract.prohibitedChanges.map(trusted),
            unresolvedAmbiguities: contract.ambiguities + contract.uncertainty,
            requiresClarification: contract.requiresClarification
        )
    }

    private func validateBoundedText(
        _ value: String,
        stage: ModelValidationStage
    ) throws {
        guard !value.isEmpty, value.utf8.count <= Self.maximumStringBytes else {
            throw reject(stage, "Provider text is empty or exceeds the local byte limit.")
        }
        guard value.unicodeScalars.allSatisfy({
            $0.value == 9 || $0.value == 10 || $0.value == 13 || $0.value >= 32
        }) else {
            throw reject(stage, "Provider text contains disallowed control characters.")
        }
    }

    private func reject(_ stage: ModelValidationStage, _ reason: String) -> ModelOutputValidationError {
        .rejected(stage: stage, reason: reason)
    }
}
