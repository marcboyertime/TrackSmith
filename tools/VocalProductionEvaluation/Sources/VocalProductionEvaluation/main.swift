import AudioAnalysis
import CryptoKit
import DSPCore
import Foundation
import PlanSchema
import VocalProduction

// TrackSmith Vocal v1 semantic/adversarial evaluator.
//
// The fixture audio below is synthesized in memory by TrackSmith. It is only
// suitable for deterministic execution/safety checks. It is deliberately not
// used as evidence that a candidate sounds good, resembles an acoustic source,
// or preserves perceptual qualities; those remain listening-only judgments.

private let maximumInputBytes = 4 * 1_024 * 1_024
private let maximumReportBytes = 2 * 1_024 * 1_024
private let fixedDate = Date(timeIntervalSince1970: 1_786_147_200)

private struct CLIArguments {
    let corpusURL: URL
    let failureMapURL: URL
    let outputURL: URL
    let sourceRevision: String
    let sourceTreeState: String
    let toolchain: String

    static func parse(_ arguments: [String]) throws -> CLIArguments {
        if arguments == ["--help"] || arguments == ["-h"] {
            print("Usage: VocalProductionEvaluation --corpus PATH --failure-map PATH --output PATH --source-revision GIT_SHA --source-tree-state clean|dirty --toolchain DESCRIPTION")
            Foundation.exit(0)
        }
        let allowed = Set([
            "--corpus", "--failure-map", "--output", "--source-revision",
            "--source-tree-state", "--toolchain",
        ])
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard allowed.contains(key) else { throw HarnessError.configuration("Unknown argument: \(key)") }
            guard values[key] == nil else { throw HarnessError.configuration("Duplicate argument: \(key)") }
            guard arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("--") else {
                throw HarnessError.configuration("Missing value for \(key)")
            }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard let corpus = values["--corpus"],
              let failureMap = values["--failure-map"],
              let output = values["--output"],
              let sourceRevision = values["--source-revision"],
              let sourceTreeState = values["--source-tree-state"],
              let toolchain = values["--toolchain"] else {
            throw HarnessError.configuration("Every documented argument is required")
        }
        let revisionBytes = sourceRevision.utf8
        guard (revisionBytes.count == 40 || revisionBytes.count == 64),
              revisionBytes.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw HarnessError.configuration("--source-revision must be a lowercase 40- or 64-character Git object ID")
        }
        guard sourceTreeState == "clean" || sourceTreeState == "dirty" else {
            throw HarnessError.configuration("--source-tree-state must be clean or dirty")
        }
        let normalizedToolchain = toolchain
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !normalizedToolchain.isEmpty, normalizedToolchain.utf8.count <= 512 else {
            throw HarnessError.configuration("--toolchain must be a nonempty bounded description")
        }
        let corpusURL = URL(fileURLWithPath: corpus).standardizedFileURL
        let failureMapURL = URL(fileURLWithPath: failureMap).standardizedFileURL
        let outputURL = URL(fileURLWithPath: output).standardizedFileURL
        guard outputURL != corpusURL, outputURL != failureMapURL else {
            throw HarnessError.configuration("Output must not overwrite an input")
        }
        return CLIArguments(
            corpusURL: corpusURL,
            failureMapURL: failureMapURL,
            outputURL: outputURL,
            sourceRevision: sourceRevision,
            sourceTreeState: sourceTreeState,
            toolchain: normalizedToolchain
        )
    }
}

private enum HarnessError: Error, CustomStringConvertible {
    case configuration(String)
    case schema(String)
    case assertion(String)

    var description: String {
        switch self {
        case let .configuration(message): "Configuration error: \(message)"
        case let .schema(message): "Schema error: \(message)"
        case let .assertion(message): "Assertion failed: \(message)"
        }
    }
}

private struct Corpus: Decodable {
    let schemaVersion: String
    let corpusID: String
    let statusDate: String
    let caseCountRationale: String
    let claimBoundary: [String]
    let cases: [CorpusCase]
}

private struct CorpusCase: Decodable {
    let id: String
    let failureMapIDs: [String]
    let kind: String
    let prompt: String?
    let scope: ScopeSpec?
    let sourceType: String?
    let assetAcceptance: String?
    let captureProfile: String?
    let audioFixture: String?
    let sourceClass: String?
    let feedbackProfile: String?
    let revision: RevisionSpec?
    let mutation: String?
    let expected: Expected
}

private struct ScopeSpec: Decodable {
    let kind: String
    let startSeconds: Double?
    let endSeconds: Double?
    let sectionID: String?
    let sectionName: String?
}

private struct RevisionSpec: Decodable {
    let baseCaseID: String
    let baseCandidateIndex: Int
    let prose: String
    let lastPhraseScope: ScopeSpec?
    let prelockedAspects: [String]?
    let lockScopePolicy: String?
    let staleCandidateIndex: Int?
    let omitApplicationIDs: Bool?
    let explicitRevertCandidateIndex: Int?
}

private struct Expected: Decodable {
    let outcome: String
    let candidateCount: Int?
    let archetype: String?
    let aspects: [String]?
    let preserved: [String]?
    let prohibited: [String]?
    let boundaries: [String]?
    let boundaryDisposition: String?
    let scopeKind: String?
    let realtimeActivatable: Bool?
    let structurallyDistinct: Bool?
    let deterministicReplay: Bool?
    let sourceUnchanged: Bool?
    let offlineFinite: Bool?
    let usesNetwork: Bool?
    let localOffline: Bool?
    let renderHashStable: Bool?
    let outsideScopePreservedExactly: Bool?
    let ambiguityCount: Int?
    let minimumAmbiguityCount: Int?
    let minimumUncertaintyCount: Int?
    let errorContains: String?
    let findingKinds: [String]?
    let immediateStop: Bool?
    let activeShareMaximum: Double?
    let sourceClass: String?
    let gainDirection: String?
    let placementAngle: String?
    let roomPosition: String?
    let placementMatchesParent: Bool?
    let confirmedPreference: Bool?
    let roomStrategies: [String]?
    let forbidsPurchaseLanguage: Bool?
    let requiresUnknownHardwareBoundary: Bool?
    let operations: [String]?
    let changedScopeOnly: Bool?
    let inheritedAspect: String?
    let inheritedCandidateIndex: Int?
    let locks: [String]?
    let revertedCandidateIndex: Int?
}

private struct FailureMap: Decodable {
    let schemaVersion: String
    let milestone: String
    let corpus: String
    let statusDate: String
    let selectionRationale: String
    let claimBoundary: String
    let risks: [FailureRisk]
}

private struct FailureRisk: Decodable {
    let id: String
    let area: String
    let failure: String
    let requiredAssertion: String
    let caseIDs: [String]
}

private struct AssertionRecord: Codable {
    let name: String
    let passed: Bool
    let detail: String
}

private struct CaseResult: Codable {
    let id: String
    let kind: String
    let failureMapIDs: [String]
    let passed: Bool
    let assertions: [AssertionRecord]
    let failure: String?
}

private struct FixtureDeclaration: Codable {
    let ownership: String
    let generatedInMemory: Bool
    let networkUsed: Bool
    let userAudioUsed: Bool
    let claimBoundary: String
}

private struct EvaluationReport: Codable {
    let schemaVersion: String
    let corpusID: String
    let corpusSHA256: String
    let failureMapSHA256: String
    let statusDate: String
    let execution: EvaluationExecutionRecord
    let passed: Int
    let failed: Int
    let total: Int
    let claimBoundary: [String]
    let fixture: FixtureDeclaration
    let cases: [CaseResult]
}

private struct EvaluationExecutionRecord: Codable {
    let sourceRevision: String
    let sourceTreeState: String
    let executableSHA256: String
    let toolchain: String
    let operatingSystem: String
    let architecture: String
    let command: [String]
    let claimBoundary: String
}

private struct Recorder {
    private(set) var records: [AssertionRecord] = []

    mutating func expect(_ condition: @autoclosure () -> Bool, _ name: String, _ detail: @autoclosure () -> String) throws {
        let passed = condition()
        let failureDetail = detail()
        records.append(AssertionRecord(
            name: name,
            passed: passed,
            detail: passed ? "Assertion satisfied." : failureDetail
        ))
        if !passed { throw HarnessError.assertion("\(name): \(records.last?.detail ?? "")") }
    }

    mutating func note(_ name: String, _ detail: String) {
        records.append(AssertionRecord(name: name, passed: true, detail: detail))
    }
}

