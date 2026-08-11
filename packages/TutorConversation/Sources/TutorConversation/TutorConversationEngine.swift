import CryptoKit
import Foundation

public actor TutorConversationEngine {
    public static let maximumMessageBytes = 24 * 1_024
    public static let maximumToolRounds = 5

    private var state: TutorConversationState
    private let store: TutorConversationStore
    private let tools: TutorToolExecutor
    private let fallbackProvider: any TutorConversationProvider
    private var activeTurnID: UUID?

    public init(
        state: TutorConversationState = TutorConversationState(),
        store: TutorConversationStore,
        tools: TutorToolExecutor,
        fallbackProvider: any TutorConversationProvider
    ) {
        self.state = state
        self.store = store
        self.tools = tools
        self.fallbackProvider = fallbackProvider
    }

    public static func live(
        observeLogic: @escaping TutorToolExecutor.LogicObservationProvider = { _ in .unavailable }
    ) throws -> TutorConversationEngine {
        let store = try TutorConversationStore()
        let state = (try? store.loadMostRecent()) ?? TutorConversationState()
        let tools = try TutorToolExecutor(
            observeLogic: observeLogic,
            priorExperiments: {
                (try? store.loadMostRecent()?.experiments) ?? []
            }
        )
        return TutorConversationEngine(
            state: state,
            store: store,
            tools: tools,
            fallbackProvider: try OfflineTutorProvider()
        )
    }

    public func snapshot() -> TutorConversationState { state }

    public func startNewConversation(projectGoal: String? = nil) throws -> TutorConversationState {
        guard activeTurnID == nil else { throw TutorConversationError.turnInProgress }
        state = TutorConversationState(projectGoal: projectGoal)
        try persistState()
        return state
    }

    public func deleteAllHistory() throws {
        guard activeTurnID == nil else { throw TutorConversationError.turnInProgress }
        try store.deleteAll()
        state = TutorConversationState()
    }

    public func recordOutcome(
        experimentID: UUID,
        outcome: TutorExperimentOutcome,
        note: String? = nil,
        userReportedSettings: [String] = [],
        followUpCapture: TutorCaptureSnapshot? = nil,
        userConfirmedUpstreamAndObservable: Bool = false
    ) throws -> TutorExperimentRecord {
        guard activeTurnID == nil else { throw TutorConversationError.turnInProgress }
        guard let index = state.experiments.firstIndex(where: { $0.id == experimentID }) else {
            throw TutorConversationError.persistence("The experiment is no longer in this conversation.")
        }
        state.experiments[index].outcome = outcome
        state.experiments[index].userNote = note
        state.experiments[index].userReportedSettings = Array(userReportedSettings.prefix(12))
        state.experiments[index].waveformComparison = TutorComparisonAuthorityValidator.validate(
            authority: state.experiments[index].comparisonAuthority,
            followUp: followUpCapture,
            userConfirmedUpstreamAndObservable: userConfirmedUpstreamAndObservable
        )
        state.updatedAt = Date()
        try persistState()
        return state.experiments[index]
    }

    public func streamTurn(
        text rawText: String,
        context: TutorRuntimeContext,
        provider: any TutorConversationProvider
    ) throws -> AsyncThrowingStream<TutorConversationEvent, Error> {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TutorConversationError.emptyMessage }
        guard text.utf8.count <= Self.maximumMessageBytes else {
            throw TutorConversationError.messageTooLarge
        }
        guard activeTurnID == nil else { throw TutorConversationError.turnInProgress }
        let userMessage = TutorConversationMessage(role: .user, text: text)
        state.messages.append(userMessage)
        state.projectGoal = context.projectGoal ?? state.projectGoal
        state.updatedAt = Date()
        let assistantMessageID = UUID()
        activeTurnID = assistantMessageID
        do {
            try persistState()
        } catch {
            activeTurnID = nil
            throw error
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                await self.runTurn(
                    userMessage: userMessage,
                    assistantMessageID: assistantMessageID,
                    context: context,
                    primaryProvider: provider,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runTurn(
        userMessage: TutorConversationMessage,
        assistantMessageID: UUID,
        context: TutorRuntimeContext,
        primaryProvider: any TutorConversationProvider,
        continuation: AsyncThrowingStream<TutorConversationEvent, Error>.Continuation
    ) async {
        defer {
            if activeTurnID == assistantMessageID { activeTurnID = nil }
        }
        var accumulatedText = ""
        var primaryFailureReason: String?
        do {
            let result: ProviderTurnResult
            do {
                result = try await executeProviderTurn(
                    provider: primaryProvider,
                    assistantMessageID: assistantMessageID,
                    context: context,
                    continuation: continuation,
                    accumulatedText: &accumulatedText
                )
            } catch let error as TutorConversationError where error == .cancelled {
                throw error
            } catch is CancellationError {
                throw TutorConversationError.cancelled
            } catch {
                let reason = fallbackReason(error)
                primaryFailureReason = reason
                continuation.yield(.fallbackActivated(reason))
                if !accumulatedText.isEmpty {
                    let divider = "\n\n— Offline fallback —\n\n"
                    let accepted = appendBounded(divider, to: &accumulatedText)
                    if !accepted.isEmpty {
                        continuation.yield(.textDelta(messageID: assistantMessageID, text: accepted))
                    }
                }
                result = try await executeProviderTurn(
                    provider: fallbackProvider,
                    assistantMessageID: assistantMessageID,
                    context: context,
                    continuation: continuation,
                    accumulatedText: &accumulatedText
                )
            }

            let evidence = evidenceReferences(context: context, toolResults: result.toolResults)
            let experimentID = result.experimentIDs.last
            state.messages.append(TutorConversationMessage(
                id: assistantMessageID,
                role: .assistant,
                text: accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines),
                status: .complete,
                evidence: evidence,
                experimentID: experimentID
            ))
            state.updatedAt = Date()
            state = try store.normalized(state)
            guard let assistantMessage = state.messages.first(where: { $0.id == assistantMessageID }) else {
                throw TutorConversationError.persistence("The completed Tutor message could not be retained.")
            }
            let receipt = TutorEvidenceReceipt(
                conversationID: state.id,
                userMessageID: userMessage.id,
                assistantMessageID: assistantMessage.id,
                provider: result.metadata,
                fallbackReason: primaryFailureReason,
                assistantTextSHA256: sha256(Data(assistantMessage.text.utf8)),
                captureSnapshotID: context.capture?.captureSnapshotID,
                captureSHA256: context.capture?.sha256,
                evidence: evidence,
                tools: result.toolResults.map { tool in
                    TutorToolReceipt(
                        name: tool.call.name,
                        callID: tool.call.callID,
                        argumentsSHA256: sha256(Data(tool.call.argumentsJSON.utf8)),
                        outputSHA256: sha256(Data(tool.outputJSON.utf8))
                    )
                },
                consents: consentReceipts(context: context, toolResults: result.toolResults)
            )
            try store.saveReceipt(receipt)
            for experimentID in result.experimentIDs {
                if let index = state.experiments.firstIndex(where: { $0.id == experimentID }) {
                    state.experiments[index].evidenceReceiptID = receipt.id
                }
            }
            try persistState()
            continuation.yield(.completed(message: assistantMessage, receipt: receipt))
            continuation.finish()
        } catch let error as TutorConversationError where error == .cancelled {
            persistInterruptedMessage(
                id: assistantMessageID,
                text: accumulatedText,
                status: .cancelled,
                context: context
            )
            continuation.yield(.cancelled(messageID: assistantMessageID))
            continuation.finish(throwing: error)
        } catch is CancellationError {
            persistInterruptedMessage(
                id: assistantMessageID,
                text: accumulatedText,
                status: .cancelled,
                context: context
            )
            continuation.yield(.cancelled(messageID: assistantMessageID))
            continuation.finish(throwing: TutorConversationError.cancelled)
        } catch {
            persistInterruptedMessage(
                id: assistantMessageID,
                text: accumulatedText,
                status: .failed,
                context: context
            )
            continuation.finish(throwing: error)
        }
    }

    private func executeProviderTurn(
        provider: any TutorConversationProvider,
        assistantMessageID: UUID,
        context: TutorRuntimeContext,
        continuation: AsyncThrowingStream<TutorConversationEvent, Error>.Continuation,
        accumulatedText: inout String
    ) async throws -> ProviderTurnResult {
        var providerContinuations: [TutorProviderContinuation] = []
        var responseInputItemsJSON: [String] = []
        var toolResults: [TutorToolResult] = []
        var experimentIDs: [UUID] = []
        var finalMetadata: TutorProviderMetadata?

        for _ in 0..<Self.maximumToolRounds {
            if Task.isCancelled { throw TutorConversationError.cancelled }
            let request = TutorProviderRequest(
                messages: state.messages,
                context: context,
                tools: tools.definitions,
                continuations: providerContinuations,
                responseInputItemsJSON: responseInputItemsJSON
            )
            var completed: (TutorProviderMetadata, [TutorProviderOutputItem])?
            var receivedTextDelta = false
            for try await event in provider.stream(request) {
                switch event {
                case let .textDelta(delta):
                    receivedTextDelta = true
                    let accepted = appendBounded(delta, to: &accumulatedText)
                    if !accepted.isEmpty {
                        continuation.yield(.textDelta(messageID: assistantMessageID, text: accepted))
                    }
                case let .completed(metadata, output):
                    completed = (metadata, output)
                }
            }
            guard let completed else {
                throw TutorConversationError.malformedProviderResponse("Provider emitted no completion event.")
            }
            finalMetadata = completed.0
            responseInputItemsJSON.append(contentsOf: completed.1.compactMap { item in
                if case let .responseInputItemJSON(json) = item { return json }
                return nil
            })
            if !receivedTextDelta {
                let completedText = completed.1.compactMap { item -> String? in
                    if case let .text(text) = item { return text }
                    return nil
                }.joined()
                if !completedText.isEmpty {
                    let accepted = appendBounded(completedText, to: &accumulatedText)
                    if !accepted.isEmpty {
                        continuation.yield(.textDelta(messageID: assistantMessageID, text: accepted))
                    }
                }
            }
            let calls = completed.1.compactMap { item -> TutorToolCall? in
                if case let .functionCall(call) = item { return call }
                return nil
            }
            if calls.isEmpty {
                guard let finalMetadata else {
                    throw TutorConversationError.malformedProviderResponse("Provider metadata was unavailable.")
                }
                return ProviderTurnResult(
                    metadata: finalMetadata,
                    toolResults: toolResults,
                    experimentIDs: experimentIDs
                )
            }
            guard toolResults.count + calls.count <= TutorToolExecutor.maximumToolCallsPerTurn else {
                throw TutorConversationError.toolLimitReached
            }
            for call in calls {
                continuation.yield(.toolActivity(call.name))
                let result = try await tools.execute(call, context: context)
                toolResults.append(result)
                providerContinuations.append(TutorProviderContinuation(
                    call: call,
                    outputJSON: result.outputJSON
                ))
                responseInputItemsJSON.append(try functionOutputJSON(callID: call.callID, output: result.outputJSON))
                if let draft = result.experiment {
                    var record = TutorExperimentRecord(
                        draft: draft,
                        comparisonAuthority: context.capture.map { TutorComparisonAuthority(baseline: $0) }
                    )
                    if state.experiments.contains(where: { $0.id == record.id }) {
                        record.draft.id = UUID()
                    }
                    state.experiments.append(record)
                    state.updatedAt = Date()
                    try persistState()
                    experimentIDs.append(record.id)
                    continuation.yield(.experiment(record))
                }
            }
        }
        throw TutorConversationError.toolLimitReached
    }

    private func evidenceReferences(
        context: TutorRuntimeContext,
        toolResults: [TutorToolResult]
    ) -> [TutorEvidenceReference] {
        var values: [TutorEvidenceReference] = [TutorEvidenceReference(
            kind: .userReported,
            label: "Current request",
            detail: "The musician's current message and explicit conversation history."
        )]
        if let capture = context.capture {
            if !capture.metrics.isEmpty {
                values.append(TutorEvidenceReference(
                    kind: .locallyMeasured,
                    label: "Current local analysis",
                    detail: "\(capture.metrics.count) bounded descriptive measurements from capture \(capture.captureSnapshotID.uuidString.prefix(8)).",
                    captureSnapshotID: capture.captureSnapshotID
                ))
            }
            if let intelligence = capture.audioIntelligence {
                values.append(TutorEvidenceReference(
                    kind: .locallyMeasured,
                    label: "Exact local waveform specialist",
                    detail: intelligence.failure ?? "Exact WAV bytes were measured locally; this is not model listening.",
                    captureSnapshotID: capture.captureSnapshotID
                ))
            }
            if capture.cloudListening.status == .listened,
               let summary = capture.cloudListening.summary {
                values.append(TutorEvidenceReference(
                    kind: .heardByModel,
                    label: "Bounded capture listened",
                    detail: summary,
                    captureSnapshotID: capture.captureSnapshotID
                ))
            } else if context.consent.audioRequested {
                values.append(TutorEvidenceReference(
                    kind: .unavailable,
                    label: "Model listening unavailable",
                    detail: capture.cloudListening.summary
                        ?? "The optional audio-listening route did not authorize a Heard claim for this turn.",
                    captureSnapshotID: capture.captureSnapshotID
                ))
            }
        } else if context.consent.audioRequested {
            values.append(TutorEvidenceReference(
                kind: .unavailable,
                label: "No capture for model listening",
                detail: "Audio listening was requested, but no current capture was attached. No audio bytes were sent."
            ))
        }
        if let logic = context.logicObservation, logic.status == .observed {
            values.append(TutorEvidenceReference(
                kind: .logicObserved,
                label: "Visible Logic UI",
                detail: logic.limitation
            ))
        }
        values.append(contentsOf: toolResults.flatMap(\.evidence))
        values.append(TutorEvidenceReference(
            kind: .inference,
            label: "Tutor reasoning",
            detail: "Diagnosis and recommendation are reasoned guidance, not proof of cause or proof of improvement."
        ))
        var seen = Set<String>()
        return values.filter {
            seen.insert([$0.kind.rawValue, $0.label, $0.metricIdentifier ?? ""].joined(separator: "|")).inserted
        }.prefix(24).map { $0 }
    }

    private func consentReceipts(
        context: TutorRuntimeContext,
        toolResults: [TutorToolResult]
    ) -> [TutorConsentReceipt] {
        var receipts = [TutorConsentReceipt(
            modality: .cloudConversationText,
            granted: context.consent.cloudTextGranted,
            purpose: context.consent.cloudTextGranted
                ? "Authorized bounded Tutor conversation text, labeled context, and local measurements for this turn; provider metadata records which path completed."
                : "Cloud conversation consent was off; the deterministic offline fallback remains authorized."
        )]
        if context.consent.audioRequested {
            receipts.append(TutorConsentReceipt(
                modality: .cloudCaptureAudio,
                granted: context.consent.cloudAudioGranted,
                purpose: context.consent.cloudAudioGranted
                    ? "Authorized the exact bounded, hash-checked WAV snapshot for optional audio listening on this turn; Heard evidence records whether listening completed."
                    : "Audio was requested in the UI, but separate cloud-audio consent was off; no audio upload was authorized.",
                captureSnapshotID: context.capture?.captureSnapshotID
            ))
        }
        if let observation = toolResults.first(where: { $0.call.name == "inspect_logic" }) {
            let observed = observation.evidence.contains(where: { $0.kind == .logicObserved })
            receipts.append(TutorConsentReceipt(
                modality: .readOnlyLogicAccessibility,
                granted: observed,
                purpose: observed
                    ? "Read currently visible Logic accessibility attributes only; no actions or setters exist in the observer."
                    : "Logic observation was requested but unavailable; no Logic state was changed."
            ))
        }
        return receipts
    }

    private func persistInterruptedMessage(
        id: UUID,
        text: String,
        status: TutorMessageStatus,
        context: TutorRuntimeContext
    ) {
        guard !text.isEmpty else { return }
        let interrupted = TutorConversationMessage(
            id: id,
            role: .assistant,
            text: text,
            status: status,
            evidence: evidenceReferences(context: context, toolResults: [])
        )
        if let index = state.messages.firstIndex(where: { $0.id == id }) {
            state.messages[index] = interrupted
        } else {
            state.messages.append(interrupted)
        }
        state.updatedAt = Date()
        try? persistState()
    }

    private func persistState() throws {
        state = try store.normalized(state)
        try store.save(state)
    }

    private func appendBounded(_ delta: String, to output: inout String) -> String {
        let marker = "\n\n[Response truncated at TrackSmith's local transcript limit.]"
        if output.hasSuffix(marker) { return "" }
        let available = max(0, Self.maximumMessageBytes - marker.utf8.count - output.utf8.count)
        var accepted = delta
        while accepted.utf8.count > available, !accepted.isEmpty { accepted.removeLast() }
        var emitted = accepted
        output += accepted
        if accepted.utf8.count < delta.utf8.count {
            output += marker
            emitted += marker
        }
        return emitted
    }

    private func functionOutputJSON(callID: String, output: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [
            "type": "function_call_output",
            "call_id": callID,
            "output": output,
        ], options: [.sortedKeys])
        guard data.count <= 128 * 1_024 else { throw TutorConversationError.responseTooLarge }
        return String(decoding: data, as: UTF8.self)
    }

    private func fallbackReason(_ error: Error) -> String {
        let detail = (error as? TutorConversationError)?.safeFailureDescription
            ?? "The cloud Tutor was unavailable."
        return "\(detail) Using the deterministic offline Tutor."
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct ProviderTurnResult: Sendable {
    var metadata: TutorProviderMetadata
    var toolResults: [TutorToolResult]
    var experimentIDs: [UUID]
}
