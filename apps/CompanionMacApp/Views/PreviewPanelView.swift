import PreviewWorkflow
import SwiftUI

struct PreviewPanelView: View {
    @ObservedObject var model: CompanionSessionModel
    var allowsUseAsWorking = true

    @ViewBuilder
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            Text(model.previewManifest?.vocalCreativeCandidates == nil
                ? "Level-matched preview variants"
                : "Level-matched vocal interpretations")
                .font(Theme.Font.section)
            if model.previewManifest != nil {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: Theme.Spacing.legacy10)], spacing: Theme.Spacing.legacy10) {
                    PreviewCard(
                        title: "Original",
                        subtitle: "Unprocessed capture",
                        selected: model.selectedAuditionIndex == 0,
                        warning: nil
                    ) { model.selectAudition(index: 0) }
                    ForEach(Array(model.auditionVariants.enumerated()), id: \.element.previewID) { index, variant in
                        PreviewCard(
                            title: previewTitle(variant),
                            subtitle: variant.status == .valid
                                ? String(format: "%+.2f dB match", variant.loudnessMatchGainDB)
                                : "Rejected",
                            subtitleIsMeasured: variant.status == .valid,
                            selected: model.selectedAuditionIndex == index + 1,
                            warning: variant.warnings.first ?? variant.rejectionReasons.first,
                            working: model.workingPlanIsVariant(variant),
                            useAction: allowsUseAsWorking
                                ? { model.useVariantAsWorking(index: index + 1) }
                                : nil
                        ) { model.selectAudition(index: index + 1) }
                    }
                    if let revision = model.workingPreview,
                       let workingIndex = model.workingAuditionIndex {
                        PreviewCard(
                            title: "Working Revision",
                            subtitle: String(format: "%+.2f dB match", revision.loudnessMatchGainDB),
                            subtitleIsMeasured: true,
                            selected: model.selectedAuditionIndex == workingIndex,
                            warning: revision.warnings.first,
                            working: true
                        ) { model.selectWorkingAudition() }
                    }
                }
                .padding(Theme.Spacing.eight)
            } else {
                Text("Capture recent playback, describe the result, then render three deterministic options.")
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func previewTitle(_ variant: PreviewVariantManifest) -> String {
        guard let summary = variant.candidateSummary,
              let title = summary.components(separatedBy: " — ").first,
              !title.isEmpty else {
            return variant.strength.rawValue.capitalized
        }
        return title
    }
}