private struct StrictJSON {
    static let corpusRoot = Set(["schemaVersion", "corpusID", "statusDate", "caseCountRationale", "claimBoundary", "cases"])
    static let corpusCase = Set(["id", "failureMapIDs", "kind", "prompt", "scope", "sourceType", "assetAcceptance", "captureProfile", "audioFixture", "sourceClass", "feedbackProfile", "revision", "mutation", "expected"])
    static let scope = Set(["kind", "startSeconds", "endSeconds", "sectionID", "sectionName"])
    static let revision = Set(["baseCaseID", "baseCandidateIndex", "prose", "lastPhraseScope", "prelockedAspects", "lockScopePolicy", "staleCandidateIndex", "omitApplicationIDs", "explicitRevertCandidateIndex"])
    static let expected = Set([
        "outcome", "candidateCount", "archetype", "aspects", "preserved", "prohibited", "boundaries",
        "boundaryDisposition", "scopeKind", "realtimeActivatable", "structurallyDistinct", "deterministicReplay",
        "sourceUnchanged", "offlineFinite", "usesNetwork", "localOffline", "renderHashStable",
        "outsideScopePreservedExactly", "ambiguityCount", "minimumAmbiguityCount", "minimumUncertaintyCount",
        "errorContains", "findingKinds", "immediateStop", "activeShareMaximum", "sourceClass", "gainDirection",
        "placementAngle", "roomPosition", "placementMatchesParent", "confirmedPreference", "roomStrategies",
        "forbidsPurchaseLanguage", "requiresUnknownHardwareBoundary", "operations", "changedScopeOnly",
        "inheritedAspect", "inheritedCandidateIndex", "locks", "revertedCandidateIndex",
    ])
    static let failureRoot = Set(["schemaVersion", "milestone", "corpus", "statusDate", "selectionRationale", "claimBoundary", "risks"])
    static let risk = Set(["id", "area", "failure", "requiredAssertion", "caseIDs"])

    static func validateCorpus(_ data: Data) throws {
        let root = try object(data, label: "corpus")
        try exactKeys(root, allowed: corpusRoot, path: "$corpus")
        guard let cases = root["cases"] as? [[String: Any]] else { throw HarnessError.schema("$corpus.cases must be an array of objects") }
        for (index, item) in cases.enumerated() {
            try exactKeys(item, allowed: corpusCase, path: "$corpus.cases[\(index)]")
            if let nested = item["scope"] as? [String: Any] { try exactKeys(nested, allowed: scope, path: "$corpus.cases[\(index)].scope") }
            if let nested = item["revision"] as? [String: Any] {
                try exactKeys(nested, allowed: revision, path: "$corpus.cases[\(index)].revision")
                if let last = nested["lastPhraseScope"] as? [String: Any] { try exactKeys(last, allowed: scope, path: "$corpus.cases[\(index)].revision.lastPhraseScope") }
            }
            guard let expectedObject = item["expected"] as? [String: Any] else { throw HarnessError.schema("$corpus.cases[\(index)].expected must be an object") }
            try exactKeys(expectedObject, allowed: expected, path: "$corpus.cases[\(index)].expected")
        }
    }

    static func validateFailureMap(_ data: Data) throws {
        let root = try object(data, label: "failure map")
        try exactKeys(root, allowed: failureRoot, path: "$failureMap")
        guard let risks = root["risks"] as? [[String: Any]] else { throw HarnessError.schema("$failureMap.risks must be an array of objects") }
        for (index, riskObject) in risks.enumerated() {
            try exactKeys(riskObject, allowed: risk, path: "$failureMap.risks[\(index)]")
        }
    }

    private static func object(_ data: Data, label: String) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let root = value as? [String: Any] else { throw HarnessError.schema("\(label) root must be an object") }
        return root
    }

    private static func exactKeys(_ object: [String: Any], allowed: Set<String>, path: String) throws {
        let unknown = Set(object.keys).subtracting(allowed).sorted()
        guard unknown.isEmpty else { throw HarnessError.schema("\(path) has unknown keys: \(unknown.joined(separator: ", "))") }
    }
}

private func loadBounded(_ url: URL) throws -> Data {
    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard values.isRegularFile == true else { throw HarnessError.configuration("Input is not a regular file: \(url.path)") }
    guard let size = values.fileSize, size > 0, size <= maximumInputBytes else {
        throw HarnessError.configuration("Input exceeds the 1...\(maximumInputBytes) byte bound: \(url.path)")
    }
    return try Data(contentsOf: url, options: [.mappedIfSafe])
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func executableSHA256() throws -> String {
    let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        .standardizedFileURL
        .resolvingSymlinksInPath()
    let values = try executableURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard values.isRegularFile == true,
          let size = values.fileSize,
          size > 0,
          size <= 256 * 1_024 * 1_024 else {
        throw HarnessError.configuration("The evaluator executable is unavailable or exceeds its fixed hash bound")
    }
    return sha256(try Data(contentsOf: executableURL, options: [.mappedIfSafe]))
}

private func runtimeArchitecture() -> String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x86_64"
    #else
    return "unknown"
    #endif
}

private func stableUUID(_ label: String) -> UUID {
    let hex = SHA256.hash(data: Data(label.utf8)).map { String(format: "%02x", $0) }.joined()
    let value = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-5\(hex.dropFirst(13).prefix(3))-a\(hex.dropFirst(17).prefix(3))-\(hex.dropFirst(20).prefix(12))"
    return UUID(uuidString: value)!
}

private func requireUniqueNonempty(_ values: [String], label: String) throws {
    guard !values.isEmpty, values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
        throw HarnessError.schema("\(label) must contain nonempty strings")
    }
    guard Set(values).count == values.count else { throw HarnessError.schema("\(label) contains duplicates") }
}

private func validateCorpusAndMap(_ corpus: Corpus, _ failureMap: FailureMap) throws {
    guard corpus.schemaVersion == "1.0", failureMap.schemaVersion == "1.0" else { throw HarnessError.schema("Only schemaVersion 1.0 is supported") }
    guard (1...512).contains(corpus.cases.count) else { throw HarnessError.schema("Corpus case count must be inside 1...512") }
    guard (1...128).contains(failureMap.risks.count) else { throw HarnessError.schema("Failure-map risk count must be inside 1...128") }
    guard corpus.statusDate == failureMap.statusDate else { throw HarnessError.schema("Corpus and failure-map dates differ") }
    try requireUniqueNonempty(corpus.cases.map(\.id), label: "case IDs")
    try requireUniqueNonempty(failureMap.risks.map(\.id), label: "risk IDs")
    let casesByID = Dictionary(uniqueKeysWithValues: corpus.cases.map { ($0.id, $0) })
    let risksByID = Dictionary(uniqueKeysWithValues: failureMap.risks.map { ($0.id, $0) })
    let supportedKinds = Set(["capturePlan", "captureAssessment", "captureRevision", "creativePlan", "providerOffline", "clarification", "intentRefusal", "plannerRefusal", "revision", "revisionRefusal", "assetRender", "assetRenderRefusal", "contractRefusal"])
    for item in corpus.cases {
        guard item.id.utf8.count <= 128, supportedKinds.contains(item.kind) else { throw HarnessError.schema("Invalid ID or kind in \(item.id)") }
        try requireUniqueNonempty(item.failureMapIDs, label: "\(item.id).failureMapIDs")
        for riskID in item.failureMapIDs where risksByID[riskID] == nil { throw HarnessError.schema("\(item.id) references missing risk \(riskID)") }
    }
    for risk in failureMap.risks {
        try requireUniqueNonempty(risk.caseIDs, label: "\(risk.id).caseIDs")
        for caseID in risk.caseIDs where casesByID[caseID] == nil { throw HarnessError.schema("\(risk.id) references missing case \(caseID)") }
        let reverse = corpus.cases.filter { $0.failureMapIDs.contains(risk.id) }.map(\.id).sorted()
        guard reverse == risk.caseIDs.sorted() else { throw HarnessError.schema("\(risk.id) case list is not reciprocal with corpus tags") }
    }
}

private struct PlanBundle {
    let sourceSnapshotID: UUID
    let intent: VocalCreativeIntent
    let candidates: [VocalCreativeCandidate]
    let scope: VocalCreativeScope
}

private final class Evaluator {
    private let corpus: Corpus
    private let casesByID: [String: CorpusCase]
    private lazy var planningAnalysis = AudioAnalyzer().analyze(syntheticAudio("cleanVocalLike"))
    private var sourceAwareAnalysisCache: [String: SourceAwareAnalysisReport] = [:]

    init(corpus: Corpus) {
        self.corpus = corpus
        self.casesByID = Dictionary(uniqueKeysWithValues: corpus.cases.map { ($0.id, $0) })
    }

    func run() -> [CaseResult] {
        corpus.cases.sorted { $0.id < $1.id }.map(evaluate)
    }

    private func evaluate(_ item: CorpusCase) -> CaseResult {
        var recorder = Recorder()
        do {
            switch item.kind {
            case "capturePlan": try evaluateCapturePlan(item, recorder: &recorder)
            case "captureAssessment": try evaluateCaptureAssessment(item, recorder: &recorder)
            case "captureRevision": try evaluateCaptureRevision(item, recorder: &recorder)
            case "creativePlan", "providerOffline": try evaluateCreativePlan(item, recorder: &recorder)
            case "clarification": try evaluateClarification(item, recorder: &recorder)
            case "intentRefusal": try evaluateIntentRefusal(item, recorder: &recorder)
            case "plannerRefusal": try evaluatePlannerRefusal(item, recorder: &recorder)
            case "revision": try evaluateRevision(item, refusal: false, recorder: &recorder)
            case "revisionRefusal": try evaluateRevision(item, refusal: true, recorder: &recorder)
            case "assetRender": try evaluateAsset(item, refusal: false, recorder: &recorder)
            case "assetRenderRefusal": try evaluateAsset(item, refusal: true, recorder: &recorder)
            case "contractRefusal": try evaluateContractRefusal(item, recorder: &recorder)
            default: throw HarnessError.schema("Unsupported case kind \(item.kind)")
            }
            return CaseResult(id: item.id, kind: item.kind, failureMapIDs: item.failureMapIDs.sorted(), passed: true, assertions: recorder.records, failure: nil)
        } catch {
            return CaseResult(id: item.id, kind: item.kind, failureMapIDs: item.failureMapIDs.sorted(), passed: false, assertions: recorder.records, failure: String(describing: error))
        }
    }

