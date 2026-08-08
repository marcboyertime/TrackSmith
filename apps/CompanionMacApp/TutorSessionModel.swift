import AudioAnalysis
import Foundation
import PlanSchema
import ProductionTutor
import SwiftUI

/// Companion-side coordinator for Guide Me lessons. Owns the tutor request,
/// lesson state, feedback handling, and tutor persistence. It has no access to
/// the AU command path: tutor mode can never mutate the processing graph.
@MainActor
final class TutorSessionModel: ObservableObject {
    @Published var requestText = "I sound nasal. Tell me exactly what to try, step by step, and explain why."
    @Published var lesson: TutorLessonState?
    @Published var explanationDepth: TutorExplanationDepth = .simple
    @Published var chainStatus: TutorUserReportedChain.Status = .unknown
    @Published var chainProcessors: Set<TutorReportedProcessor> = []
    @Published var statusMessage = "Describe the problem or the sound you want, then start a lesson."
    @Published var restoredNote = ""
    @Published var engineUnavailableReason: String?

    /// The open-domain answer for the current question, when one has been
    /// asked. Independent of `lesson`: an answer may exist with no lesson, and
    /// a lesson may be started from an answer's strategy option.
    @Published var generalOutcome: GeneralTutorOutcome?
    @Published var isAnswering = false

    /// What TrackSmith has been explicitly told or explicitly asked to
    /// remember. Local only, never uploaded, never general truth.
    @Published var profile: TutorPersonalProfile = .empty
    @Published var memoryNote = ""

    /// Research This is specified but not built. The control exists so the
    /// product does not silently pretend the path is unavailable for a
    /// different reason.
    let researchAvailable = false

    let formatter = TutorExplanationFormatter()

    private var planner: TutorPlanner?
    private var reducer: TutorFeedbackReducer?
    private var general: GeneralTutorCoordinator?
    private var profileStore: PersonalProfileStore?
    private var store: TutorSessionStore?
    private var persistedRecord: TutorSessionRecord?

    private static let activeSessionKey = "TrackSmith.ActiveTutorSessionID"

    init() {
        do {
            let planner = try TutorPlanner()
            self.planner = planner
            reducer = TutorFeedbackReducer(planner: planner)
            profileStore = try? PersonalProfileStore()
            profile = (try? profileStore?.load()) ?? .empty
            general = try GeneralTutorCoordinator(profile: profile)
        } catch {
            engineUnavailableReason = "The tutor knowledge catalog failed validation and Guide Me is disabled: \(error)"
        }
        store = try? TutorSessionStore()
        restoreLastSession()
    }

    // MARK: - Open-ended questions

