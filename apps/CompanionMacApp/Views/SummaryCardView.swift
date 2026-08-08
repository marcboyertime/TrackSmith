import ProductionTutor
import SwiftUI

struct SummaryCardView: View {
    @ObservedObject var tutor: TutorSessionModel
    let summary: TutorLessonSummary
    let lesson: TutorLessonState

    var body: some View {
        GroupBox("What you learned") {
            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                Label(summary.whatChanged, systemImage: "checkmark.circle")
                Label(summary.likelyCause, systemImage: "lightbulb")
                ForEach(summary.whatDidNotHelp, id: \.self) { item in
                    Label(item, systemImage: "minus.circle").foregroundStyle(.secondary)
                }
                ForEach(summary.whatWasPreserved, id: \.self) { item in
                    Label(item, systemImage: "lock.shield").foregroundStyle(.secondary)
                }
                Text(summary.principleToRemember)
                    .font(Theme.Font.body.weight(.semibold))
                    .padding(.top, Theme.Spacing.four)
                ForEach(summary.remainingUncertainty, id: \.self) { item in
                    Text(item).font(Theme.Font.meta).foregroundStyle(.secondary)
                }
                if !lesson.conceptsPracticed.isEmpty {
                    Divider()
                    Text("Concepts practiced").font(Theme.Font.section)
                    ForEach(lesson.conceptsPracticed, id: \.self) { concept in
                        Label(tutor.formatter.conceptLabel(concept), systemImage: "graduationcap")
                            .font(Theme.Font.meta)
                    }
                }
            }
            .font(Theme.Font.body)
            .padding(Theme.Spacing.eight)
        }
    }
}
