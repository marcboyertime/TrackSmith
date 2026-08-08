import SwiftUI

struct PromptPanelView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        GroupBox("Production request") {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
                TextField("Describe the result", text: $model.prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                HStack {
                    ForEach(["Clearer and controlled", "Warmer, not darker", "Punchier without increasing harshness"], id: \.self) { chip in
                        Button(chip) { model.prompt = chip }
                            .buttonStyle(.borderless)
                            .padding(.horizontal, Theme.Spacing.legacy9)
                            .padding(.vertical, Theme.Spacing.legacy5)
                            .background(Theme.Colors.raised, in: Capsule())
                    }
                    Spacer()
                    Button("Create 3 Previews") { model.generatePreviews() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.captureArtifact == nil || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
                }
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
