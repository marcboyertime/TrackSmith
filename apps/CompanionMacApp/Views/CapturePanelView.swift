import AgentCore
import PlanSchema
import SwiftUI

struct CapturePanelView: View {
    @ObservedObject var model: CompanionSessionModel
    var beforeCapture: (() -> Bool)? = nil
    var captureButtonTitle = "Analyze Recent Playback"
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Theme.Spacing.legacy10) {
                    Circle().fill(model.statusColor).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                        Text("Audio Context")
                            .font(Theme.Font.section)
                            .foregroundStyle(Theme.Colors.text)
                        Text(model.instances.isEmpty ? "No active insert — add TrackSmith in Logic to capture playback." : model.status)
                            .font(Theme.Font.meta)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let peak = model.activeSessionInstance?.inputPeakDBFS {
                        Text(String(format: "%+.1f dBFS", peak))
                            .font(Theme.Font.data)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(Theme.Font.meta.weight(.semibold))
                        .foregroundStyle(Theme.Colors.mutedText)
                        .accessibilityLabel(isExpanded ? "Collapse audio context" : "Expand audio context")
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse audio context" : "Expand audio context")
            .accessibilityValue(audioContextAccessibilityValue)
            .accessibilityHint(isExpanded ? "Hides capture, source, waveform, provider, and evidence details." : "Shows capture, source, waveform, provider, and evidence details.")

            if isExpanded {
                Divider().overlay(Theme.Colors.hairline)
                VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
                    Text(model.detailStatus)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    if !model.restoredConversationStatus.isEmpty {
                        Text(model.restoredConversationStatus)
                            .font(Theme.Font.meta)
                            .foregroundStyle(Theme.Colors.mutedText)
                    }
                WaveformView(samples: model.waveform)
                    .frame(height: 112)
                HStack {
                    Picker("Source", selection: $model.sourceType) {
                        ForEach(SourceType.allCases, id: \.self) { type in
                            Text(sourceLabel(type)).tag(type)
                        }
                    }
                    .frame(width: 220)
                    Button(captureButtonTitle) {
                        guard beforeCapture?() != false else { return }
                        model.captureRecent()
                    }
                        .disabled(model.selectedInstanceID == nil || model.isBusy)
                    if let capture = model.captureArtifact {
                        Text(String(format: "%.1f s · %.0f Hz · %d ch",
                                    Double(capture.frameCount) / capture.sampleRate,
                                    capture.sampleRate,
                                    capture.channelCount))
                            .font(Theme.Font.data)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    Spacer()
                }
                if let interpretation = model.interpretedIntent {
                    Divider()
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy5) {
                        Text("Validated interpretation")
                            .font(Theme.Font.section)
                        Text("Change: \(intentList(interpretation.desiredChanges))")
                        Text("Preserve: \(intentList(interpretation.preservedAttributes))")
                        Text("Prohibit: \(intentList(interpretation.prohibitedChanges))")
                        if !interpretation.unresolvedAmbiguities.isEmpty {
                            Text("Uncertainty: \(interpretation.unresolvedAmbiguities.prefix(2).joined(separator: " "))")
                        }
                    }
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
                if !model.displayedHypotheses.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy5) {
                        Text("Grounded production hypotheses")
                            .font(Theme.Font.section)
                        ForEach(Array(model.displayedHypotheses.enumerated()), id: \.offset) { _, hypothesis in
                            // " | " is an upstream concatenation separator; split it here at presentation only.
                            let fragments = hypothesis.intendedPerceptualChange
                                .components(separatedBy: " | ")
                                .map(hypothesisProse)
                            ForEach(Array(fragments.enumerated()), id: \.offset) { _, fragment in
                                Card(style: .hypothesis) {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                                        Text(fragment)
                                            .font(Theme.Font.body)
                                        Text("Strategy: \(hypothesis.processingOptionsConsidered.map(\.rawValue).joined(separator: ", "))")
                                            .font(Theme.Font.meta)
                                        if let risk = hypothesis.risks.first {
                                            Text("Risk: \(risk)")
                                                .font(Theme.Font.meta)
                                        }
                                        Badge(hypothesisDisclaimer, style: .hypothesis)
                                        if hypothesis.subjectiveListeningRemainsDecisive {
                                            Text("Listening remains decisive")
                                                .font(Theme.Font.meta)
                                        }
                                    }
                                }
                                .padding(.bottom, Theme.Spacing.legacy3)
                            }
                        }
                    }
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
                let displayedEvidence = model.displayedEvidence
                let relationships = Set(displayedEvidence.map(\.relationship))
                let sharedRelationship = relationships.count == 1 ? relationships.first : nil
                if !displayedEvidence.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.eight) {
                            Text("Relevant measured evidence")
                                .font(Theme.Font.section)
                            if let sharedRelationship {
                                Badge(sharedRelationship.rawValue, style: .category)
                            }
                        }
                        ForEach(Array(displayedEvidence.enumerated()), id: \.offset) { _, observation in
                            EvidenceObservationRow(
                                observation: observation,
                                showsRelationship: sharedRelationship == nil
                            )
                        }
                    }
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
                if let provider = model.providerEvidenceSummary,
                   let audit = model.validationAuditSummary {
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                        Text("Provider evidence")
                            .font(Theme.Font.section)
                        Text(provider).textSelection(.enabled)
                        Text(audit)
                    }
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
                Divider().overlay(Theme.Colors.hairline)
                HStack(spacing: Theme.Spacing.eight) {
                    Image(systemName: model.providerSelection.usesCloud ? "cloud" : "checkmark.shield")
                        .foregroundStyle(model.providerSelection.usesCloud ? Theme.Colors.accent : Theme.Colors.secondaryText)
                    Text(model.activeProviderDescription)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer()
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                            .font(Theme.Font.meta)
                    }
                }
                }
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private var audioContextAccessibilityValue: String {
        let status = model.instances.isEmpty
            ? "No active insert. Add TrackSmith in Logic to capture playback."
            : model.status
        guard let peak = model.activeSessionInstance?.inputPeakDBFS else { return status }
        return "\(status). Current input peak \(String(format: "%+.1f dBFS", peak))."
    }
}

private struct EvidenceObservationRow: View {
    let observation: ProductionEvidenceObservation
    let showsRelationship: Bool

    var body: some View {
        let display = evidenceDisplay(for: observation)
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.eight) {
            Text(display.name)
                .font(Theme.Font.meta)
                .help(display.inspectionText)
            Spacer()
            Text(display.measuredValue)
                .font(display.isMeasuredValue ? Theme.Font.data : Theme.Font.meta)
            if showsRelationship {
                Badge(observation.relationship.rawValue, style: .category)
            }
        }
        .foregroundStyle(Theme.Colors.secondaryText)
    }
}
