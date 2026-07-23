import AgentCore
import Foundation
import PlanSchema

public enum ProductionRevisionError: Error, Equatable, Sendable {
    case noActionableRevision
    case missingDeterministicCandidate
    case unsupportedSemanticChange([ProductionTerm])
}

public struct ProductionRevisionResolution: Codable, Equatable, Sendable {
    public var version: String
    public var plan: ProcessingPlan
    public var appliedReferences: [ModelConversationalReference]
    public var preservedAttributes: [ProductionTerm]
    public var prohibitedAttributes: [ProductionTerm]
    public var explanation: [String]
    public var audioMayChange: Bool

    public init(
        version: String = "1.0",
        plan: ProcessingPlan,
        appliedReferences: [ModelConversationalReference],
        preservedAttributes: [ProductionTerm],
        prohibitedAttributes: [ProductionTerm],
        explanation: [String],
        audioMayChange: Bool
    ) {
        self.version = version
        self.plan = plan
        self.appliedReferences = appliedReferences
        self.preservedAttributes = preservedAttributes
        self.prohibitedAttributes = prohibitedAttributes
        self.explanation = explanation
        self.audioMayChange = audioMayChange
    }
}

/// Converts a validated conversational interpretation into a new working
/// graph. Model output never supplies a node or parameter: semantic additions
/// come from AgentCore's deterministic candidate, semantic reductions move
/// existing TrackSmith controls toward their neutral values, and exact state
/// references are resolved by `ConversationalRevisionResolver` first.
public struct ProductionRevisionCoordinator: Sendable {
    public init() {}

    public func revise(
        outcome: ProductionIntelligenceOutcome,
        conversation: ReconciledConversationState,
        currentPlan: ProcessingPlan
    ) throws -> ProductionRevisionResolution {
        let validated = outcome.validatedInterpretation
        let interpretation = validated.interpretation
        guard !validated.references.isEmpty || !interpretation.desiredChanges.isEmpty else {
            throw ProductionRevisionError.noActionableRevision
        }

        var plan = currentPlan
        var explanation: [String] = []
        var preserved = Set(interpretation.preservedAttributes.map(\.term))
        var prohibited = Set(interpretation.prohibitedChanges.map(\.term))
        if !validated.references.isEmpty {
            let referenceResolution = try ConversationalRevisionResolver().resolve(
                validated,
                conversation: conversation,
                currentPlan: currentPlan
            )
            plan = referenceResolution.plan
            explanation += referenceResolution.explanation
            preserved.formUnion(referenceResolution.preservedAttributes)
            prohibited.formUnion(referenceResolution.prohibitedAttributes)
        }

        if !interpretation.desiredChanges.isEmpty {
            guard let deterministic = outcome.productionResult.hypotheses.first?
                .candidatePlans.first(where: { $0.strength == .balanced })?.plan else {
                throw ProductionRevisionError.missingDeterministicCandidate
            }
            guard deterministic.sourceSnapshotID == currentPlan.sourceSnapshotID,
                  deterministic.scope == currentPlan.scope else {
                throw ConversationalRevisionError.sourceAuthorityMismatch
            }
            let candidateTypes = Set(deterministic.nodes.compactMap { node -> NodeType? in
                guard node.type != .limiter, node.type != .loudnessMatch else { return nil }
                return node.type
            })
            let increaseTypes = interpretation.desiredChanges
                .filter { $0.direction == .increase }
                .reduce(into: Set<NodeType>()) { result, goal in
                    result.formUnion(nodeTypes(for: goal))
                }
            let decreaseTypes = interpretation.desiredChanges
                .filter { $0.direction == .decrease }
                .reduce(into: Set<NodeType>()) { result, goal in
                    result.formUnion(nodeTypes(for: goal))
                }
            // A simultaneous explicit reduction owns its processor family. A
            // generative candidate must never replace the user's current
            // compressor with a newly generated compressor while interpreting
            // “use less compression,” even if another adjective such as
            // “forward” could also be served by compression.
            let generatedTypes = candidateTypes
                .intersection(increaseTypes)
                .subtracting(decreaseTypes)
            if !generatedTypes.isEmpty {
                plan.nodes.removeAll { node in
                    generatedTypes.contains(node.type)
                        && !node.locked
                        && node.type != .limiter
                        && node.type != .loudnessMatch
                }
                for sourceNode in deterministic.nodes where generatedTypes.contains(sourceNode.type) {
                    var inserted = sourceNode
                    inserted.id = UUID()
                    insertBeforeSafetyLimiter(inserted, into: &plan.nodes)
                }
                explanation.append(
                    "Applied only TrackSmith-owned deterministic node families selected by the validated semantic change: \(generatedTypes.map(\.rawValue).sorted().joined(separator: ", "))."
                )
            }

            var unsupported: [ProductionTerm] = []
            var appliedSemanticChange = !generatedTypes.isEmpty
            for goal in interpretation.desiredChanges {
                switch goal.direction {
                case .decrease:
                    let changed = neutralize(
                        nodeTypes: nodeTypes(for: goal),
                        amount: goal.strength,
                        in: &plan
                    )
                    if changed {
                        appliedSemanticChange = true
                        explanation.append(
                            "Reduced the existing \(goal.term.rawValue) processing family toward its documented neutral controls; locked nodes remained exact."
                        )
                    } else {
                        unsupported.append(goal.term)
                    }
                case .increase:
                    if generatedTypes.isDisjoint(with: nodeTypes(for: goal)) {
                        unsupported.append(goal.term)
                    }
                case .preserve, .doNotIncrease, .doNotDecrease:
                    break
                }
            }
            let uniqueUnsupported = Array(Set(unsupported)).sorted { $0.rawValue < $1.rawValue }
            if !uniqueUnsupported.isEmpty {
                // Partial execution is allowed only when another validated
                // semantic or typed-reference action remains useful. The
                // unsupported remainder stays explicit and acquires no DSP.
                guard appliedSemanticChange || !validated.references.isEmpty else {
                    throw ProductionRevisionError.unsupportedSemanticChange(uniqueUnsupported)
                }
                explanation.append(
                    "Left unsupported semantic changes unapplied: \(uniqueUnsupported.map(\.rawValue).joined(separator: ", ")). No processing authority was invented for them."
                )
            }
            mergeGoals(from: deterministic, into: &plan)
        }

        plan.requestID = UUID()
        try restoreLockedNodes(from: currentPlan, into: &plan)
        try PlanValidator().validateForRealtimeActivation(
            plan,
            currentSnapshotID: currentPlan.sourceSnapshotID,
            basePlan: currentPlan
        )
        return ProductionRevisionResolution(
            plan: plan,
            appliedReferences: validated.references,
            preservedAttributes: preserved.sorted { $0.rawValue < $1.rawValue },
            prohibitedAttributes: prohibited.sorted { $0.rawValue < $1.rawValue },
            explanation: explanation,
            audioMayChange: audioSignature(plan) != audioSignature(currentPlan)
        )
    }

