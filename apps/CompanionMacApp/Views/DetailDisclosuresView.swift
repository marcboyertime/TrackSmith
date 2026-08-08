import ProductionTutor
import SwiftUI

struct DetailDisclosuresView: View {
    let answer: GeneralTutorAnswerContract

    @ViewBuilder
    var body: some View {
        if !answer.preservationChecks.isEmpty {
            DisclosureGroup("What to preserve") {
                SortedUniqueBulletsView(items: answer.preservationChecks)
            }
            .font(Theme.Font.meta)
        }
        if !answer.risksAndSideEffects.isEmpty {
            DisclosureGroup("What could go wrong") {
                SortedUniqueBulletsView(items: answer.risksAndSideEffects)
            }
            .font(Theme.Font.meta)
        }
        if !answer.nonDSPPossibilities.isEmpty {
            DisclosureGroup("Non-processing options") {
                SortedUniqueBulletsView(items: answer.nonDSPPossibilities)
            }
            .font(Theme.Font.meta)
        }
        if !answer.currentContextLimitations.isEmpty {
            DisclosureGroup("What TrackSmith cannot see") {
                SortedUniqueBulletsView(items: answer.currentContextLimitations)
            }
            .font(Theme.Font.meta)
        }
    }
}
