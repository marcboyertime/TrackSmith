import AgentCore
import Foundation
import PlanSchema

public enum ConversationalRevisionError: Error, Equatable, Sendable {
    case historicalStateHasNoAuthority
    case noReferences
    case referenceNotFound(String)
    case ambiguousBaseReplacement
    case unsupportedMerge(String)
    case lockedNode(UUID)
    case sourceAuthorityMismatch
}

public struct ConversationalRevisionResolution: Codable, Equatable, Sendable {
    public var version: String
    public var plan: ProcessingPlan
    public var appliedReferences: [ModelConversationalReference]
    public var preservedAttributes: [ProductionTerm]
    public var prohibitedAttributes: [ProductionTerm]
    public var explanation: [String]

    public init(
        version: String = "1.0",
        plan: ProcessingPlan,
        appliedReferences: [ModelConversationalReference],
        preservedAttributes: [ProductionTerm],
        prohibitedAttributes: [ProductionTerm],
        explanation: [String]
    ) {
        self.version = version
        self.plan = plan
        self.appliedReferences = appliedReferences
        self.preservedAttributes = preservedAttributes
        self.prohibitedAttributes = prohibitedAttributes
        self.explanation = explanation
    }
}

/// Resolves model-interpreted references against typed local identities. It
/// never consults free-form chat history and never sends a state transition to
/// the AU. Its result remains a normal ProcessingPlan requiring render and
/// PlanValidator gates before commit.
public struct ConversationalRevisionResolver: Sendable {
    public init() {}

    public func resolve(
        _ validated: ValidatedModelInterpretation,
        conversation: ReconciledConversationState,
        currentPlan: ProcessingPlan
    ) throws -> ConversationalRevisionResolution {
        guard conversation.authorityStatus == .liveAuthoritative else {
            throw ConversationalRevisionError.historicalStateHasNoAuthority
        }
        let references = validated.references
        guard !references.isEmpty else { throw ConversationalRevisionError.noReferences }
        guard currentPlan.sourceSnapshotID == conversation.state.authorityBinding?.captureSnapshotID else {
            throw ConversationalRevisionError.sourceAuthorityMismatch
        }

        let baseReferences = references.filter {
            [.preview, .snapshot, .priorRequest].contains($0.kind)
                && [.replace, .revert, .undo].contains($0.mergeBehavior)
        }
        guard baseReferences.count <= 1 else { throw ConversationalRevisionError.ambiguousBaseReplacement }

        var candidate = currentPlan
        var explanations: [String] = []
        if let base = baseReferences.first {
            candidate = try plan(for: base, state: conversation.state)
            try restoreLockedNodes(from: currentPlan, into: &candidate)
            explanations.append("Restored the exact typed \(base.kind.rawValue) reference while retaining every currently locked node.")
        }

        for reference in references where reference.mergeBehavior == .merge {
            guard reference.kind == .preview,
                  let attribute = reference.referencedAttribute,
                  let previewID = UUID(uuidString: reference.identifier),
                  let preview = conversation.state.previews.first(where: { $0.id == previewID }) else {
                throw ConversationalRevisionError.unsupportedMerge(
                    "A merge requires one existing preview and an explicit production attribute."
                )
            }
            try merge(
                attribute: attribute,
                from: preview.plan,
                into: &candidate,
                preserving: currentPlan
            )
            explanations.append("Merged only the \(attribute.rawValue) processing family from preview \(previewID.uuidString).")
        }

        var preserved = Set(validated.interpretation.preservedAttributes.map(\.term))
        var prohibited = Set(validated.interpretation.prohibitedChanges.map(\.term))
        for reference in references {
            switch reference.kind {
            case .processingNode:
                try applyNodeReference(
                    reference,
                    state: conversation.state,
                    currentPlan: currentPlan,
                    candidate: &candidate,
                    explanations: &explanations
                )
            case .productionAttribute:
                guard let term = ProductionTerm(rawValue: reference.identifier) else {
                    throw ConversationalRevisionError.referenceNotFound(reference.identifier)
                }
                switch reference.mergeBehavior {
                case .preserve, .lock: preserved.insert(term)
                case .remove: prohibited.insert(term)
                default: break
                }
            case .preview, .snapshot, .priorRequest:
                break
            }
        }

        candidate.requestID = UUID()
        candidate.goals = mergedGoals(
            candidate.goals,
            preservation: preserved,
            prohibited: prohibited,
            sourceInterpretation: validated.interpretation
        )
        try PlanValidator().validateForRealtimeActivation(
            candidate,
            currentSnapshotID: currentPlan.sourceSnapshotID,
            basePlan: currentPlan
        )
        return ConversationalRevisionResolution(
            plan: candidate,
            appliedReferences: references,
            preservedAttributes: preserved.sorted { $0.rawValue < $1.rawValue },
            prohibitedAttributes: prohibited.sorted { $0.rawValue < $1.rawValue },
            explanation: explanations
        )
    }

