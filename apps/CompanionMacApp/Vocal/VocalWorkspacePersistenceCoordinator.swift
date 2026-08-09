import Combine
import CryptoKit
import Foundation
import PlanSchema
import SharedIPC
import SwiftUI
import VocalProduction

struct VocalSessionHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let updatedAt: Date?
    let authorityStatus: VocalSessionAuthorityStatus?
    let desiredResult: String?
    let sourceSnapshotID: UUID?
    let capturePlanCount: Int
    let assessmentCount: Int
    let candidateCount: Int
    let revisionCount: Int

    var isAvailable: Bool { updatedAt != nil && authorityStatus != nil }
}

/// A compact, non-executable view of the completed test-take transaction that
/// the workspace can compare with its current brief, plan, capture, and
/// assessment before preparing a Guide -> Create handoff.
struct VocalTestTakeAuthoritySummary: Equatable, Sendable {
    let bindingID: UUID
    let captureBriefID: UUID
    let capturePlanID: UUID
    let captureRevisionID: UUID?
    let capturePlanTitle: String
    let testTakeLabel: String
    let selectedInstanceID: UUID
    let selectedRuntimeEpoch: UUID
    let sourceType: SourceType
    let resultCaptureID: UUID
    let resultAssessmentID: UUID
    let completedBindingHashSHA256: String
    let sourceIsCurrent: Bool
}

/// Two-phase transaction authority for one explicitly labeled Vocal test take.
/// The start digest binds the exact typed brief and capture plan to one AU
/// runtime. The completion digest additionally binds the resulting immutable
/// capture and assessment. Durable source authority stores identities and
/// digests, while the already-persisted typed brief/plan remains inspectable.
struct VocalTestTakeBinding: Equatable, Sendable {
    let id: UUID
    let captureBriefID: UUID
    let captureBriefHashSHA256: String
    let capturePlanID: UUID
    let captureRevisionID: UUID?
    let capturePlanTitle: String
    let capturePlanHashSHA256: String
    let testTakeLabel: String
    let testTakeLabelHashSHA256: String
    let selectedInstanceID: UUID
    let selectedRuntimeEpoch: UUID
    let sourceType: SourceType
    let startedAt: Date
    let startedBindingHashSHA256: String
    let resultCaptureID: UUID?
    let resultAssessmentID: UUID?
    let resultAssessmentHashSHA256: String?
    let resultSourceHashSHA256: String?
    let completedAt: Date?
    let completedBindingHashSHA256: String?

    static func make(
        captureBrief: VocalCaptureBrief,
        interpretation: VocalCaptureInterpretation,
        selectedInstanceID: UUID,
        selectedRuntimeEpoch: UUID,
        sourceType: SourceType,
        createdAt: Date = Date(),
        id: UUID = UUID()
    ) throws -> VocalTestTakeBinding {
        let briefHash = try digest(captureBrief)
        let planHash = try digest(interpretation)
        let label = interpretation.comparison.testTakeLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = interpretation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let labelHash = digest(Data(label.utf8))
        let canonical = [
            "tracksmith-vocal-test-take-start-v1",
            id.uuidString.lowercased(),
            captureBrief.id.uuidString.lowercased(),
            briefHash,
            interpretation.id.uuidString.lowercased(),
            interpretation.revisionID?.uuidString.lowercased() ?? "none",
            title,
            planHash,
            label,
            labelHash,
            selectedInstanceID.uuidString.lowercased(),
            selectedRuntimeEpoch.uuidString.lowercased(),
            sourceType.rawValue,
            timestamp(createdAt),
        ].joined(separator: "\n")
        return VocalTestTakeBinding(
            id: id,
            captureBriefID: captureBrief.id,
            captureBriefHashSHA256: briefHash,
            capturePlanID: interpretation.id,
            captureRevisionID: interpretation.revisionID,
            capturePlanTitle: title,
            capturePlanHashSHA256: planHash,
            testTakeLabel: label,
            testTakeLabelHashSHA256: labelHash,
            selectedInstanceID: selectedInstanceID,
            selectedRuntimeEpoch: selectedRuntimeEpoch,
            sourceType: sourceType,
            startedAt: createdAt,
            startedBindingHashSHA256: digest(Data(canonical.utf8)),
            resultCaptureID: nil,
            resultAssessmentID: nil,
            resultAssessmentHashSHA256: nil,
            resultSourceHashSHA256: nil,
            completedAt: nil,
            completedBindingHashSHA256: nil
        )
    }

    func accepts(
        artifact: CaptureArtifact,
        brief: VocalCaptureBrief?,
        interpretation: VocalCaptureInterpretation?,
        currentSourceType: SourceType
    ) -> Bool {
        guard let brief, let interpretation,
              brief.id == captureBriefID,
              interpretation.id == capturePlanID,
              interpretation.revisionID == captureRevisionID,
              interpretation.title.trimmingCharacters(in: .whitespacesAndNewlines) == capturePlanTitle,
              interpretation.comparison.testTakeLabel
                .trimmingCharacters(in: .whitespacesAndNewlines) == testTakeLabel,
              (try? Self.digest(brief)) == captureBriefHashSHA256,
              (try? Self.digest(interpretation)) == capturePlanHashSHA256,
              artifact.originatingInstanceID == selectedInstanceID,
              artifact.originatingRuntimeEpoch == selectedRuntimeEpoch,
              currentSourceType == sourceType else { return false }
        return resultCaptureID == nil || resultCaptureID == artifact.id
    }

    func accepting(
        artifact: CaptureArtifact,
        brief: VocalCaptureBrief?,
        interpretation: VocalCaptureInterpretation?,
        currentSourceType: SourceType
    ) -> VocalTestTakeBinding? {
        guard accepts(
            artifact: artifact,
            brief: brief,
            interpretation: interpretation,
            currentSourceType: currentSourceType
        ) else { return nil }
        var copy = self
        copy = copy.withResultCaptureID(artifact.id)
        return copy
    }

    func completing(
        artifact: CaptureArtifact,
        assessment: VocalTestTakeAssessment,
        sourceAuthority: VocalSourceAuthority,
        brief: VocalCaptureBrief?,
        interpretation: VocalCaptureInterpretation?,
        currentSourceType: SourceType,
        completedAt: Date = Date()
    ) throws -> VocalTestTakeBinding {
        guard accepts(
            artifact: artifact,
            brief: brief,
            interpretation: interpretation,
            currentSourceType: currentSourceType
        ), sourceAuthority.sourceSnapshotID == artifact.id else {
            throw VocalContractError.validationFailed(
                "The completed test take no longer matches its exact brief, capture plan, AU runtime, source, or result capture."
            )
        }
        let assessmentHash = try Self.digest(assessment)
        if resultCaptureID == artifact.id,
           resultAssessmentID == assessment.id,
           resultAssessmentHashSHA256 == assessmentHash,
           resultSourceHashSHA256 == sourceAuthority.contentHashSHA256,
           completedBindingHashSHA256 != nil {
            return self
        }
        guard completedBindingHashSHA256 == nil else {
            throw VocalContractError.validationFailed(
                "A completed Vocal test-take transaction is immutable; capture, assessment, or source authority changed."
            )
        }
        let canonical = [
            "tracksmith-vocal-test-take-completion-v1",
            startedBindingHashSHA256,
            artifact.id.uuidString.lowercased(),
            assessment.id.uuidString.lowercased(),
            assessmentHash,
            sourceAuthority.contentHashSHA256,
            Self.decimal(sourceAuthority.sampleRate),
            String(sourceAuthority.channelCount),
            String(sourceAuthority.frameCount),
            Self.timestamp(completedAt),
        ].joined(separator: "\n")
        return VocalTestTakeBinding(
            id: id,
            captureBriefID: captureBriefID,
            captureBriefHashSHA256: captureBriefHashSHA256,
            capturePlanID: capturePlanID,
            captureRevisionID: captureRevisionID,
            capturePlanTitle: capturePlanTitle,
            capturePlanHashSHA256: capturePlanHashSHA256,
            testTakeLabel: testTakeLabel,
            testTakeLabelHashSHA256: testTakeLabelHashSHA256,
            selectedInstanceID: selectedInstanceID,
            selectedRuntimeEpoch: selectedRuntimeEpoch,
            sourceType: sourceType,
            startedAt: startedAt,
            startedBindingHashSHA256: startedBindingHashSHA256,
            resultCaptureID: artifact.id,
            resultAssessmentID: assessment.id,
            resultAssessmentHashSHA256: assessmentHash,
            resultSourceHashSHA256: sourceAuthority.contentHashSHA256,
            completedAt: completedAt,
            completedBindingHashSHA256: Self.digest(Data(canonical.utf8))
        )
    }

