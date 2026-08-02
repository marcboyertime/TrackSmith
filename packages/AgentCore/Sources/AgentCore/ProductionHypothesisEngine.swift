import AudioAnalysis
import Foundation
import PlanSchema

public enum ProductionIntentDirection: String, Codable, CaseIterable, Sendable {
    case increase
    case decrease
    case preserve
    case doNotIncrease
    case doNotDecrease
}

public enum ExpectedMeasurementDirection: String, Codable, CaseIterable, Sendable {
    case increase
    case decrease
    case preserve
    case uncertain
}

public struct InterpretedProductionGoal: Codable, Equatable, Sendable {
    public var term: ProductionTerm
    public var matchedPhrase: String
    public var direction: ProductionIntentDirection
    public var strength: Double
    public var sourceType: SourceType
    public var interpretation: String
    public var confidence: Double
    public var evidenceClass: ProductionEvidenceClass
    public var provenance: [ProductionIntentProvenance]

    public init(
        term: ProductionTerm,
        matchedPhrase: String,
        direction: ProductionIntentDirection,
        strength: Double,
        sourceType: SourceType,
        interpretation: String,
        confidence: Double,
        evidenceClass: ProductionEvidenceClass,
        provenance: [ProductionIntentProvenance]
    ) {
        self.term = term
        self.matchedPhrase = matchedPhrase
        self.direction = direction
        self.strength = min(max(strength, 0), 1)
        self.sourceType = sourceType
        self.interpretation = interpretation
        self.confidence = min(max(confidence, 0), 1)
        self.evidenceClass = evidenceClass
        self.provenance = provenance
    }
}

public struct ProductionIntentInterpretation: Codable, Equatable, Sendable {
    public var version: String
    public var originalRequest: String
    public var sourceType: SourceType
    public var desiredChanges: [InterpretedProductionGoal]
    public var preservedAttributes: [InterpretedProductionGoal]
    public var prohibitedChanges: [InterpretedProductionGoal]
    public var unresolvedAmbiguities: [String]
    public var requiresClarification: Bool

    public init(
        version: String = "1.0",
        originalRequest: String,
        sourceType: SourceType,
        desiredChanges: [InterpretedProductionGoal],
        preservedAttributes: [InterpretedProductionGoal],
        prohibitedChanges: [InterpretedProductionGoal],
        unresolvedAmbiguities: [String],
        requiresClarification: Bool
    ) {
        self.version = version
        self.originalRequest = originalRequest
        self.sourceType = sourceType
        self.desiredChanges = desiredChanges
        self.preservedAttributes = preservedAttributes
        self.prohibitedChanges = prohibitedChanges
        self.unresolvedAmbiguities = unresolvedAmbiguities
        self.requiresClarification = requiresClarification
    }
}

public enum ProductionEvidenceRelationship: String, Codable, CaseIterable, Sendable {
    case contextual
    case supportsIntervention
    case arguesAgainstIntervention
    case preservationCheck
    case unavailable
}

public struct ProductionEvidenceObservation: Codable, Equatable, Sendable {
    public var metricIdentifier: String?
    public var value: Double?
    public var unit: String?
    public var confidence: Double
    public var relationship: ProductionEvidenceRelationship
    public var interpretationBoundary: String
    public var provenance: [ProductionIntentProvenance]

    public init(
        metricIdentifier: String? = nil,
        value: Double? = nil,
        unit: String? = nil,
        confidence: Double,
        relationship: ProductionEvidenceRelationship,
        interpretationBoundary: String,
        provenance: [ProductionIntentProvenance] = []
    ) {
        self.metricIdentifier = metricIdentifier
        self.value = value
        self.unit = unit
        self.confidence = min(max(confidence, 0), 1)
        self.relationship = relationship
        self.interpretationBoundary = interpretationBoundary
        self.provenance = provenance
    }
}

public struct ExpectedMetricChange: Codable, Equatable, Sendable {
    public var metricIdentifier: String
    public var direction: ExpectedMeasurementDirection
    public var rationale: String

    public init(metricIdentifier: String, direction: ExpectedMeasurementDirection, rationale: String) {
        self.metricIdentifier = metricIdentifier
        self.direction = direction
        self.rationale = rationale
    }
}

public struct CandidateProductionPlan: Codable, Equatable, Sendable {
    public var identifier: String
    public var strength: PreviewStrength
    public var summary: String
    public var processingOptions: [ProductionDSPStrategy]
    public var plan: ProcessingPlan
    public var validationNotes: [String]
    public var provenance: [ProductionIntentProvenance]

    public init(
        identifier: String,
        strength: PreviewStrength,
        summary: String,
        processingOptions: [ProductionDSPStrategy],
        plan: ProcessingPlan,
        validationNotes: [String],
        provenance: [ProductionIntentProvenance]
    ) {
        self.identifier = identifier
        self.strength = strength
        self.summary = summary
        self.processingOptions = processingOptions
        self.plan = plan
        self.validationNotes = validationNotes
        self.provenance = provenance
    }
}

public struct ProductionHypothesis: Codable, Equatable, Sendable {
    public var version: String
    public var intendedPerceptualChange: String
    public var sourceContext: String
    public var evidenceSupportingIntervention: [ProductionEvidenceObservation]
    public var evidenceAgainstIntervention: [ProductionEvidenceObservation]
    public var uncertainty: [String]
    public var processingOptionsConsidered: [ProductionDSPStrategy]
    public var selectedStrategyIdentifier: String
    public var preservationConstraints: [String]
    public var risks: [String]
    public var expectedMeasurableDirection: [ExpectedMetricChange]
    public var subjectiveListeningRemainsDecisive: Bool
    public var provenance: [ProductionIntentProvenance]
    public var candidatePlans: [CandidateProductionPlan]

