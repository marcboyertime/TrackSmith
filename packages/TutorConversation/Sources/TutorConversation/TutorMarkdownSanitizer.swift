import Foundation

/// Makes provider-authored Markdown safe to render as local, selectable text.
///
/// This deliberately preserves human-readable labels and ordinary Markdown
/// styling while removing every transport target.  The caller must still clear
/// `.link` attributes after parsing because Markdown parsers can recognise
/// malformed or future link syntax that this small pre-pass does not know.
public enum TutorMarkdownSanitizer {
    public static let maximumSourceBytes = 24_576

    public static func sanitize(_ source: String) -> String {
        let bounded = String(decoding: source.utf8.prefix(maximumSourceBytes), as: UTF8.self)
        return neutralizeBareTransport(stripMarkdownTargets(stripHTMLAndAutolinks(bounded)))
    }

    /// Parses the allowed inline styling and then removes every parser-created
    /// link attribute.  Views use this instead of handing provider prose to a
    /// Markdown parser directly.
    public static func inertInlineAttributedText(_ source: String) -> AttributedString {
        var parsed = (try? AttributedString(
            markdown: sanitize(source),
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(sanitize(source))
        for run in parsed.runs where run.link != nil {
            parsed[run.range].link = nil
        }
        return parsed
    }

    /// `[visible label](destination)` and `![alt](destination)` become their
    /// visible label.  Balanced destinations support ordinary nested
    /// parentheses; malformed forms remain harmless and are neutralized by the
    /// bare-transport pass below.
    private static func stripMarkdownTargets(_ source: String) -> String {
        let characters = Array(source)
        var output = ""
        var index = 0

        while index < characters.count {
            var labelStart = index
            if characters[index] == "!", index + 1 < characters.count, characters[index + 1] == "[" {
                labelStart = index + 1
            }
            guard characters[labelStart] == "[",
                  let closeBracket = matchingBracket(in: characters, from: labelStart),
                  closeBracket + 1 < characters.count,
                  characters[closeBracket + 1] == "(",
                  let closeParen = matchingParen(in: characters, from: closeBracket + 1)
            else {
                output.append(characters[index])
                index += 1
                continue
            }

            output.append(contentsOf: characters[(labelStart + 1)..<closeBracket])
            index = closeParen + 1
        }
        return output
    }

    private static func matchingBracket(in characters: [Character], from start: Int) -> Int? {
        var escaped = false
        var index = start + 1
        while index < characters.count {
            let character = characters[index]
            if escaped { escaped = false }
            else if character == "\\" { escaped = true }
            else if character == "]" { return index }
            index += 1
        }
        return nil
    }

    private static func matchingParen(in characters: [Character], from start: Int) -> Int? {
        var depth = 0
        var escaped = false
        var index = start
        while index < characters.count {
            let character = characters[index]
            if escaped { escaped = false }
            else if character == "\\" { escaped = true }
            else if character == "(" { depth += 1 }
            else if character == ")" {
                depth -= 1
                if depth == 0 { return index }
            }
            index += 1
        }
        return nil
    }

    private static func stripHTMLAndAutolinks(_ source: String) -> String {
        // Tags and angle-bracket autolinks are both deliberately inert.  A
        // textual URL outside brackets is handled separately below.
        source.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
    }

    private static func neutralizeBareTransport(_ source: String) -> String {
        // Include arbitrary URI schemes, `www`, and case variants.  The parser
        // must not get an opportunity to turn a target into a link attribute.
        source.replacingOccurrences(
            of: #"(?i)\b(?:[a-z][a-z0-9+.-]*:|www\.)[^\s<>()\[\]]+"#,
            with: "[link blocked]",
            options: .regularExpression
        )
    }
}
