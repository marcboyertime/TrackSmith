import Foundation
import PlanSchema
import ProductionTutor

public struct TutorToolExecutor: Sendable {
    public typealias LogicObservationProvider = @Sendable (String) async -> TutorLogicObservation
    public typealias PriorExperimentProvider = @Sendable () async -> [TutorExperimentRecord]

    public static let maximumToolCallsPerTurn = 6
    public static let maximumToolOutputBytes = 48 * 1_024

    public let definitions: [TutorToolDefinition]
    private let knowledge: GeneralTutorKnowledgeBase
    private let procedures: TutorProcedureCatalog
    private let observeLogic: LogicObservationProvider
    private let priorExperiments: PriorExperimentProvider

    public init(
        knowledge: GeneralTutorKnowledgeBase,
        procedures: TutorProcedureCatalog,
        observeLogic: @escaping LogicObservationProvider = { _ in .unavailable },
        priorExperiments: @escaping PriorExperimentProvider = { [] }
    ) {
        self.knowledge = knowledge
        self.procedures = procedures
        self.observeLogic = observeLogic
        self.priorExperiments = priorExperiments
        self.definitions = Self.defaultDefinitions
    }

    public init(
        observeLogic: @escaping LogicObservationProvider = { _ in .unavailable },
        priorExperiments: @escaping PriorExperimentProvider = { [] }
    ) throws {
        self.init(
            knowledge: try GeneralTutorKnowledgeBase.loadValidated(),
            procedures: try TutorProcedureCatalog.loadValidated(),
            observeLogic: observeLogic,
            priorExperiments: priorExperiments
        )
    }

    public static let defaultDefinitions: [TutorToolDefinition] = [
        TutorToolDefinition(
            name: "get_current_capture_context",
            description: "Read the current TrackSmith capture identity, source scope, local measurements, listening status, and limitations. Never returns a path or audio bytes.",
            kind: .readOnly
        ),
        TutorToolDefinition(
            name: "search_production_knowledge",
            description: "Search bounded reviewed TrackSmith production claims, strategies, and teaching concepts.",
            kind: .readOnly
        ),
        TutorToolDefinition(
            name: "get_logic_procedure",
            description: "Retrieve one reviewed, user-performed Logic procedure by ID or a short query. Procedures never grant execution authority.",
            kind: .readOnly
        ),
        TutorToolDefinition(
            name: "retrieve_prior_experiments",
            description: "Read this user's locally persisted Tutor experiments and explicit outcomes for the current conversation.",
            kind: .readOnly
        ),
        TutorToolDefinition(
            name: "inspect_logic",
            description: "Request a fresh read-only semantic observation of visible Logic UI. Returns unavailable states honestly and cannot press, set, or change controls.",
            kind: .readOnly
        ),
        TutorToolDefinition(
            name: "present_experiment",
            description: "Present one reversible user-performed experiment as a compact card. This formats advice only and performs no Logic or Audio Unit action.",
            kind: .presentationOnly
        ),
    ]

    public func execute(
        _ call: TutorToolCall,
        context: TutorRuntimeContext
    ) async throws -> TutorToolResult {
        guard definitions.contains(where: { $0.name == call.name }) else {
            throw TutorConversationError.unknownTool(call.name)
        }
        let arguments = try parseArguments(call.argumentsJSON)
        switch call.name {
        case "get_current_capture_context":
            return try captureContext(call: call, context: context)
        case "search_production_knowledge":
            return try searchKnowledge(call: call, arguments: arguments, sourceType: context.sourceType)
        case "get_logic_procedure":
            return try procedure(call: call, arguments: arguments, sourceType: context.sourceType)
        case "retrieve_prior_experiments":
            return try await experimentHistory(call: call, arguments: arguments)
        case "inspect_logic":
            return try await logicObservation(call: call, arguments: arguments)
        case "present_experiment":
            return try presentExperiment(call: call, arguments: arguments)
        default:
            throw TutorConversationError.unknownTool(call.name)
        }
    }

