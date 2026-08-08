import ProductionTutor
import SwiftUI

struct InterpretationHeaderView: View {
    let answer: GeneralTutorAnswerContract

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(kindLabel(answer.questionKind).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            if !answer.domains.isEmpty {
                Text(answer.domains.prefix(3).map(domainLabel).joined(separator: " · "))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(confidenceLabel(answer.confidenceClass))
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}
