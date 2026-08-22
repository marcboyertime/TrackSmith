import CryptoKit
import Foundation
import SQLite3

/// Process-level readiness.  This deliberately remains separate from a single
/// query result: a valid no-match must not be represented as a broken index.
public enum CandidateRetrievalAvailability: String, Codable, Equatable, Sendable { case ready, unavailable, corrupt, schemaDrift, versionMismatch, disabled }

/// Safe, model-visible outcome for one lower-authority corpus lookup.  It
/// never carries a path, SQL text, or database error.  The finer distinctions
/// let the Tutor abstain honestly without turning transient query trouble into
/// a semantic "no match" claim.
public enum CandidateRetrievalOutcomeKind: String, Codable, Equatable, Sendable {
    case matches, noMatch, queryFailed, malformedSelectedPayload, schemaDrift, corrupt, disabled, unavailable, versionMismatch
}

public struct CandidateRetrievalOutcome: Sendable {
    public let kind: CandidateRetrievalOutcomeKind
    public let cards: [CommunityCandidateCorpusRankedCard]
    public init(kind: CandidateRetrievalOutcomeKind, cards: [CommunityCandidateCorpusRankedCard] = []) {
        self.kind = kind
        self.cards = cards
    }
}

public protocol CandidateRetriever: Sendable {
    func availability() async -> CandidateRetrievalAvailability
    func ranked(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) async -> [CommunityCandidateCorpusRankedCard]
    func rankedOutcome(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) async -> CandidateRetrievalOutcome
}

public extension CandidateRetriever {
    /// Backward-compatible default for injected P16/P18 oracle stubs.  New
    /// production readers override this with typed execution failures.
    func rankedOutcome(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) async -> CandidateRetrievalOutcome {
        switch await availability() {
        case .ready:
            let cards = await ranked(query: query, filters: filters, limit: limit)
            return .init(kind: cards.isEmpty ? .noMatch : .matches, cards: cards)
        case .unavailable: return .init(kind: .unavailable)
        case .corrupt: return .init(kind: .corrupt)
        case .schemaDrift: return .init(kind: .schemaDrift)
        case .versionMismatch: return .init(kind: .versionMismatch)
        case .disabled: return .init(kind: .disabled)
        }
    }
}
public struct CandidateRetrievalOpenResult: Sendable { public let availability: CandidateRetrievalAvailability; public let retriever: CandidateRetrievalIndex? }

private struct CandidateRetrievalManifest: Decodable { let schema_version, corpus_version, retrieval_policy_version: String; let card_count, package_017_runtime_count, database_bytes: Int; let database, database_header_sha256: String }
private struct CandidateRankMetadata { let id, packageID, questionKey, domain, category, evidenceClass: String; let sourceTypes, roleFacets, sectionFacets, primaryTerms, facetTerms, contextTerms: Set<String>; let currentContext: Bool; let bm25: Double }

