import AgentCore
import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema
import ProductionIntelligence
import PreviewAudition
import PreviewWorkflow
import SessionCore
import SharedIPC
import SwiftUI

enum CompanionProviderSelection: String, CaseIterable, Identifiable {
    case offline
    case appleOnDevice
    case openAI
    case gemini

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .offline: "Offline deterministic"
        case .appleOnDevice: "Apple On-Device"
        case .openAI: "OpenAI"
        case .gemini: "Google Gemini"
        }
    }
    var credentialIdentifier: ProviderCredentialIdentifier? {
        switch self {
        case .offline, .appleOnDevice: nil
        case .openAI: .openAI
        case .gemini: .gemini
        }
    }

    var usesCloud: Bool { self == .openAI || self == .gemini }
}

@MainActor
final class CompanionSessionModel: ObservableObject {
    @Published var instances: [PluginInstanceRecord] = []
    /// Sidebar selection is navigation state only. SwiftUI may transiently set
    /// it to nil while reconciling heartbeat updates, so it must never own or
    /// discard an immutable capture transaction.
    @Published var selectedInstanceID: UUID?
    @Published var sourceType: SourceType = .vocal
    @Published var prompt = "Make this clearer, warmer, and more controlled without sounding overprocessed"
    @Published var revisionPrompt = "Use less compression"
    @Published var providerSelection: CompanionProviderSelection = .offline
    @Published var cloudReasoningConsent = false
    @Published var credentialDraft = ""
    @Published var credentialStatus = "No cloud credential is being used"
    @Published var productionOutcome: ProductionIntelligenceOutcome?
    @Published var sourceAwareAnalysis: SourceAwareAnalysisReport?
    @Published var restoredConversationStatus = ""
    @Published var status = "Connecting to the shared Audio Unit session"
    @Published var detailStatus = "Captured audio is never uploaded. Cloud reasoning stays off until a provider is selected and consent is enabled."
    @Published var statusColor: Color = .orange
    @Published var captureArtifact: CaptureArtifact?
    @Published var waveform: [Float] = []
    @Published var previewManifest: PreviewSessionManifest?
    @Published var selectedAuditionIndex = 0
    @Published var isPlaying = false
    @Published var isBusy = false
    @Published var basePlan: ProcessingPlan?
    @Published var workingPlan: ProcessingPlan?
    @Published var workingPreview: PreviewVariantManifest?
    @Published var isGlobalBypassed = false
    @Published private(set) var canUndoWorking = false
    @Published private(set) var canRedoWorking = false

    var activeProviderDescription: String {
        switch providerSelection {
        case .offline: "Offline · deterministic parser"
        case .appleOnDevice: "Apple On-Device · system language model"
        case .openAI: "OpenAI · gpt-5.6-sol"
        case .gemini: "Google Gemini · gemini-3.6-flash"
        }
    }

    var interpretedIntent: ProductionIntentInterpretation? {
        productionOutcome?.validatedInterpretation.interpretation
    }

    var displayedHypotheses: [ProductionHypothesis] {
        productionOutcome?.productionResult.hypotheses ?? []
    }

    /// A compact, de-duplicated view of the structured evidence TrackSmith used
    /// to form the current hypotheses. This is measured/typed evidence, not
    /// provider reasoning or hidden chain-of-thought.
    var displayedEvidence: [ProductionEvidenceObservation] {
        var seen = Set<String>()
        var observations: [ProductionEvidenceObservation] = []
        for hypothesis in displayedHypotheses {
            for observation in hypothesis.evidenceSupportingIntervention
                + hypothesis.evidenceAgainstIntervention {
                guard observation.metricIdentifier != nil, observation.value != nil else { continue }
                let key = [
                    observation.relationship.rawValue,
                    observation.metricIdentifier ?? "unavailable",
                    observation.value.map { String(format: "%.9g", $0) } ?? "nil",
                ].joined(separator: "|")
                if seen.insert(key).inserted { observations.append(observation) }
                if observations.count == 10 { return observations }
            }
        }
        return observations
    }

    var providerEvidenceSummary: String? {
        guard let metadata = productionOutcome?.validatedInterpretation.metadata else { return nil }
        var parts = [
            metadata.providerIdentifier,
            "configured \(metadata.modelIdentifier)",
        ]
        if let reported = metadata.providerReportedModelIdentifier {
            parts.append("reported \(reported)")
        }
        if let responseID = metadata.providerResponseID { parts.append("response \(responseID)") }
        parts.append("\(metadata.attemptCount) attempt\(metadata.attemptCount == 1 ? "" : "s")")
        parts.append("\(metadata.latencyMilliseconds) ms")
        if let input = metadata.inputTokens, let output = metadata.outputTokens {
            parts.append("\(input) in / \(output) out tokens")
        }
        return parts.joined(separator: " · ")
    }

    var validationAuditSummary: String? {
        guard let audit = productionOutcome?.validatedInterpretation.audit else { return nil }
        return "Validated \(audit.completedStages.map(\.rawValue).joined(separator: " → "))"
    }

    var selectedInstance: PluginInstanceRecord? {
        instances.first { $0.id == selectedInstanceID }
    }

    /// Commit is intentionally decoupled from the currently audible A/B slot.
    /// The user may audition Original while the exact editable working graph
    /// remains the graph that Commit Working Plan will publish.
    var selectedPlan: ProcessingPlan? { workingPlan }

    /// Once a capture exists, all mutating controls remain bound to that exact
    /// AU runtime regardless of sidebar navigation. Before capture, the selected
    /// instance is the intended target for connection-level controls.
    var activeSessionInstance: PluginInstanceRecord? {
        if let capturedInstanceID, let capturedRuntimeEpoch {
            return instances.first {
                $0.id == capturedInstanceID && $0.runtimeEpoch == capturedRuntimeEpoch
            }
        }
        return selectedInstance
    }

    var auditionVariants: [PreviewVariantManifest] {
        previewManifest?.variants.filter { $0.status == .valid && $0.audioFileName != nil } ?? []
    }

    var workingAuditionIndex: Int? {
        guard workingPreviewURL != nil else { return nil }
        return auditionVariants.count + 1
    }

    var canToggleGlobalBypass: Bool {
        guard let activeSessionInstance else { return false }
        if isGlobalBypassed || activeSessionInstance.globalBypassEnabled == true { return true }
        return activeSessionInstance.currentPlan?.nodes.contains(where: \.enabled) == true
    }

    var capturedInstanceIsAvailable: Bool {
        guard let capturedInstanceID, let capturedRuntimeEpoch else { return false }
        return instances.contains {
            $0.id == capturedInstanceID && $0.runtimeEpoch == capturedRuntimeEpoch
        }
    }

