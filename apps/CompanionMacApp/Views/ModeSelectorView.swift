import SwiftUI

struct ModeSelectorView: View {
    @Binding var mode: CompanionMode

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
            Picker("Mode", selection: $mode) {
                ForEach(CompanionMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("TrackSmith mode")
            Text(mode.subtitle)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}
