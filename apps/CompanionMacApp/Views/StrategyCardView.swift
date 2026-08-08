import ProductionTutor
import SwiftUI

struct StrategyCardView: View {
    let option: GeneralStrategyOption
    let isBest: Bool
    let depth: TutorExplanationDepth
    let startExperiment: ((String) -> Void)?

    var body: some View {
        Card(style: .strategy) {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
                HStack {
                    Text(option.label).font(.callout.weight(.medium))
                    if isBest {
                        Badge("BEST FIRST", style: .bestFirst)
                    }
                    Spacer()
                }
                Text(option.simplestTest).font(Theme.Font.caption)
                if depth != .simple {
                    if !option.tradeoffs.isEmpty {
                        Label(option.tradeoffs.joined(separator: " "), systemImage: "arrow.left.arrow.right")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !option.preservationRisks.isEmpty {
                        Label(option.preservationRisks.joined(separator: " "), systemImage: "shield")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Label("Stop when: \(option.stoppingRule)", systemImage: "hand.raised.circle")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                // Only a reviewed procedure can start an exact guided experiment.
                if let procedureID = option.relatedProcedureIDs.first, let startExperiment {
                    Button("Start guided experiment") { startExperiment(procedureID) }
                        .font(Theme.Font.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }
}
