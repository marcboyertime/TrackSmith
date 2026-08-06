import Foundation
import PlanSchema

public struct RetrievedKnowledge: Equatable, Sendable {
    public var claims: [ProductionKnowledgeClaim]
    public var strategies: [ProductionStrategyCard]
    public var concepts: [ProductionConceptCard]
    public var contradictions: [ContradictionRecord]
    public var coverage: RetrievalCoverage

    public init(
        claims: [ProductionKnowledgeClaim],
        strategies: [ProductionStrategyCard],
        concepts: [ProductionConceptCard],
        contradictions: [ContradictionRecord],
        coverage: RetrievalCoverage
    ) {
        self.claims = claims
        self.strategies = strategies
        self.concepts = concepts
        self.contradictions = contradictions
        self.coverage = coverage
    }

    public var isEmpty: Bool {
        claims.isEmpty && strategies.isEmpty && concepts.isEmpty
    }

    public var sourceIDs: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for id in claims.map(\.sourceID) + concepts.flatMap(\.sourceIDs)
        where seen.insert(id).inserted { out.append(id) }
        return out
    }
}

/// How well local reviewed knowledge covers the question. Weak coverage is
/// surfaced to the user and is what triggers a research offer.
public enum RetrievalCoverage: String, Codable, CaseIterable, Sendable {
    case strong
    case partial
    case weak
    case none
}

/// Deterministic lexical retrieval over the reviewed knowledge base.
///
/// Chosen over an embedding index because it is fully local, reproducible,
/// inspectable, and small. Ranking is BM25-like over term frequency with
/// typed domain/kind/source filters layered on top, and every tie is broken by
/// stable ID so the same question always retrieves the same cards.
public struct GeneralTutorRetriever: Sendable {
    public static let maximumClaims = 12
    public static let maximumStrategies = 5
    public static let maximumConcepts = 4
    /// No single source may supply more than this share of retrieved claims,
    /// so one article cannot dominate an answer.
    public static let maximumClaimsPerSource = 4

    private let base: GeneralTutorKnowledgeBase

    public init(base: GeneralTutorKnowledgeBase) {
        self.base = base
    }

    public init() throws {
        self.base = try GeneralTutorKnowledgeBase.loadValidated()
    }

    public var knowledgeBase: GeneralTutorKnowledgeBase { base }

    public func retrieve(for intent: GeneralTutorQuestionIntent) -> RetrievedKnowledge {
        let terms = queryTerms(intent)
        let domains = Set(intent.allDomains)
        let groups = Set(intent.allDomains.map(\.group))

        // Concepts first: an explain-a-concept question is answered directly
        // from a concept card when one matches by term or alias.
        let concepts = rankConcepts(terms: terms, domains: domains, intent: intent)

        var scoredClaims: [(ProductionKnowledgeClaim, Double)] = []
        for claim in base.claims {
            guard claim.reviewState.isTrusted else { continue }
            guard let source = base.source(claim.sourceID), source.isUsableForMaterialClaims else { continue }
            var score = lexicalScore(text: claim.claimText, terms: terms)
            score += domainScore(cardDomains: claim.domains, domains: domains, groups: groups)
            if claim.applicableQuestionKinds.contains(intent.questionKind) { score += 1.5 }
            if claim.applicableSourceTypes.contains(intent.sourceType) { score += 1.0 }
            // Tier A documentary behavior outranks practice heuristics when both match.
            if source.tier == .tierAPrimaryOrDirect { score += 0.75 }
            if score > 0 { scoredClaims.append((claim, score)) }
        }

        var scoredStrategies: [(ProductionStrategyCard, Double)] = []
        for strategy in base.strategies {
            guard strategy.reviewState.isTrusted else { continue }
            let text = [strategy.label, strategy.problemOrOutcome,
                        strategy.recommendedFirstExperiment, strategy.whyItMayHelp]
                .joined(separator: " ")
            var score = lexicalScore(text: text, terms: terms)
            score += domainScore(cardDomains: strategy.domains, domains: domains, groups: groups)
            if strategy.applicableQuestionKinds.contains(intent.questionKind) { score += 1.5 }
            if strategy.applicableSourceTypes.contains(intent.sourceType) { score += 1.25 }
            if score > 0 { scoredStrategies.append((strategy, score)) }
        }

        let claims = diversify(
            rank(scoredClaims, id: \.id),
            limit: Self.maximumClaims,
            perSource: Self.maximumClaimsPerSource,
            sourceOf: { $0.sourceID }
        )
        let strategies = Array(rank(scoredStrategies, id: \.id).prefix(Self.maximumStrategies))

        // Contradictions are included whenever they touch a retrieved claim,
        // so material disagreement is disclosed rather than silently dropped.
        let retrievedClaimIDs = Set(claims.map(\.id))
        let contradictions = base.contradictions.filter { record in
            !Set(record.positionAClaimIDs + record.positionBClaimIDs)
                .isDisjoint(with: retrievedClaimIDs)
                || !Set(record.domains).isDisjoint(with: domains)
        }

        return RetrievedKnowledge(
            claims: claims,
            strategies: strategies,
            concepts: concepts,
            contradictions: contradictions,
            coverage: coverage(claims: claims, strategies: strategies, concepts: concepts, intent: intent)
        )
    }

