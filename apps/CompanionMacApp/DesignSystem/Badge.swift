import SwiftUI

enum BadgeStyle {
    case bestFirst
    case category
}

struct Badge: View {
    let text: String
    let style: BadgeStyle

    init(_ text: String, style: BadgeStyle) {
        self.text = text
        self.style = style
    }

    @ViewBuilder
    var body: some View {
        switch style {
        case .bestFirst:
            Text(text)
                .font(Theme.Font.caption2.weight(.bold))
                .padding(.horizontal, Theme.Spacing.legacy6)
                .padding(.vertical, Theme.Spacing.legacy2)
                .background(.tint.opacity(0.2), in: Capsule())
        case .category:
            Text(text)
                .font(Theme.Font.caption)
                .padding(.horizontal, Theme.Spacing.legacy7)
                .padding(.vertical, Theme.Spacing.legacy3)
                .background(.quaternary, in: Capsule())
        }
    }
}
