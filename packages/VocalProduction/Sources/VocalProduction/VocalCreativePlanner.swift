import AudioAnalysis
import Foundation
import PlanSchema

public struct VocalCreativePlanner: Sendable {
    public init() {}

    public func plan(
        intent: VocalCreativeIntent,
        processingScope: ProcessingScope,
        analysis: AnalysisReport? = nil,
        deterministicIDs: VocalDeterministicIDs = .init(),
        createdAt: Date = Date()
    ) throws -> [VocalCreativeCandidate] {
        try VocalContractValidator().validate(intent: intent)
        if let clarification = intent.blockingClarification {
            throw VocalContractError.blockingClarificationRequired(clarification)
        }
        guard processingScope.sourceType == .vocal || processingScope.sourceType == .vocalBus else {
            throw VocalContractError.invalidSourceType(processingScope.sourceType)
        }
        let intendedRange = intent.scope.kind == .fullSource ? nil : intent.scope.seconds
        guard processingScope.timeRangeSeconds == intendedRange else {
            throw VocalContractError.invalidScope(
                "The exact ProcessingScope range does not match the typed VocalCreativeScope."
            )
        }

        let recipes = recipes(for: intent, analysis: analysis)
        guard recipes.count == 3 else {
            throw VocalContractError.validationFailed(
                "Vocal v1 must expose exactly three bounded audition candidates."
            )
        }
        try validateIdentityShape(deterministicIDs, recipeCount: recipes.count, recipes: recipes)

        return try recipes.enumerated().map { candidateIndex, recipe in
            let candidateID = deterministicIDs.candidateIDs.indices.contains(candidateIndex)
                ? deterministicIDs.candidateIDs[candidateIndex]
                : UUID()
            let requestID = deterministicIDs.planRequestIDs.indices.contains(candidateIndex)
                ? deterministicIDs.planRequestIDs[candidateIndex]
                : UUID()
            let suppliedNodeIDs = deterministicIDs.nodeIDsByCandidate.indices.contains(candidateIndex)
                ? deterministicIDs.nodeIDsByCandidate[candidateIndex]
                : []
            var nodes: [ProcessingNode] = []
            nodes.reserveCapacity(recipe.nodes.count)
            for (nodeIndex, blueprint) in recipe.nodes.enumerated() {
                let nodeID = suppliedNodeIDs.indices.contains(nodeIndex)
                    ? suppliedNodeIDs[nodeIndex]
                    : UUID()
                nodes.append(ProcessingNode(
                    id: nodeID,
                    type: blueprint.type,
                    parameters: blueprint.parameters,
                    rationale: blueprint.rationale,
                    confidence: blueprint.confidence,
                    category: blueprint.category,
                    locked: blueprint.locked
                ))
            }
            let preservationEnforcement = try VocalDSPPreservationMatrix.constrainedNodes(
                nodes,
                preservation: intent.preservation,
                lockedAspects: intent.aspectLocks.map(\.aspect)
            )
            nodes = preservationEnforcement.nodes
            let plan = ProcessingPlan(
                requestID: requestID,
                sourceSnapshotID: intent.sourceSnapshotID,
                scope: processingScope,
                goals: processingGoals(for: intent),
                nodes: nodes,
                outputConstraints: .init(
                    maxTruePeakDB: -1,
                    loudnessMatchPreview: true,
                    preserveMonoCompatibility: true,
                    maxAddedGainDB: 12
                )
            )
            let realtimeActivatable = intent.scope.kind == .fullSource
            do {
                if realtimeActivatable {
                    try PlanValidator().validateForRealtimeActivation(
                        plan,
                        currentSnapshotID: intent.sourceSnapshotID
                    )
                } else {
                    try PlanValidator().validate(
                        plan,
                        currentSnapshotID: intent.sourceSnapshotID
                    )
                }
            } catch {
                throw VocalContractError.validationFailed(String(describing: error))
            }
            let bindings = bindingsFor(recipe: recipe, nodes: nodes)
            let candidate = VocalCreativeCandidate(
                id: candidateID,
                title: recipe.title,
                summary: recipe.summary,
                interpretationIndex: candidateIndex + 1,
                intent: intent,
                plan: plan,
                boundary: realtimeActivatable ? recipe.boundary : .scopedEditablePlanForOfflineRender,
                aspectBindings: bindings,
                limitations: commonLimitations(for: intent.archetype)
                    + recipe.limitations
                    + preservationLimitations(for: preservationEnforcement),
                realtimeActivatable: realtimeActivatable,
                createdAt: createdAt
            )
            try VocalContractValidator().validate(candidate: candidate)
            return candidate
        }
    }

    public func plan(
        intent: VocalCreativeIntent,
        channelFormat: ChannelFormat,
        sourceType: SourceType = .vocal,
        scopeKind: ScopeKind = .importedFile,
        analysis: AnalysisReport? = nil,
        deterministicIDs: VocalDeterministicIDs = .init(),
        createdAt: Date = Date()
    ) throws -> [VocalCreativeCandidate] {
        try plan(
            intent: intent,
            processingScope: ProcessingScope(
                kind: scopeKind,
                channelFormat: channelFormat,
                sourceType: sourceType,
                timeRangeSeconds: intent.scope.kind == .fullSource ? nil : intent.scope.seconds
            ),
            analysis: analysis,
            deterministicIDs: deterministicIDs,
            createdAt: createdAt
        )
    }

    private struct NodeBlueprint {
        var type: NodeType
        var parameters: [ParameterID: Double]
        var rationale: String
        var confidence: Double
        var category: ChangeCategory
        var locked: Bool = false
        var aspects: [VocalAspect]
    }

    private struct Recipe {
        var title: String
        var summary: String
        var boundary: VocalProcessingBoundary
        var nodes: [NodeBlueprint]
        var limitations: [String]
    }

