import CryptoKit
import Foundation
import ProductionIntelligence

public struct TutorAudioListeningConfiguration: Codable, Equatable, Sendable {
    public var modelIdentifier: String
    public var cloudAudioConsent: Bool
    public var timeoutSeconds: Double
    public var maximumAudioBytes: Int

    public init(
        modelIdentifier: String = "gpt-audio-1.5",
        cloudAudioConsent: Bool = false,
        timeoutSeconds: Double = 45,
        maximumAudioBytes: Int = 12 * 1_024 * 1_024
    ) {
        self.modelIdentifier = modelIdentifier
        self.cloudAudioConsent = cloudAudioConsent
        self.timeoutSeconds = min(max(timeoutSeconds, 1), 60)
        self.maximumAudioBytes = min(max(maximumAudioBytes, 1_024), 24 * 1_024 * 1_024)
    }
}

/// Optional bounded audio-listening route. It is intentionally separate from
/// the reasoning provider because the strongest text model may not accept
/// audio. The result is an observation supplied to the Tutor, never a DSP plan.
public struct OpenAITutorAudioListener: Sendable {
    public static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    public let configuration: TutorAudioListeningConfiguration
    public let credentialStore: any ProviderCredentialStore
    public let transport: any ProviderHTTPTransport

    public init(
        configuration: TutorAudioListeningConfiguration = .init(),
        credentialStore: any ProviderCredentialStore = KeychainProviderCredentialStore(),
        transport: any ProviderHTTPTransport = URLSessionProviderHTTPTransport()
    ) {
        self.configuration = configuration
        self.credentialStore = credentialStore
        self.transport = transport
    }

    public func listen(
        wavData: Data,
        capture: TutorCaptureSnapshot,
        musicianQuestion: String
    ) async throws -> TutorCloudListeningEvidence {
        let intelligence = try await listenIntelligence(
            wavData: wavData, capture: capture, musicianQuestion: musicianQuestion
        )
        guard let observation = intelligence.observations.first,
              intelligence.failure == nil else {
            throw TutorConversationError.malformedProviderResponse("Audio listening returned no bounded observation.")
        }
        return TutorCloudListeningEvidence(
            status: .listened,
            summary: observation.detail,
            providerIdentifier: intelligence.providerIdentifier,
            modelIdentifier: intelligence.modelIdentifier,
            captureSnapshotID: capture.captureSnapshotID
        )
    }

