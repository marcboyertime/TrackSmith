import CryptoKit
import Darwin
import Foundation
import PlanSchema
import ProductionIntelligence
import ProductionTutor
import TutorConversation
import TutorLogicObserver

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private actor PackageSeventeenCloudConcurrencyProbe {
    private var active = 0
    private var peak = 0

    func begin() {
        active += 1
        peak = max(peak, active)
    }

    func end() { active -= 1 }
    func maximum() -> Int { peak }
}

private actor CandidateRetrieverStub: CandidateRetriever {
    let state: CandidateRetrievalAvailability
    let values: [CommunityCandidateCorpusRankedCard]
    let outcome: CandidateRetrievalOutcomeKind?
    init(_ state: CandidateRetrievalAvailability, _ values: [CommunityCandidateCorpusRankedCard] = [], outcome: CandidateRetrievalOutcomeKind? = nil) { self.state = state; self.values = values; self.outcome = outcome }
    func availability() -> CandidateRetrievalAvailability { state }
    func ranked(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) -> [CommunityCandidateCorpusRankedCard] { values.prefix(limit).map { $0 } }
    func rankedOutcome(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) -> CandidateRetrievalOutcome {
        .init(kind: outcome ?? (values.isEmpty ? .noMatch : .matches), cards: values.prefix(limit).map { $0 })
    }
}

@main
@MainActor
struct TutorConversationTests {
    static func main() async {
        let projection = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("research/community_knowledge/runtime_projection/p16", isDirectory: true).path
        setenv("TRACKSMITH_LEGACY_TEST_ORACLE_DIRECTORY", projection, 1)
        let arguments = Array(CommandLine.arguments.dropFirst())
        let ordinaryFlags = Set(["--list-tests", "--shard-index", "--shard-count", "--include", "--exclude", "--output-json"])
        let ordinaryFlagsWithValues = Set(["--shard-index", "--shard-count", "--include", "--exclude", "--output-json"])
        let consentFlags = Set(["--cloud-text-consent", "--cloud-audio-consent"])
        let hasOrdinarySelection = arguments.contains { ordinaryFlags.contains($0) }
        var positionalModes: [String] = []
        var argumentIndex = 0
        while argumentIndex < arguments.count {
            let argument = arguments[argumentIndex]
            if ordinaryFlagsWithValues.contains(argument) {
                argumentIndex += 2
            } else {
                if !argument.hasPrefix("--") { positionalModes.append(argument) }
                argumentIndex += 1
            }
        }
        if !positionalModes.isEmpty && hasOrdinarySelection {
            fputs("error: ordinary-suite sharding and JSON flags are incompatible with named diagnostics\n", stderr)
            Darwin.exit(64)
        }
        let textConsentModes = Set(["package17-cloud-evaluation", "package17-cloud-health", "package19-cloud-no-tool", "package19-cloud-full-tool", "package19-cloud-repeated-triplets"])
        let audioConsentModes = Set(["package17-public-audio-evaluation"])
        let suppliedConsentFlags = Set(arguments.filter { consentFlags.contains($0) })
        if !suppliedConsentFlags.isEmpty {
            let modeSet = Set(positionalModes)
            let textAllowed = modeSet.count == 1 && textConsentModes.contains(modeSet.first ?? "") && suppliedConsentFlags == Set(["--cloud-text-consent"])
            let audioAllowed = modeSet.count == 1 && audioConsentModes.contains(modeSet.first ?? "") && suppliedConsentFlags == Set(["--cloud-audio-consent"])
            if !textAllowed && !audioAllowed {
                fputs("error: consent flags are accepted only by their matching Package 17/19 live harness\n", stderr)
                Darwin.exit(64)
            }
        }
        let selection: Suite.Selection
        do {
            selection = try Suite.Selection(arguments: arguments.filter { !consentFlags.contains($0) })
        } catch {
            fputs("error: \(error)\n", stderr)
            Darwin.exit(64)
        }
        let suite = Suite(selection: selection)
        if !selection.includes.isEmpty && !suite.allIncludesMatch() {
            fputs("error: every --include selector must match at least one ordinary test ID\n", stderr)
            Darwin.exit(64)
        }
        if selection.listOnly {
            suite.printSelectedTestList()
            return
        }
        if CommandLine.arguments.contains("package6-diagnostics") {
            await suite.runPackageSixDiagnostic()
        } else if CommandLine.arguments.contains("candidate-corpus-diagnostics") {
            await suite.runCandidateCorpusDiagnostic()
        } else if CommandLine.arguments.contains("package4-routing-regression") {
            await suite.runPackageFourRoutingRegression()
        } else if CommandLine.arguments.contains("package7-diagnostics") {
            await suite.runPackageSevenDiagnostic()
        } else if CommandLine.arguments.contains("package8-diagnostics") {
            await suite.runPackageEightDiagnostic()
        } else if CommandLine.arguments.contains("package9-diagnostics") {
            await suite.runPackageNineDiagnostic()
        } else if CommandLine.arguments.contains("package10-diagnostics") {
            await suite.runPackageTenDiagnostic()
        } else if CommandLine.arguments.contains("package11-diagnostics") {
            await suite.runPackageElevenDiagnostic()
        } else if CommandLine.arguments.contains("package12-diagnostics") {
            await suite.runPackageTwelveDiagnostic()
        } else if CommandLine.arguments.contains("package13-diagnostics") {
            await suite.runPackageThirteenDiagnostic()
        } else if CommandLine.arguments.contains("package14-diagnostics") {
            await suite.runPackageFourteenDiagnostic()
        } else if CommandLine.arguments.contains("package15-diagnostics") {
            await suite.runPackageFifteenDiagnostic()
        } else if CommandLine.arguments.contains("package16-diagnostics") {
            await suite.runPackageSixteenDiagnostic()
        } else if CommandLine.arguments.contains("receipt-diagnostics") {
            await suite.runReceiptDiagnostic()
        } else if CommandLine.arguments.contains("package16-golden") {
            await suite.runPackageSixteenGolden()
        } else if CommandLine.arguments.contains("package16-performance") {
            await suite.runPackageSixteenPerformance()
        } else if CommandLine.arguments.contains("package16-fallback") {
            await suite.runPackageSixteenFallback()
        } else if CommandLine.arguments.contains("tool-schema-diagnostics") {
            await suite.runToolSchemaDiagnostic()
        } else if CommandLine.arguments.contains("package17-diagnostics") {
            await suite.runPackageSeventeenDiagnostic()
        } else if CommandLine.arguments.contains("package18-diagnostics") {
            await suite.runPackageEighteenDiagnostic()
        } else if CommandLine.arguments.contains("package18-index-readiness") {
            await suite.runPackageEighteenIndexReadiness()
        } else if CommandLine.arguments.contains("package18-legacy-readiness") {
            await suite.runPackageEighteenLegacyReadiness()
        } else if CommandLine.arguments.contains("package19-diagnostics") {
            await suite.runPackageNineteenDiagnostic()
        } else if CommandLine.arguments.contains("package19-cloud-no-tool") {
            await suite.runPackageNineteenCloud(.noTool)
        } else if CommandLine.arguments.contains("package19-cloud-full-tool") {
            await suite.runPackageNineteenCloud(.fullTool)
        } else if CommandLine.arguments.contains("package19-cloud-repeated-triplets") {
            await suite.runPackageNineteenCloud(.repeatedTriplets)
        } else if CommandLine.arguments.contains("package17-performance") {
            await suite.runPackageSeventeenPerformance()
        } else if CommandLine.arguments.contains("package17-live-evaluation") {
            await suite.runPackageSeventeenLiveEvaluation()
        } else if CommandLine.arguments.contains("package17-live-case-144") {
            await suite.runPackageSeventeenLiveCase144()
        } else if CommandLine.arguments.contains("package17-cloud-evaluation") {
            await suite.runPackageSeventeenCloudEvaluation()
        } else if CommandLine.arguments.contains("package17-cloud-health") {
            await suite.runPackageSeventeenCloudHealth()
        } else if CommandLine.arguments.contains("package17-public-audio-evaluation") {
            await suite.runPackageSeventeenPublicAudioEvaluation()
        } else if CommandLine.arguments.contains("level-hierarchy-diagnostics") {
            await suite.runLevelHierarchyDiagnostic()
        } else if CommandLine.arguments.contains("standards-provenance-diagnostics") {
            await suite.runStandardsProvenanceDiagnostic()
        } else {
            await suite.run()
        }
        do {
            try suite.writeReportIfRequested()
        } catch {
            fputs("error: could not write TutorConversationTests JSON report: \(error)\n", stderr)
            Darwin.exit(65)
        }
        print("TutorConversationTests: \(suite.passed)/\(suite.total) passed")
        fflush(stdout)
        if suite.passed != suite.total { Darwin.exit(1) }
    }
}

@MainActor
private final class Suite {
    private(set) var total = 0
    private(set) var passed = 0
    private let selection: Selection
    private lazy var fixedSelection = selectedCases()
    private lazy var semanticContext = (source: fileHash("tools/TutorConversationTests/Sources/TutorConversationTests/TutorConversationTests.swift"), policy: fileHash("ci/tracksmith_compute_lanes.json"), index: fileHash("packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.manifest.json"))
    private var results: [[String: Any]] = []

    struct Selection {
        let listOnly: Bool
        let includes: [String]
        let excludes: [String]
        let shardIndex: Int
        let shardCount: Int
        let outputURL: URL?

        init(arguments: [String]) throws {
            var includeValues: [String] = []
            var excludeValues: [String] = []
            var index = 0
            var count = 1
            var output: URL?
            var list = false
            var cursor = 0
            while cursor < arguments.count {
                let value = arguments[cursor]
                func nextValue() throws -> String {
                    guard cursor + 1 < arguments.count else { throw TestFailure(description: "missing value for \(value)") }
                    cursor += 1; return arguments[cursor]
                }
                switch value {
                case "--list-tests": list = true
                case "--include": includeValues.append(try nextValue())
                case "--exclude": excludeValues.append(try nextValue())
                case "--shard-index": guard let parsed = Int(try nextValue()), parsed >= 0 else { throw TestFailure(description: "--shard-index must be a nonnegative integer") }; index = parsed
                case "--shard-count": guard let parsed = Int(try nextValue()), parsed > 0 else { throw TestFailure(description: "--shard-count must be positive") }; count = parsed
                case "--output-json": output = URL(fileURLWithPath: try nextValue())
                default:
                    if value.hasPrefix("--") { throw TestFailure(description: "unknown ordinary-suite option \(value)") }
                }
                cursor += 1
            }
            guard index < count else { throw TestFailure(description: "--shard-index must be smaller than --shard-count") }
            self.listOnly = list; self.includes = includeValues; self.excludes = excludeValues
            self.shardIndex = index; self.shardCount = count; self.outputURL = output
        }
    }

    private struct CaseSpec { let id: String; let name: String; let resourceClass: String }
    private static let suiteID = "tracksmith.tutor-conversation"
    private static let suiteVersion = "2"
    private static let ordinaryCases: [CaseSpec] = [
        ("tutor-conversation/01-tool-firewall", "tool registry is mutation-incapable", "cpu"),
        ("tutor-conversation/02-legacy-boundary", "legacy identifiers and Create/Vocal boundary are preserved", "cpu"),
        ("tutor-conversation/03-streaming-ui", "Tutor streaming UI batches text with stable eager transcript layout", "cpu"),
        ("tutor-conversation/04-tool-schema", "strict OpenAI tool schemas stay bounded", "cpu"),
        ("tutor-conversation/05-sse-decoder", "SSE decoder reconstructs deltas, text, calls, and metadata", "cpu"),
        ("tutor-conversation/06-streaming-provider", "streaming provider emits SSE and sends store false", "cpu"),
        ("tutor-conversation/07-streaming-timeout", "streaming timeout is typed and sanitized", "cpu"),
        ("tutor-conversation/08-tool-execution", "reviewed knowledge, procedures, capture, Logic, and experiment tools execute", "cpu"),
        ("tutor-conversation/09-candidate-corpus", "candidate corpus stays provisional, collapsed, and structurally complete", "io"),
        ("tutor-conversation/10-store-receipts", "conversation store is checksummed, redacted, bounded, and receipt write-once", "io"),
        ("tutor-conversation/11-audio-consent", "audio listening requires separate consent and exact live hash", "cpu"),
        ("tutor-conversation/12-audio-truth", "audio intelligence evidence keeps exact waveform and calibration truth separate", "cpu"),
        ("tutor-conversation/13-local-waveform", "local waveform provider emits capture-bound exact-WAV observations", "cpu"),
        ("tutor-conversation/14-live-like-wave", "live-like Float WAV local evidence is finite, encodable, and cannot abort a tool turn", "cpu"),
        ("tutor-conversation/15-attached-double-failure", "double provider failure leaves an honest attached-capture assistant status", "cpu"),
        ("tutor-conversation/16-attached-fallback", "attached generic offline fallback gives one honest reversible tonal next step", "cpu"),
        ("tutor-conversation/17-comparison-authority", "comparison authority rejects hash-only follow-ups and accepts guarded continuity", "cpu"),
        ("tutor-conversation/18-pending-isolation", "two pending experiment confirmations cannot cross-authorize comparisons", "cpu"),
        ("tutor-conversation/19-legacy-experiment", "legacy experiment records decode with Phase 2 fields absent", "cpu"),
        ("tutor-conversation/20-dialogue-quality", "not sure and clearer-but-thin dialogue remain useful without listening claims", "cpu"),
        ("tutor-conversation/21-stateful-vertical", "muddy to thin stateful conversation retains turns, tools, experiment, and outcome", "cpu"),
        ("tutor-conversation/22-offline-fallback", "cloud failure activates deterministic offline fallback", "cpu"),
        ("tutor-conversation/23-cancellation", "cancellation persists an honest partial turn and blocks concurrent turns", "cpu"),
        ("tutor-conversation/24-package9", "Package 9 gain, bus, clipping, limiting, loudness migration integrity", "io"),
        ("tutor-conversation/25-package10", "Package 10 Flex Time/manual timing canonical-only migration integrity", "io"),
        ("tutor-conversation/26-package11", "Package 11 Smart Tempo canonical-only migration integrity", "io"),
        ("tutor-conversation/27-package12", "Package 12 recording/monitoring/comping/punch exact-subset migration integrity", "io"),
        ("tutor-conversation/28-package13", "Package 13 sends/buses/auxes/stacks/groups exact-subset migration integrity", "io"),
        ("tutor-conversation/29-package14", "Package 14 sidechain/automation/MIDI exact-subset migration integrity", "io"),
        ("tutor-conversation/30-package15", "Package 15 MIDI/Piano Roll/bounce/freeze/PDC exact-subset migration integrity", "io"),
        ("tutor-conversation/31-package16-golden", "Package 16 golden conversations stay bounded and model-independent", "cpu"),
        ("tutor-conversation/32-package16-performance", "Package 16 candidate retrieval performance stays bounded", "io"),
        ("tutor-conversation/33-package16-fallback", "Package 16 candidate and provider failures stay fail-soft", "cpu"),
        ("tutor-conversation/34-package17-contract", "Package 17 experience levels are explicit, persistent-safe, and receipt-bound", "cpu"),
        ("tutor-conversation/35-package17-isolation", "Package 17 provider context remains compact and evaluation-isolated", "cpu"),
        ("tutor-conversation/36-package17-offline", "Package 17 offline levels preserve one safe experiment and stream promptly", "cpu"),
    ].map { CaseSpec(id: $0.0, name: $0.1, resourceClass: $0.2) }

    init(selection: Selection = try! Selection(arguments: [])) { self.selection = selection }

    func printSelectedTestList() { for item in fixedSelection.cases { print("\(item.id)\t\(item.resourceClass)\t\(item.name)") } }

    private nonisolated static let packageSeventeenCloudMaximumTopicConcurrency = 3
    private nonisolated static let packageSeventeenCloudMaximumAttempts = 2
    private nonisolated static let packageSeventeenLevelOrder: [TutorExperienceLevel] = [.noob, .amateur, .pro]
    private nonisolated static let packageSeventeenTextModel = "gpt-5.6-sol"
    private nonisolated static let packageNineteenCloudPromptSuiteSHA256 = "22753465ef6b3aa1e3d53485c89b167028491b3ecf33cc32ce9c104e3eb2fba2"
    private nonisolated static let packageNineteenOrderedCloudPromptSHA256 = "1125a004c80a2977692c11abd5f3fc9f6114d63cb920bcf3623cc32d90ca57bb"
    private nonisolated static let packageSeventeenAudioModel = "gpt-audio-1.5"
    private nonisolated static let packageSeventeenPublicAudioFixtureSHA256 = "f6f168af94a612185ea4b9338e96776f936dcff2188ba5330cf3702067f11d7b"
    private nonisolated static let packageSeventeenPublicAudioFixturePathSuffix = "/Library/Caches/TrackSmith/P16/fixtures/generated/p16-controlled-source.wav"

    enum PackageNineteenCloudLane { case noTool, fullTool, repeatedTriplets }

    private struct PackageSeventeenCloudPrompt: Sendable {
        var order: Int
        var topic: String
        var query: String
    }

    private struct PackageSeventeenCloudRequestOutcome: Sendable {
        var text: String?
        var metadata: TutorProviderMetadata?
        var attempts: Int
        var terminalStatus: String
        var safeFailure: String?
    }

    private struct PackageSeventeenCloudResponse: Sendable {
        var prompt: PackageSeventeenCloudPrompt
        var level: TutorExperienceLevel
        var outcome: PackageSeventeenCloudRequestOutcome
    }

    private struct PackageSeventeenCloudTopicResult: Sendable {
        var prompt: PackageSeventeenCloudPrompt
        var responses: [PackageSeventeenCloudResponse]
    }

    private struct PackageSeventeenCloudJudgment: Sendable {
        var prompt: PackageSeventeenCloudPrompt
        var outcome: PackageSeventeenCloudRequestOutcome?
        var terminalStatus: String
        var safeFailure: String?
        var semanticReferenceProvided: Bool
    }

    private struct PackageSeventeenSemanticReference: Sendable {
        var problemSummary: String
        var recommendedFirstExperiment: String
        var evidenceRequirements: String
        var riskAndUndo: String
    }

    /// Evaluation-only run record. The artifact is built from the actual
    /// provider envelopes and engine receipt, never from advertised tools.
    private struct PackageNineteenCloudGeneration {
        var artifact: [String: Any]
        var response: PackageSeventeenCloudResponse
        var providerRequestCalls: Int
    }

    private struct PackageNineteenRetryResult {
        var outcome: PackageSeventeenCloudRequestOutcome
        var failureHistory: [[String: Any]]
        var providerRequestCalls: Int
        var durableCompletionWarning: String?
    }

    private struct PackageNineteenTopicFixture: Sendable {
        var sourceType: SourceType
        var capture: TutorCaptureSnapshot
        var logicControl: String
        var limitation: String
        var identity: [String: String]
    }

    func run() async {
        await test("tool registry is mutation-incapable", testToolMutationFirewall)
        await test("legacy identifiers and Create/Vocal boundary are preserved", testLegacyBoundary)
        await test("Tutor streaming UI batches text with stable eager transcript layout", testTutorStreamingUIContract)
        await test("strict OpenAI tool schemas stay bounded", testToolSchemas)
        await test("SSE decoder reconstructs deltas, text, calls, and metadata", testSSEDecoder)
        await test("streaming provider emits SSE and sends store false", testStreamingProvider)
        await test("streaming timeout is typed and sanitized", testStreamingTimeout)
        await test("reviewed knowledge, procedures, capture, Logic, and experiment tools execute", testToolExecution)
        await test("candidate corpus stays provisional, collapsed, and structurally complete", testCandidateCorpus)
        await test("conversation store is checksummed, redacted, bounded, and receipt write-once", testStoreAndReceipts)
        await test("audio listening requires separate consent and exact live hash", testAudioListening)
        await test("audio intelligence evidence keeps exact waveform and calibration truth separate", testAudioIntelligenceTruth)
        await test("local waveform provider emits capture-bound exact-WAV observations", testLocalProviderExactWAV)
        await test("live-like Float WAV local evidence is finite, encodable, and cannot abort a tool turn", testLiveLikeLocalEvidenceTurn)
        await test("double provider failure leaves an honest attached-capture assistant status", testAttachedCaptureDoubleFailure)
        await test("attached generic offline fallback gives one honest reversible tonal next step", testAttachedGenericOfflineFallback)
        await test("comparison authority rejects hash-only follow-ups and accepts guarded continuity", testComparisonAuthority)
        await test("two pending experiment confirmations cannot cross-authorize comparisons", testPendingExperimentConfirmationIsolation)
        await test("legacy experiment records decode with Phase 2 fields absent", testLegacyExperimentDecoding)
        await test("not sure and clearer-but-thin dialogue remain useful without listening claims", testResponseQualityVerticalSlice)
        await test("muddy to thin stateful conversation retains turns, tools, experiment, and outcome", testStatefulVerticalSlice)
        await test("cloud failure activates deterministic offline fallback", testAutomaticOfflineFallback)
        await test("cancellation persists an honest partial turn and blocks concurrent turns", testCancellationAndExclusion)
        await test("Package 9 gain, bus, clipping, limiting, loudness migration integrity", testPackageNineDiagnostic)
        await test("Package 10 Flex Time/manual timing canonical-only migration integrity", testPackageTenDiagnostic)
        await test("Package 11 Smart Tempo canonical-only migration integrity", testPackageElevenDiagnostic)
        await test("Package 12 recording/monitoring/comping/punch exact-subset migration integrity", testPackageTwelveDiagnostic)
        await test("Package 13 sends/buses/auxes/stacks/groups exact-subset migration integrity", testPackageThirteenDiagnostic)
        await test("Package 14 sidechain/automation/MIDI exact-subset migration integrity", testPackageFourteenDiagnostic)
        await test("Package 15 MIDI/Piano Roll/bounce/freeze/PDC exact-subset migration integrity", testPackageFifteenDiagnostic)
        await test("Package 16 golden conversations stay bounded and model-independent", testPackageSixteenGolden)
        await test("Package 16 candidate retrieval performance stays bounded", testPackageSixteenPerformance)
        await test("Package 16 candidate and provider failures stay fail-soft", testPackageSixteenFallback)
        await test("Package 17 experience levels are explicit, persistent-safe, and receipt-bound", testPackageSeventeenExperienceContract)
        await test("Package 17 provider context remains compact and evaluation-isolated", testPackageSeventeenProviderIsolation)
        await test("Package 17 offline levels preserve one safe experiment and stream promptly", testPackageSeventeenOfflineLevelsAndPerformance)
    }

    func runPackageSixDiagnostic() async {
        await test("Package 6 migration integrity and nonlinear/transient distinctions", testPackageSixDiagnostic)
    }

    func runCandidateCorpusDiagnostic() async {
        await test("candidate corpus stays provisional, collapsed, and structurally complete", testCandidateCorpus)
    }

    func runReceiptDiagnostic() async {
        await test("receipt persistence", testStoreAndReceipts)
    }

    func runPackageFourRoutingRegression() async {
        await test("Package 4 reverb/delay effect-choice regression", testPackageFourRoutingRegression)
    }

    func runPackageSevenDiagnostic() async {
        await test("Package 7 phase/polarity/stereo/panning migration integrity", testPackageSevenDiagnostic)
    }

    func runPackageEightDiagnostic() async {
        await test("Package 8 editing/layering migration integrity and distinctions", testPackageEightDiagnostic)
    }

    func runPackageNineDiagnostic() async {
        await test("Package 9 gain/bus/loudness migration integrity", testPackageNineDiagnostic)
    }

    func runPackageTenDiagnostic() async {
        await test("Package 10 Flex Time/manual timing canonical-only migration integrity", testPackageTenDiagnostic)
    }

    func runPackageElevenDiagnostic() async {
        await test("Package 11 Smart Tempo canonical-only migration integrity", testPackageElevenDiagnostic)
    }

    func runPackageTwelveDiagnostic() async {
        await test("Package 12 recording/monitoring/comping/punch exact-subset migration integrity", testPackageTwelveDiagnostic)
    }

    func runPackageThirteenDiagnostic() async {
        await test("Package 13 sends/buses/auxes/stacks/groups exact-subset migration integrity", testPackageThirteenDiagnostic)
    }

    func runPackageFourteenDiagnostic() async {
        await test("Package 14 sidechain/automation/MIDI exact-subset migration integrity", testPackageFourteenDiagnostic)
    }

    func runPackageFifteenDiagnostic() async {
        await test("Package 15 MIDI/Piano Roll/bounce/freeze/PDC exact-subset migration integrity", testPackageFifteenDiagnostic)
    }

    func runPackageSixteenDiagnostic() async {
        await test("Package 16 bounded candidate retrieval and runtime exact-fixture firewall", testPackageSixteenDiagnostic)
    }

    func runPackageSixteenGolden() async {
        await test("Package 16 golden conversations stay bounded and model-independent", testPackageSixteenGolden)
    }

    func runPackageSixteenPerformance() async {
        await test("Package 16 candidate retrieval performance stays bounded", testPackageSixteenPerformance)
    }

    func runPackageSixteenFallback() async {
        await test("Package 16 candidate and provider failures stay fail-soft", testPackageSixteenFallback)
    }

    func runToolSchemaDiagnostic() async {
        await test("strict OpenAI tool schemas stay bounded", testToolSchemas)
    }

    func runPackageSeventeenDiagnostic() async {
        await test("Package 17 experience levels are explicit, persistent-safe, and receipt-bound", testPackageSeventeenExperienceContract)
        await test("Package 17 provider context remains compact and evaluation-isolated", testPackageSeventeenProviderIsolation)
        await test("Package 17 opt-in audio receipt keeps exact binding and store false", testAudioListening)
        await test("Package 17 offline levels preserve one safe experiment and stream promptly", testPackageSeventeenOfflineLevelsAndPerformance)
    }

    func runPackageEighteenDiagnostic() async {
        await test("Package 18 indexed retrieval is lazy, bounded, and fail-soft", testPackageEighteenDiagnostic)
    }

    func runPackageEighteenIndexReadiness() async {
        await test("Package 18 immutable index readiness", testPackageEighteenIndexReadiness)
    }

    func runPackageEighteenLegacyReadiness() async {
        await test("Package 18 legacy oracle readiness baseline", testPackageEighteenLegacyReadiness)
    }

    func runPackageNineteenDiagnostic() async {
        await test("Package 19 deterministic seven-tool and frozen-suite diagnostic", testPackageNineteenDiagnostic)
    }

    func runPackageNineteenCloud(_ lane: PackageNineteenCloudLane) async {
        await test("Package 19 consent-gated cloud \(String(describing: lane)) harness", { try await testPackageNineteenCloud(lane) })
    }

    func runPackageSeventeenPerformance() async {
        await test("Package 17 offline levels preserve one safe experiment and stream promptly", testPackageSeventeenOfflineLevelsAndPerformance)
    }

    func runPackageSeventeenLiveEvaluation() async {
        await test("Package 17 real Offline Tutor evaluation records all level triplets", testPackageSeventeenLiveOfflineEvaluation)
    }

    func runPackageSeventeenLiveCase144() async {
        await test("Package 17 live case 144 exposes actual authority boundary", testPackageSeventeenLiveCase144)
    }

    func runPackageSeventeenCloudEvaluation() async {
        await test("Package 17 opt-in cloud evaluation has explicit consent and no fallback", testPackageSeventeenCloudEvaluation)
    }

    func runPackageSeventeenCloudHealth() async {
        await test("Package 17 one-prompt cloud health has sanitized SSE diagnostics", testPackageSeventeenCloudHealth)
    }

    func runPackageSeventeenPublicAudioEvaluation() async {
        await test("Package 17 opt-in public audio evaluation has explicit consent and exact binding", testPackageSeventeenPublicAudioEvaluation)
    }

    private func caseSpec(_ name: String) -> CaseSpec? { Self.ordinaryCases.first { $0.name == name } }

    private func matches(_ identifier: String, _ pattern: String) -> Bool {
        pattern.hasSuffix("*") ? identifier.hasPrefix(String(pattern.dropLast())) : identifier == pattern
    }

    private func fileHash(_ relative: String) -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(relative)
        return (try? Data(contentsOf: url)).map(sha256) ?? "unavailable"
    }

    private func costSeconds() -> [String: Double] {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("ci/tutor_test_costs.json")
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(payload.keys) == Set(["schema_version", "suite_id", "suite_version", "suite_source_hash", "policy_hash", "index_hash", "case_ids", "cost_seconds"]),
              payload["schema_version"] as? String == "tracksmith-tutor-test-costs/2",
              payload["suite_id"] as? String == Self.suiteID,
              payload["suite_version"] as? String == Self.suiteVersion,
              payload["suite_source_hash"] as? String == semanticContext.source,
              payload["policy_hash"] as? String == semanticContext.policy,
              payload["index_hash"] as? String == semanticContext.index,
              let caseIDs = payload["case_ids"] as? [String],
              caseIDs == Self.ordinaryCases.map(\.id),
              let raw = payload["cost_seconds"] as? [String: Any],
              Set(raw.keys) == Set(caseIDs) else { return [:] }
        let parsed: [String: Double] = raw.reduce(into: [:]) { result, item in
            if let number = item.value as? NSNumber,
               String(cString: number.objCType) != "c", // CFBoolean's Objective-C type encoding
               number.doubleValue.isFinite,
               number.doubleValue > 0 { result[item.key] = number.doubleValue }
        }
        return parsed.count == caseIDs.count ? parsed : [:]
    }

    private func selectedCases() -> (cases: [CaseSpec], algorithm: String) {
        var candidates = Self.ordinaryCases.filter { item in
            (selection.includes.isEmpty || selection.includes.contains { matches(item.id, $0) }) &&
            !selection.excludes.contains { matches(item.id, $0) }
        }
        let costs = costSeconds()
        let useCosts = !candidates.isEmpty && candidates.allSatisfy { costs[$0.id] != nil }
        if useCosts {
            candidates.sort { costs[$0.id]! == costs[$1.id]! ? $0.id < $1.id : costs[$0.id]! > costs[$1.id]! }
            var bins = Array(repeating: (load: 0.0, items: [CaseSpec]()), count: selection.shardCount)
            for item in candidates {
                let target = bins.indices.min { left, right in
                    bins[left].load == bins[right].load ? left < right : bins[left].load < bins[right].load
                }!
                bins[target].items.append(item); bins[target].load += costs[item.id]!
            }
            return (bins[selection.shardIndex].items.sorted { $0.id < $1.id }, "lpt-cost-v1")
        }
        let assigned = candidates.filter { item in
            let prefix = sha256(Data(item.id.utf8)).prefix(16)
            return Int((UInt64(prefix, radix: 16) ?? 0) % UInt64(selection.shardCount)) == selection.shardIndex
        }.sorted { $0.id < $1.id }
        return (assigned, "sha256-modulo-v1")
    }

    private func shouldRun(_ name: String) -> Bool {
        guard let item = caseSpec(name) else { return true }
        return fixedSelection.cases.contains { $0.id == item.id }
    }

    func allIncludesMatch() -> Bool {
        selection.includes.allSatisfy { pattern in Self.ordinaryCases.contains { matches($0.id, pattern) } }
    }

    func writeReportIfRequested() throws {
        guard let outputURL = selection.outputURL else { return }
        let selected = fixedSelection
        let expected = selected.cases.map(\.id).sorted()
        let partition = sha256(Data(expected.joined(separator: "\n").utf8))
        let payload: [String: Any] = [
            "schema_version": "tracksmith-shard-report/1",
            "suite_id": Self.suiteID,
            "suite_version": Self.suiteVersion,
            "suite_source_hash": semanticContext.source,
            "commit": ProcessInfo.processInfo.environment["GITHUB_SHA"] ?? "local",
            "tree_classification": ProcessInfo.processInfo.environment["GITHUB_SHA"] == nil ? "local-observational" : "github-clean-checkout",
            "shard_index": selection.shardIndex,
            "shard_count": selection.shardCount,
            "assignment_algorithm": selected.algorithm,
            "assignment_version": "1",
            "partition_hash": partition,
            "expected_ids": expected,
            "executed_ids": results.compactMap { $0["id"] as? String }.sorted(),
            "cases": results.sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") },
            "toolchain_identity": ProcessInfo.processInfo.environment["TRACKSMITH_TUTOR_TOOLCHAIN_ID"] ?? "local-toolchain-identity-not-exported",
            "toolchain_hash": sha256(Data((ProcessInfo.processInfo.environment["TRACKSMITH_TUTOR_TOOLCHAIN_ID"] ?? "local-toolchain-identity-not-exported").utf8)),
            "policy_hash": semanticContext.policy,
            "index_hash": semanticContext.index,
            "observation": ["wall_clock_is_observational": true]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outputURL, options: .atomic)
    }

    private func test(_ name: String, _ body: () async throws -> Void) async {
        guard shouldRun(name) else { return }
        total += 1
        let started = ContinuousClock.now
        let item = caseSpec(name)
        do {
            try await body()
            passed += 1
            print("PASS \(name)")
            if let item {
                let semantic = semanticHash(for: item)
                results.append(["id": item.id, "semantic_input_hash": semantic, "outcome": "passed", "duration_seconds": started.duration(to: .now).components.seconds, "result_hash": sha256(Data("\(item.id)|passed|\(semantic)".utf8)), "resource_class": item.resourceClass])
            }
        } catch {
            print("FAIL \(name): \(error)")
            if let item {
                let semantic = semanticHash(for: item)
                results.append(["id": item.id, "semantic_input_hash": semantic, "outcome": "failed", "duration_seconds": started.duration(to: .now).components.seconds, "result_hash": sha256(Data("\(item.id)|failed|\(semantic)".utf8)), "resource_class": item.resourceClass])
            }
        }
    }

    private func semanticHash(for item: CaseSpec) -> String {
        sha256(Data("\(Self.suiteID)|\(Self.suiteVersion)|\(item.id)|\(item.name)|\(item.resourceClass)|\(semanticContext.source)|\(semanticContext.policy)|\(semanticContext.index)|ordinary-case-schema-v1".utf8))
    }

    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(description: message) }
    }

    private func testToolMutationFirewall() async throws {
        let definitions = TutorToolExecutor.defaultDefinitions
        try expect(definitions.map(\.name) == [
            "get_current_capture_context",
            "search_production_knowledge",
            "search_candidate_corpus",
            "get_logic_procedure",
            "retrieve_prior_experiments",
            "inspect_logic",
            "present_experiment",
        ], "tool allowlist changed")
        let forbiddenNameFragments = ["commit", "bypass", "insert", "set_", "write", "render", "automation", "click"]
        for definition in definitions {
            try expect(!forbiddenNameFragments.contains(where: { definition.name.lowercased().contains($0) }),
                       "mutation-like tool name escaped allowlist: \(definition.name)")
            try expect(definition.kind == .readOnly || definition.kind == .presentationOnly,
                       "tool has an unauthorized kind")
        }
        try expect(LogicReadOnlyObserver.exposesMutationActions == false,
                   "Logic observer unexpectedly exposes mutation actions")
        try expect(OpenAITutorProvider.systemInstructions.contains("The user performs every Logic edit"),
                   "system boundary is missing")
        try expect(OpenAITutorProvider.systemInstructions.contains("no authority or capability to click"),
                   "model mutation denial is missing")
    }

    private func testLegacyBoundary() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        func source(_ relativePath: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
        }
        let project = try source("project.yml")
        try expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.marcboyer.logicaudioassistant\n"),
                   "legacy companion bundle identifier changed")
        try expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.marcboyer.logicaudioassistant.AudioUnit"),
                   "legacy Audio Unit bundle identifier changed")
        let audioUnitInfo = try source("plugins/AudioUnit/AudioUnitExtension/Info.plist")
        try expect(audioUnitInfo.contains("<string>LgAA</string>"), "legacy AU subtype changed")
        try expect(audioUnitInfo.contains("<string>ExAI</string>"), "legacy AU manufacturer changed")
        let app = try source("apps/CompanionMacApp/CompanionMacApp.swift")
        try expect(app.contains("Future / Legacy") && app.contains("Create For Me") && app.contains("Vocal"),
                   "Create/Vocal are no longer preserved behind the Future/Legacy boundary")
        try expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("packages/VocalProduction").path),
                   "Vocal package was removed")
        try expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("packages/ProductionIntelligence").path),
                   "Create foundation was removed")
        let tutorSession = try source("apps/CompanionMacApp/TutorConversationSessionModel.swift")
        try expect(tutorSession.contains("signalPathConfirmedExperimentIDs.contains(experiment.id)"),
                   "signal-path confirmation is not scoped to the selected experiment")
        try expect(tutorSession.contains("signalPathConfirmedExperimentIDs.remove(experiment.id)"),
                   "selected experiment confirmation is not cleared after outcome")
    }

    private func testTutorStreamingUIContract() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        func source(_ relativePath: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
        }
        let session = try source("apps/CompanionMacApp/TutorConversationSessionModel.swift")
        try expect(session.contains("pendingStreamingTextChunks.append(delta)"),
                   "provider deltas are no longer staged before publication")
        try expect(session.contains("Task.sleep(nanoseconds: Self.streamingPublicationDelayNanoseconds)"),
                   "streaming text publication is no longer throttled")
        try expect(session.contains("streamingPublicationDelayNanoseconds: UInt64 = 100_000_000"),
                   "streaming UI publication no longer leaves enough layout headroom")
        try expect(session.contains("streamingPublicationTask?.cancel()\n        streamingPublicationTask = nil"),
                   "a manual streaming flush can leave a prior publisher alive")
        try expect(session.contains("flushStagedStreamingText()"),
                   "final streamed text is not explicitly flushed before completion")

        let view = try source("apps/CompanionMacApp/TutorConversationView.swift")
        try expect(!view.contains("ScrollViewReader"),
                   "the transcript still has a programmatic scroll controller")
        try expect(!view.contains("scrollTo("),
                   "the transcript can still override a manual scroll position")
        try expect(!view.contains(".id(message.id)") && !view.contains(".id(\"streaming\")"),
                   "the transcript still carries programmatic scroll anchors")
        try expect(!view.contains("LazyVStack"),
                   "the transcript still uses lazy estimate-based layout")
        try expect(view.contains("VStack(alignment: .leading, spacing: Theme.Spacing.twentyFour)"),
                   "the transcript is no longer backed by a stable eager stack")
        try expect(!view.contains("axis: .vertical") && !view.contains(".lineLimit(1...5)"),
                   "the composer still uses a multiline self-sizing text field")
        try expect(view.contains("TextField(\"What changed, or what do you want to understand?\", text: $tutor.composer)"),
                   "the primary composer is no longer a stable single-line text field")
        try expect(view.contains(".onSubmit { tutor.send(session: session) }"),
                   "the primary composer no longer sends on submit")
    }

    private func testToolSchemas() async throws {
        for definition in TutorToolExecutor.defaultDefinitions {
            let schema = OpenAITutorProvider.toolSchema(definition)
            try expect(schema["type"] as? String == "function", "tool is not a function")
            try expect(schema["strict"] as? Bool == true, "tool schema is not strict")
            guard let parameters = schema["parameters"] as? [String: Any] else {
                throw TestFailure(description: "missing parameter schema")
            }
            try expect(parameters["additionalProperties"] as? Bool == false,
                       "tool permits unbounded extra arguments")
        }
        let experiment = OpenAITutorProvider.toolSchema(
            TutorToolExecutor.defaultDefinitions.first { $0.name == "present_experiment" }!
        )
        let parameters = experiment["parameters"] as! [String: Any]
        let required = parameters["required"] as! [String]
        try expect(Set(required) == Set([
            "title", "logic_location", "action", "starting_range", "listen_for",
            "why", "risk", "stop_condition", "undo", "visual_target_query",
        ]), "experiment contract is incomplete")
        let properties = parameters["properties"] as! [String: Any]
        let stop = properties["stop_condition"] as? [String: Any]
        try expect(stop?["type"] as? String == "string" && parameters["additionalProperties"] as? Bool == false,
                   "experiment stop condition schema is not strict")
        let defaults = TutorProviderConfiguration()
        try expect(defaults.modelIdentifier == "gpt-5.6-sol", "Tutor no longer defaults to the strongest configured reasoning model")
        try expect(defaults.serviceTier == .priority, "Tutor no longer defaults gpt-5.6-sol requests to priority service tier")
        let legacyConfiguration = try JSONDecoder().decode(TutorProviderConfiguration.self, from: Data(#"{"modelIdentifier":"gpt-5.6-sol","reasoningEffort":"high","cloudTextConsent":false,"timeoutSeconds":45,"maximumOutputTokens":25000}"#.utf8))
        try expect(legacyConfiguration.serviceTier == .priority, "legacy Tutor provider configuration did not migrate to priority service tier")
        try expect(defaults.maximumOutputTokens == 25_000, "reasoning/output reserve regressed")
        try expect(TutorAudioListeningConfiguration().modelIdentifier == "gpt-audio-1.5",
                   "audio listener defaulted to a deprecated model")
    }

    private func testSSEDecoder() async throws {
        let delta = try OpenAITutorSSEEventDecoder.decode(
            data: #"{"type":"response.output_text.delta","delta":"Clearer "}"#
        )
        try expect(delta == [.textDelta("Clearer ")], "text delta was not decoded")
        let completedJSON = #"{"type":"response.completed","response":{"id":"resp_test","model":"gpt-test","service_tier":"priority","usage":{"input_tokens":12,"output_tokens":7},"output":[{"type":"reasoning","id":"rs_test","summary":[],"encrypted_content":"opaque-test-ciphertext"},{"type":"message","content":[{"type":"output_text","text":"Try one move."}]},{"type":"function_call","call_id":"call_1","name":"search_production_knowledge","arguments":"{\"query\":\"muddy vocal\"}"}]}}"#
        let completed = try OpenAITutorSSEEventDecoder.decode(data: completedJSON)
        guard case let .completed(metadata, output) = completed.first else {
            throw TestFailure(description: "completion event missing")
        }
        try expect(metadata.serviceTier == .priority, "response service tier was not retained in provider metadata")
        try expect(metadata.providerResponseID == "resp_test", "response ID missing")
        try expect(metadata.inputTokens == 12 && metadata.outputTokens == 7, "usage missing")
        try expect(output.contains(.text("Try one move.")), "completed text missing")
        try expect(output.contains(.functionCall(TutorToolCall(
            callID: "call_1",
            name: "search_production_knowledge",
            argumentsJSON: #"{"query":"muddy vocal"}"#
        ))), "function call missing")
        try expect(output.contains(where: {
            if case let .responseInputItemJSON(json) = $0 {
                return json.contains("opaque-test-ciphertext")
            }
            return false
        }), "encrypted stateless reasoning item was discarded")
        do {
            _ = try OpenAITutorSSEEventDecoder.decode(data: "not-json")
            throw TestFailure(description: "invalid SSE unexpectedly decoded")
        } catch let error as TutorConversationError {
            try expect(error == .malformedProviderResponse("SSE event diagnostic bytes=8 json=invalid type=unavailable"),
                       "SSE diagnostic exposed content or lost bounded metadata")
        }
    }

    private func testStreamingProvider() async throws {
        let lines = [
            #"data: {"type":"response.output_text.delta","delta":"Hello "}"#,
            "",
            "data:    ",
            "",
            #"data: {"type":"response.completed","response":{"id":"resp_stream","model":"gpt-stream-test","usage":{"input_tokens":4,"output_tokens":2},"output":[{"type":"message","content":[{"type":"output_text","text":"Hello there"}]}]}}"#,
            "",
            "data: [DONE]",
            "",
        ]
        let transport = RecordingStreamingTransport(lines: lines)
        let provider = OpenAITutorProvider(
            configuration: TutorProviderConfiguration(
                modelIdentifier: "gpt-test",
                reasoningEffort: .high,
                cloudTextConsent: true
            ),
            credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "test-key-not-secret"]),
            transport: transport
        )
        let request = TutorProviderRequest(
            messages: [TutorConversationMessage(role: .user, text: "Help my vocal")],
            context: TutorRuntimeContext(sourceType: .vocal),
            tools: TutorToolExecutor.defaultDefinitions,
            responseInputItemsJSON: [
                #"{"type":"reasoning","id":"rs_1","summary":[],"encrypted_content":"opaque-replay-ciphertext"}"#,
                #"{"type":"function_call","call_id":"call_1","name":"search_production_knowledge","arguments":"{\"query\":\"muddy vocal\"}"}"#,
                #"{"type":"function_call_output","call_id":"call_1","output":"{\"matches\":[]}"}"#,
            ]
        )
        var events: [TutorProviderEvent] = []
        for try await event in provider.stream(request) { events.append(event) }
        try expect(events.contains(.textDelta("Hello ")), "provider did not stream a delta")
        try expect(events.contains(where: {
            if case let .completed(metadata, _) = $0 { return metadata.providerResponseID == "resp_stream" }
            return false
        }), "provider did not complete")
        guard let recorded = transport.latestRequest(),
              let body = try JSONSerialization.jsonObject(with: recorded.body) as? [String: Any] else {
            throw TestFailure(description: "request body was not recorded")
        }
        try expect(body["stream"] as? Bool == true, "stream flag missing")
        try expect(body["store"] as? Bool == false, "provider storage was not disabled")
        try expect(body["parallel_tool_calls"] as? Bool == false, "parallel calls were not disabled")
        try expect((body["reasoning"] as? [String: String])?["context"] == "current_turn",
                   "stateless reasoning context was not scoped to the current tool turn")
        try expect((body["tools"] as? [[String: Any]])?.count == TutorToolExecutor.defaultDefinitions.count,
                   "tool allowlist was not sent exactly")
        try expect(recorded.url == OpenAITutorProvider.endpoint, "wrong provider endpoint")
        try expect(String(decoding: recorded.body, as: UTF8.self).contains("opaque-replay-ciphertext"),
                   "encrypted reasoning continuity was not replayed with the tool output")

        let boundaryTransport = RecordingStreamingTransport(lines: [
            "event: response.created",
            #"data: {"type":"response.created","response":{"id":"boundary"}}"#,
            "event: response.output_text.delta",
            #"data: {"type":"response.output_text.delta","delta":"Framed "}"#,
            "event: response.completed",
            #"data: {"type":"response.completed","response":{"id":"boundary","model":"gpt-stream-test","output":[{"type":"message","content":[{"type":"output_text","text":"Framed completion"}]}]}}"#,
            "event: done",
            "data: [DONE]",
        ])
        let boundaryProvider = OpenAITutorProvider(
            configuration: .init(modelIdentifier: "gpt-test", cloudTextConsent: true),
            credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "test-key-not-secret"]),
            transport: boundaryTransport
        )
        var boundaryEvents: [TutorProviderEvent] = []
        for try await event in boundaryProvider.stream(TutorProviderRequest(messages: [.init(role: .user, text: "frame test")], context: .init(sourceType: .vocal), tools: [])) {
            boundaryEvents.append(event)
        }
        try expect(boundaryEvents.contains(.textDelta("Framed ")) && boundaryEvents.contains(where: { if case .completed = $0 { true } else { false } }),
                   "event-field boundaries were not decoded when blank lines were absent")

        let longMessages = (0..<80).map { index in
            TutorConversationMessage(role: index.isMultiple(of: 2) ? .user : .assistant,
                                     text: "message-\(index)-" + String(repeating: "x", count: 24_000))
        }
        for try await _ in provider.stream(TutorProviderRequest(
            messages: longMessages,
            context: TutorRuntimeContext(sourceType: .vocal),
            tools: TutorToolExecutor.defaultDefinitions
        )) {}
        guard let boundedRequest = transport.latestRequest(),
              let boundedBody = try JSONSerialization.jsonObject(with: boundedRequest.body) as? [String: Any],
              let boundedInput = boundedBody["input"] as? [[String: Any]] else {
            throw TestFailure(description: "bounded history request was not recorded")
        }
        try expect(boundedRequest.body.count <= 512 * 1_024, "model request exceeded its byte envelope")
        try expect(boundedInput.count < 81, "history count bound did not apply")
        try expect(String(decoding: boundedRequest.body, as: UTF8.self).contains("message-79-"),
                   "newest bounded history was dropped")
    }

    private func testStreamingTimeout() async throws {
        let provider = OpenAITutorProvider(
            configuration: TutorProviderConfiguration(modelIdentifier: "gpt-test", cloudTextConsent: true),
            credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "test-key-not-secret"]),
            transport: ThrowingStreamingTransport(error: URLError(.timedOut))
        )
        do {
            for try await _ in provider.stream(TutorProviderRequest(
                messages: [TutorConversationMessage(role: .user, text: "test")],
                context: TutorRuntimeContext(sourceType: .vocal),
                tools: []
            )) {}
            throw TestFailure(description: "timeout unexpectedly succeeded")
        } catch let error as TutorConversationError {
            try expect(error == .timedOut, "timeout was not mapped to typed Tutor error")
        }
    }

    private func testToolExecution() async throws {
        let prior = TutorExperimentRecord(
            draft: experimentDraft(title: "Earlier low-mid test"),
            outcome: .better,
            userNote: "clearer"
        )
        let executor = try TutorToolExecutor(
            observeLogic: { query in
                TutorLogicObservation(
                    status: .observed,
                    applicationName: "Logic Pro",
                    bundleIdentifier: "com.apple.logic10",
                    windowTitle: "Secret Project Name - Tracks",
                    controls: [TutorObservedControl(
                        role: "AXButton",
                        label: query,
                        value: "off",
                        frame: TutorScreenRect(x: 99, y: 88, width: 77, height: 66)
                    )],
                    limitation: "Test fixture: read-only visible attributes."
                )
            },
            priorExperiments: { [prior] }
        )
        let capture = sampleCapture(wavData: Data("capture".utf8))
        let context = TutorRuntimeContext(sourceType: .vocal, capture: capture)

        let captureResult = try await executor.execute(TutorToolCall(
            callID: "capture", name: "get_current_capture_context", argumentsJSON: "{}"
        ), context: context)
        try expect(captureResult.outputJSON.contains(capture.captureSnapshotID.uuidString), "capture identity missing")
        try expect(!captureResult.outputJSON.lowercased().contains("relativepath"), "path leaked")
        try expect(!captureResult.outputJSON.contains("Y2FwdHVyZQ=="), "audio bytes leaked")

        let knowledge = try await executor.execute(TutorToolCall(
            callID: "knowledge",
            name: "search_production_knowledge",
            argumentsJSON: #"{"query":"muddy vocal low mid"}"#
        ), context: context)
        try expect(knowledge.evidence.contains(where: { $0.kind == .reviewedKnowledge }),
                   "reviewed knowledge provenance missing")

        let noKnowledge = try await executor.execute(TutorToolCall(
            callID: "no-knowledge",
            name: "search_production_knowledge",
            argumentsJSON: #"{"query":"zzzznonexistenttokenzzzz"}"#
        ), context: context)
        try expect(noKnowledge.outputJSON.contains(#""matches":[]"#), "unrelated query returned a source-type-only match")

        let procedure = try await executor.execute(TutorToolCall(
            callID: "procedure",
            name: "get_logic_procedure",
            argumentsJSON: #"{"query":"Channel EQ vocal low mid"}"#
        ), context: context)
        try expect(procedure.outputJSON.contains(#""grants_execution_authority":false"#),
                   "procedure execution boundary missing")

        let history = try await executor.execute(TutorToolCall(
            callID: "history",
            name: "retrieve_prior_experiments",
            argumentsJSON: #"{"query":null,"max_results":6}"#
        ), context: context)
        try expect(history.outputJSON.contains("Earlier low-mid test"), "prior outcome missing")

        let observed = try await executor.execute(TutorToolCall(
            callID: "logic",
            name: "inspect_logic",
            argumentsJSON: #"{"query":"Channel EQ"}"#
        ), context: context)
        try expect(observed.outputJSON.contains(#""mutation_capability":false"#), "Logic mutation denial missing")
        try expect(!observed.outputJSON.contains("Secret Project Name"), "Logic project/window title leaked to the model")
        try expect(!observed.outputJSON.contains(#""x":99"#), "screen coordinates leaked to the model")
        try expect(observed.evidence.contains(where: { $0.kind == .logicObserved }), "Logic evidence missing")

        let card = try await executor.execute(TutorToolCall(
            callID: "experiment",
            name: "present_experiment",
            argumentsJSON: experimentArguments(title: "Cut a little low-mid")
        ), context: context)
        try expect(card.experiment != nil, "experiment card missing")
        try expect(card.outputJSON.contains("performed no mutation"), "presentation boundary missing")

        do {
            _ = try await executor.execute(TutorToolCall(
                callID: "forbidden", name: "commit_processing_plan", argumentsJSON: "{}"
            ), context: context)
            throw TestFailure(description: "unknown mutation tool executed")
        } catch let error as TutorConversationError {
            try expect(error == .unknownTool("commit_processing_plan"), "unknown tool did not fail closed")
        }
    }

    private func testPackageSixDiagnostic() async throws {
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-006-saturation-transient-shaping-evaluation")
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let retrieval = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        var failures: [String] = []
        for item in retrieval + supplied {
            guard let query=item["query"] as? String, let expected=item["expected_canonical_ids"] as? [String], expected.count == 1,
                  let ranked=corpus.rank(query: query, filters: .init(packageID: "tracksmith-corpus-006-saturation-transient-shaping")) else { failures.append("unrankable \(item["id"] ?? "unknown")"); continue }
            let forbidden=item["forbidden_canonical_ids"] as? [String] ?? []
            if ranked.card.id != expected[0] || forbidden.contains(ranked.card.id) { failures.append("\(item["id"] ?? "unknown") -> \(ranked.card.id)") }
            if failures.count >= 24 { break }
        }
        try expect(retrieval.count == 1_920 && supplied.count == 120 && failures.isEmpty,
                   "package-6 migration ranking failures (first \(failures.count)): \(failures.joined(separator: " | "))")
        try expect(scenarios.count == 1_152 && scenarios.allSatisfy { ($0["messages"] as? [[String: Any]])?.count == 6 && ($0["review_state"] as? String) == "candidate_not_yet_human_reviewed" }, "package-6 six-message scenario provenance drifted")
        try expect(accounting["rawPackageUniqueExactCaseCount"] as? Int == 1_920 && accounting["rawPackageNonExactLexicalCaseCount"] as? Int == 0 && accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 1_920 && accounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 0 && (accounting["safetyRedactedExactFixtureIDs"] as? [String])?.isEmpty == true, "package-6 honest exact accounting drifted")
        let p6=corpus.canonicalCards.filter { $0.packageID == "tracksmith-corpus-006-saturation-transient-shaping" }
        try expect(p6.count == 384 && p6.allSatisfy { $0.primaryResearchSourceIDs != nil && $0.nonProcessingPossibilities?.isEmpty == false && $0.procedureVerificationStatus == "candidate_unverified_on_installed_logic" }, "package-6 provenance or procedure boundary drifted")
        let legacyArrangementQuery="My vocal vanishes below dense guitars; should I compress the singer harder or remove a guitar role first?"
        guard let legacyArrangement=corpus.rank(query: legacyArrangementQuery, filters: .init()) else { throw TestFailure(description: "legacy arrangement regression did not rank") }
        try expect(legacyArrangement.card.domain == "arrangement" && legacyArrangement.card.packageID != "tracksmith-corpus-006-saturation-transient-shaping", "legacy arrangement cause-first regression -> \(legacyArrangement.card.id)/\(legacyArrangement.card.domain)")
        try testPackageSixAdversarialDiagnostics(corpus)
    }

    func runLevelHierarchyDiagnostic() async {
        await test("level-control hierarchy semantics", testLevelHierarchyDiagnostic)
    }

    func runStandardsProvenanceDiagnostic() async {
        await test("P9 standards tool and receipt provenance", testStandardsProvenanceDiagnostic)
    }

    private func testStandardsProvenanceDiagnostic() async throws {
        let executor = try TutorToolExecutor()
        let result = try await executor.execute(TutorToolCall(
            callID: "p9-ebu3341", name: "search_candidate_corpus",
            argumentsJSON: #"{"query":"What should I understand about momentary, short-term, and integrated loudness, and why does it matter?","package_id":"tracksmith-corpus-009-gain-staging-bus-processing-loudness"}"#
        ), context: TutorRuntimeContext(sourceType: .fullMix))
        guard let output = try JSONSerialization.jsonObject(with: Data(result.outputJSON.utf8)) as? [String: Any],
              let match = output["match"] as? [String: Any],
              let standards = match["standards_source_ids"] as? [String],
              let authoritative = match["authoritative_supporting_source_ids"] as? [String],
              let provenance = result.evidence.first?.candidateCorpusProvenance else {
            throw TestFailure(description: "P9 standards tool result missing")
        }
        func containsInternalIdentityKey(_ value: Any) -> Bool {
            if let object = value as? [String: Any] {
                return object.contains { key, child in
                    ["id", "record_id", "package_id", "package_version", "package_sequence"].contains(key) ||
                        containsInternalIdentityKey(child)
                }
            }
            if let values = value as? [Any] {
                return values.contains(where: containsInternalIdentityKey)
            }
            return false
        }
        let expectedStandards = ["pkg009.source.000042", "pkg009.source.000043", "pkg009.source.000047", "pkg009.source.000050"]
        let returnedSHA256 = SHA256.hash(data: try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]))
            .map { String(format: "%02x", $0) }.joined()
        try expect(provenance.recordID == "pkg009.qa.000281" && !containsInternalIdentityKey(output) &&
                   Set(standards).isSubset(of: Set(expectedStandards)) && provenance.standardsSourceIDs == expectedStandards &&
                   (provenance.sourceIDs?.count ?? 0) <= 6 && Set(authoritative).isDisjoint(with: Set(standards)) &&
                   provenance.resultSHA256 == returnedSHA256,
                   "P9 standards payload/receipt partition or complete-output hash drifted")
        let root = temporaryRoot("p9-standards-receipt"); defer { try? FileManager.default.removeItem(at: root) }
        let store = TutorConversationStore(rootURL: root)
        let receipt = TutorEvidenceReceipt(conversationID: UUID(), userMessageID: UUID(), assistantMessageID: UUID(),
                                           provider: TutorProviderMetadata(providerIdentifier: "test", modelIdentifier: "test-model"),
                                           assistantTextSHA256: sha256(Data("P9 standards".utf8)), captureSnapshotID: nil,
                                           captureSHA256: nil, evidence: result.evidence, tools: [])
        try store.saveReceipt(receipt)
        let persisted = try store.loadReceipt(receipt.id).evidence.first?.candidateCorpusProvenance
        try expect((persisted?.sourceIDs?.count ?? 0) <= 6 && persisted?.standardsSourceIDs == expectedStandards,
                   "persisted P9 standards provenance drifted")
        let legacy = try JSONDecoder().decode(TutorEvidenceReference.self, from: Data(#"{"id":"00000000-0000-0000-0000-000000000003","kind":"candidateKnowledge","label":"legacy","detail":"legacy","candidateCorpusProvenance":{"packageID":"legacy-package","packageVersion":"1.0.0","packageSequence":1,"recordID":"legacy-card"}}"#.utf8))
        try expect(legacy.candidateCorpusProvenance?.standardsSourceIDs == nil,
                   "legacy receipt decoding gained a standards partition")
    }

    private func testLevelHierarchyDiagnostic() async throws {
        let corpus = try CommunityCandidateCorpus.loadValidated()
        struct Case { let label: String; let query: String; let expected: String; let forbidden: String }
        let cases = [
            Case(label: "fader plus buried hierarchy", query: "I keep raising the lead vocal fader but it is still buried under backing parts. What hierarchy should win?", expected: "level_balancing", forbidden: "bus_processing"),
            Case(label: "level control foreground", query: "The lead stays buried below background harmonies after I raise its fader; what level hierarchy should I test first?", expected: "level_balancing", forbidden: "bus_processing"),
            Case(label: "input stage remains distinct", query: "For an analog-modeled plugin's input calibration, should I use input trim or the channel fader to change how hard I drive it?", expected: "gain_staging", forbidden: "level_balancing"),
            Case(label: "explicit routing remains bus", query: "Should a VCA control a subgroup while an aux bus sums audio, and how should that routing affect bus processing?", expected: "bus_processing", forbidden: "level_balancing")
        ]
        var failures: [String] = []
        for item in cases {
            guard let ranked = corpus.rank(query: item.query) else { failures.append("unrankable \(item.label)"); continue }
            if ranked.card.domain != item.expected || ranked.card.domain == item.forbidden {
                failures.append("\(item.label) -> \(ranked.card.id)/\(ranked.card.domain)")
            }
        }
        try expect(failures.isEmpty, "level-control hierarchy diagnostics: \(failures.prefix(8).joined(separator: " | "))")
    }

    private func testPackageSevenDiagnostic() async throws {
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-007-phase-polarity-stereo-imaging-panning-evaluation")
        let retrieval = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        var failures: [String] = []
        for item in retrieval {
            let diagnosticQuery=item["query"] as? String ?? ""
            guard let query=item["query"] as? String, let expected=item["expected_canonical_ids"] as? [String], expected.count == 1,
                  let ranked=corpus.rank(query: query, filters: .init(packageID: "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning")) else { failures.append("unrankable \(item["id"] ?? "unknown") p7Cards=\(corpus.canonicalCards.filter { $0.packageID == "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning" }.count) exact=\(corpus.exactNormalizedCanonicalIDs(diagnosticQuery))"); continue }
            let forbidden=item["forbidden_canonical_ids"] as? [String] ?? []
            if ranked.card.id != expected[0] || forbidden.contains(ranked.card.id) { failures.append("\(item["id"] ?? "unknown") -> \(ranked.card.id)") }
            if failures.count >= 24 { break }
        }
        for item in supplied {
            guard let query=item["query"] as? String, let expectedTopics=item["expected_topics"] as? [String], !expectedTopics.isEmpty,
                  let ranked=corpus.rank(query: query, filters: .init(packageID: "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning")) else { failures.append("semantic-unrankable \(item["id"] ?? "unknown")"); continue }
            let forbidden=item["forbidden_topics"] as? [String] ?? []
            if !(ranked.card.topic.map { expectedTopics.contains($0) } ?? false) || ranked.card.topic.map({ forbidden.contains($0) }) == true { failures.append("semantic \(item["id"] ?? "unknown") -> \(ranked.card.id)/\(ranked.card.topic ?? "nil")") }
            if failures.count >= 24 { break }
        }
        let p7=corpus.canonicalCards.filter { $0.packageID == "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning" }
        try expect(retrieval.count == 1_980 && supplied.count == 15 && failures.isEmpty,
                   "package-7 migration ranking failures (first \(failures.count)): \(failures.joined(separator: " | "))")
        try expect(scenarios.count == 1_188 && scenarios.allSatisfy { ($0["messages"] as? [[String: Any]])?.count == 6 && ($0["review_state"] as? String) == "candidate_not_yet_human_reviewed" }, "package-7 six-message scenario provenance drifted")
        try expect(accounting["rawPackageUniqueExactCaseCount"] as? Int == 1_980 && accounting["rawPackageNonExactLexicalCaseCount"] as? Int == 0 && accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 1_980 && accounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 0 && (accounting["safetyRedactedExactFixtureIDs"] as? [String])?.isEmpty == true, "package-7 honest exact accounting drifted")
        try expect(p7.count == 396 && p7.allSatisfy { $0.primaryResearchSourceIDs != nil && $0.nonProcessingPossibilities?.isEmpty == false && $0.procedureVerificationStatus == "candidate_unverified_on_installed_logic" }, "package-7 provenance or procedure boundary drifted")
        try testPackageSevenSemanticDiagnostics(corpus)
    }

    private func testPackageEightDiagnostic() async throws {
        let packageID = "tracksmith-corpus-008-editing-layering"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-008-editing-layering-evaluation")
        let retrieval = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let integrity = fixture["integrityCases"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        var failures: [String] = []
        var runtimeUniqueExact = 0
        var runtimeNonExact = 0

        // The imported fixture retains its historical raw/runtime-safe
        // accounting, but P16 moves every equality identity to the separate
        // development index.  This production sweep must therefore treat all
        // 2,100 rows as lexical candidates while preserving their ranking and
        // forbidden-card checks.
        for item in retrieval {
            let identifier = item["id"] as? String ?? "unknown"
            let query = item["query"] as? String ?? ""
            guard let expected = item["expected_canonical_ids"] as? [String], expected.count == 1,
                  let ranked = corpus.rank(query: query, filters: .init(packageID: packageID)) else {
                if failures.count < 24 { failures.append("unrankable \(identifier) p8Cards=\(corpus.canonicalCards.filter { $0.packageID == packageID }.count) exact=\(corpus.exactNormalizedCanonicalIDs(query))") }
                continue
            }
            let isRuntimeUniqueExact = corpus.exactNormalizedCanonicalIDs(query) == expected
            if isRuntimeUniqueExact {
                runtimeUniqueExact += 1
                if ranked.card.id != expected[0], failures.count < 24 { failures.append("exact \(identifier) -> \(ranked.card.id)") }
            } else {
                runtimeNonExact += 1
            }
            if (item["forbidden_canonical_ids"] as? [String] ?? []).contains(ranked.card.id), failures.count < 24 {
                failures.append("forbidden \(identifier) -> \(ranked.card.id)")
            }
        }

        for item in supplied {
            let identifier = item["id"] as? String ?? "unknown"
            guard let query = item["query"] as? String,
                  let expectedDomain = item["expected_domain"] as? String,
                  let expectedSubdomain = item["expected_subdomain"] as? String,
                  let ranked = corpus.rank(query: query, filters: .init(packageID: packageID)) else {
                if failures.count < 24 { failures.append("semantic-unrankable \(identifier)") }
                continue
            }
            if ranked.card.domain != expectedDomain || ranked.card.category != expectedSubdomain, failures.count < 24 {
                failures.append("semantic \(identifier) -> \(ranked.card.id)/\(ranked.card.domain)/\(ranked.card.category)")
            }
        }

        guard let descriptor = corpus.descriptor(packageID) else {
            throw TestFailure(description: "package-8 descriptor missing")
        }
        let p8 = corpus.canonicalCards.filter { $0.packageID == packageID }
        let allowedSourceClasses: Set<String> = ["official_documentation", "primary_research", "professional_practice", "specialist_discussion", "product_documentation", "community_pattern", "community_anecdote"]
        try expect(retrieval.count == 2_100 && supplied.count == 10 && failures.isEmpty,
                   "package-8 migration ranking failures (first \(failures.count)): \(failures.joined(separator: " | "))")
        try expect(runtimeUniqueExact == 0 && runtimeNonExact == 2_100 &&
                   accounting["rawPackageUniqueExactCaseCount"] as? Int == 840 &&
                   accounting["rawPackageNonExactLexicalCaseCount"] as? Int == 1_260 &&
                   accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 840 &&
                   accounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 1_260 &&
                   (accounting["safetyRedactedExactFixtureIDs"] as? [String])?.isEmpty == true,
                   "package-8 historical fixture or P16 production exact-firewall accounting drifted")
        try expect(integrity.count == 5 && integrity.allSatisfy { ($0["id"] as? String)?.hasPrefix("pkg008.integrity.") == true },
                   "package-8 integrity fixture IDs drifted")
        try expect(descriptor.packageSequence == 8 && descriptor.canonicalCount == 420 && descriptor.utteranceCount == 9_240 &&
                   descriptor.scenarioCount == 1_260 && descriptor.retrievalCaseCount == 2_100 &&
                   descriptor.contradictionCount == 46 && descriptor.mythCount == 54,
                   "package-8 descriptor inventory drifted")
        try expect(scenarios.count == 1_260 && scenarios.allSatisfy { ($0["messages"] as? [[String: Any]])?.count == 6 && ($0["review_state"] as? String) == "candidate_not_yet_human_reviewed" },
                   "package-8 scenario provenance drifted")
        try expect(p8.count == 420 && p8.allSatisfy {
            $0.originalReviewStatus == "candidate_not_yet_human_reviewed" &&
            $0.procedureVerificationStatus == "candidate_unverified_on_installed_logic" &&
            Set($0.sourceTypes).subtracting(allowedSourceClasses).isEmpty &&
            !($0.evidenceNeeded ?? []).isEmpty &&
            !(($0.authoritativeSupportingSourceIDs ?? []) + $0.professionalPracticeSourceIDs + $0.discoveryLanguageSourceIDs + ($0.primaryResearchSourceIDs ?? [])).isEmpty
        }, "package-8 candidate/source/procedure boundary drifted")
        try testPackageEightSemanticDiagnostics(corpus)
    }

    private func testPackageNineDiagnostic() async throws {
        let packageID = "tracksmith-corpus-009-gain-staging-bus-processing-loudness"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-009-gain-staging-bus-processing-loudness-evaluation")
        let retrieval = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        let cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-9 descriptor missing") }
        try expect(descriptor.packageSequence == 9 && descriptor.canonicalCount == 430 && descriptor.utteranceCount == 9_460 && descriptor.scenarioCount == 1_290 && descriptor.retrievalCaseCount == 2_150 && descriptor.contradictionCount == 48 && descriptor.mythCount == 56, "package-9 descriptor inventory drifted")
        try expect(retrieval.count == 2_150 && scenarios.count == 1_290 && scenarios.filter { ($0["messages"] as? [[String: Any]])?.count == 4 }.count == 860 && scenarios.filter { ($0["messages"] as? [[String: Any]])?.count == 6 }.count == 430, "package-9 scenario/retrieval distribution drifted")
        try expect(accounting["rawPackageUniqueExactCaseCount"] as? Int == 430 && accounting["rawPackageNonExactLexicalCaseCount"] as? Int == 1_720 && accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 430 && accounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 1_720, "package-9 accounting drifted")
        try expect(cards.count == 430 && cards.allSatisfy { $0.originalReviewStatus == "candidate_not_yet_human_reviewed" && $0.procedureVerificationStatus == "candidate_unverified_on_installed_logic" && $0.numericGuidancePolicy == "contextual_orientation_or_measurement_not_preset" && !($0.standardsSourceIDs ?? []).contains(where: { !$0.hasPrefix("pkg009.source.") }) }, "package-9 candidate/procedure/standards/numeric-policy boundary drifted")
        let metering = cards.filter { ["pkg009.qa.000281", "pkg009.qa.000282", "pkg009.qa.000283"].contains($0.id) }
        try expect(metering.count == 3 && metering.allSatisfy { ($0.standardsSourceIDs ?? []).contains("pkg009.source.000043") }, "EBU Tech 3341 metering receipt drifted")
        try testPackageNineUnfilteredSemanticDiagnostics(corpus)
    }

    private func testPackageTenDiagnostic() async throws {
        let packageID = "tracksmith-corpus-010-flex-time-manual-timing"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-010-flex-time-manual-timing-evaluation")
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let nativeRetrievalCases = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-10 descriptor missing") }
        let p10Cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        let p10Utterances = corpus.utterances.filter { $0.canonicalID.hasPrefix("pkg010.qa.") }
        let exactRows = supplied.filter { ($0["classification"] as? String) == "exact_unique" }
        let diagnosticRows = supplied.filter { ($0["classification"] as? String) != "exact_unique" }
        // Exact-unique P10 fixtures are evaluation-layer migration links, not
        // live runtime exact-index authority: P10 ships no fixture utterances.
        // Build a test-only normalized fixture map and require each declared
        // expected-top-1 row to be uniquely linked to an existing card.
        try expect(exactRows.count == 450 && diagnosticRows.count == 1_800 &&
                   exactRows.allSatisfy { ($0["diagnostic_only"] as? Bool) == false && ($0["expected_top_1"] as? Bool) == true } &&
                   diagnosticRows.allSatisfy { ($0["diagnostic_only"] as? Bool) == true && ($0["expected_top_1"] as? Bool) == false },
                   "package-10 exact/diagnostic classification partition drifted")
        let normalizeFixture: (String) -> String = { value in
            value.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
        }
        var exactFixtureLookup: [String: Set<String>] = [:]
        for item in exactRows {
            guard let query = item["query"] as? String, let canonicalID = item["canonical_qa_id"] as? String else {
                throw TestFailure(description: "package-10 exact fixture shape unreadable")
            }
            exactFixtureLookup[normalizeFixture(query), default: []].insert(canonicalID)
        }
        let exactFixtureLinksValid = exactFixtureLookup.count == 450 && exactFixtureLookup.allSatisfy { _, targets in
            targets.count == 1 && targets.allSatisfy { corpus.card($0)?.packageID == packageID }
        }
        let productionExactLookupIsPure = supplied.allSatisfy {
            guard let query = $0["query"] as? String else { return false }
            return corpus.exactNormalizedCanonicalIDs(query).isEmpty
        }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let productionCorpusSource = try String(contentsOf: root.appendingPathComponent("packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.swift"))
        try expect(exactFixtureLinksValid && productionExactLookupIsPure &&
                   !productionCorpusSource.contains("exactpkg010qa") &&
                   !productionCorpusSource.contains("pkg010.qa."),
                   "package-10 fixture authority leaked into production exact lookup/ranker")
        var failures: [String] = []
        var rankedDiagnostics = 0
        for item in diagnosticRows {
            let id = item["id"] as? String ?? "unknown"
            guard let query = item["query"] as? String,
                  corpus.rank(query: query, filters: .init(packageID: packageID)) != nil else {
                if failures.count < 24 { failures.append("unrankable \(id)") }
                continue
            }
            rankedDiagnostics += 1
        }
        // These queries are separately preserved raw owner-example utterances
        // (`owner_supplied_example_language` / `literal_user_example_preserved`).
        // The retrieval-evaluation rows that exercise them are independently
        // authored derived-synthesis records, so join by query identity rather
        // than overwriting their original evaluation provenance.
        let ownerExampleQueries: Set<String> = [
            "Can I fix just this one note?",
            "Why did Flex make my vocal sound weird?",
            "Make the bass tighter without making it robotic.",
            "This guitar chord comes in too late."
        ]
        let ownerExampleEvaluations = nativeRetrievalCases.filter { ownerExampleQueries.contains($0["query"] as? String ?? "") }
        try expect(supplied.count == 2_250 && rankedDiagnostics == 1_800 && failures.isEmpty,
                   "package-10 diagnostic ranking sweep: \(failures.prefix(16).joined(separator: " | "))")
        try expect(ownerExampleEvaluations.count == 4 && ownerExampleEvaluations.allSatisfy {
            ($0["diagnostic_only"] as? Bool) == true &&
            $0["expected_top_1"] == nil &&
            ($0["retrieval_expectation"] as? String) == "diagnostic_only" &&
            ["diagnostic_semantic_only", "diagnostic_multi_intent", "diagnostic_cross_domain_collision", "diagnostic_low_margin"].contains($0["retrieval_classification"] as? String ?? "") &&
            ($0["original_review_state"] as? String) == "derived_synthesis" &&
            ($0["original_verification_status"] as? String) == "source_span_or_documentary_metadata_registered"
        }, "package-10 owner examples must remain diagnostic-only without replacing evaluation provenance")
        try expect(descriptor.packageSequence == 10 && descriptor.canonicalCount == 450 && descriptor.utteranceCount == 10_350 && descriptor.scenarioCount == 1_350 && descriptor.retrievalCaseCount == 2_250 && descriptor.contradictionCount == 48 && descriptor.mythCount == 56 && descriptor.runtimeCanonicalOnly, "package-10 descriptor/raw-runtime separation drifted")
        try expect(p10Cards.count == 450 && p10Utterances.isEmpty && p10Cards.allSatisfy { $0.procedureCandidateID == nil && $0.procedureVerificationStatus == nil && $0.contradictions.isEmpty && $0.myths.isEmpty } && scenarios.count == 1_350 && scenarios.allSatisfy { ($0["messages"] as? [[String: Any]])?.count == 6 }, "package-10 canonical-only runtime/scenario boundary drifted")
        let classes = accounting["classificationCounts"] as? [String: Int] ?? [:]
        try expect(classes == ["exact_unique": 450, "diagnostic_semantic_only": 450, "diagnostic_multi_intent": 450, "diagnostic_cross_domain_collision": 450, "diagnostic_low_margin": 450] && accounting["rawPackageUniqueExactCaseCount"] as? Int == 450 && accounting["rawPackageNonExactLexicalCaseCount"] as? Int == 1_800 && accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 0 && accounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 2_250 && accounting["runtimeCarriesNoTestUtterances"] as? Bool == true, "package-10 classification/runtime accounting drifted")
        try testPackageTenUnfilteredSemanticDiagnostics(corpus)
        try testRecordedAudioMIDITimingDomainCue(corpus)
    }

    private func testPackageElevenDiagnostic() async throws {
        let packageID = "tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping-evaluation")
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let evaluation = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-11 descriptor missing") }
        let cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        let utterances = corpus.utterances.filter { $0.canonicalID.hasPrefix("pkg011.qa.") }
        let exact = supplied.filter { ($0["classification"] as? String) == "exact_unique" }
        let diagnostic = supplied.filter { ($0["classification"] as? String) != "exact_unique" }
        let fixtureKeys = Set(supplied.compactMap { row -> String? in guard let query=row["query"] as? String, let target=row["canonical_qa_id"] as? String, let kind=row["classification"] as? String else { return nil }; return "\(query)\u{1F}\(target)\u{1F}\(kind)" })
        let evaluationKeys = Set(evaluation.compactMap { row -> String? in guard let query=row["query"] as? String, let target=row["canonical_qa_id"] as? String, let kind=row["retrieval_classification"] as? String else { return nil }; return "\(query)\u{1F}\(target)\u{1F}\(kind)" })
        var diagnosticFailures: [String] = []
        var rankedDiagnostics = 0
        for row in diagnostic {
            let id = row["id"] as? String ?? "unknown"
            guard let query = row["query"] as? String,
                  corpus.rank(query: query, filters: .init(packageID: packageID)) != nil else {
                if diagnosticFailures.count < 24 { diagnosticFailures.append("unrankable \(id)") }
                continue
            }
            rankedDiagnostics += 1
        }
        try expect(descriptor.packageSequence == 11 && descriptor.runtimeCanonicalOnly && cards.count == 450 && utterances.isEmpty && cards.allSatisfy { $0.procedureCandidateID == nil && $0.contradictions.isEmpty && $0.myths.isEmpty }, "package-11 canonical-only runtime boundary drifted")
        try expect(exact.count == 450 && diagnostic.count == 1_800 && fixtureKeys.count == 2_250 && fixtureKeys == evaluationKeys && exact.allSatisfy { ($0["diagnostic_only"] as? Bool) == false && ($0["expected_top_1"] as? Bool) == true } && diagnostic.allSatisfy { ($0["diagnostic_only"] as? Bool) == true && ($0["expected_top_1"] as? Bool) == false }, "package-11 fixture bijection/classification drifted")
        try expect(rankedDiagnostics == 1_800 && diagnosticFailures.isEmpty, "package-11 diagnostic ranking sweep: \(diagnosticFailures.joined(separator: " | "))")
        try expect(accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 0 && accounting["runtimeCarriesNoTestUtterances"] as? Bool == true && scenarios.count == 1_350, "package-11 test-only exact/runtime accounting drifted")
        let productionSource = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.swift"))
        try expect(!productionSource.contains("exactpkg011qa") && supplied.allSatisfy { corpus.exactNormalizedCanonicalIDs($0["query"] as? String ?? "").isEmpty }, "package-11 test-only fixtures leaked into production exact lookup")
        try testPackageElevenUnindexedDiagnostics(corpus)
    }

    private func testPackageTwelveDiagnostic() async throws {
        let packageID = "tracksmith-corpus-012-recording-latency-monitoring-comping-punch"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-012-recording-latency-monitoring-comping-punch-evaluation")
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let evaluation = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-12 descriptor missing") }
        let cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        let utterances = corpus.utterances.filter { $0.canonicalID.hasPrefix("pkg012.qa.") }
        func key(_ row: [String: Any], _ classification: String) -> String? {
            guard let query = row["query"] as? String, let target = row["canonical_qa_id"] as? String else { return nil }
            return "\(query)\u{1F}\(target)\u{1F}\(classification)"
        }
        let testOnlyExactMap = Dictionary(uniqueKeysWithValues: supplied.compactMap { row -> (String, String)? in
            guard let query = row["query"] as? String, let target = row["canonical_qa_id"] as? String else { return nil }
            return (query, target)
        })
        let exactEvaluation = evaluation.filter { ($0["retrieval_classification"] as? String) == "exact_unique" }
        let exactKeys = Set(exactEvaluation.compactMap { key($0, "exact_unique") })
        let fixtureKeys = Set(supplied.compactMap { key($0, $0["classification"] as? String ?? "") })
        let classifications = Dictionary(grouping: evaluation, by: { $0["retrieval_classification"] as? String ?? "" }).mapValues(\.count)
        try expect(descriptor.packageSequence == 12 && descriptor.runtimeCanonicalOnly && descriptor.runtimeStatusFree && corpus.descriptor("tracksmith-corpus-010-flex-time-manual-timing")?.runtimeStatusFree == false && corpus.descriptor("tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping")?.runtimeStatusFree == false && descriptor.canonicalCount == 480 && descriptor.utteranceCount == 11_040 && descriptor.scenarioCount == 1_440 && descriptor.retrievalCaseCount == 2_400 && descriptor.contradictionCount == 52 && descriptor.mythCount == 64, "package-12 descriptor/raw-runtime separation drifted")
        let runtimeURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("research/community_knowledge/runtime_projection/p16/\(packageID).json")
        let runtimeValue = try JSONSerialization.jsonObject(with: Data(contentsOf: runtimeURL))
        func containsRuntimeStatusKey(_ value: Any) -> Bool {
            if let object = value as? [String: Any] {
                return object.contains { pair in
                    let normalized = pair.key.lowercased().replacingOccurrences(of: "-", with: "_")
                    return ["review", "status", "verification", "eligibility"].contains(where: { normalized.contains($0) }) || containsRuntimeStatusKey(pair.value)
                }
            }
            if let list = value as? [Any] { return list.contains(where: containsRuntimeStatusKey) }
            return false
        }
        try expect(cards.count == 480 && utterances.isEmpty && cards.allSatisfy { $0.originalReviewStatus == nil && $0.procedureCandidateID == nil && $0.procedureVerificationStatus == nil && $0.contradictions.isEmpty && $0.myths.isEmpty } && !containsRuntimeStatusKey(runtimeValue), "package-12 runtime carries candidate procedure/disagreement/status state")
        let payloadArguments = try String(data: JSONSerialization.data(withJSONObject: ["query": cards[0].question, "package_id": packageID], options: [.sortedKeys]), encoding: .utf8) ?? "{}"
        let toolResult = try await TutorToolExecutor().execute(TutorToolCall(callID: "pkg012-status-free", name: "search_candidate_corpus", argumentsJSON: payloadArguments), context: TutorRuntimeContext(sourceType: .vocal))
        let toolOutput = try JSONSerialization.jsonObject(with: Data(toolResult.outputJSON.utf8)) as? [String: Any]
        let toolMatch = toolOutput?["match"] as? [String: Any]
        let forbiddenLiveLabels = toolMatch?.keys.filter { key in ["status", "procedure", "authority"].contains(where: { key.lowercased().contains($0) }) } ?? []
        try expect(toolMatch != nil && forbiddenLiveLabels.isEmpty, "package-12 live candidate payload leaked status/procedure/authority labels: \(forbiddenLiveLabels)")
        try expect(supplied.count == 480 && testOnlyExactMap.count == 480 && fixtureKeys == exactKeys && supplied.allSatisfy { ($0["classification"] as? String) == "exact_unique" && ($0["diagnostic_only"] as? Bool) == false && ($0["expected_top_1"] as? Bool) == true }, "package-12 exact-subset fixture linkage drifted")
        try expect(classifications == ["exact_unique": 480, "diagnostic_semantic_only": 480, "diagnostic_multi_intent": 480, "diagnostic_cross_domain_collision": 480, "diagnostic_low_margin": 480] && accounting["classifiedExpectedTop1Count"] as? Int == 480 && accounting["classifiedDiagnosticOnlyCount"] as? Int == 1_920 && accounting["rawNormalizedUniqueMatchCount"] as? Int == 944 && accounting["rawNormalizedNonMatchCount"] as? Int == 1_456 && accounting["diagnosticNormalizedExactCollisionCount"] as? Int == 464 && (accounting["diagnosticNormalizedExactByClassification"] as? [String: Int]) == ["exact_unique": 480, "diagnostic_semantic_only": 464, "diagnostic_multi_intent": 0, "diagnostic_cross_domain_collision": 0, "diagnostic_low_margin": 0] && accounting["runtimeNormalizedUniqueMatchCount"] as? Int == 0 && accounting["runtimeNormalizedNonMatchCount"] as? Int == 2_400 && accounting["runtimeCarriesNoTestUtterances"] as? Bool == true && scenarios.count == 1_440, "package-12 two-axis fixture/runtime accounting drifted")
        let productionSource = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.swift"))
        try expect(!productionSource.contains("exactpkg012qa") && testOnlyExactMap.allSatisfy { pair in pair.value.hasPrefix("pkg012.qa.") && corpus.exactNormalizedCanonicalIDs(pair.key).isEmpty }, "package-12 test-only exact aliases leaked into production lookup")
        let collisionAliases = ["latency", "recording late", "cannot hear microphone", "voice twice", "microphone left side", "combine takes", "changed my comp", "record one word", "two bars before recording", "replace recording"]
        try expect(collisionAliases.allSatisfy { corpus.exactNormalizedCanonicalIDs($0).isEmpty }, "package-12 collision aliases leaked into production exact lookup")
        try testPackageTwelveUnindexedDiagnostics(corpus, collisionAliases: collisionAliases)
    }

    private func testPackageThirteenDiagnostic() async throws {
        let packageID = "tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes-evaluation")
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let evaluation = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-13 descriptor missing") }
        let cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        let utterances = corpus.utterances.filter { $0.canonicalID.hasPrefix("pkg013.qa.") }
        let exact = evaluation.filter { ($0["retrieval_classification"] as? String) == "exact_unique" }
        let diagnostics = evaluation.filter { ($0["retrieval_classification"] as? String) != "exact_unique" }
        let classifications = Dictionary(grouping: evaluation, by: { $0["retrieval_classification"] as? String ?? "" }).mapValues(\.count)
        let testOnlyExactMap = Dictionary(uniqueKeysWithValues: supplied.compactMap { row -> (String, String)? in
            guard let query = row["query"] as? String, let target = row["canonical_qa_id"] as? String else { return nil }
            return (query, target)
        })
        let runtimeURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("research/community_knowledge/runtime_projection/p16/\(packageID).json")
        let runtimeValue = try JSONSerialization.jsonObject(with: Data(contentsOf: runtimeURL))
        let forbiddenRuntimeFragments = ["review", "status", "verification", "eligibility", "procedure", "navigation", "evaluation", "scenario", "sqlite", "test", "expected", "authority"]
        func excludedRuntimeKeys(_ value: Any) -> [String] {
            if let object = value as? [String: Any] {
                return object.flatMap { key, child in
                    let own = forbiddenRuntimeFragments.contains(where: { key.lowercased().contains($0) }) ? [key] : []
                    return own + excludedRuntimeKeys(child)
                }
            }
            if let list = value as? [Any] { return list.flatMap(excludedRuntimeKeys) }
            return []
        }
        try expect(descriptor.packageSequence == 13 && descriptor.runtimeCanonicalOnly && descriptor.runtimeStatusFree && descriptor.canonicalCount == 480 && descriptor.utteranceCount == 11_040 && descriptor.scenarioCount == 1_440 && descriptor.retrievalCaseCount == 2_400 && descriptor.contradictionCount == 52 && descriptor.mythCount == 64, "package-13 descriptor/runtime boundary drifted")
        try expect(cards.count == 480 && utterances.isEmpty && cards.allSatisfy { $0.originalReviewStatus == nil && $0.procedureCandidateID == nil && $0.procedureVerificationStatus == nil && $0.authoritativeSupportingSourceIDs == nil && $0.contradictions.isEmpty && $0.myths.isEmpty } && excludedRuntimeKeys(runtimeValue).isEmpty, "package-13 runtime leaked status/procedure/authority or fixture fields")
        try expect(supplied.count == 480 && testOnlyExactMap.count == 480 && exact.count == 480 && supplied.allSatisfy { ($0["classification"] as? String) == "exact_unique" && ($0["diagnostic_only"] as? Bool) == false && ($0["expected_top_1"] as? Bool) == true }, "package-13 exact test subset drifted")
        try expect(classifications == ["exact_unique": 480, "diagnostic_semantic_only": 480, "diagnostic_multi_intent": 480, "diagnostic_cross_domain_collision": 480, "diagnostic_low_margin": 480] && diagnostics.count == 1_920 && diagnostics.allSatisfy { ($0["diagnostic_only"] as? Bool) == true && ($0["retrieval_expectation"] as? String) == "diagnostic_only" } && exact.allSatisfy { ($0["retrieval_expectation"] as? String) == "expected_top_1" } && accounting["classifiedExpectedTop1Count"] as? Int == 480 && accounting["classifiedDiagnosticOnlyCount"] as? Int == 1_920 && accounting["rawNormalizedUniqueMatchCount"] as? Int == 952 && accounting["rawNormalizedNonMatchCount"] as? Int == 1_448 && accounting["diagnosticNormalizedExactCollisionCount"] as? Int == 472 && (accounting["diagnosticNormalizedExactByClassification"] as? [String: Int]) == ["exact_unique": 480, "diagnostic_semantic_only": 472, "diagnostic_multi_intent": 0, "diagnostic_cross_domain_collision": 0, "diagnostic_low_margin": 0] && accounting["runtimeNormalizedUniqueMatchCount"] as? Int == 0 && accounting["runtimeNormalizedNonMatchCount"] as? Int == 2_400 && scenarios.count == 1_440, "package-13 two-axis exact/diagnostic accounting drifted")
        let productionSource = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.swift"))
        try expect(!productionSource.contains("exactpkg013qa") && testOnlyExactMap.allSatisfy { pair in pair.value.hasPrefix("pkg013.qa.") && corpus.exactNormalizedCanonicalIDs(pair.key).isEmpty } && diagnostics.allSatisfy { corpus.exactNormalizedCanonicalIDs($0["query"] as? String ?? "").isEmpty }, "package-13 fixtures leaked into production exact lookup")
        let suppliedAliases = ["sends routing", "bus routing", "creating routing", "send routing", "post-pan routing", "post-fader routing", "pre-fader routing", "shared routing", "wet/dry routing", "effect-return routing"]
        let diagnosticQueries = Set(diagnostics.compactMap { $0["query"] as? String })
        try expect(Set(suppliedAliases).isSubset(of: diagnosticQueries) && suppliedAliases.allSatisfy { corpus.exactNormalizedCanonicalIDs($0).isEmpty }, "package-13 supplied diagnostic aliases became production exact matches")
        let requiredCategories = ["sends_vs_inserts", "source_send_vs_return_automation", "wet_dry_aux_return", "pre_fader_sends", "post_fader_sends", "post_pan_sends", "multiple_tracks_one_effect", "parallel_compression_send", "bus_aux_signal_path", "track_stack_vs_aux_subgroup", "folder_vs_summing", "vca_vs_aux_subgroup", "group_editing", "headphone_cue_mix"]
        try expect(requiredCategories.allSatisfy { category in cards.filter { $0.category == category }.count == 10 }, "package-13 routing/grouping distinction coverage drifted")
        let policySource = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/TutorConversation/Sources/TutorConversation/TutorSystemPolicy.swift"))
        let policyTerms = ["Candidate corpus material is provisional", "one bounded, user-performed, reversible experiment", "stop condition", "undo"]
        try expect(policyTerms.allSatisfy(policySource.contains), "package-13 provider distinction/one-experiment policy drifted")
        let unfilteredCollisions: [(String, Set<String>)] = [
            ("Should this shared reverb be an insert on one vocal or a send for several vocals?", ["reverb", "delay", "sends_buses_auxes_shared_effects"]),
            ("Should the drum bus compressor sit on a subgroup rather than a shared aux return?", ["bus_processing", "sends_buses_auxes_shared_effects"]),
            ("Does a performer headphone cue need a separate balance from the main mix?", ["recording_latency_monitoring_delay", "input_monitoring_record_enable_signal_flow", "sends_buses_auxes_shared_effects"]),
        ]
        var collisionFailures: [String] = []
        for (query, allowedDomains) in unfilteredCollisions {
            guard corpus.exactNormalizedCanonicalIDs(query).isEmpty, let ranked = corpus.rank(query: query) else { collisionFailures.append("unrankable \(query)"); continue }
            if !allowedDomains.contains(ranked.card.domain) { collisionFailures.append("\(query) -> \(ranked.card.domain)") }
        }
        try expect(collisionFailures.isEmpty, "package-13 unfiltered P4/P9/P12 collision coverage: \(collisionFailures.joined(separator: " | "))")
    }

    private func testPackageFourRoutingRegression() async throws {
        let corpus = try CommunityCandidateCorpus.loadValidated()
        guard let descriptor = corpus.descriptor("community-reverb-delay-v1"),
              let ranked = corpus.rank(query: "When should I use delay instead of reverb?", filters: .init(packageID: "community-reverb-delay-v1")) else {
            throw TestFailure(description: "package-4 reverb/delay regression could not rank")
        }
        try expect(descriptor.packageSequence == 4 && ranked.card.packageID == descriptor.packageID && ranked.card.domain == "delay", "package-4 effect-choice regression drifted: \(ranked.card.packageID)/\(ranked.card.domain)")
    }

    private func testPackageFifteenDiagnostic() async throws {
        let packageID = "tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model-evaluation")
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-15 descriptor missing") }
        let evaluation = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        let cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        let runtimeURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("research/community_knowledge/runtime_projection/p16/\(packageID).json")
        let runtime = try JSONSerialization.jsonObject(with: Data(contentsOf: runtimeURL))
        let forbidden = ["review", "status", "verification", "eligibility", "procedure", "navigation", "evaluation", "scenario", "sqlite", "test", "expected", "authority"]
        func forbiddenKeys(_ value: Any) -> [String] {
            if let object = value as? [String: Any] { return object.flatMap { key, child in (forbidden.contains { key.lowercased().contains($0) } ? [key] : []) + forbiddenKeys(child) } }
            if let list = value as? [Any] { return list.flatMap(forbiddenKeys) }
            return []
        }
        let testOnlyExactMap = Dictionary(uniqueKeysWithValues: supplied.compactMap { row -> (String, String)? in
            guard let query = row["query"] as? String, let target = row["canonical_qa_id"] as? String else { return nil }; return (query, target)
        })
        let classifications = Dictionary(grouping: evaluation, by: { $0["retrieval_classification"] as? String ?? "" }).mapValues(\.count)
        try expect(descriptor.packageSequence == 15 && descriptor.runtimeCanonicalOnly && descriptor.runtimeStatusFree && descriptor.canonicalCount == 720 && descriptor.utteranceCount == 16_560 && descriptor.scenarioCount == 2_160 && descriptor.retrievalCaseCount == 3_600 && descriptor.contradictionCount == 72 && descriptor.mythCount == 84, "package-15 descriptor boundary drifted")
        try expect(cards.count == 720 && corpus.utterances.filter { $0.canonicalID.hasPrefix("pkg015.qa.") }.isEmpty && cards.allSatisfy { $0.originalReviewStatus == nil && $0.procedureCandidateID == nil && $0.procedureVerificationStatus == nil && $0.authoritativeSupportingSourceIDs == nil && $0.contradictions.isEmpty && $0.myths.isEmpty } && forbiddenKeys(runtime).isEmpty, "package-15 runtime purity/status boundary drifted")
        let cardIDs = Set(cards.map(\.id))
        try expect(supplied.count == 720 && testOnlyExactMap.count == 720 && testOnlyExactMap.values.allSatisfy(cardIDs.contains) && supplied.allSatisfy { ($0["classification"] as? String) == "exact_unique" && ($0["expected_top_1"] as? Bool) == true && ($0["diagnostic_only"] as? Bool) == false } && testOnlyExactMap.allSatisfy { corpus.exactNormalizedCanonicalIDs($0.key).isEmpty } && evaluation.count == 3_600 && evaluation.allSatisfy { corpus.exactNormalizedCanonicalIDs($0["query"] as? String ?? "").isEmpty }, "package-15 test-only exact map or production miss boundary drifted")
        try expect(classifications == ["exact_unique": 720, "diagnostic_semantic_only": 720, "diagnostic_multi_intent": 720, "diagnostic_cross_domain_collision": 720, "diagnostic_low_margin": 720] && scenarios.count == 2_160 && accounting["classifiedExpectedTop1Count"] as? Int == 720 && accounting["classifiedDiagnosticOnlyCount"] as? Int == 2_880 && accounting["rawNormalizedUniqueMatchCount"] as? Int == 1_440 && accounting["rawNormalizedNonMatchCount"] as? Int == 2_160 && accounting["runtimeNormalizedUniqueMatchCount"] as? Int == 0 && accounting["runtimeNormalizedNonMatchCount"] as? Int == 3_600, "package-15 accounting drifted")
        let aliases = ["sustain", "instrument gets quieter", "move notes", "bounce", "freeze", "latency", "duplicate region", "delete recording"]
        try expect(aliases.allSatisfy { corpus.exactNormalizedCanonicalIDs($0).isEmpty }, "package-15 aliases became production exact matches")
        let providerURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/TutorConversation/Sources/TutorConversation/TutorSystemPolicy.swift")
        let provider = try String(contentsOf: providerURL)
        let rankerURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.swift")
        let rankerSource = try String(contentsOf: rankerURL)
        let policy = ["Candidate corpus material is provisional", "one bounded, user-performed, reversible experiment", "stop condition", "undo"]
        try expect(!rankerSource.contains("exactpkg015qa") && policy.allSatisfy(provider.contains), "package-15 provider policy or decoder boundary drifted")
        let rawURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("research/community_knowledge/packages/\(packageID)/knowledge_candidates/strategies.jsonl")
        let strategies = try String(contentsOf: rawURL).split(separator: "\n").compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
        try expect(strategies.count == 720 && Set(strategies.compactMap { $0["canonical_qa_id"] as? String }).count == 720 && strategies.allSatisfy { (($0["stop_rule"] as? String) ?? "").isEmpty == false }, "package-15 strategy-derived stop coverage drifted")
        struct DiagnosticCase {
            let label: String
            let query: String
            let allowedDomains: Set<String>
            let allowedFamilies: Set<String>
            let forbiddenDomains: Set<String>
        }
        // One independently authored, deliberately unindexed query per frozen
        // distinction. These admit only overlapping domain/category families,
        // never a canonical ID or package-specific ranker exception.
        let bounded: [DiagnosticCase] = [
            .init(label: "notes versus controllers", query: "Before editing this MIDI passage, is the selected event a note or a controller event?", allowedDomains: ["midi_cc_sustain_expression", "piano_roll_precise_editing", "midi_transform_humanize_batch_editing"], allowedFamilies: [], forbiddenDomains: ["reverb", "delay", "loudness"]),
            .init(label: "CC64 versus duration", query: "Is the held sound caused by sustain CC64 data or by the note's written duration?", allowedDomains: ["midi_cc_sustain_expression", "midi_quantization_groove"], allowedFamilies: [], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "CC11 CC7 automation", query: "Is CC11 expression, CC7 volume, or track automation making this software instrument quieter?", allowedDomains: ["midi_cc_sustain_expression", "volume_pan_plugin_automation", "gain_staging"], allowedFamilies: ["automation/fundamentals"], forbiddenDomains: ["delay", "reverb"]),
            .init(label: "pitch bend versus pitch", query: "Is this pitch change MIDI pitch-bend data or the note pitch itself?", allowedDomains: ["midi_cc_sustain_expression", "piano_roll_precise_editing", "midi_transform_humanize_batch_editing"], allowedFamilies: [], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "region MIDI versus automation", query: "Does this change belong to MIDI data inside the region, or to track or plug-in automation?", allowedDomains: ["midi_cc_sustain_expression", "piano_roll_precise_editing", "volume_pan_plugin_automation", "automation"], allowedFamilies: ["automation/fundamentals"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "relative versus absolute snap", query: "When I move these selected MIDI notes, should snapping be relative or absolute?", allowedDomains: ["piano_roll_precise_editing", "midi_quantization_groove", "quantization_and_timing"], allowedFamilies: ["quantization_and_timing/midi_quantization"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "Smart Snap versus grid", query: "In Logic Piano Roll editing, is Smart Snap different from a fixed editing grid for this selected MIDI region?", allowedDomains: ["piano_roll_precise_editing", "midi_quantization_groove", "quantization_and_timing"], allowedFamilies: ["quantization_and_timing/midi_quantization"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "drag nudge numeric", query: "Should I move selected MIDI notes by dragging, nudging, or entering a numerical position?", allowedDomains: ["piano_roll_precise_editing", "midi_quantization_groove", "quantization_and_timing"], allowedFamilies: ["quantization_and_timing/midi_quantization"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "bounce BIP export", query: "Should this finished project use project bounce, Bounce in Place, or track export?", allowedDomains: ["bounce_export_stems", "freeze_cpu_management"], allowedFamilies: [], forbiddenDomains: ["midi_velocity_musical_dynamics", "reverb"]),
            .init(label: "tracks versus stems", query: "Should I export individual tracks or intentional stems for the mix handoff?", allowedDomains: ["bounce_export_stems"], allowedFamilies: [], forbiddenDomains: ["freeze_cpu_management", "reverb"]),
            .init(label: "Freeze versus BIP", query: "Should I Freeze this instrument to save CPU or Bounce in Place for an editable audio result?", allowedDomains: ["freeze_cpu_management", "bounce_export_stems"], allowedFamilies: [], forbiddenDomains: ["midi_velocity_musical_dynamics", "reverb"]),
            .init(label: "CPU versus disk", query: "Is this playback overload caused by CPU processing or by disk streaming?", allowedDomains: ["freeze_cpu_management", "plugin_delay_low_latency"], allowedFamilies: [], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "PDC monitoring Recording Delay", query: "Is this PDC playback alignment, monitoring latency, or a Recording Delay offset?", allowedDomains: ["plugin_delay_low_latency", "recording_latency_monitoring_delay"], allowedFamilies: ["plugin_delay_low_latency/pdc_vs_recording_delay"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "Low Latency versus bypass", query: "While software-monitoring a record-enabled instrument through a latency-causing plug-in, does Logic Low Latency Mode temporarily protect monitoring without permanently bypassing the insert?", allowedDomains: ["plugin_delay_low_latency", "recording_latency_monitoring_delay"], allowedFamilies: ["plugin_delay_low_latency/pdc_vs_recording_delay"], forbiddenDomains: ["reverb", "delay"]),
            // P13's subgroup-via-aux family is the narrow documented adjacent
            // owner-space distinction between Tracks-area structure and Mixer
            // routing; it is not an ID or package-level ranker exception.
            .init(label: "track versus channel strip", query: "For one ordinary Software Instrument track, not a VCA, aux, bus, subgroup, or stack, is its Arrange track header a separate object from that same track's paired Mixer channel strip with its fader and insert slots?", allowedDomains: ["logic_object_model", "volume_pan_plugin_automation", "sends_buses_auxes_shared_effects"], allowedFamilies: ["automation/fundamentals", "track_stacks_groups_submixes/subgroup_via_aux"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "region versus file", query: "Is this selected region different from the underlying audio file it references?", allowedDomains: ["logic_object_model", "editing"], allowedFamilies: ["editing/nondestructive_editing_workflow"], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "MIDI region versus instrument", query: "Is this Piano Roll MIDI region only note/controller data, distinct from the Software Instrument channel strip that generates its sound?", allowedDomains: ["logic_object_model", "midi_cc_sustain_expression", "piano_roll_precise_editing"], allowedFamilies: [], forbiddenDomains: ["reverb", "delay"]),
            .init(label: "copy versus alias", query: "Is this duplicated region an independent copy, an alias, or another linked object?", allowedDomains: ["logic_object_model", "editing_layering"], allowedFamilies: ["editing/nondestructive_editing_workflow"], forbiddenDomains: ["saturation_harmonic_distortion", "reverb"]),
            .init(label: "nondestructive versus file edit", query: "Is this a nondestructive arrangement edit, or would it destructively change the source audio file?", allowedDomains: ["logic_object_model", "editing"], allowedFamilies: ["editing/nondestructive_editing_workflow"], forbiddenDomains: ["reverb", "delay"])
        ]
        try expect(bounded.count == 19 && Set(bounded.map(\.label)).count == 19 && bounded.map(\.query).allSatisfy { corpus.exactNormalizedCanonicalIDs($0).isEmpty }, "package-15 frozen diagnostics must be 19 independent production-unindexed queries")
        var failures: [String] = []
        for item in bounded {
            guard let result = corpus.rank(query: item.query, filters: .init()) else { failures.append("unrankable \(item.label)"); continue }
            let family = "\(result.card.domain)/\(result.card.category)"
            if item.forbiddenDomains.contains(result.card.domain) || (!item.allowedDomains.contains(result.card.domain) && !item.allowedFamilies.contains(family)) { failures.append("\(item.label) -> \(family)") }
        }
        try expect(failures.isEmpty, "package-15 bounded cross-package diagnostics: \(failures.joined(separator: " | "))")
    }

    private func testPackageSixteenDiagnostic() async throws {
        let corpus = try CommunityCandidateCorpus.loadValidated()
        try expect(corpus.descriptors.count == 15 && corpus.canonicalCards.count == 6_212,
                   "P16 selected overlay card count drifted")
        for descriptor in corpus.descriptors {
            let cards = corpus.canonicalCards.filter { $0.packageID == descriptor.packageID }
            for (index, _) in cards.enumerated() {
                let fixture = "TrackSmith exact Package \(String(format: "%03d", descriptor.packageSequence)) reference exactpkg\(String(format: "%03d", descriptor.packageSequence))qa\(String(format: "%06d", index + 1))"
                try expect(corpus.exactNormalizedCanonicalIDs(fixture).isEmpty,
                           "production exact fixture authority leaked for \(descriptor.packageID)")
            }
        }
        try expect(corpus.exactNormalizedCanonicalIDs("automation").isEmpty &&
                   corpus.exactNormalizedCanonicalIDs("latency").isEmpty &&
                   corpus.rank(query: "vocal muddy full mix").map { _ in true } == true,
                   "P16 exact firewall or ordinary lexical retrieval drifted")
        let result = try await TutorToolExecutor().execute(TutorToolCall(
            callID: "p16-bounded", name: "search_candidate_corpus",
            argumentsJSON: #"{"query":"my vocal is muddy in the full mix","goal":"keep the lead audible","prior_experiment":"EQ made it thinner","evidence":"solo is clearer"}"#
        ), context: TutorRuntimeContext(sourceType: .vocal))
        let output = try JSONSerialization.jsonObject(with: Data(result.outputJSON.utf8)) as? [String: Any] ?? [:]
        let matches = output["matches"] as? [[String: Any]] ?? []
        let provenance = result.evidence.first?.candidateCorpusProvenance
        let packageIDs = (provenance?.selectedRecordIDs ?? []).compactMap { corpus.card($0)?.packageID }
        let domains = matches.compactMap { $0["domain"] as? String }
        let sourceIDs = provenance?.sourceIDs ?? []
        try expect(matches.count >= 1 && matches.count <= 4 &&
                   Dictionary(grouping: packageIDs, by: { $0 }).values.allSatisfy { $0.count <= 2 } &&
                   Dictionary(grouping: domains, by: { $0 }).values.allSatisfy { $0.count <= 2 } &&
                   sourceIDs.count <= 6 && Set(sourceIDs).count == sourceIDs.count &&
                   result.outputJSON.utf8.count <= 16 * 1_024,
                   "P16 aggregate diversity/source/context budget drifted")
        // Keep the focused P16 failure diagnostic: these are independent
        // persistence/purity guarantees, and reporting all mismatches avoids
        // a repair loop that could accidentally weaken the firewall.
        var receiptPurityFailures: [String] = []
        if output["candidate_receipt"] != nil { receiptPurityFailures.append("model_receipt_leaked") }
        // P16 preserves its projection and receipt boundary while Package 018
        // replaces only the runtime reader/ranking policy.
        if provenance?.policyVersion != "package019-bm25-ordered6-domain-diverse/1" {
            receiptPurityFailures.append("policy_version")
        }
        if provenance?.retrievalID?.count != 64 {
            receiptPurityFailures.append("retrieval_id_length")
        }
        if provenance?.querySHA256?.count != 64 {
            receiptPurityFailures.append("query_sha256_length")
        }
        if provenance?.resultSHA256?.count != 64 || provenance?.selectedRecordIDs?.count ?? 0 > 4 {
            receiptPurityFailures.append("receipt_fields")
        }
        let lowercasedOutput = result.outputJSON.lowercased()
        for forbidden in ["sqlite", "candidate_receipt", "procedure_candidate", "canonical_id", "package_id", "package_version", "package_sequence", "expected_", "evaluation_", "record_id"] where lowercasedOutput.contains(forbidden) { receiptPurityFailures.append("output_contains_\(forbidden)") }
        if lowercasedOutput.contains("logic_pro_steps") { receiptPurityFailures.append("output_contains_logic_pro_steps") }
        try expect(receiptPurityFailures.isEmpty,
                   "P16 receipt or runtime purity boundary drifted: \(receiptPurityFailures.joined(separator: ", "))")
        print("P16_RECEIPT_OK contextBytes=\(result.outputJSON.utf8.count) matches=\(matches.count) sources=\(sourceIDs.count) retrievalID=\(provenance?.retrievalID ?? "nil") querySHA256=\(provenance?.querySHA256 ?? "nil") outputHash=\(provenance?.resultSHA256 ?? "nil")")
    }

    private func testPackageEighteenIndexReadiness() async throws {
        let started = Date()
        let opened = CandidateRetrievalIndex.openBundled()
        let milliseconds = Date().timeIntervalSince(started) * 1_000
        try expect(opened.availability == .ready, "P18 immutable index readiness was \(opened.availability.rawValue)")
        print("P18_INDEX_READINESS_OK milliseconds=\(String(format: "%.3f", milliseconds))")
    }

    private func testPackageEighteenLegacyReadiness() async throws {
        let started = Date()
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let milliseconds = Date().timeIntervalSince(started) * 1_000
        try expect(corpus.canonicalCards.count == 6_212, "P18 legacy baseline card count drifted")
        print("P18_LEGACY_READINESS_OK milliseconds=\(String(format: "%.3f", milliseconds))")
    }

    private func testPackageNineteenDiagnostic() async throws {
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let promptOnly = try packageNineteenCloudPrompts(repository: repository)
        let canonicalPrompts = try packageSeventeenAcceptancePrompts(repository: repository)
        try expect(promptOnly.map { "\($0.topic)|\($0.query)" } == canonicalPrompts.map { "\($0.topic)|\($0.query)" },
                   "P19 prompt-only generation suite no longer matches the evaluation-only canonical prompt projection")
        let suiteURL = repository
            .appendingPathComponent("research/tutor_quality/package019_evaluation_suite.json")
        let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: suiteURL)) as? [[String: Any]] ?? []
        try expect(rows.count == 240 && Set(rows.compactMap { $0["partition"] as? String }) == Set(["development", "calibration", "held_out"]),
                   "P19 frozen suite was not available to the evaluation-only diagnostic")
        let contexts = rows.compactMap { $0["context_matrix"] as? [String: String] }
        let requiredIndexContexts: Set<String> = ["ready", "missing", "corrupt", "disabled", "version_mismatch", "query_failed", "malformed_selected_payload"]
        try expect(requiredIndexContexts.isSubset(of: Set(contexts.compactMap { $0["candidate_index"] }))
                   && Set(["available", "unavailable", "not_requested"]).isSubset(of: Set(contexts.compactMap { $0["model_listening"] }))
                   && rows.contains { ($0["exact_reviewed_navigation_necessary"] as? Bool == true) && (($0["context_matrix"] as? [String: String])?["reviewed_procedure"] == "absent") }
                   && rows.contains { !(($0["multi_turn_history"] as? [[String: String]]) ?? []).isEmpty },
                   "P19 required evaluation-only context coverage drifted")
        let opened = CandidateRetrievalIndex.openBundled()
        guard opened.availability == .ready, let retriever = opened.retriever else {
            throw TestFailure(description: "P19 actual runtime index unavailable: \(opened.availability.rawValue)")
        }
        var byPartition: [String: [[String: Any]]] = [:]
        var typedOutcomes: [String: Int] = [:]
        for row in rows {
            guard let query = row["query"] as? String, let partition = row["partition"] as? String else { throw TestFailure(description: "P19 suite row malformed") }
            let started = Date()
            let outcome = await retriever.rankedOutcome(query: query, filters: .init(), limit: 4)
            typedOutcomes[outcome.kind.rawValue, default: 0] += 1
            byPartition[partition, default: []].append([
                "expected": row["acceptable_diagnosis_families"] as? [String] ?? [],
                "abstain": row["ambiguity_expectation"] as? String == "abstain",
                "domains": outcome.cards.map { $0.card.domain },
                "topic": row["topic"] as? String ?? "unknown",
                "kind": row["kind"] as? String ?? "unknown",
                "latency_ms": Date().timeIntervalSince(started) * 1_000,
            ])
        }
        func metric(_ items: [[String: Any]]) -> [String: Any] {
            let positives = items.filter { !($0["expected"] as? [String] ?? []).isEmpty }
            let actualNoMatch = items.filter { $0["abstain"] as? Bool == true }
            let predictedNoMatch = items.filter { ($0["domains"] as? [String] ?? []).isEmpty }
            let truePositive = actualNoMatch.filter { ($0["domains"] as? [String] ?? []).isEmpty }.count
            let top1 = positives.filter { item in
                guard let first = (item["domains"] as? [String])?.first else { return false }
                return (item["expected"] as? [String] ?? []).contains(first)
            }.count
            let top4 = positives.filter { item in
                !Set(item["domains"] as? [String] ?? []).isDisjoint(with: Set(item["expected"] as? [String] ?? []))
            }.count
            let mrr = positives.reduce(0.0) { partial, item in
                let expected = item["expected"] as? [String] ?? []
                let rank = (item["domains"] as? [String] ?? []).firstIndex(where: { expected.contains($0) })
                return partial + (rank.map { 1.0 / Double($0 + 1) } ?? 0)
            }
            func counts(_ selected: [[String: Any]], key: String) -> [String: Int] {
                Dictionary(grouping: selected, by: { $0[key] as? String ?? "unknown" }).mapValues(\.count)
            }
            let top1Misses = positives.filter { item in
                guard let first = (item["domains"] as? [String])?.first else { return true }
                return !(item["expected"] as? [String] ?? []).contains(first)
            }
            let falseAbstains = predictedNoMatch.filter { !($0["abstain"] as? Bool ?? false) }
            let missedAbstains = actualNoMatch.filter { !($0["domains"] as? [String] ?? []).isEmpty }
            let top1Value = positives.isEmpty ? 0 : Double(top1) / Double(positives.count)
            let top4Value = positives.isEmpty ? 0 : Double(top4) / Double(positives.count)
            let precisionValue: Any = predictedNoMatch.isEmpty ? NSNull() : Double(truePositive) / Double(predictedNoMatch.count)
            let recallValue: Any = actualNoMatch.isEmpty ? NSNull() : Double(truePositive) / Double(actualNoMatch.count)
            let precisionGate = (precisionValue as? Double).map { $0 >= 0.90 } ?? false
            let recallGate = (recallValue as? Double).map { $0 >= 0.90 } ?? false
            let meets = top1Value >= 0.80 && top4Value >= 0.95 && precisionGate && recallGate
            return [
                "case_count": items.count,
                "top1_acceptable": top1Value,
                "top4_recall": top4Value,
                "mrr": positives.isEmpty ? 0 : mrr / Double(positives.count),
                "no_match_precision": precisionValue,
                "no_match_recall": recallValue,
                "no_match_counts": ["true_positive": truePositive, "predicted_no_match": predictedNoMatch.count, "actual_no_match": actualNoMatch.count],
                // Timings are exercised for every case, but host scheduling is
                // deliberately not serialized as a numeric golden artifact.
                "latency_ms": ["measured": true, "reporting": "runtime latency is measured but not serialized numerically in reproducible evidence"],
                "quality_targets": ["top1_acceptable": 0.80, "top4_recall": 0.95, "no_match_precision": 0.90, "no_match_recall": 0.90, "ambiguity_balanced_accuracy": "not_applicable_model_withheld", "status": meets ? "met" : "missed"],
                "failure_taxonomy": ["top1_miss_by_topic": counts(top1Misses, key: "topic"), "top1_miss_by_kind": counts(top1Misses, key: "kind"), "false_abstain_by_topic": counts(falseAbstains, key: "topic"), "missed_abstain_by_topic": counts(missedAbstains, key: "topic")],
            ]
        }

        let prior = TutorExperimentRecord(draft: experimentDraft(title: "Baseline comparison"), outcome: .noChange)
        let executor = try TutorToolExecutor(observeLogic: { query in
            .init(status: .observed, applicationName: "Logic Pro", bundleIdentifier: "com.apple.logic10", windowTitle: "Current channel inspector", controls: [.init(role: "AXButton", label: query, value: "off", frame: .init(x: 1, y: 1, width: 1, height: 1))], limitation: "Read-only local state; not a live Logic observation.")
        }, priorExperiments: { [prior] })
        let context = TutorRuntimeContext(sourceType: .vocal, capture: sampleCapture(wavData: Data("p19-capture".utf8)), experience: .init(persistentLevel: .amateur, temporaryOverride: .pro))
        let calls: [(String, String)] = [
            ("get_current_capture_context", "{}"), ("search_production_knowledge", #"{"query":"muddy vocal low mid"}"#),
            ("search_candidate_corpus", #"{"query":"my vocal gets muddy when guitars arrive"}"#), ("get_logic_procedure", #"{"query":"Channel EQ vocal low mid"}"#),
            ("retrieve_prior_experiments", #"{"query":null,"max_results":6}"#), ("inspect_logic", #"{"query":"Channel EQ"}"#),
            ("present_experiment", experimentArguments(title: "One-variable comparison")),
        ]
        var outputs: [TutorToolResult] = []
        for (offset, call) in calls.enumerated() {
            outputs.append(try await executor.execute(.init(callID: "p19-\(offset)", name: call.0, argumentsJSON: call.1), context: context))
        }
        try expect(outputs.count == TutorToolExecutor.defaultDefinitions.count && outputs.allSatisfy { $0.outputJSON.utf8.count <= TutorToolExecutor.maximumToolOutputBytes },
                   "P19 seven-tool execution or output bound failed")
        guard let experiment = outputs.last?.experiment else { throw TestFailure(description: "P19 experiment was not receipt-ready") }
        try expect(!experiment.title.isEmpty && !experiment.startingRange.isEmpty && !experiment.listenFor.isEmpty && !experiment.risk.isEmpty && !(experiment.stopCondition ?? "").isEmpty && !experiment.undo.isEmpty,
                   "P19 experiment completeness failed")
        let knowledge = try GeneralTutorKnowledgeBase.loadValidated(); let procedures = try TutorProcedureCatalog.loadValidated()
        // The suite context matrix is operational, not decorative: every
        // unavailable/integrity outcome travels through the real tool boundary
        // and must not be silently rewritten as an ordinary valid no-match.
        let typedFailureCases: [(CandidateRetrievalAvailability, CandidateRetrievalOutcomeKind)] = [
            (.unavailable, .unavailable), (.corrupt, .corrupt), (.disabled, .disabled),
            (.versionMismatch, .versionMismatch), (.schemaDrift, .schemaDrift),
            (.ready, .malformedSelectedPayload), (.ready, .queryFailed),
        ]
        for (offset, typed) in typedFailureCases.enumerated() {
            let injected = CandidateRetrieverStub(typed.0, outcome: typed.1)
            let result = try await TutorToolExecutor(knowledge: knowledge, procedures: procedures, candidateRetriever: injected).execute(.init(callID: "p19-typed-\(offset)", name: "search_candidate_corpus", argumentsJSON: #"{"query":"muddy vocal guitars"}"#), context: context)
            try expect(result.outputJSON.contains(typed.1.rawValue) && result.evidence.first?.kind == .unavailable,
                       "P19 typed outcome \(typed.1.rawValue) collapsed to valid no-match")
        }
        let validNoMatch = CandidateRetrieverStub(.ready, outcome: .noMatch)
        let noMatchResult = try await TutorToolExecutor(knowledge: knowledge, procedures: procedures, candidateRetriever: validNoMatch).execute(.init(callID: "p19-valid-no-match", name: "search_candidate_corpus", argumentsJSON: #"{"query":"muddy vocal guitars"}"#), context: context)
        try expect(noMatchResult.outputJSON.contains("noMatch") && noMatchResult.evidence.first?.kind != .unavailable,
                   "P19 valid no-match was conflated with a query/integrity failure")
        let legacyExperiment = try await executor.execute(.init(callID: "p19-stop-missing", name: "present_experiment", argumentsJSON: experimentArguments(title: "P19 missing stop")), context: context)
        try expect(!(legacyExperiment.experiment?.stopCondition ?? "").isEmpty, "P19 missing stop field lost additive safe default")
        let explicitStop = "Stop immediately if the vocal becomes thinner than the bypassed baseline."
        let explicitExperiment = try await executor.execute(.init(callID: "p19-stop-explicit", name: "present_experiment", argumentsJSON: experimentArguments(title: "P19 explicit stop", stopCondition: explicitStop)), context: context)
        try expect(explicitExperiment.experiment?.stopCondition == explicitStop, "P19 explicit stop field was not retained in receipt")
        do {
            _ = try await executor.execute(.init(callID: "p19-stop-oversized", name: "present_experiment", argumentsJSON: experimentArguments(title: "P19 oversized stop", stopCondition: String(repeating: "x", count: 601))), context: context)
            throw TestFailure(description: "P19 oversized stop condition was accepted")
        } catch let error as TutorConversationError {
            try expect(error == .invalidToolArguments("stop_condition"), "P19 oversized stop condition had wrong failure")
        }
        // These are behavioural security cases, not source-string checks. The
        // final assertion catches both sanitizer misses and any Markdown parser
        // attribute that would otherwise become an interactive transport.
        let hostileMarkdown = [
            "[HTTP label](HTTP://Example.test/a_(b)) and [HTTPS label](hTTps://example.test)",
            "![cover art](https://cdn.example.test/cover.png) plus <img src=\"https://cdn.example.test/x\">",
            "<HTTPS://example.test/autolink> <mailto:owner@example.test> <file:///private/tmp/a> <custom+scheme://example.test>",
            "[relative label](../private/file) and [root label](/Contents/Resources/secret)",
            "**strong** and `inline code` with www.Example.test and MAILTO:owner@example.test",
            "[nested label](https://example.test/path_(one_(two))) and [malformed](https://example.test/unclosed",
            "<b>visible HTML text</b> and <script>never load</script>",
        ]
        for input in hostileMarkdown {
            let sanitized = TutorMarkdownSanitizer.sanitize(input)
            let attributed = TutorMarkdownSanitizer.inertInlineAttributedText(input)
            try expect(!sanitized.contains("://") && !sanitized.lowercased().contains("mailto:") && !sanitized.lowercased().contains("file:") && !sanitized.lowercased().contains("custom+scheme:"),
                       "P19 Markdown sanitizer retained a transport target: \(input)")
            try expect(attributed.runs.allSatisfy { $0.link == nil }, "P19 Markdown parser retained a link attribute: \(input)")
        }
        let safeStyled = TutorMarkdownSanitizer.inertInlineAttributedText("## Heading\\n- **emphasis** and `code`")
        try expect(String(safeStyled.characters).contains("Heading") && String(safeStyled.characters).contains("emphasis") && String(safeStyled.characters).contains("code"),
                   "P19 Markdown sanitizer discarded readable local content")
        let markdownURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("apps/CompanionMacApp/SafeTutorMarkdown.swift")
        let markdownSource = try String(contentsOf: markdownURL)
        for required in ["hasPrefix(\"# \")", "hasPrefix(\"- \")", "textSelection(.enabled)", "accessibilityElement(children: .contain)", "inertInlineAttributedText"] {
            try expect(markdownSource.contains(required), "P19 safe Markdown view omitted \(required)")
        }
        try expect(!markdownSource.contains("accessibilityLabel(\"Tutor response\")"), "P19 Markdown renderer suppresses response content for VoiceOver")
        try expect(!markdownSource.contains("WebView") && !markdownSource.contains("Link("), "P19 Markdown renderer introduced remote/interactive content")
        let longContext = try await packageNineteenMeasuredLongContextHarness()
        try await packageNineteenCloudHarnessContract()
        let report: [String: Any] = [
            "package": "019", "status": "infrastructure_pass_quality_fail", "actual_runtime_current_final": ["per_partition": Dictionary(uniqueKeysWithValues: byPartition.map { ($0.key, metric($0.value)) }), "typed_outcomes": typedOutcomes, "quality_gate": "failed: held-out ranking target missed; no held-out tuning performed"],
            "tools": ["count": outputs.count, "names": calls.map(\.0), "output_bytes": outputs.map { $0.outputJSON.utf8.count }, "authority": "read-only except presentation-only experiment"],
            "experiment_completeness": ["status": "pass", "repairs": "not_applicable_no_repair_path_invoked", "max_repairs": 1, "fields": ["baseline_start", "one_variable", "listen_cue", "risk", "stop_condition", "undo"]],
            "long_context": longContext,
            "evidence_boundary": "Injected deterministic capture/Logic state, local runtime index, and a recording loopback transport only. OpenAI request serialization was exercised with store:false, but the transport cannot reach the network; no cloud provider, audio upload, installed app, Logic action, or owner listening occurred.",
        ]
        if ProcessInfo.processInfo.environment["TRACKSMITH_P19_DIAGNOSTIC_NO_WRITE"] != "1" {
            let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/evidence/PACKAGE_019_TOOL_DIAGNOSTIC.json")
            try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]).write(to: outputURL)
        }
        print("P19_LONG_CONTEXT_HARNESS_OK messages=10,25,50,80 provider=loopback-only tools=candidate,procedure,capture,history cancellation=retry capture=replaced")
        print("P19_DIAGNOSTIC_OK cases=240 tools=7 typedFailures=7 longContext=measured-10,25,50,80")
    }

    /// A provider-free end-to-end harness. It deliberately uses the public
    /// Responses request serializer with a recording in-process transport, so
    /// it proves bounded engine/store/context mechanics without a network call
    /// or a claim about cloud model quality, latency, cost, or musician value.
    private func packageNineteenMeasuredLongContextHarness() async throws -> [String: Any] {
        let counts = [10, 25, 50, 80]
        let decisiveExperiment = packageNineteenPriorExperiment()
        let captureA = packageNineteenCapture("00000000-0000-0000-0000-000000000019")
        let captureB = packageNineteenCapture("00000000-0000-0000-0000-000000000029")
        let context = TutorRuntimeContext(
            sourceType: .vocal,
            capture: captureA,
            consent: .init(cloudTextGranted: false),
            experience: .init(persistentLevel: .amateur, temporaryOverride: .pro)
        )
        var runs: [[String: Any]] = []

        for count in counts {
            let history = (0..<(count - 1)).map { index -> TutorConversationMessage in
                let text: String
                switch index {
                case count - 3:
                    text = "Decisive prior experiment: the baseline low-mid comparison was better; preserve that outcome."
                case count - 2:
                    text = "Temporary topic change: the drum bus is distracting, but do not replace the vocal baseline."
                default:
                    text = "History \(index): topic \(index % 4) remains bounded local conversation context."
                }
                return TutorConversationMessage(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                    role: index.isMultiple(of: 2) ? .user : .assistant,
                    text: text,
                    createdAt: Date(timeIntervalSince1970: 1_786_300_000 + Double(index))
                )
            }
            let root = temporaryRoot("p19-long-\(count)")
            defer { try? FileManager.default.removeItem(at: root) }
            let store = TutorConversationStore(rootURL: root)
            let executor = try TutorToolExecutor(priorExperiments: { [decisiveExperiment] })
            let engine = TutorConversationEngine(
                state: TutorConversationState(
                    id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", count))!,
                    createdAt: Date(timeIntervalSince1970: 1_786_300_000),
                    updatedAt: Date(timeIntervalSince1970: 1_786_300_000),
                    messages: history,
                    experiments: [decisiveExperiment]
                ),
                store: store,
                tools: executor,
                fallbackProvider: try OfflineTutorProvider()
            )
            let transport = PackageNineteenLoopbackStreamingTransport()
            let provider = packageNineteenLoopbackProvider(transport: transport)
            let started = Date()
            let events = try await collectTurn(
                engine,
                "Return to the vocal masking problem. Keep the decisive baseline outcome and do not repeat the temporary drum topic.",
                context,
                provider
            )
            _ = Date().timeIntervalSince(started) // exercised, intentionally non-golden
            guard let completed = events.compactMap({ event -> TutorEvidenceReceipt? in
                if case let .completed(_, receipt) = event { return receipt }
                return nil
            }).last else {
                throw TestFailure(description: "P19 long context \(count) did not complete")
            }
            let bodies = transport.requestBodies()
            try expect(bodies.count == 2 && bodies.allSatisfy { $0.count <= 512 * 1_024 },
                       "P19 long context \(count) did not use a bounded two-round local tool loop")
            guard let first = try packageNineteenRequestBody(bodies[0]),
                  let firstInput = first["input"] as? [[String: Any]],
                  let developer = firstInput.first?["content"] as? String else {
                throw TestFailure(description: "P19 long context \(count) did not serialize local provider context")
            }
            let retained = Array(firstInput.dropFirst())
            let retainedText = retained.compactMap { $0["content"] as? String }
            try expect(retained.count == count &&
                       retainedText.contains(where: { $0.contains("Decisive prior experiment") }) &&
                       retainedText.contains(where: { $0.contains("Temporary topic change") }) &&
                       retainedText.last?.contains("Return to the vocal masking") == true &&
                       developer.contains("\"temporaryOverride\":\"pro\"") &&
                       developer.contains(captureA.captureSnapshotID.uuidString) &&
                       first["store"] as? Bool == false,
                       "P19 long context \(count) lost retained relevance, temporary level, capture identity, or store:false")
            let continuationOutputs = (try packageNineteenRequestBody(bodies[1]))?["input"] as? [[String: Any]] ?? []
            let toolOutputs = continuationOutputs.filter { ($0["type"] as? String) == "function_call_output" }
            try expect(toolOutputs.count == 4 && toolOutputs.allSatisfy { ($0["output"] as? String ?? "").utf8.count <= TutorToolExecutor.maximumToolOutputBytes },
                       "P19 long context \(count) did not preserve bounded real tool outputs")
            let names = Set(completed.tools.map(\.name))
            try expect(names.isSuperset(of: ["get_current_capture_context", "search_candidate_corpus", "get_logic_procedure", "retrieve_prior_experiments"]) &&
                       completed.provider.outputTokens == PackageNineteenLoopbackStreamingTransport.fixtureOutputTokens &&
                       completed.captureSnapshotID == captureA.captureSnapshotID,
                       "P19 long context \(count) missed real capture/candidate/procedure/history tool participation")
            let requestBytes = bodies.map(\.count)
            let estimatedTokens = requestBytes.map { ($0 + 3) / 4 }
            let latency: [String: Any] = ["measured": true, "reporting": "wall-clock latency exercised but omitted from deterministic evidence"]
            let boundedness: [String: Any] = ["request_max_bytes": 512 * 1_024, "tool_output_max_bytes": TutorToolExecutor.maximumToolOutputBytes, "asserted": true]
            let run: [String: Any] = [
                "retained_messages": count,
                "provider_request_rounds": bodies.count,
                "tool_rounds": 1,
                "tool_calls": completed.tools.count,
                "request_bytes": requestBytes,
                "estimated_input_tokens": estimatedTokens,
                "output_tokens": completed.provider.outputTokens ?? NSNull(),
                "topic_change_and_return": "asserted_from_serialized_retained_history",
                "decisive_prior_experiment_outcome": "asserted_from_real_prior_experiment_tool",
                "temporary_experience_override": "pro_asserted_from_serialized_context",
                "capture_identity": "asserted_from_serialized_context_and_receipt",
                "latency_ms": latency,
                "boundedness": boundedness,
            ]
            runs.append(run)
        }

        let captureRoot = temporaryRoot("p19-capture-replacement")
        defer { try? FileManager.default.removeItem(at: captureRoot) }
        let captureStore = TutorConversationStore(rootURL: captureRoot)
        let captureEngine = TutorConversationEngine(
            store: captureStore,
            tools: try TutorToolExecutor(priorExperiments: { [decisiveExperiment] }),
            fallbackProvider: try OfflineTutorProvider()
        )
        let captureTransport = PackageNineteenLoopbackStreamingTransport()
        let captureProvider = packageNineteenLoopbackProvider(transport: captureTransport)
        let firstCaptureEvents = try await collectTurn(captureEngine, "Use the first local capture only.", context, captureProvider)
        var replacementContext = context
        replacementContext.capture = captureB
        let replacementEvents = try await collectTurn(captureEngine, "Replace the capture and keep the same local-only boundary.", replacementContext, captureProvider)
        guard let firstReceipt = firstCaptureEvents.compactMap({ if case let .completed(_, receipt) = $0 { return receipt }; return nil }).last,
              let replacementReceipt = replacementEvents.compactMap({ if case let .completed(_, receipt) = $0 { return receipt }; return nil }).last else {
            throw TestFailure(description: "P19 capture replacement receipts were absent")
        }
        let persistedFirstReceipt = try captureStore.loadReceipt(firstReceipt.id)
        let persistedReplacementReceipt = try captureStore.loadReceipt(replacementReceipt.id)
        try expect(firstReceipt.captureSnapshotID == captureA.captureSnapshotID &&
                   replacementReceipt.captureSnapshotID == captureB.captureSnapshotID &&
                   persistedFirstReceipt.captureSnapshotID == captureA.captureSnapshotID &&
                   persistedReplacementReceipt.captureSnapshotID == captureB.captureSnapshotID,
                   "P19 capture replacement identity was not persisted per turn")

        let cancellationRoot = temporaryRoot("p19-cancellation-retry")
        defer { try? FileManager.default.removeItem(at: cancellationRoot) }
        let cancellationEngine = TutorConversationEngine(
            store: TutorConversationStore(rootURL: cancellationRoot),
            tools: try TutorToolExecutor(priorExperiments: { [decisiveExperiment] }),
            fallbackProvider: try OfflineTutorProvider()
        )
        let pending = try await cancellationEngine.streamTurn(text: "Begin a cancellable local turn.", context: context, provider: SlowConversationProvider())
        let consumer = Task { for try await _ in pending {} }
        try await Task.sleep(for: .milliseconds(40))
        consumer.cancel()
        _ = await consumer.result
        try await Task.sleep(for: .milliseconds(20))
        let retryTransport = PackageNineteenLoopbackStreamingTransport()
        let retryEvents = try await collectTurn(cancellationEngine, "Retry after cancellation with the current capture.", context, packageNineteenLoopbackProvider(transport: retryTransport))
        let retryState = await cancellationEngine.snapshot()
        try expect(retryEvents.contains(where: { if case .completed = $0 { return true }; return false }) &&
                   retryState.messages.contains(where: { $0.status == .cancelled }) &&
                   retryState.messages.last?.status == .complete &&
                   !retryState.messages.contains(where: { $0.status == .complete && $0.text.contains("Partial explanation completed") }),
                   "P19 cancellation/retry left a stale provider result or failed to recover")

        return [
            "status": "provider_free_measured",
            "runs": runs,
            "message_limit": TutorConversationEngine.maximumMessageBytes,
            "tool_output_limit": TutorToolExecutor.maximumToolOutputBytes,
            "capture_replacement": "measured_receipt_identity",
            "cancellation_retry": "measured_cancelled_then_complete_without_stale_result",
            "boundary": "Local-only loopback transport exercised OpenAI request serialization and engine/store/tool mechanics. It made zero network calls and does not measure cloud latency/cost, semantic model quality, or musician usefulness.",
        ]
    }

    /// Provider-free contract coverage for the opt-in harness. This exercises
    /// the same serializer, engine tool loop, receipt, telemetry projection,
    /// firewall predicate, and transient retry policy with transports that are
    /// physically incapable of reaching a network.
    private func packageNineteenCloudHarnessContract() async throws {
        try expect(packageNineteenLaneName(.noTool) == "no_tool" && packageNineteenLaneName(.fullTool) == "full_tool" && packageNineteenLaneName(.repeatedTriplets) == "repeated_triplets",
                   "P19 cloud lane routing labels drifted")
        let root = temporaryRoot("p19-cloud-contract"); defer { try? FileManager.default.removeItem(at: root) }
        let transport = PackageNineteenLoopbackStreamingTransport()
        let provider = packageNineteenLoopbackProvider(transport: transport)
        let prior = packageNineteenPriorExperiment()
        let executor = try TutorToolExecutor(priorExperiments: { [prior] })
        let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: root), tools: executor, fallbackProvider: try OfflineTutorProvider())
        let context = TutorRuntimeContext(sourceType: .vocal, capture: packageNineteenCapture("00000000-0000-0000-0000-000000000069"), consent: .init(cloudTextGranted: false), experience: .init(persistentLevel: .amateur))
        let events = try await collectTurn(engine, "Compare one reversible adjustment with the current capture.", context, provider)
        guard let receipt = events.compactMap({ if case let .completed(_, value) = $0 { return value }; return nil }).last else {
            throw TestFailure(description: "P19 cloud contract engine path did not persist a receipt")
        }
        let bodies = transport.requestBodies(); let telemetry = try packageNineteenEnvelopeTelemetry(bodies)
        let sent = telemetry["tools_sent"] as? [String] ?? []
        let schemaHashes = telemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:]
        let calls = telemetry["tool_calls"] as? [[String: Any]] ?? []
        let results = telemetry["tool_results"] as? [[String: Any]] ?? []
        let envelopeSchemas = telemetry["tool_schema_envelopes"] as? [[String: String]] ?? []
        let envelopeEntryCounts = telemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? []
        let envelopeDuplicateNames = telemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? []
        try expect(bodies.count == 2 && Set(sent) == Set(TutorToolExecutor.defaultDefinitions.map(\.name)) && packageNineteenExactSerializedToolSchemas(actual: schemaHashes, envelopes: envelopeSchemas, envelopeEntryCounts: envelopeEntryCounts, envelopeDuplicateNames: envelopeDuplicateNames, toolsEnabled: true) && calls.count == receipt.tools.count && results.count == calls.count && bodies.allSatisfy { $0.count <= 512 * 1_024 },
                   "P19 cloud contract did not report only actually serialized tools/calls/results")
        try expect(packageNineteenReceiptMatchesTelemetry(receipt: receipt, telemetry: telemetry),
                   "P19 cloud contract receipt did not bind observed tool call IDs, arguments, and outputs")
        var mutatedSchemas = schemaHashes
        mutatedSchemas["search_candidate_corpus"] = "0" + String(repeating: "1", count: 63)
        try expect(!packageNineteenExactSerializedToolSchemas(actual: mutatedSchemas, envelopes: envelopeSchemas, envelopeEntryCounts: envelopeEntryCounts, envelopeDuplicateNames: envelopeDuplicateNames, toolsEnabled: true),
                   "P19 cloud schema contract accepted a mutated serialized parameter or description")
        let canonicalTool = OpenAITutorProvider.toolSchema(TutorToolExecutor.defaultDefinitions[0])
        let canonicalTools = TutorToolExecutor.defaultDefinitions.map(OpenAITutorProvider.toolSchema)
        let repeatedCanonicalTelemetry = try packageNineteenEnvelopeTelemetry([
            JSONSerialization.data(withJSONObject: ["tools": canonicalTools]),
            JSONSerialization.data(withJSONObject: ["tools": canonicalTools]),
        ])
        try expect(repeatedCanonicalTelemetry["tool_schema_conflict"] as? Bool == false && packageNineteenExactSerializedToolSchemas(actual: repeatedCanonicalTelemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: repeatedCanonicalTelemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: repeatedCanonicalTelemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: repeatedCanonicalTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], conflict: false, toolsEnabled: true),
                   "P19 cloud schema contract rejected identical repeated serialized schemas")
        var conflictingTool = canonicalTool
        conflictingTool["description"] = "mutated test-only description"
        let conflictingTelemetry = try packageNineteenEnvelopeTelemetry([
            JSONSerialization.data(withJSONObject: ["tools": [canonicalTool]]),
            JSONSerialization.data(withJSONObject: ["tools": [conflictingTool]]),
        ])
        try expect(conflictingTelemetry["tool_schema_conflict"] as? Bool == true && !packageNineteenExactSerializedToolSchemas(actual: conflictingTelemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: conflictingTelemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: conflictingTelemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: conflictingTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], conflict: conflictingTelemetry["tool_schema_conflict"] as? Bool ?? false, toolsEnabled: true),
                   "P19 cloud schema contract accepted conflicting repeated schemas for one tool name")
        let omittedEnvelopeTelemetry = try packageNineteenEnvelopeTelemetry([JSONSerialization.data(withJSONObject: ["tools": canonicalTools]), JSONSerialization.data(withJSONObject: ["tools": Array(canonicalTools.dropLast())])])
        try expect(!packageNineteenExactSerializedToolSchemas(actual: omittedEnvelopeTelemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: omittedEnvelopeTelemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: omittedEnvelopeTelemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: omittedEnvelopeTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], toolsEnabled: true),
                   "P19 cloud schema contract accepted a later envelope that omitted a tool")
        let duplicateCanonicalEnvelopeTelemetry = try packageNineteenEnvelopeTelemetry([JSONSerialization.data(withJSONObject: ["tools": canonicalTools + [canonicalTool]])])
        try expect(duplicateCanonicalEnvelopeTelemetry["tool_schema_conflict"] as? Bool == false && duplicateCanonicalEnvelopeTelemetry["tool_schema_envelope_entry_counts"] as? [Int] == [canonicalTools.count + 1] && duplicateCanonicalEnvelopeTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] == [true] && !packageNineteenExactSerializedToolSchemas(actual: duplicateCanonicalEnvelopeTelemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: duplicateCanonicalEnvelopeTelemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: duplicateCanonicalEnvelopeTelemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: duplicateCanonicalEnvelopeTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], toolsEnabled: true),
                   "P19 cloud schema contract accepted a duplicate canonical schema in one full envelope")
        let unnamedEnvelopeTelemetry = try packageNineteenEnvelopeTelemetry([JSONSerialization.data(withJSONObject: ["tools": [["type": "function"]]])])
        try expect((unnamedEnvelopeTelemetry["invalid_tool_schema_entry"] as? Bool) == true && !packageNineteenExactSerializedToolSchemas(actual: unnamedEnvelopeTelemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: unnamedEnvelopeTelemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: unnamedEnvelopeTelemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: unnamedEnvelopeTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], invalid: unnamedEnvelopeTelemetry["invalid_tool_schema_entry"] as? Bool ?? false, toolsEnabled: true),
                   "P19 cloud schema contract accepted unnamed or malformed serialized tools")
        try expect((unnamedEnvelopeTelemetry["tools_sent"] as? [String] ?? []).isEmpty && !packageNineteenExactSerializedToolSchemas(actual: unnamedEnvelopeTelemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: unnamedEnvelopeTelemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: unnamedEnvelopeTelemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: unnamedEnvelopeTelemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], invalid: unnamedEnvelopeTelemetry["invalid_tool_schema_entry"] as? Bool ?? false, toolsEnabled: false),
                   "P19 no-tool schema contract accepted malformed nonempty tools entries")
        let multiRoundBodies = try [
            JSONSerialization.data(withJSONObject: ["input": [["type": "function_call", "call_id": "a", "name": "get_current_capture_context", "arguments": "{}"], ["type": "function_call", "call_id": "b", "name": "search_candidate_corpus", "arguments": #"{"query":"vocal"}"#]]]),
            JSONSerialization.data(withJSONObject: ["input": [["type": "function_call", "call_id": "a", "name": "get_current_capture_context", "arguments": "{}"], ["type": "function_call", "call_id": "b", "name": "search_candidate_corpus", "arguments": #"{"query":"vocal"}"#], ["type": "function_call", "call_id": "c", "name": "get_logic_procedure", "arguments": #"{"query":"Channel EQ"}"#], ["type": "function_call_output", "call_id": "a", "output": #"{"status":"ok"}"#], ["type": "function_call_output", "call_id": "b", "output": #"{"status":"ok"}"#]]]),
            JSONSerialization.data(withJSONObject: ["input": [["type": "function_call_output", "call_id": "c", "output": #"{"status":"ok"}"#]]]),
        ]
        let multiRound = try packageNineteenEnvelopeTelemetry(multiRoundBodies)
        let multiCalls = multiRound["tool_calls"] as? [[String: Any]] ?? []
        let multiResults = multiRound["tool_results"] as? [[String: Any]] ?? []
        try expect(multiCalls.map { $0["call_id"] as? String } == ["a", "b", "c"] && multiResults.map { $0["call_id"] as? String } == ["a", "b", "c"] && multiResults.allSatisfy { ($0["output_sha256"] as? String)?.count == 64 } && (multiRound["tool_call_conflict"] as? Bool) == false && (multiRound["tool_output_conflict"] as? Bool) == false,
                   "P19 cloud telemetry duplicated cumulative tool calls or lost call-ID output binding")
        let callConflictTelemetry = try packageNineteenEnvelopeTelemetry([JSONSerialization.data(withJSONObject: ["input": [["type": "function_call", "call_id": "same", "name": "search_candidate_corpus", "arguments": "{\\\"query\\\":\\\"a\\\"}"], ["type": "function_call", "call_id": "same", "name": "search_candidate_corpus", "arguments": "{\\\"query\\\":\\\"b\\\"}"]]])])
        let outputConflictTelemetry = try packageNineteenEnvelopeTelemetry([JSONSerialization.data(withJSONObject: ["input": [["type": "function_call_output", "call_id": "same", "output": "{\\\"status\\\":\\\"a\\\"}"], ["type": "function_call_output", "call_id": "same", "output": "{\\\"status\\\":\\\"b\\\"}"]]])])
        try expect((callConflictTelemetry["tool_call_conflict"] as? Bool) == true && (outputConflictTelemetry["tool_output_conflict"] as? Bool) == true,
                   "P19 cloud telemetry accepted conflicting cumulative call or output payloads")
        let noToolTransport = PackageNineteenLoopbackStreamingTransport(toolLoop: false)
        let noToolProvider = packageNineteenLoopbackProvider(transport: noToolTransport)
        let noToolRun = await packageNineteenCloudTextWithRetry(provider: noToolProvider, query: "Compare one reversible adjustment.", context: .init(sourceType: .vocal, experience: .init(persistentLevel: .amateur)), requestCount: { noToolTransport.requestBodies().count })
        let noToolEnvelope = String(decoding: noToolTransport.requestBodies().joined(), as: UTF8.self)
        let toolEnvelope = String(decoding: bodies.joined(), as: UTF8.self)
        let noToolHasCapture = noToolEnvelope.contains("00000000-0000-0000-0000-000000000069")
        let noToolHasGoal = noToolEnvelope.contains("Assess one reversible change for the current source")
        let toolHasCapture = toolEnvelope.contains("00000000-0000-0000-0000-000000000069")
        try expect(noToolRun.outcome.terminalStatus == "completed" && !noToolHasCapture && !noToolHasGoal && toolHasCapture,
                   "P19 Lane A no-tool context drifted from the historical P17 sourceType+level baseline completed=\(noToolRun.outcome.terminalStatus) capture=\(noToolHasCapture) goal=\(noToolHasGoal) toolCapture=\(toolHasCapture)")
        let state = await engine.snapshot()
        let artifact = packageNineteenGenerationArtifact(
            prompt: .init(order: 0, topic: "contract", query: "Compare one reversible adjustment with the current capture."), level: .amateur, repetition: 0, attempt: 1,
            terminalStatus: "completed", text: state.messages.last?.text ?? "", metadata: receipt.provider,
            telemetry: telemetry, receipt: receipt, experiment: state.experiments.last, persistedExperimentCount: state.experiments.count, latencyMeasured: 0, toolsEnabled: true, safeFailure: nil
        )
        try expect((artifact["assistant_text"] as? String ?? "").utf8.count <= 4096 && ((artifact["deterministic_authority_structure"] as? [String: Any])?["no_hidden_reasoning_stored"] as? Bool) == true && ((artifact["tool_results"] as? [[String: Any]]) ?? []).allSatisfy { (($0["output_bytes"] as? Int) ?? 0) <= TutorToolExecutor.maximumToolOutputBytes },
                   "P19 cloud contract artifact exceeded bounds or retained hidden reasoning")
        let deterministic = artifact["deterministic_evaluation"] as? [String: Any]
        let proseFlags = deterministic?["final_prose_flags"] as? [String: Any]
        try expect(deterministic?["exact_procedure_necessity"] != nil && deterministic?["evidence_honesty"] != nil && deterministic?["authority"] != nil && deterministic?["overall_deterministic_completeness"] != nil && deterministic?["usefulness_structural"] != nil && proseFlags?["has_changed_variable_or_action"] != nil && proseFlags?["has_listen_cue"] != nil && proseFlags?["has_risk"] != nil && proseFlags?["has_stop"] != nil && proseFlags?["has_undo_or_rollback"] != nil && (artifact["serialized_tool_definitions_exact"] as? Bool) == true,
                   "P19 cloud contract deterministic evaluator or exact seven-tool assertion drifted")
        let noToolArtifact = packageNineteenGenerationArtifact(prompt: .init(order: 1, topic: "no-tool", query: "q"), level: .noob, repetition: 0, attempt: 1, terminalStatus: "completed", text: "Change one setting, then listen for the risk; stop and undo if it worsens.", metadata: receipt.provider, telemetry: ["tools_sent": [String](), "tool_schema_sha256_by_name": [String: String](), "tool_schema_envelopes": [[String: String]()], "tool_schema_envelope_entry_counts": [0], "tool_schema_envelope_duplicate_names": [false], "provider_request_calls": 1, "tool_rounds": 0, "tool_calls": [[String: Any]](), "tool_results": [[String: Any]]()], receipt: nil, experiment: nil, persistedExperimentCount: 0, latencyMeasured: 0, toolsEnabled: false, safeFailure: nil)
        try expect((noToolArtifact["serialized_tool_definitions_exact"] as? Bool) == true && ((noToolArtifact["tools_sent"] as? [String]) ?? []).isEmpty,
                   "P19 no-tool routing advertised a tool definition")
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let fixturePrompts = try packageNineteenCloudPrompts(repository: repository)
        let hashes = try packageNineteenEvaluationHashes(repository, prompts: fixturePrompts)
        let cloudSuite = hashes["cloud_prompt_suite"] as? [String: Any]
        try expect((cloudSuite?["exact_prompt_count"] as? Int) == 12 && cloudSuite?["ordered_prompt_suite_sha256"] as? String == Self.packageNineteenOrderedCloudPromptSHA256 && cloudSuite?["prompt_only_file_sha256"] as? String == Self.packageNineteenCloudPromptSuiteSHA256,
                   "P19 cloud artifact hash contract omitted the exact ordered 12-prompt suite")
        let lexicalPrompt = fixturePrompts[0]
        let lexicalResponses = [TutorExperienceLevel.noob, .amateur, .pro].map { level in
            PackageSeventeenCloudResponse(prompt: lexicalPrompt, level: level, outcome: .init(text: "A short bounded answer.", metadata: nil, attempts: 1, terminalStatus: "completed", safeFailure: nil))
        }
        let lexical = try packageNineteenDeterministicSemanticEvaluation(repository: repository, prompt: lexicalPrompt, triplet: lexicalResponses)
        try expect(lexical["status"] as? String == "diagnostic_only_nonsemantic_lexical_signal" && lexical["overall_status"] as? String == "indeterminate_requires_blinded_judge" && lexical["all_acceptable_family_matches"] == nil,
                   "P19 lexical diagnostic retained an authoritative acceptable-family claim")
        let fixtureA = packageNineteenTopicFixture(.init(order: 0, topic: "vocal_masking", query: "q"))
        let fixtureB = packageNineteenTopicFixture(.init(order: 7, topic: "sidechain_trigger", query: "q"))
        try expect(fixtureA.sourceType != fixtureB.sourceType && fixtureA.capture.captureSnapshotID != fixtureB.capture.captureSnapshotID && fixtureA.logicControl != fixtureB.logicControl,
                   "P19 cloud topic fixtures are not deterministically distinct")
        let allProviderContextValues = fixturePrompts.flatMap { prompt -> [String] in
            let fixture = packageNineteenTopicFixture(prompt)
            return [String(describing: fixture.capture), fixture.logicControl, fixture.limitation]
        }
        try expect(fixturePrompts.count == 12 && packageNineteenProviderFacingBoundaryIsClean(bodies: bodies, additionalValues: allProviderContextValues),
                   "P19 cloud contract leaked evaluator labels or fixture aliases into a provider-facing envelope/tool value")
        try expect(!packageNineteenProviderFacingBoundaryIsClean(bodies: [], additionalValues: ["Package 019 case-12 evaluation fixture", "sidechain_trigger"]),
                   "P19 cloud contract leak detector accepted a package/topic/case alias")
        let completed = PackageNineteenCloudGeneration(artifact: artifact, response: .init(prompt: .init(order: 0, topic: "contract", query: "q"), level: .amateur, outcome: .init(text: "a", metadata: receipt.provider, attempts: 1, terminalStatus: "completed", safeFailure: nil)), providerRequestCalls: bodies.count)
        let incomplete = PackageNineteenCloudGeneration(artifact: ["terminal_status": "failed"], response: completed.response, providerRequestCalls: 0)
        try expect(packageNineteenTripletIsGenerationComplete([completed, completed, completed]) && !packageNineteenTripletIsGenerationComplete([completed, completed, incomplete]),
                   "P19 reference firewall completion predicate drifted")
        func atLevel(_ level: TutorExperienceLevel) -> PackageNineteenCloudGeneration {
            var copied = artifact; copied["level"] = level.rawValue
            return .init(artifact: copied, response: .init(prompt: completed.response.prompt, level: level, outcome: completed.response.outcome), providerRequestCalls: bodies.count)
        }
        let orderedSummary = packageNineteenTripletSummary([atLevel(.pro), atLevel(.noob), atLevel(.amateur)], topic: "contract", repetition: 0, semanticEvaluation: ["status": "provider_free_contract_reference_not_read", "reference_read": false])
        try expect((orderedSummary["levels"] as? [String]) == [TutorExperienceLevel.noob, .amateur, .pro].map(\.rawValue),
                   "P19 triplet summary level ordering drifted")
        let fullFlags = deterministic?["final_prose_flags"] as? [String: Any]
        let noToolFlags = (noToolArtifact["deterministic_evaluation"] as? [String: Any])?["final_prose_flags"] as? [String: Any]
        try expect(fullFlags?["one_experiment_where_applicable"] as? Bool == false && noToolFlags?["one_experiment_where_applicable"] as? Bool == true && orderedSummary["deterministic_completeness_pass"] != nil,
                   "P19 completeness contract did not distinguish prose-only and exactly-one-persisted-experiment paths")
        let retryTransport = PackageNineteenRetryLoopbackStreamingTransport()
        let retryProvider = OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: retryTransport)
        let retry = await packageNineteenCloudTextWithRetry(provider: retryProvider, query: "provider-free transient retry", context: .init(sourceType: .vocal), requestCount: { retryTransport.requestCount })
        try expect(retry.outcome.terminalStatus == "completed" && retry.outcome.attempts == 2 && retry.providerRequestCalls == retryTransport.requestCount && retryTransport.requestCount == 2 && retry.failureHistory.count == 1 && retry.failureHistory.first?["safe_category"] as? String == "timeout",
                   "P19 cloud retry contract did not retain recovered transient history or bound duplicate calls")
        let postValidationTransport = PackageNineteenRetryThenUnpinnedMetadataTransport()
        let postValidationGeneration = try await packageNineteenCloudGeneration(
            prompt: .init(order: 0, topic: "contract", query: "Provider-free retry accounting."), level: .amateur, repetition: 0,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), toolsEnabled: false,
            transportFactory: { PackageNineteenRecordingForwardingTransport(base: postValidationTransport) },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let postValidationArtifact = postValidationGeneration.artifact
        let postValidationHistory = postValidationArtifact["retry_history"] as? [[String: Any]] ?? []
        try expect(postValidationGeneration.providerRequestCalls == 2 && postValidationTransport.requestCount == 2 && postValidationArtifact["provider_request_calls"] as? Int == 2 && postValidationArtifact["attempts"] as? Int == 2 && postValidationHistory.count == 2 && postValidationHistory.map { $0["attempt"] as? Int } == [1, 2] && postValidationHistory.map { $0["provider_request_calls"] as? Int } == [1, 0] && postValidationHistory.map { $0["safe_category"] as? String } == ["timeout", "provider_rejected"],
                   "P19 post-response validation rejection misreported the recovered retry attempt or duplicated provider accounting")
        let fullToolPostValidationTransport = PackageNineteenFullToolThenUnpinnedMetadataTransport()
        let fullToolPostValidation = try await packageNineteenCloudGeneration(
            prompt: .init(order: 0, topic: "contract", query: "Provider-free full-tool accounting."), level: .amateur, repetition: 0,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), toolsEnabled: true,
            transportFactory: { PackageNineteenRecordingForwardingTransport(base: fullToolPostValidationTransport) },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let fullToolPostValidationArtifact = fullToolPostValidation.artifact
        let fullToolPostValidationHistory = fullToolPostValidationArtifact["retry_history"] as? [[String: Any]] ?? []
        let fullToolCalls = fullToolPostValidationArtifact["tool_calls"] as? [[String: Any]] ?? []
        let fullToolResults = fullToolPostValidationArtifact["tool_results"] as? [[String: Any]] ?? []
        let fullToolReceipts = fullToolPostValidationArtifact["tool_receipts"] as? [[String: Any]] ?? []
        try expect(fullToolPostValidationTransport.requestCount == 2 && fullToolPostValidation.providerRequestCalls == 2 && fullToolPostValidationArtifact["terminal_status"] as? String == "failed" && fullToolPostValidationArtifact["serialized_tool_definitions_exact"] as? Bool == true && Set(fullToolPostValidationArtifact["tools_sent"] as? [String] ?? []) == Set(TutorToolExecutor.defaultDefinitions.map(\.name)) && fullToolCalls.count == 4 && fullToolResults.count == 4 && fullToolReceipts.count == 4 && fullToolPostValidationHistory.count == 1 && fullToolPostValidationHistory.first?["attempt"] as? Int == 1 && fullToolPostValidationHistory.first?["provider_request_calls"] as? Int == 0 && fullToolPostValidationHistory.first?["safe_category"] as? String == "provider_rejected",
                   "P19 full-tool post-response rejection discarded observed schemas, calls, results, or receipt telemetry")
        let preReceiptFullToolTransport = PackageNineteenPreReceiptFailureTransport()
        let preReceiptFullTool = try await packageNineteenCloudGeneration(
            prompt: .init(order: 0, topic: "contract", query: "Provider-free pre-receipt full-tool failure."), level: .amateur, repetition: 0,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), toolsEnabled: true,
            transportFactory: { PackageNineteenRecordingForwardingTransport(base: preReceiptFullToolTransport) },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let preReceiptFullToolArtifact = preReceiptFullTool.artifact
        let preReceiptFullToolDiagnostics = preReceiptFullToolArtifact["serialized_request_diagnostics"] as? [String: Any] ?? [:]
        try expect(preReceiptFullToolTransport.requestCount == 1 && preReceiptFullTool.providerRequestCalls == 1 && preReceiptFullToolArtifact["terminal_status"] as? String == "failed" && preReceiptFullToolArtifact["provider"] is NSNull && preReceiptFullToolArtifact["receipt_id"] is NSNull && Set(preReceiptFullToolArtifact["tools_sent"] as? [String] ?? []) == Set(TutorToolExecutor.defaultDefinitions.map(\.name)) && preReceiptFullToolArtifact["serialized_tool_definitions_exact"] as? Bool == true && (preReceiptFullToolArtifact["tool_calls"] as? [[String: Any]] ?? []).isEmpty && (preReceiptFullToolArtifact["tool_results"] as? [[String: Any]] ?? []).isEmpty && (preReceiptFullToolArtifact["tool_receipts"] as? [[String: Any]] ?? []).isEmpty && preReceiptFullToolDiagnostics["request_envelopes_exact"] as? Bool == true && preReceiptFullToolDiagnostics["tool_definitions_exact"] as? Bool == true && preReceiptFullToolDiagnostics["store_false"] as? Bool == true && preReceiptFullToolDiagnostics["model_pinned"] as? Bool == true && preReceiptFullToolDiagnostics["reasoning_effort_high"] as? Bool == true && preReceiptFullToolDiagnostics["service_tier_priority"] as? Bool == true,
                   "P19 pre-receipt full-tool failure fabricated empty request telemetry or provider/receipt metadata")
        let preReceiptNoToolTransport = PackageNineteenPreReceiptFailureTransport()
        let preReceiptNoTool = try await packageNineteenCloudGeneration(
            prompt: .init(order: 0, topic: "contract", query: "Provider-free pre-receipt no-tool failure."), level: .amateur, repetition: 0,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), toolsEnabled: false,
            transportFactory: { PackageNineteenRecordingForwardingTransport(base: preReceiptNoToolTransport) },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let preReceiptNoToolArtifact = preReceiptNoTool.artifact
        let preReceiptNoToolDiagnostics = preReceiptNoToolArtifact["serialized_request_diagnostics"] as? [String: Any] ?? [:]
        try expect(preReceiptNoToolTransport.requestCount == 1 && preReceiptNoTool.providerRequestCalls == 1 && preReceiptNoToolArtifact["terminal_status"] as? String == "failed" && preReceiptNoToolArtifact["provider"] is NSNull && preReceiptNoToolArtifact["receipt_id"] is NSNull && (preReceiptNoToolArtifact["tools_sent"] as? [String] ?? []).isEmpty && preReceiptNoToolArtifact["serialized_tool_definitions_exact"] as? Bool == true && preReceiptNoToolDiagnostics["request_envelopes_exact"] as? Bool == true && preReceiptNoToolDiagnostics["no_tools_exact"] as? Bool == true && preReceiptNoToolDiagnostics["store_false"] as? Bool == true && preReceiptNoToolDiagnostics["model_pinned"] as? Bool == true && preReceiptNoToolDiagnostics["reasoning_effort_high"] as? Bool == true && preReceiptNoToolDiagnostics["service_tier_priority"] as? Bool == true,
                   "P19 pre-receipt no-tool failure discarded observed envelope diagnostics or fabricated metadata")
        let mutatedGenerationTransport = PackageNineteenRetryThenPinnedJudgeTransport()
        let mutatedGeneration = try await packageNineteenCloudGeneration(
            prompt: .init(order: 0, topic: "contract", query: "Provider-free generated-envelope policy."), level: .amateur, repetition: 0,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), toolsEnabled: false,
            transportFactory: {
                PackageNineteenRecordingForwardingTransport(base: mutatedGenerationTransport, requestMutation: { request in
                    guard let object = try? JSONSerialization.jsonObject(with: request.body), var envelope = object as? [String: Any] else { return }
                    envelope["store"] = true
                    var reasoning = envelope["reasoning"] as? [String: Any] ?? [:]
                    reasoning["effort"] = TutorReasoningEffort.low.rawValue
                    envelope["reasoning"] = reasoning
                    if let mutated = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]) { request.body = mutated }
                })
            },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let mutatedGenerationArtifact = mutatedGeneration.artifact
        let mutatedGenerationHistory = mutatedGenerationArtifact["retry_history"] as? [[String: Any]] ?? []
        let mutatedGenerationDiagnostics = mutatedGenerationArtifact["serialized_request_diagnostics"] as? [String: Any] ?? [:]
        try expect(mutatedGenerationTransport.requestCount == 2 && mutatedGeneration.providerRequestCalls == 2 && mutatedGenerationArtifact["terminal_status"] as? String == "failed" && mutatedGenerationArtifact["attempts"] as? Int == 2 && mutatedGenerationHistory.count == 2 && mutatedGenerationHistory.map { $0["attempt"] as? Int } == [1, 2] && mutatedGenerationHistory.map { $0["provider_request_calls"] as? Int } == [1, 0] && mutatedGenerationHistory.map { $0["safe_category"] as? String } == ["timeout", "provider_rejected"] && mutatedGenerationDiagnostics["request_envelopes_exact"] as? Bool == false && mutatedGenerationDiagnostics["no_tools_exact"] as? Bool == true && mutatedGenerationDiagnostics["store_false"] as? Bool == false && mutatedGenerationDiagnostics["model_pinned"] as? Bool == true && mutatedGenerationDiagnostics["reasoning_effort_high"] as? Bool == false && mutatedGenerationDiagnostics["service_tier_priority"] as? Bool == true,
                   "P19 generation accepted a mutated store/reasoning serialized request envelope or lost its actual diagnostics")
        let postValidationJudgeTransport = PackageNineteenRetryThenUnpinnedJudgeMetadataTransport()
        let postValidationJudge = try await packageNineteenSupportingJudgment(
            repository: repository, prompt: lexicalPrompt, triplet: lexicalResponses,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), repetition: 0,
            transportFactory: { PackageNineteenRecordingForwardingTransport(base: postValidationJudgeTransport) },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let postValidationJudgeHistory = postValidationJudge["retry_history"] as? [[String: Any]] ?? []
        let postValidationJudgeDimensions = postValidationJudge["dimensions"] as? [String: Bool] ?? [:]
        let postValidationJudgeRequestDiagnostics = postValidationJudge["serialized_request_diagnostics"] as? [String: Any] ?? [:]
        try expect(postValidationJudgeTransport.requestCount == 2 && postValidationJudge["provider_request_calls"] as? Int == 2 && postValidationJudge["attempts"] as? Int == 2 && postValidationJudgeHistory.count == 2 && postValidationJudgeHistory.map { $0["attempt"] as? Int } == [1, 2] && postValidationJudgeHistory.map { $0["provider_request_calls"] as? Int } == [1, 0] && postValidationJudgeHistory.map { $0["safe_category"] as? String } == ["timeout", "provider_rejected"] && postValidationJudgeDimensions.count == 5 && postValidationJudgeRequestDiagnostics["request_envelopes_exact"] as? Bool == true && postValidationJudgeRequestDiagnostics["no_tools_exact"] as? Bool == true && postValidationJudgeRequestDiagnostics["store_false"] as? Bool == true && postValidationJudgeRequestDiagnostics["model_pinned"] as? Bool == true && postValidationJudgeRequestDiagnostics["reasoning_effort_high"] as? Bool == true && postValidationJudgeRequestDiagnostics["service_tier_priority"] as? Bool == true && postValidationJudge["terminal_status"] as? String == "failed" && postValidationJudge["judge_result_status"] as? String == "invalid_unpinned_provider_metadata" && postValidationJudge["safe_category"] as? String == "provider_rejected" && postValidationJudge["safe_failure"] as? String != nil,
                   "P19 supporting-judge post-response rejection misreported parsed JSON as terminal acceptance or malformed JSON")
        let mutatedJudgeTransport = PackageNineteenRetryThenPinnedJudgeTransport()
        let mutatedEnvelopeJudge = try await packageNineteenSupportingJudgment(
            repository: repository, prompt: lexicalPrompt, triplet: lexicalResponses,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), repetition: 0,
            transportFactory: {
                PackageNineteenRecordingForwardingTransport(base: mutatedJudgeTransport, requestMutation: { request in
                    guard let object = try? JSONSerialization.jsonObject(with: request.body), var envelope = object as? [String: Any] else { return }
                    envelope["store"] = true
                    if let mutated = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]) { request.body = mutated }
                })
            },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let mutatedEnvelopeHistory = mutatedEnvelopeJudge["retry_history"] as? [[String: Any]] ?? []
        let mutatedEnvelopeDiagnostics = mutatedEnvelopeJudge["serialized_request_diagnostics"] as? [String: Any] ?? [:]
        try expect(mutatedJudgeTransport.requestCount == 2 && mutatedEnvelopeJudge["provider_request_calls"] as? Int == 2 && mutatedEnvelopeJudge["attempts"] as? Int == 2 && mutatedEnvelopeHistory.count == 2 && mutatedEnvelopeHistory.map { $0["attempt"] as? Int } == [1, 2] && mutatedEnvelopeHistory.map { $0["provider_request_calls"] as? Int } == [1, 0] && mutatedEnvelopeHistory.map { $0["safe_category"] as? String } == ["timeout", "provider_rejected"] && mutatedEnvelopeJudge["terminal_status"] as? String == "failed" && mutatedEnvelopeJudge["judge_result_status"] as? String == "invalid_request_envelope" && mutatedEnvelopeDiagnostics["request_envelopes_exact"] as? Bool == false && mutatedEnvelopeDiagnostics["no_tools_exact"] as? Bool == true && mutatedEnvelopeDiagnostics["store_false"] as? Bool == false && mutatedEnvelopeDiagnostics["model_pinned"] as? Bool == true && mutatedEnvelopeDiagnostics["reasoning_effort_high"] as? Bool == true && mutatedEnvelopeDiagnostics["service_tier_priority"] as? Bool == true,
                   "P19 supporting judge accepted a mutated serialized request envelope or misreported its retry accounting")
        let extraFieldJudgeTransport = PackageNineteenExtraFieldJudgeTransport()
        let extraFieldJudgeArtifact = try await packageNineteenSupportingJudgment(
            repository: repository, prompt: lexicalPrompt, triplet: lexicalResponses,
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), repetition: 0,
            transportFactory: { PackageNineteenRecordingForwardingTransport(base: extraFieldJudgeTransport) },
            providerFactory: { transport in
                OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: transport)
            }
        )
        let extraFieldJudgeHistory = extraFieldJudgeArtifact["retry_history"] as? [[String: Any]] ?? []
        let extraFieldJudgeArtifactText = String(describing: extraFieldJudgeArtifact)
        try expect(extraFieldJudgeTransport.requestCount == 1 && extraFieldJudgeArtifact["provider_request_calls"] as? Int == 1 && extraFieldJudgeArtifact["attempts"] as? Int == 1 && extraFieldJudgeArtifact["terminal_status"] as? String == "failed" && extraFieldJudgeArtifact["judge_result_status"] as? String == "invalid_extra_fields" && extraFieldJudgeArtifact["safe_category"] as? String == "malformed_provider_response" && extraFieldJudgeArtifact["safe_failure"] as? String != nil && extraFieldJudgeHistory.count == 1 && extraFieldJudgeHistory.first?["attempt"] as? Int == 1 && extraFieldJudgeHistory.first?["provider_request_calls"] as? Int == 0 && extraFieldJudgeHistory.first?["safe_category"] as? String == "malformed_provider_response" && (extraFieldJudgeArtifact["dimensions"] as? [String: Bool] ?? [:]).isEmpty && extraFieldJudgeArtifact["judge_text"] == nil && (extraFieldJudgeArtifact["judge_text_sha256"] as? String)?.count == 64 && (extraFieldJudgeArtifact["judge_text_bytes"] as? Int ?? 0) > 0 && extraFieldJudgeArtifact["hidden_reasoning_stored"] as? Bool == false && !extraFieldJudgeArtifactText.contains("reference-derived explanation"),
                   "P19 supporting judge accepted or retained an extra-field rationale/reference response")
        let completedThenErrorTransport = PackageNineteenCompletedThenErrorTransport()
        let completedThenErrorProvider = OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: completedThenErrorTransport)
        let completedThenError = await packageNineteenCloudTextWithRetry(provider: completedThenErrorProvider, query: "provider-free completion boundary", context: .init(sourceType: .vocal), requestCount: { completedThenErrorTransport.requestCount })
        try expect(completedThenError.outcome.terminalStatus == "completed" && completedThenError.outcome.attempts == 1 && completedThenErrorTransport.requestCount == 1 && completedThenError.durableCompletionWarning != nil,
                   "P19 cloud retry contract retried a stream that had already completed")
        let fallbackTransport = PackageNineteenEngineTimeoutTransport()
        let fallbackProvider = OpenAITutorProvider(configuration: .init(modelIdentifier: "gpt-test", cloudTextConsent: true), credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]), transport: fallbackTransport)
        let fallbackRoot = temporaryRoot("p19-engine-fallback-contract"); defer { try? FileManager.default.removeItem(at: fallbackRoot) }
        let fallbackEngine = TutorConversationEngine(store: TutorConversationStore(rootURL: fallbackRoot), tools: try TutorToolExecutor(), fallbackProvider: try OfflineTutorProvider())
        let fallbackEvents = try await collectTurn(fallbackEngine, "Compare one reversible adjustment.", .init(sourceType: .vocal, consent: .init(cloudTextGranted: true)), fallbackProvider)
        guard let fallbackReceipt = fallbackEvents.compactMap({ if case let .completed(_, receipt) = $0 { return receipt }; return nil }).last,
              let fallbackReason = fallbackReceipt.fallbackReason else {
            throw TestFailure(description: "P19 engine fallback contract did not persist a durable fallback receipt")
        }
        let fallbackHistory = packageNineteenEngineFallbackHistory(attempt: 1, fallbackReason: fallbackReason, providerRequestCalls: fallbackTransport.requestCount, latencyMilliseconds: 0)
        let fallbackEvent: [String: Any] = fallbackHistory.first ?? [:]
        let fallbackCategory = fallbackEvent["safe_category"] as? String
        let fallbackRetried = fallbackEvent["retry_performed"] as? Bool
        let fallbackDurable = fallbackEvent["durable_fallback_completed"] as? Bool
        try expect(fallbackTransport.requestCount == 1 && fallbackHistory.count == 1 && fallbackCategory == "timeout" && fallbackRetried == false && fallbackDurable == true,
                   "P19 engine fallback contract retried or failed to retain the primary timed-out provider attempt")
        let validJudge = packageNineteenParseSupportingJudgeJSON(#"{"usefulness":true,"evidence_honesty":true,"strict_level_invariance":false,"experiment_completeness":true,"exact_procedure_necessity":false}"#)
        let invalidJudge = packageNineteenParseSupportingJudgeJSON(#"{"usefulness":true}"#)
        let extraFieldJudge = packageNineteenParseSupportingJudgeJSON(#"{"usefulness":true,"evidence_honesty":true,"strict_level_invariance":false,"experiment_completeness":true,"exact_procedure_necessity":false,"rationale":"reference-derived explanation"}"#)
        let numericJudge = packageNineteenParseSupportingJudgeJSON(#"{"usefulness":1,"evidence_honesty":true,"strict_level_invariance":false,"experiment_completeness":true,"exact_procedure_necessity":false}"#)
        try expect(validJudge.status == "valid" && validJudge.dimensions.count == 5 && invalidJudge.status == "invalid_missing_or_nonboolean_dimensions" && extraFieldJudge.status == "invalid_extra_fields" && numericJudge.status == "invalid_missing_or_nonboolean_dimensions",
                   "P19 supporting-judge JSON contract accepted extra, non-boolean, or incomplete dimensions")
        let pinnedMetadata = TutorProviderMetadata(providerIdentifier: OpenAITutorProvider().providerIdentifier, modelIdentifier: "gpt-5.6-sol", serviceTier: .priority)
        try expect(Self.packageNineteenCloudMetadataIsPinned(pinnedMetadata) && !Self.packageNineteenCloudMetadataIsPinned(.init(providerIdentifier: "other", modelIdentifier: "gpt-5.6-sol", serviceTier: .priority)) && !Self.packageNineteenCloudMetadataIsPinned(.init(providerIdentifier: OpenAITutorProvider().providerIdentifier, modelIdentifier: "gpt-other", serviceTier: .priority)) && !Self.packageNineteenCloudMetadataIsPinned(.init(providerIdentifier: OpenAITutorProvider().providerIdentifier, modelIdentifier: "gpt-5.6-sol", serviceTier: .fast)),
                   "P19 provider/model/priority metadata gate did not fail closed")
        let unavailableResult: [[String: Any]] = [["name": "get_logic_procedure", "reviewed_or_procedure_found": false, "reviewed_or_procedure_status": "unavailable"]]
        let procedureWithDisclosure = packageNineteenDeterministicEvaluation(text: "The exact reviewed procedure or navigation is unavailable and not verified.", experiment: nil, persistedExperimentCount: 0, toolCalls: [["name": "get_logic_procedure"]], toolResults: unavailableResult, receiptBinding: true, permittedToolAuthority: true, topic: "cannot_find", toolsEnabled: true)
        let procedureWithoutDisclosure = packageNineteenDeterministicEvaluation(text: "The microphone is unavailable, so try the next setting.", experiment: nil, persistedExperimentCount: 0, toolCalls: [["name": "get_logic_procedure"], ["name": "inspect_logic"]], toolResults: unavailableResult, receiptBinding: true, permittedToolAuthority: true, topic: "cannot_find", toolsEnabled: true)
        let withProcedure = procedureWithDisclosure["exact_procedure_necessity"] as? [String: Any]
        let withoutProcedure = procedureWithoutDisclosure["exact_procedure_necessity"] as? [String: Any]
        try expect(withProcedure?["status"] as? String == "satisfied" && withProcedure?["tool_result_unavailable"] as? Bool == true && withProcedure?["prose_unavailable_disclosure"] as? Bool == true && withoutProcedure?["status"] as? String == "missing" && withoutProcedure?["prose_unavailable_disclosure"] as? Bool == false,
                   "P19 cannot-find procedure contract accepted unavailable tooling without honest prose disclosure with=\(withProcedure ?? [:]) without=\(withoutProcedure ?? [:])")
    }

    private func packageNineteenLoopbackProvider(transport: PackageNineteenLoopbackStreamingTransport) -> OpenAITutorProvider {
        OpenAITutorProvider(
            configuration: .init(modelIdentifier: "gpt-test", cloudTextConsent: true),
            credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "p19-local-only-fixture"]),
            transport: transport
        )
    }

    private func packageNineteenRequestBody(_ data: Data) throws -> [String: Any]? {
        try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func packageNineteenPriorExperiment() -> TutorExperimentRecord {
        TutorExperimentRecord(
            draft: TutorExperimentDraft(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000039")!,
                title: "Decisive baseline low-mid comparison",
                logicLocation: "User-selected vocal channel",
                action: "Keep the successful baseline available for comparison.",
                startingRange: "No new setting during this retained-context check.",
                listenFor: "Whether the prior better result remains the stated baseline.",
                why: "The harness verifies retrieval of the user-recorded outcome, not a causal conclusion.",
                risk: "Replacing the baseline would weaken the comparison.",
                stopCondition: "Stop if the baseline identity is no longer clear.",
                undo: "Return to the saved baseline.",
                visualTargetQuery: nil
            ),
            createdAt: Date(timeIntervalSince1970: 1_786_300_000),
            outcome: .better,
            userNote: "Decisive user-reported better outcome."
        )
    }

    private func packageNineteenCapture(_ identifier: String) -> TutorCaptureSnapshot {
        let id = UUID(uuidString: identifier)!
        return TutorCaptureSnapshot(
            sourceType: .vocal,
            instanceID: UUID(uuidString: "00000000-0000-0000-0000-000000000049")!,
            runtimeEpoch: UUID(uuidString: "00000000-0000-0000-0000-000000000059")!,
            captureSnapshotID: id,
            sha256: String(repeating: identifier.hasSuffix("29") ? "b" : "a", count: 64),
            capturedAt: Date(timeIntervalSince1970: 1_786_300_000),
            durationSeconds: 8,
            scopeDescription: "Deterministic local capture context.",
            formatDescription: "48000 Hz mono WAV",
            isLive: true,
            metrics: [TutorMetricEvidence(identifier: "local_capture_context_metric", value: 0.2, unit: "ratio", confidence: 0.8, interpretationBoundary: "Local measurement; not model listening.")],
            localAnalysisLimitations: ["No audio bytes are uploaded in the provider-free harness."]
        )
    }

    /// Topic-specific injected state is evaluation-only. It gives each cloud
    /// case a deterministic source/capture/control identity without claiming a
    /// real Logic observation or uploading any audio.
    private func packageNineteenTopicFixture(_ prompt: PackageSeventeenCloudPrompt) -> PackageNineteenTopicFixture {
        let source: SourceType
        let control: String
        switch prompt.topic {
        case "midi_groove": source = .keyboard; control = "Quantize controls"
        case "flex_artifact": source = .vocal; control = "Flex Time controls"
        case "sidechain_trigger": source = .drumBus; control = "Side Chain input"
        case "bounce_tail": source = .fullMix; control = "Bounce tail setting"
        case "layering_redundancy": source = .vocalBus; control = "Track Stack disclosure"
        case "automation_owner": source = .vocal; control = "Automation mode"
        case "duplicate_monitoring": source = .vocal; control = "Input Monitoring"
        case "compression_sibilance": source = .vocal; control = "De-esser threshold"
        case "eq_tradeoff", "vocal_masking": source = .vocal; control = "Channel EQ"
        default: source = .vocal; control = "Exact-control lookup"
        }
        let suffix = String(format: "%012d", prompt.order + 700)
        let captureID = UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
        let marker = String(UnicodeScalar(97 + (prompt.order % 20))!)
        // This information is deliberately natural and label-free because it
        // crosses the provider/tool boundary. The topic identity is retained
        // only in the post-generation artifact below.
        let limitation = "Read-only local context; it is not a Logic observation or an audio-listening claim."
        let capture = TutorCaptureSnapshot(
            sourceType: source, instanceID: UUID(uuidString: "00000000-0000-0000-0000-000000000149")!, runtimeEpoch: UUID(uuidString: "00000000-0000-0000-0000-000000000159")!, captureSnapshotID: captureID,
            sha256: String(repeating: marker, count: 64), capturedAt: Date(timeIntervalSince1970: 1_786_300_000), durationSeconds: 8,
            scopeDescription: "Current source capture context", formatDescription: "48000 Hz mono local context", isLive: true,
            metrics: [.init(identifier: "local_source_balance_metric", value: Double(prompt.order + 1) / 100, unit: "ratio", confidence: 0.8, interpretationBoundary: limitation)],
            localAnalysisLimitations: [limitation]
        )
        return .init(sourceType: source, capture: capture, logicControl: control, limitation: limitation, identity: ["topic": prompt.topic, "source_type": source.rawValue, "capture_snapshot_id": captureID.uuidString, "capture_sha256": capture.sha256, "logic_control": control, "limitation": limitation])
    }

    /// Executable opt-in cloud harness. It stays outside deterministic runs:
    /// without the exact consent flag it fails before any provider/transport is
    /// constructed. Full-tool and repeated-triplet lanes share the real engine
    /// path; artifacts derive from sent envelopes and durable receipts.
    private func testPackageNineteenCloud(_ lane: PackageNineteenCloudLane) async throws {
        guard CommandLine.arguments.contains("--cloud-text-consent") else {
            throw TestFailure(description: "Package 019 cloud harness requires --cloud-text-consent; zero provider requests were sent")
        }
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let configuration = TutorProviderConfiguration(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .priority, cloudTextConsent: true)
        try expect(Self.packageSeventeenCloudConfigurationIsPinned(configuration), "P19 cloud harness requires gpt-5.6-sol, high effort, and priority service tier")
        let prompts = try packageNineteenCloudPrompts(repository: repository)
        let levels: [TutorExperienceLevel] = [.noob, .amateur, .pro]
        let repetitions = lane == .repeatedTriplets ? 3 : 1
        let toolsEnabled = lane != .noTool
        var generations: [PackageNineteenCloudGeneration] = []
        var triplets: [[String: Any]] = []
        var supportingJudgments: [[String: Any]] = []

        for repetition in 0..<repetitions {
            for prompt in prompts {
                var topicTriplet: [PackageNineteenCloudGeneration] = []
                for level in levels {
                    let generation = try await packageNineteenCloudGeneration(
                        prompt: prompt, level: level, repetition: repetition,
                        configuration: configuration, toolsEnabled: toolsEnabled
                    )
                    topicTriplet.append(generation); generations.append(generation)
                }
                // Evaluation-only references remain unopened unless the three
                // original samples for this topic/repetition all completed.
                let generationComplete = packageNineteenTripletIsGenerationComplete(topicTriplet)
                let semanticEvaluation: [String: Any]
                if generationComplete {
                    do { semanticEvaluation = try packageNineteenDeterministicSemanticEvaluation(repository: repository, prompt: prompt, triplet: topicTriplet.map(\.response)) }
                    catch { semanticEvaluation = ["status": "reference_unavailable_after_generation", "reference_read": false, "safe_failure": "Evaluation-only semantic reference was unavailable after generation."] }
                } else {
                    semanticEvaluation = ["status": "not_run_incomplete_generation", "reference_read": false]
                }
                triplets.append(packageNineteenTripletSummary(topicTriplet, topic: prompt.topic, repetition: repetition, semanticEvaluation: semanticEvaluation))
                if generationComplete {
                    do {
                        let judgment = try await packageNineteenSupportingJudgment(
                            repository: repository, prompt: prompt,
                            triplet: topicTriplet.map(\.response), configuration: configuration,
                            repetition: repetition
                        )
                        supportingJudgments.append(judgment)
                    } catch {
                        let safe = (error as? TutorConversationError)?.safeFailureDescription ?? "The post-generation supporting judgment failed safely."
                        supportingJudgments.append(["topic": prompt.topic, "repetition": repetition, "status": "failed", "semantic_reference_read": false, "provider_request_calls": 0, "safe_failure": Self.boundedEvaluationText(safe, maximumUTF8Bytes: 768), "hidden_reasoning_stored": false])
                    }
                } else {
                    supportingJudgments.append([
                        "topic": prompt.topic, "repetition": repetition,
                        "status": "skipped_incomplete_generation",
                        "semantic_reference_read": false,
                        "boundary": "No reference was read or sent because the original generation triplet was incomplete.",
                    ])
                }
            }
        }
        let attempts = generations.map(\.artifact)
        let failures = attempts.filter { ($0["terminal_status"] as? String) != "completed" }
        let judgmentFailures = supportingJudgments.filter { ($0["terminal_status"] as? String) == "failed" || ($0["status"] as? String) == "failed" }
        let generationFailureHistory = attempts.flatMap { $0["retry_history"] as? [[String: Any]] ?? [] }
        let judgmentFailureHistory = supportingJudgments.flatMap { $0["retry_history"] as? [[String: Any]] ?? [] }
        let allFailureHistory = generationFailureHistory + judgmentFailureHistory
        let completedFailureHistory = attempts.filter { ($0["terminal_status"] as? String) == "completed" }.flatMap { $0["retry_history"] as? [[String: Any]] ?? [] }
            + supportingJudgments.filter { ($0["terminal_status"] as? String) == "completed" }.flatMap { $0["retry_history"] as? [[String: Any]] ?? [] }
        let timeoutAttemptCount = allFailureHistory.filter { ($0["safe_category"] as? String) == "timeout" }.count
        let recoveredRetryTimeoutCount = completedFailureHistory.filter { ($0["safe_category"] as? String) == "timeout" }.count
        let terminalTimeoutAttemptCount = timeoutAttemptCount - recoveredRetryTimeoutCount
        func terminalTimeout(_ item: [String: Any]) -> Bool {
            let status = item["terminal_status"] as? String ?? item["status"] as? String ?? ""
            let safe = item["safe_failure"] as? String ?? ""
            return status != "completed" && (safe.localizedCaseInsensitiveContains("timed out") || safe.localizedCaseInsensitiveContains("timeout"))
        }
        let terminalTimeoutSampleCount = attempts.filter(terminalTimeout).count + supportingJudgments.filter(terminalTimeout).count
        let providerRequestCalls = generations.reduce(0) { $0 + $1.providerRequestCalls }
            + supportingJudgments.reduce(0) { $0 + (($1["provider_request_calls"] as? Int) ?? 0) }
        let artifact: [String: Any] = [
            "schema_version": "package019-cloud-evaluation/2",
            "package": "019",
            "lane": packageNineteenLaneName(lane),
            "lane_semantics": toolsEnabled ? "real TutorConversationEngine + all seven production tools; repeated lane independently repeats this exact path" : "current-policy provider-only comparison with no tools sent",
            "source_identity": packageNineteenSourceIdentity(repository),
            "evaluation_hashes": try packageNineteenEvaluationHashes(repository, prompts: prompts),
            "configuration": ["provider": OpenAITutorProvider().providerIdentifier, "model": configuration.modelIdentifier, "reasoning_effort": configuration.reasoningEffort.rawValue, "service_tier": packageNineteenJSONOrNull(configuration.serviceTier?.rawValue), "store": false, "cloud_text_consent": "explicit --cloud-text-consent", "audio_present": false, "logic_context": toolsEnabled ? "deterministic injected read-only context" : "historical_p17_no_tool_context_source_vocal_plus_level_only"],
            "counts": ["exact_prompt_count": prompts.count, "prompt_count": prompts.count, "levels": levels.map(\.rawValue), "level_count": levels.count, "repetitions": repetitions, "generation_samples": attempts.count, "provider_request_calls": providerRequestCalls, "tool_enabled_samples": attempts.filter { (($0["tools_sent"] as? [String]) ?? []).isEmpty == false }.count, "supporting_judgments": supportingJudgments.count],
            "retry_policy": [
                "by_lane": [
                    "full_tool": ["maximum_turn_attempts": 1, "durable_fallback_retried": false],
                    "repeated_triplets": ["maximum_turn_attempts": 1, "durable_fallback_retried": false],
                    "no_tool": ["maximum_attempts": 2, "retry_only_typed_transient": true, "completed_after_error_retained": true],
                    "supporting_judge": ["maximum_attempts": 2, "retry_only_typed_transient": true, "completed_after_error_retained": true],
                ],
                "completed_requests_retried": 0,
                "recovered_or_terminal_failure_history": allFailureHistory,
            ],
            "tokens": ["input": "per-attempt provider metadata", "output": "per-attempt provider metadata"],
            "latency_ms": ["first_token": NSNull(), "total_turn": "per-attempt measured value"], "cost": NSNull(),
            "attempts": attempts,
            "deterministic_triplet_summaries": triplets,
            "supporting_model_assisted_judgments": supportingJudgments,
            "owner_artistic_or_usability_judgment": "not_run_no_owner_review",
            "failure_count": allFailureHistory.count,
            "terminal_failure_sample_count": failures.count + judgmentFailures.count,
            "recovered_retry_timeout_count": recoveredRetryTimeoutCount,
            "terminal_timeout_attempt_count": terminalTimeoutAttemptCount,
            "terminal_timeout_sample_count": terminalTimeoutSampleCount,
            "timeout_count": timeoutAttemptCount,
            "partial_failure_honesty": "Artifact is atomically written after all attempted samples; failed/incomplete samples remain explicit and are never reused as completed responses.",
            "generation_reference_firewall": "No evaluation-only semantic reference is read or sent until all three original level responses for that topic/repetition complete. Hidden reasoning is never stored.",
        ]
        try packageNineteenWriteCloudArtifact(artifact, lane: lane, repository: repository)
        guard failures.isEmpty && judgmentFailures.isEmpty else {
            throw TestFailure(description: "Package 019 cloud harness wrote an honest partial artifact with \(failures.count) failed or fallback-excluded generation samples and \(judgmentFailures.count) failed or invalid supporting judgments")
        }
        print("P19_CLOUD_HARNESS_OK lane=\(packageNineteenLaneName(lane)) samples=\(attempts.count) providerRequests=\(providerRequestCalls) store=false")
    }

    private func packageNineteenCloudGeneration(
        prompt: PackageSeventeenCloudPrompt,
        level: TutorExperienceLevel,
        repetition: Int,
        configuration: TutorProviderConfiguration,
        toolsEnabled: Bool,
        transportFactory: (() -> PackageNineteenRecordingForwardingTransport)? = nil,
        providerFactory: ((PackageNineteenRecordingForwardingTransport) -> OpenAITutorProvider)? = nil
    ) async throws -> PackageNineteenCloudGeneration {
        var totalRequests = 0
        var retryHistory: [[String: Any]] = []
        let fixture = toolsEnabled ? packageNineteenTopicFixture(prompt) : nil
        // The engine owns durable fallback for a tool turn. It is therefore
        // one turn only: retrying a completed/fallback receipt would duplicate
        // a user-visible turn. Direct provider-only/judge paths may retry once.
        for attempt in 1...1 {
            let transport = transportFactory?() ?? PackageNineteenRecordingForwardingTransport()
            let provider = providerFactory?(transport) ?? OpenAITutorProvider(configuration: configuration, transport: transport)
            let started = Date()
            var attemptRequestsCounted = false
            var terminalAttemptCount = attempt
            var observedTelemetry: [String: Any]?
            var observedRequestDiagnostics: [String: Any]?
            var observedReceipt: TutorEvidenceReceipt?
            var observedMetadata: TutorProviderMetadata?
            var observedText = ""
            var observedExperiment: TutorExperimentRecord?
            var observedPersistedExperimentCount = 0
            do {
                if toolsEnabled {
                    let root = temporaryRoot("p19-cloud-\(repetition)-\(prompt.order)-\(level.rawValue)-\(attempt)")
                    defer { try? FileManager.default.removeItem(at: root) }
                    let prior = TutorExperimentRecord(draft: experimentDraft(title: "Saved baseline comparison"), outcome: .noChange)
                    let executor = try TutorToolExecutor(
                        observeLogic: { _ in .init(status: .observed, applicationName: "Logic Pro", bundleIdentifier: "com.apple.logic10", windowTitle: "Current channel inspector", controls: [.init(role: "AXButton", label: fixture?.logicControl ?? "Current control", value: "available", frame: .init(x: 1, y: 1, width: 1, height: 1))], limitation: fixture?.limitation ?? "Read-only local context.") },
                        priorExperiments: { [prior] }
                    )
                    let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: root), tools: executor, fallbackProvider: try OfflineTutorProvider())
                    let context = TutorRuntimeContext(sourceType: fixture?.sourceType ?? .vocal, projectGoal: "Assess one reversible change for the current source without assuming the cause.", capture: fixture?.capture, consent: .init(cloudTextGranted: true), experience: .init(persistentLevel: level))
                    let events = try await collectTurn(engine, prompt.query, context, provider)
                    guard let receipt = events.compactMap({ if case let .completed(_, receipt) = $0 { return receipt }; return nil }).last else {
                        throw TutorConversationError.malformedProviderResponse("Cloud tool harness completed without a receipt.")
                    }
                    let state = await engine.snapshot()
                    let text = state.messages.last?.text ?? ""
                    let telemetry = packageNineteenObservedEnvelopeTelemetry(transport.requestBodies())
                    let requestDiagnostics = packageNineteenRequestDiagnostics(transport.requestBodies(), toolsEnabled: true)
                    observedTelemetry = telemetry
                    observedRequestDiagnostics = requestDiagnostics
                    observedReceipt = receipt
                    observedMetadata = receipt.provider
                    observedText = text
                    observedExperiment = state.experiments.last
                    observedPersistedExperimentCount = state.experiments.count
                    let sent = telemetry["tools_sent"] as? [String] ?? []
                    guard Set(sent) == Set(TutorToolExecutor.defaultDefinitions.map(\.name)), sent.count == TutorToolExecutor.defaultDefinitions.count,
                          packageNineteenExactSerializedToolSchemas(actual: telemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: telemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: telemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: telemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], conflict: telemetry["tool_schema_conflict"] as? Bool ?? true, invalid: telemetry["invalid_tool_schema_entry"] as? Bool ?? true, callConflict: telemetry["tool_call_conflict"] as? Bool ?? true, outputConflict: telemetry["tool_output_conflict"] as? Bool ?? true, invalidCallOrOutput: telemetry["invalid_tool_call_or_output"] as? Bool ?? true, toolsEnabled: true) else {
                        throw TutorConversationError.malformedProviderResponse("Cloud full-tool harness did not serialize exactly the seven production tool definitions.")
                    }
                    guard requestDiagnostics["request_envelopes_exact"] as? Bool == true else {
                        throw TutorConversationError.providerRejected("Cloud full-tool harness rejected its serialized request envelope.")
                    }
                    guard packageNineteenProviderFacingBoundaryIsClean(bodies: transport.requestBodies()) else {
                        throw TutorConversationError.malformedProviderResponse("Cloud full-tool harness blocked evaluator-label leakage into a provider request or tool output.")
                    }
                    totalRequests += transport.requestCount
                    attemptRequestsCounted = true
                    let terminalStatus = receipt.fallbackReason == nil ? "completed" : "completed_with_fallback_excluded"
                    if terminalStatus == "completed", !Self.packageNineteenCloudMetadataIsPinned(receipt.provider) {
                        throw TutorConversationError.providerRejected("Cloud tool harness rejected unpinned completed provider metadata.")
                    }
                    if let fallback = receipt.fallbackReason {
                        retryHistory.append(contentsOf: packageNineteenEngineFallbackHistory(attempt: attempt, fallbackReason: fallback, providerRequestCalls: transport.requestCount, latencyMilliseconds: Date().timeIntervalSince(started) * 1_000))
                    }
                    var artifact = packageNineteenGenerationArtifact(
                        prompt: prompt, level: level, repetition: repetition, attempt: attempt,
                        terminalStatus: terminalStatus, text: text, metadata: receipt.provider,
                        telemetry: telemetry, receipt: receipt, experiment: state.experiments.last, persistedExperimentCount: state.experiments.count,
                        latencyMeasured: Date().timeIntervalSince(started) * 1_000,
                        toolsEnabled: true, safeFailure: receipt.fallbackReason, fixtureIdentity: fixture?.identity ?? [:], laneContext: "topic_specific_tool_context", retryHistory: retryHistory, requestDiagnostics: requestDiagnostics
                    )
                    artifact["provider_request_calls"] = totalRequests
                    // The engine produced a durable completion (even if it had
                    // to fall back); never duplicate it by retrying.
                    let outcome = PackageSeventeenCloudRequestOutcome(text: terminalStatus == "completed" ? text : nil, metadata: receipt.provider, attempts: attempt, terminalStatus: terminalStatus, safeFailure: receipt.fallbackReason)
                    return .init(artifact: artifact, response: .init(prompt: prompt, level: level, outcome: outcome), providerRequestCalls: totalRequests)
                }

                // Lane A intentionally mirrors the historical P17 no-tool
                // baseline: only vocal source type and selected level cross
                // the provider boundary; no capture/project/topic fixture does.
                let direct = await packageNineteenCloudTextWithRetry(provider: provider, query: prompt.query, context: .init(sourceType: .vocal, experience: .init(persistentLevel: level)), requestCount: { transport.requestCount })
                totalRequests += direct.providerRequestCalls
                attemptRequestsCounted = true
                terminalAttemptCount = direct.outcome.attempts
                retryHistory.append(contentsOf: direct.failureHistory)
                let telemetry = packageNineteenObservedEnvelopeTelemetry(transport.requestBodies())
                let requestDiagnostics = packageNineteenRequestDiagnostics(transport.requestBodies(), toolsEnabled: false)
                observedTelemetry = telemetry
                observedRequestDiagnostics = requestDiagnostics
                observedMetadata = direct.outcome.metadata
                observedText = direct.outcome.text ?? ""
                guard direct.outcome.terminalStatus == "completed", let generatedText = direct.outcome.text, let generatedMetadata = direct.outcome.metadata else {
                    let safe = direct.outcome.safeFailure ?? "The cloud evaluator request failed safely."
                    var artifact = packageNineteenGenerationArtifact(
                        prompt: prompt, level: level, repetition: repetition, attempt: direct.outcome.attempts,
                        terminalStatus: "failed", text: observedText, metadata: observedMetadata,
                        telemetry: telemetry, receipt: nil, experiment: nil, persistedExperimentCount: 0,
                        latencyMeasured: Date().timeIntervalSince(started) * 1_000,
                        toolsEnabled: false, safeFailure: safe, fixtureIdentity: [:], laneContext: "historical_p17_no_tool_context_source_vocal_plus_level_only", retryHistory: retryHistory, requestDiagnostics: requestDiagnostics
                    )
                    artifact["provider_request_calls"] = totalRequests
                    return .init(artifact: artifact, response: .init(prompt: prompt, level: level, outcome: direct.outcome), providerRequestCalls: totalRequests)
                }
                guard packageNineteenExactSerializedToolSchemas(actual: telemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:], envelopes: telemetry["tool_schema_envelopes"] as? [[String: String]] ?? [], envelopeEntryCounts: telemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [], envelopeDuplicateNames: telemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [], conflict: telemetry["tool_schema_conflict"] as? Bool ?? true, invalid: telemetry["invalid_tool_schema_entry"] as? Bool ?? true, callConflict: telemetry["tool_call_conflict"] as? Bool ?? true, outputConflict: telemetry["tool_output_conflict"] as? Bool ?? true, invalidCallOrOutput: telemetry["invalid_tool_call_or_output"] as? Bool ?? true, toolsEnabled: false) else {
                    throw TutorConversationError.malformedProviderResponse("Cloud no-tool harness serialized malformed or nonempty tool definitions.")
                }
                guard requestDiagnostics["request_envelopes_exact"] as? Bool == true else {
                    throw TutorConversationError.providerRejected("Cloud no-tool harness rejected its serialized request envelope.")
                }
                guard packageNineteenProviderFacingBoundaryIsClean(bodies: transport.requestBodies()) else {
                    throw TutorConversationError.malformedProviderResponse("Cloud no-tool harness blocked evaluator-label leakage into a provider request.")
                }
                guard Self.packageNineteenCloudMetadataIsPinned(generatedMetadata) else {
                    throw TutorConversationError.providerRejected("Cloud no-tool harness rejected unpinned completed provider metadata.")
                }
                var artifact = packageNineteenGenerationArtifact(
                    prompt: prompt, level: level, repetition: repetition, attempt: direct.outcome.attempts,
                    terminalStatus: "completed", text: generatedText, metadata: generatedMetadata,
                    telemetry: telemetry, receipt: nil, experiment: nil, persistedExperimentCount: 0,
                    latencyMeasured: Date().timeIntervalSince(started) * 1_000,
                    toolsEnabled: false, safeFailure: direct.durableCompletionWarning, fixtureIdentity: [:], laneContext: "historical_p17_no_tool_context_source_vocal_plus_level_only", retryHistory: retryHistory, requestDiagnostics: requestDiagnostics
                )
                artifact["provider_request_calls"] = totalRequests
                let outcome = PackageSeventeenCloudRequestOutcome(text: generatedText, metadata: generatedMetadata, attempts: direct.outcome.attempts, terminalStatus: "completed", safeFailure: nil)
                return .init(artifact: artifact, response: .init(prompt: prompt, level: level, outcome: outcome), providerRequestCalls: totalRequests)
            } catch {
                let failureRequestCalls = attemptRequestsCounted ? 0 : transport.requestCount
                if !attemptRequestsCounted { totalRequests += failureRequestCalls }
                let safe = (error as? TutorConversationError)?.safeFailureDescription ?? "The Package 019 cloud evaluator request failed safely."
                let transient = Self.isTransientCloudEvaluationFailure(error)
                let failure = packageNineteenRetryFailureArtifact(attempt: terminalAttemptCount, error: error, safeFailure: safe, providerRequestCalls: failureRequestCalls, latencyMilliseconds: Date().timeIntervalSince(started) * 1_000)
                retryHistory.append(failure)
                if !toolsEnabled, transient, attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(250)); continue
                }
                let failureTelemetry = observedTelemetry ?? packageNineteenObservedEnvelopeTelemetry(transport.requestBodies())
                let failureRequestDiagnostics = observedRequestDiagnostics ?? packageNineteenRequestDiagnostics(transport.requestBodies(), toolsEnabled: toolsEnabled)
                var artifact = packageNineteenGenerationArtifact(
                    prompt: prompt, level: level, repetition: repetition, attempt: terminalAttemptCount,
                    terminalStatus: "failed", text: observedText, metadata: observedMetadata,
                    telemetry: failureTelemetry, receipt: observedReceipt, experiment: observedExperiment, persistedExperimentCount: observedPersistedExperimentCount,
                    latencyMeasured: Date().timeIntervalSince(started) * 1_000,
                    toolsEnabled: toolsEnabled, safeFailure: safe, fixtureIdentity: fixture?.identity ?? [:], laneContext: toolsEnabled ? "topic_specific_tool_context" : "historical_p17_no_tool_context_source_vocal_plus_level_only", retryHistory: retryHistory, requestDiagnostics: failureRequestDiagnostics
                )
                artifact["provider_request_calls"] = totalRequests
                let outcome = PackageSeventeenCloudRequestOutcome(text: nil, metadata: nil, attempts: terminalAttemptCount, terminalStatus: "failed", safeFailure: safe)
                return .init(artifact: artifact, response: .init(prompt: prompt, level: level, outcome: outcome), providerRequestCalls: totalRequests)
            }
        }
        throw TutorConversationError.providerRejected("Package 019 cloud retry loop exhausted unexpectedly.")
    }

    /// The P19 artifact retains every failed transient attempt even when the
    /// second bounded attempt succeeds. This is separate from the historical
    /// P17 outcome type, whose persisted records remain unchanged.
    private func packageNineteenCloudTextWithRetry(
        provider: OpenAITutorProvider,
        query: String,
        context: TutorRuntimeContext,
        requestCount: @escaping () -> Int
    ) async -> PackageNineteenRetryResult {
        var history: [[String: Any]] = []
        var providerRequestCalls = 0
        for attempt in 1...2 {
            let started = Date()
            let requestsBefore = requestCount()
            do {
                var text = ""; var completed: TutorProviderMetadata?
                do {
                    for try await event in provider.stream(.init(messages: [.init(role: .user, text: query)], context: context, tools: [])) {
                        switch event {
                        case let .textDelta(delta): text += delta
                        case let .completed(metadata, output):
                            completed = metadata
                            if text.isEmpty { text = output.compactMap { if case let .text(value) = $0 { value } else { nil } }.joined() }
                        }
                    }
                } catch {
                    let callsForAttempt = max(0, requestCount() - requestsBefore)
                    if let completed, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        providerRequestCalls += callsForAttempt
                        return .init(outcome: .init(text: text, metadata: completed, attempts: attempt, terminalStatus: "completed", safeFailure: nil), failureHistory: history, providerRequestCalls: providerRequestCalls, durableCompletionWarning: "Provider stream ended after completed metadata; durable completion retained and not retried.")
                    }
                    throw error
                }
                guard let completed, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw TutorConversationError.malformedProviderResponse("Cloud evaluator completed without text.")
                }
                providerRequestCalls += max(0, requestCount() - requestsBefore)
                return .init(outcome: .init(text: text, metadata: completed, attempts: attempt, terminalStatus: "completed", safeFailure: nil), failureHistory: history, providerRequestCalls: providerRequestCalls, durableCompletionWarning: nil)
            } catch {
                let callsForAttempt = max(0, requestCount() - requestsBefore)
                providerRequestCalls += callsForAttempt
                let safe = (error as? TutorConversationError)?.safeFailureDescription ?? "The cloud evaluator request failed safely."
                let transient = Self.isTransientCloudEvaluationFailure(error)
                history.append(packageNineteenRetryFailureArtifact(attempt: attempt, error: error, safeFailure: safe, providerRequestCalls: callsForAttempt, latencyMilliseconds: Date().timeIntervalSince(started) * 1_000))
                if transient && attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(250))
                    continue
                }
                return .init(outcome: .init(text: nil, metadata: nil, attempts: attempt, terminalStatus: "failed", safeFailure: safe), failureHistory: history, providerRequestCalls: providerRequestCalls, durableCompletionWarning: nil)
            }
        }
        return .init(outcome: .init(text: nil, metadata: nil, attempts: 2, terminalStatus: "failed", safeFailure: "The cloud evaluator request failed safely."), failureHistory: history, providerRequestCalls: providerRequestCalls, durableCompletionWarning: nil)
    }

    private func packageNineteenRetryFailureArtifact(attempt: Int, error: Error, safeFailure: String, providerRequestCalls: Int, latencyMilliseconds: Double) -> [String: Any] {
        [
            "attempt": attempt,
            "status": "failed_attempt",
            "safe_category": packageNineteenFailureCategory(error),
            "safe_failure": Self.boundedEvaluationText(safeFailure, maximumUTF8Bytes: 768),
            "provider_request_calls": providerRequestCalls,
            "latency_ms": Int(latencyMilliseconds),
        ]
    }

    /// A tool turn is durably completed by the engine's offline fallback. The
    /// original provider attempt is still a failed evaluation sample, but must
    /// never be retried because doing so would duplicate the persisted turn.
    private func packageNineteenEngineFallbackHistory(attempt: Int, fallbackReason: String, providerRequestCalls: Int, latencyMilliseconds: Double) -> [[String: Any]] {
        let bounded = Self.boundedEvaluationText(fallbackReason, maximumUTF8Bytes: 768)
        let lower = bounded.lowercased()
        return [[
            "attempt": attempt,
            "status": "failed_primary_provider_attempt",
            "safe_category": (lower.contains("timed out") || lower.contains("timeout")) ? "timeout" : "engine_primary_failure",
            "safe_failure": bounded,
            "provider_request_calls": providerRequestCalls,
            "latency_ms": Int(latencyMilliseconds),
            "retry_performed": false,
            "durable_fallback_completed": true,
        ]]
    }

    private func packageNineteenFailureCategory(_ error: Error) -> String {
        if case .timedOut = error as? TutorConversationError { return "timeout" }
        if Self.isTransientCloudEvaluationFailure(error) { return "transient_provider_failure" }
        if case .malformedProviderResponse = error as? TutorConversationError { return "malformed_provider_response" }
        if case .providerRejected = error as? TutorConversationError { return "provider_rejected" }
        return "nontransient_failure"
    }

    private func packageNineteenGenerationArtifact(
        prompt: PackageSeventeenCloudPrompt, level: TutorExperienceLevel, repetition: Int, attempt: Int,
        terminalStatus: String, text: String, metadata: TutorProviderMetadata?,
        telemetry: [String: Any], receipt: TutorEvidenceReceipt?, experiment: TutorExperimentRecord?, persistedExperimentCount: Int,
        latencyMeasured: Double, toolsEnabled: Bool, safeFailure: String?, fixtureIdentity: [String: String] = [:], laneContext: String = "provider_free_contract", retryHistory: [[String: Any]] = [], requestDiagnostics: [String: Any] = [:]
    ) -> [String: Any] {
        let renderedExperiment = experiment.map(packageNineteenExperimentArtifact) ?? NSNull()
        let requiredExperimentFields = experiment.map { draft in
            [draft.draft.title, draft.draft.startingRange, draft.draft.listenFor, draft.draft.risk, draft.draft.stopCondition ?? "", draft.draft.undo].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } ?? false
        let tools = receipt?.tools.map { ["name": $0.name, "call_id": $0.callID, "arguments_sha256": $0.argumentsSHA256, "output_sha256": $0.outputSHA256] } ?? []
        let evidenceKinds = receipt?.evidence.map { $0.kind.rawValue } ?? []
        let sentTools = telemetry["tools_sent"] as? [String] ?? []
        let actualSchemaHashes = telemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:]
        let schemaConflict = telemetry["tool_schema_conflict"] as? Bool ?? false
        let schemaEnvelopes = telemetry["tool_schema_envelopes"] as? [[String: String]] ?? []
        let schemaEnvelopeEntryCounts = telemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? []
        let schemaEnvelopeDuplicateNames = telemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? []
        let invalidToolSchemaEntry = telemetry["invalid_tool_schema_entry"] as? Bool ?? false
        let callConflict = telemetry["tool_call_conflict"] as? Bool ?? false
        let outputConflict = telemetry["tool_output_conflict"] as? Bool ?? false
        let invalidCallOrOutput = telemetry["invalid_tool_call_or_output"] as? Bool ?? false
        let exactToolDefinitions = packageNineteenExactSerializedToolSchemas(actual: actualSchemaHashes, envelopes: schemaEnvelopes, envelopeEntryCounts: schemaEnvelopeEntryCounts, envelopeDuplicateNames: schemaEnvelopeDuplicateNames, conflict: schemaConflict, invalid: invalidToolSchemaEntry, callConflict: callConflict, outputConflict: outputConflict, invalidCallOrOutput: invalidCallOrOutput, toolsEnabled: toolsEnabled)
        let canonicalSchemaHashes = packageNineteenCanonicalToolSchemaHashes()
        let schemaEnvelopeExact: [Bool]
        if schemaEnvelopes.count == schemaEnvelopeEntryCounts.count, schemaEnvelopes.count == schemaEnvelopeDuplicateNames.count {
            schemaEnvelopeExact = zip(schemaEnvelopes, zip(schemaEnvelopeEntryCounts, schemaEnvelopeDuplicateNames)).map { envelope, metadata in
                envelope == canonicalSchemaHashes && metadata.0 == canonicalSchemaHashes.count && !metadata.1
            }
        } else {
            schemaEnvelopeExact = Array(repeating: false, count: schemaEnvelopes.count)
        }
        let receiptBinding = packageNineteenReceiptMatchesTelemetry(receipt: receipt, telemetry: telemetry)
        let permittedToolNames = Set(TutorToolExecutor.defaultDefinitions.map(\.name))
        let permittedToolAuthority = receipt?.tools.allSatisfy { permittedToolNames.contains($0.name) } ?? !toolsEnabled
        let deterministic = packageNineteenDeterministicEvaluation(text: text, experiment: experiment, persistedExperimentCount: persistedExperimentCount, toolCalls: telemetry["tool_calls"] as? [[String: Any]] ?? [], toolResults: telemetry["tool_results"] as? [[String: Any]] ?? [], receiptBinding: receiptBinding, permittedToolAuthority: permittedToolAuthority, topic: prompt.topic, toolsEnabled: toolsEnabled)
        let fallbackStatus = receipt?.fallbackReason ?? (metadata == nil ? "not_observed_no_receipt" : "not_applicable_provider_direct")
        return [
            "repetition": repetition, "topic": prompt.topic, "topic_order": prompt.order, "level": level.rawValue,
            "query_sha256": sha256(Data(prompt.query.utf8)), "attempts": attempt, "terminal_status": terminalStatus,
            "safe_failure": packageNineteenJSONOrNull(safeFailure.map { Self.boundedEvaluationText($0, maximumUTF8Bytes: 768) }),
            "provider": metadata?.providerIdentifier ?? NSNull(), "model": metadata?.modelIdentifier ?? NSNull(),
            "provider_response_id": packageNineteenJSONOrNull(metadata?.providerResponseID), "service_tier": packageNineteenJSONOrNull(metadata?.serviceTier?.rawValue),
            "tokens": ["input": packageNineteenJSONOrNull(metadata?.inputTokens), "output": packageNineteenJSONOrNull(metadata?.outputTokens)],
            "latency_ms": ["first_token": NSNull(), "total_turn": Int(latencyMeasured)],
            "cost": NSNull(), "tools_enabled": toolsEnabled,
            "fixture_identity": fixtureIdentity,
            "lane_context": laneContext, "retry_history": retryHistory,
            "tools_sent": sentTools, "serialized_tool_schema_sha256_by_name": actualSchemaHashes, "serialized_tool_schema_envelopes": Array(schemaEnvelopes.prefix(16)), "serialized_tool_schema_envelope_entry_counts": Array(schemaEnvelopeEntryCounts.prefix(16)), "serialized_tool_schema_envelope_duplicate_names": Array(schemaEnvelopeDuplicateNames.prefix(16)), "serialized_tool_schema_envelope_exact": Array(schemaEnvelopeExact.prefix(16)), "serialized_tool_schema_conflict": schemaConflict, "serialized_tool_schema_invalid_entry": invalidToolSchemaEntry, "tool_call_conflict": callConflict, "tool_output_conflict": outputConflict, "invalid_tool_call_or_output": invalidCallOrOutput, "serialized_tool_definitions_exact": exactToolDefinitions, "serialized_request_diagnostics": requestDiagnostics, "provider_request_calls": telemetry["provider_request_calls"] ?? 0,
            "tool_rounds": telemetry["tool_rounds"] ?? 0, "tool_calls": telemetry["tool_calls"] ?? [], "tool_results": telemetry["tool_results"] ?? [],
            "tool_receipts": tools, "evidence_kinds": evidenceKinds,
            "receipt_id": receipt?.id.uuidString ?? NSNull(), "capture_snapshot_id": receipt?.captureSnapshotID?.uuidString ?? NSNull(),
            "experience": receipt?.experience.map(packageNineteenCodableArtifact) ?? NSNull(),
            "fallback_status": fallbackStatus,
            "present_experiment": renderedExperiment,
            "experiment_completeness": ["present": experiment != nil, "persisted_count": persistedExperimentCount, "exactly_one_persisted_experiment": persistedExperimentCount == 1, "all_required_fields": requiredExperimentFields, "repair_count": 0, "max_repairs": 1, "overall_deterministic_completeness": deterministic["overall_deterministic_completeness"] ?? false],
            "assistant_text": Self.boundedEvaluationText(text, maximumUTF8Bytes: 4096), "assistant_text_sha256": sha256(Data(text.utf8)), "assistant_text_bytes": text.utf8.count,
            "deterministic_evaluation": deterministic,
            "deterministic_authority_structure": ["read_only_or_presentation_only_tools": permittedToolAuthority, "tool_receipts_match_observed_calls": receiptBinding, "no_hidden_reasoning_stored": true],
        ]
    }

    private func packageNineteenCanonicalToolSchemaHashes() -> [String: String] {
        Dictionary(uniqueKeysWithValues: TutorToolExecutor.defaultDefinitions.compactMap { definition -> (String, String)? in
            guard let data = try? JSONSerialization.data(withJSONObject: OpenAITutorProvider.toolSchema(definition), options: [.sortedKeys]) else { return nil }
            return (definition.name, sha256(data))
        })
    }

    private func packageNineteenExactSerializedToolSchemas(actual: [String: String], envelopes: [[String: String]], envelopeEntryCounts: [Int], envelopeDuplicateNames: [Bool], conflict: Bool = false, invalid: Bool = false, callConflict: Bool = false, outputConflict: Bool = false, invalidCallOrOutput: Bool = false, toolsEnabled: Bool) -> Bool {
        guard !conflict, !invalid, !callConflict, !outputConflict, !invalidCallOrOutput else { return false }
        guard envelopes.count == envelopeEntryCounts.count, envelopes.count == envelopeDuplicateNames.count,
              !envelopeDuplicateNames.contains(true) else { return false }
        let canonical = packageNineteenCanonicalToolSchemaHashes()
        if toolsEnabled {
            return actual == canonical && !envelopes.isEmpty && zip(envelopes, envelopeEntryCounts).allSatisfy { envelope, count in
                envelope == canonical && count == canonical.count
            }
        }
        return actual.isEmpty && !envelopes.isEmpty && zip(envelopes, envelopeEntryCounts).allSatisfy { envelope, count in
            envelope.isEmpty && count == 0
        }
    }

    private func packageNineteenReceiptMatchesTelemetry(receipt: TutorEvidenceReceipt?, telemetry: [String: Any]) -> Bool {
        guard !(telemetry["tool_schema_conflict"] as? Bool ?? false),
              !(telemetry["invalid_tool_schema_entry"] as? Bool ?? false),
              !(telemetry["tool_call_conflict"] as? Bool ?? false),
              !(telemetry["tool_output_conflict"] as? Bool ?? false),
              !(telemetry["invalid_tool_call_or_output"] as? Bool ?? false) else { return false }
        guard let receipt else { return (telemetry["tool_calls"] as? [[String: Any]] ?? []).isEmpty }
        let calls = Dictionary(uniqueKeysWithValues: (telemetry["tool_calls"] as? [[String: Any]] ?? []).compactMap { call -> (String, [String: Any])? in
            guard let id = call["call_id"] as? String else { return nil }; return (id, call)
        })
        let results = Dictionary(uniqueKeysWithValues: (telemetry["tool_results"] as? [[String: Any]] ?? []).compactMap { result -> (String, [String: Any])? in
            guard let id = result["call_id"] as? String else { return nil }; return (id, result)
        })
        return receipt.tools.count == calls.count && receipt.tools.allSatisfy { tool in
            guard let call = calls[tool.callID], let result = results[tool.callID] else { return false }
            return call["name"] as? String == tool.name && call["arguments_sha256"] as? String == tool.argumentsSHA256 && result["output_sha256"] as? String == tool.outputSHA256
        }
    }

    private func packageNineteenDeterministicEvaluation(text: String, experiment: TutorExperimentRecord?, persistedExperimentCount: Int, toolCalls: [[String: Any]], toolResults: [[String: Any]], receiptBinding: Bool, permittedToolAuthority: Bool, topic: String, toolsEnabled: Bool) -> [String: Any] {
        let lower = text.lowercased()
        let claims = ["i performed", "i changed", "i heard", "i observed", "tracksmith performed", "tracksmith changed", "tracksmith heard", "tracksmith observed"]
        let names = Set(toolCalls.compactMap { $0["name"] as? String })
        let procedureNecessary = topic == "cannot_find"
        let procedureResult = toolResults.first { $0["name"] as? String == "get_logic_procedure" }
        let procedureFoundFlag = procedureResult?["reviewed_or_procedure_found"] as? Bool
        let procedureFound = procedureFoundFlag == true || ((procedureResult?["reviewed_or_procedure_match_count"] as? Int) ?? 0) > 0
        let procedureStatus = procedureResult?["reviewed_or_procedure_status"] as? String ?? "not_observed"
        let toolResultUnavailable = procedureFoundFlag == false || ["unavailable", "not_found", "no_match", "absent"].contains(procedureStatus)
        let procedureSubject = ["procedure", "navigation", "control"].contains { lower.contains($0) }
        let unavailablePredicate = ["unavailable", "not verified", "cannot verify", "could not verify"].contains { lower.contains($0) }
        let proseUnavailableDisclosure = procedureSubject && unavailablePredicate
        let procedureSatisfied = names.contains("get_logic_procedure") && (procedureFound || (toolResultUnavailable && proseUnavailableDisclosure))
        let changedVariableOrAction = ["change", "adjust", "move", "lower", "raise", "set ", "toggle", "bypass", "reduce", "increase", "compare", "try "].contains { lower.contains($0) }
        let listenCue = lower.contains("listen")
        let risk = lower.contains("risk") || lower.contains("worse") || lower.contains("harsh") || lower.contains("muddy")
        let stop = lower.contains("stop") || lower.contains("if it worsens")
        let undo = lower.contains("undo") || lower.contains("rollback") || lower.contains("restore") || lower.contains("revert")
        let proseExperimentComplete = changedVariableOrAction && listenCue && risk && stop && undo
        // All twelve evaluated prompts are actionable. In the tool lane, a
        // complete answer additionally needs exactly one durable experiment;
        // provider-only comparison answers are assessed from their prose.
        let exactlyOnePersistedExperiment = persistedExperimentCount == 1 && experiment != nil
        let oneExperimentWhereApplicable = toolsEnabled ? exactlyOnePersistedExperiment : proseExperimentComplete
        let overallCompleteness = proseExperimentComplete && oneExperimentWhereApplicable
        return [
            "final_prose_flags": [
                "has_changed_variable_or_action": changedVariableOrAction,
                "has_listen_cue": listenCue, "has_risk": risk,
                "has_stop": stop, "has_undo_or_rollback": undo,
                "one_experiment_where_applicable": oneExperimentWhereApplicable,
                "exactly_one_persisted_experiment": toolsEnabled ? exactlyOnePersistedExperiment : false,
            ],
            "overall_deterministic_completeness": overallCompleteness,
            "overall_deterministic_completeness_status": overallCompleteness ? "pass" : "fail",
            "exact_procedure_necessity": ["necessary": procedureNecessary, "get_logic_procedure_called": names.contains("get_logic_procedure"), "reviewed_procedure_found": procedureFound, "tool_result_unavailable": toolResultUnavailable, "prose_unavailable_disclosure": proseUnavailableDisclosure, "status": procedureNecessary ? (procedureSatisfied ? "satisfied" : "missing") : "not_required_by_topic_fixture"],
            "evidence_honesty": ["no_unearned_hearing_or_mutation_claim": !claims.contains { lower.contains($0) }, "capture_or_logic_is_labeled_fixture": toolsEnabled],
            "authority": ["read_only_or_presentation_only_tools": permittedToolAuthority, "no_mutation_claim": !claims.contains { lower.contains($0) }, "receipt_binding": receiptBinding],
            "usefulness_structural": ["nonempty_bounded_prose": !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.utf8.count <= 4096, "separate_from_level_invariance": true],
        ]
    }

    private func packageNineteenEnvelopeTelemetry(_ bodies: [Data]) throws -> [String: Any] {
        var toolsSent = Set<String>(), toolSchemaHashes: [String: String] = [:], schemaEnvelopes: [[String: String]] = [], schemaEnvelopeEntryCounts: [Int] = [], schemaEnvelopeDuplicateNames: [Bool] = [], toolSchemaConflict = false, invalidToolSchemaEntry = false
        var calls: [[String: Any]] = [], callSignatures: [String: (name: String, argumentsSHA256: String)] = [:], outputs: [String: String] = [:]
        var toolCallConflict = false, toolOutputConflict = false, invalidToolCallOrOutput = false, toolRounds = 0
        func visit(_ value: Any) {
            if let list = value as? [Any] { list.forEach(visit); return }
            guard let object = value as? [String: Any] else { return }
            if object["type"] as? String == "function_call" {
                guard let name = object["name"] as? String, !name.isEmpty,
                      let callID = object["call_id"] as? String, !callID.isEmpty,
                      let arguments = object["arguments"] as? String else { invalidToolCallOrOutput = true; object.values.forEach(visit); return }
                let digest = sha256(Data(arguments.utf8))
                if let existing = callSignatures[callID] {
                    if existing.name != name || existing.argumentsSHA256 != digest { toolCallConflict = true }
                } else {
                    callSignatures[callID] = (name, digest)
                    calls.append(["name": name, "call_id": callID, "arguments": packageNineteenArgumentArtifact(arguments), "arguments_sha256": digest])
                }
            }
            if object["type"] as? String == "function_call_output" {
                guard let callID = object["call_id"] as? String, !callID.isEmpty,
                      let output = object["output"] as? String else { invalidToolCallOrOutput = true; object.values.forEach(visit); return }
                if let existing = outputs[callID], existing != output { toolOutputConflict = true }
                else if outputs[callID] == nil { outputs[callID] = output }
            }
            object.values.forEach(visit)
        }
        for body in bodies {
            guard let root = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                throw TutorConversationError.malformedProviderResponse("Cloud harness could not inspect its own serialized request.")
            }
            var envelope: [String: String] = [:]
            guard let rawTools = root["tools"] else {
                schemaEnvelopes.append(envelope); schemaEnvelopeEntryCounts.append(0); schemaEnvelopeDuplicateNames.append(false); visit(root)
                if String(decoding: body, as: UTF8.self).contains(#""type":"function_call_output""#) { toolRounds += 1 }
                continue
            }
            guard let tools = rawTools as? [Any] else { invalidToolSchemaEntry = true; schemaEnvelopes.append(envelope); schemaEnvelopeEntryCounts.append(0); schemaEnvelopeDuplicateNames.append(false); visit(root); continue }
            var duplicateName = false
            for rawTool in tools {
                guard let tool = rawTool as? [String: Any], let name = tool["name"] as? String, !name.isEmpty,
                      let data = try? JSONSerialization.data(withJSONObject: tool, options: [.sortedKeys]) else { invalidToolSchemaEntry = true; continue }
                let digest = sha256(data)
                if let existing = envelope[name] {
                    duplicateName = true
                    if existing != digest { toolSchemaConflict = true }
                } else { envelope[name] = digest }
                toolsSent.insert(name)
                if let existing = toolSchemaHashes[name], existing != digest { toolSchemaConflict = true }
                else if toolSchemaHashes[name] == nil { toolSchemaHashes[name] = digest }
            }
            schemaEnvelopes.append(envelope); schemaEnvelopeEntryCounts.append(tools.count); schemaEnvelopeDuplicateNames.append(duplicateName)
            visit(root)
            if String(decoding: body, as: UTF8.self).contains(#""type":"function_call_output""#) { toolRounds += 1 }
        }
        if outputs.keys.contains(where: { callSignatures[$0] == nil }) { invalidToolCallOrOutput = true }
        let boundedCalls = Array(calls.prefix(64))
        let results = boundedCalls.map { call -> [String: Any] in
            let callID = call["call_id"] as? String ?? "unknown"
            let name = call["name"] as? String ?? "unknown"
            return packageNineteenToolResultArtifact(name: name, callID: callID, output: outputs[callID])
        }
        return ["tools_sent": toolsSent.sorted(), "tool_schema_sha256_by_name": toolSchemaHashes, "tool_schema_envelopes": schemaEnvelopes, "tool_schema_envelope_entry_counts": schemaEnvelopeEntryCounts, "tool_schema_envelope_duplicate_names": schemaEnvelopeDuplicateNames, "tool_schema_conflict": toolSchemaConflict, "invalid_tool_schema_entry": invalidToolSchemaEntry, "tool_call_conflict": toolCallConflict, "tool_output_conflict": toolOutputConflict, "invalid_tool_call_or_output": invalidToolCallOrOutput, "provider_request_calls": bodies.count, "tool_rounds": toolRounds, "tool_calls": boundedCalls, "tool_results": results]
    }

    /// Provider requests and tool outputs must be blind to evaluator-only case
    /// labels. This is deliberately an exact serialized-envelope assertion:
    /// it covers both the initial request context and later function outputs.
    private func packageNineteenProviderFacingBoundaryIsClean(bodies: [Data], additionalValues: [String] = []) -> Bool {
        let forbidden = [
            "vocal_masking", "eq_tradeoff", "compression_sibilance", "layering_redundancy",
            "automation_owner", "flex_artifact", "duplicate_monitoring", "sidechain_trigger",
            "midi_groove", "bounce_tail", "cannot_find", "uncertain_evidence",
            "package 019", "package019", "package_019", "p19", "evaluation fixture", "p18-natural-", "case-", "case_", "evaluation_case", "fixture_alias",
        ]
        let values = bodies.map { String(decoding: $0, as: UTF8.self) } + additionalValues
        return values.allSatisfy { value in
            let lowered = value.lowercased()
            return !forbidden.contains(where: lowered.contains)
        }
    }

    private func packageNineteenArgumentArtifact(_ text: String) -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            return ["shape": "malformed", "sha256": sha256(Data(text.utf8)), "bytes": text.utf8.count]
        }
        let allowed = ["query", "domain", "category", "source_type", "evidence_class", "logic_version", "current_context", "role", "section", "procedure_id", "max_results"]
        var fields: [String: Any] = [:]
        for key in allowed where object[key] != nil {
            if let value = object[key] as? String { fields[key] = Self.boundedEvaluationText(value, maximumUTF8Bytes: 600) }
            else if let value = object[key] as? NSNumber { fields[key] = value }
        }
        return ["shape": "object", "fields": fields, "sha256": sha256(Data(text.utf8)), "bytes": text.utf8.count]
    }

    private func packageNineteenToolResultArtifact(name: String, callID: String, output: String?) -> [String: Any] {
        guard let output else { return ["name": name, "call_id": callID, "status": "no_function_output_observed"] }
        var summary: [String: Any] = ["name": name, "call_id": callID, "output_sha256": sha256(Data(output.utf8)), "output_bytes": output.utf8.count]
        guard let object = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] else {
            summary["status"] = "non_json_bounded_output"; return summary
        }
        if let availability = object["availability"] as? String { summary["retrieval_availability"] = availability }
        if let found = object["found"] as? Bool { summary["reviewed_or_procedure_found"] = found }
        if let matches = object["matches"] as? [Any] { summary["reviewed_or_procedure_match_count"] = matches.count }
        if let status = object["status"] as? String { summary["reviewed_or_procedure_status"] = status }
        var domains = Set<String>()
        func domainsIn(_ value: Any) {
            if let list = value as? [Any] { list.forEach(domainsIn); return }
            guard let dict = value as? [String: Any] else { return }
            if let domain = dict["domain"] as? String { domains.insert(domain) }
            dict.values.forEach(domainsIn)
        }
        domainsIn(object)
        if !domains.isEmpty { summary["selected_domains"] = Array(domains.sorted().prefix(4)) }
        return summary
    }

    private func packageNineteenExperimentArtifact(_ record: TutorExperimentRecord) -> Any {
        packageNineteenCodableArtifact(record.draft)
    }

    private func packageNineteenCodableArtifact<T: Encodable>(_ value: T) -> Any {
        guard let data = try? JSONEncoder().encode(value), let object = try? JSONSerialization.jsonObject(with: data) else { return NSNull() }
        return object
    }

    private func packageNineteenJSONOrNull(_ value: Any?) -> Any { value ?? NSNull() }

    private func packageNineteenTripletSummary(_ triplet: [PackageNineteenCloudGeneration], topic: String, repetition: Int, semanticEvaluation: [String: Any]) -> [String: Any] {
        let levelOrder: [TutorExperienceLevel: Int] = [.noob: 0, .amateur: 1, .pro: 2]
        let ordered = triplet.sorted { (levelOrder[$0.response.level] ?? .max) < (levelOrder[$1.response.level] ?? .max) }
        let artifacts = ordered.map(\.artifact)
        let completed = packageNineteenTripletIsGenerationComplete(triplet)
        return [
            "topic": topic, "repetition": repetition, "levels": artifacts.map { $0["level"] ?? "unknown" },
            "generation_complete_before_reference": completed,
            "deterministic_authority_pass": artifacts.allSatisfy {
                let authority = ($0["deterministic_evaluation"] as? [String: Any])?["authority"] as? [String: Any]
                let honesty = ($0["deterministic_evaluation"] as? [String: Any])?["evidence_honesty"] as? [String: Any]
                return authority?["read_only_or_presentation_only_tools"] as? Bool == true
                    && authority?["receipt_binding"] as? Bool == true
                    && authority?["no_mutation_claim"] as? Bool == true
                    && honesty?["no_unearned_hearing_or_mutation_claim"] as? Bool == true
            },
            "deterministic_completeness_pass": artifacts.allSatisfy { (($0["deterministic_evaluation"] as? [String: Any])?["overall_deterministic_completeness"] as? Bool) == true },
            "experiment_completeness_pass": artifacts.allSatisfy { (($0["experiment_completeness"] as? [String: Any])?["overall_deterministic_completeness"] as? Bool) == true },
            "usefulness": artifacts.map { ($0["deterministic_evaluation"] as? [String: Any])?["usefulness_structural"] ?? NSNull() },
            "strict_level_invariance": ["status": "deterministic_structure_only", "prose_hashes": artifacts.map { $0["assistant_text_sha256"] ?? NSNull() }, "separate_from_usefulness": true],
            "semantic_key_acceptable_family_check": semanticEvaluation,
        ]
    }

    private func packageNineteenTripletIsGenerationComplete(_ triplet: [PackageNineteenCloudGeneration]) -> Bool {
        triplet.count == 3 && triplet.allSatisfy { ($0.artifact["terminal_status"] as? String) == "completed" }
    }

    private func packageNineteenDeterministicSemanticEvaluation(repository: URL, prompt: PackageSeventeenCloudPrompt, triplet: [PackageSeventeenCloudResponse]) throws -> [String: Any] {
        guard triplet.count == 3, triplet.allSatisfy({ $0.outcome.text != nil && $0.outcome.terminalStatus == "completed" }) else {
            throw TutorConversationError.malformedProviderResponse("P19 deterministic semantic evaluation requires a completed generation triplet.")
        }
        // This is evaluation-only and intentionally happens after all three
        // generated answers exist. It checks family/key overlap, never a
        // literal golden-response match, and stores only a reference hash.
        let reference = try Self.packageSeventeenSemanticReference(repository: repository, topic: prompt.topic)
        let referenceText = [reference.problemSummary, reference.recommendedFirstExperiment, reference.evidenceRequirements, reference.riskAndUndo].joined(separator: " ")
        let excluded = Set(["about", "after", "before", "change", "evidence", "experiment", "listen", "music", "risk", "rollback", "safe", "safely", "small", "sound", "stop", "this", "track", "undo", "with", "worse", "your"])
        func keys(_ value: String) -> Set<String> {
            Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 3 && !excluded.contains($0) })
        }
        let problemKeys = keys([reference.problemSummary, reference.evidenceRequirements].joined(separator: " "))
        let experimentKeys = keys(reference.recommendedFirstExperiment)
        let evaluations: [[String: Any]] = triplet.map { response in
            let answer = response.outcome.text ?? ""
            let answerKeys = keys(answer)
            let problemOverlap = problemKeys.intersection(answerKeys).count
            let experimentOverlap = experimentKeys.intersection(answerKeys).count
            return ["level": response.level.rawValue, "problem_lexical_overlap_count": problemOverlap, "experiment_lexical_overlap_count": experimentOverlap, "status": "diagnostic_only_nonsemantic_lexical_signal", "verbatim_golden_overlap_not_required": true]
        }
        return ["status": "diagnostic_only_nonsemantic_lexical_signal", "reference_read": true, "reference_sha256": sha256(Data(referenceText.utf8)), "problem_reference_key_count": problemKeys.count, "experiment_reference_key_count": experimentKeys.count, "evaluation": evaluations, "overall_status": "indeterminate_requires_blinded_judge", "synonyms_or_verbatim_judged": false, "verbatim_golden_overlap_not_required": true]
    }

    private func packageNineteenSupportingJudgment(
        repository: URL, prompt: PackageSeventeenCloudPrompt, triplet: [PackageSeventeenCloudResponse],
        configuration: TutorProviderConfiguration, repetition: Int,
        transportFactory: (() -> PackageNineteenRecordingForwardingTransport)? = nil,
        providerFactory: ((PackageNineteenRecordingForwardingTransport) -> OpenAITutorProvider)? = nil
    ) async throws -> [String: Any] {
        guard triplet.count == 3, triplet.allSatisfy({ $0.outcome.terminalStatus == "completed" && $0.outcome.text != nil }) else {
            throw TutorConversationError.malformedProviderResponse("P19 semantic reference firewall rejected an incomplete triplet.")
        }
        // This follows the deterministic post-triplet semantic check. It is
        // still unreachable from generation and runtime tool requests.
        let reference = try Self.packageSeventeenSemanticReference(repository: repository, topic: prompt.topic)
        let labels = ["A", "B", "C"]
        let blinded = triplet.sorted {
            sha256(Data("\(prompt.topic)|\(repetition)|\($0.level.rawValue)".utf8)) < sha256(Data("\(prompt.topic)|\(repetition)|\($1.level.rawValue)".utf8))
        }
        let mapping = Dictionary(uniqueKeysWithValues: zip(labels, blinded.map { $0.level.rawValue }))
        let rendered = zip(labels, blinded).compactMap { label, response in
            response.outcome.text.map { "[\(label)] \(Self.boundedEvaluationText($0, maximumUTF8Bytes: 4096))" }
        }.joined(separator: "\n\n")
        let request = """
        Blinded supporting evaluation only. The labels A/B/C are deliberately pseudonymous; do not infer or discuss experience level. Return a compact JSON object with these boolean keys: usefulness, evidence_honesty, strict_level_invariance, experiment_completeness, exact_procedure_necessity. Artistic preference is excluded. Do not reveal hidden reasoning or reproduce the reference.

        Query: \(prompt.query)

        Evaluation-only semantic reference, supplied only after all three generation samples completed: problem=\(reference.problemSummary); first_experiment=\(reference.recommendedFirstExperiment); evidence=\(reference.evidenceRequirements); \(reference.riskAndUndo)

        Blinded responses:\n\(rendered)
        """
        let transport = transportFactory?() ?? PackageNineteenRecordingForwardingTransport()
        let provider = providerFactory?(transport) ?? OpenAITutorProvider(configuration: configuration, transport: transport)
        let retry = await packageNineteenCloudTextWithRetry(provider: provider, query: request, context: .init(sourceType: .vocal), requestCount: { transport.requestCount })
        let outcome = retry.outcome
        let parsed = packageNineteenParseSupportingJudgeJSON(outcome.text)
        let metadataPinned = outcome.metadata.map(Self.packageNineteenCloudMetadataIsPinned) == true
        let requestDiagnostics = packageNineteenRequestDiagnostics(transport.requestBodies(), toolsEnabled: false)
        let requestEnvelopesExact = requestDiagnostics["request_envelopes_exact"] as? Bool == true
        let responseCompleted = outcome.terminalStatus == "completed"
        let terminalValidationError: TutorConversationError?
        if responseCompleted, !requestEnvelopesExact {
            terminalValidationError = .providerRejected("Supporting judge rejected its serialized request envelope.")
        } else if responseCompleted, !metadataPinned {
            terminalValidationError = .providerRejected("Supporting judge rejected unpinned completed provider metadata.")
        } else if responseCompleted, parsed.status != "valid" {
            terminalValidationError = .malformedProviderResponse("Supporting judge returned malformed or incomplete JSON.")
        } else {
            terminalValidationError = nil
        }
        let valid = responseCompleted && terminalValidationError == nil
        var retryHistory = retry.failureHistory
        if let terminalValidationError {
            retryHistory.append(packageNineteenRetryFailureArtifact(attempt: outcome.attempts, error: terminalValidationError, safeFailure: terminalValidationError.safeFailureDescription, providerRequestCalls: 0, latencyMilliseconds: 0))
        }
        let judgeResultStatus: String
        if valid {
            judgeResultStatus = "valid"
        } else if responseCompleted, !requestEnvelopesExact {
            judgeResultStatus = "invalid_request_envelope"
        } else if responseCompleted, !metadataPinned {
            judgeResultStatus = "invalid_unpinned_provider_metadata"
        } else if responseCompleted {
            judgeResultStatus = parsed.status
        } else {
            judgeResultStatus = "invalid_terminal_provider_response"
        }
        let safeCategory: Any = valid ? NSNull() : terminalValidationError.map { packageNineteenFailureCategory($0) } ?? retryHistory.last?["safe_category"] ?? "nontransient_failure"
        let safeFailure: Any = valid ? NSNull() : terminalValidationError?.safeFailureDescription ?? outcome.safeFailure ?? "Supporting judge did not produce an accepted response."
        return [
            "topic": prompt.topic, "repetition": repetition, "phase": "post_generation_model_assisted_supporting_evidence",
            "semantic_reference_read": true, "generation_reference_access": false,
            "terminal_status": valid ? "completed" : "failed",
            "judge_result_status": judgeResultStatus,
            "attempts": outcome.attempts, "retry_history": retryHistory,
            "provider_request_calls": retry.providerRequestCalls,
            "durable_completion_warning": retry.durableCompletionWarning ?? NSNull(),
            "judge_text_sha256": outcome.text.map { sha256(Data($0.utf8)) } ?? NSNull(), "judge_text_bytes": outcome.text.map { $0.utf8.count } ?? NSNull(),
            "provider_metadata": outcome.metadata.map { ["provider": $0.providerIdentifier, "model": $0.modelIdentifier, "service_tier": $0.serviceTier?.rawValue ?? "missing"] } ?? NSNull(),
            "provider_metadata_pinned": metadataPinned,
            "serialized_request_diagnostics": requestDiagnostics,
            "safe_category": safeCategory, "safe_failure": safeFailure, "hidden_reasoning_stored": false,
            "blinded_mapping_for_analysis_outside_judge_prompt": mapping,
            "dimensions": parsed.dimensions,
            "artistic_preference": "excluded_not_owner_evidence",
            "owner_artistic_or_usability_judgment": "not_run_no_owner_review",
        ]
    }

    private func packageNineteenObservedEnvelopeTelemetry(_ bodies: [Data]) -> [String: Any] {
        (try? packageNineteenEnvelopeTelemetry(bodies)) ?? [
            "tools_sent": [String](), "tool_schema_sha256_by_name": [String: String](), "tool_schema_envelopes": [[String: String]](),
            "tool_schema_envelope_entry_counts": [Int](), "tool_schema_envelope_duplicate_names": [Bool](),
            "tool_schema_conflict": false, "invalid_tool_schema_entry": true, "tool_call_conflict": false,
            "tool_output_conflict": false, "invalid_tool_call_or_output": false,
            "provider_request_calls": bodies.count, "tool_rounds": 0, "tool_calls": [[String: Any]](), "tool_results": [[String: Any]](),
        ]
    }

    /// Bounded, provider-free projection of exact provider envelopes. It stores configuration values and schema telemetry,
    /// never request text, references, credentials, or raw bodies.
    private func packageNineteenRequestDiagnostics(_ bodies: [Data], toolsEnabled: Bool) -> [String: Any] {
        let telemetry = packageNineteenObservedEnvelopeTelemetry(bodies)
        let exactToolDefinitions = packageNineteenExactSerializedToolSchemas(
            actual: telemetry["tool_schema_sha256_by_name"] as? [String: String] ?? [:],
            envelopes: telemetry["tool_schema_envelopes"] as? [[String: String]] ?? [],
            envelopeEntryCounts: telemetry["tool_schema_envelope_entry_counts"] as? [Int] ?? [],
            envelopeDuplicateNames: telemetry["tool_schema_envelope_duplicate_names"] as? [Bool] ?? [],
            conflict: telemetry["tool_schema_conflict"] as? Bool ?? true,
            invalid: telemetry["invalid_tool_schema_entry"] as? Bool ?? true,
            callConflict: telemetry["tool_call_conflict"] as? Bool ?? true,
            outputConflict: telemetry["tool_output_conflict"] as? Bool ?? true,
            invalidCallOrOutput: telemetry["invalid_tool_call_or_output"] as? Bool ?? true,
            toolsEnabled: toolsEnabled
        )
        var malformedEnvelope = false
        var storesFalse = !bodies.isEmpty, modelsPinned = !bodies.isEmpty, effortsHigh = !bodies.isEmpty, tiersPriority = !bodies.isEmpty
        var models = Set<String>(), efforts = Set<String>(), tiers = Set<String>()
        for body in bodies {
            guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                malformedEnvelope = true; storesFalse = false; modelsPinned = false; effortsHigh = false; tiersPriority = false
                continue
            }
            let model = root["model"] as? String ?? "missing"
            let effort = (root["reasoning"] as? [String: Any])?["effort"] as? String ?? "missing"
            let tier = root["service_tier"] as? String ?? "missing"
            models.insert(model); efforts.insert(effort); tiers.insert(tier)
            storesFalse = storesFalse && root["store"] as? Bool == false
            modelsPinned = modelsPinned && model == "gpt-5.6-sol"
            effortsHigh = effortsHigh && effort == TutorReasoningEffort.high.rawValue
            tiersPriority = tiersPriority && tier == TutorProviderServiceTier.priority.rawValue
        }
        let requestEnvelopesExact = !malformedEnvelope && exactToolDefinitions && storesFalse && modelsPinned && effortsHigh && tiersPriority
        return [
            "request_count": bodies.count,
            "request_envelopes_exact": requestEnvelopesExact,
            "tools_enabled_expected": toolsEnabled,
            "tool_definitions_exact": exactToolDefinitions,
            "no_tools_exact": !toolsEnabled && exactToolDefinitions,
            "store_false": storesFalse,
            "model_pinned": modelsPinned,
            "reasoning_effort_high": effortsHigh,
            "service_tier_priority": tiersPriority,
            "malformed_envelope": malformedEnvelope,
            "models": models.sorted(), "reasoning_efforts": efforts.sorted(), "service_tiers": tiers.sorted(),
            "tools_sent": telemetry["tools_sent"] ?? [],
            "tool_schema_envelope_entry_counts": telemetry["tool_schema_envelope_entry_counts"] ?? [],
            "tool_schema_envelope_duplicate_names": telemetry["tool_schema_envelope_duplicate_names"] ?? [],
            "invalid_tool_schema_entry": telemetry["invalid_tool_schema_entry"] ?? true,
        ]
    }

    private func packageNineteenParseSupportingJudgeJSON(_ text: String?) -> (status: String, dimensions: [String: Bool]) {
        let required = ["usefulness", "evidence_honesty", "strict_level_invariance", "experiment_completeness", "exact_procedure_necessity"]
        guard let text,
              let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            return ("invalid_malformed_json", [:])
        }
        let requiredKeys = Set(required)
        let keys = Set(object.keys)
        guard keys.subtracting(requiredKeys).isEmpty else { return ("invalid_extra_fields", [:]) }
        guard keys == requiredKeys else { return ("invalid_missing_or_nonboolean_dimensions", [:]) }
        var dimensions: [String: Bool] = [:]
        for key in required {
            guard let value = object[key] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else {
                return ("invalid_missing_or_nonboolean_dimensions", [:])
            }
            dimensions[key] = value.boolValue
        }
        return ("valid", dimensions)
    }

    private func packageNineteenLaneName(_ lane: PackageNineteenCloudLane) -> String {
        switch lane { case .noTool: return "no_tool"; case .fullTool: return "full_tool"; case .repeatedTriplets: return "repeated_triplets" }
    }

    private nonisolated static func packageNineteenCloudMetadataIsPinned(_ metadata: TutorProviderMetadata) -> Bool {
        metadata.providerIdentifier == OpenAITutorProvider().providerIdentifier
            && metadata.modelIdentifier == packageSeventeenTextModel
            && metadata.serviceTier == .priority
    }

    private func packageNineteenSourceIdentity(_ repository: URL) -> [String: Any] {
        ["commit": packageNineteenGit(repository, ["rev-parse", "HEAD"]) ?? "unavailable", "index_tree": packageNineteenGit(repository, ["write-tree"]) ?? "unavailable", "worktree_patch_sha256": packageNineteenGit(repository, ["diff", "--no-ext-diff", "--binary", "HEAD"]).map { sha256(Data($0.utf8)) } ?? "unavailable", "boundary": "Commit, staged-tree, and worktree-patch fingerprints disambiguate dirty local state without recording host paths or untracked names."]
    }

    private func packageNineteenGit(_ repository: URL, _ arguments: [String]) -> String? {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/git"); process.arguments = arguments; process.currentDirectoryURL = repository
        let output = Pipe(); process.standardOutput = output; process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }; process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func packageNineteenEvaluationHashes(_ repository: URL, prompts: [PackageSeventeenCloudPrompt]? = nil) throws -> [String: Any] {
        func digest(_ relative: String) throws -> String { try sha256(Data(contentsOf: repository.appendingPathComponent(relative))) }
        let definitionMetadataData = try JSONEncoder().encode(TutorToolExecutor.defaultDefinitions)
        let canonicalToolSchemas = TutorToolExecutor.defaultDefinitions.map(OpenAITutorProvider.toolSchema)
        let toolData = try JSONSerialization.data(withJSONObject: canonicalToolSchemas, options: [.sortedKeys])
        let policy = TutorSystemPolicy.audit()
        let cloudPrompts = try prompts ?? packageNineteenCloudPrompts(repository: repository)
        let orderedPromptBytes = Data(cloudPrompts.sorted { $0.order < $1.order }.map { "\($0.order)|\($0.topic)|\($0.query)\n" }.joined().utf8)
        return [
            "suite_sha256": try digest("research/tutor_quality/package019_evaluation_suite.json"),
            "suite_manifest_sha256": try digest("research/tutor_quality/package019_evaluation_manifest.json"),
            "policy": ["version": policy.version, "utf8_bytes": policy.utf8Bytes, "sha256": policy.sha256],
            "tool_schema_sha256": sha256(toolData),
            "tool_definition_metadata_sha256": sha256(definitionMetadataData),
            "candidate_index_sha256": try digest("packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.sqlite"),
            "candidate_index_manifest_sha256": try digest("packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.manifest.json"),
            "retrieval_policy_version": CandidateRetrievalIndex.policyVersion,
            "cloud_prompt_suite": [
                "exact_prompt_count": cloudPrompts.count,
                "ordered_prompt_suite_sha256": sha256(orderedPromptBytes),
                "prompt_only_file_sha256": try digest("research/tutor_quality/package019_cloud_prompt_suite.json"),
            ],
        ]
    }

    private func packageNineteenWriteCloudArtifact(_ artifact: [String: Any], lane: PackageNineteenCloudLane, repository: URL) throws {
        let output = repository.appendingPathComponent("research/tutor_quality/evaluations/PACKAGE_019_CLOUD_\(packageNineteenLaneName(lane)).json")
        try JSONSerialization.data(withJSONObject: artifact, options: [.sortedKeys, .prettyPrinted]).write(to: output, options: .atomic)
    }

    private func testPackageEighteenDiagnostic() async throws {
        let policyAudit = TutorSystemPolicy.audit()
        try expect(policyAudit.passes && policyAudit.version == "package018/1" && policyAudit.utf8Bytes == 2_836 && policyAudit.sha256 == "b38c81c7f61cbfc4b205fcc2555cd0f19042bae5f5564dfa981b3f1f001f73da",
                   "P18 TutorSystemPolicy audit/hash/version drifted")
        let indexedReadinessStarted = Date()
        let opened = CandidateRetrievalIndex.openBundled()
        let indexedReadinessMilliseconds = Date().timeIntervalSince(indexedReadinessStarted) * 1_000
        guard opened.availability == .ready, let retriever = opened.retriever else {
            throw TestFailure(description: "P18 bundled index unavailable: \(opened.availability.rawValue)")
        }
        // This deliberately invokes the removed live implementation only as a
        // research/test oracle. It preserves an honest post-017 readiness
        // comparison without putting raw JSON decode/token construction back
        // into production.
        let legacyReadinessStarted = Date()
        _ = try CommunityCandidateCorpus.loadValidated()
        let legacyReadinessMilliseconds = Date().timeIntervalSince(legacyReadinessStarted) * 1_000
        try expect(indexedReadinessMilliseconds * 10 <= legacyReadinessMilliseconds,
                   "P18 readiness improvement missed indexed=\(Int(indexedReadinessMilliseconds))ms legacy=\(Int(legacyReadinessMilliseconds))ms")
        let results = await retriever.ranked(query: "my vocal gets muddy when guitars arrive", limit: 4)
        let decoded = await retriever.lastQueryDecodedPayloadCount()
        try expect(!results.isEmpty && results.count <= 4 && decoded == results.count && decoded <= 4,
                   "P18 payload decode was not bounded to selected IDs results=\(results.count) decoded=\(decoded)")
        let diagnostics = results.first.map { ($0.lexicalOverlap, $0.lexicalCoverage, $0.scoreMargin) }
        try expect((diagnostics?.0 ?? 0) >= 2 && (diagnostics?.1 ?? 0) <= 1 && (diagnostics?.2 ?? -1) >= 0,
                   "P18 retrieval diagnostics were not populated")

        let root = temporaryRoot("p18-index-states")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let corruptManifest = root.appendingPathComponent("corrupt.json")
        try Data("{}".utf8).write(to: corruptManifest)
        let schemaDriftManifest = root.appendingPathComponent("schema-drift.json")
        try Data(#"{"schema_version":"wrong","corpus_version":"p16-runtime-projection-6212","retrieval_policy_version":"wrong","card_count":6212,"package_017_runtime_count":0,"database":"none.sqlite","database_bytes":0,"database_header_sha256":""}"#.utf8).write(to: schemaDriftManifest)
        let mismatchManifest = root.appendingPathComponent("mismatch.json")
        try Data(#"{"schema_version":"package018-candidate-index/1","corpus_version":"p16-runtime-projection-6212","retrieval_policy_version":"wrong","card_count":6212,"package_017_runtime_count":0,"database":"none.sqlite","database_bytes":0,"database_header_sha256":""}"#.utf8).write(to: mismatchManifest)
        try expect(CandidateRetrievalIndex.open(indexURL: nil, manifestURL: nil).availability == .unavailable &&
                   CandidateRetrievalIndex.open(indexURL: nil, manifestURL: corruptManifest).availability == .corrupt &&
                   CandidateRetrievalIndex.open(indexURL: nil, manifestURL: schemaDriftManifest).availability == .schemaDrift &&
                   CandidateRetrievalIndex.open(indexURL: nil, manifestURL: mismatchManifest).availability == .versionMismatch &&
                   CandidateRetrievalIndex.open(indexURL: nil, manifestURL: mismatchManifest, disabled: true).availability == .disabled,
                   "P18 index failure states drifted")

        // Every structured predicate must be applied before payload decode.
        let filterMatrix: [(CommunityCandidateCorpusFilters, Bool)] = [
            (.init(domain: results[0].card.domain), true), (.init(domain: "not-a-domain"), false),
            (.init(category: results[0].card.category), true), (.init(category: "not-a-category"), false),
            (.init(evidenceClass: results[0].card.evidenceClass), true), (.init(evidenceClass: "not-evidence"), false),
            (.init(logicVersion: results[0].card.logicVersion ?? ""), results[0].card.logicVersion != nil), (.init(logicVersion: "not-a-version"), false),
            (.init(currentContext: results[0].card.currentContext), true), (.init(sourceType: results[0].card.sourceTypes.first ?? ""), !results[0].card.sourceTypes.isEmpty), (.init(sourceType: "not-source"), false),
            (.init(role: results[0].card.roleFacets?.first ?? ""), !(results[0].card.roleFacets ?? []).isEmpty), (.init(role: "not-role"), false),
            (.init(section: results[0].card.sectionFacets?.first ?? ""), !(results[0].card.sectionFacets ?? []).isEmpty), (.init(section: "not-section"), false),
            (.init(packageID: results[0].card.packageID), true), (.init(packageID: "not-package"), false),
            (.init(packageVersion: results[0].card.version), true), (.init(packageVersion: "not-version"), false),
        ]
        for (filters, expected) in filterMatrix {
            let filtered = await retriever.ranked(query: "my vocal gets muddy when guitars arrive", filters: filters, limit: 4)
            try expect(!filtered.isEmpty == expected, "P18 structured filter pre-payload result drifted")
            let filteredDecoded = await retriever.lastQueryDecodedPayloadCount()
            try expect(filteredDecoded == filtered.count, "P18 filter decoded non-selected payload")
        }

        let executor = try TutorToolExecutor()
        let tool = try await executor.execute(TutorToolCall(callID: "p18-diagnostics", name: "search_candidate_corpus", argumentsJSON: #"{"query":"my vocal gets muddy when guitars arrive"}"#), context: TutorRuntimeContext(sourceType: .vocal))
        let object = try JSONSerialization.jsonObject(with: Data(tool.outputJSON.utf8)) as? [String: Any] ?? [:]
        let retrieval = object["retrieval_diagnostics"] as? [String: Any] ?? [:]
        try expect((object["matches"] as? [[String: Any]] ?? []).count <= 4 && retrieval["top_score"] != nil &&
                   retrieval["lexical_coverage"] != nil && retrieval["top_margin"] != nil &&
                   !tool.outputJSON.lowercased().contains("sqlite"),
                   "P18 bounded tool diagnostics or path boundary drifted")
        for query in ["what is the best plugin ever", "I cannot find the control I need in Logic", "my mix sounds wrong but I have no more detail"] {
            let abstention = try await executor.execute(TutorToolCall(callID: "p18-abstain-\(query.count)", name: "search_candidate_corpus", argumentsJSON: "{\"query\":\"\(query)\"}"), context: .init(sourceType: .vocal))
            let abstentionObject = try JSONSerialization.jsonObject(with: Data(abstention.outputJSON.utf8)) as? [String: Any] ?? [:]
            try expect(abstentionObject["availability"] as? String == "ready" && abstentionObject["match"] is NSNull, "P18 frozen abstention regression drifted")
        }
        var ambiguous = results[0]; ambiguous.ambiguity = true
        let matrix: [(CandidateRetrievalAvailability, [CommunityCandidateCorpusRankedCard], Bool)] = [(.unavailable, [], false), (.corrupt, [results[0]], false), (.schemaDrift, [results[0]], false), (.versionMismatch, [results[0]], false), (.disabled, [results[0]], false), (.ready, [results[0]], true), (.ready, [], false), (.ready, [ambiguous, results[1]], true)]
        let knowledge = try GeneralTutorKnowledgeBase.loadValidated(); let procedures = try TutorProcedureCatalog.loadValidated()
        for level in TutorExperienceLevel.allCases {
            for (availabilityState, values, hasMatch) in matrix {
                let stub = CandidateRetrieverStub(availabilityState, values)
                let injected = TutorToolExecutor(knowledge: knowledge, procedures: procedures, candidateRetriever: stub)
                let toolResult = try await injected.execute(TutorToolCall(callID: "p18-\(level.rawValue)-\(availabilityState.rawValue)-\(values.count)", name: "search_candidate_corpus", argumentsJSON: #"{"query":"my vocal gets muddy when guitars arrive"}"#), context: .init(sourceType: .vocal, experience: .init(persistentLevel: level)))
                let json = try JSONSerialization.jsonObject(with: Data(toolResult.outputJSON.utf8)) as? [String: Any] ?? [:]
                try expect(json["availability"] as? String == availabilityState.rawValue && ((json["match"] is NSNull) != hasMatch) && !toolResult.outputJSON.localizedCaseInsensitiveContains("sqlite") && !toolResult.outputJSON.localizedCaseInsensitiveContains("package_id"), "P18 all-level state matrix shape/leak drifted state=\(availabilityState.rawValue) hasMatch=\(hasMatch) output=\(toolResult.outputJSON)")
                if availabilityState != .ready { try expect(toolResult.evidence.first?.kind == .unavailable, "P18 non-ready stub called ranker") }
                if availabilityState == .ready && values.first?.ambiguity == true {
                    let diagnostics = json["retrieval_diagnostics"] as? NSDictionary
                    try expect(diagnostics?["ambiguous"] as? Bool == true, "P18 ambiguity diagnostic drifted diagnostics=\(String(describing: diagnostics)) output=\(toolResult.outputJSON)")
                }
            }
        }
        let queryFailure = CandidateRetrieverStub(.ready, outcome: .queryFailed)
        let queryFailureExecutor = TutorToolExecutor(knowledge: knowledge, procedures: procedures, candidateRetriever: queryFailure)
        let queryFailureResult = try await queryFailureExecutor.execute(TutorToolCall(callID: "p18-query-failure", name: "search_candidate_corpus", argumentsJSON: #"{"query":"my vocal gets muddy when guitars arrive"}"#), context: .init(sourceType: .vocal))
        let queryFailureJSON = try JSONSerialization.jsonObject(with: Data(queryFailureResult.outputJSON.utf8)) as? [String: Any] ?? [:]
        try expect(queryFailureJSON["availability"] as? String == "ready" && queryFailureJSON["outcome"] as? String == CandidateRetrievalOutcomeKind.queryFailed.rawValue && queryFailureJSON["match"] is NSNull && queryFailureResult.evidence.first?.kind == .unavailable,
                   "P19 typed query failure was collapsed into no-match")
        let packageText = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Package.swift"))
        try expect(!packageText.contains("community-reverb-delay-v1.json") && !packageText.contains("package019_cloud_prompt_suite.json") && packageText.contains("CandidateRetrieval.sqlite"),
                   "P18 raw candidate resources remain in product package declaration")
        print("P18_INDEX_OK availability=ready selected=\(results.count) decodedPayloads=\(decoded) failureStates=5 diagnostics=bounded bundle=compiled-index-only indexedReadinessMs=\(Int(indexedReadinessMilliseconds)) legacyReadinessMs=\(Int(legacyReadinessMilliseconds))")
    }

    private func testPackageSixteenGolden() async throws {
        let fixture = try candidateEvaluationFixture("package16-golden-conversations")
        let cases = fixture["cases"] as? [[String: Any]] ?? []
        let turns = Set(cases.compactMap { $0["turn"] as? String })
        try expect(fixture["testOnly"] as? Bool == true && fixture["runtimeEligibility"] as? String == "excluded_from_runtime" &&
                   cases.count == 15 && Set(cases.compactMap { $0["packageSequence"] as? Int }) == Set(1...15) &&
                   Set(["clarification", "better_worse", "no_change", "not_sure", "cannot_find", "why", "causal_uncertainty", "material_disagreement", "one_experiment"]).isSubset(of: turns),
                   "P16 golden fixture coverage or runtime exclusion drifted")
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let executor = try TutorToolExecutor()
        let offline = try OfflineTutorProvider()
        var responseFailures: [String] = []
        for item in cases {
            guard let sequence = item["packageSequence"] as? Int,
                  let query = item["query"] as? String,
                  let rawSourceType = item["sourceType"] as? String,
                  let sourceType = SourceType(rawValue: rawSourceType) else {
                responseFailures.append("malformed-fixture")
                continue
            }
            // Package 018 removes package identity from the live model schema.
            // Keep P16's evaluation-only conversations as shape/safety tests,
            // not a package-targeting retrieval contract.
            let candidate = try await executor.execute(TutorToolCall(callID: "p16-golden-\(sequence)", name: "search_candidate_corpus", argumentsJSON: try jsonString(["query": query])), context: TutorRuntimeContext(sourceType: sourceType))
            if candidate.evidence.first?.kind != .candidateKnowledge || candidate.outputJSON.lowercased().contains("package_id") || candidate.outputJSON.lowercased().contains("package_version") || candidate.outputJSON.lowercased().contains("package_sequence") {
                responseFailures.append("candidate-package-\(sequence)")
                continue
            }
            let root = temporaryRoot("p16-golden-\(sequence)")
            defer { try? FileManager.default.removeItem(at: root) }
            let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: root), tools: executor, fallbackProvider: offline)
            let events = try await collectTurn(engine, query, TutorRuntimeContext(sourceType: sourceType), offline)
            guard let completed = events.compactMap({ event -> (TutorConversationMessage, TutorEvidenceReceipt)? in
                if case let .completed(message, receipt) = event { return (message, receipt) }
                return nil
            }).last else { responseFailures.append("response-\(sequence)-missing"); continue }
            let text = completed.0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = text.lowercased()
            if text.utf8.count < 48 || lower.contains("candidate_receipt") || lower.contains("logic_pro_steps") || lower.contains("sqlite") || lower.contains("{\"") || completed.1.provider.providerIdentifier.contains("openai") {
                responseFailures.append("response-shape-\(sequence)")
            }
            if completed.1.evidence.contains(where: { $0.kind == .heardByModel }) {
                responseFailures.append("heard-claim-\(sequence)")
            }
        }
        try expect(responseFailures.isEmpty, "P16 golden candidate/response shape drifted: \(responseFailures.prefix(12).joined(separator: " | "))")
        print("P16_GOLDEN_OK cases=\(cases.count) turns=\(turns.count) provider=offline modelJudging=not-run")
    }

    private func testPackageSixteenPerformance() async throws {
        let fixture = try candidateEvaluationFixture("package16-golden-conversations")
        let cases = fixture["cases"] as? [[String: Any]] ?? []
        let root = temporaryRoot("p16-startup")
        defer { try? FileManager.default.removeItem(at: root) }
        let startupStarted = Date()
        let executor = try TutorToolExecutor()
        _ = TutorConversationEngine(
            store: TutorConversationStore(rootURL: root),
            tools: executor,
            fallbackProvider: try OfflineTutorProvider()
        )
        let startupMilliseconds = Date().timeIntervalSince(startupStarted) * 1_000
        let loadStarted = Date()
        await executor.warmupCandidateCorpus()
        let loadMilliseconds = Date().timeIntervalSince(loadStarted) * 1_000
        var samples: [Double] = []
        var bytes: [Int] = []
        for (index, item) in cases.enumerated() {
            guard let query = item["query"] as? String else { continue }
            let started = Date()
            let result = try await executor.execute(TutorToolCall(callID: "p16-bench-\(index)", name: "search_candidate_corpus", argumentsJSON: try jsonString(["query": query])), context: TutorRuntimeContext(sourceType: .vocal))
            samples.append(Date().timeIntervalSince(started) * 1_000)
            bytes.append(result.outputJSON.utf8.count)
        }
        let sorted = samples.sorted()
        guard !sorted.isEmpty else { throw TestFailure(description: "P16 benchmark has no samples") }
        let p50 = sorted[(sorted.count - 1) / 2]
        let p95 = sorted[min(sorted.count - 1, Int((Double(sorted.count) * 0.95).rounded(.up)) - 1)]
        let maximum = sorted.last ?? 0
        let maxBytes = bytes.max() ?? 0
        // Native lexical retrieval is a local, bounded candidate aid. Full
        // decode/validation/indexing measured 40.6s-88.4s under current host
        // contention, so keep its runaway ceiling separate and generous; the
        // synchronous startup guard remains the responsiveness contract.
        try expect(startupMilliseconds <= 2_000 && loadMilliseconds <= 120_000 &&
                   p95 <= 5_000 && maximum <= 7_500 && maxBytes <= 16 * 1_024,
                   "P16 benchmark target missed startup=\(Int(startupMilliseconds))ms load=\(Int(loadMilliseconds))ms p95=\(Int(p95)) max=\(Int(maximum)) bytes=\(maxBytes)")
        print("P16_BENCHMARK_OK cases=\(sorted.count) startupMs=\(Int(startupMilliseconds)) loadMs=\(Int(loadMilliseconds)) p50Ms=\(Int(p50)) p95Ms=\(Int(p95)) maxMs=\(Int(maximum)) maxContextBytes=\(maxBytes) memoryMeasurement=not-collected")
    }

    private func testPackageSixteenFallback() async throws {
        let noCorpus = TutorToolExecutor(knowledge: try GeneralTutorKnowledgeBase.loadValidated(), procedures: try TutorProcedureCatalog.loadValidated(), candidateCorpus: nil)
        let unavailable = try await noCorpus.execute(TutorToolCall(callID: "p16-no-corpus", name: "search_candidate_corpus", argumentsJSON: #"{"query":"missing corpus"}"#), context: TutorRuntimeContext(sourceType: .vocal))
        try expect(unavailable.outputJSON.contains("unavailable") && !unavailable.outputJSON.lowercased().contains("sqlite"), "P16 missing/corrupt corpus did not fail soft")
        let executor = try TutorToolExecutor()
        // Copies share the loader actor. Concurrent callers must get one cached
        // corpus outcome, while cancellation stays at each caller boundary.
        let executorCopy = executor
        async let firstWarmup: Void = executor.warmupCandidateCorpus()
        async let secondWarmup: Void = executorCopy.warmupCandidateCorpus()
        async let firstSearch = executor.execute(TutorToolCall(callID: "p16-shared-a", name: "search_candidate_corpus", argumentsJSON: #"{"query":"vocal muddy full mix"}"#), context: TutorRuntimeContext(sourceType: .vocal))
        async let secondSearch = executorCopy.execute(TutorToolCall(callID: "p16-shared-b", name: "search_candidate_corpus", argumentsJSON: #"{"query":"vocal muddy full mix"}"#), context: TutorRuntimeContext(sourceType: .vocal))
        _ = await (firstWarmup, secondWarmup)
        let sharedA = try await firstSearch
        let sharedB = try await secondSearch
        try expect(sharedA.outputJSON == sharedB.outputJSON &&
                   sharedA.evidence.first?.candidateCorpusProvenance?.recordID == sharedB.evidence.first?.candidateCorpusProvenance?.recordID,
                   "P16 concurrent warmup/search did not share a deterministic corpus result")
        let removed = try await executor.execute(TutorToolCall(callID: "p16-package-removed", name: "search_candidate_corpus", argumentsJSON: #"{"query":"routing question","package_id":"removed-package"}"#), context: TutorRuntimeContext(sourceType: .vocal))
        try expect(removed.outputJSON.contains("\"match\":null") && !removed.outputJSON.lowercased().contains("logic_pro_steps") && !removed.outputJSON.lowercased().contains("sqlite"), "P16 removed package fallback drifted")
        let root = temporaryRoot("p16-no-model")
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: root), tools: executor, fallbackProvider: try OfflineTutorProvider())
        let events = try await collectTurn(engine, "No model available; give one safe next step.", TutorRuntimeContext(sourceType: .vocal), FailingConversationProvider(error: .credentialMissing))
        guard let receipt = events.compactMap({ event -> TutorEvidenceReceipt? in if case let .completed(_, receipt) = event { return receipt }; return nil }).last else {
            throw TestFailure(description: "P16 no-model fallback receipt missing")
        }
        try expect(receipt.fallbackReason?.contains("credential") == true && receipt.evidence.allSatisfy { $0.kind != .heardByModel }, "P16 no-model fallback receipt/provenance drifted")
        let engineSource = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/TutorConversation/Sources/TutorConversation/TutorConversationEngine.swift"))
        try expect(engineSource.contains("TutorConversationError.staleResult") && engineSource.contains("TutorConversationError.cancelled"), "P16 stale-result/cancellation guards missing")
        print("P16_FALLBACK_OK noCorpus=fail-soft removedPackage=no-match noModel=offline-receipt cancellation=guarded staleResult=guarded network=not-attempted audio=not-heard")
    }

    private func testPackageFourteenDiagnostic() async throws {
        let packageID = "tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform"
        let corpus = try CommunityCandidateCorpus.loadValidated()
        let fixture = try candidateEvaluationFixture("tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform-evaluation")
        guard let descriptor = corpus.descriptor(packageID) else { throw TestFailure(description: "package-14 descriptor missing") }
        let evaluation = fixture["retrievalCases"] as? [[String: Any]] ?? []
        let supplied = fixture["retrievalTests"] as? [[String: Any]] ?? []
        let scenarios = fixture["scenarios"] as? [[String: Any]] ?? []
        let accounting = fixture["retrievalAccounting"] as? [String: Any] ?? [:]
        let cards = corpus.canonicalCards.filter { $0.packageID == packageID }
        let diagnostics = evaluation.filter { ($0["retrieval_classification"] as? String) != "exact_unique" }
        let exact = evaluation.filter { ($0["retrieval_classification"] as? String) == "exact_unique" }
        let classifications = Dictionary(grouping: evaluation, by: { $0["retrieval_classification"] as? String ?? "" }).mapValues(\.count)
        let testOnlyExactMap = Dictionary(uniqueKeysWithValues: supplied.compactMap { row -> (String, String)? in
            guard let query = row["query"] as? String, let target = row["canonical_qa_id"] as? String else { return nil }
            return (query, target)
        })
        let runtimeURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("research/community_knowledge/runtime_projection/p16/\(packageID).json")
        let runtime = try JSONSerialization.jsonObject(with: Data(contentsOf: runtimeURL))
        let forbidden = ["review", "status", "verification", "eligibility", "procedure", "navigation", "evaluation", "scenario", "sqlite", "test", "expected", "authority"]
        func forbiddenKeys(_ value: Any) -> [String] {
            if let object = value as? [String: Any] { return object.flatMap { key, child in (forbidden.contains { key.lowercased().contains($0) } ? [key] : []) + forbiddenKeys(child) } }
            if let list = value as? [Any] { return list.flatMap(forbiddenKeys) }
            return []
        }
        try expect(descriptor.packageSequence == 14 && descriptor.runtimeCanonicalOnly && descriptor.runtimeStatusFree && descriptor.canonicalCount == 660 && descriptor.utteranceCount == 15_180 && descriptor.scenarioCount == 1_980 && descriptor.retrievalCaseCount == 3_300 && descriptor.contradictionCount == 66 && descriptor.mythCount == 78, "package-14 descriptor boundary drifted")
        try expect(cards.count == 660 && corpus.utterances.filter { $0.canonicalID.hasPrefix("pkg014.qa.") }.isEmpty && cards.allSatisfy { $0.originalReviewStatus == nil && $0.procedureCandidateID == nil && $0.procedureVerificationStatus == nil && $0.authoritativeSupportingSourceIDs == nil && $0.contradictions.isEmpty && $0.myths.isEmpty } && forbiddenKeys(runtime).isEmpty, "package-14 runtime leaked candidate labels or raw artifacts")
        let cardIDs = Set(cards.map(\.id))
        try expect(supplied.count == 660 && testOnlyExactMap.count == 660 && exact.count == 660 && diagnostics.count == 2_640 && scenarios.count == 1_980 && supplied.allSatisfy { ($0["classification"] as? String) == "exact_unique" && ($0["expected_top_1"] as? Bool) == true && ($0["diagnostic_only"] as? Bool) == false } && testOnlyExactMap.values.allSatisfy(cardIDs.contains) && testOnlyExactMap.allSatisfy { corpus.exactNormalizedCanonicalIDs($0.key).isEmpty } && diagnostics.allSatisfy { ($0["diagnostic_only"] as? Bool) == true && ($0["retrieval_expectation"] as? String) == "diagnostic_only" && corpus.exactNormalizedCanonicalIDs($0["query"] as? String ?? "").isEmpty }, "package-14 exact-subset/diagnostic production-boundary drifted")
        try expect(classifications == ["exact_unique": 660, "diagnostic_semantic_only": 660, "diagnostic_multi_intent": 660, "diagnostic_cross_domain_collision": 660, "diagnostic_low_margin": 660] && accounting["classifiedExpectedTop1Count"] as? Int == 660 && accounting["classifiedDiagnosticOnlyCount"] as? Int == 2_640 && accounting["rawNormalizedUniqueMatchCount"] as? Int == 1_296 && accounting["rawNormalizedNonMatchCount"] as? Int == 2_004 && accounting["diagnosticNormalizedExactCollisionCount"] as? Int == 636 && accounting["runtimeNormalizedUniqueMatchCount"] as? Int == 0 && accounting["runtimeNormalizedNonMatchCount"] as? Int == 3_300, "package-14 two-axis accounting drifted")
        let aliases = ["sidechain", "automation", "make it tighter", "humanize", "quiet notes", "fader jumps back", "swing", "randomize timing"]
        try expect(aliases.allSatisfy { corpus.exactNormalizedCanonicalIDs($0).isEmpty }, "package-14 supplied aliases became production exact matches")
        let distinctions = ["sidechain_concept", "logic_sidechain_input_selection", "track_vs_region_automation", "automation_scope_and_order", "read_mode", "volume_word_ride", "region_vs_note_quantization", "q_strength", "q_swing", "groove_templates", "ahead_behind_beat", "velocity_vs_expression_volume", "velocity_scaling", "velocity_randomization", "midi_transform_overview", "select_by_channel", "transform_undo_and_scope"]
        try expect(distinctions.allSatisfy { topic in cards.filter { $0.category == topic }.count == 10 }, "package-14 frozen 17 distinction coverage drifted")
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/TutorConversation/Sources/TutorConversation/TutorSystemPolicy.swift"))
        let rankerSource = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.swift"))
        let policy = ["Candidate corpus material is provisional", "one bounded, user-performed, reversible experiment", "stop condition", "undo"]
        try expect(!rankerSource.contains("exactpkg014qa") && policy.allSatisfy(source.contains), "package-14 provider 17-row/one-experiment or ranker boundary drifted")
        struct DiagnosticCase { let label: String; let query: String; let allowedDomains: Set<String>; let allowedFamilies: Set<String>; let forbiddenDomains: Set<String> }
        // These are authored independently of all fixtures.  They exercise the
        // frozen distinctions without asserting a card ID; older packages are
        // permitted only for their genuinely overlapping semantic families.
        let collisionCases: [DiagnosticCase] = [
            .init(label: "detector versus audible route", query: "Should ducked reverb use an audible effect return or a detector path that does not become the heard route?", allowedDomains: ["reverb", "delay", "sidechain_routing_ducking"], allowedFamilies: ["sends_buses_auxes_shared_effects/aux_sidechain_ducking"], forbiddenDomains: ["midi_velocity_musical_dynamics"]),
            .init(label: "trigger versus target", query: "Is the kick the sidechain trigger while the bass compressor is the processed target, or are those the same audible path?", allowedDomains: ["sidechain_routing_ducking", "compression", "frequency"], allowedFamilies: ["sends_buses_auxes_shared_effects/aux_sidechain_ducking"], forbiddenDomains: ["midi_transform_humanize_batch_editing"]),
            .init(label: "track versus region", query: "Is this volume change owned by track automation or only by this region?", allowedDomains: ["volume_pan_plugin_automation", "automation", "gain_staging"], allowedFamilies: ["gain_staging/region_gain_vs_fader"], forbiddenDomains: ["reverb"]),
            .init(label: "mode versus owner", query: "Before changing Touch or Latch, how do I identify the automation owner and exact parameter?", allowedDomains: ["automation_modes_troubleshooting", "volume_pan_plugin_automation", "automation"], allowedFamilies: ["automation/fundamentals"], forbiddenDomains: ["delay"]),
            .init(label: "automation modes", query: "How do Read, Touch, Latch, Write, Trim, and Relative differ when I need a safe reversible ride?", allowedDomains: ["automation_modes_troubleshooting", "automation"], allowedFamilies: ["automation/fundamentals"], forbiddenDomains: ["midi_quantization_groove"]),
            .init(label: "automation parameter", query: "Is a volume, pan, send, or plug-in parameter ride the right owner and stage for this change?", allowedDomains: ["volume_pan_plugin_automation", "automation", "sends_buses_auxes_shared_effects"], allowedFamilies: ["automation/fundamentals"], forbiddenDomains: ["midi_transform_humanize_batch_editing"]),
            .init(label: "region versus selected notes", query: "Should I quantize the entire MIDI region or just the selected notes?", allowedDomains: ["midi_quantization_groove", "quantization_and_timing", "flex_time_manual_timing"], allowedFamilies: ["quantization_and_timing/midi_quantization", "piano_roll_precise_editing/move_groups_chords"], forbiddenDomains: ["reverb"]),
            .init(label: "strength range swing", query: "In Logic's Piano Roll with MIDI notes selected, does Q-Strength differ from Q-Range and Q-Swing when I preserve this drum groove?", allowedDomains: ["midi_quantization_groove", "quantization_and_timing"], allowedFamilies: ["quantization_and_timing/midi_quantization"], forbiddenDomains: ["gain_staging"]),
            .init(label: "swing random timing", query: "Should I add rhythmic swing or a small random timing change, and why are they not interchangeable?", allowedDomains: ["midi_quantization_groove", "midi_transform_humanize_batch_editing", "quantization_and_timing"], allowedFamilies: ["flex_time_manual_timing/manual_timing_vs_audio_quantize"], forbiddenDomains: ["saturation_harmonic_distortion"]),
            .init(label: "groove template grid", query: "Should this part follow a groove template or the straight grid?", allowedDomains: ["midi_quantization_groove", "quantization_and_timing", "flex_time_manual_timing"], allowedFamilies: ["flex_time_manual_timing/grid_vs_groove"], forbiddenDomains: ["loudness"]),
            .init(label: "ahead behind error", query: "Is this intentionally ahead or behind the beat, or a timing error that needs correction?", allowedDomains: ["midi_quantization_groove", "flex_time_manual_timing", "quantization_and_timing"], allowedFamilies: ["editing/vocal_timing_tightening"], forbiddenDomains: ["stereo_imaging"]),
            .init(label: "velocity volume expression", query: "Does changing MIDI velocity differ from track volume or expression for this instrument?", allowedDomains: ["midi_velocity_musical_dynamics", "gain_staging", "automation"], allowedFamilies: ["vocal_production/dynamics_and_leveling"], forbiddenDomains: ["reverb"]),
            .init(label: "scaling fixed", query: "Should I scale selected velocities or set them all to one fixed value?", allowedDomains: ["midi_velocity_musical_dynamics", "midi_transform_humanize_batch_editing"], allowedFamilies: [], forbiddenDomains: ["delay"]),
            .init(label: "random hierarchy", query: "Can random velocity variation replace intentional accent hierarchy?", allowedDomains: ["midi_velocity_musical_dynamics", "midi_transform_humanize_batch_editing"], allowedFamilies: [], forbiddenDomains: ["saturation_harmonic_distortion"]),
            .init(label: "conditions operations", query: "In MIDI Transform, are selection conditions different from the operations that change notes?", allowedDomains: ["midi_transform_humanize_batch_editing"], allowedFamilies: ["editing/nondestructive_editing_workflow"], forbiddenDomains: ["compression"]),
            .init(label: "notes controllers", query: "Before applying a Logic MIDI Transform, will its selected-event scope affect notes, controllers, pitch bend, aftertouch, or keyswitches?", allowedDomains: ["midi_transform_humanize_batch_editing"], allowedFamilies: [], forbiddenDomains: ["reverb"]),
            .init(label: "batch safe manual", query: "When is a fast batch Transform less safe than changing selected MIDI events manually?", allowedDomains: ["midi_transform_humanize_batch_editing", "editing"], allowedFamilies: ["editing/nondestructive_editing_workflow", "flex_time_manual_timing/transform_undo_and_scope"], forbiddenDomains: ["loudness"]),
        ]
        var failures: [String] = []
        for item in collisionCases {
            if corpus.containsExactNormalizedUtterance(item.query) { failures.append("indexed \(item.label)"); continue }
            guard let ranked = corpus.rank(query: item.query) else { failures.append("unrankable \(item.label)"); continue }
            let family = "\(ranked.card.domain)/\(ranked.card.category)"
            if item.forbiddenDomains.contains(ranked.card.domain) || (!item.allowedDomains.contains(ranked.card.domain) && !item.allowedFamilies.contains(family)) { failures.append("\(item.label) -> \(family)") }
        }
        try expect(failures.isEmpty, "package-14 frozen unfiltered diagnostics: \(failures.prefix(20).joined(separator: " | "))")
        let negativeControls: [(String, Set<String>)] = [
            ("This chorus needs more arrangement strength and density, not MIDI quantization.", ["midi_quantization_groove"]),
            ("Edit one MIDI note velocity by hand.", ["midi_transform_humanize_batch_editing"]),
        ]
        var negativeFailures: [String] = []
        for (query, forbiddenDomains) in negativeControls {
            guard let ranked = corpus.rank(query: query) else { negativeFailures.append("unrankable \(query)"); continue }
            if forbiddenDomains.contains(ranked.card.domain) { negativeFailures.append("\(query) -> \(ranked.card.domain)/\(ranked.card.category)") }
        }
        try expect(negativeFailures.isEmpty, "package-14 semantic cue negative controls drifted: \(negativeFailures.joined(separator: " | "))")
    }

    private func testPackageTwelveUnindexedDiagnostics(_ corpus: CommunityCandidateCorpus, collisionAliases: [String]) throws {
        let distinctions = [
            "Is the delay only in my headphones, or does the recorded region land late?", "How is MIDI input latency different from audio recording latency?", "Did the performer play late, or is the monitoring system late?", "Is this I/O buffer duration or full round-trip latency?", "Should I direct monitor or monitor through Logic effects?", "Is Input Monitoring the same as Record Enable?", "Does interface gain do the same thing as the Logic track volume?", "Why is one microphone on the left side of a stereo track?", "Can the cue routing differ from the dry source Logic records?", "What is the difference between a take and the current comp?", "Is choosing a comp segment different from editing its boundary?", "How does Flatten differ from Flatten and Merge?", "Is Count-in the same as Pre-roll?", "Should I use Cycle or Auto Punch for this correction?", "Should the punch range be only the bad word or a wider phrase boundary?", "Do audio and MIDI Cycle recording behave the same way?", "Is Recording Delay for a repeatable offset or one performance mistake?"
        ]
        var failures: [String] = []
        let allowedDomains: Set<String> = ["recording_latency_monitoring_delay", "input_monitoring_record_enable_signal_flow", "take_folders_comping_multiple_performances", "cycle_punch_replace_recording"]
        // Global ranking can legitimately select these older, already-audited
        // families for broad unindexed wording.  They are explicit test-only
        // allowances, not a P12 card-ID exception or a production shortcut.
        // P13's pre-fader send distinction is the valid unfiltered collision
        // for cue routing versus a recorded dry path; retain it as a semantic
        // family allowance rather than selecting a canonical card ID.
        let allowedAdjacentFamilies: Set<String> = ["automation/fundamentals", "reverb/routing_and_processing", "quantization_and_timing/midi_quantization", "vocal_production/recording_and_monitoring", "vocal_production/editing_comping_tuning_and_alignment", "editing/nondestructive_editing_workflow", "sends_buses_auxes_shared_effects/pre_fader_sends", "plugin_delay_low_latency/pdc_vs_recording_delay"]
        for query in distinctions + collisionAliases {
            if corpus.containsExactNormalizedUtterance(query) { failures.append("indexed \(query)"); continue }
            guard let ranked = corpus.rank(query: query) else { failures.append("unrankable \(query)"); continue }
            let family = "\(ranked.card.domain)/\(ranked.card.category)"
            if !allowedDomains.contains(ranked.card.domain) && !allowedAdjacentFamilies.contains(family) { failures.append("\(query) -> \(family)") }
        }
        try expect(failures.isEmpty, "P12 unindexed recording/monitoring/comping distinctions: \(failures.joined(separator: " | "))")
    }

    private func testPackageElevenUnindexedDiagnostics(_ corpus: CommunityCandidateCorpus) throws {
        struct Case {
            let label: String
            let query: String
            let allowedDomains: Set<String>
            let allowedPackageIDs: Set<String>
            let allowedFamilies: Set<String>
            let forbiddenDomains: Set<String>
            let forbiddenPackageIDs: Set<String>
            init(label: String, query: String, allowedDomains: Set<String>, allowedPackageIDs: Set<String>, allowedFamilies: Set<String> = [], forbiddenDomains: Set<String>, forbiddenPackageIDs: Set<String>) {
                self.label = label
                self.query = query
                self.allowedDomains = allowedDomains
                self.allowedPackageIDs = allowedPackageIDs
                self.allowedFamilies = allowedFamilies
                self.forbiddenDomains = forbiddenDomains
                self.forbiddenPackageIDs = forbiddenPackageIDs
            }
        }
        let cases = [
            Case(label: "bpm versus authority", query: "Did Smart Tempo only detect BPM, or should the project follow this performance?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay", "gain_staging"], forbiddenPackageIDs: []),
            Case(label: "bpm versus downbeat", query: "The BPM is right but bar one is wrong; should I change the downbeat instead?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "wrong bpm versus half double", query: "Is this truly the wrong BPM or a half-time/double-time interpretation?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "smart tempo versus flex", query: "Is this Smart Tempo map authority or a local Flex Time manual timing edit?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping", "flex_time_manual_timing"], allowedPackageIDs: ["tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping", "tracksmith-corpus-010-flex-time-manual-timing"], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "smart tempo versus beat mapping", query: "Should I use Smart Tempo analysis or Beat Mapping for this free performance?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "project versus recorded performance tempo", query: "Should project tempo follow this recorded performance tempo, or should the performance conform to the project?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], allowedFamilies: ["flex_time_manual_timing/flex_follow_on_bars_beats"], forbiddenDomains: ["reverb", "delay", "gain_staging"], forbiddenPackageIDs: []),
            Case(label: "ordinary audio versus loop", query: "Is this ordinary audio or a metadata-aware loop before I follow its tempo?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], allowedFamilies: ["flex_time_manual_timing/imported_audio_tempo"], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "tempo map versus sample rate", query: "Did a tempo map change this recording speed, or is this a sample-rate problem?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "fixed versus variable", query: "Should this song keep one fixed BPM or use a variable tempo map for rubato?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "visual versus musical", query: "The grid looks aligned but musical playback feels wrong; should I trust listening?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], allowedFamilies: ["editing/nondestructive_editing_workflow"], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "keep adapt automatic", query: "How do Keep, Adapt, and Automatic differ before changing this tempo map?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], allowedFamilies: ["flex_time_manual_timing/smart_tempo_keep_adapt_auto"], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "beat markers versus flex", query: "Is this a Smart Tempo beat-marker issue or a Flex/transient-marker edit?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping", "flex_time_manual_timing"], allowedPackageIDs: ["tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping", "tracksmith-corpus-010-flex-time-manual-timing"], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "native speed versus conformance", query: "Is native playback speed correct, or has tempo conformance stretched the imported audio?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay", "flex_time_manual_timing"], forbiddenPackageIDs: ["tracksmith-corpus-010-flex-time-manual-timing"]),
            Case(label: "region to project versus project to region", query: "Should I apply this region tempo to the project, or apply the project tempo to this region?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay"], forbiddenPackageIDs: []),
            Case(label: "bar versus beat following", query: "Should this imported region follow at bar level or beat level, rather than treat Bars and Beats as quality settings?", allowedDomains: ["smart_tempo_bpm_detection_tempo_mapping"], allowedPackageIDs: [], forbiddenDomains: ["reverb", "delay", "flex_time_manual_timing"], forbiddenPackageIDs: ["tracksmith-corpus-010-flex-time-manual-timing"])
        ]
        var failures: [String] = []
        for item in cases {
            if corpus.containsExactNormalizedUtterance(item.query) { failures.append("indexed \(item.label)"); continue }
            guard let ranked = corpus.rank(query: item.query) else { failures.append("unrankable \(item.label)"); continue }
            let family = "\(ranked.card.domain)/\(ranked.card.category)"
            if item.forbiddenDomains.contains(ranked.card.domain) || item.forbiddenPackageIDs.contains(ranked.card.packageID) || (!item.allowedDomains.contains(ranked.card.domain) && !item.allowedPackageIDs.contains(ranked.card.packageID) && !item.allowedFamilies.contains(family)) { failures.append("\(item.label) -> \(ranked.card.id)/\(family)/\(ranked.card.packageID)") }
        }
        try expect(failures.isEmpty, "P11 unindexed Smart Tempo distinctions: \(failures.joined(separator: " | "))")
    }

    private func testPackageTenUnfilteredSemanticDiagnostics(_ corpus: CommunityCandidateCorpus) throws {
        struct Case {
            let label: String
            let query: String
            let allowedPrimaryDomains: Set<String>
            let allowedAdjacentFamilies: Set<String>
            let forbiddenDomains: Set<String>
            init(label: String, query: String, allowedPrimaryDomains: Set<String>, allowedAdjacentFamilies: Set<String>, forbiddenDomains: Set<String>) {
                self.label = label; self.query = query; self.allowedPrimaryDomains = allowedPrimaryDomains; self.allowedAdjacentFamilies = allowedAdjacentFamilies; self.forbiddenDomains = forbiddenDomains
            }
        }
        // These are deliberately independent, unindexed prompts.  A global
        // rank can legitimately select an older package when its documented
        // domain/category covers the distinction; this checks semantic family
        // selection and excludes only genuine false-lead domains.
        let cases = [
            Case(label: "markers", query: "Before I correct timing, how are transient markers different from Flex markers?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/edit_point_placement", "editing/flex_time_algorithms"], forbiddenDomains: ["reverb", "delay", "gain_staging"]),
            Case(label: "whole-region offset versus internal timing", query: "Is this phrase late as one whole region, or do internal events need bounded timing correction?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/vocal_timing_tightening", "editing/nondestructive_editing_workflow"], forbiddenDomains: ["reverb", "delay", "loudness"]),
            Case(label: "audio versus MIDI", query: "How should I distinguish recorded audio waveform timing in Flex Time from MIDI note events in a piano roll?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["quantization_and_timing/audio_quantization_and_flex", "quantization_and_timing/midi_quantization", "quantization_and_timing/quantization_troubleshooting_and_ear_training"], forbiddenDomains: ["reverb", "delay", "gain_staging", "transient_shaping"]),
            Case(label: "Flex Time versus Flex Pitch", query: "Is this a Flex Time timing decision or a Flex Pitch correction?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/flex_time_algorithms", "vocal_production/editing_comping_tuning_and_alignment"], forbiddenDomains: ["reverb", "delay", "stereo_imaging"]),
            Case(label: "source-specific algorithm versus universal preset", query: "Should I choose a timing algorithm for this source, rather than trust one universal Flex preset?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/flex_time_algorithms", "quantization_and_timing/audio_quantization_and_flex"], forbiddenDomains: ["reverb", "delay", "loudness"]),
            Case(label: "grid versus groove", query: "Should this groove follow the grid exactly, or preserve the performance feel?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/smart_tempo_grid_decision", "editing/vocal_timing_tightening", "quantization_and_timing/quantization_troubleshooting_and_ear_training"], forbiddenDomains: ["reverb", "delay", "stereo_imaging"]),
            Case(label: "manual timing versus audio quantization", query: "When is a manual local timing edit safer than audio quantization?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/flex_time_algorithms", "quantization_and_timing/audio_quantization_and_flex"], forbiddenDomains: ["reverb", "delay", "gain_staging"]),
            Case(label: "project follows performance versus performance follows project", query: "Should the project tempo follow this free performance, or should I force the performance to the project grid?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/smart_tempo_grid_decision", "quantization_and_timing/tempo_mapping_and_authority", "smart_tempo_bpm_detection_tempo_mapping/tempo_authority_decision"], forbiddenDomains: ["reverb", "delay", "phase_polarity"]),
            Case(label: "one event versus whole performance", query: "Do I repair one late event, or is the entire performance the timing problem?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/vocal_timing_tightening", "quantization_and_timing/quantization_troubleshooting_and_ear_training"], forbiddenDomains: ["reverb", "delay", "loudness"]),
            Case(label: "source repair versus alternate take", query: "When should I stop repairing timing and choose an alternate take or re-record?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/nondestructive_editing_workflow", "editing/final_cleanup_commit", "transient_shaping/source_editing", "vocal_production/recording_and_monitoring"], forbiddenDomains: ["reverb", "delay", "gain_staging"]),
            Case(label: "visual alignment versus audible correctness", query: "If markers look aligned but the timing feels worse in the arrangement, should I trust my ears and undo?", allowedPrimaryDomains: ["flex_time_manual_timing"], allowedAdjacentFamilies: ["editing/vocal_timing_tightening", "editing/flex_time_algorithms", "quantization_and_timing/quantization_troubleshooting_and_ear_training"], forbiddenDomains: ["reverb", "delay", "gain_staging"]),
        ]
        var failures: [String] = []
        for item in cases {
            if corpus.containsExactNormalizedUtterance(item.query) { failures.append("indexed \(item.label)"); continue }
            guard let ranked = corpus.rank(query: item.query) else { failures.append("unrankable \(item.label)"); continue }
            let family = "\(ranked.card.domain)/\(ranked.card.category)"
            if item.forbiddenDomains.contains(ranked.card.domain) || (!item.allowedPrimaryDomains.contains(ranked.card.domain) && !item.allowedAdjacentFamilies.contains(family)) { failures.append("\(item.label) -> \(ranked.card.id)/\(family)") }
        }
        try expect(failures.isEmpty, "P10 unfiltered semantic/adversarial distinctions: \(failures.prefix(16).joined(separator: " | "))")
    }

    private func testRecordedAudioMIDITimingDomainCue(_ corpus: CommunityCandidateCorpus) throws {
        let comparison = "How should I distinguish recorded audio waveform timing in Flex Time from MIDI note events in a piano roll?"
        guard let comparisonRank = corpus.rank(query: comparison) else {
            throw TestFailure(description: "recorded-audio/MIDI timing cue was unrankable")
        }
        try expect(["flex_time_manual_timing", "quantization_and_timing"].contains(comparisonRank.card.domain), "recorded-audio/MIDI timing cue routed to \(comparisonRank.card.domain)/\(comparisonRank.card.category)")

        let audioOnlyTransient = "This recorded audio waveform transient needs more attack, not a timing or MIDI quantization comparison."
        guard let transientRank = corpus.rank(query: audioOnlyTransient) else {
            throw TestFailure(description: "audio-only transient isolation was unrankable")
        }
        try expect(!["flex_time_manual_timing", "quantization_and_timing"].contains(transientRank.card.domain), "audio-only transient question was incorrectly captured by recorded-audio/MIDI timing cue")
    }

    private func testPackageNineUnfilteredSemanticDiagnostics(_ corpus: CommunityCandidateCorpus) throws {
        struct Case { let label: String; let query: String; let allowed: Set<String>; let forbidden: Set<String> }
        // Independent, unindexed cross-package prompts: they exercise semantic
        // family selection but never assert a fabricated unique card identity.
        let cases = [
            Case(label: "signal versus monitor", query: "In gain staging, the signal-chain meter is unchanged but monitor playback feels louder; which signal level and monitoring bias must I separate?", allowed: ["gain_staging"], forbidden: ["reverb", "delay"]),
            Case(label: "input versus fader", query: "A processor distorts before the channel fader; should I diagnose its input level instead of simply lowering the fader?", allowed: ["gain_staging"], forbidden: ["automation"]),
            // P14's automation-mode troubleshooting is an adjacent semantic
            // family for a region-versus-time-varying fader question; this is
            // a domain allowance, never a canonical-card override.
            Case(label: "region gain versus automation", query: "One syllable is too hot only in the chorus: is a region-level correction different from time-varying fader automation?", allowed: ["gain_staging", "automation", "automation_modes_troubleshooting"], forbidden: ["reverb"]),
            Case(label: "pre post measurement", query: "The pre-fader and post-fader readings disagree while I balance a vocal; what stage does each meter describe?", allowed: ["gain_staging"], forbidden: ["stereo_imaging"]),
            Case(label: "floating versus output clipping", query: "The internal float bus is not red, yet the converter or final delivery clips; which boundary should I inspect?", allowed: ["gain_staging", "clipping_limiting_loudness"], forbidden: ["phase_polarity"]),
            Case(label: "calibration not nominal", query: "Does this analog-model plug-in have its own operating calibration rather than a universal nominal gain target?", allowed: ["gain_staging"], forbidden: ["loudness_normalization"]),
            // P13 owns the VCA-versus-aux/stack routing distinction; it is an
            // allowed adjacent family here, never a card-ID override.
            Case(label: "vca versus aux", query: "For bus processing, should a VCA move members while an aux subgroup or Summing Stack sums their audio, and why does that routing distinction matter?", allowed: ["bus_processing", "automation", "track_stacks_groups_submixes"], forbidden: ["reverb"]),
            Case(label: "individual shared bus", query: "A shared drum bus makes cymbals react to kick hits; when is individual treatment more diagnostic than shared processing?", allowed: ["bus_processing"], forbidden: ["vocal_production"]),
            Case(label: "interaction not glue", query: "A shared bus compressor seems to glue the drum bus only because one source triggers gain reduction; how do I test bus interaction rather than assume automatic glue?", allowed: ["bus_processing", "clipping_limiting_loudness", "compression"], forbidden: ["delay"]),
            Case(label: "clean gain versus processors", query: "Before saturation, clipping, compression, or limiting, how can gain staging level-match a clean gain change and inspect true peak to hear what each process changes?", allowed: ["gain_staging", "clipping_limiting_loudness", "saturation_harmonic_distortion"], forbidden: ["reverb"]),
            Case(label: "sample true peak", query: "Sample peaks look safe but a codec or converter reconstruction may overshoot; is that a true-peak question?", allowed: ["clipping_limiting_loudness"], forbidden: ["automation"]),
            Case(label: "peak rms lufs", query: "Peak, RMS, and LUFS disagree on this chorus; which measurement answers level, energy, and perceived programme loudness?", allowed: ["clipping_limiting_loudness"], forbidden: ["phase_polarity"]),
            Case(label: "meter windows", query: "A short loud chorus and a quiet verse give different momentary, short-term, and integrated readings; which time range is relevant?", allowed: ["clipping_limiting_loudness"], forbidden: ["bus_processing"]),
            Case(label: "crest lra", query: "Can a crest-factor change and loudness range change answer different dynamic questions rather than one quality score?", allowed: ["clipping_limiting_loudness"], forbidden: ["automation"]),
            Case(label: "delivery artistic", query: "A loudness delivery specification constrains LUFS and true peak, but can it decide the artistic density or punch I prefer?", allowed: ["clipping_limiting_loudness"], forbidden: ["editing"]),
            Case(label: "louder playback", query: "In gain staging, the louder playback A/B feels better until monitor level is matched; how do I avoid calling louder monitoring a better loudness master?", allowed: ["gain_staging", "clipping_limiting_loudness"], forbidden: ["reverb"]),
        ]
        var failures: [String] = []
        for item in cases {
            if corpus.containsExactNormalizedUtterance(item.query) { failures.append("indexed \(item.label)"); continue }
            guard let ranked = corpus.rank(query: item.query) else { failures.append("unrankable \(item.label)"); continue }
            if !item.allowed.contains(ranked.card.domain) || item.forbidden.contains(ranked.card.domain) { failures.append("\(item.label) -> \(ranked.card.id)/\(ranked.card.domain)") }
        }
        try expect(failures.isEmpty, "P9 bounded unfiltered semantic diagnostics: \(failures.prefix(16).joined(separator: " | "))")
    }

    private func testPackageEightSemanticDiagnostics(_ corpus: CommunityCandidateCorpus) throws {
        struct Case {
            let label: String
            let query: String
            let allowedDomains: Set<String>
            let allowedAdjacentFamilies: Set<String>
            let forbiddenDomains: Set<String>
            let forbiddenPackageIDs: Set<String>
            init(label: String, query: String, allowedDomains: Set<String>, allowedAdjacentFamilies: Set<String> = [], forbiddenDomains: Set<String>, forbiddenPackageIDs: Set<String>) {
                self.label = label; self.query = query; self.allowedDomains = allowedDomains; self.allowedAdjacentFamilies = allowedAdjacentFamilies; self.forbiddenDomains = forbiddenDomains; self.forbiddenPackageIDs = forbiddenPackageIDs
            }
        }
        // These prompts are authored outside the supplied utterance corpus.
        // They assert an honest diagnostic family and false-lead exclusion, not
        // a brittle canonical identity when several cards could be useful.
        let cases = [
            Case(label: "source performance versus edit", query: "This vocal take lacks conviction; would slicing and tightening manufacture a stronger performance instead of fixing an edit problem?", allowedDomains: ["editing", "vocal_production"], allowedAdjacentFamilies: [], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "realism versus distracting noise", query: "The breaths make this singer feel human, but a few are distracting; should I reduce only those rather than erase all realism?", allowedDomains: ["editing", "vocal_production"], allowedAdjacentFamilies: [], forbiddenDomains: ["transient_shaping"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "boundary click versus plosive", query: "A click occurs only at the comp boundary between selected takes, while the P consonant is an embedded waveform transient inside one word; are these different edit decisions?", allowedDomains: ["editing"], allowedAdjacentFamilies: ["take_folders_comping_multiple_performances/edit_comp_boundaries"], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "timing correction versus tempo map", query: "A live drummer drifts with the song’s intended tempo changes; should I correct one local hit or decide whether the tempo map itself is wrong?", allowedDomains: ["editing", "arrangement", "flex_time_manual_timing", "smart_tempo_bpm_detection_tempo_mapping"], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "useful alignment versus overtightening", query: "The vocal doubles now align exactly but feel smaller and less human; how do I keep groove alignment without overtightening every syllable?", allowedDomains: ["editing", "layering", "phase_polarity"], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "layered instrument versus competing ensemble", query: "My stacked synth parts should read as one layered instrument, yet each part competes for the melody; which role decision comes first?", allowedDomains: ["layering", "arrangement"], forbiddenDomains: ["transient_shaping"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "missing role versus redundant overstack", query: "The chorus sounds small with many tracks; how can I tell a missing musical role from redundant layers that only overstack the same job?", allowedDomains: ["layering", "arrangement"], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "layer role families", query: "Before adding another kick layer, how do transient, body, sub, texture, width, and atmosphere roles differ in the arrangement?", allowedDomains: ["layering", "arrangement", "frequency_allocation"], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "frequency overlap versus redundancy", query: "Two guitar layers overlap in frequency, but one supplies rhythmic attack and the other texture; is overlap automatically redundant?", allowedDomains: ["layering", "frequency_allocation", "arrangement"], forbiddenDomains: ["transient_shaping"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
            Case(label: "original isolation versus separated estimate", query: "A machine-separated vocal estimate was repaired and consolidated; how should I preserve that derived identity instead of calling it the untouched original isolated source?", allowedDomains: ["editing", "layering", "phase_polarity", "stereo_imaging"], forbiddenDomains: ["saturation_harmonic_distortion"], forbiddenPackageIDs: ["tracksmith-corpus-006-saturation-transient-shaping"]),
        ]
        var failures: [String] = []
        for item in cases {
            if corpus.containsExactNormalizedUtterance(item.query) {
                if failures.count < 10 { failures.append("indexed \(item.label)") }
                continue
            }
            guard let ranked = corpus.rank(query: item.query, filters: .init()) else {
                if failures.count < 10 { failures.append("unrankable \(item.label)") }
                continue
            }
            let family = "\(ranked.card.domain)/\(ranked.card.category)"
            if (!item.allowedDomains.contains(ranked.card.domain) && !item.allowedAdjacentFamilies.contains(family)) || item.forbiddenDomains.contains(ranked.card.domain) || item.forbiddenPackageIDs.contains(ranked.card.packageID) {
                if failures.count < 10 { failures.append("\(item.label) -> \(ranked.card.id)/\(ranked.card.domain)/\(ranked.card.packageID)") }
            }
        }
        try expect(failures.isEmpty, "P8 unindexed semantic diagnostics: \(failures.joined(separator: " | "))")
    }

    private func testPackageSevenSemanticDiagnostics(_ corpus: CommunityCandidateCorpus) throws {
        struct Case { let label: String; let query: String; let domains: Set<String> }
        let cases=[
            Case(label:"phase versus polarity",query:"is phase the same thing as polarity on this two mic recording",domains:["phase_polarity"]),
            Case(label:"time offset versus polarity inversion",query:"two microphones on the same drum arrive at different times: should I test a tiny time offset before polarity inversion",domains:["phase_polarity","delay"]),
            Case(label:"relationship versus isolated waveform",query:"the waveform looks aligned alone but the pair thins in mono",domains:["phase_polarity","stereo_imaging"]),
            Case(label:"width versus panning",query:"I have one mono guitar and only move its pan position left; does that movement create source width",domains:["panning","stereo_imaging"]),
            Case(label:"Stereo Pan versus Balance",query:"for an uneven stereo file, should I use Stereo Pan to reposition the image or Balance to attenuate one side",domains:["panning","level_balancing"]),
            Case(label:"source position versus source width",query:"can I move a wide pad without making its source wider",domains:["panning","stereo_imaging"]),
            Case(label:"correlation warning versus automatic failure",query:"the correlation meter briefly dips negative but mono stays intact: is that a warning to investigate rather than automatic mix failure",domains:["stereo_imaging","phase_polarity"]),
            Case(label:"Mid Side components versus stems",query:"are Mid and Side sum and difference components rather than separate musical object stems",domains:["stereo_imaging"]),
            Case(label:"isolated sources versus separated estimates",query:"for a phase and panning evidence decision, is a machine-separated vocal only an estimate rather than true original multitrack isolation",domains:["phase_polarity","stereo_imaging","panning"]),
            Case(label:"mono compatibility versus artistic preference",query:"can I prefer a creatively wide chorus when its mono compatibility is technically acceptable but different",domains:["phase_polarity","stereo_imaging","panning","arrangement"]),
        ]
        var failures:[String]=[]
        for item in cases {
            if corpus.containsExactNormalizedUtterance(item.query) { failures.append("indexed \(item.label)"); continue }
            guard let ranked=corpus.rank(query:item.query,filters:.init()) else { failures.append("unrankable \(item.label)"); continue }
            if !item.domains.contains(ranked.card.domain) || ranked.card.packageID == "tracksmith-corpus-006-saturation-transient-shaping" { failures.append("\(item.label) -> \(ranked.card.id)/\(ranked.card.domain)") }
            if failures.count >= 10 { break }
        }
        try expect(failures.isEmpty,"P7 unindexed semantic diagnostics: \(failures.joined(separator: " | "))")
    }

    private func testPackageSixAdversarialDiagnostics(_ corpus: CommunityCandidateCorpus) throws {
        struct AdversarialCase {
            let query: String
            let allowedDomains: Set<String>
            let forbiddenDomains: Set<String>
            let forbiddenPackageIDs: Set<String>
        }
        // These prompts are deliberately absent from supplied utterances.  The
        // expected sets name diagnostic families, never one canonical card:
        // several candidate cards can be a valid next hypothesis.
        let prompts=[
            AdversarialCase(query:"is this saturation or clean gain and compression", allowedDomains:["saturation_harmonic_distortion","level_balancing","compression"], forbiddenDomains:["transient_shaping"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"is clipping the same as limiting", allowedDomains:["saturation_harmonic_distortion","compression"], forbiddenDomains:["transient_shaping"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"are these harmonics aliasing or intermodulation", allowedDomains:["saturation_harmonic_distortion"], forbiddenDomains:["transient_shaping"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"is source color really arrangement masking", allowedDomains:["saturation_harmonic_distortion","arrangement","frequency_allocation"], forbiddenDomains:["transient_shaping"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"is transient attack just continuous brightness", allowedDomains:["transient_shaping","frequency_allocation"], forbiddenDomains:["saturation_harmonic_distortion"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"is sustain shaping reverb or gating", allowedDomains:["transient_shaping","reverb","delay"], forbiddenDomains:["saturation_harmonic_distortion"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"is this envelope timing note length performance or source", allowedDomains:["transient_shaping","vocal_production","arrangement"], forbiddenDomains:["saturation_harmonic_distortion"], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
            AdversarialCase(query:"is documented saturation processor behavior different from artistic preference", allowedDomains:["saturation_harmonic_distortion","transient_shaping"], forbiddenDomains:[], forbiddenPackageIDs:["tracksmith-corpus-005-automation"]),
        ]
        var failures:[String]=[]
        for prompt in prompts {
            if corpus.containsExactNormalizedUtterance(prompt.query) { failures.append("indexed adversarial prompt: \(prompt.query)"); continue }
            guard let result=corpus.rank(query: prompt.query, filters: .init()) else { failures.append("unrankable: \(prompt.query)"); continue }
            let card=result.card
            if !prompt.allowedDomains.contains(card.domain) || prompt.forbiddenDomains.contains(card.domain) || prompt.forbiddenPackageIDs.contains(card.packageID) {
                failures.append("\(prompt.query) -> \(card.id)/\(card.domain)/\(card.packageID)")
            }
            if failures.count >= 12 { break }
        }
        try expect(failures.isEmpty, "P6 unindexed adversarial diagnostics: \(failures.joined(separator: " | "))")
    }

    private func testCandidateCorpus() async throws {
        let corpus = try CommunityCandidateCorpus.loadValidated()
        try testPackageSixAdversarialDiagnostics(corpus)
        try await testPackageTwoCandidateCorpus()
        // P10/P11/P13/P14 add canonical-only cards; P14 contributes 660
        // cards while adding no live utterances, contradictions, or myths.
        try expect(corpus.canonicalCards.count == 6_212, "candidate canonical count drifted")
        try expect(corpus.utterances.count == 62_737, "candidate utterance count drifted")
        try expect(corpus.contradictions.count == 330 && corpus.myths.count == 382, "candidate disagreement counts drifted")
        try expect(corpus.descriptor("community-vocal-quantization-v1")?.scenarioCount == 428,
                   "package-1 evaluation descriptor drifted")
        try expect(corpus.descriptor("community-level-balancing-eq-v1")?.scenarioCount == 714,
                   "package-2 evaluation descriptor drifted")
        guard let packageThreeDescriptor = corpus.descriptor("community-compression-arrangement-frequency-allocation-v1") else {
            throw TestFailure(description: "package-3 descriptor missing")
        }
        try expect(packageThreeDescriptor.packageSequence == 3 && packageThreeDescriptor.scenarioCount == 1_050 &&
                   packageThreeDescriptor.evaluationCaseCount == 1_750 &&
                   packageThreeDescriptor.evaluationKindCounts == ["retrieval": 350, "paraphrase": 350, "clarification": 350, "tradeoff": 350, "myth_resistance": 350],
                   "package-3 descriptor mixed-evaluation truth drifted")
        guard let packageFourDescriptor = corpus.descriptor("community-reverb-delay-v1") else {
            throw TestFailure(description: "package-4 descriptor missing")
        }
        try expect(packageFourDescriptor.packageSequence == 4 && packageFourDescriptor.canonicalCount == 300 &&
                   packageFourDescriptor.utteranceCount == 6_600 && packageFourDescriptor.scenarioCount == 900 &&
                   packageFourDescriptor.retrievalCaseCount == 1_500 && packageFourDescriptor.evaluationCaseCount == 0 &&
                   packageFourDescriptor.canonicalOriginalStatus == "candidate_not_yet_human_reviewed",
                   "package-4 descriptor/review boundary drifted")
        guard let packageFiveDescriptor = corpus.descriptor("tracksmith-corpus-005-automation") else {
            throw TestFailure(description: "package-5 descriptor missing")
        }
        try expect(packageFiveDescriptor.packageSequence == 5 && packageFiveDescriptor.canonicalCount == 240 &&
                   packageFiveDescriptor.utteranceCount == 5_280 && packageFiveDescriptor.scenarioCount == 720 &&
                   packageFiveDescriptor.retrievalCaseCount == 1_200 && packageFiveDescriptor.contradictionCount == 36 &&
                   packageFiveDescriptor.mythCount == 44 && packageFiveDescriptor.procedureOriginalStatus == "candidate_not_yet_human_reviewed",
                   "package-5 descriptor/review boundary drifted")
        guard let packageSixDescriptor = corpus.descriptor("tracksmith-corpus-006-saturation-transient-shaping") else {
            throw TestFailure(description: "package-6 descriptor missing")
        }
        try expect(packageSixDescriptor.packageSequence == 6 && packageSixDescriptor.canonicalCount == 384 &&
                   packageSixDescriptor.utteranceCount == 8_448 && packageSixDescriptor.scenarioCount == 1_152 &&
                   packageSixDescriptor.retrievalCaseCount == 1_920 && packageSixDescriptor.contradictionCount == 42 &&
                   packageSixDescriptor.mythCount == 50 && packageSixDescriptor.procedureOriginalStatus == "candidate_not_yet_human_reviewed",
                   "package-6 descriptor/review boundary drifted")
        guard let packageSevenDescriptor = corpus.descriptor("tracksmith-corpus-007-phase-polarity-stereo-imaging-panning"),
              let packageEightDescriptor = corpus.descriptor("tracksmith-corpus-008-editing-layering") else {
            throw TestFailure(description: "package-7/8 descriptor missing")
        }
        try expect(packageSevenDescriptor.packageSequence == 7 && packageSevenDescriptor.canonicalCount == 396 &&
                   packageEightDescriptor.packageSequence == 8 && packageEightDescriptor.canonicalCount == 420 &&
                   packageEightDescriptor.utteranceCount == 9_240 && packageEightDescriptor.scenarioCount == 1_260 &&
                   packageEightDescriptor.retrievalCaseCount == 2_100 && packageEightDescriptor.contradictionCount == 46 &&
                   packageEightDescriptor.mythCount == 54,
                   "package-7/8 descriptor additive inventory drifted")
        let packageOneEvaluation = try candidateEvaluationFixture("community-vocal-quantization-v1-evaluation")
        let packageTwoEvaluation = try candidateEvaluationFixture("community-level-balancing-eq-v1-evaluation")
        let packageThreeEvaluation = try candidateEvaluationFixture("community-compression-arrangement-frequency-allocation-v1-evaluation")
        let packageFourEvaluation = try candidateEvaluationFixture("community-reverb-delay-v1-evaluation")
        let packageFiveEvaluation = try candidateEvaluationFixture("tracksmith-corpus-005-automation-evaluation")
        let p1Scenarios = packageOneEvaluation["scenarios"] as? [[String: Any]] ?? []
        let p2Scenarios = packageTwoEvaluation["scenarios"] as? [[String: Any]] ?? []
        let p3Scenarios = packageThreeEvaluation["scenarios"] as? [[String: Any]] ?? []
        let p2Retrieval = packageTwoEvaluation["retrievalCases"] as? [[String: Any]] ?? []
        let p3Evaluations = packageThreeEvaluation["evaluationCases"] as? [[String: Any]] ?? []
        let p4Scenarios = packageFourEvaluation["scenarios"] as? [[String: Any]] ?? []
        let p4Retrieval = packageFourEvaluation["retrievalCases"] as? [[String: Any]] ?? []
        let p4RetrievalAccounting = packageFourEvaluation["retrievalAccounting"] as? [String: Any] ?? [:]
        let p5Scenarios = packageFiveEvaluation["scenarios"] as? [[String: Any]] ?? []
        let p5Retrieval = packageFiveEvaluation["retrievalCases"] as? [[String: Any]] ?? []
        let p5RetrievalTests = packageFiveEvaluation["retrievalTests"] as? [[String: Any]] ?? []
        let p5Integrity = packageFiveEvaluation["integrityCases"] as? [[String: Any]] ?? []
        let p5Accounting = packageFiveEvaluation["retrievalAccounting"] as? [String: Any] ?? [:]
        let p5Turns = p5Scenarios.compactMap { ($0["messages"] as? [[String: Any]])?.count }
        try expect(p5Scenarios.count == 720 && p5Turns.filter { $0 == 4 }.count == 480 && p5Turns.filter { $0 == 6 }.count == 240 &&
                   p5Scenarios.allSatisfy { $0["review_state"] as? String == "candidate_not_yet_human_reviewed" && !($0["expected_behaviors"] as? [String] ?? []).isEmpty && !($0["forbidden_behaviors"] as? [String] ?? []).isEmpty },
                   "package-5 scenario structure/review boundary drifted")
        try expect(p5Retrieval.count == 1_200 && p5RetrievalTests.count == 100 && p5Integrity.count == 15 &&
                   p5Accounting["rawPackageUniqueExactCaseCount"] as? Int == 480 && p5Accounting["rawPackageNonExactLexicalCaseCount"] as? Int == 720 &&
                   p5Accounting["runtimeSafeUniqueExactCaseCount"] as? Int == 480 && p5Accounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 720,
                   "package-5 evaluation-only inventory/accounting drifted")
        var p5RankFailures: [String] = []
        for fixture in p5Retrieval + p5RetrievalTests {
            guard let query = fixture["query"] as? String,
                  let expected = fixture["expected_canonical_ids"] as? [String], !expected.isEmpty,
                  let ranked = corpus.rank(query: query, filters: .init(packageID: "tracksmith-corpus-005-automation")) else {
                throw TestFailure(description: "package-5 retrieval fixture could not rank")
            }
            let forbidden = fixture["forbidden_canonical_ids"] as? [String] ?? []
            let fixtureID = fixture["id"] as? String ?? "unknown"
            if forbidden.contains(ranked.card.id), p5RankFailures.count < 20 { p5RankFailures.append("\(fixtureID) -> \(ranked.card.id)") }
            if corpus.exactNormalizedCanonicalIDs(query) == expected && ranked.card.id != expected[0] && p5RankFailures.count < 20 { p5RankFailures.append("exact \(fixtureID) -> \(ranked.card.id)") }
        }
        try expect(p5RankFailures.isEmpty, "package-5 retrieval ranking failures (first \(p5RankFailures.count)): \(p5RankFailures.joined(separator: " | "))")
        try expect(p5Integrity.allSatisfy { ($0["id"] as? String)?.hasPrefix("pkg005.test.integrity.") == true }, "package-5 integrity fixture IDs drifted")
        try expect(p1Scenarios.count == 428 && p2Scenarios.count == 714 && p2Retrieval.count == 714,
                   "evaluation-only fixture counts drifted")
        try expect(p3Evaluations.count == 1_750 && Set(p3Evaluations.compactMap { $0["kind"] as? String }) == ["retrieval", "paraphrase", "clarification", "tradeoff", "myth_resistance"] &&
                   p3Evaluations.allSatisfy { $0["package_sequence"] as? Int == 3 && $0["review_status"] as? String == "candidate_not_yet_human_reviewed" },
                   "package-3 evaluation-only fixture provenance drifted")
        try expect(p3Scenarios.count == 1_050 && p3Scenarios.allSatisfy {
            ($0["turns"] as? [[String: Any]])?.count == 6 && $0["package_sequence"] as? Int == 3 &&
            $0["review_status"] as? String == "candidate_not_yet_human_reviewed" &&
            !($0["required_memory"] as? [String] ?? []).isEmpty && !($0["forbidden_behavior"] as? [String] ?? []).isEmpty
        }, "package-3 six-turn scenario provenance/behavior drifted")
        let p4TurnCounts = p4Scenarios.compactMap { ($0["turns"] as? [[String: Any]])?.count }
        try expect(p4Scenarios.count == 900 && p4TurnCounts.filter { $0 == 4 }.count == 600 &&
                   p4TurnCounts.filter { $0 == 6 }.count == 300 && p4Scenarios.allSatisfy {
            ($0["turns"] as? [[String: Any]])?.count == 4 || ($0["turns"] as? [[String: Any]])?.count == 6
        } && p4Scenarios.allSatisfy {
            $0["package_sequence"] as? Int == 4 && $0["review_status"] as? String == "synthetic_multiturn_evaluation" &&
            !($0["required_behaviors"] as? [String] ?? []).isEmpty && !($0["forbidden_behaviors"] as? [String] ?? []).isEmpty
        }, "package-4 600 four-turn / 300 six-turn synthetic scenario provenance drifted")
        // P16 reserves equality authority for test-only fixtures. P4 predates
        // explicit classifications, so reconstruct its exact-unique subset
        // from the fixture's literal card-question identity. The other rows
        // are paraphrase/cross-domain diagnostics: package-filtered rankability
        // is useful, but their fixture namespace cannot impose a strict domain.
        let normalizeFixture: (String) -> String = { value in
            value.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
        }
        var p4ExactUnique = 0
        var p4Diagnostics = 0
        var p4DiagnosticDomains: Set<String> = []
        var p4ProductionExactLeakage: [String] = []
        var p4ExactFixtureLookup: [String: Set<String>] = [:]
        var p4ExactFixtureRows: [(query: String, expectedID: String)] = []
        var p4RankedCount = 0
        var p4PackageViolations: [String] = []
        for fixture in p4Retrieval {
            guard let query = fixture["query"] as? String,
                  let expectedIDs = fixture["expected_canonical_ids"] as? [String], expectedIDs.count == 1,
                  let ranked = corpus.rank(query: query, filters: .init(packageID: "community-reverb-delay-v1")) else {
                throw TestFailure(description: "package-4 fixture could not rank")
            }
            p4RankedCount += 1
            p4DiagnosticDomains.insert(ranked.card.domain)
            if ranked.card.packageID != "community-reverb-delay-v1", p4PackageViolations.count < 20 {
                p4PackageViolations.append(fixture["id"] as? String ?? "unknown")
            }
            let normalizedQuery = normalizeFixture(query)
            let isTestOnlyExact = corpus.card(expectedIDs[0]).map {
                normalizeFixture($0.question) == normalizedQuery
            } ?? false
            if !corpus.exactNormalizedCanonicalIDs(query).isEmpty, p4ProductionExactLeakage.count < 20 {
                p4ProductionExactLeakage.append(fixture["id"] as? String ?? "unknown")
            }
            if isTestOnlyExact {
                p4ExactFixtureLookup[normalizedQuery, default: []].insert(expectedIDs[0])
                p4ExactFixtureRows.append((normalizedQuery, expectedIDs[0]))
                p4ExactUnique += 1
            } else {
                p4Diagnostics += 1
            }
        }
        let p4ExactResolverFailures = p4ExactFixtureRows.filter {
            p4ExactFixtureLookup[$0.query] != Set([$0.expectedID])
        }
        // There are 315 runtime-safe exact fixture rows, but sixteen pairs
        // normalize to the same card question.  The test-only resolver owns
        // normalized identities, so it intentionally has 299 unique keys.
        try expect(p4ExactFixtureLookup.count == 299 && p4ExactFixtureLookup.allSatisfy { _, targets in
            targets.count == 1 && targets.allSatisfy { corpus.card($0)?.packageID == "community-reverb-delay-v1" }
        } && p4ExactResolverFailures.isEmpty && p4RankedCount == p4Retrieval.count &&
                   p4DiagnosticDomains == ["delay", "reverb"] && p4PackageViolations.isEmpty &&
                   p4ProductionExactLeakage.isEmpty,
                   "package-4 test-only exact/diagnostic purity split drifted: keys=\(p4ExactFixtureLookup.count) resolverFailures=\(p4ExactResolverFailures.count) ranked=\(p4RankedCount)/\(p4Retrieval.count) domains=\(p4DiagnosticDomains.sorted()) packageViolations=\(p4PackageViolations.count) productionExactLeakage=\(p4ProductionExactLeakage.count)")
        try expect(p4RetrievalAccounting["rawPackageUniqueExactCaseCount"] as? Int == 316 &&
                   p4RetrievalAccounting["rawPackageNonExactLexicalCaseCount"] as? Int == 1_184 &&
                   p4RetrievalAccounting["runtimeSafeUniqueExactCaseCount"] as? Int == 315 &&
                   p4RetrievalAccounting["runtimeSafeNonExactLexicalCaseCount"] as? Int == 1_185 &&
                   p4RetrievalAccounting["safetyRedactedExactFixtureIDs"] as? [String] == ["eval.delay.logic_pro_specific.logic_region_delay.1"] &&
                   p4ExactUnique == 315 && p4Diagnostics == 1_185 &&
                   corpus.exactNormalizedCanonicalIDs("How do I use the Region inspector Delay parameter without creating echoes?").isEmpty,
                   "package-4 runtime-safe exact/non-exact evaluation accounting drifted")
        // Package-filtered exact/candidate sweep is migration-integrity coverage,
        // not independent semantic-retrieval proof: these prompts originate in
        // the supplied candidate package itself.
        var p3ExactMatches = 0
        var p3NonExactMatches = 0
        var p3FixtureResolver: [String: Set<String>] = [:]
        var p3FixtureRows: [(String, String)] = []
        var p3DiagnosticFailures: [String] = []
        for fixture in p3Evaluations {
            guard let prompt = fixture["prompt"] as? String,
                  let expectedID = fixture["canonical_id"] as? String,
                  let forbidden = fixture["forbidden_canonical_ids"] as? [String],
                  let ranked = corpus.rank(query: prompt, filters: .init(packageID: "community-compression-arrangement-frequency-allocation-v1")) else {
                throw TestFailure(description: "package-3 evaluation fixture could not rank")
            }
            let isExactMigrationCase = (fixture["kind"] as? String == "retrieval" || fixture["kind"] as? String == "paraphrase")
            if forbidden.contains(ranked.card.id) || ranked.card.packageID != "community-compression-arrangement-frequency-allocation-v1" { if p3DiagnosticFailures.count < 24 { p3DiagnosticFailures.append(expectedID) } }
            if isExactMigrationCase {
                let key = normalizeFixture(prompt); p3FixtureResolver[key, default: []].insert(expectedID); p3FixtureRows.append((key, expectedID))
                p3ExactMatches += 1
            } else {
                p3NonExactMatches += 1
            }
        }
        try expect(p3ExactMatches == 700 && p3NonExactMatches == 1_050 && p3FixtureResolver.count == 700 && p3FixtureRows.count == 700 && p3FixtureRows.allSatisfy { p3FixtureResolver[$0.0] == Set([$0.1]) } && p3FixtureResolver.values.allSatisfy { $0.count == 1 && $0.allSatisfy { corpus.card($0)?.packageID == "community-compression-arrangement-frequency-allocation-v1" } } && p3DiagnosticFailures.isEmpty && p3Evaluations.allSatisfy { corpus.exactNormalizedCanonicalIDs($0["prompt"] as? String ?? "").isEmpty },
                   "package-3 exact/non-exact migration accounting drifted")
        // Stable P3 traps assert diagnosis family/domain and false leads, not a
        // single card: several cards can honestly represent the same cause.
        let legacyP3CrossDomainFixtures: [(query: String, expectedDomains: Set<String>, forbiddenIDs: [String])] = [
            ("My vocal vanishes below dense guitars; should I compress the singer harder or remove a guitar role first?", ["arrangement"], ["compression.vocal.track_print"]),
            ("Kick and bass collide even after compressor tweaks. Which should own the deepest role before EQ?", ["frequency_allocation"], ["compression.drums.kick_bass_sidechain"]),
            ("The chorus has more layers but the hook is harder to hear. Is a bright EQ boost the first move?", ["arrangement"], ["eq.source.full_mix.harsh"]),
            ("Piano and vocal mask each other when the words start; does compression solve that before voicing?", ["vocal_production", "frequency_allocation"], ["compression.foundation.compression_vs_automation"]),
            ("I keep raising the lead vocal fader but it is still buried under backing parts. What hierarchy should win?", ["level_balancing"], ["frequency.vocal_midrange.vocal_formants"]),
            ("Should I high-pass every non-bass track and add bus compression to make room for kick and bass?", ["frequency_allocation"], ["compression.bus.glue"]),
        ]
        for fixture in legacyP3CrossDomainFixtures {
            try expect(!corpus.containsExactNormalizedUtterance(fixture.query), "legacy P3 adversarial query became indexed")
            guard let ranked = corpus.rank(query: fixture.query) else { throw TestFailure(description: "legacy P3 adversarial query did not rank") }
            try expect(fixture.expectedDomains.contains(ranked.card.domain) && !fixture.forbiddenIDs.contains(ranked.card.id),
                       "legacy P3 cross-domain diagnosis drifted for \(fixture.query): \(ranked.card.id) [\(ranked.card.domain)]")
        }
        // P4 additions are deliberately unindexed and stricter: each tests a
        // supplied P4 distinction with a concrete canonical family.
        let p4CrossDomainFixtures: [(query: String, expectedIDs: Set<String>, forbiddenIDs: [String])] = [
            ("I want more depth on the lead without simply making the reverb wetter; what is the smallest level-matched comparison?", ["reverb.foundations.reverb_perception_distance"], ["level.foundation.static_mix_first"]),
            ("The vocal needs the sense of nearby walls but not a long late tail; should I change early reflections before decay?", ["reverb.foundations.early_reflections_vs_tail"], ["delay.foundations.delay_depth"]),
            ("Can mixing make this weak or tentative vocal sound confident before I add ambience?", ["vocal.recording.performance_weak"], ["reverb.diagnosis_and_clarity.reverb_detached"]),
            ("The chorus gets crowded and the hook is harder to hear when the reverb return builds up. Should I first test the return or remove an arrangement layer?", ["arrangement.section.chorus_too_crowded"], ["reverb.diagnosis_and_clarity.boomy_reverb"]),
            ("As I lengthen one repeat, when does it stop fusing like artificial doubling and become a distinct rhythmic echo?", ["delay.foundations.echo_vs_double"], ["delay.stereo_phase_and_utility.haas_vocal_width"]),
            ("The delay feels late only while monitoring the live input. Is this repeat timing or compensation and monitoring?", ["delay.stereo_phase_and_utility.live_input_latency", "delay.logic_pro_specific.logic_pdc"], ["delay.rhythm_and_tempo.quarter_note_vocal"]),
            ("I creatively prefer an obviously unreal ghostly vocal reverb; what reversible experiment respects that preference without pretending it is documented technical necessity?", ["reverb.creative_and_sound_design.ghost_vocal"], ["eq.foundation.analyzer_use"]),
        ]
        var p4CrossDomainViolations: [String] = []
        for fixture in p4CrossDomainFixtures {
            try expect(!corpus.containsExactNormalizedUtterance(fixture.query), "P4 adversarial query became indexed")
            guard let ranked = corpus.rank(query: fixture.query) else { throw TestFailure(description: "adversarial query did not rank") }
            if (!fixture.expectedIDs.contains(ranked.card.id) || fixture.forbiddenIDs.contains(ranked.card.id)), p4CrossDomainViolations.count < 20 {
                p4CrossDomainViolations.append("\(fixture.query) -> \(ranked.card.id)")
            }
        }
        try expect(p4CrossDomainViolations.isEmpty,
                   "P4 cross-domain diagnosis drifted (first \(p4CrossDomainViolations.count)): \(p4CrossDomainViolations.joined(separator: " | "))")
        try expect(p2Scenarios.allSatisfy { ($0["turns"] as? [[String: Any]])?.count == 6 &&
                   !($0["required_behaviors"] as? [String] ?? []).isEmpty &&
                   !($0["forbidden_behaviors"] as? [String] ?? []).isEmpty },
                   "six-turn package-2 scenarios lost required behavior structure")
        try expect(p2Retrieval.allSatisfy { ($0["expected_canonical_ids"] as? [String])?.isEmpty == false &&
                   $0["forbidden_domain"] is String && $0["query"] is String && $0["review_status"] as? String == "synthetic_evaluation" },
                   "package-2 retrieval fixture structure/status drifted")
        // P2's supplied retrieval prompts are synthetic migration fixtures,
        // not independent semantic-retrieval evidence.  Their literal
        // query-to-card identity therefore belongs to this test-only resolver;
        // production exact lookup remains empty and package-filtered ranks are
        // diagnostic rather than a fixture-imposed top-1 contract.
        var p2FixtureResolver: [String: Set<String>] = [:]
        var p2FixtureRows: [(query: String, expectedID: String)] = []
        var p2DiagnosticFailures: [String] = []
        for fixture in p2Retrieval {
            guard let query = fixture["query"] as? String,
                  let expected = fixture["expected_canonical_ids"] as? [String], expected.count == 1,
                  let forbiddenDomain = fixture["forbidden_domain"] as? String,
                  let requiredTags = fixture["required_tags"] as? [String],
                  let expectedCard = corpus.card(expected[0]),
                  let ranked = corpus.rank(query: query, filters: .init(packageID: "community-level-balancing-eq-v1")) else { throw TestFailure(description: "retrieval fixture could not rank") }
            let key = normalizeFixture(query)
            p2FixtureResolver[key, default: []].insert(expected[0])
            p2FixtureRows.append((key, expected[0]))
            if ranked.card.packageID != "community-level-balancing-eq-v1" ||
                ranked.card.domain == forbiddenDomain ||
                ranked.card.originalReviewStatus != "candidate_not_yet_human_reviewed", p2DiagnosticFailures.count < 24 {
                p2DiagnosticFailures.append("\(fixture["id"] as? String ?? expected[0]) -> \(ranked.card.id)")
            }
            try expect(expectedCard.packageID == "community-level-balancing-eq-v1" &&
                       expectedCard.domain != forbiddenDomain &&
                       Set(requiredTags).isSubset(of: Set(expectedCard.tags)) &&
                       expectedCard.originalReviewStatus == "candidate_not_yet_human_reviewed",
                       "package-2 synthetic fixture/card linkage drifted for \(expected[0])")
        }
        let p2ProductionExactLeakage = p2Retrieval.filter { fixture in
            let query = fixture["query"] as? String ?? ""
            return corpus.containsExactNormalizedUtterance(query) ||
                !corpus.exactNormalizedCanonicalIDs(query).isEmpty
        }.count
        try expect(p2FixtureResolver.count == 714 && p2FixtureRows.count == 714 &&
                   p2FixtureRows.allSatisfy { p2FixtureResolver[$0.query] == Set([$0.expectedID]) } &&
                   p2FixtureResolver.values.allSatisfy { targets in
                       targets.count == 1 && targets.allSatisfy {
                           corpus.card($0)?.packageID == "community-level-balancing-eq-v1"
                       }
                   } && p2DiagnosticFailures.isEmpty &&
                   p2Retrieval.allSatisfy {
                       let query = $0["query"] as? String ?? ""
                       return !corpus.containsExactNormalizedUtterance(query) &&
                           corpus.exactNormalizedCanonicalIDs(query).isEmpty
                   },
                   "package-2 test-only exact resolver/production diagnostic boundary drifted: keys=\(p2FixtureResolver.count) rows=\(p2FixtureRows.count) diagnostics=\(p2DiagnosticFailures.count) productionExactLeakage=\(p2ProductionExactLeakage)")
        // Non-indexed P2 held-out package-family coverage. Cross-package
        // adversarial diagnosis fixtures above intentionally remain unfiltered.
        let heldOut: [(String, [String])] = [
            ("Why does the chorus leap louder than verse when the arrangement fills out?", ["level.foundation.section_balance"]),
            ("Why can I barely hear the lead vocal unless I turn it up too far today?", ["level.source.lead_vocal.buried", "level.source.backing_vocals.buried"]),
            ("Why does my full mix sound harsh, and what should I test tonight?", ["eq.source.full_mix.harsh"]),
        ]
        for (query, expectedIDs) in heldOut {
            try expect(!corpus.containsExactNormalizedUtterance(query), "held-out query was indexed after production normalization")
            let rankedID = corpus.rank(query: query, filters: .init(packageID: "community-level-balancing-eq-v1"))?.card.id ?? "none"
            try expect(expectedIDs.contains(rankedID), "held-out P2 lexical family drifted for \(expectedIDs): got \(rankedID)")
        }
        let canonicalIDs = Set(corpus.canonicalCards.map(\.id))
        try expect(corpus.utterances.allSatisfy { canonicalIDs.contains($0.canonicalID) },
                   "an utterance does not link to a canonical card")

        let executor = try TutorToolExecutor()
        let result = try await executor.execute(TutorToolCall(
            callID: "candidate-muddy", name: "search_candidate_corpus",
            argumentsJSON: #"{"query":"Why does my vocal sound muddy, and what should I test first?"}"#
        ), context: TutorRuntimeContext(sourceType: .vocal))
        try expect(result.evidence.map(\.kind) == [.candidateKnowledge], "candidate evidence was not distinct")
        let candidateOutput = try JSONSerialization.jsonObject(with: Data(result.outputJSON.utf8)) as? [String: Any]
        let returnedMatch = candidateOutput?["match"] as? [String: Any]
        try expect(returnedMatch != nil && result.evidence.first?.candidateCorpusProvenance?.resultSHA256?.count == 64,
                   "candidate provenance result hash does not bind the final payload")
        try expect(!result.outputJSON.contains(#""id":"vocal.tone.muddy""#), "candidate retrieval leaked internal record id")
        try expect(result.outputJSON.contains("soloed") && result.outputJSON.contains("full mix"),
                   "muddy sentinel did not ask the solo-versus-mix distinction")
        try expect(!result.outputJSON.contains("logic_pro_steps") && !result.outputJSON.contains("Audio FX"),
                   "candidate search leaked an exact procedure path")
        try expect(!result.outputJSON.lowercased().contains("audio track editor") &&
                   !result.outputJSON.lowercased().contains("region inspector") &&
                   !result.outputJSON.lowercased().contains("piano roll"),
                   "candidate search leaked a Logic navigation target")
        try expect(!result.outputJSON.contains("reviewed_claim") && !result.outputJSON.contains("reviewed_strategy"),
                   "candidate output was mislabeled as reviewed")

        guard let muddy = corpus.card("vocal.tone.muddy"),
              let space = corpus.card("vocal.space.delay_vs_reverb"),
              let quantization = corpus.card("quant.tempo.performance_or_grid_leads") else {
            throw TestFailure(description: "candidate sentinel cards missing")
        }
        try expect(muddy.clarificationQuestions.joined(separator: " ").lowercased().contains("soloed") &&
                   muddy.clarificationQuestions.joined(separator: " ").lowercased().contains("full mix"),
                   "muddy sentinel content lost the material clarification")
        try expect(p1Scenarios.contains(where: { scenario in
            scenario["canonical_id"] as? String == muddy.id && scenario["branch_kind"] as? String == "better_but_tradeoff"
        }), "clearer-but-thin sentinel no longer requires adapting the prior experiment")
        try expect(quantization.clarificationQuestions.joined(separator: " ").lowercased().contains("project follow the performance") &&
                   quantization.clarificationQuestions.joined(separator: " ").lowercased().contains("performance follow a fixed project tempo"),
                   "quantization sentinel no longer decides whether grid or performance leads")
        try expect(space.contradictions.contains(where: { $0.id == "contradiction.vocal.reverb_vs_delay" }),
                   "delay/reverb card lost its deliberate contradiction")
        try expect(quantization.contradictions.contains(where: { $0.id == "contradiction.quant.performance_vs_tempo" }),
                   "tempo-authority card lost its deliberate contradiction")
        try expect(muddy.contradictions.count <= 1, "unrelated muddy card received a contradiction pile")
        try expect(corpus.canonicalCards.allSatisfy { $0.contradictions.count <= 3 },
                   "candidate retrieval can return more than three contradictions")
        let topLevelContradictionIDs = Set(corpus.contradictions.map(\.id))
        let attachedContradictionIDs = Set(corpus.canonicalCards.flatMap(\.contradictions).map(\.id))
        try expect(attachedContradictionIDs == topLevelContradictionIDs,
                   "a top-level contradiction is unreachable from every canonical card")
        try expect(corpus.card("vocal.tone.sibilant")?.contradictions.contains(where: { $0.id == "contradiction.vocal.deess_manual" }) == true,
                   "de-esser/manual contradiction lost its curated sibilance anchor")
        try expect(corpus.card("vocal.recording.performance_weak")?.contradictions.contains(where: { $0.id == "contradiction.vocal.source_vs_fix" }) == true,
                   "source-versus-fix contradiction lost its curated performance anchor")
        try expect(corpus.card("quant.midi.q_strength")?.contradictions.contains(where: { $0.id == "contradiction.quant.full_vs_partial" }) == true,
                   "full-versus-partial contradiction lost its Q-Strength anchor")
        guard let p3Card = corpus.card("arrangement.foundation.activity_map") else { throw TestFailure(description: "package-3 sentinel missing") }
        try expect(p3Card.packageSequence == 3 && p3Card.tracksmithDomains?.isEmpty == false && p3Card.rawCommunityDisagreementIDs?.isEmpty == false,
                   "package-3 optional card metadata drifted")
        try expect((p3Card.rawCommunityDisagreementIDs ?? []).allSatisfy { topLevelContradictionIDs.contains($0) },
                   "package-3 raw disagreement is not reachable")
        try expect(corpus.rank(query: "vocal hidden by guitars", filters: .init(role: "focal"))?.card.roleFacets?.contains("focal") == true,
                   "exact role filter did not constrain candidate cards")
        try expect(corpus.rank(query: "vocal hidden by guitars", filters: .init(role: "unknown")) == nil,
                   "unknown structured role did not fail closed")
        let packageThreeResult = try await executor.execute(TutorToolCall(
            callID: "candidate-p3", name: "search_candidate_corpus",
            argumentsJSON: #"{"query":"my vocal disappears under guitars","domain":"frequency_allocation","role":"focal"}"#
        ), context: TutorRuntimeContext(sourceType: .vocal))
        try expect(packageThreeResult.evidence.first?.candidateCorpusProvenance?.packageSequence == 3,
                   "candidate evidence lost structured package-3 provenance")
    }

    private func testPackageTwoCandidateCorpus() async throws {
        let executor = try TutorToolExecutor()
        let levelResult = try await executor.execute(TutorToolCall(
            callID: "candidate-level", name: "search_candidate_corpus",
            argumentsJSON: #"{"query":"Should I set the fader balance before adding EQ and compression?","domain":"level_balancing"}"#
        ), context: TutorRuntimeContext(sourceType: .fullMix))
        try expect(!levelResult.outputJSON.contains(#""id":"level.foundation.static_mix_first""#) &&
                   levelResult.outputJSON.contains(#""retrieval_mode":"indexed_bm25_general_rerank_provisional""#),
                   "exact-normalized package-2 retrieval or retrieval-mode disclosure drifted")
        let eqResult = try await executor.execute(TutorToolCall(
            callID: "candidate-eq", name: "search_candidate_corpus",
            argumentsJSON: #"{"query":"my vocal is muddy","domain":"equalization"}"#
        ), context: TutorRuntimeContext(sourceType: .vocal))
        try expect(eqResult.outputJSON.contains(#""domain":"equalization""#), "structured domain filter drifted")
    }

    private func candidateEvaluationFixture(_ name: String) throws -> [String: Any] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw TestFailure(description: "missing evaluation-only fixture \(name)")
        }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
    }

    private func jsonString(_ value: [String: String]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func testStoreAndReceipts() async throws {
        let root = temporaryRoot("store")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TutorConversationStore(rootURL: root)
        var state = TutorConversationState(projectGoal: "Use sk-FAKECREDENTIAL12345 without storing it")
        state.messages = [TutorConversationMessage(
            role: .user,
            text: "authorization: fakeBearerCredential123"
        )]
        state.experiments = [TutorExperimentRecord(draft: experimentDraft(title: "Test"))]
        try store.save(state)
        let loaded = try store.load(conversationID: state.id)
        try expect(loaded.projectGoal?.contains("[REDACTED CREDENTIAL]") == true, "project credential was not redacted")
        try expect(loaded.messages.first?.text.contains("[REDACTED CREDENTIAL]") == true, "message credential was not redacted")

        state.messages = (0..<70).map { index in
            TutorConversationMessage(role: index.isMultiple(of: 2) ? .user : .assistant,
                                     text: "bounded-\(index)-" + String(repeating: "z", count: 23_000))
        }
        try store.save(state)
        let bounded = try store.load(conversationID: state.id)
        try expect(bounded.messages.count < state.messages.count, "oversized history was not evicted")
        try expect(bounded.messages.last?.text.hasPrefix("bounded-69-") == true, "newest history was not retained")

        let receipt = sampleReceipt(conversationID: state.id)
        try store.saveReceipt(receipt)
        let loadedReceipt = try store.loadReceipt(receipt.id)
        try expect(loadedReceipt == receipt, "receipt round-trip changed")
        guard let provenance=loadedReceipt.evidence.first?.candidateCorpusProvenance else { throw TestFailure(description: "receipt lost candidate corpus provenance") }
        let hex64={ (value: String?) in value.map { $0.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil } ?? false }
        try expect(provenance.packageID == "community-compression-arrangement-frequency-allocation-v1" &&
                   provenance.selectedDomain == "frequency_allocation" && provenance.sourceIDs?.isEmpty == false &&
                   provenance.reviewState == "candidate_not_yet_human_reviewed" && hex64(provenance.querySHA256) && hex64(provenance.resultSHA256) && provenance.selectedRecordIDs?.count == 2 && hex64(provenance.retrievalID) && provenance.corpusVersion == "p1-p15-selected-6212" && provenance.policyVersion == "p16-policy-1" && provenance.omissions?.count == 5,
                   "receipt lost populated candidate corpus provenance")
        let legacyEvidence = try JSONDecoder().decode(TutorEvidenceReference.self, from: Data(#"{"id":"00000000-0000-0000-0000-000000000001","kind":"candidateKnowledge","label":"legacy","detail":"legacy"}"#.utf8))
        try expect(legacyEvidence.candidateCorpusProvenance == nil, "legacy evidence did not decode without corpus provenance")
        let legacyProvenance = try JSONDecoder().decode(TutorEvidenceReference.self, from: Data(#"{"id":"00000000-0000-0000-0000-000000000002","kind":"candidateKnowledge","label":"legacy","detail":"legacy","candidateCorpusProvenance":{"packageID":"legacy-package","packageVersion":"1.0.0","packageSequence":1,"recordID":"legacy-card"}}"#.utf8))
        try expect(legacyProvenance.candidateCorpusProvenance?.querySHA256 == nil && legacyProvenance.candidateCorpusProvenance?.selectedRecordIDs == nil && legacyProvenance.candidateCorpusProvenance?.retrievalID == nil && legacyProvenance.candidateCorpusProvenance?.corpusVersion == nil && legacyProvenance.candidateCorpusProvenance?.policyVersion == nil && legacyProvenance.candidateCorpusProvenance?.omissions == nil, "legacy corpus provenance did not decode without optional receipt fields")
        let permissions = try FileManager.default.attributesOfItem(atPath: store.receiptsURL
            .appendingPathComponent(receipt.id.uuidString.lowercased())
            .appendingPathExtension("json").path)[.posixPermissions] as? NSNumber
        try expect(permissions?.intValue == 0o600, "receipt permissions are not owner-only")
        do {
            try store.saveReceipt(receipt)
            throw TestFailure(description: "receipt overwrite unexpectedly succeeded")
        } catch let error as TutorConversationStoreError {
            try expect(error == .receiptAlreadyExists, "duplicate receipt did not fail as write-once")
        }
    }

    private func testAudioListening() async throws {
        let wavData = Data("RIFF-test-bounded-audio".utf8)
        let capture = sampleCapture(wavData: wavData)
        let credential = InMemoryProviderCredentialStore(values: [.openAI: "test-key-not-secret"])
        let transport = RecordingHTTPTransport(response: ProviderHTTPResponse(
            statusCode: 200,
            body: Data(#"{"model":"gpt-audio-test","choices":[{"message":{"content":"I hear a bounded low-mid buildup, but its cause is uncertain."}}]}"#.utf8)
        ))

        let denied = OpenAITutorAudioListener(
            configuration: TutorAudioListeningConfiguration(cloudAudioConsent: false),
            credentialStore: credential,
            transport: transport
        )
        do {
            _ = try await denied.listen(wavData: wavData, capture: capture, musicianQuestion: "Muddy?")
            throw TestFailure(description: "audio upload ran without consent")
        } catch let error as TutorConversationError {
            try expect(error == .audioConsentRequired, "audio consent failure was not typed")
        }
        try expect(transport.requestCount == 0, "transport ran before audio consent")

        var stale = capture
        stale.isLive = false
        let listener = OpenAITutorAudioListener(
            configuration: TutorAudioListeningConfiguration(
                modelIdentifier: "gpt-audio-test",
                cloudAudioConsent: true,
                maximumAudioBytes: 1_024
            ),
            credentialStore: credential,
            transport: transport
        )
        do {
            _ = try await listener.listen(wavData: wavData, capture: stale, musicianQuestion: "Muddy?")
            throw TestFailure(description: "stale capture was uploaded")
        } catch let error as TutorConversationError {
            try expect(error == .staleCapture, "stale capture failure was not typed")
        }
        do {
            _ = try await listener.listen(wavData: Data("wrong hash".utf8), capture: capture, musicianQuestion: "Muddy?")
            throw TestFailure(description: "hash-mismatched capture was uploaded")
        } catch let error as TutorConversationError {
            try expect(error == .staleCapture, "hash mismatch did not fail closed")
        }

        let listened = try await listener.listen(wavData: wavData, capture: capture, musicianQuestion: "Muddy?")
        try expect(listened.status == .listened, "successful audio observation not labeled Heard")
        try expect(listened.modelIdentifier == "gpt-audio-test", "valid audio response model was not retained")
        try expect(listened.captureSnapshotID == capture.captureSnapshotID, "audio observation lost capture identity")
        try expect(transport.requestCount == 1, "unexpected audio request count")
        guard let request = transport.latestRequest,
              let body = try JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            throw TestFailure(description: "audio request missing")
        }
        try expect(body["store"] as? Bool == false, "audio provider storage was not disabled")
        let bodyText = String(decoding: request.body, as: UTF8.self)
        try expect(bodyText.contains("input_audio"), "audio modality missing")
        try expect(!bodyText.contains("/Users/"), "local path leaked into audio request")

        for invalidResponse in [
            #"{"choices":[{"message":{"content":"bounded observation"}}]}"#,
            #"{"model":"gpt-audio-other","choices":[{"message":{"content":"bounded observation"}}]}"#,
        ] {
            let invalidTransport = RecordingHTTPTransport(response: ProviderHTTPResponse(statusCode: 200, body: Data(invalidResponse.utf8)))
            let invalidListener = OpenAITutorAudioListener(
                configuration: TutorAudioListeningConfiguration(modelIdentifier: "gpt-audio-test", cloudAudioConsent: true, maximumAudioBytes: 1_024),
                credentialStore: credential,
                transport: invalidTransport
            )
            do {
                _ = try await invalidListener.listen(wavData: wavData, capture: capture, musicianQuestion: "Muddy?")
                throw TestFailure(description: "missing or mismatched audio response model produced a listened receipt")
            } catch let error as TutorConversationError {
                guard case .malformedProviderResponse = error else {
                    throw TestFailure(description: "audio response model drift did not use the bounded malformed-response boundary")
                }
            }
            try expect(invalidTransport.requestCount == 1, "audio model guard did not exercise the completed mock response")
        }
    }

    private func testStatefulVerticalSlice() async throws {
        let root = temporaryRoot("stateful")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TutorConversationStore(rootURL: root)
        let tools = try TutorToolExecutor(
            observeLogic: { query in
                TutorLogicObservation(
                    status: .observed,
                    applicationName: "Logic Pro",
                    controls: [TutorObservedControl(role: "AXButton", label: query, value: "off")],
                    limitation: "Read-only test observation."
                )
            },
            priorExperiments: { (try? store.loadMostRecent()?.experiments) ?? [] }
        )
        let provider = StatefulScriptedProvider()
        let engine = TutorConversationEngine(
            store: store,
            tools: tools,
            fallbackProvider: try OfflineTutorProvider()
        )
        let context = TutorRuntimeContext(
            sourceType: .vocal,
            projectGoal: "Keep the vocal natural in the full mix",
            capture: sampleCapture(wavData: Data("local-capture".utf8)),
            consent: TutorConsentContext(cloudTextGranted: true)
        )

        let first = try await collectTurn(engine, "My vocal sounds muddy.", context, provider)
        try expect(first.contains(where: { if case .toolActivity("search_production_knowledge") = $0 { true } else { false } }),
                   "first turn did not retrieve reviewed knowledge")
        let second = try await collectTurn(engine, "It is muddy in the full mix, not in solo.", context, provider)
        try expect(second.contains(where: { if case .experiment = $0 { true } else { false } }),
                   "second turn did not present an experiment")
        var snapshot = await engine.snapshot()
        guard let experiment = snapshot.experiments.last else {
            throw TestFailure(description: "experiment did not persist")
        }
        _ = try await engine.recordOutcome(
            experimentID: experiment.id,
            outcome: .worse,
            note: "Clearer, but now it sounds thin"
        )
        let third = try await collectTurn(engine, "It is clearer but thin now. Why did that happen?", context, provider)
        try expect(third.contains(where: { if case .toolActivity("retrieve_prior_experiments") = $0 { true } else { false } }),
                   "third turn did not retrieve the explicit outcome")
        _ = try await collectTurn(engine, "I listened again. Adapt the next move without repeating that cut.", context, provider)

        snapshot = await engine.snapshot()
        try expect(snapshot.messages.count == 8, "four real dialogue turns were not persisted")
        try expect(snapshot.messages[0].text.contains("muddy"), "first turn was lost")
        try expect(snapshot.messages[4].text.contains("thin"), "follow-up turn was lost")
        try expect(snapshot.messages[7].text.contains("won't repeat"), "final answer did not adapt")
        try expect(snapshot.experiments.last?.outcome == .worse, "experiment outcome was not persisted")
        try expect(snapshot.experiments.last?.userNote == "Clearer, but now it sounds thin", "outcome note was not persisted")

        let requests = provider.requestsSnapshot()
        guard let thinRequest = requests.last(where: {
            $0.messages.last(where: { $0.role == .user })?.text.contains("thin now") == true
        }) else { throw TestFailure(description: "thin follow-up request missing") }
        try expect(thinRequest.messages.contains(where: { $0.text.contains("muddy in the full mix") }),
                   "provider did not receive earlier conversational state")
        let receiptFiles = try FileManager.default.contentsOfDirectory(
            at: store.receiptsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        try expect(receiptFiles.count == 4, "one immutable evidence receipt per turn was not written")
        let latestReceiptID = UUID(uuidString: receiptFiles.last!.deletingPathExtension().lastPathComponent)!
        let receipt = try store.loadReceipt(latestReceiptID)
        try expect(receipt.consents.contains(where: {
            $0.modality == .cloudConversationText && $0.granted
        }), "cloud-text consent receipt missing")
    }

    private func testAudioIntelligenceTruth() async throws {
        let bytes = Data("not-a-wav-but-exact".utf8)
        let capture = sampleCapture(wavData: bytes)
        let local = await LocalWaveformSpecialist().analyze(wavData: bytes, capture: capture)
        try expect(!local.receivedOriginalWaveformBytes, "undecodable bytes were mislabeled as a validated capture waveform")
        try expect(local.providerIdentifier.contains("local-waveform"), "local specialist identity missing")
        try expect(local.capabilities.allSatisfy(\.calibrated), "local lab capability calibration was not declared")
        try expect(local.failure != nil, "malformed WAV did not fail soft")
        try expect(local.limitations.joined().contains("did not hear"), "local measurement was mislabeled as listening")
        try expect(local.waveformBindingStatus == .bytesReceivedUndecodable, "undecodable bytes were labeled capture-bound")
        var mismatchCapture = capture
        mismatchCapture.sha256 = sha256(Data("different bytes".utf8))
        let mismatch = await LocalWaveformSpecialist().analyze(wavData: bytes, capture: mismatchCapture)
        try expect(mismatch.waveformBindingStatus == .bytesReceivedHashMismatch, "hash mismatch was not typed")
        try expect(!mismatch.receivedOriginalWaveformBytes, "hash mismatch was mislabeled as a validated capture waveform")
        try expect(!mismatch.sourceProvenance.lowercased().contains("hash-validated"), "hash mismatch claimed validated provenance")
    }

    private func testLocalProviderExactWAV() async throws {
        let bytes = validMonoWAV()
        let capture = sampleCapture(wavData: bytes)
        let result = await LocalWaveformSpecialist().analyze(wavData: bytes, capture: capture)
        try expect(result.waveformBindingStatus == .captureBoundExactWAV, "valid exact WAV was not capture-bound")
        try expect(result.failure == nil && !result.observations.isEmpty, "provider emitted no local measurements for valid WAV")
        try expect(result.observations.allSatisfy { $0.evidence == .localMeasurement }, "provider observation claimed non-local evidence")
    }

    private func testLiveLikeLocalEvidenceTurn() async throws {
        let bytes = validMonoWAV(sampleRate: 44_100, frameCount: 157_696)
        var capture = sampleCapture(wavData: bytes)
        capture.formatDescription = "44100 Hz mono Float32 WAV"
        capture.durationSeconds = Double(157_696) / 44_100
        capture.audioIntelligence = await LocalWaveformSpecialist().analyze(wavData: bytes, capture: capture)
        guard let intelligence = capture.audioIntelligence else { throw TestFailure(description: "local provider did not return a result") }
        try expect(intelligence.waveformBindingStatus == .captureBoundExactWAV, "live-like WAV was not bound")
        try expect(intelligence.observations.allSatisfy { $0.value?.isFinite ?? true }, "local observation contains a non-finite value")

        let executor = try TutorToolExecutor()
        let context = TutorRuntimeContext(sourceType: .vocal, capture: capture)
        let output = try await executor.execute(TutorToolCall(
            callID: "live-like-capture", name: "get_current_capture_context", argumentsJSON: "{}"
        ), context: context)
        let toolObject = try JSONSerialization.jsonObject(with: Data(output.outputJSON.utf8))
        try expect(toolObject is [String: Any], "local tool context was not JSON-encodable")

        let transport = RecordingStreamingTransport(lines: [
            #"data: {"type":"response.completed","response":{"id":"resp_live","model":"test","output":[{"type":"message","content":[{"type":"output_text","text":"Bounded response."}]}]}}"#,
            "",
        ])
        let provider = OpenAITutorProvider(
            configuration: TutorProviderConfiguration(modelIdentifier: "gpt-test", cloudTextConsent: true),
            credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "test-key-not-secret"]),
            transport: transport
        )
        for try await _ in provider.stream(TutorProviderRequest(
            messages: [TutorConversationMessage(role: .user, text: "Use this bounded local evidence.")],
            context: context, tools: TutorToolExecutor.defaultDefinitions
        )) {}
        guard let request = transport.latestRequest() else { throw TestFailure(description: "provider did not receive live-like context") }
        let body = String(decoding: request.body, as: UTF8.self)
        _ = try JSONSerialization.jsonObject(with: request.body)
        try expect(!body.contains(":NaN") && !body.contains(":Infinity") && !body.contains(":-Infinity"), "provider context serialized a non-finite numeric token")
    }

    private func testAttachedCaptureDoubleFailure() async throws {
        let root = temporaryRoot("attached-double-failure")
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = validMonoWAV(sampleRate: 44_100, frameCount: 157_696)
        var capture = sampleCapture(wavData: bytes)
        capture.audioIntelligence = await LocalWaveformSpecialist().analyze(wavData: bytes, capture: capture)
        let engine = TutorConversationEngine(
            store: TutorConversationStore(rootURL: root),
            tools: try TutorToolExecutor(),
            fallbackProvider: FailingConversationProvider(error: .malformedProviderResponse("test fallback failure"))
        )
        let stream = try await engine.streamTurn(
            text: "Use the attached capture as bounded local evidence.",
            context: TutorRuntimeContext(sourceType: .vocal, capture: capture),
            provider: FailingConversationProvider(error: .malformedProviderResponse("test primary failure"))
        )
        do { for try await _ in stream {} } catch { }
        let state = await engine.snapshot()
        try expect(state.messages.last?.status == .failed, "double failure did not retain an assistant status")
        try expect(state.messages.last?.text.contains("No Logic or Audio Unit state changed") == true, "double failure status overclaimed or disappeared")
    }

    private func testAttachedGenericOfflineFallback() async throws {
        let bytes = validMonoWAV(sampleRate: 44_100, frameCount: 157_696)
        var capture = sampleCapture(wavData: bytes)
        capture.audioIntelligence = await LocalWaveformSpecialist().analyze(wavData: bytes, capture: capture)
        let provider = OfflineTutorProvider(
            coordinator: try GeneralTutorCoordinator(),
            forceGenericFallback: true
        )
        let prompt = "Use the attached capture as bounded local evidence. What is the clearest tonal issue, and what is one reversible Logic test?"
        let request = TutorProviderRequest(
            messages: [TutorConversationMessage(role: .user, text: prompt)],
            context: TutorRuntimeContext(sourceType: .vocal, capture: capture),
            tools: TutorToolExecutor.defaultDefinitions
        )
        var text = ""
        var completed = false
        for try await event in provider.stream(request) {
            switch event {
            case let .textDelta(delta): text += delta
            case .completed: completed = true
            }
        }
        try expect(completed, "generic offline fallback did not complete")
        try expect(text.contains("descriptive local measurements"), "fallback did not disclose the measurement boundary")
        try expect(text.contains("Channel EQ") && text.contains("Toggle bypass"), "fallback did not provide a reversible next action")
        try expect(!text.localizedCaseInsensitiveContains("i hear") && !text.localizedCaseInsensitiveContains("I listened"), "fallback fabricated listening")
    }

    private func testComparisonAuthority() async throws {
        let baseline = sampleCapture(wavData: Data("baseline".utf8))
        let authority = TutorComparisonAuthority(baseline: baseline)
        var hashOnly = baseline
        hashOnly.sha256 = sha256(Data("different".utf8))
        hashOnly.captureSnapshotID = UUID()
        let rejected = TutorComparisonAuthorityValidator.validate(
            authority: authority, followUp: hashOnly, userConfirmedUpstreamAndObservable: true
        )
        try expect(!rejected.available && rejected.reason.contains("distinct later"), "hash-only comparison was accepted")
        var acceptedCapture = baseline
        acceptedCapture.captureSnapshotID = UUID()
        acceptedCapture.sha256 = sha256(Data("later".utf8))
        acceptedCapture.capturedAt = baseline.capturedAt.addingTimeInterval(1)
        let accepted = TutorComparisonAuthorityValidator.validate(
            authority: authority, followUp: acceptedCapture, userConfirmedUpstreamAndObservable: true
        )
        try expect(accepted.available, "guarded same-authority follow-up was rejected")
        try expect(accepted.measurementDeltas?.first?.identifier == "vocal_200_500_hz_energy_ratio", "accepted comparison omitted bounded metric delta")
        let noConfirmation = TutorComparisonAuthorityValidator.validate(
            authority: authority, followUp: acceptedCapture, userConfirmedUpstreamAndObservable: false
        )
        try expect(!noConfirmation.available && noConfirmation.reason.contains("did not confirm"), "missing signal-path confirmation was accepted")
    }

    private func testPendingExperimentConfirmationIsolation() async throws {
        let root = temporaryRoot("confirmation-isolation")
        defer { try? FileManager.default.removeItem(at: root) }
        let baseline = sampleCapture(wavData: Data("baseline-confirmation".utf8))
        let first = TutorExperimentRecord(
            draft: experimentDraft(title: "First pending experiment"),
            comparisonAuthority: TutorComparisonAuthority(baseline: baseline)
        )
        let second = TutorExperimentRecord(
            draft: experimentDraft(title: "Second pending experiment"),
            comparisonAuthority: TutorComparisonAuthority(baseline: baseline)
        )
        let engine = TutorConversationEngine(
            state: TutorConversationState(experiments: [first, second]),
            store: TutorConversationStore(rootURL: root),
            tools: try TutorToolExecutor(),
            fallbackProvider: try OfflineTutorProvider()
        )
        var followUp = baseline
        followUp.captureSnapshotID = UUID()
        followUp.sha256 = sha256(Data("later-confirmation".utf8))
        followUp.capturedAt = baseline.capturedAt.addingTimeInterval(1)

        // This models confirmation captured atomically from the first card.
        _ = try await engine.recordOutcome(
            experimentID: first.id, outcome: .better, followUpCapture: followUp,
            userConfirmedUpstreamAndObservable: true
        )
        // The second card receives no confirmation, even though the first did.
        _ = try await engine.recordOutcome(
            experimentID: second.id, outcome: .notSure, followUpCapture: followUp,
            userConfirmedUpstreamAndObservable: false
        )
        let records = (await engine.snapshot()).experiments
        try expect(records.first(where: { $0.id == first.id })?.waveformComparison?.available == true,
                   "selected experiment did not retain its own authorized comparison")
        let secondComparison = records.first(where: { $0.id == second.id })?.waveformComparison
        try expect(secondComparison?.available == false && secondComparison?.reason.contains("did not confirm") == true,
                   "confirmation leaked from one pending experiment to another")

        let third = TutorExperimentRecord(
            draft: experimentDraft(title: "Capture failure outcome"),
            comparisonAuthority: TutorComparisonAuthority(baseline: baseline)
        )
        let failureEngine = TutorConversationEngine(
            state: TutorConversationState(experiments: [third]),
            store: TutorConversationStore(rootURL: temporaryRoot("capture-failure")),
            tools: try TutorToolExecutor(), fallbackProvider: try OfflineTutorProvider()
        )
        let persisted = try await failureEngine.recordOutcome(
            experimentID: third.id, outcome: .noChange, followUpCapture: nil,
            userConfirmedUpstreamAndObservable: true
        )
        try expect(persisted.outcome == .noChange && persisted.waveformComparison?.available == false,
                   "missing follow-up capture did not preserve the user-only outcome as comparison unavailable")
    }

    private func testLegacyExperimentDecoding() async throws {
        let record = TutorExperimentRecord(draft: experimentDraft(title: "Old record"), outcome: .notSure)
        let data = try JSONEncoder().encode(record)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "comparisonAuthority")
        object.removeValue(forKey: "waveformComparison")
        let legacy = try JSONDecoder().decode(TutorExperimentRecord.self, from: JSONSerialization.data(withJSONObject: object))
        try expect(legacy.comparisonAuthority == nil && legacy.waveformComparison == nil, "older record did not decode additively")
        try expect(legacy.outcome == .notSure, "Not sure outcome was not retained")
    }

    private func testResponseQualityVerticalSlice() async throws {
        let root = temporaryRoot("response-quality")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TutorConversationStore(rootURL: root)
        let engine = TutorConversationEngine(store: store, tools: try TutorToolExecutor(), fallbackProvider: try OfflineTutorProvider())
        let provider = StatefulScriptedProvider()
        let context = TutorRuntimeContext(sourceType: .vocal, capture: sampleCapture(wavData: Data("quality".utf8)))
        _ = try await collectTurn(engine, "My vocal sounds muddy.", context, provider)
        _ = try await collectTurn(engine, "It is muddy in the full mix, not in solo.", context, provider)
        guard let experiment = (await engine.snapshot()).experiments.last else { throw TestFailure(description: "quality fixture lacks experiment") }
        _ = try await engine.recordOutcome(experimentID: experiment.id, outcome: .notSure, note: "Clearer, but now thin")
        _ = try await collectTurn(engine, "Why did that happen? It is clearer but thin now.", context, provider)
        let state = await engine.snapshot()
        try expect(state.experiments.last?.outcome == .notSure, "natural uncertainty outcome was not retained")
        try expect(state.messages.last?.text.lowercased().contains("thin") == true, "follow-up was generic instead of using clearer-but-thin continuity")
        try expect(!state.messages.last!.text.lowercased().contains("i heard"), "response fabricated model listening")
    }

    private func testAutomaticOfflineFallback() async throws {
        let root = temporaryRoot("fallback")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TutorConversationStore(rootURL: root)
        let engine = TutorConversationEngine(
            store: store,
            tools: try TutorToolExecutor(),
            fallbackProvider: try OfflineTutorProvider()
        )
        let events = try await collectTurn(
            engine,
            "My vocal sounds muddy. What is one safe thing to check?",
            TutorRuntimeContext(sourceType: .vocal),
            FailingConversationProvider(error: TutorConversationError.consentRequired)
        )
        try expect(events.contains(where: { if case .fallbackActivated = $0 { true } else { false } }),
                   "fallback was not announced")
        let state = await engine.snapshot()
        try expect(state.messages.count == 2, "fallback turn did not persist")
        try expect(state.messages.last?.text.contains("Offline fallback") == true,
                   "fallback did not disclose its grounding boundary")
        try expect(state.messages.last?.text.contains("250–400 Hz") == true,
                   "muddy request did not receive the issue-aware low-mid test")
        try expect(state.messages.last?.text.contains("kick and bass") != true,
                   "muddy request fell through to an unrelated lesson")
        try expect(state.experiments.count == 1,
                   "offline fallback did not persist its reversible experiment")
        guard let completedReceipt = events.compactMap({ event -> TutorEvidenceReceipt? in
            if case let .completed(_, receipt) = event { return receipt }
            return nil
        }).last else {
            throw TestFailure(description: "fallback receipt missing")
        }
        try expect(completedReceipt.fallbackReason?.contains("Cloud conversation consent is off") == true,
                   "bounded primary failure reason was not retained")
        try expect(completedReceipt.tools.contains(where: { $0.name == "present_experiment" }),
                   "offline experiment tool receipt missing")
    }

    private func testPackageSeventeenExperienceContract() async throws {
        try expect(TutorExperienceLevel.allCases.map(\.rawValue) == ["noob", "amateur", "pro"],
                   "experience raw IDs changed")
        try expect(TutorExperienceLevel.allCases.map(\.label) == ["Noob", "Amateur", "Pro"],
                   "experience labels changed")
        try expect(TutorExperienceLevel.default == .amateur, "Amateur is not the default")
        let legacy = try JSONDecoder().decode(TutorExperienceSettings.self, from: Data("{}".utf8))
        try expect(legacy.persistentLevel == .amateur, "missing preference did not migrate to Amateur")
        let current = try JSONDecoder().decode(TutorExperienceSettings.self, from: Data(#"{"version":1,"persistentLevel":"pro"}"#.utf8))
        try expect(current.version == 1 && current.persistentLevel == .pro, "current P17 preference did not decode")
        try expect((try? JSONDecoder().decode(TutorExperienceSettings.self, from: Data("not-json".utf8))) == nil,
                   "corrupt P17 preference did not fail closed")
        try expect((try? JSONDecoder().decode(TutorExperienceSettings.self, from: Data(#"{"version":2,"persistentLevel":"pro"}"#.utf8))) == nil,
                   "future P17 preference version did not fail closed")
        try expect(TutorExperienceContext.explicitTemporaryOverride(for: "Please explain more simply") == .noob,
                   "explicit simple directive was not recognized")
        try expect(TutorExperienceContext.explicitTemporaryOverride(for: "Skip basics and go deeper") == .pro,
                   "explicit pro directive was not recognized")
        for nonDirective in ["This is a noob question", "basic question", "my audio is professional", "I use simple words"] {
            try expect(TutorExperienceContext.explicitTemporaryOverride(for: nonDirective) == nil,
                       "level was inferred from non-directive text")
        }
        for negatedOrQuotedDirective in [
            "don't skip basics",
            "do not give exact clicks",
            "I did not ask for beginner mode",
            "the phrase \"skip basics\" is not my request",
        ] {
            try expect(TutorExperienceContext.explicitTemporaryOverride(for: negatedOrQuotedDirective) == nil,
                       "negated or quoted directive changed the temporary level")
        }
        try expect(TutorExperienceContext.explicitTemporaryOverride(for: "Don't overexplain; skip basics") == .pro,
                   "a later positive directive was incorrectly negated by a preceding clause")
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsSource = try String(contentsOf: root.appendingPathComponent("apps/CompanionMacApp/SettingsView.swift"), encoding: .utf8)
        let headerSource = try String(contentsOf: root.appendingPathComponent("apps/CompanionMacApp/TutorConversationView.swift"), encoding: .utf8)
        let sessionSource = try String(contentsOf: root.appendingPathComponent("apps/CompanionMacApp/CompanionSessionModel.swift"), encoding: .utf8)
        try expect(settingsSource.contains(".onChange(of: model.tutorExperienceSettings)"), "settings picker has no persistence hook")
        try expect(headerSource.contains("set: { session.setTutorExperienceLevel($0) }"), "header picker does not save explicitly")
        try expect(sessionSource.contains("func setTutorExperienceLevel") && sessionSource.contains("persistTutorSettings()"), "header selection does not persist immediately")
        try expect(!headerSource.contains("state.messages =") && !sessionSource.contains("state.messages ="), "level control rewrites transcript state")
        let receiptRoot = temporaryRoot("p17-receipt")
        defer { try? FileManager.default.removeItem(at: receiptRoot) }
        let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: receiptRoot), tools: try TutorToolExecutor(), fallbackProvider: try OfflineTutorProvider())
        let context = TutorRuntimeContext(sourceType: .vocal, experience: .init(persistentLevel: .amateur, temporaryOverride: .pro))
        let events = try await collectTurn(engine, "My vocal is muddy", context, FailingConversationProvider(error: .consentRequired))
        guard let receipt = events.compactMap({ if case let .completed(_, receipt) = $0 { receipt } else { nil } }).last else {
            throw TestFailure(description: "P17 completed receipt missing")
        }
        try expect(receipt.experience == context.experience, "receipt did not retain persistent/temporary/effective level")
        try expect(receipt.evidence.allSatisfy { $0.kind != .inference || $0.detail.isEmpty == false },
                   "experience metadata was misclassified as evidence")
    }

    private func testPackageSeventeenProviderIsolation() async throws {
        let lines = [
            "event: response.completed",
            #"data: {"type":"response.completed","response":{"id":"p17","model":"gpt-test","output":[{"type":"message","content":[{"type":"output_text","text":"ok"}]}]}}"#,
            "event: done",
            "data: [DONE]",
        ]
        let transport = RecordingStreamingTransport(lines: lines)
        let provider = OpenAITutorProvider(
            configuration: .init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, cloudTextConsent: true),
            credentialStore: InMemoryProviderCredentialStore(values: [.openAI: "test-key-not-secret"]),
            transport: transport
        )
        let context = TutorRuntimeContext(sourceType: .vocal, experience: .init(persistentLevel: .noob, temporaryOverride: .pro))
        for try await _ in provider.stream(.init(messages: [.init(role: .user, text: "go deeper")], context: context, tools: [])) {}
        guard let body = transport.latestRequest()?.body else { throw TestFailure(description: "P17 request was not recorded") }
        let text = String(decoding: body, as: UTF8.self)
        guard let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let input = payload["input"] as? [[String: Any]],
              let contextText = input.first(where: { ($0["content"] as? String)?.contains("CURRENT_CONTEXT_DATA") == true })?["content"] as? String else {
            throw TestFailure(description: "P17 context envelope was not encoded")
        }
        try expect(contextText.contains("\"persistentLevel\":\"noob\"") && contextText.contains("\"effectiveLevel\":\"pro\""),
                   "compact level context was not sent")
        try expect(payload["service_tier"] as? String == "priority", "gpt-5.6-sol request omitted its explicit priority service tier")
        for forbidden in ["pkg017", "golden", "expected_answer", "corpus.sqlite", "canonical_qa"] {
            try expect(!text.lowercased().contains(forbidden), "evaluation data leaked into provider request: \(forbidden)")
        }
        try expect(OpenAITutorProvider.systemInstructions.contains("effective_level changes only terminology"),
                   "provider lacks level-invariant instruction")
        try expect(OpenAITutorProvider.systemInstructions.contains("Ask at most one concise decision-changing question")
                       && OpenAITutorProvider.systemInstructions.contains("Ask questions alone only when no safe experiment exists")
                       && OpenAITutorProvider.systemInstructions.contains("effective_level must not change the diagnosis, clarification, experiment")
                       && OpenAITutorProvider.systemInstructions.contains("every level includes that same one bounded, reversible discriminating experiment"),
                   "provider lacks the clarification-plus-safe-experiment contract")
        let pinnedConfiguration = TutorProviderConfiguration(modelIdentifier: Self.packageSeventeenTextModel, reasoningEffort: .high, cloudTextConsent: true)
        try expect(Self.packageSeventeenCloudConfigurationIsPinned(pinnedConfiguration)
                       && !Self.packageSeventeenCloudConfigurationIsPinned(.init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .medium, cloudTextConsent: true))
                       && !Self.packageSeventeenCloudConfigurationIsPinned(.init(modelIdentifier: "gpt-other", reasoningEffort: .high, cloudTextConsent: true))
                       && !Self.packageSeventeenCloudConfigurationIsPinned(.init(modelIdentifier: "gpt-5.6-sol", reasoningEffort: .high, serviceTier: .fast, cloudTextConsent: true)),
                   "P17 cloud model, effort, or service-tier pin did not fail closed")
        try expect(Self.packageSeventeenCloudMetadataIsPinned(.init(providerIdentifier: "mock", modelIdentifier: "gpt-5.6-sol", serviceTier: .priority))
                       && !Self.packageSeventeenCloudMetadataIsPinned(.init(providerIdentifier: "mock", modelIdentifier: "gpt-other", serviceTier: .priority))
                       && !Self.packageSeventeenCloudMetadataIsPinned(.init(providerIdentifier: "mock", modelIdentifier: "gpt-5.6-sol", serviceTier: .fast)),
                   "P17 cloud returned-metadata pin did not fail closed")
        let expectedFixture = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/TrackSmith/P16/fixtures/generated/p16-controlled-source.wav")
        try expect(Self.packageSeventeenPublicAudioFixtureIsPinned(path: expectedFixture, sha256: Self.packageSeventeenPublicAudioFixtureSHA256)
                       && !Self.packageSeventeenPublicAudioFixtureIsPinned(path: expectedFixture, sha256: String(repeating: "0", count: 64))
                       && !Self.packageSeventeenPublicAudioFixtureIsPinned(path: URL(fileURLWithPath: "/tmp/Library/Caches/TrackSmith/P16/fixtures/generated/p16-controlled-source.wav"), sha256: Self.packageSeventeenPublicAudioFixtureSHA256),
                   "P17 exact public-audio fixture guard did not fail closed")
        let healthFailure = Self.packageSeventeenCloudHealthFailureArtifact(model: "gpt-5.6-sol", effort: .high, safeError: "safe", durationMilliseconds: 1)
        try expect(healthFailure["requestedModelIdentifier"] as? String == "gpt-5.6-sol"
                       && healthFailure["requestedReasoningEffort"] as? String == "high"
                       && healthFailure["requestedServiceTier"] as? String == "priority"
                       && healthFailure["store"] as? Bool == false
                       && healthFailure["toolsSent"] as? Int == 0,
                   "P17 cloud health failure artifact omitted request configuration metadata")
        let multibyteJudge = String(repeating: "🙂", count: 193)
        let boundedJudge = Self.boundedEvaluationText(multibyteJudge, maximumUTF8Bytes: 768)
        try expect(boundedJudge.utf8.count == 768 && boundedJudge.count == 192,
                   "P17 judge text cap did not use UTF-8 bytes")
        let boundedReason = Self.boundedJudgeReason("PASS:" + String(repeating: "é", count: 193))
        try expect(boundedReason.utf8.count == 384 && boundedReason.count == 192,
                   "P17 judge reason cap did not use UTF-8 bytes")

        let probe = PackageSeventeenCloudConcurrencyProbe()
        _ = await Self.boundedPackageSeventeenTopicMap(Array(0..<7)) { value in
            await probe.begin()
            try? await Task.sleep(for: .milliseconds(15))
            await probe.end()
            return value
        }
        let peak = await probe.maximum()
        try expect(Self.packageSeventeenCloudMaximumTopicConcurrency == 3 && peak <= 3,
                   "P17 cloud harness exceeded its three-topic concurrency cap")
        let prompts = [
            PackageSeventeenCloudPrompt(order: 0, topic: "first", query: "first query"),
            PackageSeventeenCloudPrompt(order: 1, topic: "second", query: "second query"),
        ]
        let completed = PackageSeventeenCloudRequestOutcome(text: "safe response", metadata: .init(providerIdentifier: "mock", modelIdentifier: "mock"), attempts: 1, terminalStatus: "completed", safeFailure: nil)
        let reverseCompletion = [
            PackageSeventeenCloudTopicResult(prompt: prompts[1], responses: Self.packageSeventeenLevelOrder.reversed().map { .init(prompt: prompts[1], level: $0, outcome: completed) }),
            PackageSeventeenCloudTopicResult(prompt: prompts[0], responses: Self.packageSeventeenLevelOrder.reversed().map { .init(prompt: prompts[0], level: $0, outcome: completed) }),
        ]
        let ordered = Self.orderedPackageSeventeenCloudResponses(reverseCompletion, prompts: prompts)
        try expect(ordered.map { "\($0.prompt.topic):\($0.level.rawValue)" } == ["first:noob", "first:amateur", "first:pro", "second:noob", "second:amateur", "second:pro"],
                   "P17 cloud artifacts are not deterministically topic/level ordered")
        let failed = PackageSeventeenCloudRequestOutcome(text: nil, metadata: nil, attempts: 2, terminalStatus: "failed", safeFailure: "The provider returned HTTP 429.")
        let failureArtifact = Self.packageSeventeenCloudResponseArtifacts([.init(prompt: prompts[0], level: .noob, outcome: failed)]).first
        try expect(failureArtifact?["terminalStatus"] as? String == "failed" && failureArtifact?["attempts"] as? Int == 2 && failureArtifact?["safeFailure"] as? String == "The provider returned HTTP 429.",
                   "P17 cloud failure artifact lost terminal status or attempts")
        try expect(Self.isTransientCloudEvaluationFailure(TutorConversationError.providerRejected("Provider HTTP 429"))
                       && !Self.isTransientCloudEvaluationFailure(TutorConversationError.malformedProviderResponse("invalid")),
                   "P17 cloud retry policy is not bounded to explicit transient failures")
        let reference = PackageSeventeenSemanticReference(problemSummary: "evaluation-only problem", recommendedFirstExperiment: "evaluation-only experiment", evidenceRequirements: "evaluation-only evidence", riskAndUndo: "evaluation-only rollback")
        let judgeRequest = Self.packageSeventeenJudgeRequest(prompt: prompts[0], triplet: Self.packageSeventeenLevelOrder.map { .init(prompt: prompts[0], level: $0, outcome: completed) }, reference: reference)
        try expect(!prompts[0].query.contains("evaluation-only problem") && judgeRequest.contains("evaluation-only problem") && judgeRequest.contains("supplied after generation"),
                   "P17 generation/judge semantic-reference boundary drifted")
    }

    private func testPackageSeventeenOfflineLevelsAndPerformance() async throws {
        var rendered: [TutorExperienceLevel: String] = [:]
        for level in TutorExperienceLevel.allCases {
            let root = temporaryRoot("p17-offline-\(level.rawValue)")
            defer { try? FileManager.default.removeItem(at: root) }
            let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: root), tools: try TutorToolExecutor(), fallbackProvider: try OfflineTutorProvider())
            let started = Date()
            let events = try await collectTurn(
                engine, "My vocal is muddy", .init(sourceType: .vocal, experience: .init(persistentLevel: level)),
                FailingConversationProvider(error: .consentRequired)
            )
            let elapsed = Date().timeIntervalSince(started)
            try expect(elapsed < 0.5, "offline first-turn path exceeded 500 ms for \(level.rawValue): \(elapsed)")
            guard let message = (await engine.snapshot()).messages.last else { throw TestFailure(description: "P17 offline message missing") }
            rendered[level] = message.text
            for invariant in ["One controlled test:", "Listen for:", "Watch for:", "Undo:"] {
                try expect(message.text.contains(invariant), "\(level.rawValue) lost invariant \(invariant)")
            }
            try expect(events.contains(where: { if case .completed = $0 { true } else { false } }), "P17 offline turn did not complete")
        }
        try expect(rendered[.noob] != rendered[.amateur] && rendered[.pro] != rendered[.amateur],
                   "levels did not change offline scaffolding")
        try expect(rendered[.noob]?.contains("Plain-language path") == true, "Noob scaffolding is missing")
        try expect(rendered[.pro]?.contains("Fast pass") == true, "Pro scaffolding is missing")
    }

    private func testPackageSeventeenLiveCase144() async throws {
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let canonicalURL = repository.appendingPathComponent("research/tutor_quality/packages/tracksmith-corpus-017-golden-tutor-conversations-level-adaptation/corpus/canonical_qa.jsonl")
        guard let raw = try String(contentsOf: canonicalURL, encoding: .utf8).split(separator: "\n").first(where: { $0.contains("pkg017.qa.000144") }),
              let row = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
              let query = row["canonical_question"] as? String else {
            throw TestFailure(description: "P17 case 144 fixture missing")
        }
        let offline = try OfflineTutorProvider()
        for level in [TutorExperienceLevel.noob, .amateur, .pro] {
            let root = temporaryRoot("p17-case-144-\(level.rawValue)")
            defer { try? FileManager.default.removeItem(at: root) }
            let engine = TutorConversationEngine(store: TutorConversationStore(rootURL: root), tools: try TutorToolExecutor(), fallbackProvider: offline)
            let events = try await collectTurn(engine, query, .init(sourceType: .vocal, experience: .init(persistentLevel: level)), FailingConversationProvider(error: .consentRequired))
            guard let receipt = events.compactMap({ if case let .completed(_, value) = $0 { value } else { nil } }).last,
                  let message = (await engine.snapshot()).messages.last else {
                throw TestFailure(description: "P17 case 144 receipt missing")
            }
            let text = message.text
            let authority = text.lowercased().contains("no authority to change")
            let stop = text.lowercased().contains("stop")
            let rollback = text.lowercased().contains("undo") || text.lowercased().contains("restore")
            print("P17_CASE144 level=\(level.rawValue) tools=\(receipt.tools.map(\.name).sorted()) evidence=\(receipt.evidence.map(\.kind.rawValue).sorted()) authority=\(authority) stop=\(stop) rollback=\(rollback)")
            print("P17_CASE144_TEXT_BEGIN \(level.rawValue)\n\(text)\nP17_CASE144_TEXT_END \(level.rawValue)")
            try expect(text.lowercased().contains("no authority to change"), "case 144 has no explicit authority boundary")
            try expect(text.lowercased().contains("stop"), "case 144 has no stop boundary")
            try expect(text.lowercased().contains("undo") || text.lowercased().contains("restore"), "case 144 has no rollback boundary")
        }
    }

    private func testPackageSeventeenCloudEvaluation() async throws {
        guard CommandLine.arguments.contains("--cloud-text-consent") else {
            throw TestFailure(description: "package17-cloud-evaluation requires --cloud-text-consent; no request was sent")
        }
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let prompts = try packageSeventeenAcceptancePrompts(repository: repository)
        let model = UserDefaults.standard.string(forKey: "TrackSmithTutorModelIdentifier") ?? "gpt-5.6-sol"
        let effort = TutorReasoningEffort(rawValue: UserDefaults.standard.string(forKey: "TrackSmithTutorReasoningEffort") ?? "high") ?? .high
        let configuration = TutorProviderConfiguration(modelIdentifier: model, reasoningEffort: effort, cloudTextConsent: true)
        try expect(Self.packageSeventeenCloudConfigurationIsPinned(configuration), "P17 cloud evaluation requires gpt-5.6-sol, high effort, and priority service tier")
        let provider = OpenAITutorProvider(configuration: configuration)
        let topicResults = await Self.boundedPackageSeventeenTopicMap(prompts) { prompt in
            await Self.generatePackageSeventeenCloudTopic(provider: provider, prompt: prompt)
        }
        let orderedResponses = Self.orderedPackageSeventeenCloudResponses(topicResults, prompts: prompts)
        let responses = Self.packageSeventeenCloudResponseArtifacts(orderedResponses)
        let artifact: [String: Any] = [
            "schemaVersion": "1.1", "evaluator": ["id": "TutorConversationTests.cloud", "version": "1.1"],
            "consent": "explicit --cloud-text-consent", "fallback": false, "expectedTextProvidedToGeneration": false,
            "requestedModelIdentifier": model, "requestedReasoningEffort": effort.rawValue, "requestedServiceTier": "priority",
            "generationReferenceBoundary": "Generation received only the query, compact runtime context, and no tools; Package 017 semantic references were not read or sent until after each completed triplet.",
            "concurrency": ["maximumTopicTasks": Self.packageSeventeenCloudMaximumTopicConcurrency, "tripletLevelsSequential": true, "levelOrder": Self.packageSeventeenLevelOrder.map(\.rawValue)],
            "counts": ["prompts": 12, "levels": 3, "responses": responses.count, "judgments": 12],
            "responses": responses,
        ]
        try writePackageSeventeenArtifact(artifact, named: "package17-cloud-evaluation.json", repository: repository)
        try expect(orderedResponses.allSatisfy(Self.packageSeventeenCloudResponseIsPinned),
                   "P17 cloud evaluation received missing or drifted model/service-tier metadata")
        // Only after generation is complete do supporting judgments load the
        // evaluation-only semantic reference for that topic. It is never sent
        // to generation or runtime Tutor requests.
        let judgments = await Self.cloudTripletJudgments(provider: provider, prompts: prompts, topicResults: topicResults, repository: repository)
        try writePackageSeventeenArtifact(judgments, named: "package17-cloud-triplet-judgments.json", repository: repository)
        print("P17_CLOUD_EVALUATION_OK prompts=12 responses=36 judgments=12 fallback=false store=false")
    }

    private func testPackageSeventeenCloudHealth() async throws {
        guard CommandLine.arguments.contains("--cloud-text-consent") else {
            throw TestFailure(description: "package17-cloud-health requires --cloud-text-consent; no request was sent")
        }
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let model = UserDefaults.standard.string(forKey: "TrackSmithTutorModelIdentifier") ?? "gpt-5.6-sol"
        let effort = TutorReasoningEffort(rawValue: UserDefaults.standard.string(forKey: "TrackSmithTutorReasoningEffort") ?? "high") ?? .high
        let configuration = TutorProviderConfiguration(modelIdentifier: model, reasoningEffort: effort, cloudTextConsent: true)
        let started = Date()
        do {
            try expect(Self.packageSeventeenCloudConfigurationIsPinned(configuration), "P17 cloud health requires gpt-5.6-sol, high effort, and priority service tier")
            let provider = OpenAITutorProvider(configuration: configuration)
            let generated = try await Self.cloudText(
                provider: provider,
                query: "Give one evidence-honest, reversible next step for a vocal that feels muddy in a full mix.",
                context: .init(sourceType: .vocal, experience: .init(persistentLevel: .amateur))
            )
            try expect(Self.packageSeventeenCloudMetadataIsPinned(generated.metadata), "P17 cloud health received missing or drifted model/service-tier metadata")
            try writePackageSeventeenArtifact([
                "schemaVersion": "1.0", "status": "completed", "providerIdentifier": generated.metadata.providerIdentifier,
                "modelIdentifier": generated.metadata.modelIdentifier, "providerResponseID": generated.metadata.providerResponseID ?? NSNull(),
                "serviceTier": generated.metadata.serviceTier?.rawValue ?? NSNull(),
                "requestedModelIdentifier": model, "requestedReasoningEffort": effort.rawValue, "requestedServiceTier": "priority",
                "assistantTextSHA256": Self.sha256String(generated.text), "toolsSent": 0, "store": false,
                "durationMilliseconds": Int(Date().timeIntervalSince(started) * 1_000),
            ], named: "package17-cloud-health.json", repository: repository)
            print("P17_CLOUD_HEALTH_OK status=completed store=false tools=0")
        } catch {
            let safe = (error as? TutorConversationError)?.safeFailureDescription ?? "Cloud health request failed safely."
            try writePackageSeventeenArtifact(Self.packageSeventeenCloudHealthFailureArtifact(
                model: model,
                effort: effort,
                safeError: safe,
                durationMilliseconds: Int(Date().timeIntervalSince(started) * 1_000)
            ), named: "package17-cloud-health.json", repository: repository)
            throw error
        }
    }

    private func testPackageSeventeenPublicAudioEvaluation() async throws {
        guard CommandLine.arguments.contains("--cloud-audio-consent") else {
            throw TestFailure(description: "package17-public-audio-evaluation requires --cloud-audio-consent; no request was sent")
        }
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let fixture = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/TrackSmith/P16/fixtures/generated/p16-controlled-source.wav")
        let wav = try Data(contentsOf: fixture)
        try expect(!wav.isEmpty && wav.count <= 12 * 1_024 * 1_024, "public P16 fixture is absent or exceeds audio cap")
        let digest = Self.sha256String(wav)
        try expect(Self.packageSeventeenPublicAudioFixtureIsPinned(path: fixture, sha256: digest), "P17 public-audio evaluation requires the exact approved P16 fixture SHA-256")
        let capture = TutorCaptureSnapshot(sourceType: .fullMix, instanceID: UUID(), runtimeEpoch: UUID(), captureSnapshotID: UUID(), sha256: digest, capturedAt: Date(), durationSeconds: 2, scopeDescription: "P16 controlled public fixture", isLive: true, metrics: [], localAnalysisLimitations: ["Evaluation fixture; no project or mix claim."])
        let model = UserDefaults.standard.string(forKey: "TrackSmithTutorAudioModelIdentifier") ?? "gpt-audio-1.5"
        try expect(model == Self.packageSeventeenAudioModel, "P17 public-audio evaluation requires gpt-audio-1.5")
        let listener = OpenAITutorAudioListener(configuration: .init(modelIdentifier: model, cloudAudioConsent: true, maximumAudioBytes: 12 * 1_024 * 1_024))
        let started = Date()
        let evidence = try await listener.listen(wavData: wav, capture: capture, musicianQuestion: "Describe only audible characteristics and uncertainty in this bounded public fixture.")
        try expect(evidence.modelIdentifier == Self.packageSeventeenAudioModel, "P17 public-audio evaluation received a drifted audio model")
        let artifact: [String: Any] = [
            "schemaVersion": "1.0", "consent": "explicit --cloud-audio-consent", "fixture": "P16 controlled public WAV",
            "wavSHA256": digest, "wavBytes": wav.count, "providerIdentifier": evidence.providerIdentifier as Any,
            "modelIdentifier": evidence.modelIdentifier as Any, "waveformBinding": "captureBoundExactWAV",
            "heard": evidence.status == .listened, "status": evidence.status.rawValue, "exactHash": true,
            "durationMilliseconds": Int(Date().timeIntervalSince(started) * 1_000),
        ]
        try writePackageSeventeenArtifact(artifact, named: "package17-public-audio-evaluation.json", repository: repository)
        print("P17_PUBLIC_AUDIO_EVALUATION_OK heard=\(evidence.status == .listened) exactHash=true")
    }

    private func packageSeventeenAcceptancePrompts(repository: URL) throws -> [PackageSeventeenCloudPrompt] {
        let path = repository.appendingPathComponent("research/tutor_quality/packages/tracksmith-corpus-017-golden-tutor-conversations-level-adaptation/corpus/canonical_qa.jsonl")
        let required: Set<String> = ["vocal_masking", "eq_tradeoff", "compression_sibilance", "layering_redundancy", "automation_owner", "flex_artifact", "duplicate_monitoring", "sidechain_trigger", "midi_groove", "bounce_tail", "cannot_find", "uncertain_evidence"]
        var values: [(String, String)] = []
        for line in try String(contentsOf: path, encoding: .utf8).split(separator: "\n") {
            guard let row = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let topic = row["topic"] as? String, required.contains(topic), row["variant_kind"] as? String == "initial",
                  let query = row["canonical_question"] as? String else { continue }
            values.append((topic, query))
        }
        guard values.count == 12, Set(values.map(\.0)).count == 12 else { throw TestFailure(description: "P17 cloud acceptance prompt map drift") }
        return values.sorted { $0.0 < $1.0 }.enumerated().map {
            PackageSeventeenCloudPrompt(order: $0.offset, topic: $0.element.0, query: $0.element.1)
        }
    }

    /// Generation reads this prompt-only artifact, never canonical_qa.jsonl.
    /// Reference answers remain behind the completed-triplet semantic firewall.
    private func packageNineteenCloudPrompts(repository: URL) throws -> [PackageSeventeenCloudPrompt] {
        let relative = "research/tutor_quality/package019_cloud_prompt_suite.json"
        let data = try Data(contentsOf: repository.appendingPathComponent(relative))
        guard sha256(data) == Self.packageNineteenCloudPromptSuiteSHA256,
              let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], rows.count == 12 else {
            throw TestFailure(description: "P19 prompt-only cloud suite hash/count drifted")
        }
        let prompts = try rows.enumerated().map { index, row -> PackageSeventeenCloudPrompt in
            guard let topic = row["topic"] as? String, let query = row["canonical_question"] as? String,
                  !topic.isEmpty, !query.isEmpty else {
                throw TestFailure(description: "P19 prompt-only cloud suite row malformed")
            }
            return .init(order: index, topic: topic, query: query)
        }
        let ordered = prompts.map { "\($0.order)|\($0.topic)|\($0.query)\n" }.joined()
        guard sha256(Data(ordered.utf8)) == Self.packageNineteenOrderedCloudPromptSHA256,
              Set(prompts.map(\.topic)).count == 12 else {
            throw TestFailure(description: "P19 prompt-only ordered cloud suite drifted")
        }
        return prompts
    }

    private nonisolated static func cloudText(provider: OpenAITutorProvider, query: String, context: TutorRuntimeContext) async throws -> (text: String, metadata: TutorProviderMetadata) {
        var text = ""; var completed: TutorProviderMetadata?
        for try await event in provider.stream(.init(messages: [.init(role: .user, text: query)], context: context, tools: [])) {
            switch event { case let .textDelta(delta): text += delta; case let .completed(metadata, output): completed = metadata; if text.isEmpty { text = output.compactMap { if case let .text(value) = $0 { value } else { nil } }.joined() } }
        }
        guard let completed, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TutorConversationError.malformedProviderResponse("Cloud evaluator completed without text.") }
        return (text, completed)
    }

    private nonisolated static func packageSeventeenCloudConfigurationIsPinned(_ configuration: TutorProviderConfiguration) -> Bool {
        configuration.modelIdentifier == packageSeventeenTextModel
            && configuration.reasoningEffort == .high
            && configuration.serviceTier == .priority
    }

    private nonisolated static func packageSeventeenCloudMetadataIsPinned(_ metadata: TutorProviderMetadata) -> Bool {
        metadata.modelIdentifier == packageSeventeenTextModel && metadata.serviceTier == .priority
    }

    private nonisolated static func packageSeventeenCloudResponseIsPinned(_ response: PackageSeventeenCloudResponse) -> Bool {
        response.outcome.terminalStatus == "completed"
            && response.outcome.metadata.map(packageSeventeenCloudMetadataIsPinned) == true
    }

    private nonisolated static func packageSeventeenCloudHealthFailureArtifact(
        model: String,
        effort: TutorReasoningEffort,
        safeError: String,
        durationMilliseconds: Int
    ) -> [String: Any] {
        [
            "schemaVersion": "1.0",
            "status": "failed",
            "safeError": safeError,
            "requestedModelIdentifier": model,
            "requestedReasoningEffort": effort.rawValue,
            "requestedServiceTier": "priority",
            "store": false,
            "toolsSent": 0,
            "durationMilliseconds": durationMilliseconds,
        ]
    }

    private nonisolated static func packageSeventeenPublicAudioFixtureIsPinned(path: URL, sha256: String) -> Bool {
        path.standardizedFileURL == FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(String(packageSeventeenPublicAudioFixturePathSuffix.dropFirst()))
            .standardizedFileURL
            && sha256 == packageSeventeenPublicAudioFixtureSHA256
    }

    private nonisolated static func boundedPackageSeventeenTopicMap<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        operation: @escaping @Sendable (Input) async -> Output
    ) async -> [Output] {
        await withTaskGroup(of: Output.self, returning: [Output].self) { group in
            var nextIndex = 0
            while nextIndex < min(inputs.count, packageSeventeenCloudMaximumTopicConcurrency) {
                let input = inputs[nextIndex]
                nextIndex += 1
                group.addTask { await operation(input) }
            }
            var outputs: [Output] = []
            while let output = await group.next() {
                outputs.append(output)
                if nextIndex < inputs.count {
                    let input = inputs[nextIndex]
                    nextIndex += 1
                    group.addTask { await operation(input) }
                }
            }
            return outputs
        }
    }

    private nonisolated static func generatePackageSeventeenCloudTopic(
        provider: OpenAITutorProvider,
        prompt: PackageSeventeenCloudPrompt
    ) async -> PackageSeventeenCloudTopicResult {
        var responses: [PackageSeventeenCloudResponse] = []
        // Keep each topic's triplet logically grouped and sequential. The only
        // generation inputs are its query and compact selected level context.
        for level in packageSeventeenLevelOrder {
            let context = TutorRuntimeContext(sourceType: .vocal, experience: .init(persistentLevel: level))
            let outcome = await cloudTextWithBoundedRetry(provider: provider, query: prompt.query, context: context)
            responses.append(PackageSeventeenCloudResponse(prompt: prompt, level: level, outcome: outcome))
        }
        return PackageSeventeenCloudTopicResult(prompt: prompt, responses: responses)
    }

    private nonisolated static func cloudTextWithBoundedRetry(
        provider: OpenAITutorProvider,
        query: String,
        context: TutorRuntimeContext
    ) async -> PackageSeventeenCloudRequestOutcome {
        for attempt in 1...packageSeventeenCloudMaximumAttempts {
            do {
                let generated = try await cloudText(provider: provider, query: query, context: context)
                // A completed request is never retried or duplicated.
                return PackageSeventeenCloudRequestOutcome(text: generated.text, metadata: generated.metadata, attempts: attempt, terminalStatus: "completed", safeFailure: nil)
            } catch {
                let transient = isTransientCloudEvaluationFailure(error)
                if transient, attempt < packageSeventeenCloudMaximumAttempts {
                    try? await Task.sleep(for: .milliseconds(250))
                    continue
                }
                let safe = (error as? TutorConversationError)?.safeFailureDescription ?? "The cloud evaluator request failed safely."
                return PackageSeventeenCloudRequestOutcome(text: nil, metadata: nil, attempts: attempt, terminalStatus: "failed", safeFailure: safe)
            }
        }
        return PackageSeventeenCloudRequestOutcome(text: nil, metadata: nil, attempts: packageSeventeenCloudMaximumAttempts, terminalStatus: "failed", safeFailure: "The cloud evaluator request failed safely.")
    }

    private nonisolated static func isTransientCloudEvaluationFailure(_ error: Error) -> Bool {
        if case .timedOut = error as? TutorConversationError { return true }
        guard case let .providerRejected(detail) = error as? TutorConversationError else { return false }
        let lowercased = detail.lowercased()
        return lowercased.contains("rate") || ["408", "409", "429", "500", "502", "503", "504"].contains { lowercased.contains($0) }
    }

    private nonisolated static func orderedPackageSeventeenCloudResponses(
        _ topicResults: [PackageSeventeenCloudTopicResult],
        prompts: [PackageSeventeenCloudPrompt]
    ) -> [PackageSeventeenCloudResponse] {
        let levelIndex = Dictionary(uniqueKeysWithValues: packageSeventeenLevelOrder.enumerated().map { ($0.element, $0.offset) })
        let byTopic = Dictionary(uniqueKeysWithValues: topicResults.map { ($0.prompt.topic, $0) })
        return prompts.flatMap { prompt in
            (byTopic[prompt.topic]?.responses ?? []).sorted {
                (levelIndex[$0.level] ?? Int.max) < (levelIndex[$1.level] ?? Int.max)
            }
        }
    }

    private nonisolated static func packageSeventeenCloudResponseArtifacts(_ responses: [PackageSeventeenCloudResponse]) -> [[String: Any]] {
        let triplets = Dictionary(grouping: responses, by: { $0.prompt.topic })
        return responses.map { response in
            let text = response.outcome.text
            let metadata = response.outcome.metadata
            let allThreeCompleted = (triplets[response.prompt.topic] ?? []).count == 3
                && (triplets[response.prompt.topic] ?? []).allSatisfy { $0.outcome.terminalStatus == "completed" && $0.outcome.text != nil }
            let distinct = allThreeCompleted
                ? Set((triplets[response.prompt.topic] ?? []).compactMap { $0.outcome.text }.map(sha256String)).count == 3
                : nil
            return [
                "topic": response.prompt.topic,
                "topicOrder": response.prompt.order,
                "effectiveLevel": response.level.rawValue,
                "querySHA256": sha256String(response.prompt.query),
                "assistantTextSHA256": text.map(sha256String) ?? NSNull(),
                "assistantText": text ?? NSNull(),
                "providerIdentifier": metadata?.providerIdentifier ?? NSNull(),
                "modelIdentifier": metadata?.modelIdentifier ?? NSNull(),
                "providerResponseID": metadata?.providerResponseID ?? NSNull(),
                "serviceTier": metadata?.serviceTier?.rawValue ?? NSNull(),
                "toolsSent": 0,
                "store": false,
                "attempts": response.outcome.attempts,
                "terminalStatus": response.outcome.terminalStatus,
                "safeFailure": response.outcome.safeFailure ?? NSNull(),
                "expectedTextProvidedToGeneration": false,
                "noAuthorityExpansion": text.map { hasNoAuthorityExpansion($0, toolsSent: 0) } ?? NSNull(),
                "stopRollback": text.map { $0.lowercased().contains("stop") && ($0.lowercased().contains("undo") || $0.lowercased().contains("restore")) } ?? NSNull(),
                "scaffoldingDiffers": distinct ?? NSNull(),
            ]
        }
    }

    private static func cloudTripletJudgments(
        provider: OpenAITutorProvider,
        prompts: [PackageSeventeenCloudPrompt],
        topicResults: [PackageSeventeenCloudTopicResult],
        repository: URL
    ) async -> [String: Any] {
        let byTopic = Dictionary(uniqueKeysWithValues: topicResults.map { ($0.prompt.topic, $0) })
        let results = await boundedPackageSeventeenTopicMap(prompts) { prompt in
            let triplet = orderedPackageSeventeenCloudResponses(byTopic[prompt.topic].map { [$0] } ?? [], prompts: [prompt])
            guard triplet.count == 3, triplet.allSatisfy({ $0.outcome.terminalStatus == "completed" && $0.outcome.text != nil }) else {
                return packageSeventeenSkippedJudgment(prompt: prompt)
            }
            do {
                // This read happens only after the entire triplet has completed.
                let reference = try packageSeventeenSemanticReference(repository: repository, topic: prompt.topic)
                let request = packageSeventeenJudgeRequest(prompt: prompt, triplet: triplet, reference: reference)
                let outcome = await cloudTextWithBoundedRetry(provider: provider, query: request, context: .init(sourceType: .vocal))
                return packageSeventeenJudgmentResult(prompt: prompt, outcome: outcome, semanticReferenceProvided: true)
            } catch {
                let safe = (error as? TutorConversationError)?.safeFailureDescription ?? "The evaluation-only semantic reference was unavailable."
                return packageSeventeenFailedJudgment(prompt: prompt, safeFailure: safe)
            }
        }
        let orderedArtifacts = results.sorted { $0.prompt.order < $1.prompt.order }.map(packageSeventeenJudgmentArtifact)
        return [
            "schemaVersion": "1.1",
            "judge": "same opt-in OpenAI provider; model-assisted supporting evidence only",
            "criteria": "generated text compared post-generation with evaluation-only semantic reference fields",
            "semanticReferenceBoundary": "Reference fields were read only after each three-level generation triplet completed; they were never sent to generation or runtime Tutor requests.",
            "concurrency": ["maximumTopicTasks": packageSeventeenCloudMaximumTopicConcurrency, "tripletJudgmentsGrouped": true],
            "results": orderedArtifacts,
        ]
    }

    private nonisolated static func packageSeventeenSemanticReference(
        repository: URL,
        topic: String
    ) throws -> PackageSeventeenSemanticReference {
        let path = repository.appendingPathComponent("research/tutor_quality/packages/tracksmith-corpus-017-golden-tutor-conversations-level-adaptation/corpus/canonical_qa.jsonl")
        let rows = try String(contentsOf: path, encoding: .utf8).split(separator: "\n")
        guard let raw = rows.first(where: { line in
            guard let row = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return false }
            return row["topic"] as? String == topic && row["variant_kind"] as? String == "initial"
        }),
        let row = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
        let problem = row["problem_summary"] as? String,
        let experiment = row["recommended_first_experiment"] as? String,
        let evidence = row["evidence_needed"],
        let guidance = row["logic_guidance"] as? [String: Any],
        let risk = guidance["risk"] as? String,
        let undo = guidance["undo"] as? String else {
            throw TutorConversationError.malformedProviderResponse("Package 17 semantic reference shape was unavailable.")
        }
        return PackageSeventeenSemanticReference(
            problemSummary: problem,
            recommendedFirstExperiment: experiment,
            evidenceRequirements: packageSeventeenJSONText(evidence),
            riskAndUndo: "Risk: \(risk) Undo: \(undo)"
        )
    }

    private nonisolated static func packageSeventeenJSONText(_ value: Any) -> String {
        if let string = value as? String { return string }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return "Unavailable"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private nonisolated static func packageSeventeenJudgeRequest(
        prompt: PackageSeventeenCloudPrompt,
        triplet: [PackageSeventeenCloudResponse],
        reference: PackageSeventeenSemanticReference
    ) -> String {
        let rendered = triplet.compactMap { response -> String? in
            guard let text = response.outcome.text else { return nil }
            return "[\(response.level.rawValue)] \(text)"
        }.joined(separator: "\n\n")
        return """
        Judge these three completed Tutor responses for the same query. Return only PASS or REVIEW plus one short visible reason; do not reveal hidden reasoning or reproduce the reference.

        Criteria: they should preserve the same diagnosis/problem framing, one reversible first experiment, evidence honesty, safety/read-only authority, and stop+rollback while varying only appropriate scaffolding. Noob must be respectful, Amateur useful, and Pro concise but not cryptic.

        Query: \(prompt.query)

        Evaluation-only semantic reference, supplied after generation: problem summary=\(reference.problemSummary); recommended first experiment=\(reference.recommendedFirstExperiment); evidence requirements=\(reference.evidenceRequirements); \(reference.riskAndUndo)

        Generated responses:\n\(rendered)
        """
    }

    private nonisolated static func packageSeventeenSkippedJudgment(prompt: PackageSeventeenCloudPrompt) -> PackageSeventeenCloudJudgment {
        PackageSeventeenCloudJudgment(
            prompt: prompt,
            outcome: nil,
            terminalStatus: "skipped_incomplete_generation",
            safeFailure: "One or more generated responses were unavailable; no semantic reference was read or sent to a judge.",
            semanticReferenceProvided: false
        )
    }

    private nonisolated static func packageSeventeenFailedJudgment(prompt: PackageSeventeenCloudPrompt, safeFailure: String) -> PackageSeventeenCloudJudgment {
        PackageSeventeenCloudJudgment(
            prompt: prompt,
            outcome: nil,
            terminalStatus: "failed",
            safeFailure: safeFailure,
            semanticReferenceProvided: false
        )
    }

    private nonisolated static func packageSeventeenJudgmentResult(
        prompt: PackageSeventeenCloudPrompt,
        outcome: PackageSeventeenCloudRequestOutcome,
        semanticReferenceProvided: Bool
    ) -> PackageSeventeenCloudJudgment {
        PackageSeventeenCloudJudgment(
            prompt: prompt,
            outcome: outcome,
            terminalStatus: outcome.terminalStatus,
            safeFailure: outcome.safeFailure,
            semanticReferenceProvided: semanticReferenceProvided
        )
    }

    private nonisolated static func packageSeventeenJudgmentArtifact(_ result: PackageSeventeenCloudJudgment) -> [String: Any] {
        let outcome = result.outcome
        let boundedJudgment = outcome?.text.map { boundedEvaluationText($0, maximumUTF8Bytes: 768) }
        let verdict = boundedJudgment?.uppercased().hasPrefix("PASS") == true ? "PASS" : "REVIEW"
        return [
            "topic": result.prompt.topic,
            "topicOrder": result.prompt.order,
            "judgeProvider": outcome?.metadata?.providerIdentifier ?? NSNull(),
            "judgeModel": outcome?.metadata?.modelIdentifier ?? NSNull(),
            "judgeResponseID": outcome?.metadata?.providerResponseID ?? NSNull(),
            "judgeServiceTier": outcome?.metadata?.serviceTier?.rawValue ?? NSNull(),
            "judgmentSHA256": outcome?.text.map(sha256String) ?? NSNull(),
            "judgmentText": boundedJudgment ?? NSNull(),
            "judgmentReason": boundedJudgment.map(boundedJudgeReason) ?? NSNull(),
            "verdict": verdict,
            "terminalStatus": result.terminalStatus,
            "attempts": outcome?.attempts ?? 0,
            "safeFailure": result.safeFailure ?? NSNull(),
            "semanticReferenceProvidedToJudge": result.semanticReferenceProvided,
            "semanticReferenceReadAfterGeneration": result.semanticReferenceProvided,
            "goldenTextProvidedToGeneration": false,
            "hiddenReasoningStored": false,
        ]
    }

    private func writePackageSeventeenArtifact(_ value: [String: Any], named: String, repository: URL) throws {
        let path = repository.appendingPathComponent("research/tutor_quality/evaluations/\(named)")
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: path, options: .atomic)
    }

    /// This is deliberately a claim-boundary check, not a demand for a
    /// repetitive literal authority disclaimer in natural Tutor language.
    private nonisolated static func hasNoAuthorityExpansion(_ text: String, toolsSent: Int) -> Bool {
        guard toolsSent == 0 else { return false }
        let normalized = text.lowercased()
        let performedClaims = [
            "i performed", "i changed", "i heard", "i observed",
            "tracksmith performed", "tracksmith changed", "tracksmith heard", "tracksmith observed",
            "we performed", "we changed", "we heard", "we observed",
        ]
        return !performedClaims.contains { normalized.contains($0) }
    }

    /// Evaluation artifacts may retain a short visible verdict/reason but
    /// never model chain-of-thought or an unbounded judge response.
    private nonisolated static func boundedEvaluationText(_ text: String, maximumUTF8Bytes: Int) -> String {
        let visible = String(text.unicodeScalars.filter { $0.value >= 32 || $0.value == 9 || $0.value == 10 })
        var result = ""
        var usedUTF8Bytes = 0
        for scalar in visible.unicodeScalars {
            let candidate = usedUTF8Bytes + scalar.utf8.count
            guard candidate <= maximumUTF8Bytes else { break }
            result.unicodeScalars.append(scalar)
            usedUTF8Bytes = candidate
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func boundedJudgeReason(_ judgment: String) -> String {
        let collapsed = judgment.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
        let separator = collapsed.firstIndex(of: ":") ?? collapsed.firstIndex(of: "-")
        let reason = separator.map { String(collapsed[collapsed.index(after: $0)...]) } ?? collapsed
        return boundedEvaluationText(reason, maximumUTF8Bytes: 384)
    }

    private func testPackageSeventeenLiveOfflineEvaluation() async throws {
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let canonicalURL = repository.appendingPathComponent(
            "research/tutor_quality/packages/tracksmith-corpus-017-golden-tutor-conversations-level-adaptation/corpus/canonical_qa.jsonl"
        )
        let rawRows = try String(contentsOf: canonicalURL, encoding: .utf8)
            .split(separator: "\n").map { Data($0.utf8) }
        try expect(rawRows.count == 180, "P17 live evaluator requires exactly 180 canonical rows")
        let levels: [TutorExperienceLevel] = [.noob, .amateur, .pro]
        let requiredTopics: Set<String> = [
            "vocal_masking", "eq_tradeoff", "compression_sibilance", "layering_redundancy",
            "automation_owner", "flex_artifact", "duplicate_monitoring", "sidechain_trigger",
            "midi_groove", "bounce_tail", "cannot_find", "uncertain_evidence",
        ]
        var records: [[String: Any]] = []
        var acceptance: [String: Set<TutorExperienceLevel>] = [:]
        var semanticReferenceUnavailable = 0
        var tripletInvariantFailures: [String] = []
        let started = Date()
        let offline = try OfflineTutorProvider()
        for raw in rawRows {
            // Generation input is decoded separately. Golden diagnosis/experiment
            // fields are not inspected until after all three live turns finish.
            guard let object = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  let identifier = object["id"] as? String,
                  let query = object["canonical_question"] as? String,
                  let topic = object["topic"] as? String,
                  let variant = object["variant_kind"] as? String else {
                throw TestFailure(description: "P17 canonical generation shape drift")
            }
            var triplet: [[String: Any]] = []
            for level in levels {
                let root = temporaryRoot("p17-live-\(identifier)-\(level.rawValue)")
                defer { try? FileManager.default.removeItem(at: root) }
                let engine = TutorConversationEngine(
                    store: TutorConversationStore(rootURL: root),
                    tools: try TutorToolExecutor(),
                    fallbackProvider: offline
                )
                let context = TutorRuntimeContext(sourceType: .vocal, experience: .init(persistentLevel: level))
                let events = try await collectTurn(engine, query, context, FailingConversationProvider(error: .consentRequired))
                guard let receipt = events.compactMap({ if case let .completed(_, value) = $0 { value } else { nil } }).last,
                      let message = (await engine.snapshot()).messages.last else {
                    throw TestFailure(description: "P17 live response/receipt missing \(identifier)")
                }
                let normalized = Self.normalizedOfflinePresentation(message.text)
                let toolNames = receipt.tools.map(\.name).sorted()
                let currentExperimentCount = normalized.components(separatedBy: "One controlled test:").count - 1
                    + normalized.components(separatedBy: "One reversible Logic test:").count - 1
                let output = [
                    "caseID": identifier, "topic": topic, "effectiveLevel": level.rawValue,
                    "querySHA256": Self.sha256String(query), "assistantTextSHA256": receipt.assistantTextSHA256,
                    "normalizedUnderlyingSHA256": Self.sha256String(normalized), "toolNames": toolNames,
                    "evidenceKinds": receipt.evidence.map { $0.kind.rawValue }.sorted(),
                    "authority": normalized.lowercased().contains("no authority to change"),
                    "stop": normalized.lowercased().contains("stop"),
                    "rollback": normalized.lowercased().contains("undo") || normalized.lowercased().contains("restore"),
                    "oneCurrentExperiment": currentExperimentCount == 1,
                    "receiptExperience": receipt.experience?.effectiveLevel.rawValue ?? "missing",
                    "expectedTextProvidedToGeneration": false,
                ] as [String: Any]
                triplet.append(output)
                if requiredTopics.contains(topic), variant == "initial" {
                    acceptance[topic, default: []].insert(level)
                }
            }
            // Only now read evaluator reference keys. They are recorded as
            // unavailable-to-receipt semantic references, never copied into a pass.
            let postGeneration = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
            let diagnosisKey = postGeneration["diagnosis_key"] as? String
            let experimentKey = postGeneration["experiment_key"] as? String
            for index in triplet.indices {
                triplet[index]["postGenerationDiagnosisKey"] = diagnosisKey ?? "missing"
                triplet[index]["postGenerationExperimentKey"] = experimentKey ?? "missing"
                triplet[index]["semanticKeyAssertedFromReceipt"] = false
                semanticReferenceUnavailable += 1
            }
            let invariant = Set(triplet.compactMap { $0["normalizedUnderlyingSHA256"] as? String }).count == 1
                && Set(triplet.compactMap { ($0["toolNames"] as? [String])?.joined(separator: "|") }).count == 1
                && Set(triplet.compactMap { ($0["evidenceKinds"] as? [String])?.joined(separator: "|") }).count == 1
                && triplet.allSatisfy({ ($0["authority"] as? Bool) == true && ($0["stop"] as? Bool) == true && ($0["rollback"] as? Bool) == true && ($0["oneCurrentExperiment"] as? Bool) == true })
            let scaffoldingDiffers = Set(triplet.compactMap { $0["assistantTextSHA256"] as? String }).count == 3
            if !invariant || !scaffoldingDiffers { tripletInvariantFailures.append(identifier) }
            for index in triplet.indices {
                triplet[index]["tripletInvariantPassed"] = invariant
                triplet[index]["scaffoldingDiffers"] = scaffoldingDiffers
            }
            records.append(contentsOf: triplet)
        }
        try expect(records.count == 540, "P17 live evaluator did not produce 540 records")
        try expect(acceptance.count == requiredTopics.count && acceptance.values.allSatisfy { $0 == Set(levels) },
                   "P17 required 12 acceptance conversations are not all represented at three levels")
        let artifact: [String: Any] = [
            "schemaVersion": "1.0", "evaluator": ["id": "TutorConversationTests.live-offline", "version": "1.0"],
            "evaluationMode": "real OfflineTutorProvider and TutorConversationEngine; expected text hidden during generation",
            "counts": ["canonical": 180, "levels": 3, "liveRecords": records.count, "acceptance": 36],
            "durationMilliseconds": Int(Date().timeIntervalSince(started) * 1_000),
            "semanticReferenceUnavailableFromReceipts": semanticReferenceUnavailable,
            "tripletInvariantFailures": tripletInvariantFailures,
            "records": records,
        ]
        let destination = repository.appendingPathComponent("research/tutor_quality/evaluations/package17-live-offline-evaluation.json")
        let data = try JSONSerialization.data(withJSONObject: artifact, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: destination, options: .atomic)
        print("P17_LIVE_OFFLINE_EVALUATION_OK canonical=180 levels=3 records=540 acceptance=36 semanticReceiptKeys=unavailable invariantFailures=\(tripletInvariantFailures.count) durationMs=\(artifact["durationMilliseconds"]!)")
    }

    private static func normalizedOfflinePresentation(_ text: String) -> String {
        text.replacingOccurrences(of: "Plain-language path: start with the small A/B below. You do not need to know the control names before you begin; follow one step, compare, and keep the original as your reset point.\n\n", with: "")
            .replacingOccurrences(of: "Fast pass: preserve the baseline and run this single level-matched A/B.\n\n", with: "")
    }

    private nonisolated static func sha256String(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func sha256String(_ value: Data) -> String {
        SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
    }

    private func testCancellationAndExclusion() async throws {
        let root = temporaryRoot("cancel")
        defer { try? FileManager.default.removeItem(at: root) }
        let experiment = TutorExperimentRecord(draft: experimentDraft(title: "Concurrent outcome test"))
        let engine = TutorConversationEngine(
            state: TutorConversationState(experiments: [experiment]),
            store: TutorConversationStore(rootURL: root),
            tools: try TutorToolExecutor(),
            fallbackProvider: try OfflineTutorProvider()
        )
        let context = TutorRuntimeContext(sourceType: .vocal)
        let stream = try await engine.streamTurn(
            text: "Start a long explanation",
            context: context,
            provider: SlowConversationProvider()
        )
        let consumer = Task {
            do { for try await _ in stream {} } catch {}
        }
        try await Task.sleep(for: .milliseconds(60))
        do {
            _ = try await engine.streamTurn(
                text: "Overlapping turn",
                context: context,
                provider: SlowConversationProvider()
            )
            throw TestFailure(description: "concurrent turn unexpectedly started")
        } catch let error as TutorConversationError {
            try expect(error == .turnInProgress, "concurrent turn did not fail with turnInProgress")
        }
        do {
            _ = try await engine.recordOutcome(experimentID: experiment.id, outcome: .better)
            throw TestFailure(description: "outcome mutated state during an active turn")
        } catch let error as TutorConversationError {
            try expect(error == .turnInProgress, "active-turn outcome did not fail with turnInProgress")
        }
        consumer.cancel()
        _ = await consumer.result
        try await Task.sleep(for: .milliseconds(40))
        let state = await engine.snapshot()
        try expect(state.messages.first?.role == .user, "cancelled turn lost user message")
        try expect(state.messages.last?.status == .cancelled, "partial assistant turn was not marked cancelled")
        try expect(state.messages.last?.text.contains("Partial") == true, "partial streamed text was not retained")
    }

    private func collectTurn(
        _ engine: TutorConversationEngine,
        _ text: String,
        _ context: TutorRuntimeContext,
        _ provider: any TutorConversationProvider
    ) async throws -> [TutorConversationEvent] {
        let stream = try await engine.streamTurn(text: text, context: context, provider: provider)
        var events: [TutorConversationEvent] = []
        for try await event in stream { events.append(event) }
        return events
    }

    private func sampleCapture(wavData: Data) -> TutorCaptureSnapshot {
        TutorCaptureSnapshot(
            sourceType: .vocal,
            instanceID: UUID(),
            runtimeEpoch: UUID(),
            captureSnapshotID: UUID(),
            sha256: sha256(wavData),
            capturedAt: Date(timeIntervalSince1970: 1_786_300_000),
            durationSeconds: 8,
            scopeDescription: "Dry vocal input at the selected TrackSmith insert.",
            formatDescription: "48000 Hz mono WAV",
            isLive: true,
            metrics: [TutorMetricEvidence(
                identifier: "vocal_200_500_hz_energy_ratio",
                value: 0.31,
                unit: "ratio",
                confidence: 0.82,
                interpretationBoundary: "Broad-band concentration does not prove muddiness or masking."
            )],
            localAnalysisLimitations: ["No source separation; local measurements are not listening."]
        )
    }

    private func sampleReceipt(conversationID: UUID) -> TutorEvidenceReceipt {
        var provenance=TutorCandidateCorpusProvenance(packageID: "community-compression-arrangement-frequency-allocation-v1", packageVersion: "1.0.0", packageSequence: 3, recordID: "frequency.vocal_midrange.vocal_guitars")
        provenance.querySHA256=String(repeating: "a", count: 64); provenance.selectedDomain="frequency_allocation"; provenance.sourceIDs=["izotope.dynamic_eq"]; provenance.reviewState="candidate_not_yet_human_reviewed"; provenance.resultSHA256=String(repeating: "b", count: 64); provenance.selectedRecordIDs=["frequency.vocal_midrange.vocal_guitars","frequency.masking.vocal_guitars"]; provenance.retrievalID=String(repeating:"c", count:64); provenance.corpusVersion="p1-p15-selected-6212"; provenance.policyVersion="p16-policy-1"; provenance.omissions=["exact_fixture_identity","ambiguous_alias_authority","candidate_procedures","development_only_index","evaluation_data"]
        return TutorEvidenceReceipt(
            conversationID: conversationID,
            userMessageID: UUID(),
            assistantMessageID: UUID(),
            provider: TutorProviderMetadata(providerIdentifier: "test", modelIdentifier: "test-model"),
            assistantTextSHA256: sha256(Data("answer".utf8)),
            captureSnapshotID: nil,
            captureSHA256: nil,
            evidence: [TutorEvidenceReference(kind: .candidateKnowledge, label: "Test", detail: "Test evidence", candidateCorpusProvenance: provenance)],
            tools: [],
            consents: [TutorConsentReceipt(
                modality: .cloudConversationText,
                granted: false,
                purpose: "Offline test"
            )]
        )
    }

    private func experimentDraft(title: String) -> TutorExperimentDraft {
        TutorExperimentDraft(
            title: title,
            logicLocation: "Logic Pro 12.3 > Audio FX > Channel EQ",
            action: "Try a small bell adjustment.",
            startingRange: "-1 to -2 dB",
            listenFor: "Clarity without loss of body.",
            why: "A controlled comparison tests the low-mid hypothesis.",
            risk: "Too much can sound thin; stop before body recedes.",
            undo: "Reset the band or bypass the user-added EQ.",
            visualTargetQuery: "EQ"
        )
    }

    private func experimentArguments(title: String, stopCondition: String? = nil) -> String {
        let object: [String: Any] = [
            "title": title,
            "logic_location": "Logic Pro 12.3 > Audio FX > Channel EQ",
            "action": "Try a small bell adjustment.",
            "starting_range": "-1 to -2 dB",
            "listen_for": "Clarity without loss of body.",
            "why": "A controlled comparison tests the low-mid hypothesis.",
            "risk": "Too much can sound thin; stop before body recedes.",
            "stop_condition": stopCondition ?? NSNull(),
            "undo": "Reset the band or bypass the user-added EQ.",
            "visual_target_query": "EQ",
        ]
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func temporaryRoot(_ label: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackSmithTutorTests-\(label)-\(UUID().uuidString)", isDirectory: true)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func validMonoWAV(sampleRate: UInt32 = 48_000, frameCount: Int = 512) -> Data {
        let samples: [Float] = (0..<frameCount).map { Float(sin(Double($0) * 0.08) * 0.2) }
        var data = Data("RIFF".utf8)
        appendUInt32(UInt32(36 + samples.count * 4), to: &data)
        data.append(Data("WAVEfmt ".utf8)); appendUInt32(16, to: &data)
        appendUInt16(3, to: &data); appendUInt16(1, to: &data); appendUInt32(sampleRate, to: &data)
        appendUInt32(sampleRate * 4, to: &data); appendUInt16(4, to: &data); appendUInt16(32, to: &data)
        data.append(Data("data".utf8)); appendUInt32(UInt32(samples.count * 4), to: &data)
        for sample in samples { appendUInt32(sample.bitPattern, to: &data) }
        return data
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) { data.append(UInt8(value & 0xff)); data.append(UInt8(value >> 8)) }
    private func appendUInt32(_ value: UInt32, to data: inout Data) { data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff)); data.append(UInt8((value >> 16) & 0xff)); data.append(UInt8((value >> 24) & 0xff)) }
}

private final class RecordingStreamingTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let responseLines: [String]
    private var requests: [TutorStreamingHTTPRequest] = []

    init(lines: [String]) { responseLines = lines }

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests.append(request) }
        return TutorStreamingHTTPResponse(statusCode: 200, lines: Self.lines(responseLines))
    }

    func latestRequest() -> TutorStreamingHTTPRequest? { lock.withLock { requests.last } }

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// This transport is intentionally in-process: it captures the exact request
/// bytes produced by `OpenAITutorProvider` and returns fixed SSE fixtures. It
/// has no URLSession, socket, or credential side effect, so Package 019 can
/// exercise the real engine/tool loop without sending any data to a provider.
private final class PackageNineteenLoopbackStreamingTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    static let fixtureOutputTokens = 17

    private let lock = NSLock()
    private let toolLoop: Bool
    private var requests: [TutorStreamingHTTPRequest] = []

    init(toolLoop: Bool = true) { self.toolLoop = toolLoop }

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests.append(request) }
        if !toolLoop { return TutorStreamingHTTPResponse(statusCode: 200, lines: Self.lines(Self.finalLines)) }
        let hasFunctionOutput = String(decoding: request.body, as: UTF8.self).contains(#""type":"function_call_output""#)
        return TutorStreamingHTTPResponse(statusCode: 200, lines: Self.lines(hasFunctionOutput ? Self.finalLines : Self.toolLines))
    }

    func requestBodies() -> [Data] { lock.withLock { requests.map(\.body) } }

    private static let toolLines = [
        #"data: {"type":"response.completed","response":{"id":"local-tools","model":"local-loopback","usage":{"input_tokens":0,"output_tokens":0},"output":[{"type":"function_call","call_id":"tool-capture","name":"get_current_capture_context","arguments":"{}"},{"type":"function_call","call_id":"tool-candidate","name":"search_candidate_corpus","arguments":"{\"query\":\"muddy vocal guitars\"}"},{"type":"function_call","call_id":"tool-procedure","name":"get_logic_procedure","arguments":"{\"procedure_id\":null,\"query\":\"Channel EQ vocal low mid\"}"},{"type":"function_call","call_id":"tool-history","name":"retrieve_prior_experiments","arguments":"{\"query\":null,\"max_results\":6}"}]}}"#,
        "",
        "data: [DONE]",
        "",
    ]

    private static let finalLines = [
        #"data: {"type":"response.completed","response":{"id":"local-final","model":"local-loopback","usage":{"input_tokens":0,"output_tokens":17},"output":[{"type":"message","content":[{"type":"output_text","text":"Change one setting, then listen for the risk; stop and undo if it worsens."}]}]}}"#,
        "",
        "data: [DONE]",
        "",
    ]

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Network-incapable full-tool fixture that completes its tool round before
/// returning intentionally unpinned final metadata for terminal accounting.
private final class PackageNineteenFullToolThenUnpinnedMetadataTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        let count = lock.withLock { requests.append(request); return requests.count }
        return .init(statusCode: 200, lines: Self.lines(count == 1 ? Self.toolLines : Self.finalLines))
    }

    var requestCount: Int { lock.withLock { requests.count } }

    private static let toolLines = [
        #"data: {"type":"response.completed","response":{"id":"p19-full-tools","model":"gpt-5.6-sol","service_tier":"priority","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"function_call","call_id":"tool-capture","name":"get_current_capture_context","arguments":"{}"},{"type":"function_call","call_id":"tool-candidate","name":"search_candidate_corpus","arguments":"{\"query\":\"muddy vocal guitars\"}"},{"type":"function_call","call_id":"tool-procedure","name":"get_logic_procedure","arguments":"{\"procedure_id\":null,\"query\":\"Channel EQ vocal low mid\"}"},{"type":"function_call","call_id":"tool-history","name":"retrieve_prior_experiments","arguments":"{\"query\":null,\"max_results\":6}"}]}}"#,
        "", "data: [DONE]", "",
    ]

    private static let finalLines = [
        #"data: {"type":"response.completed","response":{"id":"p19-full-unpinned","model":"gpt-5.6-sol","service_tier":"fast","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"Provider-free full-tool completion with intentionally unpinned metadata."}]}]}}"#,
        "", "data: [DONE]", "",
    ]

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Test-only forwarding recorder for an explicitly consented Package 019 run.
/// It observes serialized request envelopes only; production provider/tool
/// authority is unchanged and the wrapped transport remains responsible for
/// every network operation. The deterministic diagnostic instead uses the
/// loopback transport above, so this type makes zero calls unless an opt-in
/// cloud command constructs it.
private final class PackageNineteenRecordingForwardingTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let base: any TutorStreamingHTTPTransport
    private let requestMutation: ((inout TutorStreamingHTTPRequest) -> Void)?
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    init(base: any TutorStreamingHTTPTransport = URLSessionTutorStreamingTransport(), requestMutation: ((inout TutorStreamingHTTPRequest) -> Void)? = nil) {
        self.base = base
        self.requestMutation = requestMutation
    }

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        var forwarded = request
        requestMutation?(&forwarded)
        lock.withLock { requests.append(forwarded) }
        return try await base.stream(forwarded)
    }

    func requestBodies() -> [Data] { lock.withLock { requests.map(\.body) } }
    var requestCount: Int { lock.withLock { requests.count } }
}

/// Deterministic two-attempt transport for the Package 019 retry contract.
/// It never contains a URL session or any route to the network.
private final class PackageNineteenRetryLoopbackStreamingTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        let count = lock.withLock { requests.append(request); return requests.count }
        if count == 1 {
            throw TutorConversationError.timedOut
        }
        return .init(statusCode: 200, lines: Self.lines([
            #"data: {"type":"response.completed","response":{"id":"p19-retry","model":"gpt-5.6-sol","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"Provider-free retry completed."}]}]}}"#,
            "", "data: [DONE]", "",
        ]))
    }

    var requestCount: Int { lock.withLock { requests.count } }

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Provider-free retry fixture whose completed second response intentionally
/// fails the harness's pinned-metadata validation after both requests exist.
private final class PackageNineteenRetryThenUnpinnedMetadataTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        let count = lock.withLock { requests.append(request); return requests.count }
        if count == 1 { throw TutorConversationError.timedOut }
        return .init(statusCode: 200, lines: Self.lines([
            #"data: {"type":"response.completed","response":{"id":"p19-retry-unpinned","model":"gpt-5.6-sol","service_tier":"fast","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"Provider-free retry completed with intentionally unpinned metadata."}]}]}}"#,
            "", "data: [DONE]", "",
        ]))
    }

    var requestCount: Int { lock.withLock { requests.count } }

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Provider-free supporting-judge fixture: the retry succeeds with valid
/// structured JSON, but its metadata is intentionally outside the pin.
private final class PackageNineteenRetryThenUnpinnedJudgeMetadataTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        let count = lock.withLock { requests.append(request); return requests.count }
        if count == 1 { throw TutorConversationError.timedOut }
        return .init(statusCode: 200, lines: Self.lines([
            #"data: {"type":"response.completed","response":{"id":"p19-judge-retry-unpinned","model":"gpt-5.6-sol","service_tier":"fast","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"{\"usefulness\":true,\"evidence_honesty\":true,\"strict_level_invariance\":false,\"experiment_completeness\":true,\"exact_procedure_necessity\":false}"}]}]}}"#,
            "", "data: [DONE]", "",
        ]))
    }

    var requestCount: Int { lock.withLock { requests.count } }

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Provider-free supporting-judge fixture with a valid, pinned completion
/// after one typed transient failure; request-envelope mutation tests use it.
private final class PackageNineteenRetryThenPinnedJudgeTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        let count = lock.withLock { requests.append(request); return requests.count }
        if count == 1 { throw TutorConversationError.timedOut }
        return .init(statusCode: 200, lines: Self.lines([
            #"data: {"type":"response.completed","response":{"id":"p19-judge-retry-pinned","model":"gpt-5.6-sol","service_tier":"priority","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"{\"usefulness\":true,\"evidence_honesty\":true,\"strict_level_invariance\":false,\"experiment_completeness\":true,\"exact_procedure_necessity\":false}"}]}]}}"#,
            "", "data: [DONE]", "",
        ]))
    }

    var requestCount: Int { lock.withLock { requests.count } }

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Provider-free judge fixture with the five required booleans plus forbidden
/// explanatory output, used to prove strict output/privacy rejection.
private final class PackageNineteenExtraFieldJudgeTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests.append(request) }
        return .init(statusCode: 200, lines: Self.lines([
            #"data: {"type":"response.completed","response":{"id":"p19-judge-extra","model":"gpt-5.6-sol","service_tier":"priority","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"{\"usefulness\":true,\"evidence_honesty\":true,\"strict_level_invariance\":false,\"experiment_completeness\":true,\"exact_procedure_necessity\":false,\"rationale\":\"reference-derived explanation\"}"}]}]}}"#,
            "", "data: [DONE]", "",
        ]))
    }

    var requestCount: Int { lock.withLock { requests.count } }

    private static func lines(_ values: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}

/// Records a real serialized request, then terminates before any provider
/// completion so failure artifacts can prove their no-receipt projection.
private final class PackageNineteenPreReceiptFailureTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests.append(request) }
        throw TutorConversationError.cancelled
    }

    var requestCount: Int { lock.withLock { requests.count } }
}

/// Network-incapable engine transport used to verify that a durable offline
/// fallback records its single failed primary request without a retry.
private final class PackageNineteenEngineTimeoutTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests.append(request) }
        throw TutorConversationError.timedOut
    }

    var requestCount: Int { lock.withLock { requests.count } }
}

/// Simulates a transport fault after the provider has already emitted its
/// completed metadata. The direct retry helper must retain that completion.
private final class PackageNineteenCompletedThenErrorTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [TutorStreamingHTTPRequest] = []

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests.append(request) }
        let lines = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield(#"data: {"type":"response.completed","response":{"id":"local-after-complete","model":"gpt-5.6-sol","service_tier":"priority","usage":{"input_tokens":1,"output_tokens":1},"output":[{"type":"message","content":[{"type":"output_text","text":"Completed before transport fault."}]}]}}"#)
            continuation.yield("")
            continuation.finish(throwing: TutorConversationError.timedOut)
        }
        return .init(statusCode: 200, lines: lines)
    }

    var requestCount: Int { lock.withLock { requests.count } }
}

private struct ThrowingStreamingTransport: TutorStreamingHTTPTransport {
    let error: any Error & Sendable
    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse { throw error }
}

private final class RecordingHTTPTransport: ProviderHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let response: ProviderHTTPResponse
    private var requests: [ProviderHTTPRequest] = []

    init(response: ProviderHTTPResponse) { self.response = response }

    func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse {
        lock.withLock { requests.append(request) }
        return response
    }

    var requestCount: Int { lock.withLock { requests.count } }
    var latestRequest: ProviderHTTPRequest? { lock.withLock { requests.last } }
}

private final class StatefulScriptedProvider: TutorConversationProvider, @unchecked Sendable {
    let providerIdentifier = "stateful-scripted-tutor"
    private let lock = NSLock()
    private var requests: [TutorProviderRequest] = []

    func stream(_ request: TutorProviderRequest) -> AsyncThrowingStream<TutorProviderEvent, Error> {
        lock.withLock { requests.append(request) }
        let latest = request.messages.last(where: { $0.role == .user })?.text.lowercased() ?? ""
        let output: [TutorProviderOutputItem]
        if latest.contains("sounds muddy") {
            if request.continuations.isEmpty {
                output = [.functionCall(TutorToolCall(
                    callID: "knowledge-1",
                    name: "search_production_knowledge",
                    argumentsJSON: #"{"query":"muddy vocal low mid masking"}"#
                ))]
            } else {
                output = [.text("Is the muddiness present in solo, in the full mix, or both? That answer changes whether source tone or masking is the better first hypothesis.")]
            }
        } else if latest.contains("full mix") {
            if request.continuations.isEmpty {
                output = [.functionCall(TutorToolCall(
                    callID: "experiment-1",
                    name: "present_experiment",
                    argumentsJSON: scriptedExperimentArguments()
                ))]
            } else {
                output = [.text("Try the one small, reversible low-mid comparison below while the full mix plays. Stop before the vocal loses body; this tests a masking hypothesis rather than declaring a cause.")]
            }
        } else if latest.contains("thin now") {
            if request.continuations.isEmpty {
                output = [.functionCall(TutorToolCall(
                    callID: "history-1",
                    name: "retrieve_prior_experiments",
                    argumentsJSON: #"{"query":null,"max_results":6}"#
                ))]
            } else {
                output = [.text("The clearer-but-thin result suggests the cut removed useful body along with overlap. Restore it first. The reusable lesson is to change less, compare in context, and test arrangement or a narrower competing source next.")]
            }
        } else {
            output = [.text("I won't repeat the broad cut that made the vocal thin. Listen again after restoring it, then make the next comparison on the competing mix element or with a narrower, smaller move.")]
        }
        let metadata = TutorProviderMetadata(
            providerIdentifier: providerIdentifier,
            modelIdentifier: "scripted-stateful-test"
        )
        return AsyncThrowingStream { continuation in
            if case let .text(text) = output.first {
                for chunk in text.chunked(maximum: 27) { continuation.yield(.textDelta(chunk)) }
            }
            continuation.yield(.completed(metadata: metadata, output: output))
            continuation.finish()
        }
    }

    func requestsSnapshot() -> [TutorProviderRequest] { lock.withLock { requests } }

    private func scriptedExperimentArguments() -> String {
        let object: [String: Any] = [
            "title": "Test a smaller vocal low-mid move in context",
            "logic_location": "Logic Pro 12.3 > vocal channel > Audio FX > Channel EQ",
            "action": "Add or open Channel EQ and make one broad, small cut while the full mix plays.",
            "starting_range": "Around 250-400 Hz, -1 to -2 dB, broad Q",
            "listen_for": "Whether words separate from the mix without the chest and size collapsing.",
            "why": "A level-aware comparison can test low-mid overlap without assuming processing is the cause.",
            "risk": "Too much reduction makes the vocal thin; stop as soon as body recedes.",
            "undo": "Reset that EQ band or bypass the user-added EQ.",
            "visual_target_query": "EQ",
        ]
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

private struct FailingConversationProvider: TutorConversationProvider {
    let providerIdentifier = "failing-test-provider"
    let error: TutorConversationError

    func stream(_ request: TutorProviderRequest) -> AsyncThrowingStream<TutorProviderEvent, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
    }
}

private struct SlowConversationProvider: TutorConversationProvider {
    let providerIdentifier = "slow-test-provider"

    func stream(_ request: TutorProviderRequest) -> AsyncThrowingStream<TutorProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.textDelta("Partial explanation"))
                do {
                    try await Task.sleep(for: .seconds(5))
                    continuation.yield(.completed(
                        metadata: TutorProviderMetadata(
                            providerIdentifier: providerIdentifier,
                            modelIdentifier: "slow-test"
                        ),
                        output: [.text("Partial explanation completed")]
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TutorConversationError.cancelled)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension String {
    func chunked(maximum: Int) -> [String] {
        var result: [String] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: maximum, limitedBy: endIndex) ?? endIndex
            result.append(String(self[start..<end]))
            start = end
        }
        return result
    }
}
