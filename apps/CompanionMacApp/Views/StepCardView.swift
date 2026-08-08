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
                        .font(Theme.Font.section)
                        .foregroundStyle(Theme.Colors.text)
                    Spacer()
                    Text("You perform every action — TrackSmith never touches Logic")
                        .font(Theme.Font.meta)
                        .foregroundStyle(.secondary)
                }
                Text(step.title).font(Theme.Font.display)
                Text(step.instruction)

                if !step.substeps.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        ForEach(Array(step.substeps.enumerated()), id: \.offset) { index, substep in
                            Text("\(index + 1). \(substep)")
                        }
                    }
                    .font(Theme.Font.body)
                }

                Label {
                    Text(step.listenFor)
                } icon: {
                    Image(systemName: "ear")
                }
                .font(Theme.Font.body)

                Text(tutor.formatter.explanation(for: step, depth: .simple))
                    .font(Theme.Font.body)
                    .foregroundStyle(.secondary)

                if tutor.explanationDepth != .simple {
                    DisclosureGroup("Why this works") {
                        Text(step.technicalExplanation)
                            .font(Theme.Font.meta)
                            .padding(.top, Theme.Spacing.four)
                    }
                    .font(Theme.Font.meta)
                }
                DisclosureGroup("Producer lesson") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        ForEach(step.concepts, id: \.self) { concept in
                            Label(tutor.formatter.conceptLabel(concept), systemImage: "graduationcap")
                                .font(Theme.Font.meta)
                        }
                        if !step.uncertainty.isEmpty {
                            Text("Uncertainty: " + step.uncertainty.joined(separator: " "))
                                .font(Theme.Font.meta)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, Theme.Spacing.four)
                }
                .font(Theme.Font.meta)

                if let location = step.location {
                    DisclosureGroup("Where to find it") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                            Text("Logic Pro \(location.logicVersion) · \(location.workArea)")
                            Text(location.navigationLabels.joined(separator: " → "))
                                .font(Theme.Font.meta)
                            Text(location.requiredFocusOrSelection)
                            if location.verification == .documentary {
                                Text("Path from Apple documentation; not yet re-verified on this machine.")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(Theme.Font.meta)
                        .padding(.top, Theme.Spacing.four)
                    }
                    .font(Theme.Font.meta)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                    Label("Stop: \(step.stopCondition)", systemImage: "hand.raised")
                    Label("Could go wrong: \(step.commonSideEffect)", systemImage: "exclamationmark.triangle")
                    Label("Undo: \(step.undoInstruction)", systemImage: "arrow.uturn.backward")
                }
                .font(Theme.Font.meta)
                .foregroundStyle(.secondary)

                FeedbackBarView(tutor: tutor, step: step)
            }
            .padding(Theme.Spacing.legacy10)
        }
    }
}
