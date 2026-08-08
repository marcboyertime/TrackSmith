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
                            .font(Theme.Font.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if let interpretation = model.interpretedIntent {
                    Divider()
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy5) {
                        Text("Validated interpretation")
                            .font(.subheadline.weight(.semibold))
                        Text("Change: \(intentList(interpretation.desiredChanges))")
                        Text("Preserve: \(intentList(interpretation.preservedAttributes))")
                        Text("Prohibit: \(intentList(interpretation.prohibitedChanges))")
                        if !interpretation.unresolvedAmbiguities.isEmpty {
                            Text("Uncertainty: \(interpretation.unresolvedAmbiguities.prefix(2).joined(separator: " "))")
                        }
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                }
                if !model.displayedHypotheses.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy5) {
                        Text("Grounded production hypotheses")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(model.displayedHypotheses.enumerated()), id: \.offset) { index, hypothesis in
                            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                                Text("\(index + 1). \(hypothesis.intendedPerceptualChange)")
                                Text("Strategy: \(hypothesis.processingOptionsConsidered.map(\.rawValue).joined(separator: ", "))")
                                if let risk = hypothesis.risks.first {
                                    Text("Risk: \(risk)")
                                }
                                if hypothesis.subjectiveListeningRemainsDecisive {
                                    Text("Listening remains decisive")
                                }
                            }
                            .padding(.bottom, Theme.Spacing.legacy3)
                        }
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                }
                if !model.displayedEvidence.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        Text("Relevant measured evidence")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(model.displayedEvidence.enumerated()), id: \.offset) { _, observation in
                            Text(evidenceText(observation))
                                .font(Theme.Font.caption.monospaced())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                if let provider = model.providerEvidenceSummary,
                   let audit = model.validationAuditSummary {
                    VStack(alignment: .leading, spacing: Theme.Spacing.legacy3) {
                        Text("Provider evidence")
                            .font(.subheadline.weight(.semibold))
                        Text(provider).textSelection(.enabled)
                        Text(audit)
                    }
                    .font(Theme.Font.caption.monospaced())
                    .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
