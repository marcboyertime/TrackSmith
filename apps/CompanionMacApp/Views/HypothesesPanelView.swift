import ProductionTutor
import SwiftUI

struct HypothesesPanelView: View {
    @ObservedObject var tutor: TutorSessionModel
    let lesson: TutorLessonState

    var body: some View {
        GroupBox("Possible causes — deliberately more than one") {
            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                Text(tutor.formatter.hypothesisIntro(for: lesson))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(lesson.hypotheses.enumerated()), id: \.offset) { index, hypothesis in
                    HStack(alignment: .top, spacing: Theme.Spacing.eight) {
                        Image(systemName: hypothesisSymbol(hypothesis.status))
                            .foregroundStyle(Theme.Colors.hypothesisColor(for: hypothesis.status))
                        VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                            Text("\(index + 1). \(hypothesis.summary)")
                                .font(Theme.Font.caption)
                            if hypothesis.status != .open {
                                Text(hypothesisStatusLabel(hypothesis.status))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.hypothesisColor(for: hypothesis.status))
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
