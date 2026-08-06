import AudioAnalysis
import Foundation
import PlanSchema

/// Maps question domains to the measurements that can actually say something
/// about them. This is the fix for Tutor v1's conceptual gap, where a capture
/// was displayed as evidence without influencing the lesson.
public struct MeasurementRelevanceMap: Sendable {
    public init() {}

    /// Metrics that can materially support reasoning in a domain, with what
    /// they can and cannot establish.
    public static let relevance: [ProductionDomain: [String]] = [
        .clipping: ["peak_dbfs", "clipped_sample_count", "crest_factor_db"],
        .gainStaging: ["peak_dbfs", "rms_dbfs", "crest_factor_db"],
        .loudness: ["integrated_loudness_lufs", "short_term_loudness_lufs_timeline", "true_peak_dbtp"],
        .peaks: ["true_peak_dbtp", "peak_dbfs"],
        .masterDynamics: ["loudness_range_lu", "crest_factor_db"],
        .mixDynamics: ["loudness_range_lu", "crest_factor_db", "level_variability_p90_p10_db"],
        .compression: ["level_variability_p90_p10_db", "crest_factor_db"],
        .noise: ["rms_dbfs", "peak_dbfs"],
        .monoCompatibility: ["stereo_correlation", "mono_sum_energy_ratio", "side_energy_share"],
        .stereoImaging: ["stereo_correlation", "side_energy_share", "low_band_side_energy_share"],
        .width: ["side_energy_share", "stereo_correlation"],
        .polarityAndPhase: ["stereo_correlation", "mono_sum_energy_ratio"],
        .tonalDistribution: ["spectral_centroid_hz", "spectral_slope_db_per_octave",
                             "maximum_third_octave_concentration_ratio"],
        .eqAndFiltering: ["maximum_third_octave_concentration_ratio", "spectral_centroid_hz"],
        .bass: ["mix_below_250_hz_energy_ratio", "bass_sub_share_20_120_hz"],
    ]

    /// Statements the current analyzer cannot support, regardless of domain.
    public static let cannotEstablish: [String] = [
        "phoneme-specific qualities such as nasality on particular vowels",
        "musical emotion or whether a section feels exciting",
        "note identity, key, or chord content",
        "a source's role in an arrangement",
        "masking by a track TrackSmith cannot hear",
        "which compressor or reverb sounds better",
        "whether timing variation is intentional rubato",
        "whether a mix is artistically better",
    ]

    /// Which of the analyzed metrics are both present and relevant here.
    public func influencingMetrics(
        domains: [ProductionDomain],
        analysis: SourceAwareAnalysisReport?
    ) -> [String] {
        guard let analysis else { return [] }
        var wanted = Set<String>()
        for domain in domains {
            for metric in Self.relevance[domain] ?? [] { wanted.insert(metric) }
        }
        guard !wanted.isEmpty else { return [] }
        var present = Set(analysis.metrics.keys)
        present.formUnion(analysis.baseReport.metrics.keys)
        return wanted.intersection(present).sorted()
    }
}

public struct GeneralTutorRequest: Sendable {
    public var question: String
    public var sourceType: SourceType
    public var context: GeneralTutorUserContext
    public var analysis: SourceAwareAnalysisReport?
    public var explanationDepth: TutorExplanationDepth
    public var researchConsentGranted: Bool

    public init(
        question: String,
        sourceType: SourceType,
        context: GeneralTutorUserContext = .empty,
        analysis: SourceAwareAnalysisReport? = nil,
        explanationDepth: TutorExplanationDepth = .simple,
        researchConsentGranted: Bool = false
    ) {
        self.question = question
        self.sourceType = sourceType
        self.context = context
        self.analysis = analysis
        self.explanationDepth = explanationDepth
        self.researchConsentGranted = researchConsentGranted
    }
}

public struct GeneralTutorOutcome: Sendable {
    public var intent: GeneralTutorQuestionIntent
    public var retrieved: RetrievedKnowledge
    public var answer: GeneralTutorAnswerContract

    public init(
        intent: GeneralTutorQuestionIntent,
        retrieved: RetrievedKnowledge,
        answer: GeneralTutorAnswerContract
    ) {
        self.intent = intent
        self.retrieved = retrieved
        self.answer = answer
    }
}

public enum GeneralTutorError: Error, Equatable, Sendable {
    case emptyQuestion
    case answerValidationFailed(String)
}

