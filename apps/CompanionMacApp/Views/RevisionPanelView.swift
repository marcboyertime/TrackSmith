import SwiftUI

struct RevisionPanelView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
            Text("Conversational revision")
                .font(Theme.Font.section)
                TextField("Revise the current working plan", text: $model.revisionPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(Theme.Spacing.twelve)
                    .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.hairline, lineWidth: 1))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                    ForEach(["Use less compression", "Undo only the compression", "Lock the EQ", "Remove the compression"], id: \.self) { chip in
                        Button(chip) { model.revisionPrompt = chip }
                            .buttonStyle(.borderless)
                            .font(Theme.Font.meta)
                            .padding(.horizontal, Theme.Spacing.eight)
                            .padding(.vertical, Theme.Spacing.four)
                            .background(Theme.Colors.raised, in: Capsule())
                    }
                    }
                }
                HStack {
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
                    .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }
}