    private func scope(_ spec: ScopeSpec?, label: String) throws -> VocalCreativeScope {
        let spec = spec ?? ScopeSpec(kind: "fullSource", startSeconds: nil, endSeconds: nil, sectionID: nil, sectionName: nil)
        let id = stableUUID("\(label):scope")
        switch spec.kind {
        case "fullSource": return .fullSource(id: id)
        case "seconds":
            guard let start = spec.startSeconds, let end = spec.endSeconds else { throw HarnessError.schema("\(label) seconds scope is incomplete") }
            return .seconds(id: id, start: start, end: end)
        case "namedSection":
            guard let start = spec.startSeconds, let end = spec.endSeconds,
                  let sectionID = spec.sectionID, let sectionName = spec.sectionName else {
                throw HarnessError.schema("\(label) named-section scope is incomplete")
            }
            return .namedSection(id: id, sectionID: sectionID, name: sectionName, seconds: .init(start: start, end: end))
        default: throw HarnessError.schema("Unknown scope kind \(spec.kind)")
        }
    }

    private func assetAcceptance(_ raw: String?) throws -> VocalAssetAcceptance {
        guard let raw else { return .editableDSPOnly }
        guard let value = VocalAssetAcceptance(rawValue: raw) else { throw HarnessError.schema("Unknown asset acceptance \(raw)") }
        return value
    }

    private func sourceType(_ raw: String?) throws -> SourceType {
        guard let raw else { return .vocal }
        guard let value = SourceType(rawValue: raw) else { throw HarnessError.schema("Unknown source type \(raw)") }
        return value
    }

    private func makePlanBundle(
        _ item: CorpusCase,
        identityLabel: String? = nil,
        promptOverride: String? = nil,
        scopeOverride: VocalCreativeScope? = nil,
        sourceTypeOverride: SourceType? = nil,
        assetAcceptanceOverride: VocalAssetAcceptance? = nil,
        exactReferences: [VocalExactReference] = [],
        aspectLocks: [VocalAspectLock] = []
    ) throws -> PlanBundle {
        let label = identityLabel ?? item.id
        let sourceID = stableUUID("\(label):source")
        let typedScope = try scopeOverride ?? scope(item.scope, label: label)
        let acceptance = try assetAcceptanceOverride ?? assetAcceptance(item.assetAcceptance)
        let intent = try VocalIntentInterpreter().interpret(
            prompt: promptOverride ?? item.prompt ?? "",
            intentID: stableUUID("\(label):intent"),
            sourceSnapshotID: sourceID,
            scope: typedScope,
            assetAcceptance: acceptance,
            exactReferences: exactReferences,
            aspectLocks: aspectLocks
        )
        let requestedSourceType = try sourceTypeOverride ?? sourceType(item.sourceType)
        let processingScope = typedScope.processingScope(channelFormat: .mono, sourceType: requestedSourceType)
        let analysis = planningAnalysis
        let planner = VocalCreativePlanner()
        let preliminary = try planner.plan(
            intent: intent,
            processingScope: processingScope,
            analysis: analysis,
            deterministicIDs: .init(),
            createdAt: fixedDate
        )
        let IDs = VocalDeterministicIDs(
            candidateIDs: (0..<preliminary.count).map { stableUUID("\(label):candidate:\($0)") },
            planRequestIDs: (0..<preliminary.count).map { stableUUID("\(label):request:\($0)") },
            nodeIDsByCandidate: preliminary.enumerated().map { candidateIndex, candidate in
                candidate.plan.nodes.indices.map { stableUUID("\(label):node:\(candidateIndex):\($0)") }
            },
            lockIDs: []
        )
        let first = try planner.plan(intent: intent, processingScope: processingScope, analysis: analysis, deterministicIDs: IDs, createdAt: fixedDate)
        let second = try planner.plan(intent: intent, processingScope: processingScope, analysis: analysis, deterministicIDs: IDs, createdAt: fixedDate)
        guard first == second else { throw HarnessError.assertion("Planner replay differs for \(item.id)") }
        return PlanBundle(sourceSnapshotID: sourceID, intent: intent, candidates: first, scope: typedScope)
    }

    private func syntheticAudio(_ fixture: String?) -> AudioBuffer {
        let sampleRate = 48_000.0
        let frameCount = Int(sampleRate * 2.4)
        let key = fixture ?? "cleanVocalLike"
        var samples = [Float](repeating: 0, count: frameCount)
        guard key != "silence" else { return AudioBuffer(channels: [samples], sampleRate: sampleRate) }
        for frame in samples.indices {
            let time = Double(frame) / sampleRate
            let phraseOn: Bool
            if key == "phrasesWithSilence" {
                phraseOn = (0.14...0.50).contains(time) || (1.05...1.35).contains(time) || (1.90...2.15).contains(time)
            } else {
                phraseOn = true
            }
            guard phraseOn else { continue }
            let phrasePhase = time.truncatingRemainder(dividingBy: 0.48) / 0.48
            let edge = min(1, min(phrasePhase / 0.08, (1 - phrasePhase) / 0.08))
            let syllable = 0.62 + 0.38 * sin(2 * .pi * 3.2 * time) * sin(2 * .pi * 3.2 * time)
            let f0 = 178 + 9 * sin(2 * .pi * 0.55 * time)
            let harmonic = sin(2 * .pi * f0 * time)
                + 0.42 * sin(2 * .pi * f0 * 2 * time + 0.2)
                + 0.20 * sin(2 * .pi * f0 * 3 * time + 0.45)
            var value = 0.19 * max(0, edge) * syllable * harmonic
            if key == "veryLowVocalLike" { value *= 0.008 }
            if key == "clippedVocalLike" { value = min(1.08, max(-1.08, value * 9.5)) }
            samples[frame] = Float(value)
        }
        if key == "clippedVocalLike" {
            for frame in stride(from: 4_000, to: frameCount, by: 9_000) { samples[frame] = frame.isMultiple(of: 2) ? 1 : -1 }
        }
        return AudioBuffer(channels: [samples], sampleRate: sampleRate)
    }

    private func allFinite(_ buffer: AudioBuffer) -> Bool {
        buffer.sampleRate.isFinite && buffer.channels.allSatisfy { $0.allSatisfy(\.isFinite) }
    }

    private func checkSourceUnchanged(_ before: AudioBuffer, _ after: AudioBuffer) -> Bool {
        guard before.sampleRate == after.sampleRate, before.channelCount == after.channelCount, before.frameCount == after.frameCount else { return false }
        return zip(before.channels, after.channels).allSatisfy { original, current in
            zip(original, current).allSatisfy { $0.bitPattern == $1.bitPattern }
        }
    }

