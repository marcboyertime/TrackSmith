import ProductionTutor
import SwiftUI

struct SourceRowView: View {
    let id: String
    let outcome: GeneralTutorOutcome

    @ViewBuilder
    var body: some View {
        if let source = outcome.retrieved.claims.first(where: { $0.sourceID == id }) {
            Text("• \(id) — \(evidenceLabel(source.evidenceClass))")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
        } else {
            Text("• \(id)").font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
        }
    }
}
