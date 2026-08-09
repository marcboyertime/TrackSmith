import SwiftUI
import VocalProduction

struct VocalGuideCreateHandoffView: View {
    @ObservedObject var model: VocalWorkspaceModel
    let callbacks: VocalWorkspaceCallbacks

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            VocalSectionHeader(
                index: "4",
                title: "Guide → Create handoff",
                detail: "Carry the chosen capture identity, ancestry, preservation rules, unknowns, and assessment reference forward explicitly."
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                stateHeader

                if let summary = currentSummary {
                    HStack(alignment: .top, spacing: Theme.Spacing.twelve) {
                        summaryColumn(
                            "Identity",
                            [
                                "Brief \(VocalWorkspacePresentation.shortID(summary.captureBriefID))",
                                "Capture \(VocalWorkspacePresentation.shortID(summary.interpretationID))",
                                "Revision \(VocalWorkspacePresentation.shortID(summary.revisionID))",
                                "Assessment \(VocalWorkspacePresentation.shortID(summary.assessmentID))",
                                "Test take \(VocalWorkspacePresentation.shortID(summary.testTakeBindingID))",
                                "Source \(VocalWorkspacePresentation.shortID(summary.sourceSnapshotID))",
                                "Completion SHA-256 \(summary.completedBindingHashSHA256.prefix(16))…",
                            ]
                        )
                        summaryColumn(
                            "Preserve",
                            summary.preservePerformanceAttributes.map {
                                VocalWorkspacePresentation.words($0.rawValue)
                            } + summary.preserveVoiceAspects.map {
                                VocalWorkspacePresentation.words($0.rawValue)
                            }
                        )
                        summaryColumn(
                            "Carry as unknown",
                            summary.assumptions + summary.uncertainties
                        )
                    }
                } else {
                    Text("Select one capture hypothesis before requesting a handoff.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                if case let .executableHandoffPrepared(_, handoff) = model.handoffState {
                    executableDetails(handoff)
                }

                HStack {
                    VocalHonestyNote(
                        text: "A handoff transfers typed context only. It does not edit Logic, activate DSP, render audio, or prove the selected capture sounds better."
                    )
                    Button("Prepare capture context for Create") {
                        guard let summary = model.makeHandoffSummary() else { return }
                        model.markHandoffRequested(summary)
                        callbacks.requestGuideCreateHandoff(summary)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.accent)
                    .disabled(model.makeHandoffSummary() == nil || isPending)
                }
            }
            .padding(Theme.Spacing.twelve)
            .instrumentSurface(.raised, radius: Theme.Radius.medium)
        }
    }

    @ViewBuilder
    private var stateHeader: some View {
        HStack {
            Text("Handoff state")
                .font(Theme.Font.section)
            Spacer()
            switch model.handoffState {
            case .notRequested:
                VocalTag(text: "NOT REQUESTED")
            case .captureContextRequestPending:
                VocalTag(text: "CAPTURE CONTEXT PENDING", accent: true)
            case .captureContextPrepared:
                VocalTag(text: "CAPTURE CONTEXT PREPARED", accent: true)
            case .executableHandoffPrepared:
                VocalTag(text: "EXECUTABLE HANDOFF PREPARED", accent: true)
            case .refused:
                VocalTag(text: "REFUSED")
            }
        }
        if case let .refused(reason) = model.handoffState {
            Text(reason)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private var currentSummary: VocalGuideCreateHandoffSummary? {
        switch model.handoffState {
        case let .captureContextRequestPending(summary),
             let .captureContextPrepared(summary),
             let .executableHandoffPrepared(summary, _): summary
        case .notRequested, .refused: model.makeHandoffSummary()
        }
    }

    private var isPending: Bool {
        if case .captureContextRequestPending = model.handoffState { return true }
        return false
    }

    private func summaryColumn(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(title).font(Theme.Font.section)
            if items.isEmpty {
                Text("None recorded")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            } else {
                VocalBulletList(items: items, limit: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func executableDetails(_ handoff: VocalGuideCreateHandoff) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            Divider().overlay(Theme.Colors.hairline)
            HStack(spacing: Theme.Spacing.eight) {
                VocalTag(text: VocalWorkspacePresentation.words(handoff.proposal.executionMode.rawValue), accent: true)
                VocalTag(text: VocalWorkspacePresentation.processingBoundaryLabel(handoff.proposal.processingBoundary))
                VocalTag(text: "Candidate \(VocalWorkspacePresentation.shortID(handoff.proposal.candidateID))")
                VocalTag(text: "Source \(VocalWorkspacePresentation.shortID(handoff.proposal.sourceSnapshotID))")
            }
            Text("Validator: \(handoff.proposal.validationIdentity)")
                .font(Theme.Font.data)
                .foregroundStyle(Theme.Colors.mutedText)
            if handoff.reviewedKnowledgeIDs.isEmpty, handoff.reviewedProcedureIDs.isEmpty {
                Text("Reviewed tutor references: none supplied. Tutor context contributed no authority.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            } else {
                Text(
                    "Reviewed tutor references: \(handoff.reviewedKnowledgeIDs.count) knowledge · \(handoff.reviewedProcedureIDs.count) procedure"
                )
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            }
            VocalHonestyNote(
                text: handoff.requiresFinalUserAction
                    ? "The typed executable proposal passed its local handoff validation, but final user action is still required. No activation or render is recorded."
                    : "This handoff does not record a required final user action; parent validation should refuse it."
            )
        }
    }
}
