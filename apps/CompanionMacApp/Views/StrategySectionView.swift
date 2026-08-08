import ProductionTutor
import SwiftUI

struct StrategySectionView: View {
    let answer: GeneralTutorAnswerContract
    let depth: TutorExplanationDepth
    let startExperiment: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            Text("Ways to approach it")
                .font(.subheadline.weight(.semibold))
            ForEach(Array(answer.strategyOptions.enumerated()), id: \.offset) { index, option in
                StrategyCardView(
                    option: option,
                    isBest: index == 0,
                    depth: depth,
                    startExperiment: startExperiment
                )
            }
        }
    }
}
