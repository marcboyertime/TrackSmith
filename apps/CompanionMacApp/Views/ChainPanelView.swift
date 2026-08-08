import ProductionTutor
import SwiftUI

struct ChainPanelView: View {
    @ObservedObject var tutor: TutorSessionModel

    var body: some View {
        DisclosureGroup("What is already on this channel? (your report — TrackSmith cannot see Logic inserts)") {
            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                Picker("Chain", selection: $tutor.chainStatus) {
                    Text("I don't know").tag(TutorUserReportedChain.Status.unknown)
                    Text("Nothing").tag(TutorUserReportedChain.Status.none)
                    Text("These processors:").tag(TutorUserReportedChain.Status.reported)
                }
                .pickerStyle(.segmented)
                if tutor.chainStatus == .reported {
                    HStack(spacing: Theme.Spacing.legacy6) {
                        ForEach(TutorReportedProcessor.allCases, id: \.self) { processor in
                            Toggle(
                                processorLabel(processor),
                                isOn: Binding(
                                    get: { tutor.chainProcessors.contains(processor) },
                                    set: { enabled in
                                        if enabled { tutor.chainProcessors.insert(processor) }
                                        else { tutor.chainProcessors.remove(processor) }
                                    }
                                )
                            )
                            .toggleStyle(.button)
                            .controlSize(.small)
                        }
                    }
                }
                Text("This is user-reported context, never observed state.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(.top, Theme.Spacing.legacy6)
        }
        .font(Theme.Font.meta)
    }
}
