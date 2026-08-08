import SwiftUI

struct PreviewCard: View {
    var title: String
    var subtitle: String
    var subtitleIsMeasured = false
    var selected: Bool
    var warning: String?
    var working = false
    var useAction: (() -> Void)?
    var action: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.legacy6) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
                    HStack {
                        Text(title).font(Theme.Font.section)
                        if working {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Theme.Colors.accent)
                                .accessibilityLabel("Working plan")
                        }
                    }
                    Text(subtitle)
                        .font(subtitleIsMeasured ? Theme.Font.data : Theme.Font.meta)
                        .foregroundStyle(.secondary)
                    if let warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(Theme.Font.meta)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 75, alignment: .leading)
                .padding(Theme.Spacing.legacy10)
                .background(selected ? Theme.Colors.accentSelection : Theme.Colors.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(selected ? Theme.Colors.accent : Theme.Colors.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            if let useAction {
                Button(working ? "Working Plan" : "Use as Working") { useAction() }
                    .font(Theme.Font.meta)
                    .buttonStyle(.borderless)
                    .disabled(working)
            }
        }
    }
}
