import PlanSchema
import PreviewWorkflow
import SwiftUI

struct ChangeCard: View {
    var node: ProcessingNode
    var isBusy: Bool
    var setEnabled: (Bool) -> Void
    var setLocked: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
            HStack {
                Text(node.type.rawValue).font(Theme.Font.section)
                Text(node.category.rawValue.capitalized)
                    .font(Theme.Font.meta)
                    .padding(.horizontal, Theme.Spacing.legacy7).padding(.vertical, Theme.Spacing.legacy3)
                    .background(Theme.Colors.raised, in: Capsule())
                Spacer()
                Toggle("Enabled", isOn: Binding(
                    get: { node.enabled },
                    set: { enabled in setEnabled(enabled) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isBusy || node.locked)
                Button(node.locked ? "Unlock" : "Lock") { setLocked(!node.locked) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
                Text(String(format: "%.0f%% confidence", node.confidence * 100))
                    .font(Theme.Font.meta).foregroundStyle(.secondary)
            }
            if !node.parameters.isEmpty {
                Text(node.parameters.sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { "\($0.key.rawValue): \(String(format: "%.2f", $0.value))" }
                    .joined(separator: "   "))
                    .font(Theme.Font.meta)
            }
            Text(node.rationale).font(Theme.Font.meta).foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.legacy10)
        .instrumentSurface(.raised)
    }
}
