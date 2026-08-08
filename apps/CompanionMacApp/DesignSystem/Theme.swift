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
        static let canvas = SwiftUI.Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
        static let card = SwiftUI.Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255)
        static let raised = SwiftUI.Color(red: 34 / 255, green: 34 / 255, blue: 36 / 255)
        static let control = SwiftUI.Color(red: 42 / 255, green: 42 / 255, blue: 45 / 255)
        static let hairline = SwiftUI.Color.white.opacity(0.13)
        static let accent = SwiftUI.Color(red: 111 / 255, green: 66 / 255, blue: 179 / 255)
        static let accentSelection = accent.opacity(0.24)
        static let accentSubtle = accent.opacity(0.14)
        static let text = SwiftUI.Color(red: 236 / 255, green: 239 / 255, blue: 243 / 255)
        static let secondaryText = SwiftUI.Color(red: 181 / 255, green: 185 / 255, blue: 194 / 255)
        static let mutedText = SwiftUI.Color(red: 137 / 255, green: 142 / 255, blue: 152 / 255)
        static let warningSurface = SwiftUI.Color.orange.opacity(0.12)
        static let clarificationSurface = SwiftUI.Color.yellow.opacity(0.12)
        static let contradictionSurface = SwiftUI.Color.purple.opacity(0.10)

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
        static let feedbackDefault = accent

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