    private func evaluateCreativePlan(_ item: CorpusCase, recorder: inout Recorder) throws {
        let bundle = try makePlanBundle(item)
        let candidates = bundle.candidates
        let expected = item.expected
        try recorder.expect(expected.outcome == "actionable", "outcome", "creative and provider-offline cases must be actionable")
        if let count = expected.candidateCount { try recorder.expect(candidates.count == count, "candidate-count", "expected \(count), got \(candidates.count)") }
        try recorder.expect(Set(candidates.map(\.id)).count == candidates.count, "candidate-identities", "candidate IDs must be unique")
        try recorder.expect(Set(candidates.map { $0.plan.requestID }).count == candidates.count, "request-identities", "plan request IDs must be unique")
        try recorder.expect(candidates.map(\.interpretationIndex) == Array(1...candidates.count), "interpretation-order", "candidate indexes must be stable 1...N")
        if let archetype = expected.archetype { try recorder.expect(bundle.intent.archetype.rawValue == archetype, "archetype", "expected \(archetype), got \(bundle.intent.archetype.rawValue)") }
        let desired = Set(bundle.intent.desiredChanges.map { $0.aspect.rawValue })
        for aspect in expected.aspects ?? [] { try recorder.expect(desired.contains(aspect), "desired-aspect-\(aspect)", "typed intent does not include \(aspect)") }
        let preserved = Set(bundle.intent.preservation.preserved.map(\.rawValue))
        for aspect in expected.preserved ?? [] { try recorder.expect(preserved.contains(aspect), "preserved-\(aspect)", "preservation contract does not include \(aspect)") }
        let prohibited = Set(bundle.intent.preservation.prohibitedChanges.map(\.rawValue))
        for aspect in expected.prohibited ?? [] { try recorder.expect(prohibited.contains(aspect), "prohibited-\(aspect)", "prohibition contract does not include \(aspect)") }
        if let minimum = expected.minimumAmbiguityCount { try recorder.expect(bundle.intent.ambiguities.count >= minimum, "minimum-ambiguity", "expected at least \(minimum), got \(bundle.intent.ambiguities.count)") }
        if let minimum = expected.minimumUncertaintyCount { try recorder.expect(bundle.intent.uncertainties.count >= minimum, "minimum-uncertainty", "expected at least \(minimum), got \(bundle.intent.uncertainties.count)") }
        if let kind = expected.scopeKind { try recorder.expect(bundle.scope.kind.rawValue == kind, "scope-kind", "expected \(kind), got \(bundle.scope.kind.rawValue)") }
        if let boundaries = expected.boundaries { try recorder.expect(candidates.map { $0.boundary.rawValue } == boundaries, "boundaries", "expected \(boundaries), got \(candidates.map { $0.boundary.rawValue })") }
        if let realtime = expected.realtimeActivatable { try recorder.expect(candidates.allSatisfy { $0.realtimeActivatable == realtime }, "realtime-authority", "candidate realtime authority differs from expected \(realtime)") }
        if expected.structurallyDistinct == true {
            let structures = candidates.map { $0.plan.nodes.map { $0.type.rawValue }.joined(separator: ">") }
            try recorder.expect(Set(structures).count == candidates.count, "structural-distinction", "all three candidates need different node-type topology")
        }
        for candidate in candidates {
            try VocalContractValidator().validate(candidate: candidate)
            try recorder.expect(candidate.intent.sourceSnapshotID == bundle.sourceSnapshotID && candidate.plan.sourceSnapshotID == bundle.sourceSnapshotID, "source-authority-\(candidate.interpretationIndex)", "intent and plan must preserve exact source snapshot")
            try recorder.expect(candidate.plan.outputConstraints.loudnessMatchPreview, "loudness-match-\(candidate.interpretationIndex)", "preview must be loudness matched")
            try recorder.expect(candidate.plan.outputConstraints.maxTruePeakDB == -1, "peak-bound-\(candidate.interpretationIndex)", "expected -1 dB peak constraint")
            try recorder.expect(candidate.plan.nodes.count <= PlanValidator.maximumNodeCount, "node-bound-\(candidate.interpretationIndex)", "plan exceeds node bound")
            try recorder.expect(candidate.plan.nodes.allSatisfy { node in node.confidence.isFinite && node.parameters.values.allSatisfy(\.isFinite) }, "finite-plan-\(candidate.interpretationIndex)", "plan contains nonfinite values")
            try recorder.expect(candidate.limitations.contains { $0.localizedCaseInsensitiveContains("listening") || $0.localizedCaseInsensitiveContains("audition") }, "listening-boundary-\(candidate.interpretationIndex)", "candidate must state its listening boundary")
        }
        if bundle.intent.archetype == .underwater {
            try recorder.expect(candidates.allSatisfy { $0.plan.nodes.contains(where: { $0.type == .modulatedDelay }) }, "underwater-real-motion", "each underwater candidate must contain modulatedDelay")
        }
        if bundle.intent.archetype == .vocalToBrass {
            try recorder.expect(candidates.allSatisfy { $0.limitations.contains(where: { $0.localizedCaseInsensitiveContains("not") || $0.localizedCaseInsensitiveContains("metaphor") }) }, "brass-claim-boundary", "brass candidates must avoid reconstruction claims")
        }
        if expected.deterministicReplay == true { recorder.note("deterministic-replay", "Repeated planning with identical caller-supplied IDs and timestamp was byte-structurally equal.") }
        if expected.usesNetwork == false { recorder.note("provider-independent", "Evaluation used only local typed interpreter/planner APIs; no provider or network API is reachable from this executable.") }
        if expected.offlineFinite == true || expected.sourceUnchanged == true {
            let original = syntheticAudio("cleanVocalLike")
            let immutableSource = original
            for candidate in candidates {
                var processed = original
                var graph = try CompiledGraph(plan: candidate.plan, sampleRate: original.sampleRate, channelCount: original.channelCount)
                try graph.process(&processed)
                if expected.offlineFinite == true { try recorder.expect(allFinite(processed), "offline-finite-\(candidate.interpretationIndex)", "generated output contains a nonfinite sample") }
                if expected.sourceUnchanged == true { try recorder.expect(checkSourceUnchanged(immutableSource, original), "source-immutable-\(candidate.interpretationIndex)", "source fixture changed during offline processing") }
            }
            recorder.note("execution-claim-boundary", "Synthetic execution establishes finite deterministic processing only; no perceptual quality or acoustic-instrument claim is made.")
        }
    }

    private func evaluateClarification(_ item: CorpusCase, recorder: inout Recorder) throws {
        let source = stableUUID("\(item.id):source")
        let typedScope = try scope(item.scope, label: item.id)
        let intent = try VocalIntentInterpreter().interpret(prompt: item.prompt ?? "", intentID: stableUUID("\(item.id):intent"), sourceSnapshotID: source, scope: typedScope)
        try recorder.expect(item.expected.outcome == "clarification", "outcome", "case must be classified as clarification")
        if let archetype = item.expected.archetype { try recorder.expect(intent.archetype.rawValue == archetype, "archetype", "expected \(archetype)") }
        if let aspects = item.expected.aspects {
            try recorder.expect(
                Set(intent.desiredChanges.map { $0.aspect.rawValue }) == Set(aspects),
                "desired-aspects",
                "expected exact desired aspects \(aspects), got \(intent.desiredChanges.map { $0.aspect.rawValue })"
            )
        }
        if let prohibited = item.expected.prohibited {
            try recorder.expect(
                Set(intent.preservation.prohibitedChanges.map(\.rawValue)) == Set(prohibited),
                "prohibited-aspects",
                "expected exact prohibited aspects \(prohibited), got \(intent.preservation.prohibitedChanges.map(\.rawValue))"
            )
        }
        if let count = item.expected.ambiguityCount { try recorder.expect(intent.ambiguities.count == count, "one-clarification", "expected exactly \(count) ambiguity, got \(intent.ambiguities.count)") }
        guard let clarification = intent.blockingClarification else {
            throw HarnessError.assertion("Underspecified ordinary intent did not expose a typed blocking clarification")
        }
        try recorder.expect(intent.requiresBlockingClarification, "blocking-clarification-status", "underspecified ordinary intent must be marked as blocking")
        try recorder.expect(
            intent.clarificationPrompt == clarification.prompt && !clarification.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "blocking-clarification-prompt",
            "typed blocking clarification must expose one nonempty app-displayable prompt"
        )
        try recorder.expect(clarification.reason == .missingDesiredChanges, "blocking-clarification-reason", "expected missingDesiredChanges clarification reason")

        let processingScope = typedScope.processingScope(channelFormat: .mono, sourceType: .vocal)
        var refusedBeforeCandidateConstruction = false
        do {
            let candidates = try VocalCreativePlanner().plan(
                intent: intent,
                processingScope: processingScope,
                analysis: planningAnalysis,
                deterministicIDs: .init(),
                createdAt: fixedDate
            )
            throw HarnessError.assertion("Planner unexpectedly returned \(candidates.count) executable candidates for a blocking clarification")
        } catch let error as HarnessError {
            throw error
        } catch let error as VocalContractError {
            guard case let .blockingClarificationRequired(actual) = error else {
                throw HarnessError.assertion("Planner returned the wrong refusal for a blocking clarification: \(error)")
            }
            try recorder.expect(actual == clarification, "typed-planner-refusal", "planner must return the exact typed blocking clarification")
            refusedBeforeCandidateConstruction = true
        }
        try recorder.expect(refusedBeforeCandidateConstruction, "no-executable-candidates", "planner must refuse before returning executable candidates")
    }

    private func evaluateIntentRefusal(_ item: CorpusCase, recorder: inout Recorder) throws {
        let expected = item.expected.errorContains ?? ""
        do {
            _ = try VocalIntentInterpreter().interpret(
                prompt: item.prompt ?? "",
                intentID: stableUUID("\(item.id):intent"),
                sourceSnapshotID: stableUUID("\(item.id):source"),
                scope: try scope(item.scope, label: item.id)
            )
            throw HarnessError.assertion("Interpreter unexpectedly accepted refused case")
        } catch let error as HarnessError { throw error }
        catch {
            try recorder.expect(String(describing: error).localizedCaseInsensitiveContains(expected), "typed-refusal", "expected error containing '\(expected)', got '\(error)'")
        }
    }

    private func evaluatePlannerRefusal(_ item: CorpusCase, recorder: inout Recorder) throws {
        let expected = item.expected.errorContains ?? ""
        do {
            _ = try makePlanBundle(item, sourceTypeOverride: .drums)
            throw HarnessError.assertion("Planner unexpectedly accepted non-vocal source")
        } catch let error as HarnessError where error.description.contains("unexpectedly") { throw error }
        catch {
            try recorder.expect(String(describing: error).localizedCaseInsensitiveContains(expected), "source-type-refusal", "expected error containing '\(expected)', got '\(error)'")
        }
    }

