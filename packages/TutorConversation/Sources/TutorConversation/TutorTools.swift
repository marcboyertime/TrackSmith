import CryptoKit
import Foundation
import PlanSchema
import ProductionTutor

/// Shares the lower-authority indexed reader between every live tool executor.
/// The task intentionally owns its own lifetime: a cancelled caller must not
/// cancel a warmup another turn may still need.
private struct CandidateCorpusLoadResult: Sendable {
    let availability: CandidateRetrievalAvailability
    let retriever: (any CandidateRetriever)?
}

private actor CandidateCorpusLoader {
    private var loadTask: Task<CandidateCorpusLoadResult, Never>?

    func warmup() async {
        _ = await corpus()
    }

    func corpus() async -> CandidateCorpusLoadResult {
        if let loadTask {
            return await loadTask.value
        }

        let task = Task.detached(priority: .utility) {
            let opened = CandidateRetrievalIndex.openBundled()
            return CandidateCorpusLoadResult(availability: opened.availability, retriever: opened.retriever)
        }
        loadTask = task
        return await task.value
    }
}

public struct TutorToolExecutor: Sendable {
    public typealias LogicObservationProvider = @Sendable (String) async -> TutorLogicObservation
    public typealias PriorExperimentProvider = @Sendable () async -> [TutorExperimentRecord]

    public static let maximumToolCallsPerTurn = 6
    public static let maximumToolOutputBytes = 48 * 1_024
    public static let maximumCandidateCorpusOutputBytes = 16 * 1_024

    public let definitions: [TutorToolDefinition]
    private let knowledge: GeneralTutorKnowledgeBase
    private let procedures: TutorProcedureCatalog
    private let candidateCorpus: CommunityCandidateCorpus?
    // Narrow test seam for availability/state matrices. It is never surfaced
    // through the model schema or production construction path.
    private let injectedCandidateRetriever: (any CandidateRetriever)?
    private let candidateCorpusLoader: CandidateCorpusLoader?
    private let observeLogic: LogicObservationProvider
    private let priorExperiments: PriorExperimentProvider

    public init(
        knowledge: GeneralTutorKnowledgeBase,
        procedures: TutorProcedureCatalog,
        candidateCorpus: CommunityCandidateCorpus? = nil,
        candidateRetriever: (any CandidateRetriever)? = nil,
        observeLogic: @escaping LogicObservationProvider = { _ in .unavailable },
        priorExperiments: @escaping PriorExperimentProvider = { [] }
    ) {
        self.knowledge = knowledge
        self.procedures = procedures
        self.candidateCorpus = candidateCorpus
        self.injectedCandidateRetriever = candidateRetriever
        // Supplying this initializer, including with an explicit nil corpus,
        // remains a deterministic injected-corpus test path. Live construction
        // uses the separate loader-backed initializer below.
        self.candidateCorpusLoader = nil
        self.observeLogic = observeLogic
        self.priorExperiments = priorExperiments
        self.definitions = Self.defaultDefinitions
    }

