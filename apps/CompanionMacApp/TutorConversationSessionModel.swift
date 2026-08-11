import Foundation
import PlanSchema
import ProductionIntelligence
import SwiftUI
import TutorConversation
import TutorLogicObserver

@MainActor
final class TutorConversationSessionModel: ObservableObject {
    @Published private(set) var state = TutorConversationState()
    @Published var composer = ""
    @Published var projectGoal = ""
    @Published var attachCurrentCapture = true
    @Published var requestModelListening = false
    @Published var confirmEditedUpstreamOfTap = false
    @Published private(set) var streamingText = ""
    @Published private(set) var isStreaming = false
    @Published private(set) var activity = "Ready"
    @Published private(set) var fallbackNotice: String?
    @Published private(set) var logicStatus = "Show Me reads visible Logic controls only when you ask."

    private let engine: TutorConversationEngine?
    private let overlay = LogicCalloutOverlayController()
    private var turnTask: Task<Void, Never>?

    init() {
        do {
            engine = try TutorConversationEngine.live(observeLogic: { query in
                await MainActor.run {
                    LogicReadOnlyObserver().observe(query: query)
                }
            })
            activity = "Restoring Tutor history"
        } catch {
            engine = nil
            activity = "Tutor history is unavailable"
        }
        Task { [weak self] in await self?.restore() }
    }

    deinit { turnTask?.cancel() }

    func restore() async {
        guard let engine else { return }
        state = await engine.snapshot()
        projectGoal = state.projectGoal ?? ""
        activity = state.messages.isEmpty ? "Ready for a production question" : "Conversation restored locally"
    }

    func send(session: CompanionSessionModel) {
        guard !isStreaming, let engine else { return }
        let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composer = ""
        streamingText = ""
        fallbackNotice = nil
        isStreaming = true
        activity = "Preparing bounded context"
        let shouldAttach = attachCurrentCapture
        let shouldListen = requestModelListening
        requestModelListening = false

        turnTask = Task { [weak self, weak session] in
            guard let self, let session else { return }
            do {
                var capture = shouldAttach
                    ? try await session.tutorConversationCaptureSnapshot()
                    : nil
                var exactWAV: Data?
                if let current = capture {
                    do {
                        let bytes = try await session.tutorValidatedCaptureWAVData(
                            for: current, maximumBytes: 12 * 1_024 * 1_024
                        )
                        exactWAV = bytes
                        capture?.audioIntelligence = await LocalWaveformSpecialist().analyze(
                            wavData: bytes, capture: current
                        )
                    } catch {
                        // The snapshot remains useful for already-derived local metrics.
                        // No exact-waveform claim is added when the immutable bytes cannot load.
                    }
                }
                if shouldListen {
                    if !session.tutorCloudAudioConsent {
                        let snapshotID = capture?.captureSnapshotID
                        capture?.cloudListening = TutorCloudListeningEvidence(
                            status: .consentDenied,
                            summary: "Separate cloud-audio consent was off. No audio bytes were sent.",
                            captureSnapshotID: snapshotID
                        )
                    } else if let current = capture {
                        activity = "Sending the exact bounded WAV to the audio-listening model"
                        do {
                            let bytes: Data
                            if let exactWAV {
                                bytes = exactWAV
                            } else {
                                bytes = try await session.tutorValidatedCaptureWAVData(
                                    for: current, maximumBytes: 12 * 1_024 * 1_024
                                )
                            }
                            let listener = OpenAITutorAudioListener(configuration: .init(
                                modelIdentifier: session.tutorAudioModelIdentifier,
                                cloudAudioConsent: true,
                                maximumAudioBytes: 12 * 1_024 * 1_024
                            ))
                            capture?.cloudListening = try await listener.listen(
                                wavData: bytes,
                                capture: current,
                                musicianQuestion: text
                            )
                        } catch is CancellationError {
                            throw TutorConversationError.cancelled
                        } catch {
                            let reason = (error as? TutorConversationError)?.safeFailureDescription
                                ?? "The audio-listening provider was unavailable."
                            capture?.cloudListening = TutorCloudListeningEvidence(
                                status: .unavailable,
                                summary: "The optional audio-listening request did not complete. \(reason) No listening claim is authorized.",
                                captureSnapshotID: current.captureSnapshotID
                            )
                        }
                    }
                }

                let context = TutorRuntimeContext(
                    sourceType: session.sourceType,
                    projectGoal: projectGoal.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    capture: capture,
                    userReportedContext: state.experiments.suffix(6).compactMap { experiment in
                        guard let outcome = experiment.outcome else { return nil }
                        return "\(experiment.draft.title): \(outcome.rawValue)\(experiment.userNote.map { " — \($0)" } ?? "")"
                    },
                    consent: TutorConsentContext(
                        cloudTextGranted: session.tutorCloudTextConsent,
                        cloudAudioGranted: session.tutorCloudAudioConsent,
                        audioRequested: shouldListen
                    )
                )
                let provider = OpenAITutorProvider(configuration: TutorProviderConfiguration(
                    modelIdentifier: session.tutorModelIdentifier,
                    reasoningEffort: session.tutorReasoningEffort,
                    cloudTextConsent: session.tutorCloudTextConsent
                ))
                activity = "Tutor is responding"
                let stream = try await engine.streamTurn(text: text, context: context, provider: provider)
                for try await event in stream {
                    if Task.isCancelled { throw TutorConversationError.cancelled }
                    switch event {
                    case let .textDelta(_, delta):
                        streamingText += delta
                    case let .toolActivity(name):
                        activity = Self.toolActivity(name)
                    case let .experiment(record):
                        state.experiments.append(record)
                        activity = "Prepared one reversible experiment"
                    case let .fallbackActivated(reason):
                        fallbackNotice = reason
                        activity = "Using deterministic offline fallback"
                    case .completed:
                        state = await engine.snapshot()
                        streamingText = ""
                        activity = "Ready for what you heard next"
                    case .cancelled:
                        activity = "Response cancelled"
                    }
                }
            } catch let error as TutorConversationError where error == .cancelled {
                state = await engine.snapshot()
                activity = "Response cancelled"
            } catch {
                state = await engine.snapshot()
                activity = "Tutor response failed safely; no Logic or Audio Unit state changed"
            }
            isStreaming = false
            turnTask = nil
        }
    }

