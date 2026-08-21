import CryptoKit
import Foundation
import SQLite3

public enum CandidateRetrievalAvailability: String, Codable, Equatable, Sendable { case ready, unavailable, corrupt, versionMismatch, disabled }
public protocol CandidateRetriever: Sendable { func availability() async -> CandidateRetrievalAvailability; func ranked(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) async -> [CommunityCandidateCorpusRankedCard] }
public struct CandidateRetrievalOpenResult: Sendable { public let availability: CandidateRetrievalAvailability; public let retriever: CandidateRetrievalIndex? }

private struct CandidateRetrievalManifest: Decodable { let schema_version, corpus_version, retrieval_policy_version: String; let card_count, package_017_runtime_count, database_bytes: Int; let database, database_header_sha256: String }
private struct CandidateRankMetadata { let id, packageID, questionKey, domain, category, evidenceClass: String; let sourceTypes, roleFacets, sectionFacets, primaryTerms, facetTerms, contextTerms: Set<String>; let currentContext: Bool; let bm25: Double }

/// Immutable actor-owned SQLite reader. FTS returns compact ranking fields;
/// payload JSON is fetched and decoded only for final bounded IDs.
public actor CandidateRetrievalIndex: CandidateRetriever {
    public static let schemaVersion = "package018-candidate-index/1"
    public static let policyVersion = "package018-bm25-general-rerank/1"
    // The frozen natural suite separates ordinary low-evidence requests below
    // 16 from valid thin-context reports above 27; 26 is the documented
    // general confidence floor, paired with unique-term coverage below.
    private static let minimumConfidence = 26.0
    // Long conversational queries include prior-experiment context. Require
    // two unique matches, then use 20% coverage so that useful context does
    // not erase a well-supported terse diagnosis; short low-evidence requests
    // still fail the same two-term floor.
    private static let minimumCoverage = 0.20
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
        guard manifest.schema_version == schemaVersion, manifest.retrieval_policy_version == policyVersion, manifest.corpus_version == "p16-runtime-projection-6212", manifest.card_count == 6_212, manifest.package_017_runtime_count == 0 else { return .init(availability: .versionMismatch, retriever: nil) }
        guard let indexURL, let index = try? Data(contentsOf: indexURL, options: [.mappedIfSafe]), index.count == manifest.database_bytes, SHA256.hash(data: index.prefix(4096)).hexString == manifest.database_header_sha256 else { return .init(availability: .corrupt, retriever: nil) }
        var connection: OpaquePointer?
        guard sqlite3_open_v2(indexURL.absoluteString + "?mode=ro&immutable=1", &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK, let connection else { return .init(availability: .corrupt, retriever: nil) }
        sqlite3_busy_timeout(connection, 100)
        return .init(availability: .ready, retriever: .init(database: connection, manifest: manifest))
    }
    public func availability() -> CandidateRetrievalAvailability { .ready }
    public func lastQueryDecodedPayloadCount() -> Int { lastDecodedPayloadCount }

    public func ranked(query: String, filters: CommunityCandidateCorpusFilters = .init(), limit: Int = 4) -> [CommunityCandidateCorpusRankedCard] {
        lastDecodedPayloadCount = 0
        let terms = Self.terms(query); guard terms.count >= 2, limit > 0 else { return [] }
        let conjunction = fetchPool(terms: terms, filters: filters, conjunction: true)
        // An AND pool with only one or two topical families is too narrow for
        // a terse report. Bounded OR is a general fallback, not an alias map.
        let candidates = conjunction.count >= 2 && Set(conjunction.map(\.domain)).count >= 3 ? conjunction : fetchPool(terms: terms, filters: filters, conjunction: false)
        let queryTerms = Set(terms), minimumOverlap = max(2, Int(ceil(Double(terms.count) * Self.minimumCoverage)))
        let ordered = candidates.filter { Self.overlap($0, queryTerms) >= minimumOverlap }.sorted { Self.score($0, queryTerms) == Self.score($1, queryTerms) ? $0.id < $1.id : Self.score($0, queryTerms) > Self.score($1, queryTerms) }
        guard let best = ordered.first, Self.score(best, queryTerms) >= Self.minimumConfidence else { return [] }
        let bestScore = Self.score(best, queryTerms)
        let nextScore = ordered.dropFirst().first.map { Self.score($0, queryTerms) } ?? 0
        let margin = bestScore - nextScore
        let ambiguity = margin < max(4, bestScore * 0.12)
        var seenQuestions = Set<String>(), domainCounts: [String: Int] = [:], packageCounts: [String: Int] = [:], selected: [CandidateRankMetadata] = []
        for item in ordered where seenQuestions.insert(item.questionKey).inserted {
            guard domainCounts[item.domain, default: 0] < 2, packageCounts[item.packageID, default: 0] < 2 else { continue }
            domainCounts[item.domain, default: 0] += 1; packageCounts[item.packageID, default: 0] += 1; selected.append(item)
            if selected.count == limit { break }
        }
        let details = loadDetails(ids: selected.map(\.id))
        return selected.compactMap { item in
            guard let card = details[item.id] else { return nil }
            let score = Self.score(item, queryTerms)
            return .init(card: card, score: Int((score * 100).rounded()), deduplicatedCandidates: ordered.filter { $0.questionKey == item.questionKey }.count, lexicalOverlap: Self.overlap(item, queryTerms), lexicalCoverage: Double(Self.overlap(item, queryTerms)) / Double(queryTerms.count), scoreMargin: item.id == best.id ? margin : 0, ambiguity: item.id == best.id && ambiguity)
        }
    }

    private func fetchPool(terms: [String], filters: CommunityCandidateCorpusFilters, conjunction: Bool) -> [CandidateRankMetadata] {
        let expression = terms.prefix(12).map { "\"\($0)\"*" }.joined(separator: conjunction ? " AND " : " OR ")
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
        var statement: OpaquePointer?; guard sqlite3_prepare_v2(handle.pointer, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return [] }; defer { sqlite3_finalize(statement) }
        for (index, value) in bindings.enumerated() { sqlite3_bind_text(statement, Int32(index + 1), value, -1, sqliteTransient) }
        var output: [CandidateRankMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = sqliteString(statement, 0), let packageID = sqliteString(statement, 1), let questionKey = sqliteString(statement, 2), let domain = sqliteString(statement, 3), let category = sqliteString(statement, 4), let source = sqliteString(statement, 5), let evidence = sqliteString(statement, 6), let roles = sqliteString(statement, 8), let sections = sqliteString(statement, 9), let primary = sqliteString(statement, 10), let facets = sqliteString(statement, 11), let context = sqliteString(statement, 12) else { continue }
            func set(_ value: String) -> Set<String> { Set((try? JSONDecoder().decode([String].self, from: Data(value.utf8))) ?? []) }
            let sourceTypes = set(source), roleFacets = set(roles), sectionFacets = set(sections)
            let primaryTerms = Set(primary.split(separator: " ").map(String.init))
            let facetTerms = Set(facets.split(separator: " ").map(String.init))
            let contextTerms = Set(context.split(separator: " ").map(String.init))
            let currentContext = sqlite3_column_int(statement, 7) != 0
            let bm25 = sqlite3_column_double(statement, 13)
            output.append(.init(id: id, packageID: packageID, questionKey: questionKey, domain: domain, category: category, evidenceClass: evidence, sourceTypes: sourceTypes, roleFacets: roleFacets, sectionFacets: sectionFacets, primaryTerms: primaryTerms, facetTerms: facetTerms, contextTerms: contextTerms, currentContext: currentContext, bm25: bm25))
        }
        return output
    }
    private func loadDetails(ids: [String]) -> [String: CommunityCandidateCard] {
        var output: [String: CommunityCandidateCard] = [:]; var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, "SELECT payload_json FROM cards WHERE id = ?", -1, &statement, nil) == SQLITE_OK, let statement else { return output }; defer { sqlite3_finalize(statement) }
        for id in ids { sqlite3_reset(statement); sqlite3_clear_bindings(statement); sqlite3_bind_text(statement, 1, id, -1, sqliteTransient); guard sqlite3_step(statement) == SQLITE_ROW, let payload = sqliteString(statement, 0), let card = try? JSONDecoder().decode(CommunityCandidateCard.self, from: Data(payload.utf8)) else { continue }; lastDecodedPayloadCount += 1; output[id] = card }
        return output
    }
    private static func score(_ item: CandidateRankMetadata, _ query: Set<String>) -> Double {
        let primary = item.primaryTerms.intersection(query).count * 8
        let facets = item.facetTerms.intersection(query).count * 12
        let context = item.contextTerms.intersection(query).count * 2
        let bm25 = min(32, max(0, -item.bm25))
        return Double(primary + facets + context) + bm25
    }
    private static func overlap(_ item: CandidateRankMetadata, _ query: Set<String>) -> Int {
        item.primaryTerms.union(item.facetTerms).union(item.contextTerms).intersection(query).count
    }
    private static func terms(_ text: String) -> [String] {
        let words = text.lowercased().replacingOccurrences(of: "_", with: " ").split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return Set(words.compactMap { word -> String? in
            guard word.count > 1, !stopTerms.contains(word) else { return nil }
            let stem: String
            if word.hasSuffix("ing"), word.count > 5 { stem = String(word.dropLast(3)) }
            else if word.hasSuffix("s"), word.count > 3 { stem = String(word.dropLast()) }
            else { stem = word }
            let skeleton = stem.filter { !"aeiou".contains($0) }
            return stem.count >= 5 && skeleton.count >= 3 ? skeleton : stem
        }).sorted()
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