    public init(
        observeLogic: @escaping LogicObservationProvider = { _ in .unavailable },
        priorExperiments: @escaping PriorExperimentProvider = { [] }
    ) throws {
        self.knowledge = try GeneralTutorKnowledgeBase.loadValidated()
        self.procedures = try TutorProcedureCatalog.loadValidated()
        self.candidateCorpus = nil
        self.injectedCandidateRetriever = nil
        // Candidate material is strictly lower authority. Its compact indexed
        // reader opens off the construction path; it never decodes or indexes
        // the full JSON projection at launch or query time.
        self.candidateCorpusLoader = CandidateCorpusLoader()
        self.observeLogic = observeLogic
        self.priorExperiments = priorExperiments
        self.definitions = Self.defaultDefinitions
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
            name: "search_candidate_corpus",
            description: "Search bounded unreviewed candidate hypotheses: one primary card plus compact alternatives or disagreements when relevant. It is not factual or exact Logic authority.",
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

    /// Starts the shared lower-authority corpus work without making a caller
    /// wait on it during Tutor/session construction.
    public func warmupCandidateCorpus() async {
        guard let candidateCorpusLoader else { return }
        await candidateCorpusLoader.warmup()
    }

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
        case "search_candidate_corpus":
            return try await searchCandidateCorpus(call: call, arguments: arguments)
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
        let audioIntelligence: [String: Any]
        if let local = capture.audioIntelligence {
            audioIntelligence = [
                "provider": local.providerIdentifier,
                "received_original_waveform_bytes": local.receivedOriginalWaveformBytes,
                "waveform_binding_status": local.waveformBindingStatus?.rawValue ?? "legacy_unknown",
                "source_provenance": local.sourceProvenance,
                "failure": local.failure ?? NSNull(),
                "limitations": local.limitations,
                "calibrated_tasks": local.capabilities.filter(\.calibrated).map(\.task.rawValue),
            ]
            evidence.append(TutorEvidenceReference(
                kind: .locallyMeasured,
                label: "Exact local waveform analysis",
                detail: local.failure ?? "Exact WAV bytes were measured locally; this is not model listening.",
                captureSnapshotID: capture.captureSnapshotID
            ))
        } else {
            audioIntelligence = ["available": false, "reason": "No exact waveform-specialist result is attached to this turn."]
        }
        return try result(call, object: [
            "available": true,
            "source_type": capture.sourceType.rawValue,
            "scope": capture.scopeDescription,
            "format": capture.formatDescription ?? NSNull(),
            "capture_snapshot_id": capture.captureSnapshotID.uuidString,
            "captured_at": ISO8601DateFormatter().string(from: capture.capturedAt),
            "duration_seconds": capture.durationSeconds,
            "is_live": capture.isLive,
            "local_measurements": measurements,
            "local_analysis_limitations": capture.localAnalysisLimitations,
            "model_listening_status": capture.cloudListening.status.rawValue,
            "model_listening_summary": capture.cloudListening.summary ?? NSNull(),
            "audio_intelligence": audioIntelligence,
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

    /// Candidate retrieval ranks user paraphrases and canonical card language,
    /// then collapses every result to exactly one canonical card. It does not
    /// expose candidate procedure bodies or treat the result as reviewed truth.
    private func searchCandidateCorpus(
        call: TutorToolCall,
        arguments: [String: Any]
    ) async throws -> TutorToolResult {
        if Task.isCancelled { throw TutorConversationError.cancelled }
        let query = try requiredString("query", in: arguments)
        let domain = optionalString("domain", in: arguments)
        let category = optionalString("category", in: arguments)
        let sourceType = optionalString("source_type", in: arguments)
        let evidenceClass = optionalString("evidence_class", in: arguments)
        let logicVersion = optionalString("logic_version", in: arguments)
        let currentContext = arguments["current_context"] as? Bool
        let role = optionalString("role", in: arguments)
        let section = optionalString("section", in: arguments)
        let goal = optionalString("goal", in: arguments)
        let object = optionalString("object", in: arguments)
        let priorExperiment = optionalString("prior_experiment", in: arguments)
        let evidenceHint = optionalString("evidence", in: arguments)
        let loadedCandidateCorpus: CommunityCandidateCorpus?
        let indexedRetriever: (any CandidateRetriever)?
        let availability: CandidateRetrievalAvailability
        if let candidateRetriever = injectedCandidateRetriever {
            loadedCandidateCorpus = nil
            indexedRetriever = candidateRetriever
            availability = await candidateRetriever.availability()
        } else if let candidateCorpus {
            loadedCandidateCorpus = candidateCorpus
            indexedRetriever = nil
            availability = .ready
        } else if let candidateCorpusLoader {
            if Task.isCancelled { throw TutorConversationError.cancelled }
            let loaded = await candidateCorpusLoader.corpus()
            loadedCandidateCorpus = nil
            indexedRetriever = loaded.retriever
            availability = loaded.availability
            if Task.isCancelled { throw TutorConversationError.cancelled }
        } else {
            loadedCandidateCorpus = nil
            indexedRetriever = nil
            availability = .unavailable
        }
        guard availability == .ready, loadedCandidateCorpus != nil || indexedRetriever != nil else {
            let outcome: CandidateRetrievalOutcomeKind
            switch availability {
            case .ready: outcome = .unavailable
            case .unavailable: outcome = .unavailable
            case .corrupt: outcome = .corrupt
            case .schemaDrift: outcome = .schemaDrift
            case .versionMismatch: outcome = .versionMismatch
            case .disabled: outcome = .disabled
            }
            return try result(call, object: [
                "query": query,
                "match": NSNull(),
                "availability": availability.rawValue,
                "outcome": outcome.rawValue,
                "coverage_note": "The local candidate corpus is unavailable. Do not substitute exact Logic instructions.",
            ], evidence: [TutorEvidenceReference(
                kind: .unavailable,
                label: "Candidate corpus unavailable",
                detail: "Candidate retrieval is \(availability.rawValue)."
            )])
        }
        let filters = CommunityCandidateCorpusFilters(domain: domain, category: category, sourceType: sourceType, evidenceClass: evidenceClass, logicVersion: logicVersion, currentContext: currentContext, role: role, section: section)
        // Context is retrieval evidence only; it does not turn a candidate into
        // reviewed knowledge or a deterministic alias identity.
        let retrievalQuery = [query, goal, object, priorExperiment, evidenceHint].compactMap { $0 }.joined(separator: " ")
        let rankings: [CommunityCandidateCorpusRankedCard]
        let retrievalOutcome: CandidateRetrievalOutcomeKind
        let retrievalMode: String
        if let candidateCorpus = loadedCandidateCorpus {
            // Injection is reserved for tests: legacy JSON/token ranking remains
            // a migration oracle and is never constructed by the live path.
            rankings = candidateCorpus.ranked(query: retrievalQuery, filters: filters, limit: 4)
            retrievalOutcome = rankings.isEmpty ? .noMatch : .matches
            retrievalMode = "legacy_test_oracle"
        } else if let indexedRetriever {
            let outcome = await indexedRetriever.rankedOutcome(query: retrievalQuery, filters: filters, limit: 4)
            rankings = outcome.cards
            retrievalOutcome = outcome.kind
            retrievalMode = "indexed_bm25_general_rerank_provisional"
        } else {
            rankings = []
            retrievalOutcome = .unavailable
            retrievalMode = "unavailable"
        }
        if Task.isCancelled { throw TutorConversationError.cancelled }
        guard let ranking = rankings.first else {
            let safeReason: String
            switch retrievalOutcome {
            case .noMatch:
                safeReason = "No candidate canonical card matched. Do not invent a candidate procedure or Logic path."
            case .queryFailed, .malformedSelectedPayload, .schemaDrift, .corrupt, .disabled, .unavailable, .versionMismatch:
                safeReason = "Candidate retrieval could not complete. Continue with honest general teaching or ask a decision-changing question; do not substitute exact Logic instructions."
            case .matches:
                safeReason = "No candidate canonical card matched. Do not invent a candidate procedure or Logic path."
            }
            return try result(call, object: [
                "query": query,
                "match": NSNull(),
                "availability": availability.rawValue,
                "outcome": retrievalOutcome.rawValue,
                "coverage_note": safeReason,
            ], evidence: retrievalOutcome == .noMatch ? [] : [TutorEvidenceReference(
                kind: .unavailable,
                label: "Candidate retrieval unavailable for this query",
                detail: "Candidate retrieval outcome is \(retrievalOutcome.rawValue)."
            )])
        }
        let selected = ranking.card
        guard let packageDescriptor = CommunityCandidateCorpusGenerated.descriptors.first(where: { $0.packageID == selected.packageID }), packageDescriptor.packageSequence > 0 else {
            throw TutorConversationError.invalidToolArguments("candidate corpus descriptor")
        }
        let contradictionPayload: [[String: Any]] = selected.contradictions.prefix(1).map {
            ["summary": $0.summary, "what_decides": $0.whatDecides, "tutor_behavior": $0.tutorBehavior, "source_evidence_classes": $0.sourceEvidenceClasses ?? []]
        }
        let mythPayload: [[String: Any]] = selected.myths.prefix(2).map {
            ["myth": $0.myth, "correction": $0.correction, "source_evidence_classes": $0.sourceEvidenceClasses ?? []]
        }
        var payload: [String: Any] = [
            "domain": selected.domain,
            "category": selected.category,
            "topic": selected.topic ?? NSNull(),
            "title": selected.title,
            "question": selected.question,
            "original_review_status": selected.originalReviewStatus ?? NSNull(),
            "clarification_questions": selected.clarificationQuestions,
            "competing_hypotheses": selected.competingHypotheses,
            "recommended_first_experiment": selected.recommendedFirstExperiment,
            "rationale": selected.rationale,
            "listening_cues": selected.listeningCues,
            "stop_or_undo": selected.stopOrUndo,
            "tradeoffs": selected.tradeoffs,
            "teaching_principle": selected.teachingPrinciple,
            "numeric_guidance_policy": selected.numericGuidancePolicy,
            "source_types": Array(selected.sourceTypes.prefix(6)),
            "tags": Array(selected.tags.prefix(12)),
            "evidence_class": selected.evidenceClass,
            "logic_version": selected.logicVersion ?? NSNull(),
            "current_context": selected.currentContext,
            "subcategory": selected.subcategory ?? NSNull(),
            "tracksmith_domains": selected.tracksmithDomains ?? [],
            "preservation_goals": selected.preservationGoals ?? [],
            "non_dsp_possibilities": selected.nonDSPPossibilities ?? [],
            "starting_points": selected.startingPoints ?? [],
            "common_mistakes": selected.commonMistakes ?? [],
            "role_facets": selected.roleFacets ?? [],
            "section_facets": selected.sectionFacets ?? [],
            "direct_candidate_answer": selected.directCandidateAnswer ?? NSNull(),
            "key_distinction": selected.keyDistinction ?? NSNull(),
            "first_experiment": selected.firstExperiment ?? NSNull(),
            "listen_for": selected.listenFor ?? NSNull(),
            "non_automation_possibilities": selected.nonAutomationPossibilities ?? [],
            "non_processing_possibilities": selected.nonProcessingPossibilities ?? [],
            "evidence_needed": selected.evidenceNeeded ?? [],
            "user_intent": selected.userIntent ?? NSNull(),
            "retrieval_outcome": retrievalOutcome.rawValue,
            "authoritative_supporting_source_ids": selected.authoritativeSupportingSourceIDs ?? [],
            "primary_research_source_ids": selected.primaryResearchSourceIDs ?? [],
            "professional_practice_source_ids": selected.professionalPracticeSourceIDs,
            "discovery_language_source_ids": selected.discoveryLanguageSourceIDs,
            "contradictions": contradictionPayload,
            "myths": mythPayload,
        ]
        // Only P9 currently projects this optional partition.  Keep every
        // legacy package payload byte-for-byte shaped as before, and never
        // merge standards into a differently classified source partition.
        let standardsSourceIDs = selected.standardsSourceIDs ?? []
        if !standardsSourceIDs.isEmpty {
            payload["standards_source_ids"] = standardsSourceIDs
        }
        // Runtime status-free descriptors also exclude authority/procedure
        // labels from the live candidate-tool shape. Their raw review and
        // provenance records remain outside the runtime bundle.
        if packageDescriptor.runtimeStatusFree {
            ["original_review_status", "authoritative_supporting_source_ids"].forEach {
                payload.removeValue(forKey: $0)
            }
        }
        let selectedIDs = rankings.map(\.card.id)
        var sourceIDs: [String] = []
        for candidate in rankings {
            var values: [String] = []
            values.append(contentsOf: candidate.card.authoritativeSupportingSourceIDs ?? [])
            values.append(contentsOf: candidate.card.primaryResearchSourceIDs ?? [])
            values.append(contentsOf: candidate.card.professionalPracticeSourceIDs)
            values.append(contentsOf: candidate.card.discoveryLanguageSourceIDs)
            values.append(contentsOf: candidate.card.standardsSourceIDs ?? [])
            for value in values where !sourceIDs.contains(value) && sourceIDs.count < 6 { sourceIDs.append(value) }
        }
        // Candidate source provenance is useful context, but model-facing
        // output is deliberately capped across the complete aggregate result.
        let selectedSourceSet = Set(sourceIDs)
        ["authoritative_supporting_source_ids", "primary_research_source_ids", "professional_practice_source_ids", "discovery_language_source_ids", "standards_source_ids"].forEach { key in
            if let values = payload[key] as? [String] { payload[key] = values.filter(selectedSourceSet.contains) }
        }
        let summaryMatches: [[String: Any]] = rankings.map { candidate in
            ["domain": candidate.card.domain, "title": candidate.card.title,
             "score": candidate.score, "first_experiment": candidate.card.recommendedFirstExperiment]
        }
        let querySHA256 = SHA256.hash(data: Data(retrievalQuery.utf8)).map { String(format: "%02x", $0) }.joined()
        let retrievalID = SHA256.hash(data: Data(("package019-bm25-ordered6-domain-diverse/1|" + querySHA256 + "|" + selectedIDs.joined(separator: ",")).utf8)).map { String(format: "%02x", $0) }.joined()
        let output: [String: Any] = [
            "query": query, "availability": availability.rawValue, "match": payload, "matches": summaryMatches,
            "retrieval_mode": retrievalMode,
            "deduplicated_candidate_count": min(ranking.deduplicatedCandidates, 8),
            "retrieval_diagnostics": [
                "top_score": ranking.score,
                "lexical_overlap": ranking.lexicalOverlap,
                "lexical_coverage": ranking.lexicalCoverage,
                "top_margin": ranking.scoreMargin,
                "ambiguous": ranking.ambiguity,
            ],
            "coverage_note": "Bounded unreviewed candidate cards, selected by context and diversity. This is lexical structured retrieval, not completed semantic retrieval. Use it for candidate hypotheses and a reversible experiment only; get exact Logic instructions only from get_logic_procedure.",
        ]
        let resultSHA256 = SHA256.hash(data: try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])).map { String(format: "%02x", $0) }.joined()
        let evidence = TutorEvidenceReference(
            kind: .candidateKnowledge,
            label: selected.id,
            detail: "Unreviewed candidate corpus material; not factual or exact Logic authority.",
            candidateCorpusProvenance: {
                var provenance=TutorCandidateCorpusProvenance(
                packageID: selected.packageID,
                packageVersion: selected.version,
                packageSequence: packageDescriptor.packageSequence,
                recordID: selected.id
                )
                provenance.querySHA256=querySHA256
                let ordinarySourceIDs = (selected.authoritativeSupportingSourceIDs ?? []) + (selected.primaryResearchSourceIDs ?? []) + selected.professionalPracticeSourceIDs + selected.discoveryLanguageSourceIDs
                provenance.selectedDomain=selected.domain; provenance.sourceIDs=Array((ordinarySourceIDs + standardsSourceIDs).prefix(6))
                provenance.standardsSourceIDs=standardsSourceIDs.isEmpty ? nil : standardsSourceIDs
                provenance.reviewState=selected.originalReviewStatus
                provenance.resultSHA256=resultSHA256
                provenance.selectedRecordIDs=Array(selectedIDs.prefix(4)); provenance.retrievalID=retrievalID; provenance.corpusVersion="p16-runtime-projection-6212"; provenance.policyVersion="package019-bm25-ordered6-domain-diverse/1"; provenance.omissions=["exact_fixture_identity", "ambiguous_alias_authority", "candidate_procedures", "development_only_index", "evaluation_data"]
                return provenance
            }()
        )
        guard try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]).count <= Self.maximumCandidateCorpusOutputBytes else {
            throw TutorConversationError.responseTooLarge
        }
        if Task.isCancelled { throw TutorConversationError.cancelled }
        return try result(call, object: output, evidence: [evidence])
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
            // Kept optional for persisted/pre-P19 calls, but never permit the
            // general argument envelope to turn a receipt field into a large
            // unbounded model-controlled payload.
            stopCondition: try optionalBoundedString("stop_condition", in: arguments, maximum: 600) ?? "Stop if the stated risk appears or the result is worse; undo the single change.",
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

    private func optionalBoundedString(
        _ key: String,
        in arguments: [String: Any],
        maximum: Int
    ) throws -> String? {
        guard let value = optionalString(key, in: arguments) else { return nil }
        guard value.utf8.count <= maximum else {
            throw TutorConversationError.invalidToolArguments(key)
        }
        return value
    }

    private func queryTokens(_ value: String) -> Set<String> {
        Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 })
    }

    private func lexicalScore(_ tokens: Set<String>, _ text: String) -> Int {
        let haystack = queryTokens(text)
        return tokens.reduce(0) { $0 + (haystack.contains($1) ? 2 : 0) }
    }
}