    private func captureBrief(profile: String, label: String) throws -> VocalCaptureBrief {
        func item(_ kind: VocalEquipmentKind, _ state: VocalKnowledgeState, model: String? = nil) -> VocalEquipmentItem {
            VocalEquipmentItem(
                kind: kind,
                state: state,
                manufacturer: model == nil ? nil : "TrackSmith test declaration",
                model: model,
                userConfirmedFeatures: model == nil ? [] : ["User-confirmed fixture metadata"],
                uncertainty: state == .known || state == .notPresent ? [] : ["Exact hardware behavior is not known."]
            )
        }
        let known = profile == "knownControlled"
        let noExtras = profile == "reflectiveNoExtras"
        let fixed = profile == "fixedRoomQuiet"
        guard ["unknownBedroom", "reflectiveNoExtras", "knownControlled", "fixedRoomQuiet"].contains(profile) else {
            throw HarnessError.schema("Unknown capture profile \(profile)")
        }
        let equipment = VocalCaptureEquipment(
            microphone: item(.microphone, known ? .known : .unknown, model: known ? "Known cardioid microphone" : nil),
            audioInterface: item(.audioInterface, known ? .known : .userUnsure, model: known ? "Known interface" : nil),
            externalPreamp: item(.externalPreamp, .notPresent),
            headphones: item(.headphones, known ? .known : .unknown, model: known ? "Known headphones" : nil),
            popFilter: item(.popFilter, noExtras ? .notPresent : (known ? .known : .unknown), model: known ? "Known pop filter" : nil)
        )
        var constraints: [VocalCaptureConstraint] = [
            VocalCaptureConstraint(kind: .performerComfort, description: "Stop and roll back if the performer is less comfortable.", hardConstraint: true),
            VocalCaptureConstraint(kind: .hearingSafety, description: "Keep headphone monitoring at a safe level.", hardConstraint: true),
        ]
        if noExtras { constraints.append(VocalCaptureConstraint(kind: .noAdditionalEquipment, description: "Use only equipment already present.", hardConstraint: true)) }
        if fixed {
            constraints.append(VocalCaptureConstraint(kind: .fixedRoomPosition, description: "The microphone and performer must remain at the current room position.", hardConstraint: true))
            constraints.append(VocalCaptureConstraint(kind: .mustRemainQuiet, description: "Do not create additional noise during setup.", hardConstraint: true))
        }
        return VocalCaptureBrief(
            id: stableUUID("\(label):brief"),
            desiredResult: "Capture a clear, natural, editable vocal while preserving the performance and voice identity.",
            priorities: [
                VocalCapturePriorityWeight(priority: .intelligibility, weight: 1),
                VocalCapturePriorityWeight(priority: .performanceComfort, weight: 0.95),
                VocalCapturePriorityWeight(priority: .lowReflection, weight: 0.8),
                VocalCapturePriorityWeight(priority: .editability, weight: 0.8),
            ],
            equipment: equipment,
            microphonePattern: VocalMicPatternKnowledge(state: known ? .known : .unknown, pattern: known ? .cardioid : nil, confirmedByUser: known),
            environment: VocalCaptureEnvironment(
                backgroundNoise: known ? .low : .unknown,
                reflectionRisk: noExtras ? .high : (known ? .low : .moderate),
                roomSizeKnown: known,
                roomDescription: known ? "User-described controlled room" : nil,
                movableSoftMaterialsAvailable: noExtras ? .notPresent : (known ? .known : .unknown),
                knownNoiseSources: fixed ? ["User requires quiet setup"] : [],
                observations: ["All room and hardware facts are caller-declared; no acoustic inference is claimed."],
                provenance: [VocalProvenance(identifier: "\(label)-environment", evidenceKind: .userReported, statement: "Synthetic evaluation profile representing user-reported capture constraints.", limitations: ["Not an acoustic measurement."], confidence: 1)]
            ),
            practicalConstraints: constraints,
            preservePerformanceAttributes: [.emotionalDelivery, .naturalDynamics, .diction, .timingFeel, .movementFreedom],
            preserveVoiceAttributes: [.voiceIdentity, .pitch, .timing, .dynamics],
            assumptions: known ? [] : ["Only reversible relative moves are permitted while hardware is unknown."],
            missingInformation: known ? [] : ["Exact microphone, interface, pickup pattern, and room response are unavailable."],
            uncertainty: known ? [] : ["No device-specific knob, pattern, or acoustic outcome may be predicted."],
            provenance: [VocalProvenance(identifier: "\(label)-brief", evidenceKind: .userReported, statement: "Evaluation capture brief with typed constraints and preservation requirements.", limitations: ["Preference still requires a same-passage listening comparison."], confidence: 1)]
        )
    }

    private func deterministicCapturePlan(profile: String, label: String) throws -> [VocalCaptureInterpretation] {
        let brief = try captureBrief(profile: profile, label: label)
        let ids = (0..<3).map { stableUUID("\(label):capture-candidate:\($0)") }
        let planner = VocalCapturePlanner()
        let first = try planner.plan(brief: brief, interpretationIDs: ids)
        let second = try planner.plan(brief: brief, interpretationIDs: ids)
        guard first == second else { throw HarnessError.assertion("Capture plan replay differs") }
        return first
    }

    private func evaluateCapturePlan(_ item: CorpusCase, recorder: inout Recorder) throws {
        guard let profile = item.captureProfile else { throw HarnessError.schema("\(item.id) has no captureProfile") }
        let plans = try deterministicCapturePlan(profile: profile, label: item.id)
        if let count = item.expected.candidateCount { try recorder.expect(plans.count == count, "candidate-count", "expected \(count), got \(plans.count)") }
        try recorder.expect(Set(plans.map(\.id)).count == 3, "candidate-identities", "capture plan requires exactly three unique IDs")
        try recorder.expect(Set(plans.map(\.title)).count == 3, "distinct-titles", "capture hypotheses need distinct titles")
        try recorder.expect(Set(plans.map { "\($0.placement.distance.rawValue):\($0.placement.height.rawValue):\($0.placement.angle.rawValue):\($0.roomPosition.rawValue)" }).count == 3 || profile == "fixedRoomQuiet", "distinct-capture-variables", "capture hypotheses must differ structurally within hard constraints")
        try recorder.expect(plans.allSatisfy { !$0.comparison.exactProcedure.isEmpty && !$0.comparison.stopRule.isEmpty && !$0.comparison.rollbackInstructions.isEmpty }, "comparison-protocol", "every capture candidate needs instructions, stop rule, and rollback")
        try recorder.expect(plans.allSatisfy { !$0.provenance.isEmpty }, "provenance", "every capture candidate needs provenance")
        if let strategies = item.expected.roomStrategies { try recorder.expect(plans.map { $0.roomPosition.rawValue } == strategies, "room-strategies", "expected \(strategies), got \(plans.map { $0.roomPosition.rawValue })") }
        if let minimum = item.expected.minimumUncertaintyCount { try recorder.expect(plans.allSatisfy { $0.uncertainty.count >= minimum }, "uncertainty-boundary", "each plan must expose at least \(minimum) uncertainty entries") }
        if let required = item.expected.requiresUnknownHardwareBoundary {
            let hasBoundary = plans.allSatisfy { plan in
                plan.uncertainty.contains { $0.localizedCaseInsensitiveContains("hardware or pickup behavior is unknown") }
                    && !plan.gainAndHeadroom.unknownHardwareBoundary.isEmpty
            }
            try recorder.expect(hasBoundary == required, "unknown-hardware-boundary", "expected unknown-hardware boundary=\(required), got \(hasBoundary)")
        }
        if item.expected.forbidsPurchaseLanguage == true {
            let encoded = try JSONEncoder().encode(plans)
            let text = String(decoding: encoded, as: UTF8.self).lowercased()
            let purchasePattern = #"\b(buy|purchase|rent|acquire|order)\b"#
            try recorder.expect(text.range(of: purchasePattern, options: .regularExpression) == nil, "no-purchase-advice", "capture plan proposed acquiring equipment despite constraints")
        }
        if item.expected.deterministicReplay == true { recorder.note("deterministic-replay", "Repeated capture planning with three caller-supplied IDs was structurally equal.") }
    }

    private func sourceClass(_ raw: String?) throws -> SourceAnalysisClass {
        guard let raw else { return .vocal }
        guard let value = SourceAnalysisClass(rawValue: raw) else { throw HarnessError.schema("Unknown source class \(raw)") }
        return value
    }

    private func assessment(_ item: CorpusCase, label: String? = nil) throws -> (AudioBuffer, VocalTestTakeAssessment) {
        let original = syntheticAudio(item.audioFixture)
        let typedSourceClass = try sourceClass(item.sourceClass)
        let cacheKey = "\(item.audioFixture ?? "cleanVocalLike"):\(typedSourceClass.rawValue)"
        let report: SourceAwareAnalysisReport
        if let cached = sourceAwareAnalysisCache[cacheKey] {
            report = cached
        } else {
            let analyzed = SourceAwareAudioAnalyzer().analyze(original, as: typedSourceClass)
            sourceAwareAnalysisCache[cacheKey] = analyzed
            report = analyzed
        }
        let result = VocalTestTakeAssessor().assess(report, assessmentID: stableUUID("\(label ?? item.id):assessment"))
        return (original, result)
    }

