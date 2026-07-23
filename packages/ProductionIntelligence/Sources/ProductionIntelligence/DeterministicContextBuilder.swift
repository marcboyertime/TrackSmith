import AgentCore
import AudioAnalysis
import Foundation
import PlanSchema

public enum ContextConstructionError: Error, Equatable, Sendable {
    case emptyRequest
    case sourceMismatch(expected: SourceType, actual: SourceAnalysisClass)
    case budgetTooSmall
    case contextExceedsBudget(actual: Int, maximum: Int)
}

public struct ProductionContextInput: Sendable {
    public var userRequest: String
    public var scope: ProcessingScope
    public var authority: ProductionAuthorityIdentity
    public var analysis: SourceAwareAnalysisReport
    public var committedPlan: ProcessingPlan?
    public var workingPlan: ProcessingPlan?
    public var references: ModelReferenceRegistry
    public var priorRevisionSummaries: [String]
    public var budget: ProviderRequestBudget

    public init(
        userRequest: String,
        scope: ProcessingScope,
        authority: ProductionAuthorityIdentity,
        analysis: SourceAwareAnalysisReport,
        committedPlan: ProcessingPlan? = nil,
        workingPlan: ProcessingPlan? = nil,
        references: ModelReferenceRegistry = .init(),
        priorRevisionSummaries: [String] = [],
        budget: ProviderRequestBudget = .init()
    ) {
        self.userRequest = userRequest
        self.scope = scope
        self.authority = authority
        self.analysis = analysis
        self.committedPlan = committedPlan
        self.workingPlan = workingPlan
        self.references = references
        self.priorRevisionSummaries = priorRevisionSummaries
        self.budget = budget
    }
}

/// Builds a compact, stable, labeled context from typed local state. It never
/// accepts filenames, arbitrary imported metadata, raw audio, secrets, or an
/// unbounded conversation transcript.
public struct DeterministicContextBuilder: Sendable {
    public static let maximumSections = 32
    public static let maximumMetrics = 12
    public static let maximumKnowledgeTerms = 10
    public static let maximumLogicNativeKnowledgeEntries = 4
    public static let maximumLogicNativeInstrumentKnowledgeEntries = 2
    public static let maximumLogicEditorToolKnowledgeEntries = 2
    public static let maximumAbstractMusicianLanguageEntries = 3
    public static let maximumPriorRevisions = 8
    public static let maximumReferenceDescriptors = 64
    public static let minimumContextBudget = 4_096

    public var vocabulary: ProductionIntentVocabulary
    public var logicNativeKnowledge: LogicNativeToolKnowledgeCatalog
    public var logicNativeInstrumentKnowledge: LogicNativeInstrumentKnowledgeCatalog
    public var logicEditorToolKnowledge: LogicEditorToolKnowledgeCatalog
    public var abstractMusicianLanguageKnowledge: AbstractMusicianLanguageKnowledgeCatalog

    public init(
        vocabulary: ProductionIntentVocabulary = .init(),
        logicNativeKnowledge: LogicNativeToolKnowledgeCatalog = .logicPro12_3,
        logicNativeInstrumentKnowledge: LogicNativeInstrumentKnowledgeCatalog = .logicPro12_3,
        logicEditorToolKnowledge: LogicEditorToolKnowledgeCatalog = .logicPro12_3,
        abstractMusicianLanguageKnowledge: AbstractMusicianLanguageKnowledgeCatalog = .trackSmithV1
    ) {
        self.vocabulary = vocabulary
        self.logicNativeKnowledge = logicNativeKnowledge
        self.logicNativeInstrumentKnowledge = logicNativeInstrumentKnowledge
        self.logicEditorToolKnowledge = logicEditorToolKnowledge
        self.abstractMusicianLanguageKnowledge = abstractMusicianLanguageKnowledge
    }

