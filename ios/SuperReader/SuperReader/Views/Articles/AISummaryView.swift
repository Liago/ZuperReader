import SwiftUI

/// AI summary sheet of the reader, in the app's design system: themed page,
/// summary rendered as readable Markdown (see `SummaryMarkdownView`), text
/// size control, segmented length/format pickers and an accent Generate button.
struct AISummaryView: View {
    let article: Article
    let fontFamily: Typography.FontFamily
    let onGenerate: (String, String) -> Void // Passes length and format
    let isGenerating: Bool
    let error: String?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLength: SummaryLength = .medium
    @State private var selectedFormat: SummaryFormat = .summary
    /// Remembered between openings
    @AppStorage("aiSummaryFontSize") private var fontSize: Double = 17

    private let minFontSize: Double = 14
    private let maxFontSize: Double = 26

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metaRow

                    if let summary = article.aiSummary, !summary.isEmpty {
                        SummaryMarkdownView(
                            markdown: summary,
                            fontFamily: fontFamily,
                            fontSize: CGFloat(fontSize),
                            colors: themeManager.colors
                        )
                        .padding(18)
                        .background(themeManager.colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(themeManager.colors.line, lineWidth: 1)
                        )
                        .opacity(isGenerating ? 0.5 : 1)
                    } else if !isGenerating {
                        emptyState
                    }

                    if isGenerating {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Generating summary…")
                                .font(Typography.figtree(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundColor(themeManager.colors.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(Typography.figtree(13, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.accent800)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeManager.colors.accent200.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    optionsCard

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Powered by Cohere AI")
                    }
                    .font(Typography.figtree(11.5, relativeTo: .caption2))
                    .foregroundColor(themeManager.colors.muted)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(themeManager.colors.page.ignoresSafeArea())
            .navigationTitle("AI Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Meta (date + text size)

    private var metaRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(Typography.symbol(14, weight: .semibold))
                    .foregroundColor(themeManager.colors.page)
                    .frame(width: 30, height: 30)
                    .background(themeManager.colors.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(article.title)
                        .font(Typography.figtree(13.5, weight: .bold, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.text)
                        .lineLimit(1)
                    if let generated = generatedLabel {
                        Text(generated)
                            .font(Typography.figtree(12, relativeTo: .caption))
                            .foregroundColor(themeManager.colors.muted)
                    }
                }
            }

            Spacer(minLength: 0)

            if article.aiSummary != nil {
                textSizeControl
            }
        }
    }

    private var textSizeControl: some View {
        HStack(spacing: 0) {
            Button(action: { fontSize = max(minFontSize, fontSize - 1.5) }) {
                Text("A−")
                    .font(Typography.figtree(13, weight: .bold))
                    .frame(width: 40, height: 34)
                    .contentShape(Rectangle())
            }
            .disabled(fontSize <= minFontSize)
            .accessibilityLabel("Decrease text size")

            Rectangle().fill(themeManager.colors.line).frame(width: 1, height: 18)

            Button(action: { fontSize = min(maxFontSize, fontSize + 1.5) }) {
                Text("A+")
                    .font(Typography.figtree(17, weight: .bold))
                    .frame(width: 40, height: 34)
                    .contentShape(Rectangle())
            }
            .disabled(fontSize >= maxFontSize)
            .accessibilityLabel("Increase text size")
        }
        .buttonStyle(.plain)
        .foregroundColor(themeManager.colors.text)
        .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(Typography.symbol(28))
                .foregroundColor(themeManager.colors.accent.opacity(0.7))
                .frame(width: 64, height: 64)
                .background(themeManager.colors.surface)
                .clipShape(Circle())
            Text("No summary yet")
                .font(Typography.caprasimo(21, relativeTo: .title3))
                .foregroundColor(themeManager.colors.text)
            Text("Choose length and format, then tap Generate. The summary is kept with the article.")
                .font(Typography.figtree(13.5, relativeTo: .footnote))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    // MARK: - Options + Generate

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            optionLabel("LENGTH")
            Picker("Length", selection: $selectedLength) {
                ForEach(SummaryLength.allCases) { length in
                    Text(length.label).tag(length)
                }
            }
            .pickerStyle(.segmented)

            optionLabel("FORMAT")
            Picker("Format", selection: $selectedFormat) {
                ForEach(SummaryFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Button(action: { onGenerate(selectedLength.rawValue, selectedFormat.rawValue) }) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(themeManager.colors.page)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(article.aiSummary == nil ? "Generate" : "Regenerate")
                }
                .font(Typography.caprasimo(16, relativeTo: .headline))
                .foregroundColor(themeManager.colors.page)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(themeManager.colors.accent)
                .clipShape(Capsule())
                .opacity(isGenerating ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
            .padding(.top, 4)
        }
        .disabled(isGenerating)
        .padding(16)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    private func optionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.figtree(11, weight: .bold, relativeTo: .caption2))
            .tracking(1.2)
            .foregroundColor(themeManager.colors.muted)
    }

    // MARK: - Helpers

    private var generatedLabel: String? {
        guard let date = PublicLinkValidity.parseDate(article.aiSummaryGeneratedAt) else { return nil }
        return "Generated \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

// MARK: - Options

enum SummaryLength: String, CaseIterable, Identifiable {
    case short, medium, long
    var id: String { rawValue }
    var label: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        }
    }
}

enum SummaryFormat: String, CaseIterable, Identifiable {
    case summary
    case bullet
    var id: String { rawValue }
    var label: String {
        switch self {
        case .summary: return "Summary"
        case .bullet: return "Bullet points"
        }
    }
}