    private func validateIdentityShape(
        _ ids: VocalDeterministicIDs,
        recipeCount: Int,
        recipes: [Recipe]
    ) throws {
        if !ids.candidateIDs.isEmpty {
            guard ids.candidateIDs.count == recipeCount,
                  Set(ids.candidateIDs).count == recipeCount else {
                throw VocalContractError.insufficientDeterministicIDs(
                    "candidateIDs must contain exactly \(recipeCount) unique values when supplied."
                )
            }
        }
        if !ids.planRequestIDs.isEmpty {
            guard ids.planRequestIDs.count == recipeCount,
                  Set(ids.planRequestIDs).count == recipeCount else {
                throw VocalContractError.insufficientDeterministicIDs(
                    "planRequestIDs must contain exactly \(recipeCount) unique values when supplied."
                )
            }
        }
        if !ids.nodeIDsByCandidate.isEmpty {
            guard ids.nodeIDsByCandidate.count == recipeCount else {
                throw VocalContractError.insufficientDeterministicIDs(
                    "nodeIDsByCandidate must contain one row per candidate when supplied."
                )
            }
            for index in recipes.indices {
                let nodeIDs = ids.nodeIDsByCandidate[index]
                guard nodeIDs.count == recipes[index].nodes.count,
                      Set(nodeIDs).count == nodeIDs.count else {
                    throw VocalContractError.insufficientDeterministicIDs(
                        "candidate \(index + 1) requires exactly \(recipes[index].nodes.count) unique node IDs."
                    )
                }
            }
            let allNodeIDs = ids.nodeIDsByCandidate.flatMap { $0 }
            guard Set(allNodeIDs).count == allNodeIDs.count else {
                throw VocalContractError.insufficientDeterministicIDs(
                    "Initial candidates must not reuse a processing-node identity."
                )
            }
        }
    }

    private func processingGoals(for intent: VocalCreativeIntent) -> [ProcessingGoal] {
        var goals: [ProcessingGoal] = []
        func add(_ attribute: GoalAttribute, _ direction: GoalDirection, _ strength: Double, locked: Bool = false) {
            guard !goals.contains(where: { $0.attribute == attribute && $0.direction == direction }) else { return }
            goals.append(ProcessingGoal(attribute: attribute, direction: direction, strength: strength, locked: locked))
        }
        for change in intent.desiredChanges {
            let direction: GoalDirection = switch change.direction {
            case .increase: .increase
            case .decrease: .decrease
            case .preserve: .preserve
            case .prohibit: .doNotIncrease
            }
            switch change.aspect {
            case .intelligibility, .articulation, .consonants: add(.clarity, direction, change.strength)
            case .warmth, .smokyCharacter: add(.warmth, direction, change.strength)
            case .brightness, .air, .glassyCharacter: add(.brightness, direction, change.strength)
            case .darkness: add(.brightness, direction == .increase ? .decrease : .increase, change.strength)
            case .dynamics: add(.dynamicControl, direction, change.strength)
            case .closeness: add(.closeness, direction, change.strength)
            case .distance: add(.closeness, direction == .increase ? .decrease : .increase, change.strength)
            case .width: add(.width, direction, change.strength)
            case .loudness: add(.loudness, direction, change.strength)
            case .body: add(.lowEnd, direction, change.strength)
            default: break
            }
        }
        for aspect in intent.preservation.prohibitedChanges {
            switch aspect {
            case .loudness: add(.loudness, .preserve, 1, locked: true)
            case .dynamics: add(.dynamicControl, .preserve, 1, locked: true)
            case .brightness, .air: add(.brightness, .preserve, 1, locked: true)
            case .width: add(.width, .preserve, 1, locked: true)
            default: break
            }
        }
        if goals.isEmpty { add(.clarity, .increase, max(0.25, intent.strength * 0.65)) }
        return goals
    }

    private func recipes(for intent: VocalCreativeIntent, analysis: AnalysisReport?) -> [Recipe] {
        switch intent.archetype {
        case .underwater: underwaterRecipes(intent.strength)
        case .vocalToBrass: brassRecipes(intent.strength, analysis: analysis)
        case .glassy: glassyRecipes(intent.strength)
        case .smoky: smokyRecipes(intent.strength)
        case .enormousButDistant: enormousDistantRecipes(intent.strength)
        case .fragile: fragileRecipes(intent.strength)
        case .broken: brokenRecipes(intent.strength)
        case .floating: floatingRecipes(intent.strength)
        case .metallic: metallicRecipes(intent.strength)
        case .radioLike: radioRecipes(intent.strength)
        case .dreamlike: dreamlikeRecipes(intent.strength)
        case .unstable: unstableRecipes(intent.strength)
        case .extremelyIntimate: intimateRecipes(intent.strength, analysis: analysis)
        case .ordinary: ordinaryRecipes(intent, analysis: analysis)
        }
    }

