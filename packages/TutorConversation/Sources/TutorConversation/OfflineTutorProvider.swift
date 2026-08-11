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
                    if let lesson = Self.issueLesson(for: latest.text) {
                        if request.continuations.isEmpty {
                            continuation.yield(.completed(
                                metadata: TutorProviderMetadata(
                                    providerIdentifier: providerIdentifier,
                                    modelIdentifier: "deterministic-issue-tutor-v1"
                                ),
                                output: [.functionCall(try Self.experimentCall(for: lesson))]
                            ))
                            continuation.finish()
                            return
                        }
                        let text = Self.render(lesson, captureAvailable: request.context.capture != nil)
                        for chunk in Self.chunks(text, approximateCharacters: 36) {
                            if Task.isCancelled { throw TutorConversationError.cancelled }
                            continuation.yield(.textDelta(chunk))
                        }
                        continuation.yield(.completed(
                            metadata: TutorProviderMetadata(
                                providerIdentifier: providerIdentifier,
                                modelIdentifier: "deterministic-issue-tutor-v1"
                            ),
                            output: [.text(text)]
                        ))
                        continuation.finish()
                        return
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

    private static func render(_ lesson: IssueLesson, captureAvailable: Bool) -> String {
        let grounding = captureAvailable
            ? "Offline fallback used the user's description and reviewed local knowledge. A capture and descriptive measurements are attached, but this fallback did not listen to the WAV; measurements alone do not prove the diagnosis."
            : "Offline fallback used the user's description and reviewed local knowledge. No audio was heard and Logic was not observed."
        return [
            lesson.directAnswer,
            "One controlled test: \(lesson.action)",
            "Listen for: \(lesson.listenFor)",
            "Watch for: \(lesson.risk)",
            "Undo: \(lesson.undo)",
            "Why this test: \(lesson.why)",
            grounding,
        ].joined(separator: "\n\n")
    }

    private static func experimentCall(for lesson: IssueLesson) throws -> TutorToolCall {
        let arguments: [String: Any] = [
            "title": lesson.title,
            "logic_location": lesson.logicLocation,
            "action": lesson.action,
            "starting_range": lesson.startingRange,
            "listen_for": lesson.listenFor,
            "why": lesson.why,
            "risk": lesson.risk,
            "undo": lesson.undo,
            "visual_target_query": lesson.visualTargetQuery,
        ]
        let data = try JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys])
        return TutorToolCall(
            callID: "offline-present-experiment",
            name: "present_experiment",
            argumentsJSON: String(decoding: data, as: UTF8.self)
        )
    }

    private static func issueLesson(for request: String) -> IssueLesson? {
        let text = request.lowercased()
        if text.contains("muddy") || text.contains("mud") || text.contains("low-mid") || text.contains("low mid") {
            return IssueLesson(
                title: "Test vocal low-mid masking in context",
                logicLocation: "Logic Pro > vocal channel strip > user-added Channel EQ",
                action: "Loop the problem phrase in the full mix. Add or use a user-controlled Channel EQ and A/B one broad 1–2 dB cut around 250–400 Hz; level-match by ear and change nothing else.",
                startingRange: "Broad bell, about -1 to -2 dB around 250–400 Hz",
                listenFor: "Do the words separate from the mix while the vocal keeps chest and weight? Compare bypassed versus engaged at equal apparent loudness.",
                why: "“Muddy” often points to low-mid masking, but the source, arrangement, or another track may be responsible. One small in-context A/B tests that hypothesis without committing processing.",
                risk: "Stop if the vocal gets papery, smaller, or detached; that means the cut is too deep, too wide, or aimed at the wrong source.",
                undo: "Bypass or reset only the user-added EQ band.",
                visualTargetQuery: "Channel EQ"
            )
        }
        if text.contains("thin") || text.contains("small") || text.contains("no body") {
            return IssueLesson(
                title: "Test whether processing removed vocal body",
                logicLocation: "Logic Pro > vocal channel strip > user-added EQ or filter",
                action: "Loop the phrase in context and bypass the most recent low-cut or low-mid cut. If body returns, restore the cut and reduce its depth or lower the high-pass cutoff before adding anything new.",
                startingRange: "Compare bypass first; then reduce the existing cut by roughly half",
                listenFor: "Does the vocal regain natural chest and scale without bringing back rumble or clouding the mix?",
                why: "A thin result is often easier to diagnose by removing a prior subtraction than by stacking a new boost.",
                risk: "Stop if plosives, room rumble, or low-mid masking return before the vocal regains useful body.",
                undo: "Restore the prior bypass state and original user settings.",
                visualTargetQuery: "Channel EQ"
            )
        }
        if text.contains("harsh") || text.contains("sibil") || text.contains("ess") {
            return IssueLesson(
                title: "Separate harshness from sibilance",
                logicLocation: "Logic Pro > vocal channel strip > user-added Channel EQ",
                action: "Loop the worst phrase and use one temporary narrow EQ band to audition 2.5–5 kHz for harsh vowels, then 5–9 kHz for sibilants. Remove the audition boost and try a 1–2 dB cut only in the range that actually matches the irritation.",
                startingRange: "Temporary narrow audition; final cut about -1 to -2 dB",
                listenFor: "Does the painful edge recede while consonants, diction, and forward energy remain?",
                why: "Harsh vowels and sibilants occupy different regions and often need different treatment; the audition prevents a blind broad cut.",
                risk: "Stop if the vocal lisps, darkens, or loses intelligibility.",
                undo: "Reset the temporary audition/final band or bypass the user-added EQ.",
                visualTargetQuery: "Channel EQ"
            )
        }
        return nil
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

private struct IssueLesson: Sendable {
    var title: String
    var logicLocation: String
    var action: String
    var startingRange: String
    var listenFor: String
    var why: String
    var risk: String
    var undo: String
    var visualTargetQuery: String

    var directAnswer: String {
        switch title {
        case let value where value.contains("low-mid"):
            "Treat “muddy” as a low-mid masking hypothesis, not a diagnosis. Test one small reversible move in the full mix before changing the vocal chain broadly."
        case let value where value.contains("body"):
            "Treat “thin” as a possible over-subtraction problem first. A bypass comparison is more informative than immediately adding a new boost."
        default:
            "First identify whether the irritation is harsh vowel energy or sibilance; they should not be treated as the same problem."
        }
    }
}