    var authoritySummary: VocalTestTakeAuthoritySummary? {
        guard let resultCaptureID,
              let resultAssessmentID,
              let completedBindingHashSHA256 else { return nil }
        return VocalTestTakeAuthoritySummary(
            bindingID: id,
            captureBriefID: captureBriefID,
            capturePlanID: capturePlanID,
            captureRevisionID: captureRevisionID,
            capturePlanTitle: capturePlanTitle,
            testTakeLabel: testTakeLabel,
            selectedInstanceID: selectedInstanceID,
            selectedRuntimeEpoch: selectedRuntimeEpoch,
            sourceType: sourceType,
            resultCaptureID: resultCaptureID,
            resultAssessmentID: resultAssessmentID,
            completedBindingHashSHA256: completedBindingHashSHA256,
            sourceIsCurrent: true
        )
    }

    func durableImmutableSourceID() -> String? {
        guard let resultCaptureID,
              let resultAssessmentID,
              let resultAssessmentHashSHA256,
              let resultSourceHashSHA256,
              let completedAt,
              let completedBindingHashSHA256 else { return nil }
        return [
            "tracksmith-au-capture:\(resultCaptureID.uuidString.lowercased())",
            "test-take-binding-version:v1",
            "test-take-binding-id:\(id.uuidString.lowercased())",
            "test-take-start-sha256:\(startedBindingHashSHA256)",
            "test-take-completion-sha256:\(completedBindingHashSHA256)",
            "test-take-started-at:\(Self.timestamp(startedAt))",
            "test-take-completed-at:\(Self.timestamp(completedAt))",
            "capture-brief-id:\(captureBriefID.uuidString.lowercased())",
            "capture-brief-sha256:\(captureBriefHashSHA256)",
            "capture-plan-id:\(capturePlanID.uuidString.lowercased())",
            "capture-revision-id:\(captureRevisionID?.uuidString.lowercased() ?? "none")",
            "capture-plan-sha256:\(capturePlanHashSHA256)",
            "test-take-label-sha256:\(testTakeLabelHashSHA256)",
            "instance-id:\(selectedInstanceID.uuidString.lowercased())",
            "runtime-epoch:\(selectedRuntimeEpoch.uuidString.lowercased())",
            "source-type:\(sourceType.rawValue)",
            "source-sha256:\(resultSourceHashSHA256)",
            "assessment-id:\(resultAssessmentID.uuidString.lowercased())",
            "assessment-sha256:\(resultAssessmentHashSHA256)",
        ].joined(separator: ";")
    }

    func completedAuthorityMatches(
        artifact: CaptureArtifact,
        assessment: VocalTestTakeAssessment,
        sourceAuthority: VocalSourceAuthority,
        brief: VocalCaptureBrief?,
        interpretation: VocalCaptureInterpretation?,
        currentSourceType: SourceType
    ) -> Bool {
        guard accepts(
            artifact: artifact,
            brief: brief,
            interpretation: interpretation,
            currentSourceType: currentSourceType
        ), resultCaptureID == artifact.id,
           resultAssessmentID == assessment.id,
           resultAssessmentHashSHA256 == (try? Self.digest(assessment)),
           resultSourceHashSHA256 == sourceAuthority.contentHashSHA256,
           sourceAuthority.sourceSnapshotID == artifact.id,
           let durableID = durableImmutableSourceID(),
           sourceAuthority.immutableSourceID == durableID,
           authoritySummary != nil else { return false }
        return true
    }

    /// Reconstructs only the compact authority summary needed by the UI. Every
    /// identity and digest is re-derived from the already checksummed typed
    /// session state. A missing, legacy, duplicated, or contradictory token
    /// fails closed instead of upgrading historical state to live authority.
    static func restoreAuthoritySummary(
        sourceAuthority: VocalSourceAuthority,
        brief: VocalCaptureBrief?,
        interpretation: VocalCaptureInterpretation?,
        assessment: VocalTestTakeAssessment?,
        sourceIsCurrent: Bool
    ) -> VocalTestTakeAuthoritySummary? {
        guard let brief, let interpretation, let assessment,
              let fields = parseDurableIdentifier(sourceAuthority.immutableSourceID),
              fields.hasExactlyRequiredKeys,
              fields["test-take-binding-version"] == "v1",
              let bindingID = fields.uuid("test-take-binding-id"),
              let captureID = fields.uuid("tracksmith-au-capture"),
              let briefID = fields.uuid("capture-brief-id"),
              let planID = fields.uuid("capture-plan-id"),
              let instanceID = fields.uuid("instance-id"),
              let runtimeEpoch = fields.uuid("runtime-epoch"),
              let assessmentID = fields.uuid("assessment-id"),
              let sourceTypeRaw = fields["source-type"],
              let sourceType = SourceType(rawValue: sourceTypeRaw),
              sourceType == .vocal || sourceType == .vocalBus,
              let startHash = fields.sha256("test-take-start-sha256"),
              let completionHash = fields.sha256("test-take-completion-sha256"),
              let briefHash = fields.sha256("capture-brief-sha256"),
              let planHash = fields.sha256("capture-plan-sha256"),
              let labelHash = fields.sha256("test-take-label-sha256"),
              let storedAssessmentHash = fields.sha256("assessment-sha256"),
              let storedSourceHash = fields.sha256("source-sha256"),
              let startedAt = fields.date("test-take-started-at"),
              let completedAt = fields.date("test-take-completed-at"),
              completedAt >= startedAt,
              captureID == sourceAuthority.sourceSnapshotID,
              briefID == brief.id,
              planID == interpretation.id,
              assessmentID == assessment.id,
              briefHash == (try? digest(brief)),
              planHash == (try? digest(interpretation)),
              storedAssessmentHash == (try? digest(assessment)),
              storedSourceHash == sourceAuthority.contentHashSHA256,
              labelHash == digest(Data(interpretation.comparison.testTakeLabel
                .trimmingCharacters(in: .whitespacesAndNewlines).utf8)),
              fields["capture-revision-id"]
                == (interpretation.revisionID?.uuidString.lowercased() ?? "none") else {
            return nil
        }

        let title = interpretation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = interpretation.comparison.testTakeLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let startCanonical = [
            "tracksmith-vocal-test-take-start-v1",
            bindingID.uuidString.lowercased(),
            brief.id.uuidString.lowercased(),
            briefHash,
            interpretation.id.uuidString.lowercased(),
            interpretation.revisionID?.uuidString.lowercased() ?? "none",
            title,
            planHash,
            label,
            labelHash,
            instanceID.uuidString.lowercased(),
            runtimeEpoch.uuidString.lowercased(),
            sourceType.rawValue,
            timestamp(startedAt),
        ].joined(separator: "\n")
        guard digest(Data(startCanonical.utf8)) == startHash else { return nil }

        let completionCanonical = [
            "tracksmith-vocal-test-take-completion-v1",
            startHash,
            sourceAuthority.sourceSnapshotID.uuidString.lowercased(),
            assessment.id.uuidString.lowercased(),
            storedAssessmentHash,
            storedSourceHash,
            decimal(sourceAuthority.sampleRate),
            String(sourceAuthority.channelCount),
            String(sourceAuthority.frameCount),
            timestamp(completedAt),
        ].joined(separator: "\n")
        guard digest(Data(completionCanonical.utf8)) == completionHash else { return nil }

        return VocalTestTakeAuthoritySummary(
            bindingID: bindingID,
            captureBriefID: brief.id,
            capturePlanID: interpretation.id,
            captureRevisionID: interpretation.revisionID,
            capturePlanTitle: title,
            testTakeLabel: label,
            selectedInstanceID: instanceID,
            selectedRuntimeEpoch: runtimeEpoch,
            sourceType: sourceType,
            resultCaptureID: sourceAuthority.sourceSnapshotID,
            resultAssessmentID: assessment.id,
            completedBindingHashSHA256: completionHash,
            sourceIsCurrent: sourceIsCurrent
        )
    }

