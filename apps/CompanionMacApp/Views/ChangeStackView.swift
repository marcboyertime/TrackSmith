import SwiftUI

struct ChangeStackView: View {
    @ObservedObject var model: CompanionSessionModel

    @ViewBuilder
    var body: some View {
        GroupBox("Editable working plan") {
            if let plan = model.selectedPlan, !plan.nodes.isEmpty {
                VStack(spacing: Theme.Spacing.eight) {
                    ForEach(plan.nodes) { node in
                        ChangeCard(
                            node: node,
                            isBusy: model.isBusy,
                            setEnabled: { model.setNodeEnabled(nodeID: node.id, enabled: $0) },
                            setLocked: { model.setNodeLocked(nodeID: node.id, locked: $0) }
                        )
                    }
                }
                .padding(Theme.Spacing.eight)
            } else {
                Text("Choose a preview as the working plan to inspect and edit its complete graph.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
                    .padding(Theme.Spacing.eight)
            }
        }
    }
}
