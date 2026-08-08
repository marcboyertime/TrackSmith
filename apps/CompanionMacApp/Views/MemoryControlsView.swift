import SwiftUI

struct MemoryControlsView: View {
    @ObservedObject var tutor: TutorSessionModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                HStack(spacing: Theme.Spacing.eight) {
                    Text("Did this help on your track?")
                        .font(.caption.weight(.semibold))
                    Button("Remember this worked") {
                        tutor.rememberCurrentOutcome(helped: true)
                    }
                    .font(Theme.Font.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Remember it did not") {
                        tutor.rememberCurrentOutcome(helped: false)
                    }
                    .font(Theme.Font.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
                Text("Nothing is remembered unless you press one of these. What you save stays on this Mac, ranks results for you only, and is never shown as general advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !tutor.memoryNote.isEmpty {
                    Text(tutor.memoryNote).font(.caption2).foregroundStyle(.tint)
                }
                if !tutor.profile.outcomes.isEmpty {
                    DisclosureGroup("What TrackSmith remembers (\(tutor.profile.outcomes.count))") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                            ForEach(tutor.profile.outcomes) { outcome in
                                HStack(alignment: .top) {
                                    Text("• \(outcome.feedback.rawValue): \(outcome.question)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Forget") { tutor.forgetOutcome(outcome.id) }
                                        .font(.caption2)
                                        .buttonStyle(.borderless)
                                }
                            }
                            HStack {
                                Button("Delete all tutor learning", role: .destructive) {
                                    tutor.deleteAllLearning()
                                }
                                .font(.caption2)
                                .buttonStyle(.borderless)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(Theme.Font.caption)
                }
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
