import SwiftUI
import VocalProduction

struct VocalCaptureInterpretationsView: View {
    @ObservedObject var model: VocalWorkspaceModel
    let callbacks: VocalWorkspaceCallbacks

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            VocalSectionHeader(
                index: "2",
                title: "Three capture hypotheses",
                detail: "Inspect all three, then select one reversible test-take setup. None is called best before listening."
            )

            VStack(spacing: Theme.Spacing.eight) {
                ForEach(0..<3, id: \.self) { index in
                    if model.captureInterpretations.indices.contains(index) {
                        interpretationCard(model.captureInterpretations[index], number: index + 1)
                    } else {
                        VocalEmptyHypothesisSlot(number: index + 1, kind: "Capture")
                    }
                }
            }
        }
    }

    private func interpretationCard(
        _ interpretation: VocalCaptureInterpretation,
        number: Int
    ) -> some View {
        let selected = model.isCaptureInterpretationSelected(interpretation)
        return VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                    HStack {
                        VocalTag(text: "CAPTURE \(number)", accent: selected)
                        if selected {
                            VocalTag(text: "SELECTED", accent: true)
                        }
                    }
                    Text(interpretation.title)
                        .font(Theme.Font.body.weight(.medium))
                    Text(interpretation.hypothesis)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(selected ? "Selected" : "Select test") {
                    model.selectCaptureInterpretation(interpretation)
                    callbacks.selectCaptureInterpretation(interpretation)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
                .disabled(selected)
            }

            HStack(spacing: Theme.Spacing.eight) {
                VocalTag(text: VocalWorkspacePresentation.capturePlacement(interpretation.placement))
                VocalTag(text: VocalWorkspacePresentation.words(interpretation.roomPosition.rawValue))
                VocalTag(text: "Reflection: \(VocalWorkspacePresentation.words(interpretation.reflectionRisk.rawValue))")
            }

            DisclosureGroup("Inspect exact test and boundaries") {
                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    detail("Bounded adjustment", interpretation.placement.boundedAdjustment)
                    detail("Gain / headroom", interpretation.gainAndHeadroom.instruction)
                    detail("Monitoring", interpretation.monitoring.instruction)
                    detail("Test label", interpretation.comparison.testTakeLabel, data: true)
                    labeledBullets("Procedure", interpretation.comparison.exactProcedure)
                    labeledBullets("Hold constant", interpretation.comparison.variablesHeldConstant)
                    labeledBullets("Listen for", interpretation.comparison.listenFor)
                    labeledBullets("Stop / rollback", [interpretation.comparison.stopRule] + interpretation.comparison.rollbackInstructions)
                    if !interpretation.missingInformation.isEmpty || !interpretation.uncertainty.isEmpty {
                        labeledBullets(
                            "Unknowns",
                            interpretation.missingInformation + interpretation.uncertainty
                        )
                    }
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)
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

    private func detail(_ title: String, _ value: String, data: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
            Text(title)
                .font(Theme.Font.meta.weight(.semibold))
            Text(value)
                .font(data ? Theme.Font.data : Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private func labeledBullets(_ title: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(title).font(Theme.Font.meta.weight(.semibold))
            VocalBulletList(items: values)
        }
    }
}