/// Immutable actor-owned SQLite reader. FTS returns compact ranking fields;
/// payload JSON is fetched and decoded only for final bounded IDs.
public actor CandidateRetrievalIndex: CandidateRetriever {
    public static let schemaVersion = "package018-candidate-index/1"
    public static let policyVersion = "package019-bm25-ordered6-domain-diverse/1"
    // The frozen natural suite separates ordinary low-evidence requests below
    // 16 from valid thin-context reports above 27; 26 is the documented
    // general confidence floor, paired with unique-term coverage below.
    private static let minimumConfidence = 26.0
    private let handle: CandidateRetrievalDatabaseHandle
    private let manifest: CandidateRetrievalManifest
    private var lastDecodedPayloadCount = 0

    private init(database: OpaquePointer, manifest: CandidateRetrievalManifest) { handle = .init(database); self.manifest = manifest }
    public static func openBundled(disabled: Bool = false) -> CandidateRetrievalOpenResult {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: CommunityCandidateIndexBundleLocator.self)
        #endif
        let manifestURL = bundle.url(forResource: "CandidateRetrieval.manifest", withExtension: "json")
        let databaseURL = manifestURL.flatMap { url -> URL? in
            guard let data = try? Data(contentsOf: url), let manifest = try? JSONDecoder().decode(CandidateRetrievalManifest.self, from: data) else { return nil }
            return bundle.url(forResource: manifest.database, withExtension: nil)
        }
        return open(indexURL: databaseURL, manifestURL: manifestURL, disabled: disabled)
    }

    /// Injectable only for deterministic failure-state tests. It returns no
    /// filesystem path or error detail to callers; production uses openBundled.
    public static func open(indexURL: URL?, manifestURL: URL?, disabled: Bool = false) -> CandidateRetrievalOpenResult {
        guard !disabled else { return .init(availability: .disabled, retriever: nil) }
        guard let manifestURL else { return .init(availability: .unavailable, retriever: nil) }
        guard let data = try? Data(contentsOf: manifestURL), let manifest = try? JSONDecoder().decode(CandidateRetrievalManifest.self, from: data) else { return .init(availability: .corrupt, retriever: nil) }
        guard manifest.schema_version == schemaVersion else { return .init(availability: .schemaDrift, retriever: nil) }
        guard manifest.retrieval_policy_version == policyVersion, manifest.corpus_version == "p16-runtime-projection-6212", manifest.card_count == 6_212, manifest.package_017_runtime_count == 0 else { return .init(availability: .versionMismatch, retriever: nil) }
        guard let indexURL, let index = try? Data(contentsOf: indexURL, options: [.mappedIfSafe]), index.count == manifest.database_bytes, SHA256.hash(data: index.prefix(4096)).hexString == manifest.database_header_sha256 else { return .init(availability: .corrupt, retriever: nil) }
        var connection: OpaquePointer?
        guard sqlite3_open_v2(indexURL.absoluteString + "?mode=ro&immutable=1", &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK, let connection else { return .init(availability: .corrupt, retriever: nil) }
        sqlite3_busy_timeout(connection, 100)
        return .init(availability: .ready, retriever: .init(database: connection, manifest: manifest))
    }
    public func availability() -> CandidateRetrievalAvailability { .ready }
    public func lastQueryDecodedPayloadCount() -> Int { lastDecodedPayloadCount }

    public func ranked(query: String, filters: CommunityCandidateCorpusFilters = .init(), limit: Int = 4) -> [CommunityCandidateCorpusRankedCard] {
        rankedOutcome(query: query, filters: filters, limit: limit).cards
    }

    public func rankedOutcome(query: String, filters: CommunityCandidateCorpusFilters = .init(), limit: Int = 4) -> CandidateRetrievalOutcome {
        lastDecodedPayloadCount = 0
        let terms = Self.terms(query); guard terms.count >= 2, limit > 0 else { return .init(kind: .noMatch) }
        guard let conjunction = fetchPool(terms: terms, filters: filters, conjunction: true) else { return .init(kind: .queryFailed) }
        // An AND pool with only one or two topical families is too narrow for
        // a terse report. Bounded OR is a general fallback, not an alias map.
        let candidates: [CandidateRankMetadata]
        if conjunction.count >= 2 && Set(conjunction.map(\.domain)).count >= 3 {
            candidates = conjunction
        } else if let fallback = fetchPool(terms: terms, filters: filters, conjunction: false) {
            candidates = fallback
        } else {
            return .init(kind: .queryFailed)
        }
        let minimumOverlap = 2
        let ordered = candidates.filter { Self.overlap($0, terms) >= minimumOverlap }.sorted { Self.score($0, terms) == Self.score($1, terms) ? $0.id < $1.id : Self.score($0, terms) > Self.score($1, terms) }
        guard let best = ordered.first, Self.score(best, terms) >= Self.minimumConfidence else { return .init(kind: .noMatch) }
        let bestScore = Self.score(best, terms)
        let nextScore = ordered.dropFirst().first.map { Self.score($0, terms) } ?? 0
        let margin = bestScore - nextScore
        let ambiguity = margin < max(4, bestScore * 0.12)
        var seenQuestions = Set<String>(), seenDomains = Set<String>(), packageCounts: [String: Int] = [:], selected: [CandidateRankMetadata] = []
        for item in ordered where seenQuestions.insert(item.questionKey).inserted {
            guard seenDomains.insert(item.domain).inserted, packageCounts[item.packageID, default: 0] < 2 else { continue }
            packageCounts[item.packageID, default: 0] += 1; selected.append(item)
            if selected.count == limit { break }
        }
        guard let details = loadDetails(ids: selected.map(\.id)) else { return .init(kind: .queryFailed) }
        let results: [CommunityCandidateCorpusRankedCard] = selected.compactMap { item in
            guard let card = details[item.id] else { return nil }
            let score = Self.score(item, terms)
            return .init(card: card, score: Int((score * 100).rounded()), deduplicatedCandidates: ordered.filter { $0.questionKey == item.questionKey }.count, lexicalOverlap: Self.overlap(item, terms), lexicalCoverage: Double(Self.overlap(item, terms)) / Double(terms.count), scoreMargin: item.id == best.id ? margin : 0, ambiguity: item.id == best.id && ambiguity)
        }
        // A chosen ID without a decodable payload is not an abstention.  It is
        // a bounded, sanitized integrity failure that must remain visible to
        // deterministic evaluation and the model-facing tool result.
        guard results.count == selected.count else { return .init(kind: .malformedSelectedPayload) }
        return .init(kind: results.isEmpty ? .noMatch : .matches, cards: results)
    }

    private func fetchPool(terms: [String], filters: CommunityCandidateCorpusFilters, conjunction: Bool) -> [CandidateRankMetadata]? {
        let expression = terms.map { "\"\($0)\"*" }.joined(separator: conjunction ? " AND " : " OR ")
        var clauses = ["cards_fts MATCH ?"], bindings = [expression]
        if let value = filters.domain { clauses.append("c.domain = ?"); bindings.append(value) }
        if let value = filters.category { clauses.append("c.category = ?"); bindings.append(value) }
        if let value = filters.evidenceClass { clauses.append("c.evidence_class = ?"); bindings.append(value) }
        if let value = filters.logicVersion { clauses.append("c.logic_version LIKE ?"); bindings.append("%\(value)%") }
        if let value = filters.currentContext { clauses.append("c.current_context = ?"); bindings.append(value ? "1" : "0") }
        if let value = filters.packageID { clauses.append("c.package_id = ?"); bindings.append(value) }
        if let value = filters.packageVersion { clauses.append("c.version = ?"); bindings.append(value) }
        if let value = filters.sourceType { clauses.append("c.source_types LIKE ?"); bindings.append("%\"\(value)\"%") }
        if let value = filters.role { clauses.append("c.role_facets LIKE ?"); bindings.append("%\"\(value)\"%") }
        if let value = filters.section { clauses.append("c.section_facets LIKE ?"); bindings.append("%\"\(value)\"%") }
        let sql = "SELECT c.id,c.package_id,c.question_key,c.domain,c.category,c.source_types,c.evidence_class,c.current_context,c.role_facets,c.section_facets,c.primary_terms,c.facet_terms,c.context_terms,bm25(cards_fts,5.0,2.0,0.5) FROM cards_fts JOIN cards c ON c.rowid=cards_fts.rowid WHERE \(clauses.joined(separator: " AND ")) ORDER BY bm25(cards_fts,5.0,2.0,0.5) LIMIT 256"
        var statement: OpaquePointer?; guard sqlite3_prepare_v2(handle.pointer, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return nil }; defer { sqlite3_finalize(statement) }
        for (index, value) in bindings.enumerated() { sqlite3_bind_text(statement, Int32(index + 1), value, -1, sqliteTransient) }
        var output: [CandidateRankMetadata] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW {
            guard let id = sqliteString(statement, 0), let packageID = sqliteString(statement, 1), let questionKey = sqliteString(statement, 2), let domain = sqliteString(statement, 3), let category = sqliteString(statement, 4), let source = sqliteString(statement, 5), let evidence = sqliteString(statement, 6), let roles = sqliteString(statement, 8), let sections = sqliteString(statement, 9), let primary = sqliteString(statement, 10), let facets = sqliteString(statement, 11), let context = sqliteString(statement, 12) else { step = sqlite3_step(statement); continue }
            func set(_ value: String) -> Set<String> { Set((try? JSONDecoder().decode([String].self, from: Data(value.utf8))) ?? []) }
            let sourceTypes = set(source), roleFacets = set(roles), sectionFacets = set(sections)
            let primaryTerms = Set(primary.split(separator: " ").map(String.init))
            let facetTerms = Set(facets.split(separator: " ").map(String.init))
            let contextTerms = Set(context.split(separator: " ").map(String.init))
            let currentContext = sqlite3_column_int(statement, 7) != 0
            let bm25 = sqlite3_column_double(statement, 13)
            output.append(.init(id: id, packageID: packageID, questionKey: questionKey, domain: domain, category: category, evidenceClass: evidence, sourceTypes: sourceTypes, roleFacets: roleFacets, sectionFacets: sectionFacets, primaryTerms: primaryTerms, facetTerms: facetTerms, contextTerms: contextTerms, currentContext: currentContext, bm25: bm25))
            step = sqlite3_step(statement)
        }
        return step == SQLITE_DONE ? output : nil
    }
    private func loadDetails(ids: [String]) -> [String: CommunityCandidateCard]? {
        var output: [String: CommunityCandidateCard] = [:]; var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, "SELECT payload_json FROM cards WHERE id = ?", -1, &statement, nil) == SQLITE_OK, let statement else { return nil }; defer { sqlite3_finalize(statement) }
        for id in ids {
            sqlite3_reset(statement); sqlite3_clear_bindings(statement); sqlite3_bind_text(statement, 1, id, -1, sqliteTransient)
            let step = sqlite3_step(statement)
            if step != SQLITE_ROW {
                if step != SQLITE_DONE { return nil }
                continue
            }
            guard let payload = sqliteString(statement, 0), let card = try? JSONDecoder().decode(CommunityCandidateCard.self, from: Data(payload.utf8)) else { continue }
            lastDecodedPayloadCount += 1; output[id] = card
        }
        return output
    }
    private static func score(_ item: CandidateRankMetadata, _ query: [String]) -> Double {
        let uniqueQuery = Set(query)
        let primary = item.primaryTerms.intersection(uniqueQuery).count * 8
        let facets = item.facetTerms.intersection(uniqueQuery).count * 12
        let context = item.contextTerms.intersection(uniqueQuery).count * 2
        let bm25 = min(32, max(0, -item.bm25))
        return Double(primary + facets + context) + bm25
    }
    private static func overlap(_ item: CandidateRankMetadata, _ query: [String]) -> Int {
        item.primaryTerms.union(item.facetTerms).union(item.contextTerms).intersection(Set(query)).count
    }
    private static func terms(_ text: String) -> [String] {
        let words = text.lowercased().replacingOccurrences(of: "_", with: " ").split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var result: [String] = [], seen = Set<String>()
        for word in words {
            guard word.count > 1, !stopTerms.contains(word) else { continue }
            let stem: String
            if word.hasSuffix("ing"), word.count > 5 { stem = String(word.dropLast(3)) }
            else if word.hasSuffix("s"), word.count > 3 { stem = String(word.dropLast()) }
            else { stem = word }
            let skeleton = stem.filter { !"aeiou".contains($0) }
            let normalized = stem.count >= 5 && skeleton.count >= 3 ? skeleton : stem
            if seen.insert(normalized).inserted { result.append(normalized) }
            if result.count == 6 { break }
        }
        return result
    }
    // Broad host-navigation and vague-status words cannot identify a candidate
    // hypothesis by themselves; reviewed procedures/general teaching handle them.
    private static let stopTerms: Set<String> = ["a","an","and","are","best","but","cannot","control","detail","do","find","for","from","get","how","i","if","in","is","it","like","logic","make","mix","my","need","not","of","or","should","so","the","this","to","too","what","when","why","with","wrong"]
}
private func sqliteString(_ statement: OpaquePointer, _ column: Int32) -> String? { guard let raw = sqlite3_column_text(statement, column) else { return nil }; return String(validatingCString: UnsafeRawPointer(raw).assumingMemoryBound(to: CChar.self)) }
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
private final class CommunityCandidateIndexBundleLocator {}
private final class CandidateRetrievalDatabaseHandle: @unchecked Sendable { let pointer: OpaquePointer; init(_ pointer: OpaquePointer) { self.pointer = pointer }; deinit { sqlite3_close(pointer) } }
private extension SHA256.Digest { var hexString: String { map { String(format: "%02x", $0) }.joined() } }
