import PlanSchema
import SwiftUI
import TutorConversation

struct TutorConversationView: View {
    @ObservedObject var session: CompanionSessionModel
    @ObservedObject var tutor: TutorConversationSessionModel
    @State private var confirmingHistoryDeletion = false

    var body: some View {
        VStack(spacing: 0) {
            contextBar
            Divider().overlay(Theme.Colors.hairline)
            transcript
            Divider().overlay(Theme.Colors.hairline)
            composer
        }
        .confirmationDialog(
            "Delete all Tutor history?",
            isPresented: $confirmingHistoryDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Transcript, Experiments, and Receipts", role: .destructive) {
                tutor.deleteAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes Tutor conversation state and immutable local evidence receipts. It does not delete captures, previews, Logic projects, or source audio.")
        }
    }

    private var contextBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack(spacing: Theme.Spacing.twelve) {
                Picker("Source", selection: $session.sourceType) {
                    ForEach(SourceType.allCases, id: \.self) { source in
                        Text(sourceLabel(source)).tag(source)
                    }
                }
                .frame(width: 210)

                Button("Capture Recent Playback", systemImage: "waveform.badge.magnifyingglass") {
                    session.captureRecent()
                }
                .disabled(session.selectedInstanceID == nil || session.isBusy)

                Toggle("Use local measurements", isOn: $tutor.attachCurrentCapture)
                    .toggleStyle(.checkbox)

                if session.captureArtifact != nil {
                    Toggle("Let audio model listen next turn", isOn: $tutor.requestModelListening)
                        .toggleStyle(.checkbox)
                        .help("Requires separate cloud-audio consent. The exact bounded WAV is hash-checked immediately before upload.")
                }
                Spacer()
            }

            HStack(spacing: Theme.Spacing.eight) {
                Circle().fill(session.statusColor).frame(width: 8, height: 8)
                Text(captureSummary)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                Text(tutor.activity)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }

