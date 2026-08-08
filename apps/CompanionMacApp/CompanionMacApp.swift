import AgentCore
import PlanSchema
import PreviewWorkflow
import SharedIPC
import SwiftUI

@main
struct CompanionMacApp: App {
    @StateObject private var model = CompanionSessionModel()

    var body: some Scene {
        WindowGroup {
            CompanionContentView(model: model)
                .environment(\.colorScheme, .dark)
                .tint(Theme.Colors.accent)
                .groupBoxStyle(InstrumentGroupBoxStyle())
        }
            .defaultSize(width: 980, height: 760)
        Settings {
            SettingsView(model: model)
                .environment(\.colorScheme, .dark)
                .tint(Theme.Colors.accent)
                .groupBoxStyle(InstrumentGroupBoxStyle())
        }
    }
}

enum CompanionMode: String, CaseIterable, Identifiable {
    case guideMe
    case createForMe

    var id: String { rawValue }
    var title: String {
        switch self {
        case .guideMe: "Guide Me"
        case .createForMe: "Create For Me"
        }
    }
    var subtitle: String {
        switch self {
        case .guideMe: "TrackSmith tells you exactly what to try in Logic, step by step. You perform every action."
        case .createForMe: "TrackSmith renders bounded processing alternatives you audition, revise, and commit explicitly."
        }
    }
}

struct CompanionContentView: View {
    @ObservedObject var model: CompanionSessionModel
    @StateObject private var tutor = TutorSessionModel()
    @State private var mode: CompanionMode = .guideMe
    @State private var confirmingCacheDeletion = false

    var body: some View {
        VStack(spacing: 0) {
            topChrome
            Divider().overlay(Theme.Colors.hairline)
            Group {
                switch mode {
                case .guideMe:
                    TutorGuideView(session: model, tutor: tutor)
                case .createForMe:
                    ScrollView {
                        createWorkspace
                    }
                }
            }
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.canvas)
        .task { model.start() }
        .onChange(of: model.providerSelection) { _, _ in
            model.refreshCredentialStatus()
        }
        .confirmationDialog(
            "Delete all cached audio?",
            isPresented: $confirmingCacheDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Captures and Previews", role: .destructive) {
                model.deleteAllCachedAudio()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes local captured WAVs and rendered previews. It does not alter Logic projects, source audio, plug-in state, or protocol diagnostics.")
        }
    }

    private var topChrome: some View {
        HStack(spacing: Theme.Spacing.twelve) {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                Text("TrackSmith")
                    .font(Theme.Font.section)
                    .foregroundStyle(Theme.Colors.text)
                Text("Logic companion")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }
            Picker("Mode", selection: $mode) {
                ForEach(CompanionMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 245)
            .accessibilityLabel("TrackSmith mode")

            Spacer(minLength: Theme.Spacing.eight)

            activeInsertPicker

            SettingsLink {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
            .buttonStyle(.bordered)

            Menu {
                Button("Delete Local Audio Cache", systemImage: "trash", role: .destructive) {
                    confirmingCacheDeletion = true
                }
                .disabled(model.isBusy)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("More actions")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, Theme.Spacing.twentyFour)
        .padding(.vertical, Theme.Spacing.twelve)
        .background(Theme.Colors.card)
    }

    @ViewBuilder
    private var activeInsertPicker: some View {
        if model.instances.isEmpty {
            Label("No active insert", systemImage: "waveform.slash")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
                .help("Insert TrackSmith on a Logic channel, then play audio.")
                .accessibilityLabel("No active TrackSmith insert. Insert TrackSmith on a Logic channel, then play audio.")
        } else {
            Picker("Active insert", selection: $model.selectedInstanceID) {
                Text("Choose an insert").tag(Optional<UUID>.none)
                ForEach(model.instances) { instance in
                    Text("\(instance.contextName ?? "TrackSmith") — \(instanceSummary(instance))")
                        .tag(Optional(instance.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 270)
            .accessibilityLabel("Active TrackSmith insert")
            .help("Choose the Logic insert that will receive the next capture.")
        }
    }

    private var createWorkspace: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy18) {
            Text(mode.subtitle)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            CapturePanelView(model: model)
            PromptPanelView(model: model)
            PreviewPanelView(model: model)
            RevisionPanelView(model: model)
            ChangeStackView(model: model)
            ActionBarView(model: model)
        }
        .padding(Theme.Spacing.twentyFour)
    }
}