    public init(
        version: String = "1.0",
        intendedPerceptualChange: String,
        sourceContext: String,
        evidenceSupportingIntervention: [ProductionEvidenceObservation],
        evidenceAgainstIntervention: [ProductionEvidenceObservation],
        uncertainty: [String],
        processingOptionsConsidered: [ProductionDSPStrategy],
        selectedStrategyIdentifier: String,
        preservationConstraints: [String],
        risks: [String],
        expectedMeasurableDirection: [ExpectedMetricChange],
        subjectiveListeningRemainsDecisive: Bool = true,
        provenance: [ProductionIntentProvenance],
        candidatePlans: [CandidateProductionPlan]
    ) {
        self.version = version
        self.intendedPerceptualChange = intendedPerceptualChange
        self.sourceContext = sourceContext
        self.evidenceSupportingIntervention = evidenceSupportingIntervention
        self.evidenceAgainstIntervention = evidenceAgainstIntervention
        self.uncertainty = uncertainty
        self.processingOptionsConsidered = processingOptionsConsidered
        self.selectedStrategyIdentifier = selectedStrategyIdentifier
        self.preservationConstraints = preservationConstraints
        self.risks = risks
        self.expectedMeasurableDirection = expectedMeasurableDirection
        self.subjectiveListeningRemainsDecisive = subjectiveListeningRemainsDecisive
        self.provenance = provenance
        self.candidatePlans = candidatePlans
    }
}

public struct ProductionIntentResult: Codable, Equatable, Sendable {
    public var vocabularyVersion: String
    public var interpretation: ProductionIntentInterpretation
    public var hypotheses: [ProductionHypothesis]

    public init(
        vocabularyVersion: String,
        interpretation: ProductionIntentInterpretation,
        hypotheses: [ProductionHypothesis]
    ) {
        self.vocabularyVersion = vocabularyVersion
        self.interpretation = interpretation
        self.hypotheses = hypotheses
    }
}

public enum ProductionIntentError: Error, Equatable, Sendable {
    case sourceAnalysisMismatch(expected: SourceAnalysisClass, actual: SourceAnalysisClass)
    case noActionableIntent(String)
    case contradictoryIntent(String)
}

public struct ProductionIntentEngine: Sendable {
    public var vocabulary: ProductionIntentVocabulary

    public init(vocabulary: ProductionIntentVocabulary = .init()) {
        self.vocabulary = vocabulary
    }

    public func interpret(request: String, scope: ProcessingScope) throws -> ProductionIntentInterpretation {
        // Retain the existing hard safety/contradiction checks. Its returned
        // goals are deliberately ignored: this layer does not accept the old
        // keyword-to-DSP shortcut as semantic evidence.
        _ = try DeterministicPlanner().parseGoals(prompt: request, sourceType: scope.sourceType)
        let normalized = request.lowercased()
        let matches = nonOverlappingMatches(in: normalized)
        var desired: [InterpretedProductionGoal] = []
        var preserved: [InterpretedProductionGoal] = []
        var prohibited: [InterpretedProductionGoal] = []
        var ambiguity: [String] = []

        for match in matches {
            let definition = vocabulary.definition(for: match.term)
            guard definition.applicableSourceTypes.contains(scope.sourceType) else {
                ambiguity.append("‘\(match.phrase)’ is not actionable for \(scope.sourceType.rawValue) in vocabulary \(vocabulary.version).")
                continue
            }
            let direction = directionForMatch(match, in: normalized)
            let sourceInterpretation = vocabulary.interpretations(for: match.term, sourceType: scope.sourceType).first
            let goal = InterpretedProductionGoal(
                term: match.term,
                matchedPhrase: match.phrase,
                direction: direction,
                strength: requestedStrength(in: normalized),
                sourceType: scope.sourceType,
                interpretation: sourceInterpretation?.possibleAcousticInterpretation
                    ?? "The term is context-dependent and has no unique acoustic mapping.",
                confidence: definition.confidence,
                evidenceClass: definition.evidenceClass,
                provenance: definition.provenance
            )
            switch direction {
            case .preserve:
                preserved.append(goal)
            case .doNotIncrease, .doNotDecrease:
                prohibited.append(goal)
            case .increase, .decrease:
                desired.append(goal)
            }
        }

        let groupedDirections = Dictionary(grouping: desired, by: \.term)
        for (term, goals) in groupedDirections {
            let directions = Set(goals.map(\.direction))
            if directions.contains(.increase), directions.contains(.decrease) {
                throw ProductionIntentError.contradictoryIntent(
                    "The request asks to both increase and decrease ‘\(term.rawValue)’."
                )
            }
        }

        if desired.isEmpty {
            ambiguity.append("No unambiguous production change was identified; preservation constraints alone cannot choose a processor.")
        }
        let broadTerms: Set<ProductionTerm> = [.polished, .vintage, .modern]
        if !desired.isEmpty, desired.allSatisfy({ broadTerms.contains($0.term) }) {
            ambiguity.append("The request names only a broad production style and needs an acoustic priority or multiple interpretations.")
        }
        return ProductionIntentInterpretation(
            originalRequest: request,
            sourceType: scope.sourceType,
            desiredChanges: uniqueGoals(desired),
            preservedAttributes: uniqueGoals(preserved),
            prohibitedChanges: uniqueGoals(prohibited),
            unresolvedAmbiguities: ambiguity,
            requiresClarification: desired.isEmpty || desired.allSatisfy { broadTerms.contains($0.term) }
        )
    }

    public func developHypotheses(
        request: String,
        sourceSnapshotID: UUID,
        scope: ProcessingScope,
        analysis: SourceAwareAnalysisReport
    ) throws -> ProductionIntentResult {
        let interpretation = try interpret(request: request, scope: scope)
        return try developHypotheses(
            interpretation: interpretation,
            sourceSnapshotID: sourceSnapshotID,
            scope: scope,
            analysis: analysis
        )
    }

