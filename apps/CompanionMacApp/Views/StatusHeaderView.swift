import SwiftUI

struct StatusHeaderView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        HStack(spacing: Theme.Spacing.legacy10) {
            Circle().fill(model.statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                Text(model.status).font(Theme.Font.section)
                Text(model.detailStatus).font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
                if !model.restoredConversationStatus.isEmpty {
                    Text(model.restoredConversationStatus)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            Spacer()
            if let peak = model.activeSessionInstance?.inputPeakDBFS {
                Text(String(format: "Input %+.1f dBFS", peak))
                    .font(Theme.Font.data)
            }
            Text(model.providerSelection.usesCloud
                 ? "Text context only · no audio upload"
                 : "Local interpretation · no network")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.legacy14)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }
}
