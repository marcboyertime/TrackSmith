import SwiftUI

enum InstrumentSurfaceLevel {
    case card
    case raised

    var color: Color {
        switch self {
        case .card: Theme.Colors.card
        case .raised: Theme.Colors.raised
        }
    }
}

struct InstrumentSurface: ViewModifier {
    let level: InstrumentSurfaceLevel
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(level.color, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func instrumentSurface(
        _ level: InstrumentSurfaceLevel = .card,
        radius: CGFloat = Theme.Radius.small
    ) -> some View {
        modifier(InstrumentSurface(level: level, radius: radius))
    }
}

struct InstrumentGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            configuration.label
                .font(Theme.Font.section)
            configuration.content
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(radius: Theme.Radius.medium)
    }
}