    /// Answers any production question. This is the default entry point: the
    /// user is never required to phrase a problem so it matches a bounded
    /// issue vocabulary.
    func ask(sourceType: SourceType, analysis: SourceAwareAnalysisReport?) {
        guard let general else { return }
        let question = requestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            statusMessage = "Type a question first."
            return
        }
        isAnswering = true
        defer { isAnswering = false }
        do {
            let outcome = try general.answer(GeneralTutorRequest(
                question: question,
                sourceType: sourceType,
                context: GeneralTutorUserContext(
                    existingProcessors: chainProcessors.sorted { $0.rawValue < $1.rawValue },
                    processorsReported: chainStatus != .unknown
                ),
                analysis: analysis,
                explanationDepth: explanationDepth
            ))
            generalOutcome = outcome
            // A new question supersedes any previous answer's lesson.
            lesson = nil
            restoredNote = ""
            statusMessage = statusLine(for: outcome.answer)
        } catch {
            generalOutcome = nil
            statusMessage = "TrackSmith could not produce a validated answer: \(error)"
        }
    }

    private func statusLine(for answer: GeneralTutorAnswerContract) -> String {
        switch answer.answerMode {
        case .groundedAnswer:
            let sources = answer.sourceIDs.count
            return "Answer grounded in \(answer.knowledgeClaimIDs.count) reviewed claim\(answer.knowledgeClaimIDs.count == 1 ? "" : "s") across \(sources) source\(sources == 1 ? "" : "s")."
        case .clarificationNeeded:
            return "One detail would make this answerable."
        case .capabilityLimitation:
            return "That is outside what TrackSmith does."
        case .weakCoverageWithResearchOffer:
            return "Reviewed knowledge does not cover this well."
        case .provisionalResearch:
            return "Provisional answer from current research; not reviewed knowledge."
        }
    }

    /// Starts the validated guided experiment behind a strategy option, when
    /// that option names a reviewed procedure. Exact steps still come only
    /// from the procedure catalog.
    func startGuidedExperiment(
        procedureID: String,
        sourceType: SourceType,
        capture: TutorCaptureContext?
    ) {
        guard let planner,
              let procedure = planner.procedureCatalog.procedure(procedureID) else {
            statusMessage = "That experiment is not in the validated procedure catalog."
            return
        }
        var seed = TutorLessonState(
            requestKind: .troubleshootProblem,
            requestText: requestText,
            sourceType: sourceType,
            evidenceMode: capture == nil ? .userReportedOnly : .audioGrounded,
            authority: capture?.authority,
            userReportedChain: userReportedChain,
            status: .activeStep
        )
        seed = planner.activate(procedure: procedure, in: seed)
        do {
            try planner.validate(seed)
            lesson = seed
            statusMessage = seed.statusNote
            persistedRecord = TutorSessionRecord(lesson: seed)
            persist()
        } catch {
            statusMessage = "That experiment failed validation and was not started: \(error)"
        }
    }

    // MARK: - Personal memory

    /// Records a confirmed outcome for the current answer. Only called from an
    /// explicit user action; nothing is remembered implicitly.
    func rememberCurrentOutcome(helped: Bool, settings: [String] = []) {
        guard let outcome = generalOutcome else { return }
        let record = PersonalOutcomeRecord(
            question: outcome.answer.interpretedQuestion,
            sourceType: outcome.intent.sourceType,
            contextSummary: outcome.intent.userContext.reportedStatements.joined(separator: "; "),
            procedureID: outcome.answer.exactProcedureIDs.first,
            strategyID: outcome.answer.strategyOptions.first?.strategyID,
            feedback: helped ? .better : .noChange,
            userEnteredSettings: settings,
            whatImproved: helped ? outcome.answer.recommendedFirstMove : nil,
            whatDidNot: helped ? nil : outcome.answer.recommendedFirstMove,
            userAskedToRemember: true
        )
        profile.outcomes.append(record)
        saveProfile()
        memoryNote = helped
            ? "Remembered as something that worked for you. It will rank higher for you and is never shown as general advice."
            : "Remembered as something that did not work for you. It will rank lower for you."
    }

    func forgetOutcome(_ id: UUID) {
        profile.outcomes.removeAll { $0.id == id }
        saveProfile()
        memoryNote = "Forgotten."
    }

    func deleteAllLearning() {
        profile = .empty
        do {
            try profileStore?.deleteAll()
            rebuildCoordinator()
            memoryNote = "Deleted everything TrackSmith had learned about your setup and results."
        } catch {
            memoryNote = "Could not delete the profile: \(error)"
        }
    }

    func exportProfileSummary() -> String { profile.humanReadableSummary() }

    private func saveProfile() {
        do {
            try profileStore?.save(profile)
            if let reloaded = try? profileStore?.load() { profile = reloaded }
            rebuildCoordinator()
        } catch {
            memoryNote = "Could not save your profile: \(error)"
        }
    }

    /// Rebuilds the coordinator so ranking picks up the updated profile.
    private func rebuildCoordinator() {
        general = try? GeneralTutorCoordinator(profile: profile)
    }

    var userReportedChain: TutorUserReportedChain {
        TutorUserReportedChain(
            status: chainStatus,
            processors: chainProcessors.sorted { $0.rawValue < $1.rawValue }
        )
    }

    // MARK: - Lesson lifecycle

    func startLesson(sourceType: SourceType, capture: TutorCaptureContext?) {
        guard let planner else { return }
        do {
            var newLesson = try planner.makeLesson(for: TutorRequest(
                text: requestText,
                sourceType: sourceType,
                capture: capture,
                userReportedChain: userReportedChain,
                explanationDepth: explanationDepth
            ))
            newLesson.updatedAt = Date()
            lesson = newLesson
            restoredNote = ""
            statusMessage = newLesson.statusNote.isEmpty
                ? "Lesson started."
                : newLesson.statusNote
            persistedRecord = TutorSessionRecord(lesson: newLesson)
            persist()
        } catch {
            statusMessage = "The tutor could not build a validated lesson: \(error)"
        }
    }

    func send(_ feedback: TutorFeedback) {
        guard let reducer, let current = lesson else { return }
        let next = reducer.reduce(current, feedback: feedback)
        lesson = next
        statusMessage = next.statusNote
        persist()
    }

    func abandonLesson() {
        guard var current = lesson else { return }
        current.status = .abandoned
        current.activeStepID = nil
        current.updatedAt = Date()
        lesson = current
        statusMessage = "Lesson set aside. Everything you changed has its undo recorded in the step cards."
        persist()
    }

    /// Called when the live AU capture authority no longer matches the lesson.
    /// Audio-grounded claims become historical rather than silently live.
    func markAudioEvidenceHistoricalIfNeeded(authorityIsLive: Bool) {
        guard var current = lesson,
              current.evidenceMode == .audioGrounded,
              !current.audioEvidenceIsHistorical,
              !authorityIsLive else { return }
        current.audioEvidenceIsHistorical = true
        current.updatedAt = Date()
        lesson = current
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let store, let lesson else { return }
        var record = persistedRecord ?? TutorSessionRecord(lesson: lesson)
        record.lesson = lesson
        persistedRecord = record
        do {
            _ = try store.save(record)
            UserDefaults.standard.set(
                record.sessionID.uuidString,
                forKey: Self.activeSessionKey
            )
        } catch {
            statusMessage = "Tutor progress could not be persisted safely: \(error)"
        }
    }

    private func restoreLastSession() {
        guard let store,
              let raw = UserDefaults.standard.string(forKey: Self.activeSessionKey),
              let id = UUID(uuidString: raw) else { return }
        do {
            let result = try store.load(sessionID: id)
            var restored = result.record
            // A restored session cannot prove its old AU capture is still the
            // live one, so audio-grounded evidence restores as historical.
            if restored.lesson.evidenceMode == .audioGrounded {
                restored.lesson.audioEvidenceIsHistorical = true
            }
            persistedRecord = restored
            lesson = restored.lesson
            requestText = restored.lesson.requestText
            chainStatus = restored.lesson.userReportedChain.status
            chainProcessors = Set(restored.lesson.userReportedChain.processors)
            restoredNote = "Restored your previous tutor session. Measured claims from its earlier capture are historical until a new capture is analyzed."
        } catch {
            restoredNote = "A stored tutor session was unavailable or quarantined safely."
        }
    }
}
