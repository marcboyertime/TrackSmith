import ProductionTutor
import SwiftUI

struct EvidenceFooterView: View {
    let answer: GeneralTutorAnswerContract
    let outcome: GeneralTutorOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
            // The audio-honesty statement: says exactly what the capture did
            // or did not contribute.
            Label(answer.audioInfluence.statement, systemImage: "waveform.badge.magnifyingglass")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
            if !answer.sourceIDs.isEmpty {
                DisclosureGroup("Sources (\(answer.sourceIDs.count))") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                        ForEach(answer.sourceIDs, id: \.self) { id in
                            SourceRowView(id: id, outcome: outcome)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(Theme.Font.meta)
            }
            if let principle = answer.teachingPrinciple {
                Label(principle, systemImage: "graduationcap")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            if answer.listeningRemainsDecisive {
                Text("Listening remains decisive. None of this proves a cause.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }
}