    private func mergeGoals(from source: ProcessingPlan, into target: inout ProcessingPlan) {
        for goal in source.goals {
            if let index = target.goals.firstIndex(where: {
                $0.attribute == goal.attribute && $0.direction == goal.direction
            }) {
                target.goals[index] = goal
            } else {
                target.goals.append(goal)
            }
        }
    }

    private func restoreLockedNodes(
        from current: ProcessingPlan,
        into candidate: inout ProcessingPlan
    ) throws {
        guard current.sourceSnapshotID == candidate.sourceSnapshotID,
              current.scope == candidate.scope else {
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

    private func neutralize(
        nodeTypes: Set<NodeType>,
        amount: Double,
        in plan: inout ProcessingPlan
    ) -> Bool {
        let scale = 1 - min(max(amount, 0.1), 1)
        var changed = false
        for index in plan.nodes.indices where nodeTypes.contains(plan.nodes[index].type) {
            guard !plan.nodes[index].locked,
                  plan.nodes[index].type != .limiter,
                  plan.nodes[index].type != .loudnessMatch else { continue }
            let before = plan.nodes[index]
            switch plan.nodes[index].type {
            case .parametricEQ:
                if let value = before.parameters[.gainDB] {
                    plan.nodes[index].parameters[.gainDB] = value * scale
                }
            case .compressor:
                if let ratio = before.parameters[.ratio] {
                    plan.nodes[index].parameters[.ratio] = 1 + (ratio - 1) * scale
                }
                if let mix = before.parameters[.mix] {
                    plan.nodes[index].parameters[.mix] = mix * scale
                }
            case .deEsser:
                if let ratio = before.parameters[.ratio] {
                    plan.nodes[index].parameters[.ratio] = 1 + (ratio - 1) * scale
                }
                if let mix = before.parameters[.mix] {
                    plan.nodes[index].parameters[.mix] = mix * scale
                }
            case .saturation, .softClipper:
                if let drive = before.parameters[.driveDB] {
                    plan.nodes[index].parameters[.driveDB] = drive * scale
                }
                if let mix = before.parameters[.mix] {
                    plan.nodes[index].parameters[.mix] = mix * scale
                }
            case .stereoWidth:
                if let width = before.parameters[.width] {
                    plan.nodes[index].parameters[.width] = 1 + (width - 1) * scale
                }
            case .inputTrim, .outputTrim:
                if let gain = before.parameters[.gainDB] {
                    plan.nodes[index].parameters[.gainDB] = gain * scale
                }
            case .highPass, .lowPass, .polarity:
                if scale <= 0.05 { plan.nodes[index].enabled = false }
            case .expander, .loudnessMatch, .limiter, .reverb, .delay,
                 .transientShaper, .midSideEQ, .meter:
                break
            }
            if plan.nodes[index] != before {
                plan.nodes[index].rationale = "Bounded conversational reduction toward this implemented processor's neutral state."
                changed = true
            }
        }
        return changed
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

    private func audioSignature(_ plan: ProcessingPlan) -> [AudioNodeSignature] {
        plan.nodes.map {
            AudioNodeSignature(type: $0.type, enabled: $0.enabled, parameters: $0.parameters)
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
            [.compressor, .parametricEQ, .outputTrim]
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

    private func nodeTypes(for goal: InterpretedProductionGoal) -> Set<NodeType> {
        let phrase = goal.matchedPhrase.lowercased()
        if phrase.contains("compress") { return [.compressor] }
        return nodeTypes(for: goal.term)
    }
}

private struct AudioNodeSignature: Equatable {
    var type: NodeType
    var enabled: Bool
    var parameters: [ParameterID: Double]
}
