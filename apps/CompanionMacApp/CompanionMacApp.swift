import AgentCore
import AudioAnalysis
import PlanSchema
import PreviewWorkflow
import SharedIPC
import SwiftUI
import VocalProduction

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
    case vocal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .guideMe: "Guide Me"
        case .createForMe: "Create For Me"
        case .vocal: "Vocal"
        }
    }
    var subtitle: String {
        switch self {
        case .guideMe: "TrackSmith tells you exactly what to try in Logic, step by step. You perform every action."
        case .createForMe: "TrackSmith renders bounded processing alternatives you audition, revise, and commit explicitly."
        case .vocal: "Build a truthful capture brief, assess an AU test take, and audition three bounded vocal hypotheses."
        }
    }
}

private enum VocalWorkspaceIntegrationError: Error, CustomStringConvertible {
    case currentCaptureRequired
    case staleCaptureContext
    case scopedAssetPermissionRequired
    case currentAssessmentRequired
    case preparedCaptureHandoffRequired
    case previewUnavailable

    var description: String {
        switch self {
        case .currentCaptureRequired:
            "Capture recent vocal playback from the current TrackSmith AU instance first."
        case .staleCaptureContext:
            "The capture, source, or assessment changed. Refresh and repeat the explicit request."
        case .scopedAssetPermissionRequired:
            "A seconds or named-section request requires explicit permission for a local rendered derivative asset."
        case .currentAssessmentRequired:
            "Analyze the current AU test take before preparing this handoff."
        case .preparedCaptureHandoffRequired:
            "Prepare the current capture context before requesting an executable Create handoff."
        case .previewUnavailable:
            "This exact candidate does not yet have a current local preview or derivative-asset comparison."
        }
    }
}

