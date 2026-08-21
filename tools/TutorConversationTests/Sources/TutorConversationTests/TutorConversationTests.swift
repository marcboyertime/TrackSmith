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
    init(_ state: CandidateRetrievalAvailability, _ values: [CommunityCandidateCorpusRankedCard] = []) { self.state = state; self.values = values }
    func availability() -> CandidateRetrievalAvailability { state }
    func ranked(query: String, filters: CommunityCandidateCorpusFilters, limit: Int) -> [CommunityCandidateCorpusRankedCard] { values.prefix(limit).map { $0 } }
}

@main
@MainActor
struct TutorConversationTests {
    static func main() async {
        let projection = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("research/community_knowledge/runtime_projection/p16", isDirectory: true).path
        setenv("TRACKSMITH_LEGACY_TEST_ORACLE_DIRECTORY", projection, 1)
        let suite = Suite()
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
        } else if CommandLine.arguments.contains("package17-diagnostics") {
            await suite.runPackageSeventeenDiagnostic()
        } else if CommandLine.arguments.contains("package18-diagnostics") {
            await suite.runPackageEighteenDiagnostic()
        } else if CommandLine.arguments.contains("package18-index-readiness") {
            await suite.runPackageEighteenIndexReadiness()
        } else if CommandLine.arguments.contains("package18-legacy-readiness") {
            await suite.runPackageEighteenLegacyReadiness()
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
        print("TutorConversationTests: \(suite.passed)/\(suite.total) passed")
        fflush(stdout)
        if suite.passed != suite.total { Darwin.exit(1) }
    }
}

@MainActor
private final class Suite {
    private(set) var total = 0
    private(set) var passed = 0

    private nonisolated static let packageSeventeenCloudMaximumTopicConcurrency = 3
    private nonisolated static let packageSeventeenCloudMaximumAttempts = 2
    private nonisolated static let packageSeventeenLevelOrder: [TutorExperienceLevel] = [.noob, .amateur, .pro]
    private nonisolated static let packageSeventeenTextModel = "gpt-5.6-sol"
    private nonisolated static let packageSeventeenAudioModel = "gpt-audio-1.5"
    private nonisolated static let packageSeventeenPublicAudioFixtureSHA256 = "f6f168af94a612185ea4b9338e96776f936dcff2188ba5330cf3702067f11d7b"
    private nonisolated static let packageSeventeenPublicAudioFixturePathSuffix = "/Library/Caches/TrackSmith/P16/fixtures/generated/p16-controlled-source.wav"

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

    private func test(_ name: String, _ body: () async throws -> Void) async {
        total += 1
        do {
            try await body()
            passed += 1
            print("PASS \(name)")
        } catch {
            print("FAIL \(name): \(error)")
        }
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
            "why", "risk", "undo", "visual_target_query",
        ]), "experiment contract is incomplete")
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
        if provenance?.policyVersion != "package018-bm25-general-rerank/1" {
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
        let mismatchManifest = root.appendingPathComponent("mismatch.json")
        try Data(#"{"schema_version":"wrong","corpus_version":"p16-runtime-projection-6212","retrieval_policy_version":"wrong","card_count":6212,"package_017_runtime_count":0,"database":"none.sqlite","database_bytes":0,"database_header_sha256":""}"#.utf8).write(to: mismatchManifest)
        try expect(CandidateRetrievalIndex.open(indexURL: nil, manifestURL: nil).availability == .unavailable &&
                   CandidateRetrievalIndex.open(indexURL: nil, manifestURL: corruptManifest).availability == .corrupt &&
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
        let matrix: [(CandidateRetrievalAvailability, [CommunityCandidateCorpusRankedCard], Bool)] = [(.unavailable, [], false), (.corrupt, [results[0]], false), (.versionMismatch, [results[0]], false), (.disabled, [results[0]], false), (.ready, [results[0]], true), (.ready, [], false), (.ready, [ambiguous, results[1]], true)]
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
        let packageText = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Package.swift"))
        try expect(!packageText.contains("community-reverb-delay-v1.json") && packageText.contains("CandidateRetrieval.sqlite"),
                   "P18 raw candidate resources remain in product package declaration")
        print("P18_INDEX_OK availability=ready selected=\(results.count) decodedPayloads=\(decoded) failureStates=4 diagnostics=bounded bundle=compiled-index-only indexedReadinessMs=\(Int(indexedReadinessMilliseconds)) legacyReadinessMs=\(Int(legacyReadinessMilliseconds))")
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

    private nonisolated static func cloudTripletJudgments(
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

    private func experimentArguments(title: String) -> String {
        let object: [String: Any] = [
            "title": title,
            "logic_location": "Logic Pro 12.3 > Audio FX > Channel EQ",
            "action": "Try a small bell adjustment.",
            "starting_range": "-1 to -2 dB",
            "listen_for": "Clarity without loss of body.",
            "why": "A controlled comparison tests the low-mid hypothesis.",
            "risk": "Too much can sound thin; stop before body recedes.",
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
