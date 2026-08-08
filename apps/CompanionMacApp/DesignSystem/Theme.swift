import ProductionTutor
import SwiftUI

enum Theme {
    enum Spacing {
        static let four: CGFloat = 4
        static let eight: CGFloat = 8
        static let twelve: CGFloat = 12
        static let sixteen: CGFloat = 16
        static let twentyFour: CGFloat = 24

        static let legacy2: CGFloat = 2
        static let legacy3: CGFloat = 3
        static let legacy5: CGFloat = 5
        static let legacy6: CGFloat = 6
        static let legacy7: CGFloat = 7
        static let legacy9: CGFloat = 9
        static let legacy10: CGFloat = 10
        static let legacy14: CGFloat = 14
        static let legacy18: CGFloat = 18
        static let legacy22: CGFloat = 22
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
    }

    enum Colors {
        static let evidenceAudioCurrent = SwiftUI.Color.green
        static let evidenceAudioHistorical = SwiftUI.Color.orange
        static let evidenceAvailable = SwiftUI.Color.green
        static let evidenceUnavailable = SwiftUI.Color.orange

        static let hypothesisOpen = SwiftUI.Color.secondary
        static let hypothesisStrengthened = SwiftUI.Color.green
        static let hypothesisWeakened = SwiftUI.Color.orange
        static let hypothesisContraindicated = SwiftUI.Color.red

        static let feedbackBetter = SwiftUI.Color.green
        static let feedbackWorse = SwiftUI.Color.red
        static let feedbackUndo = SwiftUI.Color.orange
        static let feedbackDefault = SwiftUI.Color.accentColor

        static func hypothesisColor(for status: TutorHypothesisStatus) -> SwiftUI.Color {
            switch status {
            case .open: hypothesisOpen
            case .strengthened: hypothesisStrengthened
            case .weakened: hypothesisWeakened
            case .contraindicated: hypothesisContraindicated
            }
        }

        static func feedbackTint(for feedback: TutorFeedback) -> SwiftUI.Color {
            switch feedback {
            case .better: feedbackBetter
            case .worse: feedbackWorse
            case .undo: feedbackUndo
            default: feedbackDefault
            }
        }
    }

    enum Font {
        static let display: SwiftUI.Font = .system(size: 20, weight: .semibold)
        static let section: SwiftUI.Font = .system(size: 13, weight: .semibold)
        static let body: SwiftUI.Font = .system(size: 16, weight: .regular)
        static let meta: SwiftUI.Font = .system(size: 11, weight: .regular)
        static let data: SwiftUI.Font = .system(size: 11, weight: .regular, design: .monospaced)
    }
}