    private func withResultCaptureID(_ resultCaptureID: UUID) -> VocalTestTakeBinding {
        VocalTestTakeBinding(
            id: id,
            captureBriefID: captureBriefID,
            captureBriefHashSHA256: captureBriefHashSHA256,
            capturePlanID: capturePlanID,
            captureRevisionID: captureRevisionID,
            capturePlanTitle: capturePlanTitle,
            capturePlanHashSHA256: capturePlanHashSHA256,
            testTakeLabel: testTakeLabel,
            testTakeLabelHashSHA256: testTakeLabelHashSHA256,
            selectedInstanceID: selectedInstanceID,
            selectedRuntimeEpoch: selectedRuntimeEpoch,
            sourceType: sourceType,
            startedAt: startedAt,
            startedBindingHashSHA256: startedBindingHashSHA256,
            resultCaptureID: resultCaptureID,
            resultAssessmentID: resultAssessmentID,
            resultAssessmentHashSHA256: resultAssessmentHashSHA256,
            resultSourceHashSHA256: resultSourceHashSHA256,
            completedAt: completedAt,
            completedBindingHashSHA256: completedBindingHashSHA256
        )
    }

    private static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return digest(try encoder.encode(value))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func timestamp(_ date: Date) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), date.timeIntervalSince1970)
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.9f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func parseDurableIdentifier(_ identifier: String) -> DurableFields? {
        var values: [String: String] = [:]
        for component in identifier.split(separator: ";", omittingEmptySubsequences: false) {
            guard let separator = component.firstIndex(of: ":") else { return nil }
            let key = String(component[..<separator])
            let value = String(component[component.index(after: separator)...])
            guard !key.isEmpty, !value.isEmpty, values[key] == nil else { return nil }
            values[key] = value
        }
        return DurableFields(values: values)
    }

    private struct DurableFields {
        let values: [String: String]

        private static let requiredKeys: Set<String> = [
            "tracksmith-au-capture",
            "test-take-binding-version",
            "test-take-binding-id",
            "test-take-start-sha256",
            "test-take-completion-sha256",
            "test-take-started-at",
            "test-take-completed-at",
            "capture-brief-id",
            "capture-brief-sha256",
            "capture-plan-id",
            "capture-revision-id",
            "capture-plan-sha256",
            "test-take-label-sha256",
            "instance-id",
            "runtime-epoch",
            "source-type",
            "source-sha256",
            "assessment-id",
            "assessment-sha256",
        ]

        var hasExactlyRequiredKeys: Bool {
            Set(values.keys) == Self.requiredKeys
        }

        subscript(_ key: String) -> String? { values[key] }

        func uuid(_ key: String) -> UUID? {
            values[key].flatMap(UUID.init(uuidString:))
        }

        func sha256(_ key: String) -> String? {
            guard let value = values[key],
                  value.count == 64,
                  value.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
            return value
        }

        func date(_ key: String) -> Date? {
            guard let value = values[key],
                  let seconds = Double(value),
                  seconds.isFinite else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
    }
}

/// App boundary around the core atomic/checksummed/quarantining store. It keeps
/// canonical state separate from a demoted presentation copy, so an unavailable
/// source can never overwrite otherwise recoverable authority.
@MainActor
final class VocalWorkspacePersistenceCoordinator: ObservableObject {
    @Published private(set) var statusMessage: String
    @Published private(set) var presentationState: VocalSessionState?
    @Published private(set) var historyEntries: [VocalSessionHistoryEntry]
    @Published var inspectorExpanded = false
    @Published var creativePreferenceNote = ""
    @Published private(set) var selectedPreferenceAspects = Set<VocalAspect>()

    private static let activeSessionKey = "TrackSmith.Vocal.ActiveSessionID.v1"
    private static let knownSessionsKey = "TrackSmith.Vocal.KnownSessionIDs.v1"

    private let store: VocalSessionStore?
    private let defaults: UserDefaults
    private let now: () -> Date
    private let makeID: () -> UUID
    private var canonicalState: VocalSessionState?
    private var inspectionOnlySessionID: UUID?

    init(
        store: VocalSessionStore?,
        defaults: UserDefaults,
        initialStatus: String = "Saved Vocal state has not been inspected yet.",
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.store = store
        self.defaults = defaults
        self.statusMessage = initialStatus
        self.historyEntries = []
        self.now = now
        self.makeID = makeID
        refreshHistory()
    }

    static func live() -> VocalWorkspacePersistenceCoordinator {
        let defaults = UserDefaults(suiteName: AppGroupContainer.identifier) ?? .standard
        do {
            let base = try AppGroupContainer.exchangeRoot().deletingLastPathComponent()
            let store = try VocalSessionStore(
                baseDirectoryURL: base,
                subdirectoryName: "VocalSessions-v1"
            )
            return VocalWorkspacePersistenceCoordinator(store: store, defaults: defaults)
        } catch {
            return VocalWorkspacePersistenceCoordinator(
                store: nil,
                defaults: defaults,
                initialStatus: "Saved Vocal state unavailable: \(error)"
            )
        }
    }

    var activeSessionID: UUID? { canonicalState?.id }

    var allCandidates: [VocalCreativeCandidate] {
        (presentationState ?? canonicalState)?.candidates ?? []
    }

    var knownSessionCount: Int { knownSessionIDs.count }

    var authorityLabel: String {
        switch presentationState?.authorityStatus {
        case .current: "CURRENT SOURCE"
        case .staleSourceDemoted: "STALE · READ ONLY"
        case .sourceUnavailableReadOnly: "SOURCE UNAVAILABLE · READ ONLY"
        case nil: "NO SAVED SESSION"
        }
    }

    func restore(into model: VocalWorkspaceModel) {
        guard let store else { return }
        refreshHistory()
        guard let sessionID = defaults.string(forKey: Self.activeSessionKey).flatMap(UUID.init(uuidString:)) else {
            statusMessage = historyEntries.isEmpty
                ? "No saved Vocal session. Typed state will be created on the first explicit save."
                : "No active Vocal session. Choose Inspect read-only from saved session history."
            return
        }
        do {
            let loaded = try store.load(sessionID: sessionID)
            canonicalState = loaded.state
            inspectionOnlySessionID = sessionID
            let presentation = sourceUnavailablePresentation(loaded.state)
            presentationState = presentation
            apply(presentation, to: model)
            remember(sessionID)
            statusMessage = "Saved typed Vocal state restored read-only until the exact capture authority is available."
        } catch {
            // A rejected, incompatible, quarantined, or temporarily unreadable
            // session remains a useful inspectable history record. Only an
            // explicit store-level absence proves this ID can be forgotten.
            if isConfirmedMissingSession(error, id: sessionID) {
                forgetKnownID(sessionID)
            }
            refreshHistory()
            statusMessage = "Saved Vocal session could not be restored: \(error)"
        }
    }

