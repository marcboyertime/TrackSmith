import SwiftUI

struct ActionBarView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        HStack {
            Button(model.isPlaying ? "Pause" : "Play") { model.togglePlayback() }
                .disabled(model.previewManifest == nil)
            Button("Rewind") { model.rewind() }
                .disabled(model.previewManifest == nil)
            Text("A/B switching stays sample-synchronized")
                .font(Theme.Font.meta)
                .foregroundStyle(.secondary)
            Button("Undo Edit") { model.undoWorkingChange() }
                .disabled(!model.canUndoWorking || model.isBusy)
            Button("Redo Edit") { model.redoWorkingChange() }
                .disabled(!model.canRedoWorking || model.isBusy)
            Spacer()
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
}
