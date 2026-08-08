import SwiftUI

struct RevisionPanelView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        GroupBox("Conversational revision") {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
                TextField("Revise the current working plan", text: $model.revisionPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                HStack {
                    ForEach(["Use less compression", "Undo only the compression", "Lock the EQ", "Remove the compression"], id: \.self) { chip in
                        Button(chip) { model.revisionPrompt = chip }
                            .buttonStyle(.borderless)
                            .font(Theme.Font.meta)
                            .padding(.horizontal, Theme.Spacing.eight)
                            .padding(.vertical, Theme.Spacing.four)
                            .background(Theme.Colors.raised, in: Capsule())
                    }
                    Spacer()
                    Button("Render Revision") { model.previewRevision() }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            model.selectedPlan == nil
                                || model.revisionPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.isBusy
                        )
                }
                Text("Edits derive from structured working state. Unmentioned production nodes and every locked node remain intact; measured preview gain is recalibrated after audio changes.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
