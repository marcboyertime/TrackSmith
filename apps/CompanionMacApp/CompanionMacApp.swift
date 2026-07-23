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

struct CompanionContentView: View {
    @StateObject private var model = CompanionSessionModel()
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
                        VStack(alignment: .leading, spacing: 3) {
                            Text(instance.contextName ?? "TrackSmith")
                            Text(instanceSummary(instance))
                                .font(.caption.monospacedDigit())
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
                VStack(alignment: .leading, spacing: 18) {
                    statusHeader
                    capturePanel
                    providerPanel
                    promptPanel
                    previewPanel
                    revisionPanel
                    changeStack
                    actionBar
                }
                .padding(22)
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

    private var statusHeader: some View {
        HStack(spacing: 10) {
            Circle().fill(model.statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.status).font(.headline)
                Text(model.detailStatus).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let peak = model.activeSessionInstance?.inputPeakDBFS {
                Text(String(format: "Input %+.1f dBFS", peak))
                    .font(.caption.monospacedDigit())
            }
            Text(model.providerSelection.usesCloud
                 ? "Text context only · no audio upload"
                 : "Local interpretation · no network")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var providerPanel: some View {
        GroupBox("Production Intelligence") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Provider", selection: $model.providerSelection) {
                        ForEach(CompanionProviderSelection.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .frame(width: 300)
                    Text(model.activeProviderDescription)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if model.providerSelection.usesCloud {
                    Toggle(
                        "Allow this request's labeled text context and measurements to be sent to the selected cloud provider",
                        isOn: $model.cloudReasoningConsent
                    )
                    Text("Captured audio is never uploaded. Provider output is untrusted, schema-validated, capability-checked, state-resolved, and converted to local deterministic DSP only after every gate passes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        SecureField("Provider API credential", text: $model.credentialDraft)
                            .textFieldStyle(.roundedBorder)
                        Button("Save to Keychain") { model.saveProviderCredential() }
                            .disabled(model.credentialDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Remove", role: .destructive) { model.deleteProviderCredential() }
                    }
                    Text(model.credentialStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.providerSelection == .appleOnDevice {
                    Text("Apple's system language model interprets bounded labeled context entirely on this Mac. It uses no API key, receives no raw audio, and has no authority over DSP or Logic state. \(model.credentialStatus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("The deterministic offline provider remains available when credentials, consent, networking, or a cloud provider are unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !model.restoredConversationStatus.isEmpty {
                    Text(model.restoredConversationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var capturePanel: some View {
        GroupBox("Captured plug-in input") {
            VStack(alignment: .leading, spacing: 12) {
                WaveformView(samples: model.waveform)
                    .frame(height: 165)
                HStack {
                    Picker("Source", selection: $model.sourceType) {
                        ForEach(SourceType.allCases, id: \.self) { type in
                            Text(sourceLabel(type)).tag(type)
                        }
                    }
                    .frame(width: 220)
                    Button("Analyze Recent Playback") { model.captureRecent() }
                        .disabled(model.selectedInstanceID == nil || model.isBusy)
                    if let capture = model.captureArtifact {
                        Text(String(format: "%.1f s · %.0f Hz · %d ch",
                                    Double(capture.frameCount) / capture.sampleRate,
                                    capture.sampleRate,
                                    capture.channelCount))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if let interpretation = model.interpretedIntent {
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Validated interpretation")
                            .font(.subheadline.weight(.semibold))
                        Text("Change: \(intentList(interpretation.desiredChanges))")
                        Text("Preserve: \(intentList(interpretation.preservedAttributes))")
                        Text("Prohibit: \(intentList(interpretation.prohibitedChanges))")
                        if !interpretation.unresolvedAmbiguities.isEmpty {
                            Text("Uncertainty: \(interpretation.unresolvedAmbiguities.prefix(2).joined(separator: " "))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if !model.displayedHypotheses.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Grounded production hypotheses")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(model.displayedHypotheses.enumerated()), id: \.offset) { index, hypothesis in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(index + 1). \(hypothesis.intendedPerceptualChange)")
                                Text("Strategy: \(hypothesis.processingOptionsConsidered.map(\.rawValue).joined(separator: ", "))")
                                if let risk = hypothesis.risks.first {
                                    Text("Risk: \(risk)")
                                }
                                if hypothesis.subjectiveListeningRemainsDecisive {
                                    Text("Listening remains decisive")
                                }
                            }
                            .padding(.bottom, 3)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if !model.displayedEvidence.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Relevant measured evidence")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(model.displayedEvidence.enumerated()), id: \.offset) { _, observation in
                            Text(evidenceText(observation))
                                .font(.caption.monospaced())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                if let provider = model.providerEvidenceSummary,
                   let audit = model.validationAuditSummary {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Provider evidence")
                            .font(.subheadline.weight(.semibold))
                        Text(provider).textSelection(.enabled)
                        Text(audit)
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var promptPanel: some View {
        GroupBox("Production request") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Describe the result", text: $model.prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                HStack {
                    ForEach(["Clearer and controlled", "Warmer, not darker", "Punchier without increasing harshness"], id: \.self) { chip in
                        Button(chip) { model.prompt = chip }
                            .buttonStyle(.borderless)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                    Button("Create 3 Previews") { model.generatePreviews() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.captureArtifact == nil || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder private var previewPanel: some View {
        GroupBox("Level-matched preview variants") {
            if model.previewManifest != nil {
                HStack(spacing: 10) {
                    PreviewCard(
                        title: "Original",
                        subtitle: "Unprocessed capture",
                        selected: model.selectedAuditionIndex == 0,
                        warning: nil
                    ) { model.selectAudition(index: 0) }
                    ForEach(Array(model.auditionVariants.enumerated()), id: \.element.previewID) { index, variant in
                        PreviewCard(
                            title: variant.strength.rawValue.capitalized,
                            subtitle: variant.status == .valid
                                ? String(format: "%+.2f dB match", variant.loudnessMatchGainDB)
                                : "Rejected",
                            selected: model.selectedAuditionIndex == index + 1,
                            warning: variant.warnings.first ?? variant.rejectionReasons.first,
                            working: model.workingPlanIsVariant(variant),
                            useAction: { model.useVariantAsWorking(index: index + 1) }
                        ) { model.selectAudition(index: index + 1) }
                    }
                    if let revision = model.workingPreview,
                       let workingIndex = model.workingAuditionIndex {
                        PreviewCard(
                            title: "Working Revision",
                            subtitle: String(format: "%+.2f dB match", revision.loudnessMatchGainDB),
                            selected: model.selectedAuditionIndex == workingIndex,
                            warning: revision.warnings.first,
                            working: true
                        ) { model.selectWorkingAudition() }
                    }
                }
                .padding(8)
            } else {
                Text("Capture recent playback, describe the result, then render three deterministic options.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
            }
        }
    }

    private var revisionPanel: some View {
        GroupBox("Conversational revision") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Revise the current working plan", text: $model.revisionPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                HStack {
                    ForEach(["Use less compression", "Undo only the compression", "Lock the EQ", "Remove the compression"], id: \.self) { chip in
                        Button(chip) { model.revisionPrompt = chip }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                    Button("Render Revision") { model.previewRevision() }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            model.selectedPlan == nil
                                || model.revisionPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.isBusy
                        )
                }
                Text("Edits derive from structured working state. Unmentioned production nodes and every locked node remain intact; measured preview gain is recalibrated after audio changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    @ViewBuilder private var changeStack: some View {
        GroupBox("Editable working plan") {
            if let plan = model.selectedPlan, !plan.nodes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(plan.nodes) { node in
                        ChangeCard(
                            node: node,
                            isBusy: model.isBusy,
                            setEnabled: { model.setNodeEnabled(nodeID: node.id, enabled: $0) },
                            setLocked: { model.setNodeLocked(nodeID: node.id, locked: $0) }
                        )
                    }
                }
                .padding(8)
            } else {
                Text("Choose a preview as the working plan to inspect and edit its complete graph.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
                    .padding(8)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button(model.isPlaying ? "Pause" : "Play") { model.togglePlayback() }
                .disabled(model.previewManifest == nil)
            Button("Rewind") { model.rewind() }
                .disabled(model.previewManifest == nil)
            Text("A/B switching stays sample-synchronized")
                .font(.caption)
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

    private func instanceSummary(_ instance: PluginInstanceRecord) -> String {
        guard let sampleRate = instance.sampleRate, let channels = instance.channelCount else {
            return "Waiting for host audio format"
        }
        return "\(Int(sampleRate)) Hz · \(channels == 1 ? "mono" : "stereo")"
    }

    private func intentList(_ goals: [InterpretedProductionGoal]) -> String {
        goals.isEmpty
            ? "none"
            : goals.map { "\($0.direction.rawValue) \($0.term.rawValue)" }.joined(separator: ", ")
    }

    private func evidenceText(_ observation: ProductionEvidenceObservation) -> String {
        let identifier = observation.metricIdentifier ?? "no measured metric"
        let measured: String
        if let value = observation.value {
            measured = String(format: "%.4g %@", value, observation.unit ?? "")
                .trimmingCharacters(in: .whitespaces)
        } else {
            measured = "unavailable"
        }
        return "\(identifier): \(measured) · confidence \(Int((observation.confidence * 100).rounded()))% · \(observation.relationship.rawValue)"
    }

    private func sourceLabel(_ type: SourceType) -> String {
        switch type {
        case .vocal: "Vocal"
        case .vocalBus: "Vocal bus"
        case .drums: "Drums"
        case .drumBus: "Drum bus"
        case .bass: "Bass"
        case .guitar: "Guitar"
        case .keyboard: "Keyboard"
        case .synth: "Synth"
        case .fullMix: "Full mix"
        case .reference: "Reference"
        case .unknown: "Unknown"
        }
    }
}

private struct PreviewCard: View {
    var title: String
    var subtitle: String
    var selected: Bool
    var warning: String?
    var working = false
    var useAction: (() -> Void)?
    var action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title).font(.headline)
                        if working {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Working plan")
                        }
                    }
                    Text(subtitle).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if let warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 75, alignment: .leading)
                .padding(10)
                .background(selected ? Color.accentColor.opacity(0.17) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            if let useAction {
                Button(working ? "Working Plan" : "Use as Working") { useAction() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .disabled(working)
            }
        }
    }
}

private struct ChangeCard: View {
    var node: ProcessingNode
    var isBusy: Bool
    var setEnabled: (Bool) -> Void
    var setLocked: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(node.type.rawValue).font(.headline)
                Text(node.category.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Toggle("Enabled", isOn: Binding(
                    get: { node.enabled },
                    set: { enabled in setEnabled(enabled) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isBusy || node.locked)
                Button(node.locked ? "Unlock" : "Lock") { setLocked(!node.locked) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
                Text(String(format: "%.0f%% confidence", node.confidence * 100))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if !node.parameters.isEmpty {
                Text(node.parameters.sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { "\($0.key.rawValue): \(String(format: "%.2f", $0.value))" }
                    .joined(separator: "   "))
                    .font(.caption.monospacedDigit())
            }
            Text(node.rationale).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WaveformView: View {
    var samples: [Float]

    var body: some View {
        Canvas { context, size in
            let middle = size.height / 2
            var center = Path()
            center.move(to: CGPoint(x: 0, y: middle))
            center.addLine(to: CGPoint(x: size.width, y: middle))
            context.stroke(center, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
            guard samples.count > 1 else { return }
            var path = Path()
            for index in samples.indices {
                let x = CGFloat(index) / CGFloat(samples.count - 1) * size.width
                let amplitude = CGFloat(min(max(samples[index], -1), 1))
                let y = middle - amplitude * middle * 0.88
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 1.2)
        }
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if samples.isEmpty {
                Text("Waveform appears after captured playback").foregroundStyle(.secondary)
            }
        }
    }
}
