import ProductionTutor
import SwiftUI

struct FeedbackBarView: View {
    @ObservedObject var tutor: TutorSessionModel
    let step: TutorStep

    private static let comparisonPrimaryFeedback: Set<TutorFeedback> = [.better, .worse, .noChange]

    private var isComparisonStep: Bool {
        switch step.actionKind {
        case .compareBypass, .levelMatchComparison:
            return true
        default:
            return false
        }
    }

    private var primaryFeedback: [TutorFeedback] {
        guard isComparisonStep else { return step.supportedFeedback }
        return step.supportedFeedback.filter { Self.comparisonPrimaryFeedback.contains($0) }
    }

    private var overflowFeedback: [TutorFeedback] {
        guard isComparisonStep else { return [] }
        return step.supportedFeedback.filter { !Self.comparisonPrimaryFeedback.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
            Text("What happened?").font(Theme.Font.section)
            HStack(spacing: Theme.Spacing.eight) {
                ForEach(primaryFeedback, id: \.self) { feedback in
                    feedbackButton(feedback)
                }
                if !overflowFeedback.isEmpty {
                    Menu("More") {
                        ForEach(overflowFeedback, id: \.self) { feedback in
                            Button(feedbackLabel(feedback)) { tutor.send(feedback) }
                                .accessibilityLabel(feedbackAccessibilityLabel(feedback))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private func feedbackButton(_ feedback: TutorFeedback) -> some View {
        Button(feedbackLabel(feedback)) { tutor.send(feedback) }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.feedbackTint(for: feedback))
            .controlSize(.regular)
            .accessibilityLabel(feedbackAccessibilityLabel(feedback))
    }
}
