import AgentCore
import PlanSchema
import SwiftUI

struct CapturePanelView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        GroupBox("Captured plug-in input") {
            VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
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
                            .font(Theme.Font.data)
                            .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.eight)
        }
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
    }
}
