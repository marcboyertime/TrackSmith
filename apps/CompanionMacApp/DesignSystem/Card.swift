import SwiftUI

enum CardStyle {
    case directAnswer
    case clarification
    case unsupported
    case firstMove
    case strategy
    case hypothesis
    case contradiction
}

struct Card<Content: View>: View {
    let style: CardStyle
    @ViewBuilder let content: () -> Content

    init(style: CardStyle, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        switch style {
        case .directAnswer:
            content()
                .padding(Theme.Spacing.twelve)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        case .clarification:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        case .unsupported:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        case .firstMove:
            content()
                .padding(Theme.Spacing.twelve)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        case .strategy:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        case .hypothesis:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        case .contradiction:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
    }
}
