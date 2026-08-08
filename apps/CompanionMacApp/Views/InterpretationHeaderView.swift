import ProductionTutor
import SwiftUI

struct InterpretationHeaderView: View {
    let answer: GeneralTutorAnswerContract

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(kindLabel(answer.questionKind).uppercased())
                .font(Theme.Font.section)
                .foregroundStyle(.tint)
            if !answer.domains.isEmpty {
                Text(answer.domains.prefix(3).map(domainLabel).joined(separator: " · "))
                    .font(Theme.Font.meta)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(confidenceLabel(answer.confidenceClass))
                .font(Theme.Font.meta)
                .foregroundStyle(.secondary)
        }
    }
}
