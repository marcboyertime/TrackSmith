import SwiftUI

struct PromptPanelView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
            Text("Create For Me")
                .font(Theme.Font.section)
                TextField("Describe the result", text: $model.prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...5)
                    .padding(Theme.Spacing.twelve)
                    .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.hairline, lineWidth: 1))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                    ForEach(["Clearer and controlled", "Warmer, not darker", "Punchier without increasing harshness"], id: \.self) { chip in
                        Button(chip) { model.prompt = chip }
                            .buttonStyle(.borderless)
                            .padding(.horizontal, Theme.Spacing.legacy9)
                            .padding(.vertical, Theme.Spacing.legacy5)
                            .background(Theme.Colors.raised, in: Capsule())
                    }
                    }
                }
                HStack {
                    Spacer()
                    Button("Create 3 Previews") { model.generatePreviews() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.captureArtifact == nil || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
                }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }
}
