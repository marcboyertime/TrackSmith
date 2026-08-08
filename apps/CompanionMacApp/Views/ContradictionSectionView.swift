import ProductionTutor
import SwiftUI

struct ContradictionSectionView: View {
    let answer: GeneralTutorAnswerContract

    var body: some View {
        Card(style: .contradiction) {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
                Label("Credible sources disagree", systemImage: "exclamationmark.bubble")
                    .font(Theme.Font.section)
                ForEach(answer.contradictionDisclosures, id: \.self) { disclosure in
                    Text(disclosure).font(Theme.Font.meta).foregroundStyle(.secondary)
                }
            }
        }
    }
}
