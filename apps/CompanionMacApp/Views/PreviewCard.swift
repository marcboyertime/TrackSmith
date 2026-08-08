import SwiftUI

struct PreviewCard: View {
    var title: String
    var subtitle: String
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
                        Text(title).font(.headline)
                        if working {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Working plan")
                        }
                    }
                    Text(subtitle).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if let warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 75, alignment: .leading)
                .padding(Theme.Spacing.legacy10)
                .background(selected ? Color.accentColor.opacity(0.17) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            if let useAction {
                Button(working ? "Working Plan" : "Use as Working") { useAction() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .disabled(working)
            }
        }
    }
}
