import ProductionTutor
import SwiftUI

struct FeedbackBarView: View {
    @ObservedObject var tutor: TutorSessionModel
    let step: TutorStep

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
            Text("What happened?").font(Theme.Font.section)
            HStack(spacing: Theme.Spacing.eight) {
                ForEach(step.supportedFeedback, id: \.self) { feedback in
                    Button(feedbackLabel(feedback)) { tutor.send(feedback) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.feedbackTint(for: feedback))
                        .controlSize(.regular)
                        .accessibilityLabel(feedbackAccessibilityLabel(feedback))
                }
            }
        }
    }
}