    public func build(_ input: ProductionContextInput) throws -> ModelInterpretationRequest {
        let request = boundedText(input.userRequest, maximumBytes: 4_096)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { throw ContextConstructionError.emptyRequest }
        guard input.budget.maxContextUTF8Bytes >= Self.minimumContextBudget else {
            throw ContextConstructionError.budgetTooSmall
        }
        let expectedClass = try sourceClass(for: input.scope.sourceType)
        guard input.analysis.sourceClass == expectedClass else {
            throw ContextConstructionError.sourceMismatch(
                expected: input.scope.sourceType,
                actual: input.analysis.sourceClass
            )
        }

        let abstractLanguageKnowledge = abstractMusicianLanguageKnowledge.select(
            request: request,
            sourceType: input.scope.sourceType,
            maximumCount: Self.maximumAbstractMusicianLanguageEntries
        )
        let selectedTerms = relevantTerms(
            request: request,
            sourceType: input.scope.sourceType,
            seededTerms: Set(abstractLanguageKnowledge.flatMap(\.canonicalCandidateTerms))
        )
        let metricIdentifiers = Set(selectedTerms.flatMap { term in
            vocabulary.interpretations(for: term, sourceType: input.scope.sourceType)
                .flatMap(\.supportingMetricIdentifiers)
        })
        let selectedMetrics = input.analysis.metrics.values.sorted { lhs, rhs in
            let leftRelevant = metricIdentifiers.contains(lhs.definition.identifier)
            let rightRelevant = metricIdentifiers.contains(rhs.definition.identifier)
            if leftRelevant != rightRelevant { return leftRelevant }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.definition.identifier < rhs.definition.identifier
        }.prefix(Self.maximumMetrics)

        var sections: [ModelContextSection] = []
        sections.append(.init(label: .userRequest, identifier: "request", content: request))
        sections.append(.init(
            label: .currentState,
            identifier: "scope",
            content: encodeJSON(ScopeContext(
                sourceType: input.scope.sourceType,
                channelFormat: input.scope.channelFormat,
                scopeKind: input.scope.kind,
                temporalScope: input.scope.timeRangeSeconds,
                captureSnapshotID: input.authority.captureSnapshotID
            ))
        ))
        sections.append(.init(
            label: .measuredEvidence,
            identifier: "source-aware-analysis-v\(input.analysis.version)",
            content: encodeJSON(selectedMetrics.map { value in
                MetricContext(
                    identifier: value.definition.identifier,
                    value: value.value,
                    unit: value.definition.unit.rawValue,
                    confidence: value.confidence,
                    validConditions: Array(value.definition.validConditions.prefix(4)),
                    windowing: boundedText(value.definition.windowing, maximumBytes: 512),
                    aggregation: boundedText(value.definition.aggregation, maximumBytes: 512),
                    knownFailureModes: Array(value.definition.knownFailureModes.prefix(4))
                )
            })
        ))

        if let committedPlan = input.committedPlan {
            sections.append(graphSection(plan: committedPlan, identifier: "committed-graph"))
        }
        if let workingPlan = input.workingPlan, workingPlan != input.committedPlan {
            sections.append(graphSection(plan: workingPlan, identifier: "working-graph"))
        }

        let referenceCatalog = boundedReferenceCatalog(input.references)
        if !referenceCatalog.isEmpty {
            sections.append(.init(
                label: .currentState,
                identifier: "typed-reference-catalog",
                content: encodeJSON(referenceCatalog)
            ))
        }

        // An explicitly named instrument is stronger context than generic
        // semantic defaults. Insert it before lower-priority term/effect
        // advisories so bounded pruning removes generic material first.
        let instrumentKnowledge = logicNativeInstrumentKnowledge.selectExplicitlyReferenced(
            request: request,
            sourceType: input.scope.sourceType,
            maximumCount: Self.maximumLogicNativeInstrumentKnowledgeEntries
        )
        for entry in instrumentKnowledge {
            sections.append(.init(
                label: .professionalPracticeHeuristic,
                identifier: "logic-native-instrument-advisory:\(entry.identifier)",
                content: encodeJSON(LogicNativeToolContext(entry))
            ))
        }

        // Host editor tools are included only when the request explicitly uses
        // tool language. Their context says what state they affect and why the
        // operation is unsupported; it never supplies a key command or action.
        let editorToolKnowledge = logicEditorToolKnowledge.selectExplicitlyReferenced(
            request: request,
            maximumCount: Self.maximumLogicEditorToolKnowledgeEntries
        )
        for entry in editorToolKnowledge {
            sections.append(.init(
                label: .professionalPracticeHeuristic,
                identifier: "logic-editor-tool-advisory:\(entry.identifier)",
                content: encodeJSON(LogicEditorToolContext(entry))
            ))
        }

        // Abstract musician language is deliberately distinct from executable
        // ProductionTerm output. It supplies bounded alternate senses,
        // contradictions, unsupported causes, and clarification policy. Its
        // candidate terms only improve deterministic evidence retrieval; the
        // provider must still emit the versioned contract and pass every local
        // validation stage before TrackSmith can form a hypothesis.
        for entry in abstractLanguageKnowledge {
            sections.append(.init(
                label: .professionalPracticeHeuristic,
                identifier: "abstract-musician-language:\(entry.identifier)",
                content: encodeJSON(AbstractMusicianLanguageContext(
                    entry,
                    sourceType: input.scope.sourceType
                ))
            ))
        }

        for term in selectedTerms {
            let definition = vocabulary.definition(for: term)
            let sourceRules = vocabulary.interpretations(for: term, sourceType: input.scope.sourceType)
            let label: ModelContextLabel = switch definition.evidenceClass {
            case .standardsBacked, .peerReviewedResearchBacked: .researchBackedKnowledge
            case .professionalPracticeHeuristic: .professionalPracticeHeuristic
            case .productHeuristic: .productHeuristic
            }
            sections.append(.init(
                label: label,
                identifier: "production-term:\(term.rawValue)",
                content: encodeJSON(KnowledgeContext(
                    term: term,
                    possibleInterpretations: sourceRules.map(\.possibleAcousticInterpretation),
                    contradictoryEvidence: Array(definition.contradictoryEvidence.prefix(3)),
                    candidateStrategies: sourceRules.flatMap(\.candidateDSPStrategies)
                        .uniqued().map(\.rawValue).sorted(),
                    preservationRisks: Array(definition.preservationRisks.prefix(4)),
                    confidence: definition.confidence,
                    evidenceClass: definition.evidenceClass
                ))
            ))
        }

        let logicKnowledge = logicNativeKnowledge.select(
            request: request,
            sourceType: input.scope.sourceType,
            semanticTerms: selectedTerms,
            maximumCount: Self.maximumLogicNativeKnowledgeEntries
        )
        for entry in logicKnowledge {
            sections.append(.init(
                label: .professionalPracticeHeuristic,
                identifier: "logic-native-advisory:\(entry.identifier)",
                content: encodeJSON(LogicNativeToolContext(entry))
            ))
        }

        let implemented = PlanValidator.implementedNodeTypes.map(\.rawValue).sorted()
        sections.append(.init(
            label: .availableCapability,
            identifier: "deterministic-dsp-v1",
            content: encodeJSON(implemented)
        ))
        let unsupported = NodeType.allCases.filter { !PlanValidator.implementedNodeTypes.contains($0) }
            .map(\.rawValue).sorted()
        sections.append(.init(
            label: .knownLimitation,
            identifier: "unsupported-dsp-and-host-actions",
            content: encodeJSON([
                "unsupportedNodeTypes": unsupported.joined(separator: ","),
                "hostLimits": "No arbitrary Logic project or region editing; no third-party plug-in insertion; no source separation; no generative waveform replacement; no raw-audio cloud upload.",
            ])
        ))

        let revisions = input.priorRevisionSummaries.prefix(Self.maximumPriorRevisions).map {
            boundedText($0, maximumBytes: 768)
        }
        if !revisions.isEmpty {
            sections.append(.init(
                label: .currentState,
                identifier: "bounded-prior-revisions",
                content: encodeJSON(Array(revisions))
            ))
        }

        let constructedSectionCount = sections.count
        sections = Array(sections.prefix(Self.maximumSections))
        var omitted = max(0, constructedSectionCount - sections.count)
        while true {
            let byteCount = encodedByteCount(sections)
            if byteCount <= input.budget.maxContextUTF8Bytes {
                let envelope = ModelContextEnvelope(
                    sections: sections,
                    utf8ByteCount: byteCount,
                    omittedSectionCount: omitted
                )
                return ModelInterpretationRequest(
                    userRequest: request,
                    scope: input.scope,
                    authority: input.authority,
                    references: input.references,
                    context: envelope,
                    budget: input.budget
                )
            }
            // Mandatory request/scope/evidence/capability/limitation sections
            // are retained. Lower-priority term and revision sections are
            // removed deterministically from the end.
            guard let index = sections.lastIndex(where: {
                $0.identifier.hasPrefix("production-term:")
                    || $0.identifier.hasPrefix("abstract-musician-language:")
                    || $0.identifier.hasPrefix("logic-native-advisory:")
                    || $0.identifier.hasPrefix("logic-native-instrument-advisory:")
                    || $0.identifier.hasPrefix("logic-editor-tool-advisory:")
                    || $0.identifier == "bounded-prior-revisions"
            }) else {
                throw ContextConstructionError.contextExceedsBudget(
                    actual: byteCount,
                    maximum: input.budget.maxContextUTF8Bytes
                )
            }
            sections.remove(at: index)
            omitted += 1
        }
    }

