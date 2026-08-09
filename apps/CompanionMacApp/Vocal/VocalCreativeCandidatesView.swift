import SwiftUI
import VocalProduction

struct VocalCreativeCandidatesView: View {
    @ObservedObject var model: VocalWorkspaceModel
    let callbacks: VocalWorkspaceCallbacks

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            VocalSectionHeader(
                index: "6",
                title: "Three creative hypotheses",
                detail: "Inspect processing, boundary, limitations, locks, ancestry, and authority before requesting a render."
            )

            if let conflictMessage = model.conflictMessage {
                Label(conflictMessage, systemImage: "exclamationmark.octagon")
                    .font(Theme.Font.meta)
                    .foregroundStyle(.orange)
                    .padding(Theme.Spacing.eight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.warningSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }

            VStack(spacing: Theme.Spacing.eight) {
                ForEach(0..<3, id: \.self) { index in
                    if model.creativeCandidates.indices.contains(index) {
                        candidateCard(model.creativeCandidates[index], number: index + 1)
                    } else {
                        VocalEmptyHypothesisSlot(number: index + 1, kind: "Creative")
                    }
                }
            }

            executableHandoffRequest
            revisionComposer
        }
    }

    private func candidateCard(
        _ candidate: VocalCreativeCandidate,
        number: Int
    ) -> some View {
        let selected = model.selectedCreativeCandidateID == candidate.id
        let canRequestWork = candidate.authorityStatus == .locallyValidated
        let hasAuditionReference = candidate.previewID != nil || candidate.assetID != nil
        let scopedOrAsset = candidate.intent.scope.kind != .fullSource
            || candidate.boundary == .scopedEditablePlanForOfflineRender
            || candidate.boundary == .analysisDrivenResynthesis
            || candidate.boundary == .renderedAsset
        let scopedAssetPermission = candidate.intent.scope.kind == .fullSource
            || candidate.intent.assetAcceptance == .allowLocalRenderedAsset
            || candidate.intent.assetAcceptance == .requireLocalRenderedAsset
        return VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                    HStack {
                        VocalTag(text: "HYPOTHESIS \(number)", accent: selected)
                        VocalTag(text: VocalWorkspacePresentation.authorityLabel(candidate.authorityStatus))
                        if selected { VocalTag(text: "SELECTED", accent: true) }
                    }
                    Text(candidate.title)
                        .font(Theme.Font.body.weight(.medium))
                    Text(candidate.summary)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(selected ? "Audition selected" : "Select to audition") {
                    model.selectCreativeCandidate(candidate)
                    callbacks.selectCreativeCandidate(candidate)
                }
                .buttonStyle(.bordered)
                .disabled(selected)
            }

            HStack(spacing: Theme.Spacing.eight) {
                VocalTag(
                    text: VocalWorkspacePresentation.processingBoundaryLabel(candidate.boundary),
                    accent: true
                )
                VocalTag(text: candidate.realtimeActivatable ? "Realtime-activatable plan" : "Off-render / asset path")
                VocalTag(text: "Source \(VocalWorkspacePresentation.shortID(candidate.intent.sourceSnapshotID))")
            }

            if scopedOrAsset {
                VocalHonestyNote(
                    text: "SCOPED / ASSET PATH · offline derivative only. An explicit render request goes to the parent-owned atomic source-preserving publisher; it does not activate the AU, edit a Logic region, replace source audio, or prove a render completed.",
                    systemImage: "waveform.badge.plus"
                )
            } else {
                VocalHonestyNote(
                    text: "FULL-SOURCE EDITABLE PLAN · requesting a preview does not activate an AU instance or change Logic. Host activation remains a separate explicit validated action.",
                    systemImage: "slider.horizontal.3"
                )
            }

            DisclosureGroup("Processing and limitations") {
                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    candidateSection(
                        "Processing labels",
                        candidate.plan.nodes.map(VocalWorkspacePresentation.nodeLabel)
                    )
                    candidateSection("Limitations", candidate.limitations)
                    candidateSection(
                        "Stop conditions",
                        candidate.intent.preservation.stopConditions
                    )
                    if !candidate.aspectBindings.isEmpty {
                        candidateSection(
                            "Aspect bindings",
                            candidate.aspectBindings.map {
                                "\(VocalWorkspacePresentation.words($0.aspect.rawValue)) → \($0.nodeIDs.count) typed node reference(s)"
                            }
                        )
                    }
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            lockSection(candidate)
            ancestrySection(candidate)
            conflictSection(candidate)

            HStack {
                if let previewID = candidate.previewID {
                    Text("Preview reference \(VocalWorkspacePresentation.shortID(previewID)); no listening judgment implied")
                        .font(Theme.Font.data)
                        .foregroundStyle(Theme.Colors.mutedText)
                } else if let assetID = candidate.assetID {
                    Text("Asset reference \(VocalWorkspacePresentation.shortID(assetID)); no listening judgment implied")
                        .font(Theme.Font.data)
                        .foregroundStyle(Theme.Colors.mutedText)
                } else {
                    Text("No preview or derivative asset reference")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.mutedText)
                }
                Spacer()
                if !scopedOrAsset, hasAuditionReference {
                    Button("Use as working") {
                        callbacks.requestUseAsWorkingCandidate(candidate)
                        model.noteRequest(
                            "Use-as-working requested for the exact candidate plan; selection and audition alone never change commit authority."
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.accent)
                    .disabled(!canRequestWork)
                    .help("Explicitly binds edits and Commit Working Plan to this exact validated preview graph.")
                }

                Button(scopedOrAsset ? "Request scoped asset render" : "Render and use as working") {
                    callbacks.requestCandidateRender(candidate)
                    model.noteRequest(
                        scopedOrAsset
                            ? "Offline derivative render requested for hypothesis \(number); no artifact is recorded until the parent supplies one."
                            : "A local render and explicit working-plan request was submitted for hypothesis \(number); no commit is implied."
                    )
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.accent)
                .disabled(!canRequestWork || !scopedAssetPermission)
                .help(
                    scopedAssetPermission
                        ? (scopedOrAsset
                            ? "Requests an isolated parent-owned render; it does not replace source or a Logic region."
                            : "Renders this exact plan and makes that validated render the working graph. Commit remains a separate explicit action.")
                        : "The typed intent does not permit a local rendered derivative asset."
                )

                Button("Request listening comparison") {
                    callbacks.requestListeningComparison(candidate)
                    model.noteRequest(
                        "Listening comparison requested; this workspace has not recorded a preference."
                    )
                }
                .buttonStyle(.bordered)
                .disabled(!canRequestWork || !hasAuditionReference)
                .help(
                    hasAuditionReference
                        ? "Requests the parent-owned listening workflow."
                        : "A validated preview or derivative-asset reference is required first."
                )
            }
        }
        .padding(Theme.Spacing.twelve)
        .background(
            selected ? Theme.Colors.accentSubtle : Theme.Colors.raised,
            in: RoundedRectangle(cornerRadius: Theme.Radius.medium)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(selected ? Theme.Colors.accent : Theme.Colors.hairline, lineWidth: 1)
        )
    }

    private func lockSection(_ candidate: VocalCreativeCandidate) -> some View {
        let aspects = lockableAspects(candidate)
        return DisclosureGroup("Aspect locks") {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
                if aspects.isEmpty {
                    Text("No lockable requested or inherited aspects are recorded.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.mutedText)
                } else {
                    ForEach(aspects, id: \.self) { aspect in
                        let locked = candidate.intent.aspectLocks.contains { $0.aspect == aspect }
                        HStack {
                            Image(systemName: locked ? "lock.fill" : "lock.open")
                                .foregroundStyle(locked ? Theme.Colors.accent : Theme.Colors.mutedText)
                            Text(VocalWorkspacePresentation.words(aspect.rawValue))
                                .font(Theme.Font.meta)
                            Spacer()
                            Button(locked ? "Request unlock" : "Request lock") {
                                callbacks.requestAspectLock(candidate, aspect, !locked)
                                model.noteRequest(
                                    "Aspect \(locked ? "unlock" : "lock") requested; the typed candidate remains unchanged until validated by the parent."
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(candidate.authorityStatus != .locallyValidated)
                        }
                    }
                }
            }
            .padding(.top, Theme.Spacing.eight)
        }
        .font(Theme.Font.meta)
    }

    @ViewBuilder
    private func ancestrySection(_ candidate: VocalCreativeCandidate) -> some View {
        if let revision = model.latestCreativeRevision,
           revision.candidate.id == candidate.id {
            DisclosureGroup("Exact revision ancestry") {
                VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                    Text(
                        revision.record.exactAncestorCandidateIDs
                            .map(VocalWorkspacePresentation.shortID)
                            .joined(separator: " → ")
                    )
                    .font(Theme.Font.data)
                    Text("Changed nodes: \(revision.record.changedNodeIDs.map(VocalWorkspacePresentation.shortID).joined(separator: ", "))")
                        .font(Theme.Font.data)
                    Text("Inserted nodes: \(revision.record.insertedNodeIDs.map(VocalWorkspacePresentation.shortID).joined(separator: ", "))")
                        .font(Theme.Font.data)
                    Text("Removed nodes: \(revision.record.removedNodeIDs.map(VocalWorkspacePresentation.shortID).joined(separator: ", "))")
                        .font(Theme.Font.data)
                    Text(revision.record.changedScopeOnly ? "Scope-only revision" : "Processing and/or intent revision")
                        .font(Theme.Font.meta)
                }
                .foregroundStyle(Theme.Colors.secondaryText)
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)
        } else if candidate.parentCandidateID != nil
            || candidate.revisionID != nil
            || candidate.revertedToCandidateID != nil {
            DisclosureGroup("Ancestry") {
                VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                    Text("Parent candidate: \(VocalWorkspacePresentation.shortID(candidate.parentCandidateID))")
                    Text("Revision: \(VocalWorkspacePresentation.shortID(candidate.revisionID))")
                    Text("Exact revert target: \(VocalWorkspacePresentation.shortID(candidate.revertedToCandidateID))")
                }
                .font(Theme.Font.data)
                .foregroundStyle(Theme.Colors.secondaryText)
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)
        }
    }

    @ViewBuilder
    private func conflictSection(_ candidate: VocalCreativeCandidate) -> some View {
        let conflicts = possibleLockConflicts(candidate)
        if candidate.authorityStatus != .locallyValidated || !conflicts.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                Text("Conflict / authority boundary")
                    .font(Theme.Font.meta.weight(.semibold))
                if candidate.authorityStatus != .locallyValidated {
                    Text(VocalWorkspacePresentation.authorityLabel(candidate.authorityStatus))
                        .font(Theme.Font.meta)
                }
                VocalBulletList(items: conflicts)
            }
            .padding(Theme.Spacing.eight)
            .background(Theme.Colors.warningSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
    }

    private var revisionComposer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack {
                Text("Revise selected hypothesis")
                    .font(Theme.Font.section)
                Spacer()
                if let selected = model.selectedCreativeCandidate {
                    Text("Candidate \(VocalWorkspacePresentation.shortID(selected.id))")
                        .font(Theme.Font.data)
                        .foregroundStyle(Theme.Colors.mutedText)
                }
            }
            TextField(
                "Example: keep the movement, preserve consonants, and make the space darker",
                text: $model.creativeRevisionText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...3)
            .padding(Theme.Spacing.eight)
            .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
            HStack {
                Text("A revision must preserve exact source, scope, locks, and parent ancestry or be refused.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                Button("Request typed revision") {
                    guard let candidate = model.selectedCreativeCandidate else { return }
                    callbacks.requestCreativeRevision(candidate, model.creativeRevisionText)
                    model.noteRequest(
                        "Typed candidate revision requested; the current candidate and source remain unchanged."
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
                .disabled(
                    model.selectedCreativeCandidate == nil
                        || model.creativeRevisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.selectedCreativeCandidate?.authorityStatus != .locallyValidated
                )
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private var executableHandoffRequest: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.twelve) {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                Text("Validated Create handoff")
                    .font(Theme.Font.section)
                Text("The parent must bind source authority, candidate, scope, plan, measurements, and final-user-action requirements.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            Spacer()
            Button("Request executable handoff") {
                guard let summary = model.makeHandoffSummary(),
                      let candidate = model.selectedCreativeCandidate else { return }
                callbacks.requestExecutableHandoff(summary, candidate)
                model.noteRequest(
                    "Validated executable handoff requested; no activation or offline render is implied."
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accent)
            .disabled(
                model.makeHandoffSummary() == nil
                    || model.selectedCreativeCandidate?.authorityStatus != .locallyValidated
            )
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func candidateSection(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(title).font(Theme.Font.meta.weight(.semibold))
            if items.isEmpty {
                Text("None recorded")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            } else {
                VocalBulletList(items: items)
            }
        }
    }

    private func lockableAspects(_ candidate: VocalCreativeCandidate) -> [VocalAspect] {
        var seen = Set<VocalAspect>()
        return (candidate.intent.aspectLocks.map(\.aspect)
            + candidate.intent.desiredChanges.map(\.aspect)
            + candidate.intent.preservation.preserved)
            .filter { seen.insert($0).inserted }
    }

    private func possibleLockConflicts(_ candidate: VocalCreativeCandidate) -> [String] {
        let locked = Set(candidate.intent.aspectLocks.map(\.aspect))
        return candidate.intent.desiredChanges.compactMap { change in
            guard locked.contains(change.aspect), change.direction != .preserve else { return nil }
            return "Requested \(VocalWorkspacePresentation.words(change.direction.rawValue).lowercased()) intersects locked \(VocalWorkspacePresentation.words(change.aspect.rawValue).lowercased()); validation or refusal is required."
        }
    }
}