    // MARK: - Scoring

    private func queryTerms(_ intent: GeneralTutorQuestionIntent) -> [String] {
        let text = ([intent.problemSummary, intent.desiredOutcome]
            + intent.preservationConstraints
            + intent.comparisonAlternatives
            + intent.namedEntities).joined(separator: " ")
        return tokenize(text)
    }

    private func tokenize(_ text: String) -> [String] {
        let stop: Set<String> = [
            "the", "a", "an", "and", "or", "but", "is", "are", "was", "were", "be",
            "to", "of", "in", "on", "it", "this", "that", "my", "i", "me", "do",
            "does", "how", "what", "why", "when", "should", "would", "can", "with",
            "for", "so", "if", "not", "too", "more", "less", "make", "makes", "get",
            "you", "your", "at", "as", "from", "have", "has", "there", "then",
        ]
        return text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 && !stop.contains($0) }
    }

    /// Saturating term-frequency scoring: repeated hits help but with
    /// diminishing return, which keeps long cards from dominating.
    private func lexicalScore(text: String, terms: [String]) -> Double {
        guard !terms.isEmpty else { return 0 }
        let haystack = text.lowercased()
        let tokens = Set(tokenize(text))
        var score = 0.0
        for term in Set(terms) {
            if tokens.contains(term) {
                score += 2.0
            } else if term.count > 4, haystack.contains(term) {
                score += 1.0
            }
        }
        return score
    }

    private func domainScore(
        cardDomains: [ProductionDomain],
        domains: Set<ProductionDomain>,
        groups: Set<ProductionDomainGroup>
    ) -> Double {
        guard !cardDomains.isEmpty else { return 0 }
        let exact = cardDomains.filter { domains.contains($0) }.count
        let grouped = cardDomains.filter { groups.contains($0.group) }.count
        return Double(exact) * 2.0 + Double(grouped) * 0.5
    }

    private func rank<T>(_ scored: [(T, Double)], id: KeyPath<T, String>) -> [T] {
        scored.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0[keyPath: id] < $1.0[keyPath: id]
        }.map(\.0)
    }

    private func diversify<T>(
        _ items: [T],
        limit: Int,
        perSource: Int,
        sourceOf: (T) -> String
    ) -> [T] {
        var counts: [String: Int] = [:]
        var out: [T] = []
        for item in items {
            let source = sourceOf(item)
            let used = counts[source, default: 0]
            guard used < perSource else { continue }
            counts[source] = used + 1
            out.append(item)
            if out.count == limit { break }
        }
        return out
    }

    private func rankConcepts(
        terms: [String],
        domains: Set<ProductionDomain>,
        intent: GeneralTutorQuestionIntent
    ) -> [ProductionConceptCard] {
        var scored: [(ProductionConceptCard, Double)] = []
        let haystack = intent.problemSummary.lowercased()
        for concept in base.concepts where concept.reviewState.isTrusted {
            var score = 0.0
            // An explicit term or alias mention is the strongest signal.
            for name in [concept.term] + concept.aliases where haystack.contains(name.lowercased()) {
                score += 6.0
            }
            score += lexicalScore(
                text: [concept.term, concept.simpleExplanation, concept.causalExplanation]
                    .joined(separator: " "),
                terms: terms
            ) * 0.5
            score += Double(concept.domains.filter { domains.contains($0) }.count) * 1.5
            if intent.questionKind == .explainConcept { score *= 1.5 }
            if score > 0 { scored.append((concept, score)) }
        }
        return Array(rank(scored, id: \.id).prefix(Self.maximumConcepts))
    }

    private func coverage(
        claims: [ProductionKnowledgeClaim],
        strategies: [ProductionStrategyCard],
        concepts: [ProductionConceptCard],
        intent: GeneralTutorQuestionIntent
    ) -> RetrievalCoverage {
        if claims.isEmpty && strategies.isEmpty && concepts.isEmpty { return .none }
        // A concept question is well covered by one strong concept card.
        if intent.questionKind == .explainConcept, !concepts.isEmpty { return .strong }
        if strategies.count >= 2 && claims.count >= 4 { return .strong }
        if !strategies.isEmpty || claims.count >= 3 { return .partial }
        return .weak
    }
}
