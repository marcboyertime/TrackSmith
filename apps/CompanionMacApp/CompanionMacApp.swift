import AgentCore
import PlanSchema
import PreviewWorkflow
import SharedIPC
import SwiftUI

@main
struct CompanionMacApp: App {
    var body: some Scene {
        WindowGroup { CompanionContentView() }
            .defaultSize(width: 1_120, height: 760)
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
    @StateObject private var model = CompanionSessionModel()
    @StateObject private var tutor = TutorSessionModel()
    @State private var mode: CompanionMode = .guideMe
    @State private var confirmingCacheDeletion = false

    var body: some View {
        NavigationSplitView {
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
                                .font(Theme.Font.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .tag(instance.id)
                    }
                }
            }
            .navigationTitle("Sessions")
            .frame(minWidth: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy18) {
                    StatusHeaderView(model: model)
                    ModeSelectorView(mode: $mode)
                    CapturePanelView(model: model)
                    ProviderPanelView(model: model)
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
            .navigationTitle("TrackSmith")
        }
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
