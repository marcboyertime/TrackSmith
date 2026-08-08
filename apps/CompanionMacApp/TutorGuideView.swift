import PlanSchema
import ProductionTutor
import SwiftUI

/// Guide Me: a structured studio workflow, not a chat transcript. One active
/// step at a time, simple language first, technical detail behind disclosure,
/// visible evidence grounding and uncertainty, and an undo for everything.
struct TutorGuideView: View {
    @ObservedObject var session: CompanionSessionModel
    @ObservedObject var tutor: TutorSessionModel
    @State private var isStartingLesson = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy18) {
                    Text("TrackSmith tells you exactly what to try in Logic, step by step. You perform every action.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    CapturePanelView(model: session)
                    if let reason = tutor.engineUnavailableReason {
                        Label(reason, systemImage: "exclamationmark.octagon")
                            .foregroundStyle(.red)
                    } else {
                        EvidenceBannerView(session: session, tutor: tutor)
                        if let outcome = tutor.generalOutcome {
                            GeneralAnswerView(
                                outcome: outcome,
                                depth: tutor.explanationDepth,
                                startExperiment: { procedureID in
                                    beginExperiment(procedureID)
                                }
                            )
                            MemoryControlsView(tutor: tutor)
                        }
                        if let lesson = tutor.lesson {
                            LessonContentView(tutor: tutor, lesson: lesson)
                        }
                    }
                }
                .padding(Theme.Spacing.twentyFour)
            }
            Divider().overlay(Theme.Colors.hairline)
            RequestPanelView(
                tutor: tutor,
                isStartingLesson: isStartingLesson,
                startLesson: { startLesson() },
                askQuestion: { askQuestion() }
            )
            .padding(Theme.Spacing.twelve)
            .background(Theme.Colors.card)
        }
        .onChange(of: session.captureArtifact) { _, _ in reconcileAuthority() }
        .onChange(of: session.instances) { _, _ in reconcileAuthority() }
    }

    private func reconcileAuthority() {
        tutor.markAudioEvidenceHistoricalIfNeeded(
            authorityIsLive: session.tutorAuthorityIsLive(tutor.lesson?.authority)
        )
    }

    private func startLesson() {
        isStartingLesson = true
        let sourceType = session.sourceType
        Task {
            defer { isStartingLesson = false }
            var capture: TutorCaptureContext?
            do {
                capture = try await session.tutorCaptureContext()
            } catch {
                capture = nil
            }
            tutor.startLesson(sourceType: sourceType, capture: capture)
        }
    }

    /// Answers any open-ended production question. A capture is used only when
    /// one already exists; asking never forces an analysis.
    private func askQuestion() {
        let sourceType = session.sourceType
        Task {
            // Ensure the analysis is current when a capture is present, so the
            // measurement-relevance map has something real to work with.
            _ = try? await session.tutorCaptureContext()
            tutor.ask(sourceType: sourceType, analysis: session.sourceAwareAnalysis)
        }
    }

    private func beginExperiment(_ procedureID: String) {
        let sourceType = session.sourceType
        Task {
            var capture: TutorCaptureContext?
            do { capture = try await session.tutorCaptureContext() } catch { capture = nil }
            tutor.startGuidedExperiment(
                procedureID: procedureID,
                sourceType: sourceType,
                capture: capture
            )
        }
    }
}