    private let client: CompanionSessionClient?
    private let credentialStore = KeychainProviderCredentialStore()
    private let conversationStore: ProductionConversationStore?
    private var conversationState = ProductionConversationState()
    private let audition = SynchronizedAuditionEngine()
    private struct PendingRequest {
        var id: UUID
        var instanceID: UUID
        var runtimeEpoch: UUID
        var deadline: Date
        var expectation: AppliedCommandExpectation?
    }
    private enum CommitPurpose {
        case apply
        case revert
        case bypass
        case restore
    }
    private enum WorkingHistoryUpdate: Sendable {
        case appendCurrent
        case replace(undo: [ProcessingPlan], redo: [ProcessingPlan])
    }
    private var previewDirectory: URL?
    private var workingPreviewURL: URL?
    private var pollingTask: Task<Void, Never>?
    private var pendingCaptureRequest: PendingRequest?
    private var pendingCommitRequest: PendingRequest?
    private var pendingCommitPurpose: CommitPurpose = .apply
    private var activeCaptureOperationID: UUID?
    private var activeWorkingRenderID: UUID?
    private var activeProductionTurnID: UUID?
    /// Terminal failures remain visible long enough to be read and audited.
    /// The heartbeat scanner must not erase them on its next 350 ms refresh.
    private var failureStatusExpiresAt: Date?
    private var capturedInstanceID: UUID?
    private var capturedRuntimeEpoch: UUID?
    /// The exact AU graph observed when this capture transaction began, then
    /// advanced only after acknowledgement or heartbeat reconciliation.
    private var expectedCurrentPlan: ProcessingPlan?
    private var undoWorkingPlans: [ProcessingPlan] = []
    private var redoWorkingPlans: [ProcessingPlan] = []

    init() {
        conversationStore = try? ProductionConversationStore()
        do { client = try CompanionSessionClient(appGroup: .default) }
        catch {
            client = nil
            status = "Shared App Group unavailable"
            detailStatus = String(describing: error)
            statusColor = .red
        }
        restoreActiveConversation()
        refreshCredentialStatus()
    }

    deinit { pollingTask?.cancel() }

    func start() {
        guard pollingTask == nil, client != nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    func captureRecent() {
        guard !isBusy, let client, let instance = selectedInstance else { return }
        // Starting a new capture is the explicit transaction boundary that
        // replaces prior local capture and preview state.
        clearCapturedSession()
        beginNewConversation()
        isBusy = true
        status = "Requesting recent playback"
        detailStatus = "The plug-in is copying its bounded dry-input ring outside the audio thread."
        statusColor = .orange
        capturedInstanceID = instance.id
        capturedRuntimeEpoch = instance.runtimeEpoch
        expectedCurrentPlan = instance.currentPlan
        basePlan = instance.currentPlan
        let operationID = UUID()
        activeCaptureOperationID = operationID
        Task {
            do {
                guard captureOperationMatches(operationID, instance: instance) else { return }
                let id = try await client.requestRecentCapture(instance: instance)
                // The actor hop can outlive this transaction if the user starts
                // another capture. Only the operation that still owns the
                // captured instance may install its pending request. Sidebar
                // navigation is intentionally irrelevant to transaction state.
                guard captureOperationMatches(operationID, instance: instance) else { return }
                pendingCaptureRequest = PendingRequest(
                    id: id,
                    instanceID: instance.id,
                    runtimeEpoch: instance.runtimeEpoch,
                    deadline: Date(timeIntervalSinceNow: 35),
                    expectation: nil
                )
            } catch {
                guard captureOperationMatches(operationID, instance: instance) else { return }
                fail(error)
            }
        }
    }

    func generatePreviews() {
        guard !isBusy,
              let client,
              let artifact = captureArtifact,
              let capturedInstanceID,
              let capturedRuntimeEpoch else { return }
        isBusy = true
        status = providerSelection == .offline
            ? "Interpreting deterministically and rendering three options"
            : "Grounding the production request"
        detailStatus = switch providerSelection {
        case .offline:
            "Offline deterministic interpretation · local DSP · level-matched constraint checks"
        case .appleOnDevice:
            "On-device semantic interpretation · no credential or network · local deterministic DSP"
        case .openAI, .gemini:
            "Cloud receives labeled text context and measurements only—never captured audio"
        }
        statusColor = .orange
        let selectedProvider = providerSelection
        let consent = cloudReasoningConsent
        activeProductionTurnID = UUID()
        Task {
            do {
                let analysis = try await client.analyzeCapture(
                    artifact: artifact,
                    sourceType: sourceType
                )
                guard self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch,
                      self.captureArtifact?.id == artifact.id else {
                    throw ModelProviderFailure.staleResult
                }
                sourceAwareAnalysis = analysis
                let authority = productionAuthority(
                    artifact: artifact,
                    instanceID: capturedInstanceID,
                    runtimeEpoch: capturedRuntimeEpoch
                )
                let reconciled = ConversationStateReconciler().reconcile(
                    conversationState,
                    currentAuthority: authority,
                    // `expectedCurrentPlan` is the exact live-AU compare-and-swap
                    // authority and may still carry the snapshot identity from
                    // the capture that originally produced that committed graph.
                    // Conversation references belong to this immutable recent
                    // capture, so reconciliation must use the otherwise exact
                    // graph rebound to `artifact.id`.
                    currentCommittedPlan: basePlan ?? expectedCurrentPlan
                )
                let references = referenceRegistry(
                    reconciled: reconciled,
                    currentPlan: workingPlan ?? basePlan
                )
                let input = ProductionContextInput(
                    userRequest: prompt,
                    scope: processingScope(for: artifact),
                    authority: authority,
                    analysis: analysis,
                    committedPlan: basePlan ?? expectedCurrentPlan,
                    workingPlan: workingPlan,
                    references: references,
                    priorRevisionSummaries: conversationState.turns.suffix(8).compactMap(\.userText),
                    budget: providerRequestBudget(for: selectedProvider)
                )
                let provider = try makeProvider(selection: selectedProvider, consent: consent)
                let outcome = try await ProductionIntelligenceCoordinator().interpretAndPlan(
                    input: input,
                    provider: provider,
                    currentAuthority: { [weak self] in
                        await MainActor.run {
                            guard let self,
                                  self.captureArtifact?.id == artifact.id,
                                  self.capturedInstanceID == capturedInstanceID,
                                  self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return nil }
                            return self.productionAuthority(
                                artifact: artifact,
                                instanceID: capturedInstanceID,
                                runtimeEpoch: capturedRuntimeEpoch
                            )
                        }
                    }
                )
                guard !outcome.productionResult.hypotheses.isEmpty else {
                    productionOutcome = outcome
                    isBusy = false
                    status = "One clarification is needed"
                    detailStatus = outcome.validatedInterpretation.clarificationQuestion
                        ?? outcome.validatedInterpretation.interpretation.unresolvedAmbiguities.first
                        ?? "Please describe the acoustic priority you want TrackSmith to change."
                    statusColor = .orange
                    recordConversation(outcome: outcome, manifest: nil)
                    activeProductionTurnID = nil
                    return
                }
                status = "Rendering three grounded options"
                detailStatus = "Validated deterministic graphs · local offline render · level matching · safety checks"
                let result = try await client.renderProductionIntelligencePreviews(
                    artifact: artifact,
                    prompt: prompt,
                    sourceType: sourceType,
                    result: outcome.productionResult,
                    providerMetadata: outcome.validatedInterpretation.metadata
                )
                guard self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch,
                      self.captureArtifact?.id == artifact.id else {
                    throw ModelProviderFailure.staleResult
                }
                let urls = auditionURLs(result: result)
                try await audition.load(urls: urls)
                // Loading suspends. An explicit new capture may have replaced
                // this transaction while the audio engine was preparing files.
                guard self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                previewManifest = result.manifest
                productionOutcome = outcome
                previewDirectory = result.directory
                workingPreview = nil
                workingPreviewURL = nil
                let valid = result.manifest.variants.filter {
                    $0.status == .valid && $0.audioFileName != nil
                }
                selectedAuditionIndex = valid.firstIndex(where: { $0.strength == .balanced })
                    .map { $0 + 1 } ?? (valid.isEmpty ? 0 : 1)
                workingPlan = selectedAuditionIndex > 0 ? valid[selectedAuditionIndex - 1].plan : nil
                resetWorkingHistory()
                audition.select(index: selectedAuditionIndex)
                status = "\(result.manifest.validVariantCount) previews ready"
                detailStatus = "\(activeProviderDescription) interpreted the request; TrackSmith generated and validated every editable DSP graph locally."
                statusColor = .green
                isBusy = false
                recordConversation(outcome: outcome, manifest: result.manifest)
                activeProductionTurnID = nil
            } catch {
                guard self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                fail(error)
            }
        }
    }

