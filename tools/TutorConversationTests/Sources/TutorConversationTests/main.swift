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

@main
@MainActor
struct TutorConversationTests {
    static func main() async {
        let suite = Suite()
        await suite.run()
        print("TutorConversationTests: \(suite.passed)/\(suite.total) passed")
        if suite.passed != suite.total { Darwin.exit(1) }
    }
}

@MainActor
private final class Suite {
    private(set) var total = 0
    private(set) var passed = 0

    func run() async {
        await test("tool registry is mutation-incapable", testToolMutationFirewall)
        await test("legacy identifiers and Create/Vocal boundary are preserved", testLegacyBoundary)
        await test("strict OpenAI tool schemas stay bounded", testToolSchemas)
        await test("SSE decoder reconstructs deltas, text, calls, and metadata", testSSEDecoder)
        await test("streaming provider emits SSE and sends store false", testStreamingProvider)
        await test("streaming timeout is typed and sanitized", testStreamingTimeout)
        await test("reviewed knowledge, procedures, capture, Logic, and experiment tools execute", testToolExecution)
        await test("conversation store is checksummed, redacted, bounded, and receipt write-once", testStoreAndReceipts)
        await test("audio listening requires separate consent and exact live hash", testAudioListening)
        await test("audio intelligence evidence keeps exact waveform and calibration truth separate", testAudioIntelligenceTruth)
        await test("local waveform provider emits capture-bound exact-WAV observations", testLocalProviderExactWAV)
        await test("live-like Float WAV local evidence is finite, encodable, and cannot abort a tool turn", testLiveLikeLocalEvidenceTurn)
        await test("double provider failure leaves an honest attached-capture assistant status", testAttachedCaptureDoubleFailure)
        await test("attached generic offline fallback gives one honest reversible tonal next step", testAttachedGenericOfflineFallback)
        await test("comparison authority rejects hash-only follow-ups and accepts guarded continuity", testComparisonAuthority)
        await test("legacy experiment records decode with Phase 2 fields absent", testLegacyExperimentDecoding)
        await test("not sure and clearer-but-thin dialogue remain useful without listening claims", testResponseQualityVerticalSlice)
        await test("muddy to thin stateful conversation retains turns, tools, experiment, and outcome", testStatefulVerticalSlice)
        await test("cloud failure activates deterministic offline fallback", testAutomaticOfflineFallback)
        await test("cancellation persists an honest partial turn and blocks concurrent turns", testCancellationAndExclusion)
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
        try expect(tutorSession.components(separatedBy: "confirmEditedUpstreamOfTap = false").count >= 4,
                   "signal-path confirmation is not reset after outcome/new conversation/history deletion")
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
        try expect(defaults.maximumOutputTokens == 25_000, "reasoning/output reserve regressed")
        try expect(TutorAudioListeningConfiguration().modelIdentifier == "gpt-audio-1.5",
                   "audio listener defaulted to a deprecated model")
    }

    private func testSSEDecoder() async throws {
        let delta = try OpenAITutorSSEEventDecoder.decode(
            data: #"{"type":"response.output_text.delta","delta":"Clearer "}"#
        )
        try expect(delta == [.textDelta("Clearer ")], "text delta was not decoded")
        let completedJSON = #"{"type":"response.completed","response":{"id":"resp_test","model":"gpt-test","usage":{"input_tokens":12,"output_tokens":7},"output":[{"type":"reasoning","id":"rs_test","summary":[],"encrypted_content":"opaque-test-ciphertext"},{"type":"message","content":[{"type":"output_text","text":"Try one move."}]},{"type":"function_call","call_id":"call_1","name":"search_production_knowledge","arguments":"{\"query\":\"muddy vocal\"}"}]}}"#
        let completed = try OpenAITutorSSEEventDecoder.decode(data: completedJSON)
        guard case let .completed(metadata, output) = completed.first else {
            throw TestFailure(description: "completion event missing")
        }
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
    }

    private func testStreamingProvider() async throws {
        let lines = [
            #"data: {"type":"response.output_text.delta","delta":"Hello "}"#,
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
        TutorEvidenceReceipt(
            conversationID: conversationID,
            userMessageID: UUID(),
            assistantMessageID: UUID(),
            provider: TutorProviderMetadata(providerIdentifier: "test", modelIdentifier: "test-model"),
            assistantTextSHA256: sha256(Data("answer".utf8)),
            captureSnapshotID: nil,
            captureSHA256: nil,
            evidence: [TutorEvidenceReference(kind: .inference, label: "Test", detail: "Test evidence")],
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