    private func evaluateCaptureAssessment(_ item: CorpusCase, recorder: inout Recorder) throws {
        let before = syntheticAudio(item.audioFixture)
        let (source, result) = try assessment(item)
        let kinds = Set(result.findings.map { $0.kind.rawValue })
        for kind in item.expected.findingKinds ?? [] { try recorder.expect(kinds.contains(kind), "finding-\(kind)", "assessment findings \(kinds.sorted()) do not include \(kind)") }
        if let immediateStop = item.expected.immediateStop { try recorder.expect(result.requiresImmediateStop == immediateStop, "immediate-stop", "expected \(immediateStop), got \(result.requiresImmediateStop)") }
        if let expectedClass = item.expected.sourceClass { try recorder.expect(result.sourceClass?.rawValue == expectedClass, "source-class", "expected \(expectedClass), got \(result.sourceClass?.rawValue ?? "nil")") }
        if let maximum = item.expected.activeShareMaximum,
           let finding = result.findings.first(where: { $0.kind == .activeWindowShare }),
           let value = finding.value {
            try recorder.expect(value <= maximum, "active-share-gate", "active share \(value) exceeds \(maximum)")
        }
        try recorder.expect(result.findings.allSatisfy { $0.evidenceKind != .listeningOnly }, "objective-evidence-labels", "measurement pipeline must not label a finding as a listening judgment")
        try recorder.expect(result.listeningOnlyJudgments == VocalListeningJudgment.allCases, "listening-only-boundary", "all listening-only judgment categories must remain explicit")
        try recorder.expect(result.measurementLimitations.contains { $0.localizedCaseInsensitiveContains("no phoneme") }, "measurement-limitations", "assessment must disclaim phoneme/performance understanding")
        if item.expected.sourceUnchanged == true { try recorder.expect(checkSourceUnchanged(before, source), "source-unchanged", "analysis mutated the generated source") }
        recorder.note("claim-boundary", "Findings are measurements or bounded product heuristics; placement quality, articulation, performance, and acceptability still require listening.")
    }

    private func feedback(_ profile: String?) throws -> VocalCaptureListeningFeedback {
        switch profile ?? "none" {
        case "none": return VocalCaptureListeningFeedback()
        case "plosiveWorse": return VocalCaptureListeningFeedback(breathBlastOrPlosiveRisk: .worse, note: "User-reported listening label.")
        case "roomWorse": return VocalCaptureListeningFeedback(roomOrReflectionImpression: .worse, note: "User-reported listening label.")
        case "comfortWorse": return VocalCaptureListeningFeedback(performanceComfort: .worse, voiceNaturalness: .worse, note: "User-reported listening label.")
        case "confirmedBalanced": return VocalCaptureListeningFeedback(wordClarity: .better, performanceComfort: .better, voiceNaturalness: .better, proximity: .balanced, note: "Explicit formative preference.", explicitlyConfirmAsPreference: true)
        default: throw HarnessError.schema("Unknown feedback profile \(profile ?? "nil")")
        }
    }

    private func evaluateCaptureRevision(_ item: CorpusCase, recorder: inout Recorder) throws {
        guard let profile = item.captureProfile else { throw HarnessError.schema("Missing capture profile") }
        let plans = try deterministicCapturePlan(profile: profile, label: "\(item.id):base")
        let selected = plans[0]
        let (_, assessed) = try assessment(item, label: item.id)
        let userFeedback = try feedback(item.feedbackProfile)
        let reviser = VocalCapturePlanReviser()
        func apply() -> VocalCaptureRevisionResult {
            reviser.revise(
                selected: selected,
                assessment: assessed,
                feedback: userFeedback,
                revisedInterpretationID: stableUUID("\(item.id):result"),
                revisionID: stableUUID("\(item.id):revision"),
                preferenceID: stableUUID("\(item.id):preference"),
                revisedAt: fixedDate
            )
        }
        let first = apply()
        let second = apply()
        if item.expected.deterministicReplay == true { try recorder.expect(first == second, "deterministic-replay", "repeated capture revision differs") }
        let revised = first.revisedInterpretation
        try recorder.expect(revised.parentInterpretationID == selected.id, "parent-identity", "revision lost exact parent")
        try recorder.expect(revised.ancestry == selected.ancestry + [selected.id], "ancestry", "revision ancestry is not append-only")
        try recorder.expect(revised.revisionID == stableUUID("\(item.id):revision"), "revision-identity", "revision ID differs")
        try recorder.expect(revised.comparison.rollbackInstructions.contains { $0.localizedCaseInsensitiveContains(selected.id.uuidString) }, "exact-rollback", "rollback does not name exact parent interpretation")
        if let gain = item.expected.gainDirection { try recorder.expect(revised.gainAndHeadroom.direction.rawValue == gain, "gain-direction", "expected \(gain), got \(revised.gainAndHeadroom.direction.rawValue)") }
        if let angle = item.expected.placementAngle { try recorder.expect(revised.placement.angle.rawValue == angle, "placement-angle", "expected \(angle), got \(revised.placement.angle.rawValue)") }
        if let room = item.expected.roomPosition { try recorder.expect(revised.roomPosition.rawValue == room, "room-position", "expected \(room), got \(revised.roomPosition.rawValue)") }
        if item.expected.placementMatchesParent == true { try recorder.expect(revised.placement == selected.placement && revised.roomPosition == selected.roomPosition, "placement-rollback", "comfort/naturalness feedback must restore exact parent placement") }
        if let confirmed = item.expected.confirmedPreference { try recorder.expect((first.confirmedPreference != nil) == confirmed, "explicit-preference", "preference must exist only after explicit confirmation") }
        try recorder.expect((first.confirmedPreference != nil) == userFeedback.explicitlyConfirmAsPreference, "preference-authority", "implicit feedback must never become a confirmed preference")
    }

    private func revisionOperationStrings(_ operations: [VocalRevisionOperation]) -> [String] {
        operations.map { operation in
            switch operation {
            case .clearerWordsKeepingMovement: "clearerWordsKeepingMovement"
            case .lessReverbMoreWobble: "lessReverbMoreWobble"
            case let .changeScope(scope): "changeScope:\(scope.kind.rawValue)"
            case let .inheritAspect(aspect, _): "inheritAspect:\(aspect.rawValue)"
            case .strangerPreservingIntelligibility: "strangerPreservingIntelligibility"
            case .moreBrassLessVoice: "moreBrassLessVoice"
            case let .lockAspect(aspect): "lockAspect:\(aspect.rawValue)"
            case let .unlockAspect(aspect): "unlockAspect:\(aspect.rawValue)"
            case let .preserveAspects(aspects): "preserveAspects:\(aspects.map(\.rawValue).joined(separator: ","))"
            case .exactRevert: "exactRevert"
            }
        }
    }

    private func makePrelock(aspect: VocalAspect, base: VocalCreativeCandidate, itemID: String, policy: VocalAspectLockScopePolicy) -> VocalAspectLock {
        let nodeIDs = base.aspectBindings.filter { $0.aspect == aspect }.flatMap(\.nodeIDs)
        let idSet = Set(nodeIDs)
        let exactNodes = base.plan.nodes.filter { idSet.contains($0.id) }
        return VocalAspectLock(
            id: stableUUID("\(itemID):prelock:\(aspect.rawValue)"),
            aspect: aspect,
            reference: VocalExactReference(
                sourceSnapshotID: base.intent.sourceSnapshotID,
                scopeID: base.intent.scope.id,
                candidateID: base.id,
                nodeIDs: nodeIDs,
                aspect: aspect
            ),
            exactNodes: exactNodes,
            scopePolicy: policy,
            reason: "Pre-existing exact evaluation lock."
        )
    }