    private func captureContext(
        call: TutorToolCall,
        context: TutorRuntimeContext
    ) throws -> TutorToolResult {
        guard let capture = context.capture else {
            let evidence = TutorEvidenceReference(
                kind: .unavailable,
                label: "No current capture",
                detail: "No current TrackSmith capture is attached. Ask the user to play the relevant section and press Listen to recent playback."
            )
            return try result(call, object: [
                "available": false,
                "reason": evidence.detail,
            ], evidence: [evidence])
        }
        let measurements: [[String: Any]] = capture.metrics.map {
            [
                "identifier": $0.identifier,
                "value": $0.value,
                "unit": $0.unit,
                "confidence": $0.confidence,
                "interpretation_boundary": $0.interpretationBoundary,
            ]
        }
        var evidence = capture.metrics.prefix(8).map {
            TutorEvidenceReference(
                kind: .locallyMeasured,
                label: $0.identifier,
                detail: "Local descriptive measurement; \($0.interpretationBoundary)",
                confidence: $0.confidence,
                captureSnapshotID: capture.captureSnapshotID,
                metricIdentifier: $0.identifier
            )
        }
        switch capture.cloudListening.status {
        case .listened:
            if let summary = capture.cloudListening.summary {
                evidence.append(TutorEvidenceReference(
                    kind: .heardByModel,
                    label: "Model listened to bounded capture",
                    detail: summary,
                    captureSnapshotID: capture.captureSnapshotID
                ))
            }
        case .consentDenied, .notRequested, .unavailable:
            evidence.append(TutorEvidenceReference(
                kind: .unavailable,
                label: "Model listening not used",
                detail: capture.cloudListening.status.rawValue,
                captureSnapshotID: capture.captureSnapshotID
            ))
        }
        return try result(call, object: [
            "available": true,
            "source_type": capture.sourceType.rawValue,
            "scope": capture.scopeDescription,
            "capture_snapshot_id": capture.captureSnapshotID.uuidString,
            "captured_at": ISO8601DateFormatter().string(from: capture.capturedAt),
            "duration_seconds": capture.durationSeconds,
            "is_live": capture.isLive,
            "local_measurements": measurements,
            "local_analysis_limitations": capture.localAnalysisLimitations,
            "model_listening_status": capture.cloudListening.status.rawValue,
            "model_listening_summary": capture.cloudListening.summary ?? NSNull(),
        ], evidence: evidence)
    }