    func saveProviderCredential() {
        guard let identifier = providerSelection.credentialIdentifier else { return }
        do {
            try credentialStore.saveCredential(credentialDraft, for: identifier)
            credentialDraft = ""
            refreshCredentialStatus()
            status = "Provider credential saved securely"
            detailStatus = "Stored in macOS Keychain. It is not written to AU, project, conversation, prompt, or diagnostic state."
            statusColor = .green
        } catch { fail(error) }
    }

    func deleteProviderCredential() {
        guard let identifier = providerSelection.credentialIdentifier else { return }
        do {
            try credentialStore.deleteCredential(for: identifier)
            credentialDraft = ""
            refreshCredentialStatus()
            status = "Provider credential removed"
            detailStatus = "Cloud requests for this provider will fail closed until a new Keychain credential is saved."
            statusColor = .green
        } catch { fail(error) }
    }

    func refreshCredentialStatus() {
        guard let identifier = providerSelection.credentialIdentifier else {
            credentialStatus = providerSelection == .appleOnDevice
                ? "Apple On-Device uses no credential or network · \(AppleFoundationModelProvider().availability.rawValue)"
                : "Offline mode does not use a credential or network"
            return
        }
        do {
            credentialStatus = try credentialStore.credential(for: identifier) == nil
                ? "No Keychain credential saved"
                : "Credential available in macOS Keychain"
        } catch {
            credentialStatus = "Keychain credential status unavailable"
        }
    }

    func selectAudition(index: Int) {
        selectedAuditionIndex = index
        audition.select(index: index)
    }

    func useVariantAsWorking(index: Int) {
        guard !isBusy, index > 0, auditionVariants.indices.contains(index - 1) else { return }
        let plan = auditionVariants[index - 1].plan
        appendCurrentPlanToHistory(ifChangingTo: plan)
        workingPlan = plan
        workingPreview = nil
        workingPreviewURL = nil
        selectedAuditionIndex = index
        audition.select(index: index)
        status = "\(auditionVariants[index - 1].strength.rawValue.capitalized) is now the working plan"
        detailStatus = "Conversational and per-node edits will derive from this exact graph."
        statusColor = .green
        for previewIndex in conversationState.previews.indices {
            conversationState.previews[previewIndex].selected =
                conversationState.previews[previewIndex].id == auditionVariants[index - 1].previewID
        }
        persistConversation()
    }

    func workingPlanIsVariant(_ variant: PreviewVariantManifest) -> Bool {
        workingPreview == nil && workingPlan?.requestID == variant.plan.requestID
    }

    func selectWorkingAudition() {
        guard let index = workingAuditionIndex else { return }
        selectedAuditionIndex = index
        audition.select(index: index)
    }

