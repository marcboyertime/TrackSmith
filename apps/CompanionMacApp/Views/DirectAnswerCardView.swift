import ProductionTutor
import SwiftUI

struct DirectAnswerCardView: View {
    let answer: GeneralTutorAnswerContract

    var body: some View {
        Card(style: .directAnswer) {
            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                Text(answer.directAnswer)
                    .font(Theme.Font.body)
                    .textSelection(.enabled)
                if !answer.assumptions.isEmpty {
                    DisclosureGroup("What I am assuming") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                            ForEach(answer.assumptions, id: \.self) { assumption in
                                Text("• " + assumption)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(Theme.Font.caption)
                }
            }
        }
    }
}