    // Underwater is deliberately three different signal structures. Every
    // interpretation contains modulatedDelay so movement is real and
    // time-varying, never a renamed fixed delay.
    private func underwaterRecipes(_ strength: Double) -> [Recipe] {
        let amount = 0.65 + strength * 0.35
        return [
            Recipe(
                title: "Submerged slow current",
                summary: "Dark filtering, slow moving delay, then diffuse space.",
                boundary: .editableModulationDSP,
                nodes: [
                    node(.lowPass, [.frequencyHz: 4_800 - 2_200 * strength, .q: 0.72], "Darken the vocal as a submerged metaphor; this is not a physical underwater transfer model.", [.underwaterColoration, .darkness]),
                    modulatedDelay(baseMS: 15, depthMS: 5 + 6 * strength, rateHz: 0.14 + 0.16 * strength, stereoPhase: 90, feedback: 0.12, damping: 0.62, mix: 0.20 + 0.20 * amount, rationale: "Create audible slow time-varying current while preserving the dry voice.", aspects: [.movement, .wobble, .underwaterColoration]),
                    node(.reverb, [.algorithmVersion: 1, .preDelayMS: 8, .decayTimeSeconds: 1.5 + 1.8 * strength, .roomSize: 0.68, .damping: 0.72, .diffusion: 0.86, .mix: 0.16 + 0.22 * strength], "Add a diffuse bounded space after the moving path.", [.space, .underwaterColoration]),
                    limiter(),
                ],
                limitations: ["Darkness and modulation may reduce consonant definition; compare against dry at matched level."]
            ),
            Recipe(
                title: "Rippling filtered reflections",
                summary: "Band-shaped direct sound, faster ripple, then a separate fixed reflection path.",
                boundary: .editableModulationDSP,
                nodes: [
                    node(.highPass, [.frequencyHz: 95 + 45 * strength, .q: 0.78], "Keep subsonic energy out of the moving reflection chain.", [.underwaterColoration]),
                    node(.lowPass, [.frequencyHz: 5_600 - 2_000 * strength, .q: 1.05], "Use a more resonant, less deeply darkened filter shape than candidate one.", [.tone, .underwaterColoration]),
                    modulatedDelay(baseMS: 7, depthMS: 2.5 + 4.5 * strength, rateHz: 0.75 + 0.9 * strength, stereoPhase: 150, feedback: 0.08, damping: 0.48, mix: 0.18 + 0.18 * strength, rationale: "Produce a quicker ripple distinct from the slow-current candidate.", aspects: [.movement, .wobble, .underwaterColoration]),
                    node(.delay, [.algorithmVersion: 1, .delayTimeMS: 155 + 95 * strength, .feedback: 0.16 + 0.12 * strength, .damping: 0.64, .stereoCrossfeed: 0.35, .mix: 0.10 + 0.14 * strength], "Add discrete filtered reflections after the moving path.", [.space, .underwaterColoration]),
                    limiter(),
                ],
                limitations: ["The fixed echo can expose rhythmic conflicts; timing quality is a listening judgment."]
            ),
            Recipe(
                title: "Dense pressure haze",
                summary: "Parallel harmonic density and control feed a darker moving haze.",
                boundary: .editableModulationDSP,
                nodes: [
                    node(.saturation, [.driveDB: 3 + 7 * strength, .mix: 0.10 + 0.20 * strength], "Add bounded harmonic density without replacing the vocal.", [.body, .underwaterColoration]),
                    node(.compressor, [.thresholdDB: -20 - 5 * strength, .ratio: 1.5 + 1.2 * strength, .attackMS: 24, .releaseMS: 180, .makeupGainDB: 0, .kneeDB: 8, .mix: 0.65], "Shape density while leaving a dry transient path.", [.dynamics, .body]),
                    node(.lowPass, [.frequencyHz: 4_100 - 1_600 * strength, .q: 0.68], "Create the darkest of the three underwater tonal structures.", [.darkness, .underwaterColoration]),
                    modulatedDelay(baseMS: 20, depthMS: 7 + 7 * strength, rateHz: 0.28 + 0.30 * strength, stereoPhase: 45, feedback: 0.18, damping: 0.78, mix: 0.22 + 0.18 * strength, rationale: "Create a deep, asymmetric time-varying haze.", aspects: [.movement, .wobble, .underwaterColoration]),
                    node(.reverb, [.algorithmVersion: 1, .preDelayMS: 2, .decayTimeSeconds: 0.9 + 1.1 * strength, .roomSize: 0.45, .damping: 0.84, .diffusion: 0.92, .mix: 0.12 + 0.14 * strength], "Fuse the dense path without claiming an environmental reconstruction.", [.space, .underwaterColoration]),
                    limiter(),
                ],
                limitations: ["Density can mask breath and articulation; preservation is evaluated by audition, not inferred."]
            ),
        ]
    }

    // Brass candidates are editable coloration/hybrid plans. Their node
    // structures differ and none claims vocal-to-instrument reconstruction.
    private func brassRecipes(_ strength: Double, analysis: AnalysisReport?) -> [Recipe] {
        let measuredRMS = analysis?.metrics["rms_dbfs"]?.value ?? -24
        let threshold = min(-8, max(-40, measuredRMS + 4 - 4 * strength))
        return [
            Recipe(
                title: "Resonant brass color",
                summary: "A formant-like editable EQ contour into controlled harmonic density.",
                boundary: .editableDeterministicDSP,
                nodes: [
                    node(.highPass, [.frequencyHz: 105, .q: 0.72], "Remove only subsonic energy before resonant coloration.", [.brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 620, .q: 1.5, .gainDB: 1.2 + 1.8 * strength], "Create one broad resonant brass-like color band without claiming a formant reconstruction.", [.tone, .brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 1_650, .q: 1.8, .gainDB: 1.0 + 1.5 * strength], "Add a second editable resonance for the hybrid color.", [.tone, .brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 4_300, .q: 1.1, .gainDB: -0.8 - 1.2 * strength], "Bound brittle upper energy as the resonances and saturation increase.", [.brightness, .consonants]),
                    node(.compressor, [.thresholdDB: threshold, .ratio: 1.8 + 1.5 * strength, .attackMS: 18, .releaseMS: 120, .makeupGainDB: 0, .kneeDB: 7, .mix: 0.78], "Increase sustained density while retaining an uncompressed component.", [.dynamics, .attack, .brassLikeColoration]),
                    node(.saturation, [.driveDB: 4 + 10 * strength, .mix: 0.18 + 0.30 * strength], "Add bounded harmonic coloration; this does not synthesize a brass instrument.", [.metallicCharacter, .brassLikeColoration]),
                    limiter(),
                ],
                limitations: ["Resonant EQ is not vocal-tract or brass-bore modeling; the source remains recognizably vocal."]
            ),
            Recipe(
                title: "Muted-brass hybrid",
                summary: "Narrower tone and saturation feed a short room-and-reflection structure.",
                boundary: .editableDeterministicDSP,
                nodes: [
                    node(.lowPass, [.frequencyHz: 6_800 - 1_900 * strength, .q: 1.15], "Use a muted-brass-like spectral boundary without claiming a physical mute.", [.tone, .brassLikeColoration]),
                    node(.saturation, [.driveDB: 6 + 9 * strength, .mix: 0.16 + 0.32 * strength], "Create parallel harmonic density before the resonances.", [.metallicCharacter, .brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 880, .q: 2.2, .gainDB: 1.0 + 2.0 * strength], "Emphasize a bounded nasal/resonant color for comparison.", [.tone, .brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 2_450, .q: 1.6, .gainDB: 0.8 + 1.4 * strength], "Add a second resonant color while monitoring intelligibility.", [.tone, .brassLikeColoration, .intelligibility]),
                    node(.delay, [.algorithmVersion: 1, .delayTimeMS: 72, .feedback: 0.08, .damping: 0.55, .stereoCrossfeed: 0.25, .mix: 0.08 + 0.08 * strength], "Add one short editable reflection rather than instrument-body reconstruction.", [.space, .brassLikeColoration]),
                    node(.reverb, [.algorithmVersion: 1, .preDelayMS: 5, .decayTimeSeconds: 0.45 + 0.35 * strength, .roomSize: 0.28, .damping: 0.48, .diffusion: 0.60, .mix: 0.07 + 0.08 * strength], "Place the hybrid color in a compact space.", [.space]),
                    limiter(),
                ],
                limitations: ["The muted quality is a metaphorical color assembled from filters and nonlinear DSP."]
            ),
            Recipe(
                title: "Animated brass ensemble color",
                summary: "Compression and saturation feed subtle time-varying ensemble motion and resonant EQ.",
                boundary: .editableModulationDSP,
                nodes: [
                    node(.highPass, [.frequencyHz: 120, .q: 0.75], "Protect headroom before the dense hybrid path.", [.brassLikeColoration]),
                    node(.compressor, [.thresholdDB: threshold - 2, .ratio: 2.0 + 1.2 * strength, .attackMS: 28, .releaseMS: 150, .makeupGainDB: 0, .kneeDB: 9, .mix: 0.72], "Retain attack while increasing body continuity.", [.dynamics, .attack, .brassLikeColoration]),
                    node(.saturation, [.driveDB: 5 + 11 * strength, .mix: 0.14 + 0.28 * strength], "Generate editable harmonic coloration from the voice.", [.metallicCharacter, .brassLikeColoration]),
                    modulatedDelay(baseMS: 10, depthMS: 1.5 + 3.5 * strength, rateHz: 0.32 + 0.42 * strength, stereoPhase: 120, feedback: 0.04, damping: 0.38, mix: 0.09 + 0.12 * strength, rationale: "Add subtle ensemble-like time variation, not additional reconstructed performers.", aspects: [.movement, .brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 720, .q: 1.4, .gainDB: 1.0 + 1.6 * strength], "Shape lower resonant color after motion.", [.tone, .brassLikeColoration]),
                    node(.parametricEQ, [.frequencyHz: 2_100, .q: 1.5, .gainDB: 0.9 + 1.5 * strength], "Shape upper resonant color after motion.", [.tone, .brassLikeColoration]),
                    limiter(),
                ],
                limitations: ["Ensemble motion is modulation of one vocal source, not a brass section or acoustic reconstruction."]
            ),
        ]
    }

