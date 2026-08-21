import PlanSchema
import SwiftUI
import TutorConversation

struct TutorConversationView: View {
    @ObservedObject var session: CompanionSessionModel
    @ObservedObject var tutor: TutorConversationSessionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingHistoryDeletion = false
    @State private var contextExpanded = false
    @State private var experimentDetailsExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            compactHeader
            transcript
            composer
        }
        .background(Theme.Colors.canvas)
        .confirmationDialog("Delete all Tutor history?", isPresented: $confirmingHistoryDeletion, titleVisibility: .visible) {
            Button("Delete Transcript, Experiments, and Receipts", role: .destructive) { tutor.deleteAllHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes local Tutor history and receipts, not captures, previews, Logic projects, or source audio.")
        }
    }

    private var compactHeader: some View {
        VStack(spacing: Theme.Spacing.eight) {
            HStack(spacing: Theme.Spacing.twelve) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TUTOR").font(Theme.Font.kicker).foregroundStyle(Theme.Colors.accentBright)
                    Text("A considered second pair of ears")
                        .font(Theme.Font.section).foregroundStyle(Theme.Colors.text)
                }
                Spacer()
                Menu {
                    Picker("Explanation level", selection: Binding(
                        get: { session.tutorExperienceLevel },
                        set: { session.setTutorExperienceLevel($0) }
                    )) {
                        ForEach(TutorExperienceLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }
                } label: {
                    Text(session.tutorExperienceLevel.label)
                        .font(Theme.Font.meta.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.eight).padding(.vertical, Theme.Spacing.legacy5)
                        .background(Theme.Colors.control, in: Capsule())
                }
                .accessibilityLabel("Tutor explanation level: \(session.tutorExperienceLevel.label)")
                .accessibilityHint("Changes scaffolding for future responses only")
                statusPill
                Menu {
                    Picker("Source", selection: $session.sourceType) {
                        ForEach(SourceType.allCases, id: \.self) { Text(sourceLabel($0)).tag($0) }
                    }
                    Button("Capture Recent Playback", systemImage: "waveform.badge.magnifyingglass") { session.captureRecent() }
                        .disabled(session.selectedInstanceID == nil || session.isBusy)
                    Toggle("Attach local capture context", isOn: $tutor.attachCurrentCapture)
                    if session.captureArtifact != nil {
                        Toggle("Request audio-model listening next turn", isOn: $tutor.requestModelListening)
                    }
                    Divider()
                    Button("New Conversation", systemImage: "plus.bubble") { tutor.startNewConversation() }
                    Button("Grant Read-Only Accessibility", systemImage: "eye") { tutor.requestAccessibilityAccess() }
                    Button("Delete All Tutor History", systemImage: "trash", role: .destructive) { confirmingHistoryDeletion = true }
                } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28)
                }
                .accessibilityLabel("Tutor context and actions")
            }
            Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { contextExpanded.toggle() } } label: {
                HStack(spacing: Theme.Spacing.eight) {
                    Circle().fill(session.statusColor).frame(width: 7, height: 7)
                    Text(captureSummary).lineLimit(1)
                    Spacer()
                    Image(systemName: contextExpanded ? "chevron.up" : "chevron.down")
                }
                .font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture and evidence status")
            if contextExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                    Label("\(tutor.activity)", systemImage: tutor.isStreaming ? "ellipsis.message" : "checkmark.circle")
                    Text("Local measurement is not model listening. Audio is sent only with separate consent and an exact capture hash.")
                    Text(tutor.logicStatus)
                }
                .font(Theme.Font.meta).foregroundStyle(Theme.Colors.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Theme.Spacing.twentyFour).padding(.vertical, Theme.Spacing.twelve)
        .background(Theme.Colors.header)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.hairline).frame(height: 1) }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Image(systemName: tutor.isStreaming ? "waveform" : "waveform.path.ecg")
            Text(tutor.isStreaming ? "Thinking" : "Ready")
        }
        .font(Theme.Font.meta.weight(.semibold)).foregroundStyle(Theme.Colors.secondaryText)
        .padding(.horizontal, Theme.Spacing.eight).padding(.vertical, Theme.Spacing.legacy5)
        .background(Theme.Colors.control, in: Capsule())
        .accessibilityLabel(tutor.isStreaming ? "Tutor is responding" : "Tutor is ready")
    }

    private var transcript: some View {
        ScrollView {
            // Tutor history is bounded to 240 messages. Eager layout avoids the
            // lazy-stack estimate cycle observed during manual transcript scrolling.
            VStack(alignment: .leading, spacing: Theme.Spacing.twentyFour) {
                if tutor.state.messages.isEmpty { welcome }
                ForEach(tutor.state.messages) { message in
                    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.twelve) {
                        messageBubble(message)
                        if let id = message.experimentID, let experiment = tutor.state.experiments.first(where: { $0.id == id }) { experimentCard(experiment) }
                    }
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                }
                if tutor.isStreaming { streamingBubble }
            }
            .frame(maxWidth: 850, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.twentyFour).padding(.vertical, Theme.Spacing.twentyFour)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sixteen) {
            Text("What are you noticing?").font(Theme.Font.hero)
            Text("Describe the moment. I’ll keep the next move small, show the evidence I used, and leave every edit in your hands.")
                .font(Theme.Font.body).foregroundStyle(Theme.Colors.secondaryText).frame(maxWidth: 520, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                HStack { starter("My vocal is muddy in the mix"); starter("Why is my chorus smaller?"); starter("Teach compression by ear") }
                VStack(alignment: .leading) { starter("My vocal is muddy in the mix"); starter("Why is my chorus smaller?"); starter("Teach compression by ear") }
            }
        }
        .padding(Theme.Spacing.twentyFour).frame(maxWidth: 680, alignment: .leading)
        .background(Theme.Colors.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large).stroke(Theme.Colors.hairline))
    }

    private func starter(_ text: String) -> some View {
        Button(text) { tutor.composer = text }.buttonStyle(.bordered).accessibilityHint("Places this idea in the Tutor composer")
    }

    private func messageBubble(_ message: TutorConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            Text(message.role == .assistant ? "TRACKSMITH" : "YOU").font(Theme.Font.kicker).foregroundStyle(message.role == .assistant ? Theme.Colors.accentBright : Theme.Colors.mutedText)
            Text(message.text).font(Theme.Font.body).foregroundStyle(Theme.Colors.text).textSelection(.enabled)
            if !message.evidence.isEmpty {
                DisclosureGroup("Evidence and limits") { evidenceDetails(message.evidence) }
                    .font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
            }
            if message.status != .complete { Label(message.status.rawValue.capitalized, systemImage: "exclamationmark.circle").font(Theme.Font.meta).foregroundStyle(.orange) }
        }
        .padding(Theme.Spacing.sixteen).frame(maxWidth: message.role == .user ? 580 : 720, alignment: .leading)
        .background(message.role == .user ? Theme.Colors.userMessage : Theme.Colors.assistantMessage, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large).stroke(Theme.Colors.hairline))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message.role == .assistant ? "Tutor response" : "Your message")
    }

    private func evidenceDetails(_ evidence: [TutorEvidenceReference]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            ForEach(Array(evidence.prefix(8))) { item in
                HStack(alignment: .top, spacing: Theme.Spacing.legacy6) {
                    Circle().fill(evidenceColor(item.kind)).frame(width: 6, height: 6).padding(.top, 4)
                    Text("\(item.kind.compactLabel): \(item.detail)")
                }
            }
        }.padding(.top, Theme.Spacing.eight)
    }

    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack { ProgressView().controlSize(.small); Text(tutor.activity).font(Theme.Font.meta) }
            if !tutor.streamingText.isEmpty { Text(tutor.streamingText).font(Theme.Font.body).textSelection(.enabled) }
            if let fallback = tutor.fallbackNotice { Label(fallback, systemImage: "wifi.slash").font(Theme.Font.meta).foregroundStyle(.orange) }
        }
        .padding(Theme.Spacing.sixteen).frame(maxWidth: 720, alignment: .leading)
        .background(Theme.Colors.assistantMessage, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        .accessibilityLabel("Tutor is responding")
    }

    private func experimentCard(_ experiment: TutorExperimentRecord) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            HStack { Label("ONE SMALL EXPERIMENT", systemImage: "sparkles").font(Theme.Font.kicker).foregroundStyle(Theme.Colors.accentBright); Spacer(); Text("You stay in control").font(Theme.Font.meta).foregroundStyle(Theme.Colors.mutedText) }
            Text(experiment.draft.title).font(Theme.Font.section)
            experimentRow("Try", "\(experiment.draft.action) Start: \(experiment.draft.startingRange)")
            experimentRow("Listen for", experiment.draft.listenFor)
            DisclosureGroup("Where, why, risk, and undo", isExpanded: $experimentDetailsExpanded) {
                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    experimentRow("Where", experiment.draft.logicLocation); experimentRow("Why", experiment.draft.why)
                    experimentRow("Risk", experiment.draft.risk); experimentRow("Undo", experiment.draft.undo)
                }.padding(.top, Theme.Spacing.eight)
            }.font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
            if experiment.comparisonAuthority != nil, experiment.outcome == nil {
                Toggle("My edit is upstream of TrackSmith and the follow-up capture contains its signal", isOn: tutor.signalPathConfirmationBinding(for: experiment.id))
                    .font(Theme.Font.meta).toggleStyle(.checkbox)
                    .accessibilityHint("Required for a bounded local measurement comparison, not a listening claim.")
            }
            if let comparison = experiment.waveformComparison { comparisonDetail(comparison) }
            HStack(spacing: Theme.Spacing.eight) {
                Button("Show Me", systemImage: "scope") { tutor.showMe(experiment) }.accessibilityHint("Shows a read-only Logic overlay when available")
                Button("Listen Again", systemImage: "waveform.badge.magnifyingglass") { session.captureRecent() }
                    .disabled(session.selectedInstanceID == nil || session.isBusy)
                    .accessibilityHint("Captures recent playback for an optional bounded follow-up measurement")
                if experiment.outcome == nil {
                    Menu("What changed?") {
                        Button("Better") { tutor.submitOutcome(experiment: experiment, outcome: .better, session: session) }
                        Button("Worse") { tutor.submitOutcome(experiment: experiment, outcome: .worse, session: session) }
                        Button("No change") { tutor.submitOutcome(experiment: experiment, outcome: .noChange, session: session) }
                        Button("Not sure") { tutor.submitOutcome(experiment: experiment, outcome: .notSure, session: session) }
                        Button("Can't find it") { tutor.submitOutcome(experiment: experiment, outcome: .cannotFind, session: session) }
                    }
                } else { Label("You reported: \(experiment.outcome!.rawValue)", systemImage: "person.fill.checkmark") }
                Spacer()
                Button("Dismiss", systemImage: "xmark") { tutor.dismissCallout() }.labelStyle(.iconOnly).accessibilityLabel("Dismiss Show Me callout")
            }.buttonStyle(.bordered)
        }
        .padding(Theme.Spacing.sixteen).frame(maxWidth: 760, alignment: .leading)
        .background(Theme.Colors.experimentSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large).stroke(Theme.Colors.accent.opacity(0.45)))
    }

    private func comparisonDetail(_ comparison: TutorWaveformComparison) -> some View {
        DisclosureGroup { VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(comparison.reason)
            ForEach(comparison.measurementDeltas ?? []) { delta in Text("\(delta.identifier): \(delta.before, specifier: "%.3f") → \(delta.after, specifier: "%.3f") (Δ \(delta.delta, specifier: "%+.3f") \(delta.unit))") }
        }.font(Theme.Font.data).padding(.top, Theme.Spacing.four) } label: {
            Label(comparison.available ? "Bounded local measurement delta" : "Comparison unavailable", systemImage: comparison.available ? "chart.line.uptrend.xyaxis" : "exclamationmark.triangle")
                .font(Theme.Font.meta).foregroundStyle(comparison.available ? Theme.Colors.evidenceAvailable : Theme.Colors.evidenceUnavailable)
        }
    }

    private func experimentRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.eight) { Text(label).font(Theme.Font.meta.weight(.semibold)).frame(width: 68, alignment: .leading); Text(value).font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText) }
    }

    private var composer: some View {
        VStack(spacing: Theme.Spacing.eight) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.twelve) {
                TextField("What changed, or what do you want to understand?", text: $tutor.composer)
                    .textFieldStyle(.plain).font(Theme.Font.body).onSubmit { tutor.send(session: session) }
                    .accessibilityLabel("Tutor question")
                if tutor.isStreaming { Button("Cancel", role: .cancel) { tutor.cancel() }.buttonStyle(.bordered) }
                else { Button("Send", systemImage: "arrow.up") { tutor.send(session: session) }.buttonStyle(.borderedProminent).disabled(tutor.composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityHint("Sends your question to Tutor") }
            }
            HStack { Text("Optional goal").font(Theme.Font.meta); TextField("Keep the vocal natural", text: $tutor.projectGoal).textFieldStyle(.plain).font(Theme.Font.meta); Spacer(); Text("No Logic edits are made by Tutor").font(Theme.Font.meta).foregroundStyle(Theme.Colors.mutedText) }
        }
        .padding(Theme.Spacing.twelve).background(Theme.Colors.composer, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        .padding(.horizontal, Theme.Spacing.twentyFour).padding(.vertical, Theme.Spacing.twelve)
        .background(Theme.Colors.header).overlay(alignment: .top) { Rectangle().fill(Theme.Colors.hairline).frame(height: 1) }
    }

    private var captureSummary: String { guard let capture = session.captureArtifact else { return session.instances.isEmpty ? "No TrackSmith capture available" : "No capture attached — Tutor can still work from your report" }; return "Capture \(capture.id.uuidString.prefix(6)) · \(String(format: "%.1fs", Double(capture.frameCount) / capture.sampleRate)) · local evidence" }
    private func evidenceColor(_ kind: TutorEvidenceKind) -> Color { switch kind { case .heardByModel: .green; case .locallyMeasured: .blue; case .logicObserved: .purple; case .userReported: .cyan; case .reviewedKnowledge: .indigo; case .candidateKnowledge: .yellow; case .separatedSourceEstimate: .teal; case .structureEstimate: .mint; case .inference: .orange; case .unavailable: .gray } }
}