    private func evaluateRevision(_ item: CorpusCase, refusal: Bool, recorder: inout Recorder) throws {
        guard let spec = item.revision, let baseCase = casesByID[spec.baseCaseID] else { throw HarnessError.schema("Missing revision base case") }
        var available = try makePlanBundle(baseCase, identityLabel: baseCase.id).candidates
        guard available.indices.contains(spec.baseCandidateIndex) else { throw HarnessError.schema("Revision base candidate index is out of range") }
        let policy: VocalAspectLockScopePolicy = spec.lockScopePolicy == "exactScope" ? .exactScope : .contentRelative
        if let aspects = spec.prelockedAspects {
            for raw in aspects {
                guard let aspect = VocalAspect(rawValue: raw) else { throw HarnessError.schema("Unknown prelocked aspect \(raw)") }
                let lock = makePrelock(aspect: aspect, base: available[spec.baseCandidateIndex], itemID: item.id, policy: policy)
                available[spec.baseCandidateIndex].intent.aspectLocks.append(lock)
            }
        }
        if let staleIndex = spec.staleCandidateIndex {
            guard available.indices.contains(staleIndex) else { throw HarnessError.schema("Stale candidate index is out of range") }
            let staleSource = stableUUID("\(item.id):stale-source")
            available[staleIndex].intent.sourceSnapshotID = staleSource
            available[staleIndex].plan.sourceSnapshotID = staleSource
        }
        let base = available[spec.baseCandidateIndex]
        let authority = VocalRevisionReferenceAuthority(
            orderedCandidateIDs: available.map(\.id),
            selectedCandidateID: base.id,
            lastPhraseScope: try spec.lastPhraseScope.map { try scope($0, label: "\(item.id):last-phrase") },
            explicitRevertCandidateID: spec.explicitRevertCandidateIndex.flatMap { available.indices.contains($0) ? available[$0].id : nil }
        )
        do {
            let command = try VocalRevisionParser().parse(spec.prose, authority: authority, commandID: stableUUID("\(item.id):command"))
            let IDs = VocalRevisionApplicationIDs(
                resultCandidateID: stableUUID("\(item.id):result-candidate"),
                resultIntentID: stableUUID("\(item.id):result-intent"),
                resultPlanRequestID: stableUUID("\(item.id):result-request"),
                insertedNodeIDs: spec.omitApplicationIDs == true ? [] : (0..<8).map { stableUUID("\(item.id):inserted:\($0)") },
                aspectLockIDs: spec.omitApplicationIDs == true ? [] : (0..<8).map { stableUUID("\(item.id):lock:\($0)") }
            )
            let engine = VocalRevisionEngine()
            let first = try engine.apply(command, to: base, availableCandidates: available, ids: IDs, createdAt: fixedDate)
            if refusal { throw HarnessError.assertion("Revision unexpectedly succeeded") }
            let second = try engine.apply(command, to: base, availableCandidates: available, ids: IDs, createdAt: fixedDate)
            if item.expected.deterministicReplay == true { try recorder.expect(first == second, "deterministic-replay", "repeated revision application differs") }
            let result = first.candidate
            try recorder.expect(result.parentCandidateID == base.id, "parent-identity", "result does not name the exact base candidate")
            try recorder.expect(result.revisionID == command.id, "revision-identity", "result revision ID differs from typed command")
            try recorder.expect(result.plan.sourceSnapshotID == base.plan.sourceSnapshotID && result.intent.sourceSnapshotID == base.intent.sourceSnapshotID, "source-authority", "revision changed source identity")
            try recorder.expect(first.record.baseCandidateID == base.id && first.record.resultCandidateID == result.id, "revision-record", "revision record does not bind base and result identities")
            try recorder.expect(first.record.exactAncestorCandidateIDs.contains(base.id), "ancestry", "revision ancestry omits base candidate")
            if let expectedOperations = item.expected.operations { try recorder.expect(revisionOperationStrings(command.operations) == expectedOperations, "typed-operations", "expected \(expectedOperations), got \(revisionOperationStrings(command.operations))") }
            if let changedScopeOnly = item.expected.changedScopeOnly { try recorder.expect(first.record.changedScopeOnly == changedScopeOnly, "scope-only", "expected changedScopeOnly=\(changedScopeOnly), got \(first.record.changedScopeOnly)") }
            if let scopeKind = item.expected.scopeKind { try recorder.expect(result.intent.scope.kind.rawValue == scopeKind, "scope-kind", "expected \(scopeKind), got \(result.intent.scope.kind.rawValue)") }
            if let realtime = item.expected.realtimeActivatable { try recorder.expect(result.realtimeActivatable == realtime, "realtime-authority", "expected \(realtime), got \(result.realtimeActivatable)") }
            for aspect in item.expected.preserved ?? [] { try recorder.expect(result.intent.preservation.preserved.map(\.rawValue).contains(aspect), "preserved-\(aspect)", "revision preservation omits \(aspect)") }
            for aspect in item.expected.locks ?? [] { try recorder.expect(result.intent.aspectLocks.map { $0.aspect.rawValue }.contains(aspect), "lock-\(aspect)", "revision lock set omits \(aspect)") }
            if let inheritedAspect = item.expected.inheritedAspect,
               let inheritedIndex = item.expected.inheritedCandidateIndex {
                guard available.indices.contains(inheritedIndex) else { throw HarnessError.schema("Inherited candidate index is out of range") }
                let reference = available[inheritedIndex]
                try recorder.expect(first.record.inheritedReferences.contains { $0.aspect?.rawValue == inheritedAspect && $0.candidateID == reference.id }, "exact-inheritance", "revision does not reference exact candidate \(inheritedIndex + 1) for \(inheritedAspect)")
            }
            if let revertedIndex = item.expected.revertedCandidateIndex {
                guard available.indices.contains(revertedIndex) else { throw HarnessError.schema("Revert candidate index is out of range") }
                try recorder.expect(result.revertedToCandidateID == available[revertedIndex].id, "exact-revert", "revert target differs from expected candidate")
            }
            if first.record.changedScopeOnly { try recorder.expect(result.plan.nodes == base.plan.nodes, "scope-change-preserves-nodes", "scope-only revision changed DSP nodes") }
            try VocalContractValidator().validate(candidate: result)
        } catch let error as HarnessError where error.description.contains("unexpectedly") { throw error }
        catch {
            if !refusal { throw error }
            let expected = item.expected.errorContains ?? ""
            try recorder.expect(String(describing: error).localizedCaseInsensitiveContains(expected), "typed-refusal", "expected error containing '\(expected)', got '\(error)'")
        }
    }

    private func evaluateAsset(_ item: CorpusCase, refusal: Bool, recorder: inout Recorder) throws {
        let bundle = try makePlanBundle(item)
        guard var candidate = bundle.candidates.first else { throw HarnessError.assertion("Asset case has no candidate") }
        let source = syntheticAudio(item.audioFixture)
        let sourceBefore = source
        let hasher = VocalAudioHasher()
        var authority = try hasher.authority(
            for: source,
            sourceSnapshotID: bundle.sourceSnapshotID,
            immutableSourceID: "tracksmith-owned-generated-vocal-fixture-v1",
            capturedAt: fixedDate
        )
        var thirdParty: VocalThirdPartyMaterialStatus = .noneUsed
        switch item.mutation {
        case nil: break
        case "thirdPartyMaterial": thirdParty = .callerDeclaredLicensedMaterial
        case "staleSourceSnapshot": authority.sourceSnapshotID = stableUUID("\(item.id):stale-authority")
        case "staleSourceHash": authority.contentHashSHA256 = String(repeating: "0", count: 64)
        case "changedSampleRateAuthority": authority.sampleRate = 44_100
        default: throw HarnessError.schema("Unknown asset mutation \(item.mutation ?? "nil")")
        }
        // Preserve candidate-level ancestry fields as well as request-level
        // ancestry so the manifest proves exact lineage instead of prose-only
        // references.
        candidate.previewID = stableUUID("\(item.id):candidate-preview")
        candidate.assetID = stableUUID("\(item.id):candidate-asset")
        let boundary = VocalProcessingBoundaryEvaluator().decision(for: candidate.intent)
        if let disposition = item.expected.boundaryDisposition { try recorder.expect(boundary.disposition.rawValue == disposition, "boundary-disposition", "expected \(disposition), got \(boundary.disposition.rawValue)") }
        try recorder.expect(!boundary.usesNetwork, "boundary-network", "Vocal v1 asset decision must remain local")
        let parentAssetID = stableUUID("\(item.id):parent-asset")
        let request = VocalScopedRenderRequest(
            renderID: stableUUID("\(item.id):render"),
            candidate: candidate,
            sourceAuthority: authority,
            engine: .trackSmithVocalV1,
            randomSeed: 42,
            parentPreviewID: stableUUID("\(item.id):parent-preview"),
            parentAssetID: parentAssetID,
            assetAncestry: [stableUUID("\(item.id):ancestor:0"), parentAssetID],
            createdAt: fixedDate,
            crossfadeSeconds: 0.01,
            thirdPartyMaterialStatus: thirdParty
        )
        do {
            let renderer = VocalScopedAssetRenderer()
            let first = try renderer.render(source: source, request: request)
            if refusal { throw HarnessError.assertion("Asset render unexpectedly succeeded") }
            let second = try renderer.render(source: source, request: request)
            try recorder.expect(first == second, "deterministic-replay", "identical render request produced different result")
            try recorder.expect(first.manifest.renderID == request.renderID, "render-identity", "manifest render ID differs")
            try recorder.expect(first.manifest.sourceAuthority == authority, "source-authority", "manifest changed source authority")
            try recorder.expect(first.manifest.exactCandidateID == candidate.id && first.manifest.exactPlanRequestID == candidate.plan.requestID, "candidate-plan-authority", "manifest lost exact candidate or plan request")
            try recorder.expect(first.manifest.exactNodeIDs == candidate.plan.nodes.map(\.id), "node-authority", "manifest node identity/order differs")
            try recorder.expect(first.manifest.typedIntent == candidate.intent && first.manifest.preservation == candidate.intent.preservation, "intent-provenance", "manifest lost typed intent or preservation")
            try recorder.expect(first.manifest.originalPrompt == candidate.intent.originalPrompt, "original-prompt-provenance", "manifest lost the exact original prompt")
            try recorder.expect(first.manifest.processingPlan == candidate.plan, "processing-plan-provenance", "manifest lost the exact processing plan")
            try recorder.expect(first.manifest.boundaryDecision == boundary, "boundary-decision-provenance", "manifest lost the exact boundary decision")
            try recorder.expect(first.manifest.assetAncestry == request.assetAncestry && first.manifest.parentPreviewID == request.parentPreviewID && first.manifest.parentAssetID == request.parentAssetID, "asset-ancestry", "manifest lost parent/ancestry identity")
            try recorder.expect(first.manifest.engine == .trackSmithVocalV1 && first.manifest.randomSeed == 42, "engine-replay-provenance", "manifest lost engine or seed")
            if item.expected.localOffline == true { try recorder.expect(first.manifest.localOffline, "local-offline", "manifest does not assert local offline execution") }
            if item.expected.usesNetwork == false { try recorder.expect(!first.manifest.usesNetwork, "no-network", "manifest says network was used") }
            try recorder.expect(first.manifest.thirdPartyMaterialStatus == .noneUsed, "no-third-party-material", "successful render used third-party material")
            if let outside = item.expected.outsideScopePreservedExactly { try recorder.expect(first.manifest.outsideScopePreservedExactly == outside, "outside-scope-manifest", "expected outsideScopePreservedExactly=\(outside)") }
            if item.expected.renderHashStable == true {
                let exactHash = try hasher.sha256(first.audio)
                try recorder.expect(first.manifest.renderHashSHA256 == exactHash, "render-hash", "manifest hash differs from exact rendered audio")
            }
            try recorder.expect(allFinite(first.audio), "finite-render", "rendered output contains nonfinite samples")
            if item.expected.sourceUnchanged == true { try recorder.expect(checkSourceUnchanged(sourceBefore, source), "source-unchanged", "renderer mutated immutable input source") }
            if item.expected.outsideScopePreservedExactly == true, let range = candidate.intent.scope.seconds {
                let lower = Int((range.start * source.sampleRate).rounded(.down))
                let upper = Int((range.end * source.sampleRate).rounded(.up))
                var equal = true
                for channel in source.channels.indices {
                    for frame in 0..<lower where source.channels[channel][frame].bitPattern != first.audio.channels[channel][frame].bitPattern { equal = false }
                    if upper < source.frameCount {
                        for frame in upper..<source.frameCount where source.channels[channel][frame].bitPattern != first.audio.channels[channel][frame].bitPattern { equal = false }
                    }
                }
                try recorder.expect(equal, "outside-scope-bits", "samples outside exact frame range changed")
            }
            recorder.note("claim-boundary", "Generated-audio checks establish local deterministic finite execution and exact source/scope preservation only; they make no sound-quality or acoustic-reconstruction claim.")
        } catch let error as HarnessError where error.description.contains("unexpectedly") { throw error }
        catch {
            if !refusal { throw error }
            let expected = item.expected.errorContains ?? ""
            try recorder.expect(String(describing: error).localizedCaseInsensitiveContains(expected), "typed-refusal", "expected error containing '\(expected)', got '\(error)'")
        }
    }

