import SwiftUI

struct ProviderStatusRowView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        HStack(spacing: Theme.Spacing.eight) {
            Image(systemName: model.providerSelection.usesCloud ? "cloud" : "checkmark.shield")
                .foregroundStyle(model.providerSelection.usesCloud ? Theme.Colors.accent : .secondary)
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                Text(model.activeProviderDescription)
                    .font(Theme.Font.meta)
                if model.providerSelection.usesCloud {
                    Text(model.cloudReasoningConsent ? "Cloud consent: granted" : "Cloud consent: not granted")
                        .font(Theme.Font.meta)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            SettingsLink {
                Label("Settings", systemImage: "gear")
                    .font(Theme.Font.meta)
            }
        }
        .padding(.horizontal, Theme.Spacing.eight)
        .padding(.vertical, Theme.Spacing.four)
        .instrumentSurface(.raised)
    }
}