    func inspectKnownSession(_ sessionID: UUID, into model: VocalWorkspaceModel) {
        guard let store else { return }
        do {
            let loaded = try store.load(sessionID: sessionID)
            canonicalState = loaded.state
            inspectionOnlySessionID = sessionID
            let presentation = sourceUnavailablePresentation(loaded.state)
            presentationState = presentation
            apply(presentation, to: model)
            defaults.set(sessionID.uuidString.lowercased(), forKey: Self.activeSessionKey)
            remember(sessionID)
            refreshHistory()
            statusMessage = "Saved Vocal session loaded for read-only inspection. Exact live source and immutable test-take authority must reconcile before working, revision, render, handoff, or commit authority returns."
        } catch {
            refreshHistory()
            statusMessage = "Saved Vocal session could not be inspected; its typed metadata remains unavailable and no authority was granted: \(error)"
        }
    }

    func reconcile(
        currentSourceAuthority: VocalSourceAuthority,
        into model: VocalWorkspaceModel
    ) {
        guard let store, let sessionID = canonicalState?.id else { return }
        do {
            let loaded = try store.load(
                sessionID: sessionID,
                currentSourceAuthority: currentSourceAuthority
            )
            let immutableIdentityMismatch = loaded.state.sourceAuthority.map {
                !sameAuthority($0, currentSourceAuthority)
            } ?? true
            let presentation = immutableIdentityMismatch
                ? staleSourcePresentation(loaded.state)
                : loaded.state
            presentationState = presentation
            if presentation.authorityStatus == .current {
                inspectionOnlySessionID = nil
            }
            apply(presentation, to: model)
            statusMessage = loaded.staleAuthorityDemoted || immutableIdentityMismatch
                ? "Saved Vocal state targets another capture or test-take transaction and is demoted read-only. Start new work to rotate to the current source."
                : "Saved Vocal state reconciled to the exact current source hash, capture identity, and completed test-take transaction."
        } catch {
            statusMessage = "Saved Vocal authority reconciliation failed: \(error)"
        }
    }

    func sourceBecameUnavailable(into model: VocalWorkspaceModel) {
        guard let canonicalState else { return }
        let presentation = sourceUnavailablePresentation(canonicalState)
        presentationState = presentation
        apply(presentation, to: model)
        statusMessage = "Current source is unavailable; saved candidates and handoffs are inspectable but non-executable."
    }

    func save(
        workspace model: VocalWorkspaceModel,
        currentSourceAuthority: VocalSourceAuthority?,
        revisionRecords: [VocalRevisionRecord],
        renderedAssetManifest: VocalRenderedAssetManifest?
    ) {
        guard let store else { return }
        let hasTypedContent = model.captureBrief != nil
            || !model.captureInterpretations.isEmpty
            || model.testTakeAssessment != nil
            || model.creativeIntent != nil
            || !model.creativeCandidates.isEmpty
        guard hasTypedContent || canonicalState != nil else { return }

        do {
            var state = try stateForSave(currentSourceAuthority: currentSourceAuthority)
            state.captureBrief = model.captureBrief ?? state.captureBrief
            state.captureInterpretations = mergeByID(
                state.captureInterpretations,
                model.captureInterpretations
                    + [model.latestCaptureRevision?.revisedInterpretation].compactMap { $0 }
            )
            if let assessment = model.testTakeAssessment {
                state.testTakeAssessments = mergeAssessments(state.testTakeAssessments, [assessment])
            }
            if let revision = model.latestCaptureRevision {
                state.captureRevisions = mergeCaptureRevisions(state.captureRevisions, [revision])
                if let preference = revision.confirmedPreference {
                    state.confirmedCapturePreferences = mergeCapturePreferences(
                        state.confirmedCapturePreferences,
                        [preference]
                    )
                }
            }
            state.selectedCaptureInterpretationID = model.selectedCaptureInterpretationID

            let mayMergeCreative = currentSourceAuthority != nil
                || state.sourceAuthority == nil
            if mayMergeCreative {
                let visibleCandidates = model.creativeCandidates.filter { candidate in
                    guard let currentSourceAuthority else {
                        return state.sourceAuthority == nil
                            && candidate.authorityStatus == .locallyValidated
                    }
                    return candidate.authorityStatus == .locallyValidated
                        && candidate.intent.sourceSnapshotID == currentSourceAuthority.sourceSnapshotID
                        && candidate.plan.sourceSnapshotID == currentSourceAuthority.sourceSnapshotID
                }
                state.candidates = mergeCandidatesPreservingArtifactAncestry(
                    state.candidates,
                    visibleCandidates
                )
                state.creativeIntents = mergeCreativeIntents(
                    state.creativeIntents,
                    visibleCandidates.map(\.intent)
                        + [model.creativeIntent].compactMap { $0 }
                            .filter { intent in
                                guard let currentSourceAuthority else { return false }
                                return intent.sourceSnapshotID == currentSourceAuthority.sourceSnapshotID
                            }
                )
                let candidateIDs = Set(state.candidates.map(\.id))
                state.revisions = mergeByID(
                    state.revisions,
                    (revisionRecords + [model.latestCreativeRevision?.record].compactMap { $0 })
                        .filter {
                            candidateIDs.contains($0.baseCandidateID)
                                && candidateIDs.contains($0.resultCandidateID)
                                && $0.exactAncestorCandidateIDs.allSatisfy(candidateIDs.contains)
                        }
                )
                if let selected = model.selectedCreativeCandidateID,
                   candidateIDs.contains(selected) {
                    state.selectedCandidateID = selected
                }
                state.previews = mergeByID(
                    state.previews,
                    previewRecords(from: visibleCandidates)
                )
                if let renderedAssetManifest,
                   candidateIDs.contains(renderedAssetManifest.exactCandidateID),
                   let currentSourceAuthority,
                   sameAuthority(
                    renderedAssetManifest.sourceAuthority,
                    currentSourceAuthority
                   ) {
                    state.assets = mergeByID(
                        state.assets,
                        [assetRecord(renderedAssetManifest)]
                    )
                }
                if case let .executableHandoffPrepared(_, handoff) = model.handoffState,
                   candidateIDs.contains(handoff.proposal.candidateID),
                   let currentSourceAuthority,
                   handoff.proposal.sourceSnapshotID == currentSourceAuthority.sourceSnapshotID,
                   sameAuthority(
                    handoff.captureAuthority.sourceAuthority,
                    currentSourceAuthority
                   ) {
                    state.handoffs = mergeByID(
                        state.handoffs,
                        [VocalStoredHandoffRecord(
                            id: handoff.id,
                            handoff: handoff,
                            authorityStatus: .current,
                            executable: true
                        )]
                    )
                }
            }
            state.updatedAt = now()
            _ = try store.save(state)
            canonicalState = state
            inspectionOnlySessionID = nil
            presentationState = currentSourceAuthority == nil
                ? sourceUnavailablePresentation(state)
                : state
            defaults.set(state.id.uuidString.lowercased(), forKey: Self.activeSessionKey)
            remember(state.id)
            refreshHistory()
            statusMessage = "Typed Vocal session saved atomically with checksum; no raw audio or provider credential was stored."
        } catch {
            statusMessage = "Typed Vocal session save refused: \(error)"
        }
    }

    func togglePreferenceAspect(_ aspect: VocalAspect) {
        if selectedPreferenceAspects.contains(aspect) {
            selectedPreferenceAspects.remove(aspect)
        } else {
            selectedPreferenceAspects.insert(aspect)
        }
    }