struct CompanionContentView: View {
    @ObservedObject var model: CompanionSessionModel
    @StateObject private var tutor = TutorSessionModel()
    @StateObject private var vocal = VocalWorkspaceModel()
    @StateObject private var vocalBriefEditor = VocalCaptureBriefEditorModel()
    @StateObject private var vocalPersistence = VocalWorkspacePersistenceCoordinator.live()
    @State private var mode: CompanionMode = .guideMe
    @State private var confirmingCacheDeletion = false
    @State private var vocalCaptureRuntimeContext: VocalCaptureRuntimeContext?
    @State private var pendingVocalTestTakeBinding: VocalTestTakeBinding?
    @State private var acceptedVocalTestTakeBinding: VocalTestTakeBinding?
    @State private var activeVocalIntentRequestID: UUID?

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
                case .vocal:
                    vocalWorkspace
                }
            }
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.canvas)
        .task { model.start() }
        .task { vocalPersistence.restore(into: vocal) }
        .task(id: mode) {
            guard mode == .vocal else { return }
            await refreshVocalCaptureContext(force: false)
        }
        .task(id: model.captureArtifact?.id) {
            vocalCaptureRuntimeContext = nil
            guard let _ = model.captureArtifact else {
                vocal.clearAnalysis()
                return
            }
            guard mode == .vocal else { return }
            guard acceptPendingVocalTestTake() else {
                vocal.clearAnalysis()
                vocalPersistence.sourceBecameUnavailable(into: vocal)
                return
            }
            await refreshVocalCaptureContext(force: true)
        }
        .onChange(of: model.providerSelection) { _, _ in
            model.refreshCredentialStatus()
        }
        .onChange(of: model.sourceType) { _, _ in
            vocalCaptureRuntimeContext = nil
            model.sourceAwareAnalysis = nil
            vocal.clearAnalysis()
            pendingVocalTestTakeBinding = nil
            acceptedVocalTestTakeBinding = nil
            clearCompanionVocalPlanningAuthority()
            guard mode == .vocal else { return }
            Task { await refreshVocalCaptureContext(force: true) }
        }
        .onChange(of: model.sourceAwareAnalysis) { _, report in
            synchronizeVocalAnalysis(report)
        }
        .onChange(of: model.vocalCandidates) { _, _ in
            synchronizeGeneratedVocalCandidates()
        }
        .onChange(of: model.vocalRenderedAssetManifest) { _, manifest in
            synchronizeRenderedVocalAsset(manifest)
        }
        .onChange(of: model.isBusy) { _, isBusy in
            if !isBusy { synchronizeWorkingVocalPreview() }
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
            .frame(maxWidth: 360)
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

    private var vocalWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.twentyFour) {
                Text(mode.subtitle)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)

                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    Text("AU test take")
                        .font(Theme.Font.body.weight(.medium))
                    Text("Capture from the selected TrackSmith insert. The resulting immutable WAV and source hash bind analysis, plans, renders, revisions, and handoffs.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    if let interpretation = vocal.activeCaptureInterpretation {
                        Text("Bound test: \(interpretation.comparison.testTakeLabel)")
                            .font(Theme.Font.data)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        Text("Select one typed capture hypothesis before starting a Vocal test take.")
                            .font(Theme.Font.meta)
                            .foregroundStyle(Theme.Colors.mutedText)
                    }
                    CapturePanelView(
                        model: model,
                        beforeCapture: beginBoundVocalTestTake,
                        captureButtonTitle: "Capture Bound Vocal Test Take"
                    )
                }

                VocalCaptureBriefEditorView(editor: vocalBriefEditor) { brief in
                    vocal.loadCaptureBrief(brief)
                    pendingVocalTestTakeBinding = nil
                    acceptedVocalTestTakeBinding = nil
                    vocalCaptureRuntimeContext = nil
                    clearCompanionVocalPlanningAuthority()
                    vocal.noteRequest(
                        "Musician-entered capture brief loaded. Request three bounded capture plans when ready."
                    )
                    persistVocalWorkspace()
                }

                VocalWorkspaceView(
                    model: vocal,
                    callbacks: vocalCallbacks,
                    usesOwnScroll: false
                )

                VocalWorkspacePersistenceView(
                    coordinator: vocalPersistence,
                    model: vocal,
                    saveNow: persistVocalWorkspace,
                    restoreCandidate: restoreExactVocalCandidate,
                    inspectSession: { sessionID in
                        invalidateBoundVocalRuntimeAuthority()
                        vocalPersistence.inspectKnownSession(sessionID, into: vocal)
                    },
                    deleteCurrent: {
                        invalidateBoundVocalRuntimeAuthority()
                        vocalPersistence.deleteCurrent(into: vocal)
                    },
                    deleteAll: {
                        invalidateBoundVocalRuntimeAuthority()
                        vocalPersistence.deleteAllKnown(into: vocal)
                    },
                    deleteSession: { sessionID in
                        if vocalPersistence.activeSessionID == sessionID {
                            invalidateBoundVocalRuntimeAuthority()
                        }
                        vocalPersistence.deleteKnownSession(sessionID, into: vocal)
                    }
                )

                PreviewPanelView(model: model, allowsUseAsWorking: false)
                ChangeStackView(model: model)
                ActionBarView(
                    model: model,
                    commitAuthorityIsCurrent: vocalWorkingCommitAuthorityIsCurrent
                )
            }
            .padding(Theme.Spacing.twentyFour)
        }
    }

    private var vocalCallbacks: VocalWorkspaceCallbacks {
        VocalWorkspaceCallbacks(
            requestCaptureInterpretations: { brief in
                do {
                    let interpretations = try VocalCapturePlanner().plan(brief: brief)
                    vocal.loadCaptureBrief(brief, interpretations: interpretations)
                    pendingVocalTestTakeBinding = nil
                    acceptedVocalTestTakeBinding = nil
                    vocalCaptureRuntimeContext = nil
                    clearCompanionVocalPlanningAuthority()
                    persistVocalWorkspace()
                } catch {
                    vocal.setConflict("Capture planning refused: \(error)")
                }
            },
            selectCaptureInterpretation: { interpretation in
                pendingVocalTestTakeBinding = nil
                acceptedVocalTestTakeBinding = nil
                vocalCaptureRuntimeContext = nil
                clearCompanionVocalPlanningAuthority()
                vocal.noteRequest(
                    "Capture \(VocalWorkspacePresentation.shortID(interpretation.id)) selected for a reversible test; no preference is inferred."
                )
                persistVocalWorkspace()
            },
            submitCaptureListening: { interpretation, _ in
                vocal.noteRequest(
                    "Listening feedback remains in this workspace for capture \(VocalWorkspacePresentation.shortID(interpretation.id)); request a bounded revision to create typed ancestry or a confirmed-preference record."
                )
            },
            requestCaptureRevision: { interpretation, assessment, feedback in
                Task {
                    do {
                        let context = try await currentVocalCaptureContext()
                        if let assessment, assessment.id != context.assessment.id {
                            throw VocalWorkspaceIntegrationError.staleCaptureContext
                        }
                        let revision = VocalCapturePlanReviser().revise(
                            selected: interpretation,
                            assessment: context.assessment,
                            feedback: feedback,
                            revisedInterpretationID: UUID(),
                            revisionID: UUID(),
                            preferenceID: UUID(),
                            revisedAt: Date()
                        )
                        vocal.loadCaptureRevision(revision)
                        pendingVocalTestTakeBinding = nil
                        acceptedVocalTestTakeBinding = nil
                        vocalCaptureRuntimeContext = nil
                        clearCompanionVocalPlanningAuthority()
                        persistVocalWorkspace()
                    } catch {
                        vocal.setConflict("Capture revision refused: \(error)")
                    }
                }
            },
            requestGuideCreateHandoff: { summary in
                Task {
                    do {
                        let context = try await currentVocalCaptureContext()
                        guard summary.assessmentID == context.assessment.id else {
                            throw VocalWorkspaceIntegrationError.currentAssessmentRequired
                        }
                        vocal.markHandoffPrepared(summary)
                        persistVocalWorkspace()
                    } catch {
                        vocal.markHandoffRefused("Capture-context handoff refused: \(error)")
                    }
                }
            },
            requestExecutableHandoff: { summary, candidate in
                Task {
                    do {
                        guard case let .captureContextPrepared(prepared) = vocal.handoffState,
                              prepared == summary else {
                            throw VocalWorkspaceIntegrationError.preparedCaptureHandoffRequired
                        }
                        let context = try await currentVocalCaptureContext()
                        guard summary.assessmentID == context.assessment.id,
                              candidate.intent.sourceSnapshotID == context.sourceAuthority.sourceSnapshotID,
                              candidate.plan.sourceSnapshotID == context.sourceAuthority.sourceSnapshotID,
                              completedVocalAuthorityIsCurrent(context.sourceAuthority) else {
                            throw VocalWorkspaceIntegrationError.staleCaptureContext
                        }
                        let authority = VocalCaptureHandoffAuthority(
                            captureBriefID: summary.captureBriefID,
                            selectedCaptureInterpretationID: summary.interpretationID,
                            testTakeAssessmentID: summary.assessmentID,
                            confirmedPreferenceID: vocal.latestCaptureRevision?.confirmedPreference?.id,
                            sourceAuthority: context.sourceAuthority
                        )
                        let measurements = context.assessment.findings.prefix(64).compactMap {
                            finding -> VocalHandoffMeasurement? in
                            guard let identifier = finding.metricIdentifier,
                                  let value = finding.value else { return nil }
                            return VocalHandoffMeasurement(
                                metricIdentifier: identifier,
                                value: value,
                                unit: finding.unit ?? "",
                                confidence: finding.confidence,
                                analysisVersion: context.assessment.analysisVersion,
                                limitation: finding.limitations.joined(separator: " ")
                            )
                        }
                        let builder = VocalGuideCreateHandoffBuilder()
                        let tutorReferences = currentTutorReferences(
                            sourceType: context.sourceType
                        )
                        let handoff = try builder.build(
                            handoffID: UUID(),
                            explicitUserIntentConfirmed: true,
                            candidate: candidate,
                            captureAuthority: authority,
                            reviewedKnowledgeIDs: tutorReferences.knowledgeIDs,
                            reviewedProcedureIDs: tutorReferences.procedureIDs,
                            relevantMeasurements: measurements,
                            createdAt: Date()
                        )
                        try builder.validate(handoff)
                        vocal.loadExecutableHandoff(handoff)
                        if let questionID = tutorReferences.questionID {
                            vocal.noteRequest(
                                "Executable handoff validated with reviewed identifiers copied from Tutor answer \(VocalWorkspacePresentation.shortID(questionID)). Tutor supplied provenance only and no mutation authority."
                            )
                        } else {
                            vocal.noteRequest(
                                "Executable handoff validated with no current, source-consistent reviewed Tutor-answer provenance. Tutor context supplied no mutation authority."
                            )
                        }
                        persistVocalWorkspace()
                    } catch {
                        vocal.markHandoffRefused("Executable Create handoff refused: \(error)")
                    }
                }
            },
            requestCreativeIntent: { prompt, scope, assetAcceptance in
                requestVocalCreativeIntent(
                    prompt: prompt,
                    scope: scope,
                    assetAcceptance: assetAcceptance
                )
            },
            selectCreativeCandidate: { candidate in
                selectVocalAuditionIfAvailable(candidate)
                persistVocalWorkspace()
            },
            requestUseAsWorkingCandidate: { candidate in
                useVocalCandidateAsWorking(candidate)
            },
            requestCandidateRender: { candidate in
                Task {
                    do {
                        let context = try await currentVocalCaptureContext()
                        guard candidate.intent.sourceSnapshotID
                                == context.sourceAuthority.sourceSnapshotID,
                              candidate.plan.sourceSnapshotID
                                == context.sourceAuthority.sourceSnapshotID,
                              completedVocalAuthorityIsCurrent(context.sourceAuthority) else {
                            throw VocalWorkspaceIntegrationError.staleCaptureContext
                        }
                        model.renderVocalCandidate(
                            candidate,
                            sourceAuthority: context.sourceAuthority,
                            completedAuthorityIsCurrent: { authority in
                                completedVocalAuthorityIsCurrent(authority)
                            }
                        )
                    } catch {
                        vocal.setConflict("Vocal candidate render refused: \(error)")
                    }
                }
            },
            requestAspectLock: { candidate, aspect, locked in
                applyVocalLock(candidate: candidate, aspect: aspect, locked: locked)
            },
            requestCreativeRevision: { candidate, prose in
                applyVocalRevision(candidate: candidate, prose: prose)
            },
            requestListeningComparison: { candidate in
                beginVocalListeningComparison(candidate)
            }
        )
    }

    /// Checks the entire immutable capture authority together with the
    /// completed test-take binding. Snapshot identity alone is deliberately
    /// insufficient because a changed hash, format, timestamp, or durable
    /// binding would otherwise let a stale rendered asset become active.
    @MainActor
    private func completedVocalAuthorityIsCurrent(
        _ sourceAuthority: VocalSourceAuthority
    ) -> Bool {
        guard let artifact = model.captureArtifact,
              let context = vocalCaptureRuntimeContext,
              let binding = acceptedVocalTestTakeBinding,
              model.capturedInstanceIsAvailable,
              sourceAuthority == context.sourceAuthority,
              sourceAuthority.sourceSnapshotID == artifact.id,
              context.capturedInstanceID == binding.selectedInstanceID,
              context.capturedRuntimeEpoch == binding.selectedRuntimeEpoch else {
            return false
        }
        return binding.completedAuthorityMatches(
            artifact: artifact,
            assessment: context.assessment,
            sourceAuthority: sourceAuthority,
            brief: vocal.captureBrief,
            interpretation: vocal.activeCaptureInterpretation,
            currentSourceType: model.sourceType
        )
    }

    @MainActor
    private func currentVocalCaptureContext() async throws -> VocalCaptureRuntimeContext {
        if let artifact = model.captureArtifact,
           let binding = acceptedVocalTestTakeBinding,
           let cached = vocalCaptureRuntimeContext,
           cached.sourceAuthority.sourceSnapshotID == artifact.id,
           cached.sourceType == model.sourceType,
           cached.capturedInstanceID == binding.selectedInstanceID,
           cached.capturedRuntimeEpoch == binding.selectedRuntimeEpoch,
           model.capturedInstanceIsAvailable,
           binding.completedAuthorityMatches(
                artifact: artifact,
                assessment: cached.assessment,
                sourceAuthority: cached.sourceAuthority,
                brief: vocal.captureBrief,
                interpretation: vocal.activeCaptureInterpretation,
                currentSourceType: model.sourceType
           ),
           let summary = binding.authoritySummary {
            vocal.loadTestTakeAuthority(summary)
            return cached
        }
        guard let artifact = model.captureArtifact,
              let binding = acceptedVocalTestTakeBinding,
              binding.accepts(
                artifact: artifact,
                brief: vocal.captureBrief,
                interpretation: vocal.activeCaptureInterpretation,
                currentSourceType: model.sourceType
              ) else {
            throw VocalWorkspaceIntegrationError.staleCaptureContext
        }
        guard let context = try await model.vocalCaptureContext() else {
            throw VocalWorkspaceIntegrationError.currentCaptureRequired
        }
        guard context.capturedInstanceID == binding.selectedInstanceID,
              context.capturedRuntimeEpoch == binding.selectedRuntimeEpoch,
              model.capturedInstanceIsAvailable else {
            throw VocalWorkspaceIntegrationError.staleCaptureContext
        }
        let completedBinding = try binding.completing(
            artifact: artifact,
            assessment: context.assessment,
            sourceAuthority: context.sourceAuthority,
            brief: vocal.captureBrief,
            interpretation: vocal.activeCaptureInterpretation,
            currentSourceType: model.sourceType
        )
        guard let durableSourceID = completedBinding.durableImmutableSourceID(),
              let authoritySummary = completedBinding.authoritySummary else {
            throw VocalWorkspaceIntegrationError.staleCaptureContext
        }
        var boundContext = context
        boundContext.sourceAuthority.immutableSourceID = durableSourceID
        guard completedBinding.completedAuthorityMatches(
            artifact: artifact,
            assessment: boundContext.assessment,
            sourceAuthority: boundContext.sourceAuthority,
            brief: vocal.captureBrief,
            interpretation: vocal.activeCaptureInterpretation,
            currentSourceType: model.sourceType
        ) else {
            throw VocalWorkspaceIntegrationError.staleCaptureContext
        }
        acceptedVocalTestTakeBinding = completedBinding
        vocalCaptureRuntimeContext = boundContext
        vocal.loadAnalysis(report: boundContext.analysis, assessment: boundContext.assessment)
        vocal.loadTestTakeAuthority(authoritySummary)
        vocalPersistence.reconcile(
            currentSourceAuthority: boundContext.sourceAuthority,
            into: vocal
        )
        if vocalPersistence.presentationState?.authorityStatus != .current {
            vocal.beginNewTestTake()
        }
        // Reconciliation may restore a saved assessment. The fresh assessment
        // from this exact bound test take is authoritative for current work.
        vocal.loadAnalysis(report: boundContext.analysis, assessment: boundContext.assessment)
        vocal.loadTestTakeAuthority(authoritySummary)
        persistVocalWorkspace()
        return boundContext
    }

    @MainActor
    private func refreshVocalCaptureContext(force: Bool) async {
        if force { vocalCaptureRuntimeContext = nil }
        do {
            _ = try await currentVocalCaptureContext()
        } catch {
            vocal.clearAnalysis()
            vocalPersistence.sourceBecameUnavailable(into: vocal)
            if model.captureArtifact != nil {
                vocal.setConflict("Current Vocal capture unavailable: \(error)")
            }
        }
    }

    private func synchronizeVocalAnalysis(_ report: AudioAnalysis.SourceAwareAnalysisReport?) {
        guard let report else { return }
        guard var context = vocalCaptureRuntimeContext,
              let artifact = model.captureArtifact,
              let binding = acceptedVocalTestTakeBinding,
              context.sourceAuthority.sourceSnapshotID == artifact.id else {
            if mode == .vocal {
                Task { await refreshVocalCaptureContext(force: false) }
            }
            return
        }
        context.analysis = report
        context.assessment = VocalTestTakeAssessor().assess(
            report,
            assessmentID: context.assessment.id
        )
        guard binding.completedAuthorityMatches(
            artifact: artifact,
            assessment: context.assessment,
            sourceAuthority: context.sourceAuthority,
            brief: vocal.captureBrief,
            interpretation: vocal.activeCaptureInterpretation,
            currentSourceType: model.sourceType
        ), let summary = binding.authoritySummary else {
            vocalCaptureRuntimeContext = nil
            acceptedVocalTestTakeBinding = nil
            vocal.clearAnalysis()
            vocalPersistence.sourceBecameUnavailable(into: vocal)
            vocal.setConflict(
                "Current analysis no longer matches the completed test-take transaction; capture again before continuing."
            )
            return
        }
        vocalCaptureRuntimeContext = context
        vocal.loadAnalysis(report: report, assessment: context.assessment)
        vocal.loadTestTakeAuthority(summary)
        persistVocalWorkspace()
    }

    private func requestVocalCreativeIntent(
        prompt: String,
        scope: VocalCreativeScope,
        assetAcceptance: VocalAssetAcceptance
    ) {
        // The button press supersedes all prior Vocal preview/render authority,
        // even while capture-context lookup and typed interpretation suspend.
        // The request token prevents an older lookup from restoring stale UI.
        clearCompanionVocalPlanningAuthority()
        let requestID = UUID()
        activeVocalIntentRequestID = requestID
        Task {
            do {
                let context = try await currentVocalCaptureContext()
                guard activeVocalIntentRequestID == requestID else { return }
                let intent = try VocalIntentInterpreter().interpret(
                    prompt: prompt,
                    sourceSnapshotID: context.sourceAuthority.sourceSnapshotID,
                    scope: scope,
                    assetAcceptance: assetAcceptance
                )
                guard activeVocalIntentRequestID == requestID else { return }
                if let clarification = intent.blockingClarification {
                    presentVocalBlockingClarification(
                        intent,
                        clarification: clarification
                    )
                    return
                }

                // A new typed intent cannot inherit prior candidate, render,
                // revision, handoff, selection, or working-plan authority.
                model.vocalIntent = intent
                vocal.loadCreativeIntent(intent)

                if scope.kind == .fullSource {
                    model.generateVocalPreviews(intent: intent)
                    vocal.noteRequest(
                        "Three full-source Vocal previews requested from the immutable AU capture; no AU activation is implied."
                    )
                    activeVocalIntentRequestID = nil
                    return
                }

                guard assetAcceptance == .allowLocalRenderedAsset
                        || assetAcceptance == .requireLocalRenderedAsset else {
                    throw VocalWorkspaceIntegrationError.scopedAssetPermissionRequired
                }
                let candidates = try VocalCreativePlanner().plan(
                    intent: intent,
                    channelFormat: context.channelFormat,
                    sourceType: context.sourceType,
                    scopeKind: .importedFile,
                    analysis: context.analysis.baseReport
                )
                guard candidates.count == 3,
                      candidates.allSatisfy({ !$0.realtimeActivatable }) else {
                    throw VocalContractError.validationFailed(
                        "Scoped Vocal planning must produce exactly three off-render candidates."
                    )
                }
                model.vocalCandidates = candidates
                model.vocalRevisionRecords = []
                vocal.loadCreativeResult(intent: intent, candidates: candidates)
                persistVocalWorkspace()
                vocal.noteRequest(
                    "Three scoped plans prepared locally from the exact capture. Each requires a separate explicit offline asset render."
                )
                activeVocalIntentRequestID = nil
            } catch let error as VocalContractError {
                guard activeVocalIntentRequestID == requestID else { return }
                if case let .blockingClarificationRequired(clarification) = error,
                   let intent = model.vocalIntent,
                   intent.blockingClarification == clarification {
                    presentVocalBlockingClarification(intent, clarification: clarification)
                } else {
                    vocal.setConflict("Vocal planning refused: \(error)")
                }
                activeVocalIntentRequestID = nil
            } catch {
                guard activeVocalIntentRequestID == requestID else { return }
                vocal.setConflict("Vocal planning refused: \(error)")
                activeVocalIntentRequestID = nil
            }
        }
    }

    /// Presents the one authoritative clarification without leaving a stale
    /// candidate, preview, revision, handoff, or working graph active.
    private func presentVocalBlockingClarification(
        _ intent: VocalCreativeIntent,
        clarification: VocalBlockingClarification
    ) {
        clearCompanionVocalPlanningAuthority()
        model.generateVocalPreviews(intent: intent)
        vocal.loadBlockingClarification(intent, clarification: clarification)
        persistVocalWorkspace()
    }

    private func synchronizeGeneratedVocalCandidates() {
        guard let intent = model.vocalIntent else { return }
        let candidates = model.vocalCandidates
        guard candidates.count == 3,
              candidates.allSatisfy({ $0.intent.id == intent.id }) else { return }
        let incomingIDs = candidates.map(\.id)
        guard vocal.creativeCandidates.map(\.id) != incomingIDs
                || vocal.creativeIntent?.id != intent.id else {
            // Companion-side preview/asset/revision reconciliation writes the
            // already-loaded candidates back to the session model. Do not
            // interpret that echo as a new planning result or erase explicit
            // selection/revision authority.
            return
        }
        vocal.loadCreativeResult(intent: intent, candidates: candidates)
        persistVocalWorkspace()
    }

    private func synchronizeRenderedVocalAsset(_ manifest: VocalRenderedAssetManifest?) {
        guard let manifest else { return }
        guard let currentSourceAuthority = vocalCaptureRuntimeContext?.sourceAuthority,
              manifest.sourceAuthority == currentSourceAuthority,
              completedVocalAuthorityIsCurrent(currentSourceAuthority) else {
            model.discardVocalRenderedAssetOutput()
            vocal.setConflict(
                "Rendered Vocal asset rejected because its completed test-take authority is no longer current."
            )
            return
        }
        guard vocal.loadRenderedAsset(
            manifest,
            expectedSourceAuthority: currentSourceAuthority
        ) else {
            model.discardVocalRenderedAssetOutput()
            return
        }
        model.vocalCandidates = vocal.creativeCandidates
        persistVocalWorkspace()
    }

    private func synchronizeWorkingVocalPreview() {
        guard let preview = model.workingPreview,
              let candidate = vocal.creativeCandidates.first(where: {
                  $0.plan.requestID == preview.plan.requestID
              }) else { return }
        let baseReferences = Dictionary(
            uniqueKeysWithValues: (model.previewManifest?.vocalCreativeCandidates ?? [])
                .compactMap { base -> (UUID, UUID)? in
                    guard let previewID = base.previewID else { return nil }
                    return (base.id, previewID)
                }
        )
        vocal.reconcilePreviewReferences(
            baseReferences: baseReferences,
            currentWorkingCandidateID: candidate.id,
            currentWorkingPreviewID: preview.previewID,
            exactPlanRequestID: preview.plan.requestID
        )
        model.vocalCandidates = vocal.creativeCandidates
        persistVocalWorkspace()
    }

    private func selectVocalAuditionIfAvailable(_ candidate: VocalCreativeCandidate) {
        if let previewID = candidate.previewID,
           let index = model.auditionVariants.firstIndex(where: {
               $0.previewID == previewID
           }) {
            model.selectAudition(index: index + 1)
            return
        }
        if let previewID = candidate.previewID,
           model.workingPreview?.previewID == previewID,
           model.workingPreview?.plan.requestID == candidate.plan.requestID {
            model.selectWorkingAudition()
            return
        }
        if let manifest = model.vocalRenderedAssetManifest,
           manifest.exactCandidateID == candidate.id,
           manifest.renderID == candidate.assetID {
            model.selectAudition(index: 1)
        }
    }

    private func useVocalCandidateAsWorking(_ candidate: VocalCreativeCandidate) {
        guard vocalCandidateHasCurrentAuthority(candidate),
              candidate.realtimeActivatable,
              candidate.intent.scope.kind == .fullSource else {
            vocal.setConflict("Only a current, full-source, locally validated candidate can become the working AU graph.")
            return
        }
        if let previewID = candidate.previewID,
           let index = model.auditionVariants.firstIndex(where: {
               $0.previewID == previewID && $0.plan.requestID == candidate.plan.requestID
           }) {
            model.useVariantAsWorking(index: index + 1)
            vocal.selectCreativeCandidate(candidate)
            vocal.noteRequest(
                "Candidate \(VocalWorkspacePresentation.shortID(candidate.id)) is now the exact working graph. Commit remains a separate explicit action."
            )
            persistVocalWorkspace()
            return
        }
        if model.workingPlan?.requestID == candidate.plan.requestID {
            vocal.selectCreativeCandidate(candidate)
            vocal.noteRequest("This exact candidate is already the working graph; no commit was performed.")
            persistVocalWorkspace()
            return
        }
        vocal.setConflict("The exact candidate has no loaded validated preview. Render it explicitly before using it as working.")
    }

    private var vocalWorkingCommitAuthorityIsCurrent: Bool {
        guard let requestID = model.workingPlan?.requestID,
              let candidate = vocal.creativeCandidates.first(where: {
                  $0.plan.requestID == requestID
              }) else { return false }
        return candidate.realtimeActivatable
            && candidate.intent.scope.kind == .fullSource
            && vocalCandidateHasCurrentAuthority(candidate)
    }

    private func vocalCandidateHasCurrentAuthority(
        _ candidate: VocalCreativeCandidate
    ) -> Bool {
        guard let artifact = model.captureArtifact,
              let context = vocalCaptureRuntimeContext,
              let binding = acceptedVocalTestTakeBinding,
              model.capturedInstanceIsAvailable,
              vocalPersistence.presentationState?.authorityStatus == .current,
              candidate.authorityStatus == .locallyValidated,
              candidate.intent.sourceSnapshotID == artifact.id,
              candidate.plan.sourceSnapshotID == artifact.id else { return false }
        return binding.completedAuthorityMatches(
            artifact: artifact,
            assessment: context.assessment,
            sourceAuthority: context.sourceAuthority,
            brief: vocal.captureBrief,
            interpretation: vocal.activeCaptureInterpretation,
            currentSourceType: model.sourceType
        )
    }

    private func beginVocalListeningComparison(_ candidate: VocalCreativeCandidate) {
        if let previewID = candidate.previewID,
           let index = model.auditionVariants.firstIndex(where: {
               $0.previewID == previewID
           }) {
            model.rewind()
            model.selectAudition(index: index + 1)
            model.togglePlayback()
            return
        }
        if let previewID = candidate.previewID,
           model.workingPreview?.previewID == previewID,
           model.workingPreview?.plan.requestID == candidate.plan.requestID {
            model.rewind()
            model.selectWorkingAudition()
            model.togglePlayback()
            return
        }
        if let manifest = model.vocalRenderedAssetManifest,
           manifest.exactCandidateID == candidate.id,
           manifest.renderID == candidate.assetID {
            model.rewind()
            model.selectAudition(index: 1)
            model.togglePlayback()
            return
        }
        vocal.setConflict(VocalWorkspaceIntegrationError.previewUnavailable.description)
    }

    private func applyVocalLock(
        candidate: VocalCreativeCandidate,
        aspect: VocalAspect,
        locked: Bool
    ) {
        let operation: VocalRevisionOperation = locked
            ? .lockAspect(aspect)
            : .unlockAspect(aspect)
        let command = VocalRevisionCommand(
            id: UUID(),
            originalProse: locked
                ? "Lock \(aspect.rawValue)"
                : "Unlock \(aspect.rawValue)",
            operations: [operation],
            parsedAgainstCandidateIDs: orderedVocalRevisionCandidateIDs(selected: candidate.id)
        )
        applyVocalRevision(command, to: candidate)
    }

    private func applyVocalRevision(
        candidate: VocalCreativeCandidate,
        prose: String
    ) {
        do {
            let authority = VocalRevisionReferenceAuthority(
                orderedCandidateIDs: orderedVocalRevisionCandidateIDs(selected: candidate.id),
                selectedCandidateID: candidate.id,
                lastPhraseScope: vocal.creativeScope.kind == .fullSource
                    ? nil
                    : vocal.creativeScope,
                explicitRevertCandidateID: candidate.parentCandidateID.flatMap { parentID in
                    currentVocalRevisionHistory.contains(where: { $0.id == parentID }) ? parentID : nil
                }
            )
            let command = try VocalRevisionParser().parse(prose, authority: authority)
            applyVocalRevision(command, to: candidate)
        } catch {
            vocal.setConflict("Typed Vocal revision refused: \(error)")
        }
    }

    private func applyVocalRevision(
        _ command: VocalRevisionCommand,
        to candidate: VocalCreativeCandidate
    ) {
        guard let artifact = model.captureArtifact,
              let context = vocalCaptureRuntimeContext,
              let binding = acceptedVocalTestTakeBinding,
              model.capturedInstanceIsAvailable,
              candidate.authorityStatus == .locallyValidated,
              candidate.intent.sourceSnapshotID == artifact.id,
              candidate.plan.sourceSnapshotID == artifact.id,
              vocal.creativeCandidates.contains(where: { $0.id == candidate.id }),
              binding.completedAuthorityMatches(
                artifact: artifact,
                assessment: context.assessment,
                sourceAuthority: context.sourceAuthority,
                brief: vocal.captureBrief,
                interpretation: vocal.activeCaptureInterpretation,
                currentSourceType: model.sourceType
              ) else {
            vocal.setConflict(
                "Typed Vocal revision refused because the selected candidate or completed test-take authority is not current."
            )
            return
        }
        do {
            let result = try VocalRevisionEngine().apply(
                command,
                to: candidate,
                availableCandidates: currentVocalRevisionHistory,
                ids: VocalRevisionApplicationIDs(
                    resultCandidateID: UUID(),
                    resultIntentID: UUID(),
                    resultPlanRequestID: UUID(),
                    insertedNodeIDs: (0..<8).map { _ in UUID() },
                    aspectLockIDs: (0..<8).map { _ in UUID() }
                ),
                createdAt: Date()
            )
            vocal.loadCreativeRevision(result)
            model.vocalCandidates = vocal.creativeCandidates
            model.vocalRevisionRecords.append(result.record)
            persistVocalWorkspace()
        } catch {
            vocal.setConflict("Typed Vocal revision refused: \(error)")
        }
    }

    private var currentVocalRevisionHistory: [VocalCreativeCandidate] {
        guard let sourceSnapshotID = model.captureArtifact?.id,
              vocalPersistence.presentationState?.authorityStatus == .current else {
            return []
        }
        var seen = Set<UUID>()
        return (vocal.creativeCandidates + vocalPersistence.allCandidates)
            .filter {
                $0.authorityStatus == .locallyValidated
                    && $0.intent.sourceSnapshotID == sourceSnapshotID
                    && $0.plan.sourceSnapshotID == sourceSnapshotID
            }
            .filter { seen.insert($0.id).inserted }
    }

    private func orderedVocalRevisionCandidateIDs(selected: UUID) -> [UUID] {
        var seen = Set<UUID>()
        let currentIDs = Set(currentVocalRevisionHistory.map(\.id))
        let visible = vocal.creativeCandidates
            .filter { currentIDs.contains($0.id) }
            .map(\.id)
        let historical = currentVocalRevisionHistory.map(\.id)
        let ordered = (visible + historical).filter { seen.insert($0).inserted }
        if ordered.contains(selected) { return ordered }
        return [selected] + ordered
    }

    private func beginBoundVocalTestTake() -> Bool {
        guard model.sourceType == .vocal || model.sourceType == .vocalBus else {
            vocal.setConflict("A bound Vocal test take requires Vocal or Vocal Bus as the selected source type.")
            return false
        }
        guard let brief = vocal.captureBrief,
              let interpretation = vocal.activeCaptureInterpretation,
              !interpretation.comparison.testTakeLabel
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let instance = model.selectedInstance else {
            vocal.setConflict(
                "Load a typed capture brief, select one capture hypothesis, and choose an active TrackSmith insert before capture."
            )
            return false
        }
        do {
            let binding = try VocalTestTakeBinding.make(
                captureBrief: brief,
                interpretation: interpretation,
                selectedInstanceID: instance.id,
                selectedRuntimeEpoch: instance.runtimeEpoch,
                sourceType: model.sourceType
            )
            pendingVocalTestTakeBinding = binding
            acceptedVocalTestTakeBinding = nil
            vocalCaptureRuntimeContext = nil
            vocal.beginNewTestTake()
            clearCompanionVocalPlanningAuthority()
            vocal.noteRequest(
                "Bound test take started for brief \(VocalWorkspacePresentation.shortID(brief.id)), capture \(VocalWorkspacePresentation.shortID(interpretation.id)), label \(binding.testTakeLabel), and the selected AU runtime."
            )
            return true
        } catch {
            pendingVocalTestTakeBinding = nil
            acceptedVocalTestTakeBinding = nil
            vocalCaptureRuntimeContext = nil
            vocal.setConflict("The bound Vocal test take could not start: \(error)")
            return false
        }
    }

    private func acceptPendingVocalTestTake() -> Bool {
        guard let artifact = model.captureArtifact,
              let binding = pendingVocalTestTakeBinding ?? acceptedVocalTestTakeBinding,
              let accepted = binding.accepting(
                artifact: artifact,
                brief: vocal.captureBrief,
                interpretation: vocal.activeCaptureInterpretation,
                currentSourceType: model.sourceType
              ) else {
            pendingVocalTestTakeBinding = nil
            acceptedVocalTestTakeBinding = nil
            vocal.setConflict(
                "Captured audio was not accepted as this Vocal test take because its brief, interpretation/revision, label, source type, AU instance, or runtime binding changed."
            )
            return false
        }
        acceptedVocalTestTakeBinding = accepted
        pendingVocalTestTakeBinding = nil
        vocal.noteRequest(
            "Bound test take accepted. Binding \(VocalWorkspacePresentation.shortID(accepted.id)) will become authoritative only after the exact result assessment and source hash complete the transaction."
        )
        return true
    }

    private func persistVocalWorkspace() {
        vocalPersistence.save(
            workspace: vocal,
            currentSourceAuthority: vocalCaptureRuntimeContext?.sourceAuthority,
            revisionRecords: model.vocalRevisionRecords,
            renderedAssetManifest: model.vocalRenderedAssetManifest
        )
    }

    private func invalidateBoundVocalRuntimeAuthority() {
        pendingVocalTestTakeBinding = nil
        acceptedVocalTestTakeBinding = nil
        vocalCaptureRuntimeContext = nil
        model.sourceAwareAnalysis = nil
        clearCompanionVocalPlanningAuthority()
    }

    private func clearCompanionVocalPlanningAuthority() {
        activeVocalIntentRequestID = nil
        model.vocalIntent = nil
        model.vocalCandidates = []
        model.vocalRevisionRecords = []
        model.clearVocalPreviewAuthority()
    }

    private func restoreExactVocalCandidate(_ candidate: VocalCreativeCandidate) {
        var exact = candidate
        if let previewID = exact.previewID,
           !model.auditionVariants.contains(where: {
               $0.previewID == previewID && $0.plan.requestID == exact.plan.requestID
           }),
           model.workingPreview?.previewID != previewID {
            exact.previewID = nil
        }
        if let assetID = exact.assetID,
           model.vocalRenderedAssetManifest?.renderID != assetID {
            exact.assetID = nil
        }
        vocal.restoreHistoricalCandidate(exact)
        model.vocalIntent = exact.intent
        model.vocalCandidates = vocal.creativeCandidates
        persistVocalWorkspace()
    }

    private func boundedUniqueTutorIDs(_ input: [String]) -> [String] {
        var seen = Set<String>()
        return input.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  trimmed.utf8.count <= 512,
                  seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
        .prefix(128)
        .map { $0 }
    }

    private func currentTutorReferences(
        sourceType: SourceType
    ) -> (knowledgeIDs: [String], procedureIDs: [String], questionID: UUID?) {
        guard let outcome = tutor.generalOutcome,
              outcome.answer.questionID == outcome.intent.questionID,
              outcome.intent.sourceType == sourceType,
              outcome.answer.answerMode == .groundedAnswer,
              !outcome.answer.requiresCurrentResearch,
              outcome.answer.provisionalResearchStatus == nil,
              !outcome.answer.audioInfluence.captureAvailable else {
            // Tutor answers do not carry immutable capture identity. If audio
            // influenced an answer, its references cannot be represented as
            // provenance for this exact Vocal capture transaction.
            return ([], [], nil)
        }
        let retrievedClaimIDs = Set(outcome.retrieved.claims.map(\.id))
        let retrievedSourceIDs = Set(outcome.retrieved.sourceIDs)
        guard outcome.answer.knowledgeClaimIDs.allSatisfy(retrievedClaimIDs.contains),
              outcome.answer.sourceIDs.allSatisfy(retrievedSourceIDs.contains) else {
            return ([], [], nil)
        }
        let knowledgeIDs = boundedUniqueTutorIDs(outcome.answer.knowledgeClaimIDs)
        let procedureIDs = boundedUniqueTutorIDs(outcome.answer.exactProcedureIDs)
        guard !knowledgeIDs.isEmpty || !procedureIDs.isEmpty else { return ([], [], nil) }
        return (knowledgeIDs, procedureIDs, outcome.answer.questionID)
    }
}
