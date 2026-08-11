import Foundation
import ProductionTutor

/// Fully local fallback that reuses the validated deterministic General Tutor.
/// It deliberately exposes its limitations: it does not pretend to listen,
/// inspect Logic, or preserve frontier-model conversational reasoning.
public struct OfflineTutorProvider: TutorConversationProvider, Sendable {
    public let providerIdentifier = "tracksmith-offline-tutor-v1"
    private let coordinator: GeneralTutorCoordinator

    public init(coordinator: GeneralTutorCoordinator) {
        self.coordinator = coordinator
    }

    public init() throws {
        self.coordinator = try GeneralTutorCoordinator()
    }

    public func stream(_ request: TutorProviderRequest) -> AsyncThrowingStream<TutorProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let latest = request.messages.last(where: { $0.role == .user }) else {
                        throw TutorConversationError.emptyMessage
                    }
                    let context = GeneralTutorUserContext(
                        sourceRole: request.context.sourceType.rawValue,
                        problemLocation: request.context.capture?.scopeDescription,
                        preservationPriorities: request.context.userReportedContext
                    )
                    let outcome = try coordinator.answer(GeneralTutorRequest(
                        question: latest.text,
                        sourceType: request.context.sourceType,
                        context: context,
                        analysis: nil,
                        explanationDepth: .simple
                    ))
                    let text = Self.render(outcome.answer, captureAvailable: request.context.capture != nil)
                    for chunk in Self.chunks(text, approximateCharacters: 36) {
                        if Task.isCancelled { throw TutorConversationError.cancelled }
                        continuation.yield(.textDelta(chunk))
                    }
                    continuation.yield(.completed(
                        metadata: TutorProviderMetadata(
                            providerIdentifier: providerIdentifier,
                            modelIdentifier: "deterministic-general-tutor-v2"
                        ),
                        output: [.text(text)]
                    ))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: TutorConversationError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func render(
        _ answer: GeneralTutorAnswerContract,
        captureAvailable: Bool
    ) -> String {
        var paragraphs: [String] = []
        paragraphs.append(answer.directAnswer)
        if let question = answer.clarificationQuestion { paragraphs.append(question) }
        if let move = answer.recommendedFirstMove {
            paragraphs.append("One controlled test: \(move)")
        } else if let strategy = answer.strategyOptions.first {
            paragraphs.append("One controlled test: \(strategy.simplestTest)")
        }
        if let listen = answer.whatToListenFor.first {
            paragraphs.append("Listen for: \(listen)")
        }
        if let risk = answer.risksAndSideEffects.first {
            paragraphs.append("Watch for: \(risk)")
        }
        if let stop = answer.stopConditions.first {
            paragraphs.append("Stop when: \(stop)")
        }
        if let principle = answer.teachingPrinciple {
            paragraphs.append("Why this matters: \(principle)")
        }
        let grounding = captureAvailable
            ? "Offline fallback used the user's text and reviewed local knowledge. A capture exists, but this fallback did not listen to it and did not use its measurements to author this answer."
            : "Offline fallback used the user's text and reviewed local knowledge. No audio was heard and Logic was not observed."
        paragraphs.append(grounding)
        return paragraphs.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static func chunks(_ text: String, approximateCharacters: Int) -> [String] {
        guard text.count > approximateCharacters else { return [text] }
        var output: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let tentative = text.index(start, offsetBy: approximateCharacters, limitedBy: text.endIndex)
                ?? text.endIndex
            var end = tentative
            if tentative < text.endIndex,
               let boundary = text[start..<tentative].lastIndex(where: { $0.isWhitespace }) {
                end = text.index(after: boundary)
            }
            guard end > start else { break }
            output.append(String(text[start..<end]))
            start = end
        }
        return output
    }
}