    func confirmCreativePreference(candidateID: UUID?) {
        guard let store,
              var state = canonicalState,
              state.authorityStatus == .current,
              let candidateID,
              state.candidates.contains(where: { $0.id == candidateID }) else {
            statusMessage = "Owner preference confirmation requires a current saved candidate."
            return
        }
        let note = creativePreferenceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let preference = VocalConfirmedCreativePreference(
            id: makeID(),
            candidateID: candidateID,
            preferredAspects: VocalAspect.allCases.filter(selectedPreferenceAspects.contains),
            note: note.isEmpty ? nil : note,
            explicitlyConfirmedByUser: true,
            confirmedAt: now()
        )
        do {
            state.confirmedCreativePreferences = mergeByID(
                state.confirmedCreativePreferences,
                [preference]
            )
            state.updatedAt = now()
            _ = try store.save(state)
            canonicalState = state
            presentationState = state
            selectedPreferenceAspects = []
            creativePreferenceNote = ""
            refreshHistory()
            statusMessage = "Explicit owner preference saved. It remains personal evidence, not a universal claim."
        } catch {
            statusMessage = "Owner preference was not saved: \(error)"
        }
    }

    func forgetCapturePreferences(in model: VocalWorkspaceModel) {
        let forgotten = mutateCanonical(
            "Confirmed capture preferences forgotten; capture plans and audio were not deleted."
        ) {
            $0.confirmedCapturePreferences = []
            $0.captureRevisions = $0.captureRevisions.map { revision in
                var copy = revision
                copy.confirmedPreference = nil
                return copy
            }
        }
        if forgotten { model.forgetCapturePreferenceEvidence() }
    }

    func forgetCreativePreferences() {
        mutateCanonical("Confirmed creative preferences forgotten; candidate ancestry was retained.") {
            $0.confirmedCreativePreferences = []
        }
    }

    func candidateForExactRestore(_ id: UUID) -> VocalCreativeCandidate? {
        guard presentationState?.authorityStatus == .current else {
            statusMessage = "Exact restore is read-only until the saved source authority is current."
            return nil
        }
        guard let candidate = presentationState?.candidates.first(where: { $0.id == id }),
              candidate.authorityStatus == .locallyValidated else {
            statusMessage = "Saved candidate is unavailable or stale."
            return nil
        }
        return candidate
    }

    func selectRestoredCandidate(_ candidate: VocalCreativeCandidate) {
        canonicalState?.selectedCandidateID = candidate.id
        presentationState?.selectedCandidateID = candidate.id
        statusMessage = "Exact candidate ancestry restored visibly. Working and commit authority remain unchanged."
    }

    func deleteCurrent(into model: VocalWorkspaceModel) {
        guard let store, let sessionID = canonicalState?.id else { return }
        do {
            try store.delete(sessionID: sessionID)
            forgetKnownID(sessionID)
            canonicalState = nil
            inspectionOnlySessionID = nil
            presentationState = nil
            selectedPreferenceAspects = []
            creativePreferenceNote = ""
            model.clearPersistedWorkspace()
            refreshHistory()
            statusMessage = "Saved typed Vocal session deleted. Raw captures, Logic projects, and AU state were not touched."
        } catch {
            statusMessage = "Saved Vocal session deletion failed: \(error)"
        }
    }

    func deleteKnownSession(_ sessionID: UUID, into model: VocalWorkspaceModel) {
        guard let store else { return }
        do {
            try store.delete(sessionID: sessionID)
            forgetKnownID(sessionID)
            if canonicalState?.id == sessionID {
                canonicalState = nil
                inspectionOnlySessionID = nil
                presentationState = nil
                selectedPreferenceAspects = []
                creativePreferenceNote = ""
                model.clearPersistedWorkspace()
            }
            refreshHistory()
            statusMessage = "Saved typed Vocal session \(VocalWorkspacePresentation.shortID(sessionID)) deleted. Raw captures, Logic projects, and AU state were not touched."
        } catch {
            refreshHistory()
            statusMessage = "Saved Vocal session deletion failed: \(error)"
        }
    }

    func deleteAllKnown(into model: VocalWorkspaceModel) {
        guard let store else { return }
        let sessionIDs = knownSessionIDs
        var failures: [UUID] = []
        for id in sessionIDs {
            do { try store.delete(sessionID: id) }
            catch { failures.append(id) }
        }
        if failures.isEmpty {
            defaults.removeObject(forKey: Self.knownSessionsKey)
            defaults.removeObject(forKey: Self.activeSessionKey)
            canonicalState = nil
            inspectionOnlySessionID = nil
            presentationState = nil
            selectedPreferenceAspects = []
            creativePreferenceNote = ""
            model.clearPersistedWorkspace()
            refreshHistory()
            statusMessage = "All known typed Vocal sessions deleted; audio cache and Logic state were not changed."
        } else {
            defaults.set(
                failures.map { $0.uuidString.lowercased() },
                forKey: Self.knownSessionsKey
            )
            if let activeID = canonicalState?.id, !failures.contains(activeID) {
                defaults.removeObject(forKey: Self.activeSessionKey)
                canonicalState = nil
                inspectionOnlySessionID = nil
                presentationState = nil
                selectedPreferenceAspects = []
                creativePreferenceNote = ""
                model.clearPersistedWorkspace()
            }
            refreshHistory()
            statusMessage = "Deleted \(sessionIDs.count - failures.count) known typed Vocal session(s); \(failures.count) could not be deleted and remain listed."
        }
    }

    private func stateForSave(
        currentSourceAuthority: VocalSourceAuthority?
    ) throws -> VocalSessionState {
        // An explicitly restored/history-selected session stays immutable while
        // it is presented read-only. Saving edits rotates to a fresh session;
        // only `reconcile` can clear this guard after an exact source match.
        if inspectionOnlySessionID == canonicalState?.id {
            let date = now()
            return VocalSessionState(
                id: makeID(),
                createdAt: date,
                updatedAt: date,
                authorityStatus: currentSourceAuthority == nil ? .sourceUnavailableReadOnly : .current,
                sourceAuthority: currentSourceAuthority
            )
        }
        // Never rewrite a historical source-bound session from a presentation
        // that currently has no source authority. A new pre-capture edit starts
        // a new durable session and leaves the previous source history intact.
        if currentSourceAuthority == nil,
           canonicalState?.sourceAuthority != nil {
            let date = now()
            return VocalSessionState(
                id: makeID(),
                createdAt: date,
                updatedAt: date,
                authorityStatus: .sourceUnavailableReadOnly
            )
        }
        if let currentSourceAuthority,
           let stored = canonicalState?.sourceAuthority,
           !sameAuthority(stored, currentSourceAuthority) {
            let date = now()
            return VocalSessionState(
                id: makeID(),
                createdAt: date,
                updatedAt: date,
                authorityStatus: .current,
                sourceAuthority: currentSourceAuthority
            )
        }
        if var state = canonicalState {
            if let currentSourceAuthority {
                state.sourceAuthority = currentSourceAuthority
                state.authorityStatus = .current
            }
            return state
        }
        let date = now()
        return VocalSessionState(
            id: makeID(),
            createdAt: date,
            updatedAt: date,
            authorityStatus: currentSourceAuthority == nil ? .sourceUnavailableReadOnly : .current,
            sourceAuthority: currentSourceAuthority
        )
    }

