import AudioAnalysis
import Combine
import Foundation
import VocalProduction

struct VocalGuideCreateHandoffSummary: Equatable {
    var captureBriefID: UUID
    var interpretationID: UUID
    var revisionID: UUID?
    var assessmentID: UUID
    var testTakeBindingID: UUID
    var sourceSnapshotID: UUID
    var completedBindingHashSHA256: String
    var desiredResult: String
    var preservePerformanceAttributes: [VocalPerformanceAttribute]
    var preserveVoiceAspects: [VocalAspect]
    var assumptions: [String]
    var uncertainties: [String]
}

enum VocalGuideCreateHandoffState: Equatable {
    case notRequested
    case captureContextRequestPending(VocalGuideCreateHandoffSummary)
    case captureContextPrepared(VocalGuideCreateHandoffSummary)
    case executableHandoffPrepared(VocalGuideCreateHandoffSummary, VocalGuideCreateHandoff)
    case refused(String)
}

struct VocalWorkspaceCallbacks {
    var requestCaptureInterpretations: (VocalCaptureBrief) -> Void
    var selectCaptureInterpretation: (VocalCaptureInterpretation) -> Void
    var submitCaptureListening: (VocalCaptureInterpretation, VocalCaptureListeningFeedback) -> Void
    var requestCaptureRevision: (
        VocalCaptureInterpretation,
        VocalTestTakeAssessment?,
        VocalCaptureListeningFeedback
    ) -> Void
    var requestGuideCreateHandoff: (VocalGuideCreateHandoffSummary) -> Void
    var requestExecutableHandoff: (VocalGuideCreateHandoffSummary, VocalCreativeCandidate) -> Void
    var requestCreativeIntent: (String, VocalCreativeScope, VocalAssetAcceptance) -> Void
    var selectCreativeCandidate: (VocalCreativeCandidate) -> Void
    var requestUseAsWorkingCandidate: (VocalCreativeCandidate) -> Void
    var requestCandidateRender: (VocalCreativeCandidate) -> Void
    var requestAspectLock: (VocalCreativeCandidate, VocalAspect, Bool) -> Void
    var requestCreativeRevision: (VocalCreativeCandidate, String) -> Void
    var requestListeningComparison: (VocalCreativeCandidate) -> Void

    init(
        requestCaptureInterpretations: @escaping (VocalCaptureBrief) -> Void = { _ in },
        selectCaptureInterpretation: @escaping (VocalCaptureInterpretation) -> Void = { _ in },
        submitCaptureListening: @escaping (
            VocalCaptureInterpretation,
            VocalCaptureListeningFeedback
        ) -> Void = { _, _ in },
        requestCaptureRevision: @escaping (
            VocalCaptureInterpretation,
            VocalTestTakeAssessment?,
            VocalCaptureListeningFeedback
        ) -> Void = { _, _, _ in },
        requestGuideCreateHandoff: @escaping (VocalGuideCreateHandoffSummary) -> Void = { _ in },
        requestExecutableHandoff: @escaping (
            VocalGuideCreateHandoffSummary,
            VocalCreativeCandidate
        ) -> Void = { _, _ in },
        requestCreativeIntent: @escaping (
            String,
            VocalCreativeScope,
            VocalAssetAcceptance
        ) -> Void = { _, _, _ in },
        selectCreativeCandidate: @escaping (VocalCreativeCandidate) -> Void = { _ in },
        requestUseAsWorkingCandidate: @escaping (VocalCreativeCandidate) -> Void = { _ in },
        requestCandidateRender: @escaping (VocalCreativeCandidate) -> Void = { _ in },
        requestAspectLock: @escaping (VocalCreativeCandidate, VocalAspect, Bool) -> Void = { _, _, _ in },
        requestCreativeRevision: @escaping (VocalCreativeCandidate, String) -> Void = { _, _ in },
        requestListeningComparison: @escaping (VocalCreativeCandidate) -> Void = { _ in }
    ) {
        self.requestCaptureInterpretations = requestCaptureInterpretations
        self.selectCaptureInterpretation = selectCaptureInterpretation
        self.submitCaptureListening = submitCaptureListening
        self.requestCaptureRevision = requestCaptureRevision
        self.requestGuideCreateHandoff = requestGuideCreateHandoff
        self.requestExecutableHandoff = requestExecutableHandoff
        self.requestCreativeIntent = requestCreativeIntent
        self.selectCreativeCandidate = selectCreativeCandidate
        self.requestUseAsWorkingCandidate = requestUseAsWorkingCandidate
        self.requestCandidateRender = requestCandidateRender
        self.requestAspectLock = requestAspectLock
        self.requestCreativeRevision = requestCreativeRevision
        self.requestListeningComparison = requestListeningComparison
    }
}