    private func glassyRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Clear glass edge", "Frosted glass wash", "Moving glass reflection"],
            summaries: ["Bright resonant edge with controlled sharpness.", "Diffuse bright coloration with soft space.", "Short moving reflections around a bright vocal."],
            nodeSets: [
                [node(.highPass, [.frequencyHz: 110, .q: 0.72], "Protect low headroom.", [.glassyCharacter]), node(.parametricEQ, [.frequencyHz: 7_500, .q: 0.8, .gainDB: 1 + 2 * s], "Add bounded glass-like sheen.", [.glassyCharacter, .air]), node(.deEsser, [.frequencyHz: 7_000, .thresholdDB: -28, .ratio: 2 + s, .attackMS: 1.5, .releaseMS: 75, .mix: 0.7], "Limit sharp upper events while retaining the sheen.", [.consonants, .intelligibility])],
                [node(.parametricEQ, [.frequencyHz: 5_500, .q: 1.4, .gainDB: 1.2 + 1.8 * s], "Create a narrower frosted-glass color.", [.glassyCharacter]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 18, .decayTimeSeconds: 1.1 + s, .roomSize: 0.52, .damping: 0.32, .diffusion: 0.88, .mix: 0.12 + 0.16 * s], "Add a bright diffuse wash.", [.space, .glassyCharacter])],
                [node(.parametricEQ, [.frequencyHz: 8_200, .q: 0.65, .gainDB: 0.8 + 1.4 * s], "Add reflective brightness conservatively.", [.glassyCharacter, .air]), modulatedDelay(baseMS: 12, depthMS: 2 + 3 * s, rateHz: 0.25 + 0.4 * s, stereoPhase: 135, feedback: 0.05, damping: 0.22, mix: 0.10 + 0.12 * s, rationale: "Create genuine moving glass-like reflection cues.", aspects: [.movement, .glassyCharacter])],
            ],
            boundary: [.editableDeterministicDSP, .editableDeterministicDSP, .editableModulationDSP],
            limitation: "Glassy is a metaphor; upper-frequency preference and sharpness require listening."
        )
    }

    private func smokyRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Warm smoke", "Dark velvet smoke", "Smoky room trail"],
            summaries: ["Parallel warmth with softened upper tone.", "Darker harmonic density and gentle control.", "Warm direct vocal with a short dark trail."],
            nodeSets: [
                [node(.saturation, [.driveDB: 3 + 8 * s, .mix: 0.14 + 0.25 * s], "Add bounded smoky harmonic density.", [.smokyCharacter, .warmth]), node(.parametricEQ, [.frequencyHz: 7_000, .q: 0.75, .gainDB: -0.8 - 1.2 * s], "Soften upper brightness.", [.darkness, .smokyCharacter])],
                [node(.lowPass, [.frequencyHz: 9_000 - 2_500 * s, .q: 0.65], "Create a darker contour.", [.darkness, .smokyCharacter]), node(.compressor, [.thresholdDB: -24, .ratio: 1.5 + s, .attackMS: 30, .releaseMS: 170, .makeupGainDB: 0, .kneeDB: 9, .mix: 0.65], "Gently bind the darker color while retaining dynamics.", [.dynamics, .smokyCharacter]), node(.saturation, [.driveDB: 4 + 7 * s, .mix: 0.12 + 0.22 * s], "Add parallel density.", [.warmth, .smokyCharacter])],
                [node(.parametricEQ, [.frequencyHz: 420, .q: 0.8, .gainDB: 0.6 + s], "Add restrained body.", [.body, .smokyCharacter]), node(.saturation, [.driveDB: 3 + 6 * s, .mix: 0.12 + 0.20 * s], "Add warm density.", [.warmth, .smokyCharacter]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 24, .decayTimeSeconds: 0.8 + 0.8 * s, .roomSize: 0.38, .damping: 0.75, .diffusion: 0.78, .mix: 0.08 + 0.13 * s], "Add a short dark trail.", [.space, .smokyCharacter])],
            ],
            limitation: "Smoky is implemented as tone, density, and space—not as a source or performance classification."
        )
    }

    private func enormousDistantRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Far hall mass", "Distant double shadow", "Wide horizon"],
            summaries: ["Long diffuse space with retained low-mid body.", "Quieter direct image with echo and room layers.", "Wide, delayed depth with controlled body."],
            nodeSets: [
                [node(.parametricEQ, [.frequencyHz: 220, .q: 0.75, .gainDB: 0.8 + 1.2 * s], "Retain body so distance does not only become thinness.", [.body]), node(.outputTrim, [.gainDB: -1.5 - 2 * s], "Reduce direct salience before the large space.", [.distance]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 35, .decayTimeSeconds: 2.5 + 3 * s, .roomSize: 0.9, .damping: 0.48, .diffusion: 0.9, .mix: 0.22 + 0.25 * s], "Create a large diffuse editable space.", [.space, .distance])],
                [node(.outputTrim, [.gainDB: -2 - 2.5 * s], "Lower direct salience.", [.distance]), node(.delay, [.algorithmVersion: 1, .delayTimeMS: 280 + 180 * s, .feedback: 0.18 + 0.18 * s, .damping: 0.52, .stereoCrossfeed: 0.45, .mix: 0.12 + 0.16 * s], "Create a separate distant shadow.", [.space, .distance]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 12, .decayTimeSeconds: 1.8 + 2.2 * s, .roomSize: 0.82, .damping: 0.55, .diffusion: 0.86, .mix: 0.18 + 0.20 * s], "Diffuse the distant shadow.", [.space, .distance])],
                [node(.parametricEQ, [.frequencyHz: 300, .q: 0.8, .gainDB: 0.7 + s], "Preserve weight.", [.body]), node(.stereoWidth, [.width: 1.1 + 0.45 * s, .mix: 0.5], "Increase the horizon-like spatial spread while preserving a dry center.", [.width, .space]), node(.delay, [.algorithmVersion: 1, .delayTimeMS: 120 + 80 * s, .feedback: 0.12, .damping: 0.62, .stereoCrossfeed: 0.65, .mix: 0.11 + 0.12 * s], "Create depth before the room.", [.distance, .space]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 50, .decayTimeSeconds: 2.1 + 2.7 * s, .roomSize: 0.88, .damping: 0.50, .diffusion: 0.84, .mix: 0.18 + 0.21 * s], "Create large-space cues.", [.distance, .space])],
            ],
            limitation: "Enormous and distant are conflicting perceptual cues; candidates balance editable level, body, delay, and reverb rather than claiming a unique solution."
        )
    }

    private func fragileRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Bare fragile detail", "Soft fragile halo", "Fragile edge"],
            summaries: ["Minimal high-pass and very light control.", "Air detail with a restrained halo.", "Parallel broken-edge texture kept beneath the dry voice."],
            nodeSets: [
                [node(.highPass, [.frequencyHz: 70, .q: 0.7], "Remove only subsonic energy.", [.fragility]), node(.compressor, [.thresholdDB: -20, .ratio: 1.25 + 0.45 * s, .attackMS: 38, .releaseMS: 220, .makeupGainDB: 0, .kneeDB: 10, .mix: 0.45], "Use very light parallel control while preserving natural dynamics.", [.fragility, .dynamics])],
                [node(.parametricEQ, [.frequencyHz: 9_000, .q: 0.65, .gainDB: 0.5 + 0.8 * s], "Lift air cautiously.", [.air, .fragility]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 28, .decayTimeSeconds: 0.7 + 0.7 * s, .roomSize: 0.35, .damping: 0.42, .diffusion: 0.85, .mix: 0.07 + 0.10 * s], "Add a restrained halo.", [.space, .fragility])],
                [node(.saturation, [.driveDB: 2 + 6 * s, .mix: 0.05 + 0.12 * s], "Add a barely parallel frayed edge.", [.fragility, .distortion]), node(.parametricEQ, [.frequencyHz: 6_500, .q: 1.0, .gainDB: -0.5 - 0.7 * s], "Prevent the edge from becoming brittle.", [.consonants, .fragility])],
            ],
            limitation: "Fragility is an artistic listening judgment; DSP cannot infer or create emotional performance intent."
        )
    }

    private func brokenRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Parallel fracture", "Stuttering reflection color", "Warped break"],
            summaries: ["Parallel saturation with retained dry identity.", "Short repeated reflection and band color.", "Controlled modulation and nonlinear edge."],
            nodeSets: [
                [node(.saturation, [.driveDB: 8 + 16 * s, .mix: 0.14 + 0.35 * s], "Create a bounded parallel fractured texture.", [.broken, .distortion])],
                [node(.parametricEQ, [.frequencyHz: 1_800, .q: 2.4, .gainDB: 1 + 2 * s], "Create a narrow fractured color.", [.broken, .tone]), node(.delay, [.algorithmVersion: 1, .delayTimeMS: 85, .feedback: 0.18 + 0.25 * s, .damping: 0.32, .stereoCrossfeed: 0.3, .mix: 0.10 + 0.18 * s], "Add a bounded repeated fragment; this is not time editing.", [.broken, .space])],
                [node(.softClipper, [.driveDB: 4 + 11 * s, .ceilingDB: -2, .mix: 0.12 + 0.25 * s], "Add a controlled nonlinear edge.", [.broken, .distortion]), modulatedDelay(baseMS: 9, depthMS: 2 + 5 * s, rateHz: 0.6 + 1.2 * s, stereoPhase: 70, feedback: 0.06, damping: 0.25, mix: 0.10 + 0.18 * s, rationale: "Warp the edge with real time variation without replacing timing.", aspects: [.broken, .instability, .movement])],
            ],
            boundary: [.editableDeterministicDSP, .editableDeterministicDSP, .editableModulationDSP],
            limitation: "Broken is a reversible texture; no timing edits, dropouts, or source destruction are performed."
        )
    }

    private func floatingRecipes(_ s: Double) -> [Recipe] {
        movementSpaceRecipes(label: "Floating", strength: s, rate: 0.18, depth: 3, darker: false)
    }

    private func metallicRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Metal resonance", "Short metal reflection", "Moving alloy"],
            summaries: ["Resonant EQ and harmonic density.", "Narrow color with a short reflection.", "Subtle time-varying metallic hybrid."],
            nodeSets: [
                [node(.parametricEQ, [.frequencyHz: 1_250, .q: 3.2, .gainDB: 1.2 + 2.4 * s], "Create a bounded metallic resonance.", [.metallicCharacter]), node(.parametricEQ, [.frequencyHz: 3_600, .q: 2.6, .gainDB: 0.8 + 1.8 * s], "Add a second resonant cue.", [.metallicCharacter]), node(.saturation, [.driveDB: 4 + 9 * s, .mix: 0.12 + 0.25 * s], "Add harmonic density beneath the dry voice.", [.metallicCharacter, .distortion])],
                [node(.parametricEQ, [.frequencyHz: 2_200, .q: 3.8, .gainDB: 1 + 2 * s], "Create a narrow metallic color.", [.metallicCharacter]), node(.delay, [.algorithmVersion: 1, .delayTimeMS: 34, .feedback: 0.22, .damping: 0.18, .stereoCrossfeed: 0.4, .mix: 0.08 + 0.15 * s], "Add a short ringing reflection.", [.metallicCharacter, .space])],
                [node(.saturation, [.driveDB: 3 + 8 * s, .mix: 0.10 + 0.22 * s], "Create an alloy-like harmonic bed.", [.metallicCharacter]), modulatedDelay(baseMS: 8, depthMS: 1 + 3 * s, rateHz: 0.45 + 0.8 * s, stereoPhase: 180, feedback: 0.08, damping: 0.22, mix: 0.10 + 0.16 * s, rationale: "Add time-varying metallic motion.", aspects: [.metallicCharacter, .movement])],
            ],
            boundary: [.editableDeterministicDSP, .editableDeterministicDSP, .editableModulationDSP],
            limitation: "Metallic is resonant DSP coloration, not material identification or physical modeling."
        )
    }

    private func radioRecipes(_ s: Double) -> [Recipe] {
        variants(
            names: ["Clean small radio", "Driven radio", "Room radio"],
            summaries: ["Band-limited but intelligible.", "Band-limit with parallel harmonic density.", "Band-limited voice heard through a short room cue."],
            nodeSets: [
                [node(.highPass, [.frequencyHz: 260 + 140 * s, .q: 0.72], "Set the low boundary of a radio-like band.", [.radioLike]), node(.lowPass, [.frequencyHz: 5_200 - 1_500 * s, .q: 0.78], "Set the high boundary while retaining word cues.", [.radioLike, .intelligibility])],
                [node(.highPass, [.frequencyHz: 330, .q: 0.85], "Set the low radio-like boundary.", [.radioLike]), node(.lowPass, [.frequencyHz: 4_500, .q: 1.0], "Set the high radio-like boundary.", [.radioLike]), node(.saturation, [.driveDB: 5 + 10 * s, .mix: 0.13 + 0.28 * s], "Add bounded small-speaker-like density without modeling a device.", [.radioLike, .distortion])],
                [node(.highPass, [.frequencyHz: 280, .q: 0.72], "Band-limit the direct signal.", [.radioLike]), node(.lowPass, [.frequencyHz: 5_000, .q: 0.75], "Bound upper bandwidth.", [.radioLike]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 4, .decayTimeSeconds: 0.35 + 0.35 * s, .roomSize: 0.22, .damping: 0.60, .diffusion: 0.55, .mix: 0.06 + 0.09 * s], "Place the radio-like color in a small editable space.", [.radioLike, .space])],
            ],
            limitation: "Radio-like is generic band and density coloration, not an emulation of a named radio or transmission path."
        )
    }

    private func dreamlikeRecipes(_ s: Double) -> [Recipe] {
        movementSpaceRecipes(label: "Dreamlike", strength: s, rate: 0.12, depth: 4, darker: true)
    }

    private func unstableRecipes(_ s: Double) -> [Recipe] {
        let recipes = movementSpaceRecipes(label: "Unstable", strength: s, rate: 0.8, depth: 7, darker: false)
        return recipes.map { recipe in
            var copy = recipe
            copy.limitations.append("Instability is bounded modulated delay; pitch and timing are not analyzed or replaced.")
            return copy
        }
    }

    private func movementSpaceRecipes(
        label: String,
        strength s: Double,
        rate: Double,
        depth: Double,
        darker: Bool
    ) -> [Recipe] {
        variants(
            names: ["\(label) slow drift", "\(label) echo field", "\(label) close motion"],
            summaries: ["Slow modulation into diffuse space.", "Moving direct path plus a separate echo.", "Subtle faster motion with restrained room."],
            nodeSets: [
                [modulatedDelay(baseMS: 16, depthMS: min(20, depth + 4 * s), rateHz: min(5, rate + 0.15 * s), stereoPhase: 120, feedback: 0.08, damping: darker ? 0.65 : 0.35, mix: 0.12 + 0.20 * s, rationale: "Create a slow real time-varying drift.", aspects: [.movement, .floating]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 26, .decayTimeSeconds: 1.4 + 1.8 * s, .roomSize: 0.66, .damping: darker ? 0.68 : 0.42, .diffusion: 0.90, .mix: 0.14 + 0.20 * s], "Create a diffuse suspended space.", [.space, .floating])],
                [modulatedDelay(baseMS: 10, depthMS: min(20, depth * 0.7 + 3 * s), rateHz: min(5, rate * 1.5 + 0.25 * s), stereoPhase: 165, feedback: 0.05, damping: 0.4, mix: 0.10 + 0.16 * s, rationale: "Move the direct path deterministically.", aspects: [.movement]), node(.delay, [.algorithmVersion: 1, .delayTimeMS: 260, .feedback: 0.22, .damping: 0.55, .stereoCrossfeed: 0.55, .mix: 0.10 + 0.15 * s], "Add an independent echo field.", [.space, .floating])],
                [node(.parametricEQ, [.frequencyHz: darker ? 5_500 : 8_000, .q: 0.7, .gainDB: darker ? -1.2 * s : 0.7 * s], "Set a distinct tonal frame for the close-motion candidate.", [.tone]), modulatedDelay(baseMS: 6, depthMS: min(20, depth * 0.5 + 2 * s), rateHz: min(5, rate * 2 + 0.35 * s), stereoPhase: 60, feedback: 0.03, damping: 0.32, mix: 0.08 + 0.13 * s, rationale: "Use a closer, quicker motion structure.", aspects: [.movement]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 12, .decayTimeSeconds: 0.7 + 0.9 * s, .roomSize: 0.42, .damping: 0.5, .diffusion: 0.82, .mix: 0.08 + 0.12 * s], "Add a restrained supporting room.", [.space])],
            ],
            boundary: [.editableModulationDSP, .editableModulationDSP, .editableModulationDSP],
            limitation: "The spatial/motion metaphor is deterministic DSP; no scene, emotion, or performance understanding is claimed."
        )
    }

    private func intimateRecipes(_ s: Double, analysis: AnalysisReport?) -> [Recipe] {
        let rms = analysis?.metrics["rms_dbfs"]?.value ?? -24
        let threshold = min(-10, max(-38, rms + 5))
        return variants(
            names: ["Dry close detail", "Close controlled body", "Intimate short room"],
            summaries: ["Minimal subsonic cleanup and gentle presence.", "Parallel control and warmth for direct salience.", "Direct vocal with a barely audible short room."],
            nodeSets: [
                [node(.highPass, [.frequencyHz: 72, .q: 0.7], "Remove only subsonic energy.", [.closeness]), node(.parametricEQ, [.frequencyHz: 3_200, .q: 0.9, .gainDB: 0.5 + 0.9 * s], "Increase direct word presence conservatively.", [.closeness, .intelligibility])],
                [node(.compressor, [.thresholdDB: threshold, .ratio: 1.3 + 0.8 * s, .attackMS: 22, .releaseMS: 140, .makeupGainDB: 0, .kneeDB: 9, .mix: 0.58], "Increase direct density while retaining dry dynamics.", [.closeness, .dynamics]), node(.saturation, [.driveDB: 2 + 5 * s, .mix: 0.08 + 0.16 * s], "Add close harmonic body without replacing capture detail.", [.closeness, .warmth])],
                [node(.parametricEQ, [.frequencyHz: 2_800, .q: 0.85, .gainDB: 0.4 + 0.8 * s], "Increase direct salience.", [.closeness, .intelligibility]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 36, .decayTimeSeconds: 0.35 + 0.35 * s, .roomSize: 0.2, .damping: 0.58, .diffusion: 0.65, .mix: 0.04 + 0.06 * s], "Add only a short low-mix room cue.", [.space, .closeness])],
            ],
            limitation: "Extremely intimate processing cannot recreate missing close-mic capture information or infer breath/performance intent."
        )
    }

    private func ordinaryRecipes(_ intent: VocalCreativeIntent, analysis: AnalysisReport?) -> [Recipe] {
        let s = intent.strength
        let wantsDark = intent.desiredChanges.contains { $0.aspect == .darkness && $0.direction == .increase }
        let wantsBright = intent.desiredChanges.contains { [.brightness, .air].contains($0.aspect) && $0.direction == .increase }
        let wantsWarm = intent.desiredChanges.contains { $0.aspect == .warmth && $0.direction == .increase }
        let wantsWidth = intent.desiredChanges.contains { $0.aspect == .width }
        let toneFrequency = wantsBright ? 5_500.0 : (wantsDark ? 7_500.0 : 3_200.0)
        let toneGain = wantsDark ? -(0.7 + 1.3 * s) : (0.5 + 1.2 * s)
        let rms = analysis?.metrics["rms_dbfs"]?.value ?? -24
        return variants(
            names: ["Focused corrective", "Parallel color", "Spatial alternative"],
            summaries: ["Minimal tone and dynamics changes.", "Parallel harmonic/dynamic option.", "A restrained spatial interpretation."],
            nodeSets: [
                [node(.highPass, [.frequencyHz: 75, .q: 0.7], "Remove subsonic energy conservatively.", [.tone]), node(.parametricEQ, [.frequencyHz: toneFrequency, .q: 0.9, .gainDB: toneGain], "Apply the requested ordinary tone direction with a bounded broad band.", wantsBright ? [.brightness, .intelligibility] : (wantsDark ? [.darkness] : [.intelligibility])), node(.compressor, [.thresholdDB: min(-8, max(-40, rms + 5)), .ratio: 1.3 + 0.8 * s, .attackMS: 24, .releaseMS: 140, .makeupGainDB: 0, .kneeDB: 8, .mix: 0.72], "Use gentle signal-relative control.", [.dynamics, .attack])],
                [node(.saturation, [.driveDB: wantsWarm ? 3 + 7 * s : 2 + 4 * s, .mix: wantsWarm ? 0.12 + 0.24 * s : 0.08 + 0.14 * s], "Offer a parallel harmonic-color interpretation.", wantsWarm ? [.warmth, .body] : [.tone]), node(.compressor, [.thresholdDB: min(-8, max(-40, rms + 3)), .ratio: 1.25 + 0.65 * s, .attackMS: 34, .releaseMS: 180, .makeupGainDB: 0, .kneeDB: 10, .mix: 0.5], "Bind the colored path lightly while preserving dynamics.", [.dynamics, .attack])],
                wantsWidth
                    ? [node(.stereoWidth, [.width: 1 + 0.45 * s, .mix: 0.45], "Offer bounded stereo width while retaining the dry center.", [.width, .space]), node(.delay, [.algorithmVersion: 1, .delayTimeMS: 95, .feedback: 0.08, .damping: 0.55, .stereoCrossfeed: 0.55, .mix: 0.06 + 0.08 * s], "Add a restrained spatial alternative.", [.space])]
                    : [node(.delay, [.algorithmVersion: 1, .delayTimeMS: 105, .feedback: 0.08, .damping: 0.58, .stereoCrossfeed: 0.4, .mix: 0.05 + 0.07 * s], "Offer a restrained echo rather than assuming the user wants reverb.", [.space]), node(.reverb, [.algorithmVersion: 1, .preDelayMS: 28, .decayTimeSeconds: 0.55 + 0.45 * s, .roomSize: 0.3, .damping: 0.58, .diffusion: 0.75, .mix: 0.04 + 0.07 * s], "Offer a short low-mix room alternative.", [.space])],
            ],
            limitation: "Ordinary vocal goals are context-dependent; the three plans are hypotheses for matched audition, not automatic quality judgments."
        )
    }

    private func variants(
        names: [String],
        summaries: [String],
        nodeSets: [[NodeBlueprint]],
        boundary: [VocalProcessingBoundary] = Array(repeating: .editableDeterministicDSP, count: 3),
        limitation: String
    ) -> [Recipe] {
        (0..<3).map { index in
            Recipe(
                title: names[index],
                summary: summaries[index],
                boundary: boundary[index],
                nodes: nodeSets[index] + [limiter()],
                limitations: [limitation]
            )
        }
    }

    private func node(
        _ type: NodeType,
        _ parameters: [ParameterID: Double],
        _ rationale: String,
        _ aspects: [VocalAspect],
        confidence: Double = 0.68,
        category: ChangeCategory = .creative,
        locked: Bool = false
    ) -> NodeBlueprint {
        NodeBlueprint(
            type: type,
            parameters: parameters,
            rationale: rationale,
            confidence: confidence,
            category: category,
            locked: locked,
            aspects: aspects
        )
    }

    private func modulatedDelay(
        baseMS: Double,
        depthMS: Double,
        rateHz: Double,
        stereoPhase: Double,
        feedback: Double,
        damping: Double,
        mix: Double,
        rationale: String,
        aspects: [VocalAspect]
    ) -> NodeBlueprint {
        node(
            .modulatedDelay,
            [
                .algorithmVersion: 1,
                .delayTimeMS: baseMS,
                .modulationDepthMS: min(max(depthMS, 0), 20),
                .modulationRateHz: min(max(rateHz, 0.05), 5),
                .stereoPhaseDegrees: min(max(stereoPhase, 0), 180),
                .feedback: min(max(feedback, 0), PlanValidator.maximumFeedback),
                .damping: min(max(damping, 0), 1),
                .mix: min(max(mix, 0), 1),
            ],
            rationale,
            aspects
        )
    }

    private func limiter() -> NodeBlueprint {
        node(
            .limiter,
            [.ceilingDB: -1, .releaseMS: 80, .lookaheadMS: 0],
            "Final zero-lookahead sample-peak safety limiter; this is not used as a loudness maximizer or a true-peak guarantee.",
            [.loudness],
            confidence: 0.96,
            category: .loudness
        )
    }

    private func bindingsFor(recipe: Recipe, nodes: [ProcessingNode]) -> [VocalAspectBinding] {
        var order: [VocalAspect] = []
        var map: [VocalAspect: [UUID]] = [:]
        for (index, blueprint) in recipe.nodes.enumerated() {
            for aspect in blueprint.aspects {
                if map[aspect] == nil { order.append(aspect) }
                map[aspect, default: []].append(nodes[index].id)
            }
        }
        return order.map { aspect in
            VocalAspectBinding(
                aspect: aspect,
                nodeIDs: map[aspect, default: []],
                limitations: bindingLimitations(for: aspect)
            )
        }
    }

    private func preservationLimitations(
        for enforcement: VocalPreservationEnforcement
    ) -> [String] {
        guard !enforcement.constrainedAspects.isEmpty else { return [] }
        let aspects = enforcement.constrainedAspects.map(\.rawValue).joined(separator: ", ")
        var result = [
            "The local VocalDSPPreservationMatrix checked bounded process constraints for: \(aspects). This does not measure or certify the preserved perception."
        ]
        if !enforcement.adjustments.isEmpty {
            result.append(
                "This candidate was deterministically downgraded where needed: \(enforcement.adjustments.joined(separator: " "))"
            )
        }
        return result
    }

    private func bindingLimitations(for aspect: VocalAspect) -> [String] {
        switch aspect {
        case .pitch, .timing, .melody:
            ["This plan does not replace or claim to measure the source's \(aspect.rawValue)."]
        case .intelligibility, .consonants, .articulation:
            ["This is a processing relationship, not phoneme or lyric understanding; listening remains decisive."]
        case .space, .distance, .closeness:
            ["DSP cues do not identify or reconstruct the captured room or physical distance."]
        default:
            ["The binding identifies exact editable nodes; it does not prove the requested perception."]
        }
    }

    private func commonLimitations(for archetype: VocalCreativeArchetype) -> [String] {
        var result = [
            "The plan preserves the source samples as authority and contains no pitch replacement, timing edit, provider action, or Logic automation.",
            "Node settings are bounded deterministic hypotheses; matched audition is required to judge the singer, lyrics, arrangement, or emotional result.",
            "The final limiter is sample-peak safety only; rendered output must still be checked and no unseen true-peak guarantee is made.",
        ]
        if archetype == .vocalToBrass {
            result.append("Brass-like candidates are honest DSP coloration/hybrid plans, not acoustic reconstruction or instrument conversion.")
        }
        if archetype == .underwater {
            result.append("Every underwater candidate uses NodeType.modulatedDelay for genuine time-varying movement.")
        }
        return result
    }
}
