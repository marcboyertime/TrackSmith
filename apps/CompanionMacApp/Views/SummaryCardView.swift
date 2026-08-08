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
                    .font(.callout.weight(.semibold))
                    .padding(.top, Theme.Spacing.four)
                ForEach(summary.remainingUncertainty, id: \.self) { item in
                    Text(item).font(Theme.Font.caption).foregroundStyle(.secondary)
                }
                if !lesson.conceptsPracticed.isEmpty {
                    Divider()
                    Text("Concepts practiced").font(.caption.weight(.semibold))
                    ForEach(lesson.conceptsPracticed, id: \.self) { concept in
                        Label(tutor.formatter.conceptLabel(concept), systemImage: "graduationcap")
                            .font(Theme.Font.caption)
                    }
                }
            }
            .font(Theme.Font.callout)
            .padding(Theme.Spacing.eight)
        }
    }
}