    private func searchKnowledge(
        call: TutorToolCall,
        arguments: [String: Any],
        sourceType: PlanSchema.SourceType
    ) throws -> TutorToolResult {
        let query = try requiredString("query", in: arguments)
        let tokens = queryTokens(query)
        guard !tokens.isEmpty else {
            throw TutorConversationError.invalidToolArguments("query")
        }
        var matches: [(score: Int, kind: String, id: String, payload: [String: Any], sourceIDs: [String])] = []

        for claim in knowledge.claims where claim.reviewState.isTrusted {
            let text = ([claim.claimText] + claim.conditions + claim.limitations).joined(separator: " ")
            var score = lexicalScore(tokens, text)
            guard score > 0 else { continue }
            if claim.applicableSourceTypes.contains(sourceType) { score += 3 }
            matches.append((score, "claim", claim.id, [
                "id": claim.id,
                "kind": "reviewed_claim",
                "claim": claim.claimText,
                "conditions": Array(claim.conditions.prefix(4)),
                "limitations": Array(claim.limitations.prefix(4)),
                "listening_remains_decisive": claim.listeningRemainsDecisive,
                "source_id": claim.sourceID,
            ], [claim.sourceID]))
        }
        for strategy in knowledge.strategies where strategy.reviewState.isTrusted {
            let text = ([strategy.label, strategy.problemOrOutcome, strategy.recommendedFirstExperiment, strategy.whyItMayHelp]
                + strategy.usefulWhen + strategy.notUsefulWhen).joined(separator: " ")
            var score = lexicalScore(tokens, text)
            guard score > 0 else { continue }
            if strategy.applicableSourceTypes.contains(sourceType) { score += 3 }
            let sourceIDs = strategy.supportingClaimIDs.compactMap { knowledge.claim($0)?.sourceID }
            matches.append((score, "strategy", strategy.id, [
                "id": strategy.id,
                "kind": "reviewed_strategy",
                "label": strategy.label,
                "useful_when": Array(strategy.usefulWhen.prefix(4)),
                "not_useful_when": Array(strategy.notUsefulWhen.prefix(4)),
                "first_experiment": strategy.recommendedFirstExperiment,
                "why": strategy.whyItMayHelp,
                "tradeoffs": Array(strategy.tradeoffs.prefix(4)),
                "stop_rules": Array(strategy.stoppingRules.prefix(4)),
                "related_procedure_ids": Array(strategy.relatedProcedureIDs.prefix(4)),
            ], sourceIDs))
        }
        for concept in knowledge.concepts where concept.reviewState.isTrusted {
            let text = ([concept.term, concept.simpleExplanation, concept.causalExplanation]
                + concept.aliases + concept.whereItMatters).joined(separator: " ")
            let score = lexicalScore(tokens, text)
            guard score > 0 else { continue }
            matches.append((score, "concept", concept.id, [
                "id": concept.id,
                "kind": "reviewed_concept",
                "term": concept.term,
                "simple_explanation": concept.simpleExplanation,
                "causal_explanation": concept.causalExplanation,
                "common_misunderstanding": concept.commonMisunderstanding,
                "practical_example": concept.practicalExample,
            ], concept.sourceIDs))
        }
        let selected = matches.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            return $0.id < $1.id
        }.prefix(6)
        let evidence = selected.map {
            TutorEvidenceReference(
                kind: .reviewedKnowledge,
                label: $0.id,
                detail: "Reviewed TrackSmith \($0.kind); sources: \($0.sourceIDs.prefix(4).joined(separator: ", "))"
            )
        }
        return try result(call, object: [
            "query": query,
            "matches": selected.map { $0.payload },
            "coverage_note": selected.isEmpty
                ? "No reviewed local match. The Tutor may use general knowledge but must label uncertainty."
                : "These are reviewed local references, not proof that one treatment is correct for this audio.",
        ], evidence: evidence)
    }

    private func procedure(
        call: TutorToolCall,
        arguments: [String: Any],
        sourceType: PlanSchema.SourceType
    ) throws -> TutorToolResult {
        let identifier = optionalString("procedure_id", in: arguments)
        let query = optionalString("query", in: arguments)
        let selected: TutorProcedure?
        if let identifier, !identifier.isEmpty {
            selected = procedures.procedure(identifier)
        } else if let query, !query.isEmpty {
            let tokens = queryTokens(query)
            var scored: [(procedure: TutorProcedure, score: Int)] = []
            for candidate in procedures.procedures {
                let stepText = candidate.steps.flatMap { [$0.title, $0.instruction, $0.listenFor] }
                let searchable = ([candidate.id] + candidate.processorIdentities + stepText).joined(separator: " ")
                let lexical = lexicalScore(tokens, searchable)
                guard lexical > 0 else { continue }
                let sourceBonus = candidate.supportedSourceTypes.contains(sourceType) ? 3 : 0
                let score = lexical + sourceBonus
                if score > 0 { scored.append((candidate, score)) }
            }
            scored.sort { lhs, rhs in
                lhs.score == rhs.score ? lhs.procedure.id < rhs.procedure.id : lhs.score > rhs.score
            }
            selected = scored.first?.procedure
        } else {
            throw TutorConversationError.invalidToolArguments("procedure_id or query")
        }
        guard let selected else {
            return try result(call, object: [
                "found": false,
                "reason": "No reviewed exact procedure matched. Do not invent a Logic path or claim direct verification.",
            ], evidence: [TutorEvidenceReference(
                kind: .unavailable,
                label: "No exact reviewed procedure",
                detail: "Exact Logic procedure coverage was unavailable for this query."
            )])
        }
        let steps: [[String: Any]] = selected.steps.prefix(8).map { step in
            var object: [String: Any] = [
                "id": step.id,
                "title": step.title,
                "instruction": step.instruction,
                "substeps": Array(step.substeps.prefix(6)),
                "listen_for": step.listenFor,
                "why": step.reason,
                "risk": step.commonSideEffect,
                "stop_condition": step.stopCondition,
                "undo": step.undoInstruction,
                "actor": step.actor.rawValue,
            ]
            if let location = step.location {
                let processor: Any = location.processorIdentity.map { $0 as Any } ?? NSNull()
                let control: Any = location.controlIdentity.map { $0 as Any } ?? NSNull()
                object["logic_location"] = [
                    "logic_version": location.logicVersion,
                    "work_area": location.workArea,
                    "object_scope": location.objectScope,
                    "processor": processor,
                    "control": control,
                    "navigation_labels": location.navigationLabels,
                    "required_focus": location.requiredFocusOrSelection,
                    "verification": location.verification.rawValue,
                ]
            }
            object["parameters"] = step.parameters.prefix(6).map { parameter in
                [
                    "control": parameter.controlIdentity,
                    "unit": parameter.unit.rawValue,
                    "start": parameter.safeStartingValue ?? NSNull(),
                    "minimum": parameter.minimumValue ?? NSNull(),
                    "maximum": parameter.maximumValue ?? NSNull(),
                    "method": parameter.adjustmentMethod.rawValue,
                    "stop": parameter.stopCondition,
                    "rollback": parameter.rollbackValueDescription,
                ] as [String: Any]
            }
            return object
        }
        return try result(call, object: [
            "found": true,
            "procedure_id": selected.id,
            "logic_version_scope": selected.logicVersionScope,
            "steps": steps,
            "preservation_requirements": selected.preservationRequirements,
            "stopping_rules": selected.stoppingRules,
            "contraindications": selected.contraindications,
            "subjective_listening_boundary": selected.subjectiveListeningBoundary,
            "grants_execution_authority": selected.grantsExecutionAuthority,
        ], evidence: [TutorEvidenceReference(
            kind: .reviewedKnowledge,
            label: selected.id,
            detail: "Reviewed Logic procedure for user-performed actions; execution authority is false."
        )])
    }

    private func experimentHistory(
        call: TutorToolCall,
        arguments: [String: Any]
    ) async throws -> TutorToolResult {
        let query = optionalString("query", in: arguments) ?? ""
        let requested = (arguments["max_results"] as? Int) ?? 6
        let limit = min(max(requested, 1), 10)
        let tokens = queryTokens(query)
        let candidates = await priorExperiments()
        let selected = candidates.filter { experiment in
            tokens.isEmpty || lexicalScore(tokens, [
                experiment.draft.title,
                experiment.draft.action,
                experiment.userNote ?? "",
                experiment.outcome?.rawValue ?? "",
            ].joined(separator: " ")) > 0
        }.suffix(limit)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Array(selected))
        let object = try JSONSerialization.jsonObject(with: data)
        let evidence = selected.map {
            TutorEvidenceReference(
                kind: .userReported,
                label: $0.draft.title,
                detail: "Persisted user outcome: \($0.outcome?.rawValue ?? "not yet reported")."
            )
        }
        return try result(call, object: [
            "query": query,
            "experiments": object,
            "personal_only": true,
            "note": "These outcomes belong to this user and are not universal production facts.",
        ], evidence: evidence)
    }

    private func logicObservation(
        call: TutorToolCall,
        arguments: [String: Any]
    ) async throws -> TutorToolResult {
        let query = try requiredString("query", in: arguments)
        let observation = await observeLogic(query)
        let controls: [[String: Any]] = observation.controls.prefix(40).map { control in
            [
                "role": control.role,
                "label": control.label,
                "value": control.value ?? NSNull(),
            ]
        }
        let object: [String: Any] = [
            "status": observation.status.rawValue,
            "application_name": observation.applicationName ?? NSNull(),
            "bundle_identifier": observation.bundleIdentifier ?? NSNull(),
            "controls": controls,
            "limitation": observation.limitation,
            "observed_at": ISO8601DateFormatter().string(from: observation.observedAt),
            "privacy_boundary": "Window/project titles and screen coordinates are retained locally and are not supplied to the model.",
        ]
        let kind: TutorEvidenceKind = observation.status == .observed ? .logicObserved : .unavailable
        return try result(call, object: [
            "query": query,
            "observation": object,
            "read_only": true,
            "mutation_capability": false,
        ], evidence: [TutorEvidenceReference(
            kind: kind,
            label: observation.status == .observed ? "Visible Logic UI observed" : "Logic observation unavailable",
            detail: observation.limitation
        )])
    }

    private func presentExperiment(
        call: TutorToolCall,
        arguments: [String: Any]
    ) throws -> TutorToolResult {
        let experiment = TutorExperimentDraft(
            title: try boundedRequiredString("title", in: arguments, maximum: 160),
            logicLocation: try boundedRequiredString("logic_location", in: arguments, maximum: 600),
            action: try boundedRequiredString("action", in: arguments, maximum: 1_200),
            startingRange: try boundedRequiredString("starting_range", in: arguments, maximum: 300),
            listenFor: try boundedRequiredString("listen_for", in: arguments, maximum: 800),
            why: try boundedRequiredString("why", in: arguments, maximum: 800),
            risk: try boundedRequiredString("risk", in: arguments, maximum: 600),
            undo: try boundedRequiredString("undo", in: arguments, maximum: 600),
            visualTargetQuery: optionalString("visual_target_query", in: arguments)
        )
        return try result(call, object: [
            "accepted": true,
            "experiment_id": experiment.id.uuidString,
            "boundary": "The card is advice only. The user performs every Logic edit; TrackSmith performed no mutation.",
        ], experiment: experiment)
    }

    private func result(
        _ call: TutorToolCall,
        object: Any,
        evidence: [TutorEvidenceReference] = [],
        experiment: TutorExperimentDraft? = nil
    ) throws -> TutorToolResult {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard data.count <= Self.maximumToolOutputBytes else {
            throw TutorConversationError.responseTooLarge
        }
        return TutorToolResult(
            call: call,
            outputJSON: String(decoding: data, as: UTF8.self),
            evidence: evidence,
            experiment: experiment
        )
    }

    private func parseArguments(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8), data.count <= 16 * 1_024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TutorConversationError.invalidToolArguments("malformed JSON")
        }
        return object
    }

    private func requiredString(_ key: String, in arguments: [String: Any]) throws -> String {
        guard let value = arguments[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TutorConversationError.invalidToolArguments(key)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func boundedRequiredString(
        _ key: String,
        in arguments: [String: Any],
        maximum: Int
    ) throws -> String {
        let value = try requiredString(key, in: arguments)
        guard value.utf8.count <= maximum else {
            throw TutorConversationError.invalidToolArguments(key)
        }
        return value
    }

    private func optionalString(_ key: String, in arguments: [String: Any]) -> String? {
        guard let value = arguments[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func queryTokens(_ value: String) -> Set<String> {
        Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 })
    }

    private func lexicalScore(_ tokens: Set<String>, _ text: String) -> Int {
        let haystack = queryTokens(text)
        return tokens.reduce(0) { $0 + (haystack.contains($1) ? 2 : 0) }
    }
}