    func cancel() {
        turnTask?.cancel()
        activity = "Cancelling response"
    }

    func startNewConversation() {
        guard !isStreaming, let engine else { return }
        overlay.dismiss()
        Task {
            do {
                state = try await engine.startNewConversation(
                    projectGoal: projectGoal.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                confirmEditedUpstreamOfTap = false
                activity = "New local Tutor conversation"
            } catch {
                activity = "A new conversation could not be created"
            }
        }
    }

    func deleteAllHistory() {
        guard !isStreaming, let engine else { return }
        overlay.dismiss()
        Task {
            do {
                try await engine.deleteAllHistory()
                state = await engine.snapshot()
                projectGoal = ""
                confirmEditedUpstreamOfTap = false
                activity = "Tutor transcript, experiments, and receipts deleted locally"
            } catch {
                activity = "Tutor history could not be deleted"
            }
        }
    }

    func submitOutcome(
        experiment: TutorExperimentRecord,
        outcome: TutorExperimentOutcome,
        session: CompanionSessionModel
    ) {
        guard !isStreaming, let engine else { return }
        Task {
            do {
                let followUp = try await session.tutorConversationCaptureSnapshot()
                _ = try await engine.recordOutcome(
                    experimentID: experiment.id,
                    outcome: outcome,
                    followUpCapture: followUp,
                    userConfirmedUpstreamAndObservable: confirmEditedUpstreamOfTap
                )
                state = await engine.snapshot()
                // A confirmation never carries into the automatic follow-up or another experiment.
                confirmEditedUpstreamOfTap = false
                composer = Self.feedbackText(outcome)
                send(session: session)
            } catch {
                activity = "That outcome could not be attached to the experiment"
            }
        }
    }

    func showMe(_ experiment: TutorExperimentRecord) {
        let query = experiment.draft.visualTargetQuery ?? experiment.draft.logicLocation
        let observation = LogicReadOnlyObserver().observe(query: query)
        switch observation.status {
        case .observed:
            guard let target = observation.controls.first(where: { $0.frame != nil }) else {
                logicStatus = "Logic exposed a matching label but not a usable frame. Follow the written location."
                return
            }
            logicStatus = overlay.show(control: target, message: experiment.draft.title)
                ? "Showing a mouse-transparent callout on a currently visible Logic control. No control was pressed or changed."
                : "The matching control was observed, but its display frame could not be mapped safely."
        case .permissionDenied:
            logicStatus = "Accessibility access is off. Use Grant Accessibility only if you want read-only visible-control guidance."
        case .logicNotRunning:
            logicStatus = "Logic Pro is not running. The written directions remain available."
        case .controlNotFound:
            logicStatus = "No visible semantic match was found. Hidden plug-in controls may not be exposed; use the written location."
        case .unavailable:
            logicStatus = observation.limitation
        }
    }

    func requestAccessibilityAccess() {
        let trusted = LogicReadOnlyObserver().requestAccessibilityPermission()
        logicStatus = trusted
            ? "Accessibility access is available for read-only Logic observation."
            : "macOS has not granted Accessibility access. TrackSmith will continue with written directions."
    }

    func dismissCallout() {
        overlay.dismiss()
        logicStatus = "Logic callout dismissed."
    }

    private static func toolActivity(_ name: String) -> String {
        switch name {
        case "get_current_capture_context": "Reading capture identity and local measurements"
        case "search_production_knowledge": "Searching reviewed production knowledge"
        case "get_logic_procedure": "Retrieving a reviewed Logic procedure"
        case "retrieve_prior_experiments": "Reviewing your prior outcomes"
        case "inspect_logic": "Reading visible Logic controls without changing them"
        case "present_experiment": "Formatting one reversible experiment"
        default: "Using a bounded read-only Tutor tool"
        }
    }

    private static func feedbackText(_ outcome: TutorExperimentOutcome) -> String {
        switch outcome {
        case .better: "That sounded better. What should I listen for now, and why did that help?"
        case .worse: "That sounded worse. Help me undo the downside and choose a different one-step experiment."
        case .noChange: "I heard no meaningful change. What does that rule out, and what should I try next?"
        case .cannotFind: "I couldn't find that control in Logic. Give me an exact path or a simpler alternative."
        case .notSure: "I'm not sure what changed. Help me make the next comparison smaller and clearer."
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
