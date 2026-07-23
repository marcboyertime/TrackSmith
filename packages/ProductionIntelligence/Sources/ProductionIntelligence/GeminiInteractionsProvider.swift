import AgentCore
import CryptoKit
import Foundation

public struct GeminiProviderConfiguration: Codable, Equatable, Sendable {
    public var modelIdentifier: String
    public var cloudReasoningConsent: Bool
    public var automaticRetryEnabled: Bool
    public var maximumAttempts: Int

    public init(
        modelIdentifier: String = "gemini-3.6-flash",
        cloudReasoningConsent: Bool = false,
        automaticRetryEnabled: Bool = false,
        maximumAttempts: Int = 1
    ) {
        self.modelIdentifier = modelIdentifier
        self.cloudReasoningConsent = cloudReasoningConsent
        self.automaticRetryEnabled = automaticRetryEnabled
        self.maximumAttempts = min(max(maximumAttempts, 1), 2)
    }
}

/// Second production adapter using Google's current Interactions API. It is
/// stateless (`store=false`), tool-free, text-only, and shares the exact same
/// TrackSmith contract and downstream validator as every other provider.
public struct GeminiInteractionsProvider: ModelProvider, Sendable {
    public static let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1/interactions")!

    public let configuration: GeminiProviderConfiguration
    public let credentialStore: any ProviderCredentialStore
    public let transport: any ProviderHTTPTransport
    public let replayGuard: ProviderResponseReplayGuard

    public var descriptor: ModelProviderDescriptor {
        ModelProviderDescriptor(
            identifier: "gemini-interactions-v1",
            displayName: "Google Gemini",
            kind: .gemini,
            modelIdentifier: configuration.modelIdentifier,
            capabilities: [
                .semanticIntentInterpretation,
                .ambiguityDetection,
                .conversationalReferenceInterpretation,
                .productionHypothesisGeneration,
                .explanationGeneration,
            ],
            usesNetwork: true,
            acceptsRawAudio: false
        )
    }

    public init(
        configuration: GeminiProviderConfiguration = .init(),
        credentialStore: any ProviderCredentialStore = KeychainProviderCredentialStore(),
        transport: any ProviderHTTPTransport = URLSessionProviderHTTPTransport(),
        replayGuard: ProviderResponseReplayGuard = .shared
    ) {
        self.configuration = configuration
        self.credentialStore = credentialStore
        self.transport = transport
        self.replayGuard = replayGuard
    }

