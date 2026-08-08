import ProductionTutor
import SwiftUI

struct UnsupportedCardView: View {
    let answer: GeneralTutorAnswerContract

    var body: some View {
        Card(style: .unsupported) {
            VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                ForEach(answer.unsupportedCapabilities, id: \.self) { capability in
                    Label("Not something TrackSmith does: \(capability)", systemImage: "hand.raised")
                        .font(Theme.Font.meta)
                }
            }
        }
    }
}