    /// Shared evidence result for the optional remote route. Calibration is
    /// explicitly false because the local lab does not test this provider.
    public func listenIntelligence(
        wavData: Data,
        capture: TutorCaptureSnapshot,
        musicianQuestion: String
    ) async throws -> TutorAudioIntelligenceResult {
        let started = ContinuousClock.now
        guard configuration.cloudAudioConsent else {
            throw TutorConversationError.audioConsentRequired
        }
        guard capture.isLive else { throw TutorConversationError.staleCapture }
        guard !wavData.isEmpty, wavData.count <= configuration.maximumAudioBytes else {
            throw TutorConversationError.audioAttachmentTooLarge
        }
        let digest = SHA256.hash(data: wavData).map { String(format: "%02x", $0) }.joined()
        guard digest == capture.sha256 else { throw TutorConversationError.staleCapture }
        guard validModelIdentifier(configuration.modelIdentifier) else {
            throw TutorConversationError.invalidModel
        }
        let credential: String
        do {
            guard let value = try credentialStore.credential(for: .openAI) else {
                throw TutorConversationError.credentialMissing
            }
            credential = value
        } catch let error as TutorConversationError {
            throw error
        } catch {
            throw TutorConversationError.credentialUnavailable
        }

        let question = bounded(musicianQuestion, maximumBytes: 4_096)
        let body: [String: Any] = [
            "model": configuration.modelIdentifier,
            "modalities": ["text"],
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are the bounded music-audio listening component for TrackSmith Tutor. Listen to the supplied excerpt as music-production audio, not merely speech. Return concise observable acoustic impressions relevant to the musician's question. Distinguish what is audible from possible causes. Do not claim access to tracks, inserts, project state, settings, or audio outside this excerpt. Do not prescribe or perform processing. Mention uncertainty and the excerpt scope. Never provide hidden reasoning.
                    """,
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Musician question: \(question)\nCapture scope: \(capture.scopeDescription)\nSource label: \(capture.sourceType.rawValue)\nDuration: \(String(format: "%.2f", capture.durationSeconds)) seconds",
                        ],
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": wavData.base64EncodedString(),
                                "format": "wav",
                            ],
                        ],
                    ],
                ],
            ],
            "max_completion_tokens": 1_200,
            "store": false,
        ]
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        guard data.count <= configuration.maximumAudioBytes * 2 + 256 * 1_024 else {
            throw TutorConversationError.audioAttachmentTooLarge
        }
        let response: ProviderHTTPResponse
        do {
            response = try await transport.send(ProviderHTTPRequest(
                url: Self.endpoint,
                method: "POST",
                headers: [
                    "Authorization": "Bearer \(credential)",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "User-Agent": "TrackSmith-Tutor-Audio/1.0",
                ],
                body: data,
                timeoutSeconds: configuration.timeoutSeconds
            ))
        } catch is CancellationError {
            throw TutorConversationError.cancelled
        } catch let error as URLError where error.code == .timedOut {
            throw TutorConversationError.timedOut
        }
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw TutorConversationError.providerRejected("The OpenAI credential was rejected.")
            }
            throw TutorConversationError.providerRejected("Audio listening provider HTTP \(response.statusCode).")
        }
        guard response.body.count <= 1_024 * 1_024,
              let object = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let summary = extractText(message["content"]),
              !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TutorConversationError.malformedProviderResponse("Audio listening returned no bounded text observation.")
        }
        return TutorAudioIntelligenceResult(
            capture: TutorAudioCaptureIdentity(capture),
            providerIdentifier: "openai-chat-completions-audio-v1",
            modelIdentifier: (object["model"] as? String) ?? configuration.modelIdentifier,
            receivedOriginalWaveformBytes: true,
            waveformBindingStatus: .captureBoundExactWAV,
            sourceProvenance: "Exact hash-validated WAV bytes were included in this completed provider request.",
            capabilities: TutorAudioTask.allCases.map {
                TutorAudioTaskCapability(task: $0, calibrated: false, detail: "Not calibrated by the deterministic local lab.")
            },
            observations: [TutorAudioObservation(
                identifier: "bounded_model_observation",
                evidence: .modelHeardWaveform,
                detail: bounded(summary, maximumBytes: 8_192)
            )],
            limitations: ["A completed remote response is a bounded excerpt observation only; it does not expose tracks, inserts, or whole-mix causality."],
            runtimeMilliseconds: elapsed(started),
            deadlineSeconds: configuration.timeoutSeconds
        )
    }

    private func elapsed(_ started: ContinuousClock.Instant) -> Int {
        let components = (ContinuousClock.now - started).components
        return max(0, Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000))
    }

    private func extractText(_ content: Any?) -> String? {
        if let content = content as? String { return content }
        if let parts = content as? [[String: Any]] {
            return parts.compactMap { part in
                if let text = part["text"] as? String { return text }
                return nil
            }.joined()
        }
        return nil
    }

    private func validModelIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
            && value.allSatisfy { $0.isLetter || $0.isNumber || ".-_".contains($0) }
    }

    private func bounded(_ input: String, maximumBytes: Int) -> String {
        var output = String(input.unicodeScalars.filter { $0.value >= 32 || $0.value == 9 || $0.value == 10 })
        while output.utf8.count > maximumBytes, !output.isEmpty { output.removeLast() }
        return output
    }
}
