import SwiftUI

struct VocalSectionHeader: View {
    let index: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.eight) {
            Text(index)
                .font(Theme.Font.meta.weight(.bold))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 24, height: 24)
                .background(Theme.Colors.accentSelection, in: Circle())
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                Text(title)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.Colors.text)
                Text(detail)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }
}

struct VocalTag: View {
    let text: String
    var accent = false

    var body: some View {
        Text(text)
            .font(Theme.Font.meta.weight(accent ? .semibold : .regular))
            .foregroundStyle(Theme.Colors.text)
            .padding(.horizontal, Theme.Spacing.legacy7)
            .padding(.vertical, Theme.Spacing.legacy3)
            .background(accent ? Theme.Colors.accentSelection : Theme.Colors.raised, in: Capsule())
    }
}

struct VocalBulletList: View {
    let items: [String]
    var limit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            ForEach(Array(items.prefix(limit ?? items.count).enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: Theme.Spacing.legacy6) {
                    Text("•")
                        .foregroundStyle(Theme.Colors.accent)
                    Text(item)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct VocalHonestyNote: View {
    let text: String
    var systemImage = "info.circle"

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(Theme.Font.meta)
            .foregroundStyle(Theme.Colors.secondaryText)
            .padding(Theme.Spacing.eight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.accentSubtle, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}

struct VocalEmptyHypothesisSlot: View {
    let number: Int
    let kind: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            HStack {
                VocalTag(text: "\(kind) \(number)")
                Spacer()
                Text("AWAITING TYPED DATA")
                    .font(Theme.Font.meta.weight(.semibold))
                    .foregroundStyle(Theme.Colors.mutedText)
            }
            Text("No hypothesis has been supplied for this slot.")
                .font(Theme.Font.section)
            Text("Nothing has been rendered, auditioned, preferred, or applied.")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised)
    }
}