    public func interpret(_ request: ModelInterpretationRequest) async throws -> ModelInterpretationResponse {
        guard configuration.cloudReasoningConsent else { throw ModelProviderFailure.consentRequired }
        guard configuration.modelIdentifier.utf8.count <= 128,
              !configuration.modelIdentifier.isEmpty,
              configuration.modelIdentifier.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
            throw ModelProviderFailure.unavailable
        }
        let credential: String
        do {
            guard let storedCredential = try credentialStore.credential(for: .gemini) else {
                throw ModelProviderFailure.credentialMissing
            }
            credential = storedCredential
        } catch let failure as ModelProviderFailure {
            throw failure
        } catch {
            throw ModelProviderFailure.credentialStoreUnavailable
        }
        if Task.isCancelled { throw ModelProviderFailure.cancelled }
        let body = try requestBody(for: request)
        let maximumAttempts = configuration.automaticRetryEnabled
            ? min(configuration.maximumAttempts, request.budget.maxAttempts, 2)
            : 1
        let start = ContinuousClock.now
        var attempt = 0
        while attempt < maximumAttempts {
            attempt += 1
            do {
                let response = try await ProviderTransportDeadline.send(using: transport, request: .init(
                    url: Self.endpoint,
                    method: "POST",
                    headers: [
                        "x-goog-api-key": credential,
                        "Content-Type": "application/json",
                        "Accept": "application/json",
                        "User-Agent": "TrackSmith-ProductionIntelligence/1.0",
                    ],
                    body: body,
                    timeoutSeconds: min(max(request.budget.timeoutSeconds, 1), 60)
                ))
                if shouldRetry(response), attempt < maximumAttempts {
                    try await boundedRetryDelay(response: response, attempt: attempt)
                    continue
                }
                let decoded = try decode(response, request: request, attemptCount: attempt, start: start)
                if let responseID = decoded.metadata.providerResponseID {
                    try await replayGuard.register(
                        providerIdentifier: descriptor.identifier,
                        responseIdentifier: responseID
                    )
                }
                return decoded
            } catch is CancellationError {
                throw ModelProviderFailure.cancelled
            } catch let failure as ModelProviderFailure {
                throw failure
            } catch let error as URLError {
                if error.code == .cancelled { throw ModelProviderFailure.cancelled }
                if error.code == .timedOut { throw ModelProviderFailure.timedOut }
                throw ModelProviderFailure.network(sanitized(error.localizedDescription))
            } catch {
                throw ModelProviderFailure.network(sanitized(String(describing: error)))
            }
        }
        throw ModelProviderFailure.unavailable
    }

    private func requestBody(for request: ModelInterpretationRequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var authorityReferences = request.references
        authorityReferences.catalog = []
        let inputData = try encoder.encode(TrackSmithProviderInput(
            userRequest: request.userRequest,
            sourceType: request.scope.sourceType,
            channelFormat: request.scope.channelFormat,
            scopeKind: request.scope.kind,
            context: request.context,
            availableReferences: authorityReferences
        ))
        guard inputData.count <= request.budget.maxContextUTF8Bytes + 16_384 else {
            throw ModelProviderFailure.responseTooLarge
        }
        let body: [String: Any] = [
            "model": configuration.modelIdentifier,
            "system_instruction": OpenAIResponsesProvider.trackSmithSystemInstructions,
            "input": String(decoding: inputData, as: UTF8.self),
            "response_format": [
                "type": "text",
                "mime_type": "application/json",
                "schema": OpenAIResponsesProvider.trackSmithIntentSchema(),
            ],
            "generation_config": [
                "max_output_tokens": min(max(request.budget.maxOutputTokens, 16), 8_192),
                // TrackSmith asks Gemini to perform a bounded semantic
                // classification, not to invent or execute the production
                // plan. Google's current guidance recommends minimal/low
                // thinking for classification-style work; the deterministic
                // hypothesis and DSP layers remain authoritative downstream.
                "thinking_level": "low",
                "thinking_summaries": "none",
                "tool_choice": "none",
            ],
            "store": false,
            "background": false,
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private func decode(
        _ response: ProviderHTTPResponse,
        request: ModelInterpretationRequest,
        attemptCount: Int,
        start: ContinuousClock.Instant
    ) throws -> ModelInterpretationResponse {
        guard response.body.count <= ModelOutputValidator.maximumResponseBytes else {
            throw ModelProviderFailure.responseTooLarge
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw ModelProviderFailure.credentialRejected
        }
        if response.statusCode == 429 {
            throw ModelProviderFailure.rateLimited(retryAfterSeconds: retryAfter(response))
        }
        guard (200...299).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: response.body))?.error.message
            throw ModelProviderFailure.providerRejected(sanitized(message ?? "Provider HTTP \(response.statusCode)"))
        }
        let envelope: GeminiInteractionEnvelope
        do { envelope = try JSONDecoder().decode(GeminiInteractionEnvelope.self, from: response.body) }
        catch { throw ModelProviderFailure.malformedResponse("The Interactions API envelope could not be decoded.") }
        switch envelope.status {
        case "completed": break
        case "cancelled": throw ModelProviderFailure.cancelled
        case "incomplete", "budget_exceeded":
            throw ModelProviderFailure.providerRejected("The provider exhausted its bounded output budget.")
        default:
            throw ModelProviderFailure.providerRejected("The provider did not complete the interaction.")
        }
        guard let text = envelope.steps
            .filter({ $0.type == "model_output" })
            .flatMap({ $0.content ?? [] })
            .first(where: { $0.type == "text" })?.text,
              let data = text.data(using: .utf8),
              data.count <= ModelOutputValidator.maximumResponseBytes else {
            throw ModelProviderFailure.malformedResponse("The interaction contained no bounded structured model output.")
        }
        let contract: ModelIntentContract
        do { contract = try JSONDecoder().decode(ModelIntentContract.self, from: data) }
        catch { throw ModelProviderFailure.malformedResponse("The structured intent did not decode as TrackSmith contract v1.") }
        let elapsed = start.duration(to: .now)
        let milliseconds = Int(elapsed.components.seconds * 1_000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        // Stateless (`store:false`) Gemini responses may omit a retrievable
        // interaction ID. Preserve replay protection without retaining the
        // envelope by deriving a stable, non-reversible local body fingerprint.
        let responseIdentifier = [envelope.id, envelope.interactionID]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty })
            ?? "local-body-sha256:\(SHA256.hash(data: response.body).map { String(format: "%02x", $0) }.joined())"
        return ModelInterpretationResponse(
            requestID: request.requestID,
            authority: request.authority,
            contract: contract,
            metadata: .init(
                providerIdentifier: descriptor.identifier,
                modelIdentifier: configuration.modelIdentifier,
                providerReportedModelIdentifier: envelope.model,
                providerResponseID: responseIdentifier,
                attemptCount: attemptCount,
                latencyMilliseconds: max(0, milliseconds),
                inputTokens: envelope.usage?.totalInputTokens,
                outputTokens: envelope.usage?.totalOutputTokens,
                retainedByProvider: nil
            )
        )
    }

    private func shouldRetry(_ response: ProviderHTTPResponse) -> Bool {
        response.statusCode == 429 || (500...599).contains(response.statusCode)
    }

    private func boundedRetryDelay(response: ProviderHTTPResponse, attempt: Int) async throws {
        let server = retryAfter(response) ?? 0
        let exponential = min(2.0, 0.25 * pow(2, Double(attempt - 1)))
        try await Task.sleep(for: .milliseconds(Int(min(2, max(server, exponential)) * 1_000)))
    }

    private func retryAfter(_ response: ProviderHTTPResponse) -> Double? {
        guard let raw = response.headers["retry-after"], let value = Double(raw), value >= 0 else { return nil }
        return min(value, 2)
    }

    private func sanitized(_ text: String) -> String {
        let value = text.unicodeScalars.filter { $0.value >= 32 || $0.value == 9 || $0.value == 10 }
        var result = String(String.UnicodeScalarView(value))
        while result.utf8.count > 512, !result.isEmpty { result.removeLast() }
        return result
    }
}

private struct GeminiErrorEnvelope: Decodable {
    struct ProviderError: Decodable { var message: String }
    var error: ProviderError
}

private struct GeminiInteractionEnvelope: Decodable {
    struct Usage: Decodable {
        var totalInputTokens: Int?
        var totalOutputTokens: Int?
        enum CodingKeys: String, CodingKey {
            case totalInputTokens = "total_input_tokens"
            case totalOutputTokens = "total_output_tokens"
        }
    }
    struct Step: Decodable {
        struct Content: Decodable {
            var type: String
            var text: String?
        }
        var type: String
        var content: [Content]?
    }
    var id: String?
    var interactionID: String?
    var status: String
    var model: String?
    var usage: Usage?
    var steps: [Step]

    enum CodingKeys: String, CodingKey {
        case id, status, model, usage, steps
        case interactionID = "interaction_id"
    }
}
