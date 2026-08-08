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
                .instrumentSurface()
        case .clarification:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.clarificationSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.hairline, lineWidth: 1))
        case .unsupported:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.warningSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.hairline, lineWidth: 1))
        case .firstMove:
            content()
                .padding(Theme.Spacing.twelve)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.accentSubtle, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.hairline, lineWidth: 1))
        case .strategy:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .instrumentSurface()
        case .hypothesis:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .instrumentSurface()
        case .contradiction:
            content()
                .padding(Theme.Spacing.legacy10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.contradictionSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.hairline, lineWidth: 1))
        }
    }
}
