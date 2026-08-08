import ProductionTutor
import SwiftUI

struct FirstMoveCardView: View {
    let answer: GeneralTutorAnswerContract
    let move: String

    var body: some View {
        Card(style: .firstMove) {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
            Text("TRY THIS FIRST")
                .font(Theme.Font.section)
                .foregroundStyle(Theme.Colors.text)
                Text(move).font(Theme.Font.body)
                if !answer.whatToListenFor.isEmpty {
                    Label(answer.whatToListenFor.prefix(2).joined(separator: " "), systemImage: "ear")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                if let stop = answer.stopConditions.first {
                    Label("Stop when: \(stop)", systemImage: "hand.raised.circle")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
    }
}