    private func graphSection(plan: ProcessingPlan, identifier: String) -> ModelContextSection {
        let graph = GraphContext(
            requestID: plan.requestID,
            sourceSnapshotID: plan.sourceSnapshotID,
            goals: plan.goals,
            nodes: plan.nodes.map { node in
                NodeContext(
                    id: node.id,
                    type: node.type,
                    enabled: node.enabled,
                    locked: node.locked,
                    parameters: Dictionary(uniqueKeysWithValues: node.parameters.map { ($0.key.rawValue, $0.value) })
                )
            }
        )
        return .init(label: .currentState, identifier: identifier, content: encodeJSON(graph))
    }

    private func boundedReferenceCatalog(
        _ registry: ModelReferenceRegistry
    ) -> [ModelReferenceDescriptor] {
        registry.catalog.prefix(Self.maximumReferenceDescriptors).compactMap { descriptor in
            guard descriptor.identifier.utf8.count <= 64,
                  referenceExists(descriptor, in: registry) else { return nil }
            var bounded = descriptor
            bounded.aliases = descriptor.aliases.prefix(8).map {
                boundedText($0, maximumBytes: 128)
            }
            bounded.summary = descriptor.summary.map {
                boundedText($0, maximumBytes: 512)
            }
            bounded.ordinal = descriptor.ordinal.map { min(max($0, 1), 10_000) }
            bounded.parentIdentifier = boundedIdentifier(descriptor.parentIdentifier)
            bounded.baseIdentifier = boundedIdentifier(descriptor.baseIdentifier)
            bounded.resultIdentifier = boundedIdentifier(descriptor.resultIdentifier)
            return bounded
        }
    }