/// UI state for the Vocal v1 path. Domain objects remain typed and are supplied by the parent;
/// this model never infers host authority, invents a render, or records a listening result.
@MainActor
final class VocalWorkspaceModel: ObservableObject {
    @Published private(set) var captureBrief: VocalCaptureBrief?
    @Published private(set) var captureInterpretations: [VocalCaptureInterpretation]
    @Published private(set) var selectedCaptureInterpretationID: UUID?
    @Published private(set) var sourceAwareAnalysis: SourceAwareAnalysisReport?
    @Published private(set) var testTakeAssessment: VocalTestTakeAssessment?
    @Published private(set) var testTakeAuthority: VocalTestTakeAuthoritySummary?
    @Published var captureFeedback: VocalCaptureListeningFeedback
    @Published private(set) var latestCaptureRevision: VocalCaptureRevisionResult?
    @Published private(set) var handoffState: VocalGuideCreateHandoffState

    @Published var creativePrompt: String
    @Published private(set) var creativeScope: VocalCreativeScope
    @Published var assetAcceptance: VocalAssetAcceptance
    @Published private(set) var creativeIntent: VocalCreativeIntent?
    @Published private(set) var blockingClarification: VocalBlockingClarification?
    @Published private(set) var creativeCandidates: [VocalCreativeCandidate]
    @Published private(set) var latestCreativeRevision: VocalRevisionResult?
    @Published private(set) var selectedCreativeCandidateID: UUID?
    @Published var creativeRevisionText: String
    @Published private(set) var revisionLastPhraseScope: VocalCreativeScope?
    @Published private(set) var explicitRevertCandidateID: UUID?

    @Published var scopeStartText: String
    @Published var scopeEndText: String
    @Published var scopeSectionID: String
    @Published var scopeSectionName: String
    @Published private(set) var scopeDraftError: String?
    @Published private(set) var validationMessage: String?
    @Published private(set) var conflictMessage: String?
    @Published private(set) var requestNotice: String?

    private let scopeID: UUID

    init(
        captureBrief: VocalCaptureBrief? = nil,
        captureInterpretations: [VocalCaptureInterpretation] = [],
        creativeScope: VocalCreativeScope = .fullSource(id: UUID())
    ) {
        self.captureBrief = captureBrief
        self.captureInterpretations = []
        self.selectedCaptureInterpretationID = nil
        self.sourceAwareAnalysis = nil
        self.testTakeAssessment = nil
        self.testTakeAuthority = nil
        self.captureFeedback = VocalCaptureListeningFeedback()
        self.latestCaptureRevision = nil
        self.handoffState = .notRequested
        self.creativePrompt = ""
        self.creativeScope = creativeScope
        self.assetAcceptance = .editableDSPOnly
        self.creativeIntent = nil
        self.blockingClarification = nil
        self.creativeCandidates = []
        self.latestCreativeRevision = nil
        self.selectedCreativeCandidateID = nil
        self.creativeRevisionText = ""
        self.revisionLastPhraseScope = nil
        self.explicitRevertCandidateID = nil
        self.scopeStartText = creativeScope.seconds.map { String($0.start) } ?? "0"
        self.scopeEndText = creativeScope.seconds.map { String($0.end) } ?? "10"
        self.scopeSectionID = creativeScope.sectionID ?? "section-1"
        self.scopeSectionName = creativeScope.sectionName ?? "Selected section"
        self.scopeDraftError = nil
        self.validationMessage = nil
        self.conflictMessage = nil
        self.requestNotice = nil
        self.scopeID = creativeScope.id
        if !captureInterpretations.isEmpty {
            acceptCaptureInterpretations(captureInterpretations)
        }
    }

    var activeCaptureInterpretation: VocalCaptureInterpretation? {
        if let revised = latestCaptureRevision?.revisedInterpretation,
           revised.id == selectedCaptureInterpretationID {
            return revised
        }
        return captureInterpretations.first { $0.id == selectedCaptureInterpretationID }
    }

    var selectedCreativeCandidate: VocalCreativeCandidate? {
        creativeCandidates.first { $0.id == selectedCreativeCandidateID }
    }