            Text(tutor.logicStatus)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.mutedText)
        }
        .padding(.horizontal, Theme.Spacing.twentyFour)
        .padding(.vertical, Theme.Spacing.twelve)
        .background(Theme.Colors.card)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.sixteen) {
                    if tutor.state.messages.isEmpty {
                        welcome
                    }
                    ForEach(tutor.state.messages) { message in
                        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.eight) {
                            messageBubble(message)
                            if let experimentID = message.experimentID,
                               let experiment = tutor.state.experiments.first(where: { $0.id == experimentID }) {
                                experimentCard(experiment)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                        .id(message.id)
                    }
                    if !tutor.streamingText.isEmpty {
                        streamingBubble.id("streaming")
                    }
                }
                .padding(Theme.Spacing.twentyFour)
            }
            .onChange(of: tutor.state.messages.count) { _, _ in
                if let last = tutor.state.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: tutor.streamingText) { _, _ in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            Text("Tell me what you want to hear.")
                .font(Theme.Font.display)
            Text("I’ll ask only what changes the next move, use reviewed local knowledge and capture evidence when available, then give you one reversible experiment in Logic. You perform every edit.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.secondaryText)
            HStack {
                starter("My vocal sounds muddy in the mix")
                starter("Why does my chorus feel smaller?")
                starter("Teach me compression by ear")
            }
        }
        .padding(Theme.Spacing.twentyFour)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func starter(_ text: String) -> some View {
        Button(text) { tutor.composer = text }
            .buttonStyle(.bordered)
    }

    private func messageBubble(_ message: TutorConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            Text(message.text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.text)
                .textSelection(.enabled)
            if !message.evidence.isEmpty {
                evidenceChips(message.evidence)
            }
            if message.status != .complete {
                Text(message.status.rawValue.capitalized)
                    .font(Theme.Font.meta)
                    .foregroundStyle(.orange)
            }
        }
        .padding(Theme.Spacing.twelve)
        .frame(maxWidth: 720, alignment: .leading)
        .background(
            message.role == .user ? Theme.Colors.accentSelection : Theme.Colors.raised,
            in: RoundedRectangle(cornerRadius: Theme.Radius.medium)
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.hairline))
    }

    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack {
                ProgressView().controlSize(.small)
                Text(tutor.activity).font(Theme.Font.meta).foregroundStyle(Theme.Colors.mutedText)
            }
            Text(tutor.streamingText)
                .font(Theme.Font.body)
                .textSelection(.enabled)
            if let notice = tutor.fallbackNotice {
                Text(notice)
                    .font(Theme.Font.meta)
                    .foregroundStyle(.orange)
            }
        }
        .padding(Theme.Spacing.twelve)
        .frame(maxWidth: 720, alignment: .leading)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func evidenceChips(_ values: [TutorEvidenceReference]) -> some View {
        HStack(spacing: Theme.Spacing.four) {
            ForEach(Array(values.prefix(6))) { evidence in
                Text(evidence.kind.compactLabel)
                    .font(Theme.Font.meta.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.legacy6)
                    .padding(.vertical, Theme.Spacing.legacy2)
                    .background(evidenceColor(evidence.kind).opacity(0.16), in: Capsule())
                    .help("\(evidence.label): \(evidence.detail)")
            }
        }
    }

    private func experimentCard(_ experiment: TutorExperimentRecord) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack {
                Label("One reversible experiment", systemImage: "dial.medium")
                    .font(Theme.Font.section)
                Spacer()
                Text("User performs this")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }
            Text(experiment.draft.title).font(Theme.Font.body.weight(.semibold))
            experimentRow("Where", experiment.draft.logicLocation)
            experimentRow("Try", "\(experiment.draft.action) Starting point: \(experiment.draft.startingRange)")
            experimentRow("Listen for", experiment.draft.listenFor)
            experimentRow("Why", experiment.draft.why)
            experimentRow("Risk / stop", experiment.draft.risk)
            experimentRow("Undo", experiment.draft.undo)
            HStack {
                Button("Show Me", systemImage: "scope") { tutor.showMe(experiment) }
                Button("Dismiss Callout") { tutor.dismissCallout() }
                Spacer()
                if let outcome = experiment.outcome {
                    Text("Reported: \(outcome.rawValue)")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                } else {
                    Button("Better") { tutor.submitOutcome(experiment: experiment, outcome: .better, session: session) }
                    Button("Worse") { tutor.submitOutcome(experiment: experiment, outcome: .worse, session: session) }
                    Button("No change") { tutor.submitOutcome(experiment: experiment, outcome: .noChange, session: session) }
                    Button("Can't find it") { tutor.submitOutcome(experiment: experiment, outcome: .cannotFind, session: session) }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(Theme.Spacing.twelve)
        .frame(maxWidth: 760, alignment: .leading)
        .background(Theme.Colors.accentSubtle, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.accent.opacity(0.55)))
    }

    private func experimentRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.eight) {
            Text(label).font(Theme.Font.meta.weight(.semibold)).frame(width: 72, alignment: .leading)
            Text(value).font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            TextField("Project goal (optional)", text: $tutor.projectGoal)
                .textFieldStyle(.plain)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            HStack(alignment: .bottom, spacing: Theme.Spacing.eight) {
                TextField("Ask about what you hear, what changed, or why…", text: $tutor.composer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .onSubmit { tutor.send(session: session) }
                if tutor.isStreaming {
                    Button("Cancel", role: .cancel) { tutor.cancel() }
                } else {
                    Button("Send", systemImage: "arrow.up.circle.fill") { tutor.send(session: session) }
                        .buttonStyle(.borderedProminent)
                        .disabled(tutor.composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Menu {
                    Button("New Conversation", systemImage: "plus.bubble") { tutor.startNewConversation() }
                    Button("Grant Read-Only Accessibility", systemImage: "eye") { tutor.requestAccessibilityAccess() }
                    Divider()
                    Button("Delete All Tutor History", systemImage: "trash", role: .destructive) {
                        confirmingHistoryDeletion = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("Tutor actions")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
            Text("Text and measurements leave this Mac only with cloud-text consent. Audio requires a second consent and an exact hash-bound capture. The model has no Logic or Audio Unit mutation tools.")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.mutedText)
        }
        .padding(.horizontal, Theme.Spacing.twentyFour)
        .padding(.vertical, Theme.Spacing.twelve)
        .background(Theme.Colors.card)
    }

    private var captureSummary: String {
        guard let capture = session.captureArtifact else {
            return session.instances.isEmpty
                ? "Add the TrackSmith Audio Unit in Logic to capture playback."
                : "No capture attached. Tutor can still teach from your description and reviewed knowledge."
        }
        return String(
            format: "Current immutable capture %@ · %.1f s · %.0f Hz · %d ch · local measurements are not model listening",
            String(capture.id.uuidString.prefix(8)),
            Double(capture.frameCount) / capture.sampleRate,
            capture.sampleRate,
            capture.channelCount
        )
    }

    private func evidenceColor(_ kind: TutorEvidenceKind) -> Color {
        switch kind {
        case .heardByModel: .green
        case .locallyMeasured: .blue
        case .logicObserved: .purple
        case .userReported: .cyan
        case .reviewedKnowledge: .indigo
        case .inference: .orange
        case .unavailable: .gray
        }
    }
}