    private func plan(
        for reference: ModelConversationalReference,
        state: ProductionConversationState
    ) throws -> ProcessingPlan {
        guard let id = UUID(uuidString: reference.identifier) else {
            throw ConversationalRevisionError.referenceNotFound(reference.identifier)
        }
        switch reference.kind {
        case .preview:
            guard let plan = state.previews.first(where: { $0.id == id })?.plan else {
                throw ConversationalRevisionError.referenceNotFound(reference.identifier)
            }
            return plan
        case .snapshot:
            guard let plan = state.snapshots.first(where: { $0.id == id })?.plan else {
                throw ConversationalRevisionError.referenceNotFound(reference.identifier)
            }
            return plan
        case .priorRequest:
            guard let revision = state.revisions.last(where: { $0.turnID == id }),
                  let plan = state.snapshots.first(where: { $0.id == revision.resultSnapshotID })?.plan else {
                throw ConversationalRevisionError.referenceNotFound(reference.identifier)
            }
            return plan
        case .productionAttribute, .processingNode:
            throw ConversationalRevisionError.unsupportedMerge("This reference cannot replace a complete graph.")
        }
    }

    private func restoreLockedNodes(
        from current: ProcessingPlan,
        into candidate: inout ProcessingPlan
    ) throws {
        guard candidate.sourceSnapshotID == current.sourceSnapshotID,
              candidate.scope == current.scope else {
            throw ConversationalRevisionError.sourceAuthorityMismatch
        }
        for locked in current.nodes where locked.locked {
            if let index = candidate.nodes.firstIndex(where: { $0.id == locked.id }) {
                candidate.nodes[index] = locked
            } else {
                insertBeforeSafetyLimiter(locked, into: &candidate.nodes)
            }
        }
    }

    private func merge(
        attribute: ProductionTerm,
        from source: ProcessingPlan,
        into candidate: inout ProcessingPlan,
        preserving current: ProcessingPlan
    ) throws {
        guard source.sourceSnapshotID == current.sourceSnapshotID,
              source.scope == current.scope else {
            throw ConversationalRevisionError.sourceAuthorityMismatch
        }
        let types = nodeTypes(for: attribute)
        guard !types.isEmpty else {
            throw ConversationalRevisionError.unsupportedMerge(attribute.rawValue)
        }
        candidate.nodes.removeAll { node in
            types.contains(node.type) && !node.locked && node.type != .limiter
        }
        for node in source.nodes where types.contains(node.type) && node.type != .limiter {
            if let locked = current.nodes.first(where: { $0.id == node.id && $0.locked }) {
                if !candidate.nodes.contains(where: { $0.id == locked.id }) {
                    insertBeforeSafetyLimiter(locked, into: &candidate.nodes)
                }
            } else {
                var merged = node
                if candidate.nodes.contains(where: { $0.id == merged.id }) { merged.id = UUID() }
                insertBeforeSafetyLimiter(merged, into: &candidate.nodes)
            }
        }
        try restoreLockedNodes(from: current, into: &candidate)
    }

    private func applyNodeReference(
        _ reference: ModelConversationalReference,
        state: ProductionConversationState,
        currentPlan: ProcessingPlan,
        candidate: inout ProcessingPlan,
        explanations: inout [String]
    ) throws {
        guard let id = UUID(uuidString: reference.identifier),
              let currentNode = currentPlan.nodes.first(where: { $0.id == id }) else {
            throw ConversationalRevisionError.referenceNotFound(reference.identifier)
        }
        switch reference.mergeBehavior {
        case .preserve, .lock:
            if let index = candidate.nodes.firstIndex(where: { $0.id == id }) {
                candidate.nodes[index] = currentNode
                candidate.nodes[index].locked = true
            } else {
                var retained = currentNode
                retained.locked = true
                insertBeforeSafetyLimiter(retained, into: &candidate.nodes)
            }
            explanations.append("Preserved and locked \(currentNode.type.rawValue) node \(id.uuidString).")
        case .unlock:
            guard let index = candidate.nodes.firstIndex(where: { $0.id == id }) else {
                throw ConversationalRevisionError.referenceNotFound(reference.identifier)
            }
            candidate.nodes[index].locked = false
            explanations.append("Explicitly unlocked \(currentNode.type.rawValue) node \(id.uuidString).")
        case .remove:
            guard !currentNode.locked else { throw ConversationalRevisionError.lockedNode(id) }
            candidate.nodes.removeAll { $0.id == id }
            explanations.append("Removed the explicitly referenced \(currentNode.type.rawValue) node.")
        case .undo, .revert:
            guard !currentNode.locked else { throw ConversationalRevisionError.lockedNode(id) }
            guard let prior = priorVersion(of: id, before: currentNode, snapshots: state.snapshots) else {
                throw ConversationalRevisionError.referenceNotFound("prior node version \(id.uuidString)")
            }
            if let index = candidate.nodes.firstIndex(where: { $0.id == id }) {
                candidate.nodes[index] = prior
            } else {
                insertBeforeSafetyLimiter(prior, into: &candidate.nodes)
            }
            explanations.append("Restored the most recent historical version of \(currentNode.type.rawValue) node \(id.uuidString).")
        case .replace, .merge:
            break
        }
    }

