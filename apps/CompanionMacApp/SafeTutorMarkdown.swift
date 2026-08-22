import SwiftUI
import TutorConversation

/// A deliberately small local Markdown projection for Tutor prose.  It is not
/// a web view: raw HTML, images, and links are rendered as inert plain text so
/// a provider response cannot load remote content or create an opaque control.
struct SafeTutorMarkdown: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                rendered(line)
            }
        }
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
    }

    private var lines: [String] {
        let bounded = TutorMarkdownSanitizer.sanitize(source)
        return bounded.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    @ViewBuilder private func rendered(_ original: String) -> some View {
        let line = original
        if line.hasPrefix("### ") {
            markdownText(String(line.dropFirst(4))).font(Theme.Font.meta.weight(.semibold))
        } else if line.hasPrefix("## ") {
            markdownText(String(line.dropFirst(3))).font(Theme.Font.section)
        } else if line.hasPrefix("# ") {
            markdownText(String(line.dropFirst(2))).font(Theme.Font.hero)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•").accessibilityHidden(true)
                markdownText(String(line.dropFirst(2)))
            }
        } else if let range = line.range(of: "^\\d+\\. ", options: .regularExpression) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(line[range])).accessibilityHidden(true)
                markdownText(String(line[range.upperBound...]))
            }
        } else {
            markdownText(line)
        }
    }

    private func markdownText(_ value: String) -> Text {
        // Inline-only parsing admits emphasis and inline code, while the
        // sanitizer and attribute pass make any attempted transport inert.
        var parsed = TutorMarkdownSanitizer.inertInlineAttributedText(value)
        // This is deliberately redundant with TutorMarkdownSanitizer.  It
        // protects against parser-recognised link spellings (including future
        // Markdown syntax) without removing readable text, styling, selection,
        // or VoiceOver content semantics.
        for run in parsed.runs where run.link != nil {
            parsed[run.range].link = nil
        }
        return Text(parsed).font(Theme.Font.body).foregroundStyle(Theme.Colors.text)
    }
}