    private func referenceExists(
        _ descriptor: ModelReferenceDescriptor,
        in registry: ModelReferenceRegistry
    ) -> Bool {
        switch descriptor.kind {
        case .productionAttribute:
            guard let term = ProductionTerm(rawValue: descriptor.identifier) else { return false }
            return registry.productionAttributes.contains(term)
        case .preview, .snapshot, .priorRequest, .processingNode:
            guard let identifier = UUID(uuidString: descriptor.identifier) else { return false }
            return switch descriptor.kind {
            case .preview: registry.previewIDs.contains(identifier)
            case .snapshot: registry.snapshotIDs.contains(identifier)
            case .priorRequest: registry.priorRequestIDs.contains(identifier)
            case .processingNode: registry.processingNodeIDs.contains(identifier)
            case .productionAttribute: false
            }
        }
    }

    private func boundedIdentifier(_ identifier: String?) -> String? {
        guard let identifier, identifier.utf8.count <= 64 else { return nil }
        return identifier
    }

    private func relevantTerms(
        request: String,
        sourceType: SourceType,
        seededTerms: Set<ProductionTerm> = []
    ) -> [ProductionTerm] {
        let words = Set(request.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let defaults = defaultTerms(for: sourceType)
        return ProductionTerm.allCases.filter {
            vocabulary.definition(for: $0).applicableSourceTypes.contains(sourceType)
        }.sorted { lhs, rhs in
            let left = relevanceScore(lhs, words: words, defaults: defaults, seededTerms: seededTerms)
            let right = relevanceScore(rhs, words: words, defaults: defaults, seededTerms: seededTerms)
            if left != right { return left > right }
            return lhs.rawValue < rhs.rawValue
        }.prefix(Self.maximumKnowledgeTerms).map { $0 }
    }

    private func relevanceScore(
        _ term: ProductionTerm,
        words: Set<String>,
        defaults: [ProductionTerm],
        seededTerms: Set<ProductionTerm>
    ) -> Int {
        let definition = vocabulary.definition(for: term)
        let aliases = definition.aliases.flatMap {
            $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        }
        let lexical = aliases.reduce(0) { $0 + (words.contains($1) ? 100 : 0) }
        let defaultScore = defaults.firstIndex(of: term).map { 40 - $0 } ?? 0
        let abstractLanguageScore = seededTerms.contains(term) ? 300 : 0
        return lexical + abstractLanguageScore + defaultScore
    }

    private func defaultTerms(for sourceType: SourceType) -> [ProductionTerm] {
        switch sourceType {
        case .vocal, .vocalBus:
            [.clear, .intimate, .forward, .warm, .sibilant, .airy, .polished, .controlled, .dynamic, .harsh]
        case .drums, .drumBus:
            [.punchy, .energetic, .controlled, .harsh, .cymbalHarshness, .warm, .raw, .dynamic, .tight, .aggressive]
        case .bass:
            [.tight, .boomy, .lowEndWeight, .controlled, .warm, .clear, .punchy, .muddy, .dynamic, .aggressive]
        case .guitar:
            [.harsh, .aggressive, .pickAttack, .clear, .warm, .raw, .forward, .smooth, .thin, .controlled]
        case .keyboard, .synth:
            [.wide, .monoCompatibility, .clear, .warm, .bright, .dark, .smooth, .energetic, .controlled, .airy]
        case .fullMix:
            [.clear, .controlled, .dynamic, .polished, .warm, .bright, .wide, .tight, .energetic, .modern]
        case .reference, .unknown:
            []
        }
    }

    private func sourceClass(for sourceType: SourceType) throws -> SourceAnalysisClass {
        switch sourceType {
        case .vocal, .vocalBus: .vocal
        case .drums, .drumBus: .drums
        case .bass: .bass
        case .guitar: .guitar
        case .keyboard, .synth: .synthKeys
        case .fullMix: .fullStereoMix
        case .reference, .unknown:
            throw ContextConstructionError.sourceMismatch(expected: sourceType, actual: .fullStereoMix)
        }
    }

    private func encodedByteCount(_ sections: [ModelContextSection]) -> Int {
        (try? JSONEncoder.sorted.encode(sections).count) ?? Int.max
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder.sorted.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private func boundedText(_ value: String, maximumBytes: Int) -> String {
        let filtered = value.unicodeScalars.filter {
            $0.value == 9 || $0.value == 10 || $0.value == 13 || $0.value >= 32
        }
        var result = String(String.UnicodeScalarView(filtered))
        while result.utf8.count > maximumBytes, !result.isEmpty { result.removeLast() }
        return result
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private struct ScopeContext: Codable {
    var sourceType: SourceType
    var channelFormat: ChannelFormat
    var scopeKind: ScopeKind
    var temporalScope: TimeRangeSeconds?
    var captureSnapshotID: UUID
}

private struct MetricContext: Codable {
    var identifier: String
    var value: Double
    var unit: String
    var confidence: Double
    var validConditions: [String]
    var windowing: String
    var aggregation: String
    var knownFailureModes: [String]
}

private struct KnowledgeContext: Codable {
    var term: ProductionTerm
    var possibleInterpretations: [String]
    var contradictoryEvidence: [String]
    var candidateStrategies: [String]
    var preservationRisks: [String]
    var confidence: Double
    var evidenceClass: ProductionEvidenceClass
}

private struct GraphContext: Codable {
    var requestID: UUID
    var sourceSnapshotID: UUID
    var goals: [ProcessingGoal]
    var nodes: [NodeContext]
}

private struct NodeContext: Codable {
    var id: UUID
    var type: NodeType
    var enabled: Bool
    var locked: Bool
    var parameters: [String: Double]
}