    private func priorVersion(
        of nodeID: UUID,
        before current: ProcessingNode,
        snapshots: [ConversationSnapshotRecord]
    ) -> ProcessingNode? {
        snapshots.sorted { $0.createdAt > $1.createdAt }
            .compactMap { $0.plan?.nodes.first(where: { $0.id == nodeID }) }
            .first(where: { $0 != current })
    }

    private func insertBeforeSafetyLimiter(
        _ node: ProcessingNode,
        into nodes: inout [ProcessingNode]
    ) {
        if let limiter = nodes.lastIndex(where: { $0.enabled && $0.type == .limiter }) {
            nodes.insert(node, at: limiter)
        } else {
            nodes.append(node)
        }
    }

    private func mergedGoals(
        _ existing: [ProcessingGoal],
        preservation: Set<ProductionTerm>,
        prohibited: Set<ProductionTerm>,
        sourceInterpretation: ProductionIntentInterpretation
    ) -> [ProcessingGoal] {
        var goals = existing
        for term in preservation {
            appendGoal(
                .init(attribute: schemaAttribute(for: term), direction: .preserve, strength: 1, locked: true),
                to: &goals
            )
        }
        for term in prohibited {
            let interpreted = sourceInterpretation.prohibitedChanges.first(where: { $0.term == term })
            let direction: GoalDirection = interpreted?.direction == .doNotDecrease ? .doNotDecrease : .doNotIncrease
            appendGoal(
                .init(attribute: schemaAttribute(for: term), direction: direction, strength: 1, locked: true),
                to: &goals
            )
        }
        return goals
    }

    private func appendGoal(_ goal: ProcessingGoal, to goals: inout [ProcessingGoal]) {
        if let index = goals.firstIndex(where: { $0.attribute == goal.attribute && $0.direction == goal.direction }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
    }

    private func nodeTypes(for term: ProductionTerm) -> Set<NodeType> {
        switch term {
        case .warm, .vintage: [.saturation, .parametricEQ, .lowPass]
        case .bright, .dark, .airy, .harsh, .sibilant, .cymbalHarshness, .modern:
            [.parametricEQ, .lowPass, .deEsser]
        case .clear, .muddy, .boxy, .thin, .boomy:
            [.parametricEQ, .highPass, .lowPass]
        case .punchy, .energetic, .aggressive, .pickAttack:
            [.compressor, .parametricEQ, .saturation]
        case .intimate, .distant, .forward:
            [.compressor, .parametricEQ]
        case .level:
            [.inputTrim, .outputTrim]
        case .polished, .raw, .smooth, .controlled, .dynamic, .tight, .soft:
            [.compressor, .saturation, .parametricEQ]
        case .wide, .narrow, .monoCompatibility:
            [.stereoWidth, .midSideEQ]
        case .lowEndWeight:
            [.parametricEQ, .highPass]
        }
    }

    private func schemaAttribute(for term: ProductionTerm) -> GoalAttribute {
        switch term {
        case .warm, .vintage: .warmth
        case .bright, .dark, .airy, .modern: .brightness
        case .clear, .polished: .clarity
        case .muddy, .boxy, .thin, .boomy: .muddiness
        case .harsh: .harshness
        case .sibilant: .sibilance
        case .punchy, .aggressive, .energetic, .pickAttack: .punch
        case .intimate, .distant, .forward: .closeness
        case .level: .loudness
        case .raw, .smooth, .controlled, .dynamic, .tight, .soft: .dynamicControl
        case .wide, .narrow, .monoCompatibility: .width
        case .lowEndWeight: .lowEnd
        case .cymbalHarshness: .cymbalHarshness
        }
    }
}
