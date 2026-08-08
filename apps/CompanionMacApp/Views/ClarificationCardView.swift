import SwiftUI

struct ClarificationCardView: View {
    let question: String

    var body: some View {
        Card(style: .clarification) {
            Label(question, systemImage: "questionmark.circle")
                .font(Theme.Font.body)
        }
    }
}