    private func evaluateContractRefusal(_ item: CorpusCase, recorder: inout Recorder) throws {
        let bundle = try makePlanBundle(item)
        guard var candidate = bundle.candidates.first else { throw HarnessError.assertion("Contract case has no candidate") }
        do {
            switch item.mutation {
            case "stalePlanSource":
                candidate.plan.sourceSnapshotID = stableUUID("\(item.id):stale-plan-source")
                try VocalContractValidator().validate(candidate: candidate)
            case "staleLockSource":
                let aspect: VocalAspect = .movement
                candidate.intent.aspectLocks.append(VocalAspectLock(
                    id: stableUUID("\(item.id):lock"),
                    aspect: aspect,
                    reference: VocalExactReference(
                        sourceSnapshotID: stableUUID("\(item.id):stale-lock-source"),
                        scopeID: candidate.intent.scope.id,
                        candidateID: candidate.id,
                        aspect: aspect
                    ),
                    reason: "Adversarial stale-source lock."
                ))
                try VocalContractValidator().validate(intent: candidate.intent)
            case "desiredAlsoProhibited":
                guard let aspect = candidate.intent.desiredChanges.first?.aspect else { throw HarnessError.assertion("Mutation requires a desired aspect") }
                candidate.intent.preservation.prohibitedChanges.append(aspect)
                try VocalContractValidator().validate(intent: candidate.intent)
            case "malformedNamedScope":
                let malformed = VocalCreativeScope(id: stableUUID("\(item.id):malformed-scope"), kind: .namedSection, seconds: .init(start: 0.5, end: 1.0), sectionID: "", sectionName: nil)
                try VocalContractValidator().validate(scope: malformed)
            case "unsupportedNode":
                let injected = ProcessingNode(id: stableUUID("\(item.id):unsupported-node"), type: .transientShaper, parameters: [.gainDB: 1, .mix: 0.5], rationale: "Adversarial unsupported node.", confidence: 1, category: .creative)
                candidate.plan.nodes.insert(injected, at: max(0, candidate.plan.nodes.count - 1))
                try VocalContractValidator().validate(candidate: candidate)
            case "nonfiniteParameter":
                guard let nodeIndex = candidate.plan.nodes.firstIndex(where: { !$0.parameters.isEmpty }),
                      let parameter = candidate.plan.nodes[nodeIndex].parameters.keys.sorted(by: { $0.rawValue < $1.rawValue }).first else { throw HarnessError.assertion("Mutation requires a parameterized node") }
                candidate.plan.nodes[nodeIndex].parameters[parameter] = .nan
                try VocalContractValidator().validate(candidate: candidate)
            case "tooManyNodes":
                while candidate.plan.nodes.count <= PlanValidator.maximumNodeCount {
                    candidate.plan.nodes.append(ProcessingNode(id: stableUUID("\(item.id):meter:\(candidate.plan.nodes.count)"), type: .meter, rationale: "Adversarial complexity node.", confidence: 1, category: .corrective))
                }
                try VocalContractValidator().validate(candidate: candidate)
            default: throw HarnessError.schema("Unknown contract mutation \(item.mutation ?? "nil")")
            }
            throw HarnessError.assertion("Contract mutation unexpectedly validated")
        } catch let error as HarnessError where error.description.contains("unexpectedly") { throw error }
        catch {
            let expected = item.expected.errorContains ?? ""
            try recorder.expect(String(describing: error).localizedCaseInsensitiveContains(expected), "contract-refusal", "expected error containing '\(expected)', got '\(error)'")
        }
    }
}

private func writeReport(_ report: EvaluationReport, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(report)
    guard data.count <= maximumReportBytes else { throw HarnessError.configuration("Report exceeds \(maximumReportBytes) byte bound") }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

private func runMain() throws -> Int32 {
    let arguments = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
    let corpusData = try loadBounded(arguments.corpusURL)
    let failureData = try loadBounded(arguments.failureMapURL)
    try StrictJSON.validateCorpus(corpusData)
    try StrictJSON.validateFailureMap(failureData)
    let decoder = JSONDecoder()
    let corpus = try decoder.decode(Corpus.self, from: corpusData)
    let failureMap = try decoder.decode(FailureMap.self, from: failureData)
    try validateCorpusAndMap(corpus, failureMap)
    let results = Evaluator(corpus: corpus).run().sorted { $0.id < $1.id }
    let passed = results.filter(\.passed).count
    let report = EvaluationReport(
        schemaVersion: "1.1",
        corpusID: corpus.corpusID,
        corpusSHA256: sha256(corpusData),
        failureMapSHA256: sha256(failureData),
        statusDate: corpus.statusDate,
        execution: EvaluationExecutionRecord(
            sourceRevision: arguments.sourceRevision,
            sourceTreeState: arguments.sourceTreeState,
            executableSHA256: try executableSHA256(),
            toolchain: arguments.toolchain,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: runtimeArchitecture(),
            command: ["VocalProductionEvaluation"] + Array(CommandLine.arguments.dropFirst()),
            claimBoundary: arguments.sourceTreeState == "clean"
                ? "The executable and report identify a clean Git revision. This binds the exercised source but does not add listening or installed-host evidence."
                : "The evaluator ran from a dirty working tree. Treat the result as development evidence until reproduced from a clean committed revision."
        ),
        passed: passed,
        failed: results.count - passed,
        total: results.count,
        claimBoundary: corpus.claimBoundary + [failureMap.claimBoundary],
        fixture: FixtureDeclaration(
            ownership: "TrackSmith-owned deterministic harmonic vocal-like signal",
            generatedInMemory: true,
            networkUsed: false,
            userAudioUsed: false,
            claimBoundary: "Execution fixture only. No listening, quality, vocal identity, phoneme, room, microphone, brass reconstruction, or population claim."
        ),
        cases: results
    )
    try writeReport(report, to: arguments.outputURL)
    print("VOCAL_EVALUATION_SUMMARY passed=\(report.passed) failed=\(report.failed) total=\(report.total) corpus_sha256=\(report.corpusSHA256) report=\(arguments.outputURL.path)")
    return report.failed == 0 ? 0 : 1
}

do {
    Foundation.exit(try runMain())
} catch {
    fputs("VOCAL_EVALUATION_ERROR \(error)\n", stderr)
    Foundation.exit(2)
}