    func previewRevision() {
        let request = revisionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBusy,
              !request.isEmpty,
              let client,
              let artifact = captureArtifact,
              let plan = workingPlan,
              let capturedInstanceID,
              let capturedRuntimeEpoch else { return }
        if providerSelection == .offline {
            previewOfflineRevision(
                request: request,
                client: client,
                artifact: artifact,
                plan: plan,
                capturedInstanceID: capturedInstanceID,
                capturedRuntimeEpoch: capturedRuntimeEpoch
            )
            return
        }
        beginWorkingRender(status: "Rendering conversational revision")
        let operationID = UUID()
        activeWorkingRenderID = operationID
        activeProductionTurnID = UUID()
        let selectedProvider = providerSelection
        let consent = cloudReasoningConsent
        Task {
            do {
                status = "Resolving conversational revision"
                detailStatus = "The provider may interpret language and references; TrackSmith alone resolves identities and constructs the graph."
                let analysis: SourceAwareAnalysisReport
                if let existing = sourceAwareAnalysis {
                    analysis = existing
                } else {
                    analysis = try await client.analyzeCapture(
                        artifact: artifact,
                        sourceType: sourceType
                    )
                }
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch,
                      self.captureArtifact?.id == artifact.id else { return }
                sourceAwareAnalysis = analysis
                let authority = productionAuthority(
                    artifact: artifact,
                    instanceID: capturedInstanceID,
                    runtimeEpoch: capturedRuntimeEpoch
                )
                let reconciled = ConversationStateReconciler().reconcile(
                    conversationState,
                    currentAuthority: authority,
                    // Resolve preview/snapshot/node identities against the
                    // capture-bound graph. Keep `expectedCurrentPlan` unchanged
                    // for the eventual live-AU compare-and-swap commit.
                    currentCommittedPlan: basePlan ?? expectedCurrentPlan
                )
                let references = referenceRegistry(
                    reconciled: reconciled,
                    currentPlan: plan
                )
                let input = ProductionContextInput(
                    userRequest: request,
                    scope: processingScope(for: artifact),
                    authority: authority,
                    analysis: analysis,
                    committedPlan: basePlan ?? expectedCurrentPlan,
                    workingPlan: plan,
                    references: references,
                    priorRevisionSummaries: conversationState.turns.suffix(8).compactMap(\.userText),
                    budget: providerRequestBudget(for: selectedProvider)
                )
                let provider = try makeProvider(selection: selectedProvider, consent: consent)
                let outcome = try await ProductionIntelligenceCoordinator().interpretAndPlan(
                    input: input,
                    provider: provider,
                    currentAuthority: { [weak self] in
                        await MainActor.run {
                            guard let self,
                                  self.activeWorkingRenderID == operationID,
                                  self.captureArtifact?.id == artifact.id,
                                  self.capturedInstanceID == capturedInstanceID,
                                  self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return nil }
                            return self.productionAuthority(
                                artifact: artifact,
                                instanceID: capturedInstanceID,
                                runtimeEpoch: capturedRuntimeEpoch
                            )
                        }
                    }
                )
                guard !outcome.validatedInterpretation.interpretation.requiresClarification else {
                    activeWorkingRenderID = nil
                    activeProductionTurnID = nil
                    isBusy = false
                    status = "One clarification is needed"
                    detailStatus = outcome.validatedInterpretation.clarificationQuestion
                        ?? outcome.validatedInterpretation.interpretation.unresolvedAmbiguities.first
                        ?? "Please identify the prior version, node, or acoustic attribute you mean."
                    statusColor = .orange
                    recordConversation(outcome: outcome, manifest: nil)
                    return
                }
                let revision = try ProductionRevisionCoordinator().revise(
                    outcome: outcome,
                    conversation: reconciled,
                    currentPlan: plan
                )
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch,
                      self.captureArtifact?.id == artifact.id else { return }
                if revision.audioMayChange {
                    status = "Rendering validated conversational revision"
                    let result = try await client.renderWorkingPlanPreview(
                        artifact: artifact,
                        plan: revision.plan
                    )
                    guard let installedPlan = try await installWorkingPreview(
                        result,
                        operationID: operationID,
                        capturedInstanceID: capturedInstanceID,
                        capturedRuntimeEpoch: capturedRuntimeEpoch,
                        historyUpdate: .appendCurrent
                    ) else {
                        // A rejected render never becomes conversation history.
                        // The prior working graph remains authoritative.
                        activeProductionTurnID = nil
                        return
                    }
                    recordRevision(
                        outcome: outcome,
                        resolution: revision,
                        request: request,
                        // Preview validation can recalibrate loudness matching.
                        // Persist the exact graph that rendered and is now
                        // installed as working state, never the pre-render plan.
                        resultingPlan: installedPlan
                    )
                } else {
                    appendCurrentPlanToHistory(ifChangingTo: revision.plan)
                    workingPlan = revision.plan
                    if var preview = workingPreview {
                        preview.plan = revision.plan
                        workingPreview = preview
                    }
                    activeWorkingRenderID = nil
                    isBusy = false
                    status = "Conversational graph constraint applied"
                    detailStatus = "The typed reference or lock changed graph authority without changing samples, so no redundant audio render was created."
                    statusColor = .green
                    recordRevision(
                        outcome: outcome,
                        resolution: revision,
                        request: request,
                        resultingPlan: revision.plan
                    )
                }
                activeProductionTurnID = nil
            } catch {
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                activeProductionTurnID = nil
                fail(error)
            }
        }
    }

    private func previewOfflineRevision(
        request: String,
        client: CompanionSessionClient,
        artifact: CaptureArtifact,
        plan: ProcessingPlan,
        capturedInstanceID: UUID,
        capturedRuntimeEpoch: UUID
    ) {
        beginWorkingRender(status: "Rendering offline deterministic revision")
        let operationID = UUID()
        activeWorkingRenderID = operationID
        Task {
            do {
                let result = try await client.renderRevisionPreview(
                    artifact: artifact,
                    basePlan: plan,
                    request: request
                )
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                _ = try await installWorkingPreview(
                    result,
                    operationID: operationID,
                    capturedInstanceID: capturedInstanceID,
                    capturedRuntimeEpoch: capturedRuntimeEpoch,
                    historyUpdate: .appendCurrent
                )
            } catch {
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                fail(error)
            }
        }
    }

    func setNodeEnabled(nodeID: UUID, enabled: Bool) {
        guard !isBusy, let artifact = captureArtifact, var candidate = workingPlan,
              let index = candidate.nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        let base = candidate
        guard !candidate.nodes[index].locked else {
            status = "Unlock this change before bypassing it"
            detailStatus = "Locked nodes are protected from conversational and indirect graph edits."
            statusColor = .orange
            return
        }
        guard candidate.nodes[index].enabled != enabled else { return }
        candidate.nodes[index].enabled = enabled
        candidate.requestID = UUID()
        do {
            try PlanValidator().validate(
                candidate,
                currentSnapshotID: artifact.id,
                basePlan: base
            )
            renderWorkingCandidate(
                candidate,
                status: enabled ? "Rendering enabled change" : "Rendering node bypass"
            )
        } catch { fail(error) }
    }

    func setNodeLocked(nodeID: UUID, locked: Bool) {
        guard !isBusy, let artifact = captureArtifact, var candidate = workingPlan,
              let index = candidate.nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        let base = candidate
        guard candidate.nodes[index].locked != locked else { return }
        candidate.nodes[index].locked = locked
        candidate.requestID = UUID()
        do {
            // Unlocking is an explicit user command. Locking and every indirect
            // edit still use the prior graph as a locked-node constraint base.
            try PlanValidator().validate(
                candidate,
                currentSnapshotID: artifact.id,
                basePlan: locked ? base : nil
            )
            workingPlan = candidate
            appendHistoryState(previousPlan: base)
            if var preview = workingPreview {
                preview.plan = candidate
                workingPreview = preview
            }
            status = locked ? "Change locked" : "Change unlocked"
            detailStatus = locked
                ? "Future conversational revisions must preserve this node exactly."
                : "The node may now be revised or bypassed. Audio was not re-rendered because locking changes no samples."
            statusColor = .green
            conversationState.lockHistory.append(.init(nodeID: nodeID, locked: locked))
            persistConversation()
        } catch { fail(error) }
    }

    func togglePlayback() {
        do {
            if isPlaying { audition.pause() }
            else { try audition.play() }
            isPlaying.toggle()
        } catch { fail(error) }
    }

    func rewind() {
        audition.stopAndRewind()
        isPlaying = false
    }

    func undoWorkingChange() {
        guard !isBusy, let current = workingPlan, let target = undoWorkingPlans.last else { return }
        let nextUndo = Array(undoWorkingPlans.dropLast())
        let nextRedo = redoWorkingPlans + [current]
        renderWorkingCandidate(
            target,
            status: "Rendering previous working state",
            historyUpdate: .replace(undo: nextUndo, redo: nextRedo)
        )
    }

    func redoWorkingChange() {
        guard !isBusy, let current = workingPlan, let target = redoWorkingPlans.last else { return }
        let nextUndo = undoWorkingPlans + [current]
        let nextRedo = Array(redoWorkingPlans.dropLast())
        renderWorkingCandidate(
            target,
            status: "Rendering redone working state",
            historyUpdate: .replace(undo: nextUndo, redo: nextRedo)
        )
    }

    func commitSelected() {
        guard !isBusy, let plan = workingPlan else { return }
        commit(plan: plan, purpose: .apply, allowLockedNodeRemoval: false)
    }

    func revert() {
        guard !isBusy, let plan = basePlan else { return }
        commit(plan: plan, purpose: .revert, allowLockedNodeRemoval: true)
    }

    func toggleGlobalBypass() {
        guard !isBusy, let client, let instance = activeSessionInstance else { return }
        let enable = !isGlobalBypassed
        isBusy = true
        pendingCommitPurpose = enable ? .bypass : .restore
        status = enable ? "Bypassing all processing" : "Restoring processing"
        detailStatus = enable
            ? "The plug-in will pass dry input exactly while retaining the committed graph."
            : "The retained committed graph will resume at the next audio block."
        statusColor = .orange
        Task {
            do {
                let id = try await client.setGlobalBypass(enabled: enable, instance: instance)
                pendingCommitRequest = PendingRequest(
                    id: id,
                    instanceID: instance.id,
                    runtimeEpoch: instance.runtimeEpoch,
                    deadline: Date(timeIntervalSinceNow: 35),
                    expectation: .globalBypass(enable)
                )
            } catch { fail(error) }
        }
    }

    func deleteAllCachedAudio() {
        guard !isBusy, let client else { return }
        isBusy = true
        rewind()
        status = "Deleting local audio cache"
        detailStatus = "Captured WAVs and rendered previews are being removed from the App Group container."
        statusColor = .orange
        Task {
            do {
                let result = try await client.deleteAllCachedAudio()
                clearCapturedSession()
                status = "Local audio cache deleted"
                detailStatus = "Removed \(result.removedArtifactEntries) capture entr\(result.removedArtifactEntries == 1 ? "y" : "ies") and \(result.removedPreviewEntries) preview entr\(result.removedPreviewEntries == 1 ? "y" : "ies")."
                statusColor = .green
            } catch {
                // Some entries may already be gone after a partial filesystem
                // failure. Drop all in-memory references before reporting it.
                clearCapturedSession()
                fail(error)
            }
        }
    }

    private func renderWorkingCandidate(
        _ candidate: ProcessingPlan,
        status: String,
        historyUpdate: WorkingHistoryUpdate = .appendCurrent
    ) {
        guard let client,
              let artifact = captureArtifact,
              let capturedInstanceID,
              let capturedRuntimeEpoch else { return }
        beginWorkingRender(status: status)
        let operationID = UUID()
        activeWorkingRenderID = operationID
        Task {
            do {
                let result = try await client.renderWorkingPlanPreview(
                    artifact: artifact,
                    plan: candidate
                )
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                _ = try await installWorkingPreview(
                    result,
                    operationID: operationID,
                    capturedInstanceID: capturedInstanceID,
                    capturedRuntimeEpoch: capturedRuntimeEpoch,
                    historyUpdate: historyUpdate
                )
            } catch {
                guard activeWorkingRenderID == operationID,
                      self.capturedInstanceID == capturedInstanceID,
                      self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return }
                fail(error)
            }
        }
    }

    private func beginWorkingRender(status: String) {
        isBusy = true
        self.status = status
        detailStatus = "The candidate is rendered locally, level-matched, and checked before it can replace the working plan."
        statusColor = .orange
    }

    private func installWorkingPreview(
        _ result: WorkingPlanPreviewResult,
        operationID: UUID,
        capturedInstanceID: UUID,
        capturedRuntimeEpoch: UUID,
        historyUpdate: WorkingHistoryUpdate
    ) async throws -> ProcessingPlan? {
        guard result.variant.status == .valid, let audioURL = result.audioURL else {
            activeWorkingRenderID = nil
            isBusy = false
            status = "Revision rejected safely"
            detailStatus = result.variant.rejectionReasons.joined(separator: " ")
            statusColor = .orange
            return nil
        }
        let urls = auditionURLs(workingURL: audioURL)
        try await audition.load(urls: urls)
        guard activeWorkingRenderID == operationID,
              self.capturedInstanceID == capturedInstanceID,
              self.capturedRuntimeEpoch == capturedRuntimeEpoch else { return nil }
        switch historyUpdate {
        case .appendCurrent:
            appendCurrentPlanToHistory(ifChangingTo: result.variant.plan)
        case let .replace(undo, redo):
            undoWorkingPlans = undo
            redoWorkingPlans = redo
            updateHistoryAvailability()
        }
        workingPlan = result.variant.plan
        workingPreview = result.variant
        workingPreviewURL = audioURL
        selectedAuditionIndex = urls.count - 1
        audition.select(index: selectedAuditionIndex)
        isPlaying = false
        activeWorkingRenderID = nil
        isBusy = false
        status = "Working revision ready"
        detailStatus = "The displayed graph is exactly the graph this preview rendered and Commit Working Plan will publish."
        statusColor = .green
        return result.variant.plan
    }

    private func commit(
        plan: ProcessingPlan,
        purpose: CommitPurpose,
        allowLockedNodeRemoval: Bool
    ) {
        guard let client,
              let artifact = captureArtifact,
              let capturedInstanceID,
              let capturedRuntimeEpoch,
              let instance = instances.first(where: {
                  $0.id == capturedInstanceID && $0.runtimeEpoch == capturedRuntimeEpoch
              }) else {
            fail(CompanionSessionError.capturedInstanceUnavailable)
            return
        }
        isBusy = true
        pendingCommitPurpose = purpose
        switch purpose {
        case .apply: status = "Publishing exact working graph"
        case .revert: status = "Reverting to the captured original graph"
        case .bypass: status = "Bypassing all processing"
        case .restore: status = "Restoring the working processing graph"
        }
        detailStatus = "The plug-in validates and compiles the complete graph before an atomic block-boundary swap."
        statusColor = .orange
        Task {
            do {
                let id = try await client.commit(
                    plan: plan,
                    artifact: artifact,
                    originatingInstance: instance,
                    expectedCurrentPlan: expectedCurrentPlan,
                    allowLockedNodeRemoval: allowLockedNodeRemoval
                )
                pendingCommitRequest = PendingRequest(
                    id: id,
                    instanceID: instance.id,
                    runtimeEpoch: instance.runtimeEpoch,
                    deadline: Date(timeIntervalSinceNow: 35),
                    expectation: .plan(plan)
                )
            }
            catch { fail(error) }
        }
    }

    private func refresh() async {
        guard let client else { return }
        do {
            let scan = try await client.activeInstances()
            instances = scan.instances
            if selectedInstanceID == nil || !instances.contains(where: { $0.id == selectedInstanceID }) {
                selectedInstanceID = instances.first?.id
            }
            if pendingCommitRequest == nil, !isBusy {
                isGlobalBypassed = activeSessionInstance?.globalBypassEnabled ?? false
            }
            let mayReplaceTerminalStatus = failureStatusExpiresAt.map { Date() >= $0 } ?? true
            if mayReplaceTerminalStatus,
               capturedInstanceID != nil, capturedRuntimeEpoch != nil,
               pendingCaptureRequest == nil, pendingCommitRequest == nil, !isBusy {
                if !capturedInstanceIsAvailable {
                    status = "Captured Audio Unit instance is no longer available"
                    detailStatus = "The local capture and previews remain auditionable. Reconnect that insert before committing."
                    statusColor = .orange
                } else if isGlobalBypassed {
                    status = "All processing is bypassed"
                    detailStatus = "The committed graph remains loaded and Restore Processing will resume it."
                    statusColor = .orange
                } else if workingPreview != nil {
                    status = "Working revision ready"
                    detailStatus = "Audition Original, the initial strengths, and the exact editable revision."
                    statusColor = .green
                } else if let previewManifest {
                    status = "\(previewManifest.validVariantCount) previews ready"
                    detailStatus = "Audition any version, then explicitly choose which option becomes the working plan."
                    statusColor = .green
                } else if captureArtifact != nil {
                    status = "Recent playback captured"
                    detailStatus = "The immutable local capture is ready for analysis and preview rendering."
                    statusColor = .green
                }
            } else if mayReplaceTerminalStatus,
                      instances.isEmpty, pendingCaptureRequest == nil, pendingCommitRequest == nil {
                status = "Waiting for an Audio Unit instance"
                detailStatus = "Insert the plug-in in Logic, then play the section you want to analyze."
                statusColor = .orange
            } else if mayReplaceTerminalStatus,
                      captureArtifact == nil, pendingCaptureRequest == nil, !isBusy,
                      capturedInstanceID == nil {
                if isGlobalBypassed {
                    status = "All processing is bypassed"
                    detailStatus = "The committed graph remains loaded and Restore Processing will resume it."
                    statusColor = .orange
                } else {
                    status = "Connected to Logic Audio Assistant"
                    detailStatus = "Play audio in Logic, then analyze recent playback."
                    statusColor = .green
                }
            }
        } catch {
            status = "Connection check will retry"
            detailStatus = String(describing: error)
            statusColor = .orange
            return
        }
        do {
            try await resolvePendingCapture(client)
            try await resolvePendingCommit(client)
        } catch { fail(error) }
    }

    private func resolvePendingCapture(_ client: CompanionSessionClient) async throws {
        guard let pending = pendingCaptureRequest else { return }
        guard pending.deadline >= Date() else {
            throw CompanionSessionError.requestTimedOut("capture")
        }
        guard let (artifact, _) = try await client.captureReply(
            requestID: pending.id,
            instanceID: pending.instanceID
        ) else { return }
        guard capturedInstanceID == pending.instanceID else {
            throw CompanionSessionError.capturedInstanceUnavailable
        }
        guard artifact.originatingInstanceID == pending.instanceID else {
            throw CompanionSessionError.captureInstanceMismatch(
                expected: pending.instanceID,
                actual: artifact.originatingInstanceID
            )
        }
        guard artifact.originatingRuntimeEpoch == pending.runtimeEpoch else {
            throw CompanionSessionError.captureRuntimeMismatch(
                expected: pending.runtimeEpoch,
                actual: artifact.originatingRuntimeEpoch
            )
        }
        let audio = try await client.loadCapturedAudio(artifact)
        captureArtifact = artifact
        pendingCaptureRequest = nil
        activeCaptureOperationID = nil
        waveform = await Task.detached(priority: .userInitiated) {
            Self.waveformSamples(audio)
        }.value
        basePlan = rebindBasePlan(basePlan, to: artifact)
        let authority = productionAuthority(
            artifact: artifact,
            instanceID: pending.instanceID,
            runtimeEpoch: pending.runtimeEpoch
        )
        conversationState.authorityBinding = authority
        conversationState.snapshots.append(.init(
            id: artifact.id,
            label: "Immutable recent-input capture",
            authority: authority,
            plan: basePlan
        ))
        persistConversation()
        status = "Recent playback captured"
        detailStatus = "The immutable local capture is ready for analysis and preview rendering."
        statusColor = .green
        isBusy = false
    }

    private func resolvePendingCommit(_ client: CompanionSessionClient) async throws {
        guard let pending = pendingCommitRequest else { return }
        guard let expectation = pending.expectation else {
            throw CompanionSessionError.unexpectedReply
        }
        guard let resolution = try await client.commandResolution(
            requestID: pending.id,
            instanceID: pending.instanceID,
            runtimeEpoch: pending.runtimeEpoch,
            expectation: expectation
        ) else {
            guard pending.deadline >= Date() else {
                throw CompanionSessionError.requestTimedOut("commit")
            }
            return
        }
        pendingCommitRequest = nil
        isBusy = false
        let confirmationText: String
        switch resolution {
        case let .rejected(reply):
            throw CompanionSessionError.replyWasFailure(reply.text ?? "The plug-in rejected the graph.")
        case let .acknowledged(reply):
            confirmationText = reply.text ?? "The graph is active in the Audio Unit."
        case .reconciled:
            confirmationText = "The acknowledgement was unavailable, but the Audio Unit heartbeat proves this exact command is active."
        }
        if case let .plan(plan) = expectation {
            expectedCurrentPlan = plan
            if let artifact = captureArtifact,
               let capturedInstanceID,
               let capturedRuntimeEpoch {
                conversationState.authorityBinding = productionAuthority(
                    artifact: artifact,
                    instanceID: capturedInstanceID,
                    runtimeEpoch: capturedRuntimeEpoch
                )
                conversationState.turns.append(.init(
                    kind: .commit,
                    userText: pendingCommitPurpose == .revert ? "Restore captured base graph" : "Commit working graph",
                    authority: conversationState.authorityBinding
                ))
                persistConversation()
            }
        }
        switch pendingCommitPurpose {
        case .apply:
            status = isGlobalBypassed
                ? "Working graph committed behind global bypass"
                : "Working graph committed"
        case .revert:
            status = isGlobalBypassed
                ? "Original graph restored behind global bypass"
                : "Original graph restored"
        case .bypass:
            isGlobalBypassed = true
            status = "All processing bypassed"
        case .restore:
            isGlobalBypassed = false
            status = "Processing restored"
        }
        detailStatus = confirmationText
        statusColor = .green
    }

    private func auditionURLs(result: PreviewExportResult) -> [URL] {
        var urls = [result.directory.appendingPathComponent(result.manifest.originalAudioFileName)]
        urls += result.manifest.variants.filter { $0.status == .valid }.compactMap { variant in
            variant.audioFileName.map { result.directory.appendingPathComponent($0) }
        }
        return urls
    }

    private func auditionURLs(workingURL: URL) -> [URL] {
        guard let previewManifest, let previewDirectory else { return [workingURL] }
        var urls = [previewDirectory.appendingPathComponent(previewManifest.originalAudioFileName)]
        urls += previewManifest.variants.filter { $0.status == .valid }.compactMap { variant in
            variant.audioFileName.map { previewDirectory.appendingPathComponent($0) }
        }
        urls.append(workingURL)
        return urls
    }

    nonisolated private static func waveformSamples(_ audio: AudioBuffer, targetCount: Int = 1_600) -> [Float] {
        guard audio.frameCount > 0 else { return [] }
        let stride = max(1, audio.frameCount / targetCount)
        var result: [Float] = []
        result.reserveCapacity(min(targetCount, audio.frameCount))
        var start = 0
        while start < audio.frameCount {
            let end = min(audio.frameCount, start + stride)
            var signedPeak: Float = 0
            for frame in start..<end {
                var mono: Float = 0
                for channel in audio.channels { mono += channel[frame] }
                mono /= Float(audio.channelCount)
                if abs(mono) > abs(signedPeak) { signedPeak = mono }
            }
            result.append(signedPeak)
            start = end
        }
        return result
    }

    private func fail(_ error: Error) {
        status = "Operation failed safely"
        detailStatus = String(describing: error)
        statusColor = .red
        failureStatusExpiresAt = Date(timeIntervalSinceNow: 15)
        isBusy = false
        isPlaying = false
        activeWorkingRenderID = nil
        activeCaptureOperationID = nil
        activeProductionTurnID = nil
        pendingCaptureRequest = nil
        pendingCommitRequest = nil
    }

    private func clearCapturedSession() {
        activeCaptureOperationID = nil
        pendingCaptureRequest = nil
        captureArtifact = nil
        waveform = []
        previewManifest = nil
        previewDirectory = nil
        workingPlan = nil
        workingPreview = nil
        workingPreviewURL = nil
        activeWorkingRenderID = nil
        activeProductionTurnID = nil
        selectedAuditionIndex = 0
        basePlan = nil
        expectedCurrentPlan = nil
        productionOutcome = nil
        sourceAwareAnalysis = nil
        resetWorkingHistory()
        capturedInstanceID = nil
        capturedRuntimeEpoch = nil
        audition.unload()
        isPlaying = false
        if pendingCommitRequest == nil { isBusy = false }
    }

    private func captureOperationMatches(
        _ operationID: UUID,
        instance: PluginInstanceRecord
    ) -> Bool {
        activeCaptureOperationID == operationID
            && capturedInstanceID == instance.id
            && capturedRuntimeEpoch == instance.runtimeEpoch
    }

    private func appendCurrentPlanToHistory(ifChangingTo nextPlan: ProcessingPlan) {
        guard let current = workingPlan, current != nextPlan else { return }
        appendHistoryState(previousPlan: current)
    }

    private func appendHistoryState(previousPlan: ProcessingPlan) {
        if undoWorkingPlans.last != previousPlan { undoWorkingPlans.append(previousPlan) }
        redoWorkingPlans.removeAll(keepingCapacity: true)
        updateHistoryAvailability()
    }

    private func resetWorkingHistory() {
        undoWorkingPlans.removeAll(keepingCapacity: true)
        redoWorkingPlans.removeAll(keepingCapacity: true)
        updateHistoryAvailability()
    }

    private func updateHistoryAvailability() {
        canUndoWorking = !undoWorkingPlans.isEmpty
        canRedoWorking = !redoWorkingPlans.isEmpty
    }

    private func rebindBasePlan(
        _ existing: ProcessingPlan?,
        to artifact: CaptureArtifact
    ) -> ProcessingPlan {
        let scope = ProcessingScope(
            kind: .pluginInput,
            channelFormat: artifact.channelCount == 1 ? .mono : .stereo,
            sourceType: sourceType,
            timeRangeSeconds: TimeRangeSeconds(
                start: 0,
                end: Double(artifact.frameCount) / artifact.sampleRate
            )
        )
        guard var rebound = existing else {
            return ProcessingPlan(
                sourceSnapshotID: artifact.id,
                scope: scope,
                goals: [],
                nodes: []
            )
        }
        rebound.sourceSnapshotID = artifact.id
        rebound.scope = scope
        return rebound
    }

    private func processingScope(for artifact: CaptureArtifact) -> ProcessingScope {
        ProcessingScope(
            kind: .pluginInput,
            channelFormat: artifact.channelCount == 1 ? .mono : .stereo,
            sourceType: sourceType,
            timeRangeSeconds: .init(
                start: 0,
                end: Double(artifact.frameCount) / artifact.sampleRate
            )
        )
    }

    private func productionAuthority(
        artifact: CaptureArtifact,
        instanceID: UUID,
        runtimeEpoch: UUID
    ) -> ProductionAuthorityIdentity {
        ProductionAuthorityIdentity(
            instanceID: instanceID,
            runtimeEpoch: runtimeEpoch,
            captureSnapshotID: artifact.id,
            currentPlanRequestID: expectedCurrentPlan?.requestID ?? basePlan?.requestID,
            conversationID: conversationState.conversationID,
            turnID: activeProductionTurnID ?? UUID()
        )
    }

    private func referenceRegistry(
        reconciled: ReconciledConversationState,
        currentPlan: ProcessingPlan?
    ) -> ModelReferenceRegistry {
        var registry = reconciled.activeReferences
        let variants = previewManifest?.variants.filter { $0.status == .valid } ?? []
        let conversationReferencesAreLive = reconciled.authorityStatus == .liveAuthoritative
        registry.previewIDs.formUnion(variants.map(\.previewID))
        if conversationReferencesAreLive {
            registry.snapshotIDs.formUnion(conversationState.snapshots.map(\.id))
            registry.priorRequestIDs.formUnion(conversationState.turns.map(\.id))
        }
        // Processing-node verbs are always resolved against the exact working
        // graph passed to `ProductionRevisionCoordinator`. Reconciled durable
        // state may describe the committed AU graph, which can legitimately
        // differ while a preview is selected. Never union those identities:
        // validation and deterministic resolution must have the same node
        // authority set.
        registry.replaceProcessingNodeAuthority(with: currentPlan?.nodes ?? [])

        var catalog: [ModelReferenceDescriptor] = []
        for (index, variant) in variants.enumerated() {
            let ordinal = index + 1
            catalog.append(.init(
                kind: .preview,
                identifier: variant.previewID.uuidString,
                aliases: ordinalAliases(noun: "version", ordinal: ordinal)
                    + ordinalAliases(noun: "preview", ordinal: ordinal)
                    + [variant.strength.rawValue + " preview"],
                summary: variant.hypothesisIdentifier.map {
                    "\(variant.strength.rawValue) preview from hypothesis \($0)"
                } ?? "\(variant.strength.rawValue) preview",
                ordinal: ordinal,
                selected: workingPlan?.requestID == variant.plan.requestID
            ))
        }

        for (index, snapshot) in conversationState.snapshots.enumerated()
            where conversationReferencesAreLive {
            let ordinal = index + 1
            catalog.append(.init(
                kind: .snapshot,
                identifier: snapshot.id.uuidString,
                aliases: ordinalAliases(noun: "snapshot", ordinal: ordinal),
                summary: snapshot.label,
                ordinal: ordinal,
                selected: workingPlan?.requestID == snapshot.plan?.requestID,
                parentIdentifier: snapshot.parentSnapshotID?.uuidString
            ))
        }

        for (index, turn) in conversationState.turns.enumerated()
            where conversationReferencesAreLive {
            let ordinal = index + 1
            let revision = conversationState.revisions.last { $0.turnID == turn.id }
            catalog.append(.init(
                kind: .priorRequest,
                identifier: turn.id.uuidString,
                aliases: ordinalAliases(noun: "request", ordinal: ordinal)
                    + ordinalAliases(noun: "turn", ordinal: ordinal),
                summary: turn.userText,
                ordinal: ordinal,
                baseIdentifier: revision?.baseSnapshotID.uuidString,
                resultIdentifier: revision?.resultSnapshotID.uuidString
            ))
        }

        if let currentPlan {
            var typeOrdinals: [NodeType: Int] = [:]
            for (index, node) in currentPlan.nodes.enumerated() {
                let typeOrdinal = (typeOrdinals[node.type] ?? 0) + 1
                typeOrdinals[node.type] = typeOrdinal
                var aliases = [node.type.rawValue, "\(node.type.rawValue) node"]
                aliases += ordinalAliases(noun: "processing node", ordinal: index + 1)
                if typeOrdinal > 1 {
                    aliases += ordinalAliases(noun: node.type.rawValue, ordinal: typeOrdinal)
                }
                catalog.append(.init(
                    kind: .processingNode,
                    identifier: node.id.uuidString,
                    aliases: aliases,
                    summary: "\(node.type.rawValue); \(node.enabled ? "enabled" : "bypassed"); \(node.locked ? "locked" : "unlocked")",
                    ordinal: index + 1,
                    locked: node.locked,
                    nodeType: node.type
                ))
            }
        }

        var seen: Set<String> = []
        registry.catalog = catalog.filter {
            seen.insert("\($0.kind.rawValue)|\($0.identifier)").inserted
        }
        return registry
    }

    private func ordinalAliases(noun: String, ordinal: Int) -> [String] {
        let words = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
        let cardinalWords = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        var aliases = ["\(noun) \(ordinal)"]
        if words.indices.contains(ordinal - 1) {
            aliases.append("\(words[ordinal - 1]) \(noun)")
            aliases.append("\(noun) \(words[ordinal - 1])")
        }
        if cardinalWords.indices.contains(ordinal - 1) {
            aliases.append("\(noun) \(cardinalWords[ordinal - 1])")
        }
        return aliases
    }

    private func makeProvider(
        selection: CompanionProviderSelection,
        consent: Bool
    ) throws -> any ModelProvider {
        switch selection {
        case .offline:
            return MockModelProvider()
        case .appleOnDevice:
            return AppleFoundationModelProvider()
        case .openAI:
            return OpenAIResponsesProvider(
                configuration: .init(cloudReasoningConsent: consent),
                credentialStore: credentialStore
            )
        case .gemini:
            return GeminiInteractionsProvider(
                configuration: .init(cloudReasoningConsent: consent),
                credentialStore: credentialStore
            )
        }
    }

    private func providerRequestBudget(
        for selection: CompanionProviderSelection
    ) -> ProviderRequestBudget {
        switch selection {
        case .openAI, .gemini:
            // One explicit attempt, a bounded output, and enough wall time for
            // the current frontier lanes. The provider never retries silently.
            .init(maxOutputTokens: 2_500, maxAttempts: 1, timeoutSeconds: 60)
        case .appleOnDevice:
            .init(maxOutputTokens: 2_500, maxAttempts: 1, timeoutSeconds: 45)
        case .offline:
            .init(maxOutputTokens: 2_500, maxAttempts: 1, timeoutSeconds: 25)
        }
    }

    private func beginNewConversation() {
        conversationState = ProductionConversationState()
        restoredConversationStatus = ""
        UserDefaults.standard.set(
            conversationState.conversationID.uuidString,
            forKey: "TrackSmith.ActiveConversationID"
        )
    }

    private func recordConversation(
        outcome: ProductionIntelligenceOutcome,
        manifest: PreviewSessionManifest?
    ) {
        conversationState.authorityBinding = outcome.request.authority
        let summaries = outcome.productionResult.hypotheses.enumerated().map { index, hypothesis in
            PersistedHypothesisSummary(
                identifier: "tracksmith-hypothesis-\(index + 1)",
                intendedOutcome: hypothesis.intendedPerceptualChange,
                supportingMetricIdentifiers: hypothesis.evidenceSupportingIntervention.compactMap(\.metricIdentifier),
                contradictoryMetricIdentifiers: hypothesis.evidenceAgainstIntervention.compactMap(\.metricIdentifier),
                strategyCategories: hypothesis.processingOptionsConsidered,
                risks: hypothesis.risks,
                provenance: hypothesis.provenance,
                listeningRemainsDecisive: hypothesis.subjectiveListeningRemainsDecisive
            )
        }
        conversationState.turns.append(.init(
            id: outcome.request.authority.turnID,
            kind: outcome.validatedInterpretation.interpretation.requiresClarification ? .clarification : .request,
            userText: outcome.request.userRequest,
            interpretation: outcome.validatedInterpretation.interpretation,
            clarificationQuestion: outcome.validatedInterpretation.clarificationQuestion,
            hypotheses: summaries,
            references: outcome.validatedInterpretation.references,
            providerMetadata: outcome.validatedInterpretation.metadata,
            validationAudit: outcome.validatedInterpretation.audit,
            authority: outcome.request.authority
        ))
        if let manifest {
            for variant in manifest.variants where !conversationState.previews.contains(where: { $0.id == variant.previewID }) {
                conversationState.previews.append(.init(
                    id: variant.previewID,
                    sourceSnapshotID: manifest.sourceSnapshotID,
                    hypothesisIdentifier: variant.hypothesisIdentifier,
                    strength: variant.strength,
                    plan: variant.plan,
                    selected: workingPlan?.requestID == variant.plan.requestID
                ))
            }
        }
        persistConversation()
    }

    private func recordRevision(
        outcome: ProductionIntelligenceOutcome,
        resolution: ProductionRevisionResolution,
        request: String,
        resultingPlan: ProcessingPlan
    ) {
        conversationState.authorityBinding = outcome.request.authority
        let turnID = outcome.request.authority.turnID
        let summaries = outcome.productionResult.hypotheses.enumerated().map { index, hypothesis in
            PersistedHypothesisSummary(
                identifier: "tracksmith-hypothesis-\(index + 1)",
                intendedOutcome: hypothesis.intendedPerceptualChange,
                supportingMetricIdentifiers: hypothesis.evidenceSupportingIntervention.compactMap(\.metricIdentifier),
                contradictoryMetricIdentifiers: hypothesis.evidenceAgainstIntervention.compactMap(\.metricIdentifier),
                strategyCategories: hypothesis.processingOptionsConsidered,
                risks: hypothesis.risks,
                provenance: hypothesis.provenance,
                listeningRemainsDecisive: hypothesis.subjectiveListeningRemainsDecisive
            )
        }
        conversationState.turns.append(.init(
            id: turnID,
            kind: .revision,
            userText: request,
            interpretation: outcome.validatedInterpretation.interpretation,
            hypotheses: summaries,
            references: resolution.appliedReferences,
            providerMetadata: outcome.validatedInterpretation.metadata,
            validationAudit: outcome.validatedInterpretation.audit,
            authority: outcome.request.authority
        ))
        let parentSnapshotID = conversationState.snapshots.last?.id
        let resultSnapshotID = UUID()
        conversationState.snapshots.append(.init(
            id: resultSnapshotID,
            parentSnapshotID: parentSnapshotID,
            label: "Conversational working revision",
            authority: outcome.request.authority,
            plan: resultingPlan
        ))
        let selectedPreviewID = conversationState.previews.last(where: \.selected)?.id
        conversationState.revisions.append(.init(
            turnID: turnID,
            parentRevisionID: conversationState.revisions.last?.id,
            basePreviewID: selectedPreviewID,
            baseSnapshotID: parentSnapshotID ?? outcome.request.authority.captureSnapshotID,
            resultSnapshotID: resultSnapshotID,
            request: request,
            references: resolution.appliedReferences,
            resultingPlanRequestID: resultingPlan.requestID
        ))
        persistConversation()
    }

    private func persistConversation() {
        guard let conversationStore else { return }
        do {
            _ = try conversationStore.save(conversationState)
            UserDefaults.standard.set(
                conversationState.conversationID.uuidString,
                forKey: "TrackSmith.ActiveConversationID"
            )
        } catch {
            restoredConversationStatus = "Conversation state could not be persisted safely: \(error)"
        }
    }

    private func restoreActiveConversation() {
        guard let conversationStore,
              let raw = UserDefaults.standard.string(forKey: "TrackSmith.ActiveConversationID"),
              let id = UUID(uuidString: raw) else { return }
        do {
            let restored = try conversationStore.load(conversationID: id)
            conversationState = restored.state
            restoredConversationStatus = restored.migratedFromVersion.map {
                "Restored historical conversation after migrating v\($0) state. Live AU authority must be reconciled."
            } ?? "Restored historical conversation. It is view-only until exact AU runtime and graph authority reconcile."
        } catch {
            restoredConversationStatus = "Stored conversation was unavailable or quarantined safely."
            conversationState = ProductionConversationState()
        }
    }
}
