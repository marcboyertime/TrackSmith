import SwiftUI

struct ResearchControlView: View {
    @ObservedObject var tutor: TutorSessionModel

    @ViewBuilder
    var body: some View {
        if tutor.researchAvailable {
            Toggle("Research current sources", isOn: .constant(false))
                .font(Theme.Font.caption)
        } else {
            Label("Research This: not built yet", systemImage: "globe.badge.chevron.backward")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help("Answers come only from reviewed local knowledge. Live source research is specified but not implemented, so TrackSmith will tell you when its knowledge does not cover a question rather than searching.")
        }
    }
}
