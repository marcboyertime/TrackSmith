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
            .defaultSize(width: 1_120, height: 760)
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
        NavigationSplitView {
            VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                List {
                    Section("Mode") {
                        ForEach(CompanionMode.allCases) { candidate in
                            Button {
                                mode = candidate
                            } label: {
                                Text(candidate.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, Theme.Spacing.four)
                                    .padding(.horizontal, Theme.Spacing.eight)
                                    .background(
                                        mode == candidate
                                            ? Theme.Colors.accentSelection
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(mode == candidate ? .isSelected : [])
                        }
                    }
                }
                .listStyle(.sidebar)
                .accessibilityLabel("TrackSmith mode")

                Divider()

                Text("Sessions")
                    .font(Theme.Font.meta)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Spacing.twelve)

                List(selection: $model.selectedInstanceID) {
                    Section("Logic Audio Units") {
                        if model.instances.isEmpty {
                            ContentUnavailableView(
                                "No active insert",
                                systemImage: "waveform.slash",
                                description: Text("Insert TrackSmith on a track and play audio.")
                            )
                        }
                        ForEach(model.instances) { instance in
                            VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                                Text(instance.contextName ?? "TrackSmith")
                                Text(instanceSummary(instance))
                                    .font(instanceSummaryIsMeasured(instance) ? Theme.Font.data : Theme.Font.meta)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(instance.id)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("TrackSmith")
            .frame(minWidth: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy18) {
                    Text(mode.subtitle)
                        .font(Theme.Font.meta)
                        .foregroundStyle(.secondary)
                    StatusHeaderView(model: model)
                    CapturePanelView(model: model)
                    ProviderStatusRowView(model: model)
                    switch mode {
                    case .guideMe:
                        TutorGuideView(session: model, tutor: tutor)
                    case .createForMe:
                        PromptPanelView(model: model)
                        PreviewPanelView(model: model)
                        RevisionPanelView(model: model)
                        ChangeStackView(model: model)
                        ActionBarView(model: model)
                    }
                }
                .padding(Theme.Spacing.legacy22)
            }
            .navigationTitle(mode.title)
        }
        .background(Theme.Colors.canvas)
        .task { model.start() }
        .onChange(of: model.providerSelection) { _, _ in
            model.refreshCredentialStatus()
        }
        .toolbar {
            Button("Delete Local Audio Cache", systemImage: "trash", role: .destructive) {
                confirmingCacheDeletion = true
            }
            .disabled(model.isBusy)
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
}