    /// Converts an already decoded and validated semantic interpretation into
    /// evidence-grounded hypotheses and deterministic plans. This is the only
    /// entry point used by frontier-model adapters: provider output never
    /// contains executable DSP parameters and must pass the provider-contract
    /// validator before reaching this method.
    public func developHypotheses(
        interpretation: ProductionIntentInterpretation,
        sourceSnapshotID: UUID,
        scope: ProcessingScope,
        analysis: SourceAwareAnalysisReport,
        validatedStrategyProposals: [ModelHypothesisProposal] = []
    ) throws -> ProductionIntentResult {
        let expectedClass = try sourceClass(for: scope.sourceType)
        guard analysis.sourceClass == expectedClass else {
            throw ProductionIntentError.sourceAnalysisMismatch(expected: expectedClass, actual: analysis.sourceClass)
        }
        guard interpretation.version == "1.0",
              interpretation.sourceType == scope.sourceType else {
            throw ProductionIntentError.noActionableIntent(
                "The validated interpretation does not match the current source scope."
            )
        }
        guard !interpretation.desiredChanges.isEmpty else {
            return ProductionIntentResult(vocabularyVersion: vocabulary.version, interpretation: interpretation, hypotheses: [])
        }

        var seenProposalStrategies = Set<String>()
        var proposals: [ModelHypothesisProposal] = []
        for proposal in validatedStrategyProposals where proposals.count < 3 {
            let signature = Set(proposal.strategyCategories.map(\.rawValue))
                .sorted()
                .joined(separator: "|")
            if seenProposalStrategies.insert(signature).inserted {
                proposals.append(proposal)
            }
        }
        let hypotheses: [ProductionHypothesis]
        if proposals.isEmpty {
            hypotheses = [try makeHypothesis(
                interpretation: interpretation,
                sourceSnapshotID: sourceSnapshotID,
                scope: scope,
                analysis: analysis,
                proposal: nil,
                hypothesisIndex: 0
            )]
        } else {
            hypotheses = try proposals.enumerated().map { index, proposal in
                try makeHypothesis(
                    interpretation: interpretation,
                    sourceSnapshotID: sourceSnapshotID,
                    scope: scope,
                    analysis: analysis,
                    proposal: proposal,
                    hypothesisIndex: index
                )
            }
        }
        return ProductionIntentResult(
            vocabularyVersion: vocabulary.version,
            interpretation: interpretation,
            hypotheses: hypotheses
        )
    }

    private struct TermMatch {
        var term: ProductionTerm
        var phrase: String
        var range: NSRange
    }

    private func nonOverlappingMatches(in text: String) -> [TermMatch] {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var candidates: [TermMatch] = []
        for term in ProductionTerm.allCases {
            let definition = vocabulary.definition(for: term)
            for alias in definition.aliases.sorted(by: { $0.count > $1.count }) {
                let escaped = NSRegularExpression.escapedPattern(for: alias.lowercased())
                guard let expression = try? NSRegularExpression(
                    pattern: "(?<![a-z0-9])\(escaped)(?![a-z0-9])",
                    options: [.caseInsensitive]
                ), let match = expression.firstMatch(in: text, range: fullRange) else { continue }
                candidates.append(TermMatch(term: term, phrase: alias, range: match.range))
                break
            }
        }
        candidates.sort {
            if $0.range.length != $1.range.length { return $0.range.length > $1.range.length }
            return $0.range.location < $1.range.location
        }
        var selected: [TermMatch] = []
        for candidate in candidates where !selected.contains(where: { NSIntersectionRange($0.range, candidate.range).length > 0 }) {
            selected.append(candidate)
        }
        return selected.sorted { $0.range.location < $1.range.location }
    }

    private func directionForMatch(_ match: TermMatch, in text: String) -> ProductionIntentDirection {
        let nsText = text as NSString
        let contextStart = max(0, match.range.location - 48)
        let prefix = nsText.substring(with: NSRange(location: contextStart, length: match.range.location - contextStart))
        let immediateWords = prefix.split(whereSeparator: { !$0.isLetter }).suffix(7).joined(separator: " ")
        let phrase = match.phrase.lowercased()
        let negativeTerms: Set<ProductionTerm> = [.muddy, .boxy, .harsh, .sibilant, .thin, .boomy, .cymbalHarshness]

        if match.term == .level {
            let suffixStart = match.range.location + match.range.length
            let suffixLength = min(32, nsText.length - suffixStart)
            let suffix = suffixLength > 0
                ? nsText.substring(with: NSRange(location: suffixStart, length: suffixLength))
                : ""
            if phrase == "quieter" || phrase == "turn it down"
                || immediateWords.contains("turn down")
                || immediateWords.contains("lower")
                || (immediateWords.contains("pull") && suffix.contains("back")) {
                return .decrease
            }
            if phrase == "louder" || phrase == "turn it up"
                || immediateWords.contains("turn up")
                || immediateWords.contains("raise") {
                return .increase
            }
        }

        if phrase.hasPrefix("preserve ")
            || phrase.hasPrefix("keep the ")
            || immediateWords.contains("without losing")
            || immediateWords.contains("without burying")
            || immediateWords.contains("without damaging")
            || immediateWords.contains("keep it")
            || immediateWords.contains("keep the")
            || immediateWords.contains("preserve")
            || immediateWords.contains("maintain")
            || immediateWords.contains("retain") {
            return .preserve
        }
        if immediateWords.contains("without making")
            || immediateWords.contains("do not make")
            || immediateWords.contains("don t make")
            || immediateWords.contains("avoid increasing") {
            return .doNotIncrease
        }
        if immediateWords.contains("without reducing") || immediateWords.contains("do not reduce") {
            return .doNotDecrease
        }
        if immediateWords.contains("less")
            || immediateWords.contains("reduce")
            || immediateWords.contains("remove")
            || immediateWords.contains("tame")
            || immediateWords.contains("decrease") {
            return .decrease
        }
        return negativeTerms.contains(match.term) ? .decrease : .increase
    }

    private func requestedStrength(in text: String) -> Double {
        if text.contains("subtle") || text.contains("slight") || text.contains("a little") { return 0.35 }
        if text.contains("strong") || text.contains("much more") || text.contains("aggressively") { return 0.9 }
        return 0.62
    }