/// Deterministic open-domain answering: route, retrieve, synthesize, validate.
/// No provider is required; this is the complete offline path.
public struct GeneralTutorCoordinator: Sendable {
    private let router = GeneralTutorRouter()
    private let retriever: GeneralTutorRetriever
    private let relevance = MeasurementRelevanceMap()
    private let procedureCatalog: TutorProcedureCatalog
    private let validator: GeneralTutorAnswerValidator

    public init(
        retriever: GeneralTutorRetriever,
        procedureCatalog: TutorProcedureCatalog
    ) {
        self.retriever = retriever
        self.procedureCatalog = procedureCatalog
        self.validator = GeneralTutorAnswerValidator(
            base: retriever.knowledgeBase,
            procedureIDs: Set(procedureCatalog.procedures.map(\.id))
        )
    }

    public init() throws {
        let retriever = try GeneralTutorRetriever()
        let catalog = try TutorProcedureCatalog.loadValidated()
        self.init(retriever: retriever, procedureCatalog: catalog)
    }

    public func answer(_ request: GeneralTutorRequest) throws -> GeneralTutorOutcome {
        let text = request.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeneralTutorError.emptyQuestion }

        let intent = router.route(
            question: text,
            sourceType: request.sourceType,
            context: request.context,
            audioAvailable: request.analysis != nil,
            explanationDepth: request.explanationDepth
        )
        let retrieved = retriever.retrieve(for: intent)
        let answer = synthesize(intent: intent, retrieved: retrieved, request: request)

        do { try validator.validate(answer) }
        catch { throw GeneralTutorError.answerValidationFailed(String(describing: error)) }