    var hasCaptureFeedback: Bool {
        let ratings = [
            captureFeedback.wordClarity,
            captureFeedback.breathBlastOrPlosiveRisk,
            captureFeedback.sharpHighFrequencyEvents,
            captureFeedback.roomOrReflectionImpression,
            captureFeedback.betweenPhraseNoise,
            captureFeedback.performanceComfort,
            captureFeedback.voiceNaturalness,
        ]
        return ratings.contains { $0 != .notAssessed }
            || captureFeedback.proximity != .notAssessed
            || !(captureFeedback.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var canRequestCreativeIntent: Bool {
        !creativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && scopeDraftError == nil
    }

    func loadCaptureBrief(
        _ brief: VocalCaptureBrief,
        interpretations: [VocalCaptureInterpretation]
    ) {
        captureBrief = brief
        latestCaptureRevision = nil
        clearCurrentTestTakeAuthority()
        clearCreativeAuthorityForCaptureChange()
        handoffState = .notRequested
        acceptCaptureInterpretations(interpretations)
    }

    func loadCaptureBrief(_ brief: VocalCaptureBrief) {
        captureBrief = brief
        captureInterpretations = []
        selectedCaptureInterpretationID = nil
        latestCaptureRevision = nil
        clearCurrentTestTakeAuthority()
        clearCreativeAuthorityForCaptureChange()
        handoffState = .notRequested
        validationMessage = nil
        requestNotice = "Typed capture brief loaded; three capture hypotheses have not been supplied yet."
    }

    func loadCaptureInterpretations(_ interpretations: [VocalCaptureInterpretation]) {
        acceptCaptureInterpretations(interpretations)
    }

    func selectCaptureInterpretation(_ interpretation: VocalCaptureInterpretation) {
        guard captureInterpretations.contains(where: { $0.id == interpretation.id })
                || latestCaptureRevision?.revisedInterpretation.id == interpretation.id else {
            validationMessage = "The selected capture interpretation is not part of this workspace."
            return
        }
        selectedCaptureInterpretationID = interpretation.id
        clearCurrentTestTakeAuthority()
        clearCreativeAuthorityForCaptureChange()
        handoffState = .notRequested
        requestNotice = "Capture interpretation selected. No listening preference is implied."
    }

    func isCaptureInterpretationSelected(_ interpretation: VocalCaptureInterpretation) -> Bool {
        guard let selectedCaptureInterpretationID else { return false }
        if selectedCaptureInterpretationID == interpretation.id { return true }
        guard let revised = latestCaptureRevision?.revisedInterpretation,
              revised.id == selectedCaptureInterpretationID else { return false }
        return revised.ancestry.contains(interpretation.id)
    }

    func loadAnalysis(
        report: SourceAwareAnalysisReport,
        assessment: VocalTestTakeAssessment
    ) {
        sourceAwareAnalysis = report
        testTakeAssessment = assessment
        requestNotice = "A typed analysis report is available. Listening-only labels remain unmeasured."
    }

    func loadTestTakeAuthority(_ authority: VocalTestTakeAuthoritySummary) {
        guard authority.captureBriefID == captureBrief?.id,
              authority.capturePlanID == activeCaptureInterpretation?.id,
              authority.captureRevisionID == activeCaptureInterpretation?.revisionID,
              authority.resultAssessmentID == testTakeAssessment?.id else {
            validationMessage = "Completed test-take authority does not match the current brief, capture plan, revision, or assessment."
            testTakeAuthority = nil
            return
        }
        testTakeAuthority = authority
        validationMessage = nil
        if !authority.sourceIsCurrent {
            requestNotice = "Completed test-take provenance was restored and verified against saved typed state, but its source is historical/read-only until exact live authority reconciles."
        }
    }

    func clearAnalysis() {
        sourceAwareAnalysis = nil
        testTakeAssessment = nil
        testTakeAuthority = nil
    }

    func beginNewTestTake() {
        clearCurrentTestTakeAuthority()
        captureFeedback = VocalCaptureListeningFeedback()
        handoffState = .notRequested
        clearCreativeAuthorityForCaptureChange()
        validationMessage = nil
        conflictMessage = nil
        requestNotice = "A new bound test-take transaction started. Earlier creative and handoff authority remains only in saved history."
    }

    func loadPersistedAssessment(_ assessment: VocalTestTakeAssessment?) {
        sourceAwareAnalysis = nil
        testTakeAssessment = assessment
        testTakeAuthority = nil
        if assessment != nil {
            requestNotice = "A saved assessment reference was restored read-only. Re-capture and re-analyze before using it as current authority."
        }
    }

    func loadCaptureRevision(_ revision: VocalCaptureRevisionResult) {
        guard captureInterpretations.contains(where: {
            revision.revisedInterpretation.ancestry.contains($0.id)
                || revision.revisedInterpretation.parentInterpretationID == $0.id
        }) else {
            validationMessage = "The capture revision does not descend from one of the three visible interpretations."
            return
        }
        latestCaptureRevision = revision
        selectedCaptureInterpretationID = revision.revisedInterpretation.id
        clearCurrentTestTakeAuthority()
        clearCreativeAuthorityForCaptureChange()
        handoffState = .notRequested
        requestNotice = "A typed capture revision was loaded; it has not been auditioned here."
    }

    func makeHandoffSummary() -> VocalGuideCreateHandoffSummary? {
        guard let captureBrief,
              let selected = activeCaptureInterpretation,
              let assessment = testTakeAssessment,
              let authority = testTakeAuthority,
              authority.sourceIsCurrent,
              authority.captureBriefID == captureBrief.id,
              authority.capturePlanID == selected.id,
              authority.captureRevisionID == selected.revisionID,
              authority.resultAssessmentID == assessment.id else { return nil }
        return VocalGuideCreateHandoffSummary(
            captureBriefID: captureBrief.id,
            interpretationID: selected.id,
            revisionID: selected.revisionID,
            assessmentID: assessment.id,
            testTakeBindingID: authority.bindingID,
            sourceSnapshotID: authority.resultCaptureID,
            completedBindingHashSHA256: authority.completedBindingHashSHA256,
            desiredResult: captureBrief.desiredResult,
            preservePerformanceAttributes: captureBrief.preservePerformanceAttributes,
            preserveVoiceAspects: captureBrief.preserveVoiceAttributes,
            assumptions: selected.assumptions,
            uncertainties: selected.uncertainty
        )
    }

    func markHandoffRequested(_ summary: VocalGuideCreateHandoffSummary) {
        handoffState = .captureContextRequestPending(summary)
        requestNotice = "Guide → Create capture context requested; no executable handoff or render exists yet."
    }

    func markHandoffPrepared(_ summary: VocalGuideCreateHandoffSummary) {
        guard case let .captureContextRequestPending(expected) = handoffState,
              expected == summary,
              makeHandoffSummary() == summary else {
            handoffState = .refused(
                "Prepared handoff rejected because capture selection, revision, or assessment identity changed."
            )
            return
        }
        handoffState = .captureContextPrepared(summary)
        requestNotice = "The parent accepted typed capture context for Create. This is not yet an executable handoff."
    }

    func loadExecutableHandoff(_ handoff: VocalGuideCreateHandoff) {
        do {
            try VocalGuideCreateHandoffBuilder().validate(handoff)
            guard let summary = makeHandoffSummary(),
                  let candidate = creativeCandidates.first(where: {
                      $0.id == handoff.proposal.candidateID
                  }),
                  candidate.intent.id == handoff.explicitUserIntentID,
                  candidate.intent.sourceSnapshotID == handoff.proposal.sourceSnapshotID,
                  handoff.captureAuthority.captureBriefID == nil
                    || handoff.captureAuthority.captureBriefID == summary.captureBriefID,
                  handoff.captureAuthority.selectedCaptureInterpretationID == nil
                    || handoff.captureAuthority.selectedCaptureInterpretationID == summary.interpretationID,
                  handoff.captureAuthority.testTakeAssessmentID == nil
                    || handoff.captureAuthority.testTakeAssessmentID == summary.assessmentID else {
                throw VocalHandoffError.staleSource
            }
            handoffState = .executableHandoffPrepared(summary, handoff)
            requestNotice = "A validated executable handoff was loaded. Final user action is still required; nothing was activated or rendered here."
        } catch {
            handoffState = .refused("Executable handoff rejected: \(error)")
        }
    }

    func markHandoffRefused(_ reason: String) {
        handoffState = .refused(reason)
    }

    func setCreativeScopeKind(_ kind: VocalScopeKind) {
        switch kind {
        case .fullSource:
            creativeScope = .fullSource(id: scopeID)
            scopeDraftError = nil
        case .seconds:
            rebuildTimedScope(named: false)
        case .namedSection:
            rebuildTimedScope(named: true)
        }
    }

    func updateScopeDraft() {
        switch creativeScope.kind {
        case .fullSource:
            scopeDraftError = nil
        case .seconds:
            rebuildTimedScope(named: false)
        case .namedSection:
            rebuildTimedScope(named: true)
        }
    }

    func loadCreativeResult(
        intent: VocalCreativeIntent,
        candidates: [VocalCreativeCandidate]
    ) {
        if let clarification = intent.blockingClarification {
            loadBlockingClarification(intent, clarification: clarification)
            return
        }
        do {
            try VocalContractValidator().validate(intent: intent)
            guard candidates.count == 3,
                  Set(candidates.map(\.id)).count == 3,
                  Set(candidates.map(\.interpretationIndex)) == Set(1...3) else {
                validationMessage = "Vocal Create requires exactly three unique, indexed candidate hypotheses."
                creativeCandidates = []
                selectedCreativeCandidateID = nil
                return
            }
            for candidate in candidates {
                try VocalContractValidator().validate(candidate: candidate)
                guard candidate.intent.id == intent.id else {
                    throw VocalContractError.validationFailed(
                        "A candidate carries a different creative intent identity."
                    )
                }
            }
            creativeIntent = intent
            creativeScope = intent.scope
            synchronizeScopeDraft(from: intent.scope)
            assetAcceptance = intent.assetAcceptance
            creativeCandidates = candidates.sorted { $0.interpretationIndex < $1.interpretationIndex }
            blockingClarification = nil
            latestCreativeRevision = nil
            // Rendering the three hypotheses does not choose hypothesis 1.
            // Selection, Use as working, and Commit remain separate actions.
            selectedCreativeCandidateID = nil
            clearRevisionReferenceAuthority()
            handoffState = .notRequested
            conflictMessage = nil
            validationMessage = nil
            requestNotice = "Three typed hypotheses loaded. No candidate is rendered or preferred by this state alone."
        } catch {
            creativeIntent = nil
            creativeCandidates = []
            selectedCreativeCandidateID = nil
            validationMessage = "Typed creative result rejected: \(error)"
        }
    }

    func loadCreativeIntent(_ intent: VocalCreativeIntent) {
        if let clarification = intent.blockingClarification {
            loadBlockingClarification(intent, clarification: clarification)
            return
        }
        do {
            try VocalContractValidator().validate(intent: intent)
            creativeIntent = intent
            creativePrompt = intent.originalPrompt
            creativeScope = intent.scope
            synchronizeScopeDraft(from: intent.scope)
            assetAcceptance = intent.assetAcceptance
            blockingClarification = nil
            creativeCandidates = []
            selectedCreativeCandidateID = nil
            latestCreativeRevision = nil
            clearRevisionReferenceAuthority()
            handoffState = .notRequested
            conflictMessage = nil
            validationMessage = nil
            requestNotice = "Typed creative intent loaded; three executable hypotheses have not been supplied yet."
        } catch {
            creativeIntent = nil
            validationMessage = "Typed creative intent rejected: \(error)"
        }
    }

    /// Holds a locally validated but non-executable interpretation while the
    /// user supplies the one missing creative priority. This intentionally
    /// removes every downstream candidate, revision, handoff, render, and
    /// working-selection authority rather than treating ordinary prose as a
    /// request for a default sound.
    func loadBlockingClarification(
        _ intent: VocalCreativeIntent,
        clarification: VocalBlockingClarification
    ) {
        do {
            try VocalContractValidator().validate(intent: intent)
            guard intent.blockingClarification == clarification else {
                throw VocalContractError.validationFailed(
                    "The supplied Vocal clarification does not match the typed intent."
                )
            }
            creativeIntent = intent
            creativePrompt = intent.originalPrompt
            creativeScope = intent.scope
            synchronizeScopeDraft(from: intent.scope)
            assetAcceptance = intent.assetAcceptance
            blockingClarification = clarification
            creativeCandidates = []
            latestCreativeRevision = nil
            selectedCreativeCandidateID = nil
            creativeRevisionText = ""
            clearRevisionReferenceAuthority()
            handoffState = .notRequested
            conflictMessage = nil
            validationMessage = clarification.prompt
            requestNotice = nil
        } catch {
            blockingClarification = nil
            creativeIntent = nil
            creativeCandidates = []
            latestCreativeRevision = nil
            selectedCreativeCandidateID = nil
            validationMessage = "Typed blocking clarification rejected: \(error)"
        }
    }

    func loadCreativeCandidates(_ candidates: [VocalCreativeCandidate]) {
        guard let intent = creativeIntent else {
            validationMessage = "Creative candidates require a validated typed intent first."
            return
        }
        if let clarification = intent.blockingClarification {
            loadBlockingClarification(intent, clarification: clarification)
            return
        }
        loadCreativeResult(intent: intent, candidates: candidates)
    }

    func loadCreativeRevision(_ revision: VocalRevisionResult) {
        if let clarification = revision.candidate.intent.blockingClarification {
            loadBlockingClarification(revision.candidate.intent, clarification: clarification)
            return
        }
        do {
            try VocalContractValidator().validate(candidate: revision.candidate)
            guard revision.record.resultCandidateID == revision.candidate.id,
                  revision.record.id == revision.candidate.revisionID,
                  let replacementIndex = creativeCandidates.firstIndex(where: {
                      $0.id == revision.record.baseCandidateID
                  }),
                  creativeCandidates[replacementIndex].authorityStatus == .locallyValidated,
                  revision.candidate.authorityStatus == .locallyValidated,
                  creativeCandidates[replacementIndex].intent.sourceSnapshotID
                    == revision.candidate.intent.sourceSnapshotID,
                  creativeCandidates[replacementIndex].plan.sourceSnapshotID
                    == revision.candidate.plan.sourceSnapshotID,
                  revision.record.exactAncestorCandidateIDs.contains(
                      revision.record.baseCandidateID
                  ) else {
                throw VocalContractError.missingReference(revision.record.baseCandidateID)
            }
            creativeCandidates[replacementIndex] = revision.candidate
            creativeCandidates.sort { $0.interpretationIndex < $1.interpretationIndex }
            selectedCreativeCandidateID = revision.candidate.id
            latestCreativeRevision = revision
            requestNotice = "A typed candidate revision was loaded with exact ancestry; it has not been rendered or listened to here."
        } catch {
            validationMessage = "Creative revision rejected: \(error)"
        }
    }

    /// Restores the three currently visible leaves while retaining complete
    /// ancestry in the persistence coordinator. Unlike a fresh planning result,
    /// the leaves may carry different revision intent identities.
    func restorePersistedCreativeState(
        candidates: [VocalCreativeCandidate],
        selectedCandidateID: UUID?,
        latestRevision: VocalRevisionResult?
    ) {
        if let intent = candidates.map(\.intent).first(where: {
            $0.blockingClarification != nil
        }), let clarification = intent.blockingClarification {
            loadBlockingClarification(intent, clarification: clarification)
            return
        }
        do {
            guard candidates.count == 3,
                  Set(candidates.map(\.id)).count == 3,
                  Set(candidates.map(\.interpretationIndex)) == Set(1...3),
                  Set(candidates.map { $0.intent.sourceSnapshotID }).count == 1 else {
                throw VocalContractError.validationFailed(
                    "Saved Vocal state must expose exactly three source-consistent hypothesis leaves."
                )
            }
            for candidate in candidates {
                try VocalContractValidator().validate(candidate: candidate)
            }
            creativeCandidates = candidates.sorted { $0.interpretationIndex < $1.interpretationIndex }
            let selected = creativeCandidates.first(where: { $0.id == selectedCandidateID })
            // Preserve an explicitly saved selection, but never silently grant
            // hypothesis 1 revision or handoff authority after restore.
            creativeIntent = selected?.intent ?? creativeCandidates.first?.intent
            blockingClarification = nil
            if let intent = creativeIntent {
                creativeScope = intent.scope
                synchronizeScopeDraft(from: intent.scope)
                assetAcceptance = intent.assetAcceptance
            }
            self.selectedCreativeCandidateID = selected?.id
            self.latestCreativeRevision = latestRevision?.candidate.id == selected?.id
                ? latestRevision
                : nil
            clearRevisionReferenceAuthority()
            conflictMessage = nil
            validationMessage = nil
            requestNotice = "Saved Vocal hypotheses restored. Artifact references are historical until the exact current capture is reconciled."
        } catch {
            creativeIntent = nil
            blockingClarification = nil
            creativeCandidates = []
            selectedCreativeCandidateID = nil
            latestCreativeRevision = nil
            validationMessage = "Saved creative state rejected: \(error)"
        }
    }

    func restoreHistoricalCandidate(_ candidate: VocalCreativeCandidate) {
        if let clarification = candidate.intent.blockingClarification {
            loadBlockingClarification(candidate.intent, clarification: clarification)
            return
        }
        do {
            try VocalContractValidator().validate(candidate: candidate)
            guard let index = creativeCandidates.firstIndex(where: {
                $0.interpretationIndex == candidate.interpretationIndex
            }) else {
                throw VocalContractError.missingReference(candidate.id)
            }
            creativeCandidates[index] = candidate
            creativeCandidates.sort { $0.interpretationIndex < $1.interpretationIndex }
            creativeIntent = candidate.intent
            blockingClarification = nil
            creativeScope = candidate.intent.scope
            synchronizeScopeDraft(from: candidate.intent.scope)
            assetAcceptance = candidate.intent.assetAcceptance
            selectedCreativeCandidateID = candidate.id
            latestCreativeRevision = nil
            validationMessage = nil
            requestNotice = "Exact saved candidate restored as the visible hypothesis. It is not the working or committed plan until you explicitly choose Use as working."
        } catch {
            validationMessage = "Historical candidate restore refused: \(error)"
        }
    }

    func restorePersistedCaptureState(
        brief: VocalCaptureBrief?,
        baseInterpretations: [VocalCaptureInterpretation],
        selectedInterpretationID: UUID?,
        latestRevision: VocalCaptureRevisionResult?,
        assessment: VocalTestTakeAssessment?,
        confirmedFeedback: VocalCaptureListeningFeedback?
    ) {
        captureBrief = brief
        if baseInterpretations.count == 3, Set(baseInterpretations.map(\.id)).count == 3 {
            captureInterpretations = baseInterpretations
        } else {
            captureInterpretations = []
        }
        latestCaptureRevision = latestRevision
        if let selectedInterpretationID,
           captureInterpretations.contains(where: { $0.id == selectedInterpretationID })
            || latestRevision?.revisedInterpretation.id == selectedInterpretationID {
            self.selectedCaptureInterpretationID = selectedInterpretationID
        } else {
            self.selectedCaptureInterpretationID = nil
        }
        sourceAwareAnalysis = nil
        testTakeAssessment = assessment
        testTakeAuthority = nil
        captureFeedback = confirmedFeedback ?? VocalCaptureListeningFeedback()
        handoffState = .notRequested
        validationMessage = nil
    }

    func clearPersistedWorkspace() {
        captureBrief = nil
        captureInterpretations = []
        selectedCaptureInterpretationID = nil
        sourceAwareAnalysis = nil
        testTakeAssessment = nil
        testTakeAuthority = nil
        captureFeedback = VocalCaptureListeningFeedback()
        latestCaptureRevision = nil
        handoffState = .notRequested
        creativeIntent = nil
        blockingClarification = nil
        creativeCandidates = []
        latestCreativeRevision = nil
        selectedCreativeCandidateID = nil
        creativeRevisionText = ""
        clearRevisionReferenceAuthority()
        validationMessage = nil
        conflictMessage = nil
        requestNotice = "Saved Vocal state deleted. Source audio and Logic state were not changed."
    }

    func forgetCapturePreferenceEvidence() {
        captureFeedback.explicitlyConfirmAsPreference = false
        if var revision = latestCaptureRevision {
            revision.confirmedPreference = nil
            latestCaptureRevision = revision
        }
        requestNotice = "Confirmed capture preference forgotten. Descriptive feedback remains editable and will not be re-saved as a preference unless explicitly confirmed again."
    }

    @discardableResult
    func loadRenderedAsset(
        _ manifest: VocalRenderedAssetManifest,
        expectedSourceAuthority: VocalSourceAuthority
    ) -> Bool {
        if let clarification = manifest.typedIntent.blockingClarification {
            loadBlockingClarification(manifest.typedIntent, clarification: clarification)
            return false
        }
        do {
            guard manifest.localOffline,
                  !manifest.usesNetwork,
                  manifest.sourceAuthority == expectedSourceAuthority,
                  let index = creativeCandidates.firstIndex(where: {
                      $0.id == manifest.exactCandidateID
                  }) else {
                throw VocalContractError.validationFailed(
                    "The rendered asset is not a local artifact for one of the current candidates."
                )
            }
            var candidate = creativeCandidates[index]
            guard candidate.authorityStatus == .locallyValidated,
                  candidate.intent.sourceSnapshotID == manifest.sourceAuthority.sourceSnapshotID,
                  candidate.intent.id == manifest.typedIntent.id,
                  candidate.plan.requestID == manifest.exactPlanRequestID,
                  candidate.plan.nodes.map(\.id) == manifest.exactNodeIDs,
                  candidate.intent.scope == manifest.scope else {
                throw VocalContractError.validationFailed(
                    "The rendered asset does not match the exact candidate, source, scope, intent, and plan identities."
                )
            }
            candidate.assetID = manifest.renderID
            for otherIndex in creativeCandidates.indices where otherIndex != index {
                if creativeCandidates[otherIndex].intent.scope.kind != .fullSource {
                    creativeCandidates[otherIndex].assetID = nil
                }
            }
            creativeCandidates[index] = candidate
            selectedCreativeCandidateID = candidate.id
            validationMessage = nil
            requestNotice = "A source-preserving local derivative asset reference was loaded; no Logic region or AU state was changed."
            return true
        } catch {
            validationMessage = "Rendered Vocal asset rejected: \(error)"
            return false
        }
    }

    func reconcilePreviewReferences(
        baseReferences: [UUID: UUID],
        currentWorkingCandidateID candidateID: UUID,
        currentWorkingPreviewID previewID: UUID,
        exactPlanRequestID: UUID
    ) {
        guard let index = creativeCandidates.firstIndex(where: { $0.id == candidateID }),
              creativeCandidates[index].authorityStatus == .locallyValidated,
              creativeCandidates[index].plan.requestID == exactPlanRequestID else {
            validationMessage = "Preview reference rejected because its candidate or exact plan identity changed."
            return
        }
        for candidateIndex in creativeCandidates.indices {
            creativeCandidates[candidateIndex].previewID =
                baseReferences[creativeCandidates[candidateIndex].id]
        }
        creativeCandidates[index].previewID = previewID
        selectedCreativeCandidateID = candidateID
        validationMessage = nil
        requestNotice = "A local preview reference was loaded; selection and preference remain listening decisions."
    }

    func selectCreativeCandidate(_ candidate: VocalCreativeCandidate) {
        if let clarification = candidate.intent.blockingClarification {
            loadBlockingClarification(candidate.intent, clarification: clarification)
            return
        }
        guard creativeCandidates.contains(where: { $0.id == candidate.id }) else {
            validationMessage = "The creative candidate is not part of the current three-hypothesis set."
            return
        }
        selectedCreativeCandidateID = candidate.id
        requestNotice = "Creative hypothesis selected. Selection is not a render or listening preference."
    }

    func useCurrentScopeAsLastPhraseAuthority() {
        guard creativeScope.kind != .fullSource else {
            validationMessage = "Last-phrase revision authority requires an explicit bounded seconds or named-section scope."
            return
        }
        revisionLastPhraseScope = creativeScope
        validationMessage = nil
        requestNotice = "Current \(VocalWorkspacePresentation.scopeLabel(creativeScope)) scope explicitly bound as the last-phrase revision target."
    }

    func clearLastPhraseAuthority() {
        revisionLastPhraseScope = nil
        requestNotice = "Last-phrase revision authority cleared. Last-phrase prose will now fail closed."
    }

    func setExplicitRevertCandidate(_ candidate: VocalCreativeCandidate) {
        guard candidate.authorityStatus == .locallyValidated,
              let selectedCreativeCandidate,
              candidate.intent.sourceSnapshotID == selectedCreativeCandidate.intent.sourceSnapshotID else {
            validationMessage = "Exact-revert authority requires a current, locally validated candidate from the selected source."
            return
        }
        explicitRevertCandidateID = candidate.id
        validationMessage = nil
        requestNotice = "Candidate \(VocalWorkspacePresentation.shortID(candidate.id)) explicitly bound as the natural-language exact-revert target."
    }

    func clearExplicitRevertCandidate() {
        explicitRevertCandidateID = nil
        requestNotice = "Natural-language exact-revert authority cleared. Numbered candidate references remain explicit."
    }

    func clearRevisionReferenceAuthority() {
        revisionLastPhraseScope = nil
        explicitRevertCandidateID = nil
    }

    func setConflict(_ message: String?) {
        conflictMessage = message
    }

    func noteRequest(_ message: String) {
        requestNotice = message
    }

    func dismissMessages() {
        validationMessage = blockingClarification?.prompt
        requestNotice = nil
    }

    private func acceptCaptureInterpretations(_ interpretations: [VocalCaptureInterpretation]) {
        guard interpretations.count == 3, Set(interpretations.map(\.id)).count == 3 else {
            captureInterpretations = []
            selectedCaptureInterpretationID = nil
            validationMessage = "Vocal Guide requires exactly three unique capture interpretations."
            return
        }
        captureInterpretations = interpretations
        selectedCaptureInterpretationID = nil
        clearCurrentTestTakeAuthority()
        clearCreativeAuthorityForCaptureChange()
        validationMessage = nil
        requestNotice = "Three capture hypotheses loaded. Select one explicitly before starting a bound test take; none has been listened to or preferred here."
    }

    private func rebuildTimedScope(named: Bool) {
        guard let start = Double(scopeStartText),
              let end = Double(scopeEndText),
              start.isFinite,
              end.isFinite,
              start >= 0,
              end > start else {
            scopeDraftError = "Scope requires finite seconds with end greater than start."
            return
        }
        if named {
            let sectionID = scopeSectionID.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = scopeSectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sectionID.isEmpty, !name.isEmpty else {
                scopeDraftError = "A named section requires both an ID and a name."
                return
            }
            creativeScope = .namedSection(
                id: scopeID,
                sectionID: sectionID,
                name: name,
                seconds: .init(start: start, end: end)
            )
        } else {
            creativeScope = .seconds(id: scopeID, start: start, end: end)
        }
        scopeDraftError = nil
    }

    private func synchronizeScopeDraft(from scope: VocalCreativeScope) {
        scopeStartText = scope.seconds.map { String($0.start) } ?? "0"
        scopeEndText = scope.seconds.map { String($0.end) } ?? "10"
        scopeSectionID = scope.sectionID ?? "section-1"
        scopeSectionName = scope.sectionName ?? "Selected section"
        scopeDraftError = nil
    }

    private func clearCurrentTestTakeAuthority() {
        sourceAwareAnalysis = nil
        testTakeAssessment = nil
        testTakeAuthority = nil
    }

    private func clearCreativeAuthorityForCaptureChange() {
        creativeIntent = nil
        blockingClarification = nil
        creativeCandidates = []
        latestCreativeRevision = nil
        selectedCreativeCandidateID = nil
        creativeRevisionText = ""
        clearRevisionReferenceAuthority()
        handoffState = .notRequested
    }
}