    private func uniqueGoals(_ goals: [InterpretedProductionGoal]) -> [InterpretedProductionGoal] {
        var seen = Set<String>()
        return goals.filter { seen.insert("\($0.term.rawValue)|\($0.direction.rawValue)").inserted }
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
            throw ProductionIntentError.noActionableIntent("No source-aware v1 analyzer exists for \(sourceType.rawValue).")
        }
    }

    private func makeHypothesis(
        interpretation: ProductionIntentInterpretation,
        sourceSnapshotID: UUID,
        scope: ProcessingScope,
        analysis: SourceAwareAnalysisReport,
        proposal: ModelHypothesisProposal?,
        hypothesisIndex: Int
    ) throws -> ProductionHypothesis {
        let desiredTerms = interpretation.desiredChanges.map(\.term)
        let definitions = desiredTerms.map { vocabulary.definition(for: $0) }
        let sourceRules = desiredTerms.flatMap { vocabulary.interpretations(for: $0, sourceType: scope.sourceType) }
        let relevantMetricIDs = Array(Set(sourceRules.flatMap(\.supportingMetricIdentifiers))).sorted()
        var supporting: [ProductionEvidenceObservation] = []
        var against: [ProductionEvidenceObservation] = []

        for identifier in relevantMetricIDs {
            guard let metric = analysis.metrics[identifier] else {
                against.append(.init(
                    metricIdentifier: identifier,
                    confidence: 0,
                    relationship: .unavailable,
                    interpretationBoundary: "The source-aware report does not expose this evidence; TrackSmith must not invent a value."
                ))
                continue
            }
            let observation = ProductionEvidenceObservation(
                metricIdentifier: identifier,
                value: metric.value,
                unit: metric.definition.unit.rawValue,
                confidence: metric.confidence,
                relationship: metric.confidence >= 0.5 ? .contextual : .arguesAgainstIntervention,
                interpretationBoundary: "This measurement can constrain a hypothesis but cannot prove ‘\(desiredTerms.map(\.rawValue).joined(separator: ", "))’. Known failures: \(metric.definition.knownFailureModes.joined(separator: "; ")).",
                provenance: metric.definition.provenance.map { source in
                    ProductionIntentProvenance(
                        sourceIdentity: source.sourceIdentity,
                        sourceVersion: source.sourceVersion,
                        relevantSection: source.relevantSection,
                        evidenceClass: ProductionEvidenceClass(rawValue: source.evidenceClass.rawValue) ?? .productHeuristic,
                        consequence: source.consequence
                    )
                }
            )
            if metric.confidence >= 0.5 { supporting.append(observation) } else { against.append(observation) }
        }

        let preservationTerms = interpretation.preservedAttributes + interpretation.prohibitedChanges
        for goal in preservationTerms {
            for rule in vocabulary.interpretations(for: goal.term, sourceType: scope.sourceType) {
                for identifier in rule.supportingMetricIdentifiers {
                    guard let metric = analysis.metrics[identifier] else { continue }
                    against.append(.init(
                        metricIdentifier: identifier,
                        value: metric.value,
                        unit: metric.definition.unit.rawValue,
                        confidence: metric.confidence,
                        relationship: .preservationCheck,
                        interpretationBoundary: "Monitor this evidence because ‘\(goal.term.rawValue)’ is a \(goal.direction.rawValue) constraint, not a target to sacrifice."
                    ))
                }
            }
        }

        let sourceOptions = Set(sourceRules.flatMap(\.candidateDSPStrategies))
        let proposedOptions = Set(proposal?.strategyCategories ?? [])
        let focusedOptions = sourceOptions.intersection(proposedOptions)
        let consideredOptions = proposal == nil || focusedOptions.isEmpty ? sourceOptions : focusedOptions
        // The original is always available as the listening baseline. A
        // provider proposal containing only listen/preserve/clarify semantics
        // must not become a fake processed preview whose level-only trim is
        // cancelled by mandatory loudness matching. Select a TrackSmith-owned,
        // source-relevant executable strategy for the audition plan while
        // retaining the provider's non-executable option as considered context.
        let executableStrategies: Set<ProductionDSPStrategy> = [
            .subtractiveEQ, .additiveEQ, .dynamicEQOrDeEsser,
            .gentleCompression, .transientPreservingCompression, .parallelCompression,
            .levelAutomation, .saturation, .stereoWidth, .ambienceOrDelay,
        ]
        let protectedStrategyTerms = Set(preservationTerms.map(\.term))
        func isViable(_ strategy: ProductionDSPStrategy) -> Bool {
            switch strategy {
            case .saturation:
                return protectedStrategyTerms.isDisjoint(with: [
                    .punchy, .pickAttack, .dynamic, .harsh, .cymbalHarshness, .sibilant,
                ])
            case .stereoWidth:
                return scope.channelFormat == .stereo
            case .ambienceOrDelay:
                return !protectedStrategyTerms.contains(.raw)
            default:
                return true
            }
        }
        let sourceExecutableOptions = Set(
            sourceOptions.intersection(executableStrategies).filter(isViable)
        )
        let focusedExecutableOptions = Set(
            focusedOptions.intersection(executableStrategies).filter(isViable)
        )
        let fallbackPriority: [ProductionDSPStrategy] = [
            .transientPreservingCompression, .gentleCompression,
            .subtractiveEQ, .additiveEQ, .dynamicEQOrDeEsser, .parallelCompression,
            .saturation, .ambienceOrDelay, .stereoWidth,
        ]
        let defaultFallback = fallbackPriority.first(where: sourceExecutableOptions.contains)
            .map { Set([$0]) } ?? sourceExecutableOptions
        let requestsImpact = !Set(desiredTerms).isDisjoint(with: [.punchy, .aggressive, .energetic])
        let fallbackPlanningOptions: Set<ProductionDSPStrategy>
        if proposedOptions.contains(.saturation), requestsImpact {
            // When saturation conflicts with a cymbal/crest preservation
            // constraint, retain a genuinely different density hypothesis by
            // combining one transient-safe dynamics strategy with one bounded
            // tonal strategy. This remains distinct from both compression-only
            // and EQ-only siblings without violating the protected attribute.
            var combined = Set<ProductionDSPStrategy>()
            if let dynamics = [
                ProductionDSPStrategy.transientPreservingCompression,
                .gentleCompression, .parallelCompression,
            ].first(where: sourceExecutableOptions.contains) {
                combined.insert(dynamics)
            }
            if let tonal = [
                ProductionDSPStrategy.additiveEQ, .subtractiveEQ, .dynamicEQOrDeEsser,
            ].first(where: sourceExecutableOptions.contains) {
                combined.insert(tonal)
            }
            fallbackPlanningOptions = combined.isEmpty ? defaultFallback : combined
        } else {
            fallbackPlanningOptions = defaultFallback
        }
        var planningOptions = proposal == nil
            ? sourceExecutableOptions
            : (focusedExecutableOptions.isEmpty ? fallbackPlanningOptions : focusedExecutableOptions)
        // Some concrete user goals currently have one narrow TrackSmith-owned
        // executable family. Do not let a globally valid strategy proposal for
        // another adjective silently starve those goals. Broader attributes
        // remain free to produce distinct competing hypotheses.
        let requiredCoverage: [ProductionTerm: ProductionDSPStrategy] = [
            .intimate: .additiveEQ,
            .distant: .ambienceOrDelay,
            .level: .levelAutomation,
        ]
        for term in desiredTerms {
            guard let coverage = requiredCoverage[term], isViable(coverage) else { continue }
            planningOptions.insert(coverage)
        }
        let options = Array(consideredOptions)
            .sorted { $0.rawValue < $1.rawValue }
        let executableOptions = Array(planningOptions).sorted { $0.rawValue < $1.rawValue }
        let provenance = uniqueProvenance(definitions.flatMap(\.provenance))
        let candidatePlans = try PreviewStrength.allCases.map { strength in
            try makeCandidatePlan(
                strength: strength,
                interpretation: interpretation,
                sourceSnapshotID: sourceSnapshotID,
                scope: scope,
                analysis: analysis,
                options: executableOptions,
                provenance: provenance,
                hypothesisIndex: hypothesisIndex,
                strategyFocus: proposal == nil ? nil : planningOptions
            )
        }
        let balancedID = candidatePlans.first(where: { $0.strength == .balanced })?.identifier
            ?? candidatePlans[0].identifier
        let groundedIntended = interpretation.desiredChanges.map {
            "\($0.direction.rawValue) \($0.term.rawValue): \($0.interpretation)"
        }.joined(separator: " | ")
        let intended = proposal.map {
            "\($0.intendedOutcome) | Grounded TrackSmith interpretation: \(groundedIntended)"
        } ?? groundedIntended
        let constraints = preservationTerms.map { "\($0.direction.rawValue) \($0.term.rawValue)" }
        let risks = Array(Set(
            sourceRules.flatMap(\.preservationRisks)
                + definitions.flatMap(\.preservationRisks)
                + (proposal?.risks ?? [])
        )).sorted()

        return ProductionHypothesis(
            intendedPerceptualChange: intended,
            sourceContext: "\(scope.sourceType.rawValue), \(scope.channelFormat.rawValue), \(scope.kind.rawValue); analysis v\(analysis.version)",
            evidenceSupportingIntervention: supporting,
            evidenceAgainstIntervention: against,
            uncertainty: [
                "Production adjectives do not have unique acoustic definitions.",
                "The implemented metrics are within-capture descriptors without genre- or role-calibrated semantic thresholds.",
                "Existing processing, arrangement relationships, monitoring, and user taste are only partially observable.",
            ] + interpretation.unresolvedAmbiguities,
            processingOptionsConsidered: options,
            selectedStrategyIdentifier: balancedID,
            preservationConstraints: constraints,
            risks: risks,
            expectedMeasurableDirection: expectedChanges(for: interpretation),
            provenance: provenance,
            candidatePlans: candidatePlans
        )
    }

    private func makeCandidatePlan(
        strength: PreviewStrength,
        interpretation: ProductionIntentInterpretation,
        sourceSnapshotID: UUID,
        scope: ProcessingScope,
        analysis: SourceAwareAnalysisReport,
        options: [ProductionDSPStrategy],
        provenance: [ProductionIntentProvenance],
        hypothesisIndex: Int,
        strategyFocus: Set<ProductionDSPStrategy>?
    ) throws -> CandidateProductionPlan {
        let scale: Double = switch strength {
        case .conservative: 0.5
        case .balanced: 1.5
        case .strong: 3.0
        }
        let nodes = groundedNodes(
            desired: interpretation.desiredChanges,
            preserved: interpretation.preservedAttributes,
            prohibited: interpretation.prohibitedChanges,
            sourceType: scope.sourceType,
            channelFormat: scope.channelFormat,
            scale: scale,
            analysis: analysis,
            strategyFocus: strategyFocus
        )
        let goals = schemaGoals(for: interpretation, scale: scale)
        let plan = ProcessingPlan(
            sourceSnapshotID: sourceSnapshotID,
            scope: scope,
            goals: goals,
            nodes: nodes,
            outputConstraints: .init(
                maxTruePeakDB: -1,
                loudnessMatchPreview: true,
                preserveMonoCompatibility: true,
                maxAddedGainDB: 6
            )
        )
        try PlanValidator().validateForRealtimeActivation(plan, currentSnapshotID: sourceSnapshotID)
        return CandidateProductionPlan(
            identifier: "source-aware-v1-h\(hypothesisIndex + 1)-\(strength.rawValue)",
            strength: strength,
            summary: "A \(strength.rawValue) source-aware deterministic plan; parameters scale within validated bounds and preservation constraints remain explicit.",
            processingOptions: options,
            plan: plan,
            validationNotes: [
                "Validated by PlanValidator.validateForRealtimeActivation.",
                "Ends in the implemented -3 dBFS sample-peak safety limiter to leave inter-sample margin; rendered true peak still requires measurement.",
                "Preview loudness matching is required before subjective comparison.",
            ],
            provenance: provenance
        )
    }

    private func schemaGoals(
        for interpretation: ProductionIntentInterpretation,
        scale: Double
    ) -> [ProcessingGoal] {
        let all = interpretation.desiredChanges + interpretation.preservedAttributes + interpretation.prohibitedChanges
        var result: [ProcessingGoal] = []
        for goal in all {
            let attribute = schemaAttribute(for: goal.term)
            let direction: GoalDirection = switch goal.direction {
            case .increase: .increase
            case .decrease: .decrease
            case .preserve: .preserve
            case .doNotIncrease: .doNotIncrease
            case .doNotDecrease: .doNotDecrease
            }
            if !result.contains(where: { $0.attribute == attribute && $0.direction == direction }) {
                result.append(.init(
                    attribute: attribute,
                    direction: direction,
                    strength: min(1, goal.strength * scale),
                    locked: goal.direction == .preserve || goal.direction == .doNotIncrease || goal.direction == .doNotDecrease
                ))
            }
        }
        return result
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

    private func groundedNodes(
        desired: [InterpretedProductionGoal],
        preserved: [InterpretedProductionGoal],
        prohibited: [InterpretedProductionGoal],
        sourceType: SourceType,
        channelFormat: ChannelFormat,
        scale: Double,
        analysis: SourceAwareAnalysisReport,
        strategyFocus: Set<ProductionDSPStrategy>?
    ) -> [ProcessingNode] {
        var desiredDirections: [ProductionTerm: ProductionIntentDirection] = [:]
        for goal in desired {
            desiredDirections[goal.term] = goal.direction
        }
        let protectedTerms = Set((preserved + prohibited).map(\.term))
        let baseRMS = analysis.baseReport.metrics["rms_dbfs"]?.value ?? -22
        let crest = max(1.42, min(12, analysis.baseReport.metrics["crest_factor"]?.value ?? 3))
        var nodes: [ProcessingNode] = []
        // Every positive linear gain in the candidate shares the same explicit
        // graph budget. Multiple valid semantic goals must not combine into a
        // plan that only fails at the final PlanValidator gate.
        var remainingAddedGainDB = 6.0

        func budgetedGainDB(_ requested: Double) -> Double {
            guard requested > 0 else { return requested }
            let accepted = min(requested, remainingAddedGainDB)
            remainingAddedGainDB -= accepted
            return accepted
        }

        func allows(_ strategies: Set<ProductionDSPStrategy>) -> Bool {
            guard let strategyFocus else { return true }
            return !strategyFocus.isDisjoint(with: strategies)
        }
        let allowsEQ = allows([.subtractiveEQ, .additiveEQ, .dynamicEQOrDeEsser])
        let allowsCompression = allows([.gentleCompression, .transientPreservingCompression, .parallelCompression])
        let allowsSaturation = allows([.saturation])
        let allowsWidth = allows([.stereoWidth])
        let allowsAmbience = allows([.ambienceOrDelay])

        func addEQ(_ frequency: Double, _ gain: Double, q: Double, rationale: String, locked: Bool = false) {
            let gainDB = budgetedGainDB(gain * scale)
            guard gainDB != 0 else { return }
            nodes.append(.init(
                type: .parametricEQ,
                parameters: [.frequencyHz: frequency, .q: q, .gainDB: gainDB],
                rationale: rationale,
                confidence: 0.58,
                category: .corrective,
                locked: locked
            ))
        }

        func addCompression(punch: Bool, rationale: String) {
            // Map the three preview strengths continuously. The former step
            // function jumped a balanced candidate to near-full-wet 5.8:1
            // compression, creating enough gain loss that the bounded +6 dB
            // preview matcher could not make a fair A/B comparison.
            // The conservative variant must remain perceptibly distinct after
            // level matching. Below 0.35, short low-frequency fixtures could
            // produce a technically non-bypassed graph that still fell below
            // TrackSmith's source-relative audibility floor.
            let dynamicsScale = min(1.25, max(0.35, scale / 2))
            let automaticAttack = min(80, max(5, 160 / (crest * crest)))
            let attack = punch ? max(24, automaticAttack * 1.8) : max(12, automaticAttack)
            let release = min(450, max(sourceType == .vocal ? 90 : 65, 2_000 / (crest * crest) - attack))
            let threshold = min(-3, max(-48, baseRMS + 1 - 5 * dynamicsScale))
            nodes.append(.init(
                type: .compressor,
                parameters: [
                    .thresholdDB: threshold,
                    .ratio: 1.2 + 2.3 * dynamicsScale,
                    .attackMS: attack,
                    .releaseMS: release,
                    .makeupGainDB: 0,
                    .kneeDB: min(24, 5 + 3 * dynamicsScale),
                    .mix: min(0.96, (punch ? 0.35 : 0.45) + 0.27 * dynamicsScale),
                ],
                rationale: rationale,
                confidence: 0.74,
                category: .corrective
            ))
        }

        if desiredDirections[.warm] == .increase {
            let settings: (drive: Double, mix: Double, extraEQ: (Double, Double)?) = switch sourceType {
            case .vocal, .vocalBus: (5.5, 0.42, nil)
            case .drums, .drumBus: (4.0, 0.32, (180, 0.4))
            case .bass: (6.0, 0.45, (220, 0.4))
            case .guitar: (4.5, 0.35, (240, 0.55))
            case .keyboard, .synth: (5.0, 0.4, (190, 0.65))
            case .fullMix: (3.0, 0.25, nil)
            case .reference, .unknown: (0, 0, nil)
            }
            let protectsLeadingEdge = protectedTerms.contains(.punchy)
                || protectedTerms.contains(.pickAttack)
            let protectsUpperHarshness = protectedTerms.contains(.harsh)
                || protectedTerms.contains(.cymbalHarshness)
                || protectedTerms.contains(.sibilant)
            if settings.drive > 0, allowsSaturation, !protectsLeadingEdge, !protectsUpperHarshness {
                nodes.append(.init(
                    type: .saturation,
                    parameters: [.driveDB: settings.drive * scale, .mix: min(0.92, settings.mix * scale)],
                    rationale: "Use a source-specific low-mix nonlinear density hypothesis; ‘warm’ is not reduced to one EQ band or analog label.",
                    confidence: 0.56,
                    category: .creative
                ))
            }
            if let extra = settings.extraEQ, allowsEQ {
                let bodyGain = protectsLeadingEdge ? extra.1 * 4 : extra.1
                addEQ(
                    extra.0,
                    bodyGain,
                    q: 0.7,
                    rationale: protectsLeadingEdge
                        ? "Prefer bounded body EQ over peak-flattening saturation because leading-edge punch is explicitly preserved."
                        : "Test restrained source-specific body while monitoring masking and headroom."
                )
            }
        }

        if allowsEQ && (
            desiredDirections[.clear] == .increase
                || desiredDirections[.muddy] == .decrease
                || desiredDirections[.boxy] == .decrease
                || desiredDirections[.boomy] == .decrease
        ) {
            let frequency: Double = switch sourceType {
            case .vocal, .vocalBus: desiredDirections[.boxy] == .decrease ? 620 : 280
            case .drums, .drumBus: desiredDirections[.boomy] == .decrease ? 120 : 360
            case .bass: desiredDirections[.boomy] == .decrease ? 145 : 240
            case .guitar: 420
            case .keyboard, .synth: 330
            case .fullMix: 310
            case .reference, .unknown: 300
            }
            addEQ(frequency, -1.8, q: 0.9, rationale: "Reduce a source-specific masking candidate without equating the band measurement with a semantic verdict.")
        }

        // Direct level is intentionally represented by a bounded trim, never
        // by compression or a quality adjective. Mandatory preview loudness
        // matching may make this unsuitable as a standalone artistic A/B, but
        // the node remains useful for explicit conversational revisions of an
        // existing working graph.
        if desiredDirections[.level] == .increase || desiredDirections[.level] == .decrease {
            let sign = desiredDirections[.level] == .decrease ? -1.0 : 1.0
            nodes.append(.init(
                type: .outputTrim,
                parameters: [.gainDB: sign * min(3, 0.75 * scale)],
                rationale: "Apply only the explicit bounded level direction; do not reinterpret it as dynamics, tone, or production quality.",
                confidence: 0.9,
                category: .loudness
            ))
        }

        if allowsEQ, desiredDirections[.thin] == .decrease {
            let frequency: Double = sourceType == .bass ? 170 : (sourceType == .vocal ? 220 : 260)
            addEQ(frequency, 0.8, q: 0.75, rationale: "Test restrained body restoration while preserving low-end headroom.")
        }

        if allowsEQ && (
            desiredDirections[.harsh] == .decrease
                || desiredDirections[.cymbalHarshness] == .decrease
        ) {
            let frequency: Double = switch sourceType {
            case .vocal, .vocalBus: 4_800
            case .drums, .drumBus: 7_200
            case .bass: 3_100
            case .guitar: 3_200
            case .keyboard, .synth: 3_600
            case .fullMix: 3_400
            case .reference, .unknown: 3_500
            }
            addEQ(frequency, -3.4, q: 1.2, rationale: "Test a bounded source-specific presence-band reduction while preserving articulation.")
        }

        if allows([.dynamicEQOrDeEsser]), desiredDirections[.sibilant] == .decrease, sourceType == .vocal || sourceType == .vocalBus {
            let detector = analysis.baseReport.metrics["sibilance_detector_rms_dbfs"]?.value ?? -32
            nodes.append(.init(
                type: .deEsser,
                parameters: [
                    .frequencyHz: 6_500,
                    .thresholdDB: min(-10, max(-42, detector + 7 - 5 * scale)),
                    .ratio: 1.2 + 3 * scale,
                    .attackMS: 1.5,
                    .releaseMS: 70,
                    .mix: min(1, 0.35 + 0.4 * scale),
                ],
                rationale: "Use event-relative upper-band attenuation and preserve air/intelligibility; whole-capture brightness is not treated as sibilance.",
                confidence: 0.72,
                category: .corrective
            ))
            if scale >= 2, allowsEQ, !protectedTerms.contains(.airy) {
                addEQ(
                    7_600,
                    -1.2,
                    q: 2.2,
                    rationale: "The strong interpretation adds a bounded narrow-band restraint after event-relative de-essing; reject it by listening if air or diction suffers."
                )
            }
        }

        if allowsCompression && (
            desiredDirections[.punchy] == .increase
                || desiredDirections[.aggressive] == .increase
                || desiredDirections[.energetic] == .increase
        ) {
            addCompression(
                punch: true,
                rationale: "Use source- and crest-dependent ballistics with a slower attack and parallel dry path to preserve leading transients."
            )
            if allowsEQ && (sourceType == .drums || sourceType == .drumBus) {
                addEQ(88, 1.6, q: 0.8, rationale: "Test bounded low-frequency drum impact without increasing cymbal-band energy.")
            }
        }

        if allowsCompression && (
            desiredDirections[.controlled] == .increase
                || desiredDirections[.tight] == .increase
                || desiredDirections[.smooth] == .increase
        ) {
            addCompression(
                punch: protectedTerms.contains(.dynamic) || protectedTerms.contains(.pickAttack),
                rationale: "Control signal-relative variability while preserving the explicitly protected dynamics or onset when present."
            )
            if desiredDirections[.tight] == .increase,
               protectedTerms.contains(.lowEndWeight), allowsEQ {
                let frequency: Double = sourceType == .bass ? 72 : 88
                addEQ(
                    frequency,
                    1.5,
                    q: 0.7,
                    rationale: "Compensate bounded low-band weight after dynamics-led tightening because low-end weight is an explicit preservation constraint."
                )
            }
        }

        if allowsEQ && (
            desiredDirections[.bright] == .increase
                || desiredDirections[.airy] == .increase
                || desiredDirections[.forward] == .increase
        ) {
            let blocksBrightness = protectedTerms.contains(.bright)
                || protectedTerms.contains(.harsh)
                || protectedTerms.contains(.sibilant)
                || protectedTerms.contains(.cymbalHarshness)
            if !blocksBrightness {
                let frequency = desiredDirections[.airy] == .increase ? 12_000.0 : 4_500.0
                addEQ(frequency, desiredDirections[.airy] == .increase ? 1.0 : 1.2, q: 0.65, rationale: "Test a bounded upper-band change while monitoring event-specific harshness and sibilance.")
            }
        }

        if allowsEQ && (
            desiredDirections[.dark] == .increase || desiredDirections[.soft] == .increase
        ) {
            addEQ(6_500, -0.75, q: 0.7, rationale: "Test reduced upper-band salience without assuming darkness or softness is one fixed cutoff.")
        }

        if allowsWidth, desiredDirections[.wide] == .increase, channelFormat == .stereo {
            let monoRetention = analysis.metrics["mono_sum_energy_ratio"]?.value ?? 1
            let lowSide = analysis.metrics["low_band_side_energy_share"]?.value ?? 0
            let constraintScale = monoRetention < 0.75 || lowSide > 0.25 ? 0.45 : 1
            nodes.append(.init(
                type: .stereoWidth,
                parameters: [.width: 1 + 0.22 * scale * constraintScale, .mix: 0.65],
                rationale: "Apply conservative stereo widening scaled down when mono retention or low-band side evidence is concerning.",
                confidence: 0.64,
                category: .creative
            ))
        }
        if allowsWidth, desiredDirections[.narrow] == .increase, channelFormat == .stereo {
            nodes.append(.init(
                type: .stereoWidth,
                parameters: [.width: max(0.65, 1 - 0.25 * scale), .mix: 0.75],
                rationale: "Reduce side contribution conservatively while preserving balance and auditioning the result in stereo and mono.",
                confidence: 0.62,
                category: .creative
            ))
        }

        if allowsAmbience, desiredDirections[.distant] == .increase {
            let protectsClarity = protectedTerms.contains(.clear)
                || protectedTerms.contains(.forward)
                || protectedTerms.contains(.punchy)
                || protectedTerms.contains(.pickAttack)
            let wetScale = protectsClarity ? 0.55 : 1
            nodes.append(.init(
                type: .reverb,
                parameters: [
                    .algorithmVersion: 1,
                    .preDelayMS: protectsClarity ? 28 : 14,
                    .decayTimeSeconds: min(3, 0.55 + 0.38 * scale),
                    .roomSize: min(0.9, 0.3 + 0.14 * scale),
                    .damping: 0.48,
                    .diffusion: 0.68,
                    .mix: min(0.42, 0.08 + 0.08 * scale) * wetScale,
                ],
                rationale: "Test a bounded TrackSmith algorithmic-room interpretation of distance; predelay and wet depth are constrained when clarity, onset, or forwardness is preserved.",
                confidence: 0.53,
                category: .creative
            ))
        }

        // Intimacy is not implemented as a fixed reverb preset. A level-only
        // move would be cancelled by mandatory preview level matching, so pair
        // direct-source salience with a bounded presence hypothesis.
        if allows([.additiveEQ]), desiredDirections[.intimate] == .increase {
            var addedPresenceProcessing = false
            if allowsEQ {
                let nodeCount = nodes.count
                addEQ(
                    2_200,
                    0.9,
                    q: 0.75,
                    rationale: "Test restrained direct-source presence while preserving air and avoiding an invented ambience-removal claim."
                )
                addedPresenceProcessing = nodes.count > nodeCount
            }
            let directGainDB = addedPresenceProcessing ? budgetedGainDB(0.35 * scale) : 0
            if directGainDB > 0 {
                nodes.append(.init(
                    type: .outputTrim,
                    parameters: [.gainDB: directGainDB],
                    rationale: "Test slightly greater direct-source salience; do not invent or remove ambience without a validated ambience metric.",
                    confidence: 0.42,
                    category: .creative
                ))
            }
        }

        if strategyFocus != nil, allowsCompression,
           !nodes.contains(where: { $0.type == .compressor }) {
            addCompression(
                punch: protectedTerms.contains(.dynamic) || protectedTerms.contains(.pickAttack),
                rationale: "Materialize the selected bounded dynamics hypothesis alongside other explicitly required goal coverage."
            )
        }

        if nodes.isEmpty, strategyFocus != nil {
            if allowsCompression {
                addCompression(
                    punch: protectedTerms.contains(.dynamic) || protectedTerms.contains(.pickAttack),
                    rationale: "Test a bounded dynamics-led interpretation because the validated hypothesis selected compression; this does not prove the production adjective."
                )
            } else if allowsSaturation {
                nodes.append(.init(
                    type: .saturation,
                    parameters: [
                        .driveDB: min(12, 4 + 3 * scale),
                        .mix: min(0.65, 0.12 + 0.2 * scale),
                    ],
                    rationale: "Test a restrained nonlinear-density interpretation selected by the validated hypothesis while preserving the dry source.",
                    confidence: 0.44,
                    category: .creative
                ))
            } else if allowsAmbience {
                nodes.append(.init(
                    type: .delay,
                    parameters: [
                        .algorithmVersion: 1,
                        .delayTimeMS: sourceType == .vocal || sourceType == .vocalBus ? 92 : 145,
                        .feedback: min(0.45, 0.12 + 0.08 * scale),
                        .damping: 0.45,
                        .stereoCrossfeed: channelFormat == .stereo ? 0.2 : 0,
                        .mix: min(0.3, 0.06 + 0.06 * scale),
                    ],
                    rationale: "Materialize the selected bounded ambience/delay interpretation as a discrete TrackSmith echo; this is not a Logic processor model or a universal distance mapping.",
                    confidence: 0.43,
                    category: .creative
                ))
            } else if allowsEQ {
                let frequency: Double = sourceType == .bass ? 260 : (sourceType == .drums || sourceType == .drumBus ? 420 : 520)
                addEQ(frequency, -0.55, q: 0.85, rationale: "Test a conservative masking-reduction interpretation selected by the validated hypothesis.")
            }
        }

        nodes.append(.init(
            type: .limiter,
            parameters: [.ceilingDB: -3, .releaseMS: 80, .lookaheadMS: 0],
            rationale: "Catch unsafe sample peaks with inter-sample margin; rendered true peak and loudness matching are measured separately.",
            confidence: 0.9,
            category: .loudness
        ))
        return nodes
    }

    private func expectedChanges(for interpretation: ProductionIntentInterpretation) -> [ExpectedMetricChange] {
        var changes: [ExpectedMetricChange] = []
        for goal in interpretation.desiredChanges {
            let rules = vocabulary.interpretations(for: goal.term, sourceType: interpretation.sourceType)
            for identifier in rules.flatMap(\.supportingMetricIdentifiers).prefix(4) {
                let direction: ExpectedMeasurementDirection = switch goal.term {
                case .muddy, .boxy, .boomy, .harsh, .sibilant, .cymbalHarshness:
                    goal.direction == .decrease ? .decrease : .uncertain
                case .wide:
                    identifier.contains("side") ? .increase : .uncertain
                case .narrow:
                    identifier.contains("side") ? .decrease : .uncertain
                case .controlled, .smooth, .tight:
                    identifier.contains("variability") || identifier.contains("sustain") ? .decrease : .uncertain
                case .punchy, .pickAttack:
                    identifier.contains("flux") || identifier.contains("crest") ? .preserve : .uncertain
                case .level:
                    identifier == "rms_dbfs" || identifier.contains("loudness") ? goal.direction == .increase ? .increase : .decrease : .uncertain
                default:
                    .uncertain
                }
                changes.append(.init(
                    metricIdentifier: identifier,
                    direction: direction,
                    rationale: "Expected direction is a validation aid for the selected hypothesis, not proof of the perceptual term."
                ))
            }
        }
        for constraint in interpretation.preservedAttributes + interpretation.prohibitedChanges {
            for identifier in vocabulary.interpretations(for: constraint.term, sourceType: interpretation.sourceType)
                .flatMap(\.supportingMetricIdentifiers).prefix(3) {
                changes.append(.init(
                    metricIdentifier: identifier,
                    direction: .preserve,
                    rationale: "Explicit \(constraint.direction.rawValue) constraint for \(constraint.term.rawValue)."
                ))
            }
        }
        var seen = Set<String>()
        return changes.filter { seen.insert("\($0.metricIdentifier)|\($0.direction.rawValue)").inserted }
    }

    private func uniqueProvenance(_ entries: [ProductionIntentProvenance]) -> [ProductionIntentProvenance] {
        var seen = Set<String>()
        return entries.filter {
            seen.insert("\($0.sourceIdentity)|\($0.sourceVersion)|\($0.relevantSection)").inserted
        }
    }
}