        return GeneralTutorOutcome(intent: intent, retrieved: retrieved, answer: answer)
    }

    // MARK: - Synthesis

    private func synthesize(
        intent: GeneralTutorQuestionIntent,
        retrieved: RetrievedKnowledge,
        request: GeneralTutorRequest
    ) -> GeneralTutorAnswerContract {
        let influencing = relevance.influencingMetrics(
            domains: intent.allDomains, analysis: request.analysis
        )
        let audio = audioInfluence(intent: intent, influencing: influencing, request: request)
        let assumptions = buildAssumptions(intent: intent)
        let limitations = buildContextLimitations(intent: intent)

        // 1. Capability boundaries win over everything else.
        if !intent.unsupportedRequests.isEmpty {
            return capabilityAnswer(intent: intent, audio: audio, assumptions: assumptions)
        }

        // 2. Genuinely unroutable questions ask exactly one thing.
        if intent.requiresClarification, let question = intent.clarificationQuestion {
            return GeneralTutorAnswerContract(
                questionID: intent.questionID,
                interpretedQuestion: intent.problemSummary,
                questionKind: intent.questionKind,
                domains: intent.allDomains,
                answerMode: .clarificationNeeded,
                directAnswer: "I need one more detail before I can point you somewhere useful.",
                assumptions: assumptions,
                clarificationQuestion: question,
                currentContextLimitations: limitations,
                confidenceClass: .unsupportedOrUnresolved,
                audioInfluence: audio
            )
        }

        // 3. Concept questions answer from a concept card directly.
        if intent.questionKind == .explainConcept, let concept = retrieved.concepts.first {
            return conceptAnswer(
                intent: intent, concept: concept, retrieved: retrieved,
                audio: audio, assumptions: assumptions, limitations: limitations
            )
        }

        // 4. No usable coverage: say so honestly, and offer research.
        if retrieved.isEmpty || retrieved.coverage == .none {
            return weakCoverageAnswer(
                intent: intent, retrieved: retrieved, request: request,
                audio: audio, assumptions: assumptions, limitations: limitations
            )
        }

        // 5. Grounded strategy answer.
        return groundedAnswer(
            intent: intent, retrieved: retrieved, request: request,
            audio: audio, assumptions: assumptions, limitations: limitations
        )
    }

    private func audioInfluence(
        intent: GeneralTutorQuestionIntent,
        influencing: [String],
        request: GeneralTutorRequest
    ) -> AudioInfluenceRecord {
        let available = request.analysis != nil
        guard available else {
            return AudioInfluenceRecord(
                captureAvailable: false,
                influencingMetricIdentifiers: [],
                observedButNotResolving: [],
                statement: "No capture was used. This answer is general guidance, not grounded in your audio."
            )
        }
        guard !influencing.isEmpty else {
            return AudioInfluenceRecord(
                captureAvailable: true,
                influencingMetricIdentifiers: [],
                observedButNotResolving: Array((request.analysis?.metrics.keys).map(Array.init)?.sorted().prefix(6) ?? []),
                statement: "A capture is available, but no measurement it provides can resolve this question, so the answer does not rest on it."
            )
        }
        return AudioInfluenceRecord(
            captureAvailable: true,
            influencingMetricIdentifiers: influencing,
            observedButNotResolving: [],
            statement: "These measurements from your capture informed the answer: "
                + influencing.joined(separator: ", ")
                + ". They describe the signal; they do not prove a cause."
        )
    }

    private func buildAssumptions(intent: GeneralTutorQuestionIntent) -> [String] {
        var out: [String] = []
        out.append("You are asking about \(sourceLabel(intent.sourceType)) material.")
        let reported = intent.userContext.reportedStatements
        if reported.isEmpty {
            out.append("You have not described your project, so I am assuming a typical setup. Anything I say about your channel or arrangement is a guess, not something I can see.")
        } else {
            out.append("Using what you told me (user-reported, not observed): " + reported.joined(separator: "; ") + ".")
        }
        if !intent.preservationConstraints.isEmpty {
            out.append("Preserving: " + intent.preservationConstraints.joined(separator: "; ") + ".")
        }
        return out
    }

    private func buildContextLimitations(intent: GeneralTutorQuestionIntent) -> [String] {
        var out = [
            "TrackSmith can only hear audio passing through its own insert. It cannot see your other tracks, plug-ins, automation, MIDI, or arrangement.",
        ]
        if intent.requiresProjectWideContext {
            out.append("This question depends on how parts interact across the project, which TrackSmith cannot observe. The answer reasons from what you described rather than from your session.")
        }
        if intent.requestsExactLogicInstructions {
            out.append("Exact Logic steps are only given when a reviewed procedure exists; otherwise the guidance stays at strategy level.")
        }
        return out
    }

    private func capabilityAnswer(
        intent: GeneralTutorQuestionIntent,
        audio: AudioInfluenceRecord,
        assumptions: [String]
    ) -> GeneralTutorAnswerContract {
        var unsupported: [String] = []
        var answer = ""
        for request in intent.unsupportedRequests {
            switch request {
            case .hostAutomationRequested:
                unsupported.append("Operating Logic on your behalf")
                answer = "I do not operate Logic. I can tell you exactly what to do and why, but you stay in control of every action."
            case .destructiveActionRequested:
                unsupported.append("Destructive or irreversible edits")
                answer = "I keep guidance to reversible experiments, so I will not walk you through a destructive edit like bouncing in place, replacing, or normalizing a file."
            case .namedArtistCloningRequested:
                unsupported.append("Reproducing a specific artist's sound exactly")
                answer = "I cannot honestly promise to match a specific record — that depends on the voice, performance, room, and arrangement. Tell me the quality you are chasing and I can help with that."
            }
        }
        return GeneralTutorAnswerContract(
            questionID: intent.questionID,
            interpretedQuestion: intent.problemSummary,
            questionKind: intent.questionKind,
            domains: intent.allDomains,
            answerMode: .capabilityLimitation,
            directAnswer: answer,
            assumptions: assumptions,
            currentContextLimitations: [
                "This is a deliberate product boundary, not a missing feature.",
            ],
            confidenceClass: .unsupportedOrUnresolved,
            unsupportedCapabilities: unsupported,
            audioInfluence: audio
        )
    }

    private func conceptAnswer(
        intent: GeneralTutorQuestionIntent,
        concept: ProductionConceptCard,
        retrieved: RetrievedKnowledge,
        audio: AudioInfluenceRecord,
        assumptions: [String],
        limitations: [String]
    ) -> GeneralTutorAnswerContract {
        let body: String
        switch intent.explanationDepth {
        case .simple:
            body = concept.simpleExplanation
        case .standard:
            body = concept.simpleExplanation + " " + concept.causalExplanation
        case .technical:
            body = [concept.simpleExplanation, concept.causalExplanation,
                    concept.technicalExplanation].joined(separator: "\n\n")
        }
        return GeneralTutorAnswerContract(
            questionID: intent.questionID,
            interpretedQuestion: intent.problemSummary,
            questionKind: .explainConcept,
            domains: intent.allDomains,
            answerMode: .groundedAnswer,
            directAnswer: body,
            assumptions: assumptions,
            recommendedFirstMove: concept.practicalExample,
            exactProcedureIDs: concept.relatedProcedureIDs.filter(procedureExists),
            whatToListenFor: [concept.practicalExample],
            currentContextLimitations: limitations,
            relevantConceptIDs: [concept.id],
            knowledgeClaimIDs: Array(retrieved.claims.prefix(4).map(\.id)),
            sourceIDs: Array(Set(concept.sourceIDs + retrieved.claims.prefix(4).map(\.sourceID))).sorted(),
            contradictionIDs: [],
            confidenceClass: .sourceGroundedStrategy,
            audioInfluence: audio,
            teachingPrinciple: "Common misunderstanding worth avoiding: " + concept.commonMisunderstanding
        )
    }

    private func weakCoverageAnswer(
        intent: GeneralTutorQuestionIntent,
        retrieved: RetrievedKnowledge,
        request: GeneralTutorRequest,
        audio: AudioInfluenceRecord,
        assumptions: [String],
        limitations: [String]
    ) -> GeneralTutorAnswerContract {
        var extra = limitations
        extra.append("My reviewed knowledge does not cover this well enough to give you a grounded answer, so I am not going to improvise one.")
        let researchLine = request.researchConsentGranted
            ? "You have research enabled, so I can look this up against current sources and return a clearly labeled provisional answer."
            : "If you enable Research This, I can look it up against current sources and return a clearly labeled provisional answer."
        return GeneralTutorAnswerContract(
            questionID: intent.questionID,
            interpretedQuestion: intent.problemSummary,
            questionKind: intent.questionKind,
            domains: intent.allDomains,
            answerMode: .weakCoverageWithResearchOffer,
            directAnswer: "I do not have reviewed knowledge that covers this question well. " + researchLine,
            assumptions: assumptions,
            currentContextLimitations: extra,
            confidenceClass: .unsupportedOrUnresolved,
            requiresCurrentResearch: true,
            audioInfluence: audio,
            teachingPrinciple: "When a source cannot support an answer, the useful move is to say so rather than produce confident-sounding filler."
        )
    }

    private func groundedAnswer(
        intent: GeneralTutorQuestionIntent,
        retrieved: RetrievedKnowledge,
        request: GeneralTutorRequest,
        audio: AudioInfluenceRecord,
        assumptions: [String],
        limitations: [String]
    ) -> GeneralTutorAnswerContract {
        let retrievedClaimIDs = Set(retrieved.claims.map(\.id))
        let options = retrieved.strategies.prefix(3).map { strategy in
            GeneralStrategyOption(
                label: strategy.label,
                purpose: strategy.problemOrOutcome,
                whenUseful: strategy.usefulWhen.first ?? "When the description above matches what you are hearing.",
                whyItMayHelp: strategy.whyItMayHelp,
                tradeoffs: strategy.tradeoffs,
                preservationRisks: strategy.preservationConcerns,
                simplestTest: strategy.recommendedFirstExperiment,
                stoppingRule: strategy.stoppingRules.first ?? "Stop when the problem stops bothering you in context.",
                relatedProcedureIDs: strategy.relatedProcedureIDs.filter(procedureExists),
                supportingKnowledgeIDs: strategy.supportingClaimIDs.filter { retrievedClaimIDs.contains($0) },
                strategyID: strategy.id
            )
        }

        // Exact procedures only when the Tutor v1 fast path recognized the
        // issue and a validated procedure genuinely covers it.
        let procedures = exactProcedures(for: intent)
        let first = options.first

        var direct = ""
        if let first {
            direct = "The most likely useful direction: \(first.label). \(first.whyItMayHelp)"
        } else if let claim = retrieved.claims.first {
            direct = claim.claimText
        }
        if direct.isEmpty { direct = "Here is what reviewed sources suggest for this situation." }

        let contradictions = retrieved.contradictions
        let disclosures = contradictions.map {
            "Credible sources disagree here — \($0.topic). \($0.positionASummary) \($0.positionBSummary) What decides it: \($0.whatDeterminesWhichApplies)"
        }

        // Cite the claims that actually back the presented options, plus the
        // top retrieved claims for the domain.
        var citedClaims = Set(options.flatMap(\.supportingKnowledgeIDs))
        for claim in retrieved.claims.prefix(6) { citedClaims.insert(claim.id) }
        // Any contradiction we disclose must have both sides cited.
        for record in contradictions {
            for id in record.positionAClaimIDs.prefix(1) + record.positionBClaimIDs.prefix(1)
            where retriever.knowledgeBase.claim(id) != nil {
                citedClaims.insert(id)
            }
        }
        let claimIDs = citedClaims.sorted()
        let sourceIDs = Array(Set(claimIDs.compactMap { retriever.knowledgeBase.claim($0)?.sourceID })).sorted()

        let confidence: AnswerConfidenceClass = procedures.isEmpty
            ? .sourceGroundedStrategy
            : .reviewedExactProcedure

        return GeneralTutorAnswerContract(
            questionID: intent.questionID,
            interpretedQuestion: intent.problemSummary,
            questionKind: intent.questionKind,
            domains: intent.allDomains,
            answerMode: .groundedAnswer,
            directAnswer: direct,
            assumptions: assumptions,
            recommendedFirstMove: first?.simplestTest,
            strategyOptions: Array(options),
            exactProcedureIDs: procedures,
            whatToListenFor: retrieved.strategies.prefix(2).flatMap(\.expectedAudibleConsequences),
            preservationChecks: retrieved.strategies.prefix(2).flatMap(\.preservationConcerns),
            stopConditions: retrieved.strategies.prefix(2).flatMap(\.stoppingRules),
            risksAndSideEffects: retrieved.strategies.prefix(2).flatMap(\.tradeoffs),
            alternatives: Array(retrieved.strategies.dropFirst().prefix(2)).map(\.label),
            nonDSPPossibilities: retrieved.strategies.prefix(3).flatMap(\.nonDSPAlternatives),
            currentContextLimitations: limitations,
            relevantConceptIDs: retrieved.concepts.prefix(2).map(\.id),
            knowledgeClaimIDs: claimIDs,
            sourceIDs: sourceIDs,
            contradictionIDs: contradictions.map(\.id),
            contradictionDisclosures: disclosures,
            confidenceClass: confidence,
            requiresCurrentResearch: retrieved.coverage == .weak,
            audioInfluence: audio,
            teachingPrinciple: teachingPrinciple(for: intent, retrieved: retrieved)
        )
    }

    private func exactProcedures(for intent: GeneralTutorQuestionIntent) -> [String] {
        guard let issue = intent.recognizedTutorIssues.first else { return [] }
        let planner = try? TutorPlanner(catalog: procedureCatalog)
        guard let planner else { return [] }
        let ordered = planner.orderedCandidateProcedureIDs(
            issue: issue,
            qualifiers: TutorRequestQualifiers(),
            chain: intent.userContext.tutorChain,
            sourceType: intent.sourceType
        )
        return Array(ordered.prefix(2))
    }

    private func procedureExists(_ id: String) -> Bool {
        procedureCatalog.procedure(id) != nil
    }

    private func teachingPrinciple(
        for intent: GeneralTutorQuestionIntent,
        retrieved: RetrievedKnowledge
    ) -> String {
        if !retrieved.contradictions.isEmpty {
            return "Reusable principle: when credible sources disagree, the deciding factor is usually context and intent, not who is right. Decide by listening in the actual arrangement."
        }
        switch intent.questionKind {
        case .compareOptions:
            return "Reusable principle: compare options at matched loudness and change one variable at a time, or you are measuring level rather than difference."
        case .productionStrategy, .planSession:
            return "Reusable principle: do the cheapest reversible test that could disprove your theory before committing to processing."
        case .diagnoseTradeoff:
            return "Reusable principle: most production moves trade one quality for another. Name what you are willing to give up before you turn the knob."
        default:
            return "Reusable principle: fix the biggest, most reversible thing first, and check whether the problem is in the source before reaching for processing."
        }
    }

    private func sourceLabel(_ type: SourceType) -> String {
        switch type {
        case .vocal: "vocal"
        case .vocalBus: "vocal bus"
        case .drums: "drum"
        case .drumBus: "drum bus"
        case .bass: "bass"
        case .guitar: "guitar"
        case .keyboard: "keyboard"
        case .synth: "synth"
        case .fullMix: "full mix"
        case .reference: "reference"
        case .unknown: "unspecified"
        }
    }
}