    private func apply(_ state: VocalSessionState, to model: VocalWorkspaceModel) {
        // Applying another durable session is replacement, never a merge with
        // the previously viewed session's transient UI authority.
        model.clearPersistedWorkspace()
        let roots = state.captureInterpretations.filter { $0.parentInterpretationID == nil }
        let baseInterpretations = Array((roots.count >= 3 ? roots : state.captureInterpretations).prefix(3))
        let selectedCaptureRevision = state.captureRevisions.last(where: {
            $0.revisedInterpretation.id == state.selectedCaptureInterpretationID
        })
        let selectedInterpretation = selectedCaptureRevision?.revisedInterpretation
            ?? state.captureInterpretations.first(where: {
                $0.id == state.selectedCaptureInterpretationID
            })
        let restoredTransaction: (
            assessment: VocalTestTakeAssessment,
            summary: VocalTestTakeAuthoritySummary
        )? = {
            guard let sourceAuthority = state.sourceAuthority else { return nil }
            for assessment in state.testTakeAssessments {
                if let summary = VocalTestTakeBinding.restoreAuthoritySummary(
                    sourceAuthority: sourceAuthority,
                    brief: state.captureBrief,
                    interpretation: selectedInterpretation,
                    assessment: assessment,
                    sourceIsCurrent: state.authorityStatus == .current
                ) {
                    return (assessment, summary)
                }
            }
            return nil
        }()
        let historicalAssessmentID = selectedCaptureRevision?.assessmentID
            ?? state.testTakeAssessments.last?.id
        let assessment = restoredTransaction?.assessment
            ?? state.testTakeAssessments.first(where: { $0.id == historicalAssessmentID })
        let capturePreference = state.confirmedCapturePreferences.last(where: {
            $0.interpretationID == state.selectedCaptureInterpretationID
        })
        model.restorePersistedCaptureState(
            brief: state.captureBrief,
            baseInterpretations: baseInterpretations,
            selectedInterpretationID: state.selectedCaptureInterpretationID,
            latestRevision: selectedCaptureRevision,
            assessment: assessment,
            confirmedFeedback: capturePreference?.feedback
        )
        if let restoredTransaction {
            model.loadTestTakeAuthority(restoredTransaction.summary)
        }

        let visible = visibleCandidateLeaves(in: state)
        if visible.count == 3 {
            let selectedRevision: VocalRevisionResult? = state.selectedCandidateID.flatMap { selectedID in
                guard let candidate = state.candidates.first(where: { $0.id == selectedID }),
                      let revisionID = candidate.revisionID,
                      let record = state.revisions.first(where: { $0.id == revisionID }) else { return nil }
                return VocalRevisionResult(candidate: candidate, record: record)
            }
            // Durable preview/asset IDs describe ancestry, not a loaded local
            // audition engine after relaunch. Clear operational references.
            let presentationCandidates = visible.map { candidate in
                var copy = candidate
                copy.previewID = nil
                copy.assetID = nil
                return copy
            }
            model.restorePersistedCreativeState(
                candidates: presentationCandidates,
                selectedCandidateID: state.selectedCandidateID,
                latestRevision: selectedRevision
            )
        } else if let intent = state.creativeIntents.last {
            if let clarification = intent.blockingClarification {
                model.loadBlockingClarification(intent, clarification: clarification)
            } else {
                model.loadCreativeIntent(intent)
            }
        }
        if state.authorityStatus == .current,
           let executable = state.handoffs.last(where: { $0.executable })?.handoff {
            model.loadExecutableHandoff(executable)
        }
        if restoredTransaction == nil,
           state.sourceAuthority != nil,
           assessment != nil {
            model.noteRequest(
                "Saved test-take provenance did not reconcile with the exact persisted brief, plan/revision, assessment, and source; handoff authority remains disabled."
            )
        } else if let restoredTransaction,
                  !restoredTransaction.summary.sourceIsCurrent {
            model.noteRequest(
                "Completed test-take provenance was restored and verified against saved typed state, but its source is historical/read-only until exact live authority reconciles."
            )
        }
    }

    private func visibleCandidateLeaves(in state: VocalSessionState) -> [VocalCreativeCandidate] {
        (1...3).compactMap { interpretationIndex in
            let candidates = state.candidates.filter { $0.interpretationIndex == interpretationIndex }
            if let selectedID = state.selectedCandidateID,
               let selected = candidates.first(where: { $0.id == selectedID }) {
                return selected
            }
            let parentIDs = Set(candidates.compactMap(\.parentCandidateID))
            return candidates
                .filter { !parentIDs.contains($0.id) }
                .max { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.createdAt < rhs.createdAt
                }
                ?? candidates.last
        }
    }

    private func sourceUnavailablePresentation(_ input: VocalSessionState) -> VocalSessionState {
        var state = input
        state.authorityStatus = .sourceUnavailableReadOnly
        state.candidates = state.candidates.map { candidate in
            var copy = candidate
            copy.authorityStatus = .staleSourceReadOnly
            copy.realtimeActivatable = false
            return copy
        }
        state.handoffs = state.handoffs.map { handoff in
            var copy = handoff
            copy.authorityStatus = .sourceUnavailableReadOnly
            copy.executable = false
            return copy
        }
        return state
    }

    private func staleSourcePresentation(_ input: VocalSessionState) -> VocalSessionState {
        var state = input
        state.authorityStatus = .staleSourceDemoted
        state.candidates = state.candidates.map { candidate in
            var copy = candidate
            copy.authorityStatus = .staleSourceReadOnly
            copy.realtimeActivatable = false
            return copy
        }
        state.handoffs = state.handoffs.map { handoff in
            var copy = handoff
            copy.authorityStatus = .staleSourceDemoted
            copy.executable = false
            return copy
        }
        return state
    }

    private func sameAuthority(_ lhs: VocalSourceAuthority, _ rhs: VocalSourceAuthority) -> Bool {
        lhs == rhs
    }

    private func previewRecords(from candidates: [VocalCreativeCandidate]) -> [VocalPreviewAncestryRecord] {
        candidates.compactMap { candidate in
            guard let previewID = candidate.previewID else { return nil }
            return VocalPreviewAncestryRecord(
                id: previewID,
                candidateID: candidate.id,
                sourceSnapshotID: candidate.intent.sourceSnapshotID,
                createdAt: candidate.createdAt
            )
        }
    }

    private func assetRecord(_ manifest: VocalRenderedAssetManifest) -> VocalAssetAncestryRecord {
        VocalAssetAncestryRecord(
            id: manifest.renderID,
            candidateID: manifest.exactCandidateID,
            parentPreviewID: manifest.parentPreviewID,
            parentAssetID: manifest.parentAssetID,
            ancestorAssetIDs: manifest.assetAncestry,
            manifest: manifest
        )
    }

    @discardableResult
    private func mutateCanonical(
        _ successMessage: String,
        mutation: (inout VocalSessionState) -> Void
    ) -> Bool {
        guard let store, var state = canonicalState else { return false }
        let presentedAuthority = presentationState?.authorityStatus
        do {
            mutation(&state)
            state.updatedAt = now()
            _ = try store.save(state)
            canonicalState = state
            presentationState = switch presentedAuthority {
            case .current, nil: state
            case .staleSourceDemoted: staleSourcePresentation(state)
            case .sourceUnavailableReadOnly: sourceUnavailablePresentation(state)
            }
            refreshHistory()
            statusMessage = successMessage
            return true
        } catch {
            statusMessage = "Saved preference update failed: \(error)"
            return false
        }
    }

