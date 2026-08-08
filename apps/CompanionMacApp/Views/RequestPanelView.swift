import ProductionTutor
import SwiftUI

struct RequestPanelView: View {
    @ObservedObject var tutor: TutorSessionModel
    let isStartingLesson: Bool
    let startLesson: () -> Void
    let askQuestion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
            HStack {
                Text("Guide Me")
                    .font(Theme.Font.section)
                Spacer()
                Text("⌘↩ to ask")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }
                TextField(
                    "Describe the problem or the sound you want",
                    text: $tutor.requestText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(Theme.Spacing.twelve)
                .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.hairline, lineWidth: 1))
                HStack {
                    Button("Start Lesson") { startLesson() }
                        .buttonStyle(.bordered)
                        .disabled(
                            isStartingLesson
                                || tutor.requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .help("Runs the bounded step-by-step vocal troubleshooting flow.")
                    Spacer()
                    Button {
                        askQuestion()
                    } label: {
                        Label("Ask", systemImage: "arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(
                        tutor.isAnswering
                            || tutor.requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .help("Answers any production question from reviewed knowledge.")
                }
                ScrollView(.horizontal, showsIndicators: false) {
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
                            .font(Theme.Font.meta)
                            .padding(.horizontal, Theme.Spacing.eight)
                            .padding(.vertical, Theme.Spacing.four)
                            .background(Theme.Colors.raised, in: Capsule())
                    }
                    }
                }
                DisclosureGroup("Answer context") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                        ChainPanelView(tutor: tutor)
                        HStack {
                            Picker("Explanation", selection: $tutor.explanationDepth) {
                        Text("Simple").tag(TutorExplanationDepth.simple)
                        Text("Standard").tag(TutorExplanationDepth.standard)
                        Text("Technical").tag(TutorExplanationDepth.technical)
                    }
                    .pickerStyle(.segmented)
                            .frame(maxWidth: 310)
                            ResearchControlView(tutor: tutor)
                        }
                    }
                    .padding(.top, Theme.Spacing.four)
                }
                if !tutor.restoredNote.isEmpty {
                    Text(tutor.restoredNote).font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
                }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }
}
