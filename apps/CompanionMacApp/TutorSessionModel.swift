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

    let formatter = TutorExplanationFormatter()

    private var planner: TutorPlanner?
    private var reducer: TutorFeedbackReducer?
    private var store: TutorSessionStore?
    private var persistedRecord: TutorSessionRecord?

    private static let activeSessionKey = "TrackSmith.ActiveTutorSessionID"

    init() {
        do {
            let planner = try TutorPlanner()
            self.planner = planner
            reducer = TutorFeedbackReducer(planner: planner)
        } catch {
            engineUnavailableReason = "The tutor knowledge catalog failed validation and Guide Me is disabled: \(error)"
        }
        store = try? TutorSessionStore()
        restoreLastSession()
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