    private func refreshHistory() {
        guard let store else {
            historyEntries = []
            return
        }
        historyEntries = knownSessionIDs.map { sessionID in
            guard let state = try? store.load(sessionID: sessionID).state else {
                return VocalSessionHistoryEntry(
                    id: sessionID,
                    updatedAt: nil,
                    authorityStatus: nil,
                    desiredResult: nil,
                    sourceSnapshotID: nil,
                    capturePlanCount: 0,
                    assessmentCount: 0,
                    candidateCount: 0,
                    revisionCount: 0
                )
            }
            let desired = state.captureBrief?.desiredResult
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return VocalSessionHistoryEntry(
                id: sessionID,
                updatedAt: state.updatedAt,
                authorityStatus: state.authorityStatus,
                desiredResult: desired?.isEmpty == false ? desired : nil,
                sourceSnapshotID: state.sourceAuthority?.sourceSnapshotID,
                capturePlanCount: state.captureInterpretations.count,
                assessmentCount: state.testTakeAssessments.count,
                candidateCount: state.candidates.count,
                revisionCount: state.revisions.count
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.updatedAt, rhs.updatedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    private var knownSessionIDs: [UUID] {
        (defaults.stringArray(forKey: Self.knownSessionsKey) ?? [])
            .compactMap(UUID.init(uuidString:))
    }

    private func remember(_ id: UUID) {
        var ids = knownSessionIDs
        if !ids.contains(id) { ids.append(id) }
        defaults.set(ids.map { $0.uuidString.lowercased() }, forKey: Self.knownSessionsKey)
    }

    private func forgetKnownID(_ id: UUID) {
        let ids = knownSessionIDs.filter { $0 != id }
        defaults.set(ids.map { $0.uuidString.lowercased() }, forKey: Self.knownSessionsKey)
        if defaults.string(forKey: Self.activeSessionKey).flatMap(UUID.init(uuidString:)) == id {
            defaults.removeObject(forKey: Self.activeSessionKey)
        }
    }

    private func isConfirmedMissingSession(_ error: Error, id: UUID) -> Bool {
        guard case let VocalSessionStoreError.missingSession(missingID) = error else {
            return false
        }
        return missingID == id
    }

    private func mergeByID<T: Identifiable>(_ existing: [T], _ incoming: [T]) -> [T]
    where T.ID == UUID {
        var order = existing.map(\.id)
        var values = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for value in incoming {
            if values[value.id] == nil { order.append(value.id) }
            values[value.id] = value
        }
        return order.compactMap { values[$0] }
    }

    /// Operational UI state clears preview and asset IDs after relaunch because
    /// audio is not loaded. Saving that presentation copy must never erase the
    /// durable ancestry references already recorded for the exact candidate.
    private func mergeCandidatesPreservingArtifactAncestry(
        _ existing: [VocalCreativeCandidate],
        _ incoming: [VocalCreativeCandidate]
    ) -> [VocalCreativeCandidate] {
        let oldByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let preserving = incoming.map { incomingCandidate -> VocalCreativeCandidate in
            guard let old = oldByID[incomingCandidate.id] else { return incomingCandidate }
            var candidate = incomingCandidate
            if candidate.previewID == nil { candidate.previewID = old.previewID }
            if candidate.assetID == nil { candidate.assetID = old.assetID }
            if candidate.authorityStatus != .locallyValidated,
               old.authorityStatus == .locallyValidated {
                candidate.authorityStatus = old.authorityStatus
                candidate.realtimeActivatable = old.realtimeActivatable
            }
            return candidate
        }
        return mergeByID(existing, preserving)
    }

    private func mergeAssessments(
        _ existing: [VocalTestTakeAssessment],
        _ incoming: [VocalTestTakeAssessment]
    ) -> [VocalTestTakeAssessment] {
        mergeUUIDValues(existing, incoming, id: \.id)
    }

    private func mergeCapturePreferences(
        _ existing: [VocalConfirmedCapturePreference],
        _ incoming: [VocalConfirmedCapturePreference]
    ) -> [VocalConfirmedCapturePreference] {
        mergeUUIDValues(existing, incoming, id: \.id)
    }

    private func mergeCreativeIntents(
        _ existing: [VocalCreativeIntent],
        _ incoming: [VocalCreativeIntent]
    ) -> [VocalCreativeIntent] {
        mergeUUIDValues(existing, incoming, id: \.id)
    }

    private func mergeCaptureRevisions(
        _ existing: [VocalCaptureRevisionResult],
        _ incoming: [VocalCaptureRevisionResult]
    ) -> [VocalCaptureRevisionResult] {
        mergeUUIDValues(existing, incoming, id: { $0.revisedInterpretation.id })
    }

    private func mergeUUIDValues<T>(
        _ existing: [T],
        _ incoming: [T],
        id: (T) -> UUID
    ) -> [T] {
        var order = existing.map(id)
        var values = Dictionary(uniqueKeysWithValues: existing.map { (id($0), $0) })
        for value in incoming {
            let valueID = id(value)
            if values[valueID] == nil { order.append(valueID) }
            values[valueID] = value
        }
        return order.compactMap { values[$0] }
    }
}

struct VocalWorkspacePersistenceView: View {
    @ObservedObject var coordinator: VocalWorkspacePersistenceCoordinator
    @ObservedObject var model: VocalWorkspaceModel
    let saveNow: () -> Void
    let restoreCandidate: (VocalCreativeCandidate) -> Void
    let inspectSession: (UUID) -> Void
    let deleteCurrent: () -> Void
    let deleteAll: () -> Void
    let deleteSession: (UUID) -> Void
    @State private var confirmsDeleteCurrent = false
    @State private var confirmsDeleteAll = false
    @State private var confirmsDeleteHistorySession = false
    @State private var pendingHistoryDeletionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                    Text("Saved Vocal session")
                        .font(Theme.Font.section)
                    Text(coordinator.statusMessage)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                Spacer()
                VocalTag(text: coordinator.authorityLabel, accent: coordinator.presentationState?.authorityStatus == .current)
                Button("Save typed state", action: saveNow)
                    .buttonStyle(.bordered)
                Button(coordinator.inspectorExpanded ? "Hide inspector" : "Inspect") {
                    coordinator.inspectorExpanded.toggle()
                }
                .buttonStyle(.bordered)
            }

            if let candidate = model.selectedCreativeCandidate,
               coordinator.presentationState?.authorityStatus == .current {
                preferenceControls(candidate: candidate)
            }

            if coordinator.inspectorExpanded {
                inspector
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
        .confirmationDialog(
            "Delete this saved typed Vocal session?",
            isPresented: $confirmsDeleteCurrent,
            titleVisibility: .visible
        ) {
            Button("Delete Saved Session", role: .destructive) {
                deleteCurrent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes typed Vocal state only. It does not delete raw capture audio or change Logic/AU state.")
        }
        .confirmationDialog(
            "Delete all known saved typed Vocal sessions?",
            isPresented: $confirmsDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete All Saved Sessions", role: .destructive) {
                deleteAll()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this session from saved Vocal history?",
            isPresented: $confirmsDeleteHistorySession,
            titleVisibility: .visible
        ) {
            if let sessionID = pendingHistoryDeletionID {
                Button("Delete Saved Session", role: .destructive) {
                    deleteSession(sessionID)
                    pendingHistoryDeletionID = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingHistoryDeletionID = nil
            }
        } message: {
            Text("This removes typed state for the selected session only. It never deletes raw audio or changes Logic/AU state.")
        }
    }

    private func preferenceControls(candidate: VocalCreativeCandidate) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            Divider().overlay(Theme.Colors.hairline)
            Text("Explicit owner personalization")
                .font(Theme.Font.section)
            Text("Only the Confirm button persists this personal preference. It never becomes a general sound-quality claim.")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(preferenceChoices(candidate), id: \.self) { aspect in
                        Toggle(
                            VocalWorkspacePresentation.words(aspect.rawValue),
                            isOn: Binding(
                                get: { coordinator.selectedPreferenceAspects.contains(aspect) },
                                set: { _ in coordinator.togglePreferenceAspect(aspect) }
                            )
                        )
                        .toggleStyle(.button)
                        .controlSize(.small)
                    }
                }
            }
            HStack {
                TextField("Optional private owner note", text: $coordinator.creativePreferenceNote)
                    .textFieldStyle(.roundedBorder)
                Button("Confirm selected candidate preference") {
                    coordinator.confirmCreativePreference(candidateID: candidate.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
            }
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            Divider().overlay(Theme.Colors.hairline)
            sessionHistory
            if let state = coordinator.presentationState {
                Text("Session \(VocalWorkspacePresentation.shortID(state.id)) · \(state.candidates.count) candidate records · \(state.revisions.count) revisions · \(state.previews.count) preview references · \(state.assets.count) asset references")
                    .font(Theme.Font.data)
                if let source = state.sourceAuthority {
                    Text("Source \(VocalWorkspacePresentation.shortID(source.sourceSnapshotID)) · SHA-256 \(source.contentHashSHA256.prefix(12))…")
                        .font(Theme.Font.data)
                    ForEach(bindingInspectionLines(source.immutableSourceID), id: \.self) { line in
                        Text(line).font(Theme.Font.data)
                    }
                }
                if state.confirmedCapturePreferences.isEmpty,
                   state.confirmedCreativePreferences.isEmpty {
                    Text("No explicitly confirmed owner preferences stored.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.mutedText)
                } else {
                    Text("Confirmed owner preferences: \(state.confirmedCapturePreferences.count) capture · \(state.confirmedCreativePreferences.count) creative")
                        .font(Theme.Font.meta)
                }
                DisclosureGroup("Candidate history and exact restore") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        ForEach(state.candidates.sorted(by: historyOrder)) { candidate in
                            HStack {
                                Text("#\(candidate.interpretationIndex) \(candidate.title) · \(VocalWorkspacePresentation.shortID(candidate.id))")
                                    .font(Theme.Font.meta)
                                Spacer()
                                Button("Restore exact") {
                                    guard let exact = coordinator.candidateForExactRestore(candidate.id) else { return }
                                    restoreCandidate(exact)
                                    coordinator.selectRestoredCandidate(exact)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(state.authorityStatus != .current || candidate.authorityStatus != .locallyValidated)
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.four)
                }
                .font(Theme.Font.meta)
                HStack {
                    Button("Forget capture preferences") {
                        coordinator.forgetCapturePreferences(in: model)
                    }
                        .disabled(state.confirmedCapturePreferences.isEmpty)
                    Button("Forget creative preferences") { coordinator.forgetCreativePreferences() }
                        .disabled(state.confirmedCreativePreferences.isEmpty)
                    Spacer()
                    Button("Delete saved session", role: .destructive) { confirmsDeleteCurrent = true }
                    Button("Delete all \(coordinator.knownSessionCount) known sessions", role: .destructive) {
                        confirmsDeleteAll = true
                    }
                    .disabled(coordinator.knownSessionCount == 0)
                }
            } else {
                Text("No saved typed Vocal session is available.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }
            VocalHonestyNote(
                text: "The inspector contains typed identities, hashes, plans, ancestry, assessment references, handoffs, and explicit preferences only—never raw audio, file paths, or provider credentials."
            )
        }
    }

    @ViewBuilder
    private var sessionHistory: some View {
        if coordinator.historyEntries.isEmpty {
            Text("No saved session history.")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.mutedText)
        } else {
            DisclosureGroup("Saved session history (\(coordinator.historyEntries.count))") {
                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    ForEach(
                        coordinator.historyEntries,
                        id: \VocalSessionHistoryEntry.id
                    ) { (entry: VocalSessionHistoryEntry) in
                        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Session \(VocalWorkspacePresentation.shortID(entry.id))")
                                    .font(Theme.Font.data)
                                Spacer()
                                Text(historyAuthorityLabel(entry.authorityStatus))
                                    .font(Theme.Font.meta.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            if let desiredResult = entry.desiredResult {
                                Text(desiredResult)
                                    .font(Theme.Font.meta)
                                    .lineLimit(2)
                            }
                            if let updatedAt = entry.updatedAt {
                                Text("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened)) · \(entry.capturePlanCount) plans · \(entry.assessmentCount) assessments · \(entry.candidateCount) candidates · \(entry.revisionCount) revisions")
                                    .font(Theme.Font.data)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            } else {
                                Text("Typed metadata unavailable; this entry cannot grant authority.")
                                    .font(Theme.Font.meta)
                                    .foregroundStyle(Theme.Colors.evidenceUnavailable)
                            }
                            if let sourceSnapshotID = entry.sourceSnapshotID {
                                Text("Source identity \(VocalWorkspacePresentation.shortID(sourceSnapshotID))")
                                    .font(Theme.Font.data)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            HStack {
                                Button(
                                    coordinator.activeSessionID == entry.id
                                        ? (coordinator.presentationState?.authorityStatus == .current
                                            ? "Active · exact source"
                                            : "Inspecting read-only")
                                        : "Inspect read-only"
                                ) {
                                    inspectSession(entry.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                // Unavailable records remain retryable
                                // inspection targets; they never grant
                                // authority unless a later exact load succeeds.
                                .disabled(coordinator.activeSessionID == entry.id)
                                Button("Delete", role: .destructive) {
                                    pendingHistoryDeletionID = entry.id
                                    confirmsDeleteHistorySession = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(Theme.Spacing.eight)
                        .instrumentSurface(.card, radius: Theme.Radius.small)
                    }
                }
                .padding(.top, Theme.Spacing.four)
            }
            .font(Theme.Font.meta)
            VocalHonestyNote(
                text: "Opening saved history is inspection-only. Working, revision, render, handoff, and commit controls remain denied until the exact source and immutable test-take transaction reconcile."
            )
        }
    }

    private func historyAuthorityLabel(_ authority: VocalSessionAuthorityStatus?) -> String {
        switch authority {
        case .current: "CURRENT WHEN SAVED"
        case .staleSourceDemoted: "STALE WHEN SAVED"
        case .sourceUnavailableReadOnly: "SOURCE UNAVAILABLE"
        case nil: "UNAVAILABLE"
        }
    }

    private func preferenceChoices(_ candidate: VocalCreativeCandidate) -> [VocalAspect] {
        var seen = Set<VocalAspect>()
        let choices = candidate.intent.desiredChanges.map(\.aspect)
            + candidate.intent.preservation.preserved
            + candidate.intent.aspectLocks.map(\.aspect)
        return choices.filter { seen.insert($0).inserted }.prefix(12).map { $0 }
    }

    private func historyOrder(_ lhs: VocalCreativeCandidate, _ rhs: VocalCreativeCandidate) -> Bool {
        if lhs.interpretationIndex != rhs.interpretationIndex {
            return lhs.interpretationIndex < rhs.interpretationIndex
        }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func bindingInspectionLines(_ identifier: String) -> [String] {
        identifier.split(separator: ";").compactMap { component in
            if component.hasPrefix("test-take-binding-id:") {
                return "Test-take binding identity \(component.dropFirst("test-take-binding-id:".count))"
            }
            if component.hasPrefix("test-take-start-sha256:") {
                return "Test-take start SHA-256 \(component.dropFirst("test-take-start-sha256:".count).prefix(16))…"
            }
            if component.hasPrefix("test-take-completion-sha256:") {
                return "Test-take completion SHA-256 \(component.dropFirst("test-take-completion-sha256:".count).prefix(16))…"
            }
            if component.hasPrefix("instance-id:") {
                return "Captured instance \(component.dropFirst("instance-id:".count))"
            }
            if component.hasPrefix("runtime-epoch:") {
                return "Captured runtime \(component.dropFirst("runtime-epoch:".count))"
            }
            if component.hasPrefix("assessment-id:") {
                return "Bound assessment \(component.dropFirst("assessment-id:".count))"
            }
            return nil
        }
    }
}
