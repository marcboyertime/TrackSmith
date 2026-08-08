import ProductionTutor
import SwiftUI

struct RequestPanelView: View {
    @ObservedObject var tutor: TutorSessionModel
    let isStartingLesson: Bool
    let startLesson: () -> Void
    let askQuestion: () -> Void

    var body: some View {
        GroupBox("What do you want help with?") {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
                TextField(
                    "Describe the problem or the sound you want",
                    text: $tutor.requestText,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                HStack {
                    ForEach(
                        ["I sound nasal",
                         "Why does my chorus feel smaller than the verse?",
                         "How do I tighten my MIDI piano without making it robotic?",
                         "What is pre-delay actually doing?",
                         "I am stuck. What should I try next?"],
                        id: \.self
                    ) { chip in
                        Button(chip) { tutor.requestText = chip }
                            .buttonStyle(.borderless)
                            .font(Theme.Font.caption)
                            .padding(.horizontal, Theme.Spacing.eight)
                            .padding(.vertical, Theme.Spacing.four)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                }
                ChainPanelView(tutor: tutor)
                HStack {
                    Picker("Explanation", selection: $tutor.explanationDepth) {
                        Text("Simple").tag(TutorExplanationDepth.simple)
                        Text("Standard").tag(TutorExplanationDepth.standard)
                        Text("Technical").tag(TutorExplanationDepth.technical)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                    ResearchControlView(tutor: tutor)
                    Spacer()
                    // Ask is the default: any production question is accepted.
                    // Start Lesson remains for the bounded vocal fast path.
                    Button("Start Lesson") { startLesson() }
                        .buttonStyle(.bordered)
                        .disabled(
                            isStartingLesson
                                || tutor.requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .help("Runs the bounded step-by-step vocal troubleshooting flow.")
                    Button("Ask") { askQuestion() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(
                            tutor.isAnswering
                                || tutor.requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .help("Answers any production question from reviewed knowledge.")
                }
                if !tutor.restoredNote.isEmpty {
                    Text(tutor.restoredNote).font(Theme.Font.caption).foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
