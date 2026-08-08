import SwiftUI

/// Bullet list that collapses exact duplicates and sorts alphabetically.
/// The name is deliberately explicit: callers that need source order or
/// repeated entries preserved must not use this view.
struct SortedUniqueBulletsView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            ForEach(Array(Set(items)).sorted(), id: \.self) { item in
                Text("• " + item).font(Theme.Font.meta).foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
