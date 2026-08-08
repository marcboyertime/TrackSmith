import ProductionTutor
import SwiftUI

struct LessonContentView: View {
    @ObservedObject var tutor: TutorSessionModel
    let lesson: TutorLessonState

    @ViewBuilder
    var body: some View {
        if lesson.status == .awaitingClarification, let question = lesson.clarificationQuestion {
            GroupBox("One quick question") {
                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    Text(question)
                    Text("Answer by editing your request above and starting the lesson again.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.eight)
            }
        }

        if !lesson.hypotheses.isEmpty {
            HypothesesPanelView(tutor: tutor, lesson: lesson)
        }

        if !lesson.unresolvedLimitations.isEmpty {
            GroupBox("What the tutor will not do here") {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
                    ForEach(lesson.unresolvedLimitations, id: \.self) { limitation in
                        Label(limitation, systemImage: "hand.raised")
                            .font(Theme.Font.caption)
                    }
                }
                .padding(Theme.Spacing.eight)
            }
        }

        if let step = lesson.activeStep, lesson.status == .activeStep {
            StepCardView(tutor: tutor, step: step, lesson: lesson)
        }

        if !tutor.statusMessage.isEmpty {
            Text(tutor.statusMessage)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }

        if let summary = lesson.finalSummary {
            SummaryCardView(tutor: tutor, summary: summary, lesson: lesson)
        }
    }
}
