import ProductionTutor
import SwiftUI

struct StepCardView: View {
    @ObservedObject var tutor: TutorSessionModel
    let step: TutorStep
    let lesson: TutorLessonState

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
                HStack {
                    Text(progressLabel(step, lesson: lesson))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text("You perform every action — TrackSmith never touches Logic")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(step.title).font(.title3.weight(.semibold))
                Text(step.instruction)

                if !step.substeps.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        ForEach(Array(step.substeps.enumerated()), id: \.offset) { index, substep in
                            Text("\(index + 1). \(substep)")
                        }
                    }
                    .font(Theme.Font.callout)
                }

                Label {
                    Text(step.listenFor)
                } icon: {
                    Image(systemName: "ear")
                }
                .font(Theme.Font.callout)

                Text(tutor.formatter.explanation(for: step, depth: .simple))
                    .font(Theme.Font.callout)
                    .foregroundStyle(.secondary)

                if tutor.explanationDepth != .simple {
                    DisclosureGroup("Why this works") {
                        Text(step.technicalExplanation)
                            .font(Theme.Font.caption)
                            .padding(.top, Theme.Spacing.four)
                    }
                    .font(Theme.Font.caption)
                }
                DisclosureGroup("Producer lesson") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        ForEach(step.concepts, id: \.self) { concept in
                            Label(tutor.formatter.conceptLabel(concept), systemImage: "graduationcap")
                                .font(Theme.Font.caption)
                        }
                        if !step.uncertainty.isEmpty {
                            Text("Uncertainty: " + step.uncertainty.joined(separator: " "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, Theme.Spacing.four)
                }
                .font(Theme.Font.caption)

                if let location = step.location {
                    DisclosureGroup("Where to find it") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                            Text("Logic Pro \(location.logicVersion) · \(location.workArea)")
                            Text(location.navigationLabels.joined(separator: " → "))
                                .font(.caption.monospaced())
                            Text(location.requiredFocusOrSelection)
                            if location.verification == .documentary {
                                Text("Path from Apple documentation; not yet re-verified on this machine.")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(Theme.Font.caption)
                        .padding(.top, Theme.Spacing.four)
                    }
                    .font(Theme.Font.caption)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                    Label("Stop: \(step.stopCondition)", systemImage: "hand.raised")
                    Label("Could go wrong: \(step.commonSideEffect)", systemImage: "exclamationmark.triangle")
                    Label("Undo: \(step.undoInstruction)", systemImage: "arrow.uturn.backward")
                }
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)

                FeedbackBarView(tutor: tutor, step: step)
            }
            .padding(Theme.Spacing.legacy10)
        }
    }
}
