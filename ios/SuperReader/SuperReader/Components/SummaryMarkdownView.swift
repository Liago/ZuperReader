import SwiftUI

// MARK: - Summary Markdown

/// Renders the Markdown returned by the AI summary (Cohere) as readable,
/// typographically spaced blocks instead of raw text:
/// - `# … ######` headings and lines fully wrapped in `**…**` / `***…***` → headings
/// - `-`, `*`, `•`, `+` items → bullets; `1.` / `1)` → numbered items
/// - `---`, `***`, `……` lines → dividers; `>` → quotes
/// - inline `**bold**`, `*italic*`, `` `code` `` and links via AttributedString
/// - blank lines separate paragraphs; single line breaks are kept.
struct SummaryMarkdownView: View {
    let markdown: String
    let fontFamily: Typography.FontFamily
    let fontSize: CGFloat
    let colors: ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.85) {
            ForEach(Array(SummaryMarkdownParser.parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: SummaryMarkdownParser.Block) -> some View {
        switch block {
        case .heading(let text, let level):
            Text(Self.inline(text))
                .font(Typography.figtree(fontSize * (level <= 2 ? 1.25 : 1.1), weight: .bold, relativeTo: .headline))
                .foregroundColor(colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, fontSize * 0.35)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            Text(Self.inline(text))
                .font(fontFamily.font(size: fontSize))
                .foregroundColor(colors.text)
                .lineSpacing(fontSize * 0.45)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet(let text, let indent):
            listItem(marker: "•", text: text, indent: indent)

        case .numbered(let number, let text, let indent):
            listItem(marker: "\(number).", text: text, indent: indent)

        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.accent2)
                    .frame(width: 3)
                Text(Self.inline(text))
                    .font(fontFamily.font(size: fontSize))
                    .italic()
                    .foregroundColor(colors.muted)
                    .lineSpacing(fontSize * 0.4)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .divider:
            Rectangle()
                .fill(colors.line)
                .frame(height: 1)
                .padding(.vertical, fontSize * 0.2)
        }
    }

    private func listItem(marker: String, text: String, indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker)
                .font(Typography.figtree(fontSize, weight: .bold))
                .foregroundColor(colors.accent)
                .frame(minWidth: fontSize * 0.9, alignment: .leading)
            Text(Self.inline(text))
                .font(fontFamily.font(size: fontSize))
                .foregroundColor(colors.text)
                .lineSpacing(fontSize * 0.4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, CGFloat(indent) * fontSize)
    }

    /// Inline Markdown (bold, italic, code, links), keeping line breaks.
    /// Falls back to the text without stray markers if parsing fails.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return attributed
        }
        return AttributedString(text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: ""))
    }
}

// MARK: - Parser

enum SummaryMarkdownParser {
    enum Block: Equatable {
        case heading(String, level: Int)
        case paragraph(String)
        case bullet(String, indent: Int)
        case numbered(Int, String, indent: Int)
        case quote(String)
        case divider
    }

    static func parse(_ raw: String) -> [Block] {
        // Some providers return escaped newlines: normalise them first
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")

        var blocks: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }

        for rawLine in text.components(separatedBy: "\n") {
            let indent = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count / 2
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                continue
            }

            // Divider: ---, ***, ___, ……… or ......
            if isDivider(line) {
                flushParagraph()
                if blocks.last != .divider { blocks.append(.divider) }
                continue
            }

            // # Heading
            if let match = line.firstMatch(of: #/^(#{1,6})\s+(.+?)\s*#*$/#) {
                flushParagraph()
                blocks.append(.heading(stripWrapping(String(match.2)), level: match.1.count))
                continue
            }

            // **Heading** / ***Heading*** / __Heading__ alone on a line (optionally ending with ':')
            if let heading = boldOnlyLine(line) {
                flushParagraph()
                blocks.append(.heading(heading, level: 3))
                continue
            }

            // - bullet, * bullet, • bullet, + bullet
            if let match = line.firstMatch(of: #/^[-*•+]\s+(.+)$/#) {
                flushParagraph()
                blocks.append(.bullet(String(match.1), indent: indent))
                continue
            }

            // 1. numbered / 1) numbered
            if let match = line.firstMatch(of: #/^(\d{1,3})[.)]\s+(.+)$/#) {
                flushParagraph()
                blocks.append(.numbered(Int(match.1) ?? 1, String(match.2), indent: indent))
                continue
            }

            // > quote
            if let match = line.firstMatch(of: #/^>\s?(.*)$/#) {
                flushParagraph()
                blocks.append(.quote(String(match.1)))
                continue
            }

            paragraph.append(line)
        }
        flushParagraph()

        // Drop leading/trailing dividers
        while blocks.first == .divider { blocks.removeFirst() }
        while blocks.last == .divider { blocks.removeLast() }
        return blocks
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { "-*_".contains($0) } && Set(compact).count == 1
            || compact.allSatisfy { $0 == "…" || $0 == "." }
    }

    /// Returns the heading text when the whole line is bold, e.g. `**Title**`, `***Title***`, `**Title:**`.
    private static func boldOnlyLine(_ line: String) -> String? {
        guard let match = line.firstMatch(of: #/^(\*{2,3}|_{2,3})(.+?)\1:?$/#) else { return nil }
        let inner = String(match.2).trimmingCharacters(in: CharacterSet(charactersIn: " *_:"))
        // Long bold sentences are emphasis, not headings
        guard !inner.isEmpty, inner.count <= 90 else { return nil }
        return inner
    }

    /// Removes bold/italic markers wrapping a whole heading (`## **Title**` → `Title`).
    private static func stripWrapping(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: " *_"))
    }
}

#Preview {
    ScrollView {
        SummaryMarkdownView(
            markdown: """
            ***Introduzione***
            Suno ha lanciato una **nuova funzione** che genera *parlato*.
            Seconda riga dello stesso paragrafo.

            ## Punti chiave
            - Voci diverse per ogni stile
            - Disponibile per gli abbonati
              - Anche in italiano
            1. Primo passo
            2. Secondo passo
            ---
            > Una citazione
            """,
            fontFamily: .figtree,
            fontSize: 17,
            colors: ThemeManager.shared.colors
        )
        .padding()
    }
}
