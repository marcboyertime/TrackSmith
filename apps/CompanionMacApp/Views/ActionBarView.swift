import SwiftUI

struct ActionBarView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalControls
            verticalControls
        }
    }

    private var horizontalControls: some View {
        HStack {
            Button(model.isPlaying ? "Pause" : "Play") { model.togglePlayback() }
                .disabled(model.previewManifest == nil)
            Button("Rewind") { model.rewind() }
                .disabled(model.previewManifest == nil)
            Text("A/B switching stays sample-synchronized")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            Button("Undo Edit") { model.undoWorkingChange() }
                .disabled(!model.canUndoWorking || model.isBusy)
            Button("Redo Edit") { model.redoWorkingChange() }
                .disabled(!model.canRedoWorking || model.isBusy)
            Spacer()
            trailingActions
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private var verticalControls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack {
                Button(model.isPlaying ? "Pause" : "Play") { model.togglePlayback() }
                .disabled(model.previewManifest == nil)
                Button("Rewind") { model.rewind() }
                .disabled(model.previewManifest == nil)
                Button("Undo Edit") { model.undoWorkingChange() }
                    .disabled(!model.canUndoWorking || model.isBusy)
                Button("Redo Edit") { model.redoWorkingChange() }
                    .disabled(!model.canRedoWorking || model.isBusy)
            }
            Text("A/B switching stays sample-synchronized")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            HStack {
                trailingActions
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    @ViewBuilder
    private var trailingActions: some View {
            Button("Revert") { model.revert() }
                .disabled(model.basePlan == nil || !model.capturedInstanceIsAvailable || model.isBusy)
            Button(model.isGlobalBypassed ? "Restore Processing" : "Bypass All") {
                model.toggleGlobalBypass()
            }
            .disabled(!model.canToggleGlobalBypass || model.isBusy)
            Button("Commit Working Plan") { model.commitSelected() }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedPlan == nil || !model.capturedInstanceIsAvailable || model.isBusy)
    }
}
