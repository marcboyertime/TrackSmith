import ProductionTutor
import SwiftUI

/// Renders a validated open-domain answer: direct answer first, then the one
/// recommended move, then alternatives and their tradeoffs, then evidence.
/// Depth follows the user's explanation setting; detail stays behind
/// disclosure so the default view is short.
struct GeneralAnswerView: View {
    let outcome: GeneralTutorOutcome
    let depth: TutorExplanationDepth
    /// Starting a guided experiment is only offered when a reviewed procedure
    /// backs the option; the closure is nil when no lesson can be started.
    var startExperiment: ((String) -> Void)?

    private var answer: GeneralTutorAnswerContract { outcome.answer }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy14) {
            InterpretationHeaderView(answer: answer)
            DirectAnswerCardView(answer: answer)
            if let clarification = answer.clarificationQuestion {
                ClarificationCardView(question: clarification)
            }
            if !answer.unsupportedCapabilities.isEmpty {
                UnsupportedCardView(answer: answer)
            }
            if let first = answer.recommendedFirstMove, answer.answerMode == .groundedAnswer {
                FirstMoveCardView(answer: answer, move: first)
            }
            if !answer.strategyOptions.isEmpty {
                StrategySectionView(answer: answer, depth: depth, startExperiment: startExperiment)
            }
            if !answer.contradictionDisclosures.isEmpty {
                ContradictionSectionView(answer: answer)
            }
            DetailDisclosuresView(answer: answer)
            EvidenceFooterView(answer: answer, outcome: outcome)
        }
    }
}
