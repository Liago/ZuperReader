import SwiftUI
import Supabase
import Auth

// MARK: - Save a Link Sheet
//
// Editorial Teal (design canvas · "11 · Salva link"): Cancel / title header,
// a "Link" field, the parsed article as a bordered preview, tags, an
// "Add to Up next" switch and the "Save to library" pill.

struct AddArticleSheet: View {
    let onArticleAdded: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var url = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var parseResult: ParseResult?
    @State private var pastedFromClipboard = false
    @State private var suppressClipboardFlagClear = false
    @State private var parseTask: Task<Void, Never>?

    @State private var acceptedTags: [String] = []
    @State private var suggestedTags: [String] = []
    @State private var addToQueue = false

    private var errorColor: Color { Color(hex: "#B42318") }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(themeManager.colors.line)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                    urlField
                    helperLine

                    if let result = parseResult {
                        previewCard(result)
                        tagsSection
                        upNextRow
                    } else if isLoading {
                        previewSkeleton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }

            saveButton
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
        }
        .background(themeManager.colors.page)
        .onAppear { pasteFromClipboardIfPossible() }
        .onChange(of: url) { _, newValue in handleUrlChange(newValue) }
        .onDisappear { parseTask?.cancel() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Save a link")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(Typography.ui(15))
                    .foregroundColor(themeManager.colors.muted)
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                Spacer()
            }
        }
    }

    // MARK: - URL Field

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Link")
                .font(Typography.fieldLabel)
                .foregroundColor(themeManager.colors.accent2)

        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundColor(errorMessage != nil ? errorColor : themeManager.colors.accent)
                .accessibilityHidden(true)

            TextField(
                "",
                text: $url,
                prompt: Text("https://example.com/article").foregroundColor(themeManager.colors.muted)
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.URL)
            .foregroundColor(themeManager.colors.text)
            .accessibilityLabel("Link to save")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(themeManager.colors.page)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(errorMessage != nil ? errorColor : themeManager.colors.accent, lineWidth: 1.5)
        )
        }
    }

    @ViewBuilder
    private var helperLine: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(Typography.ui(12.5))
                .foregroundColor(errorColor)
        } else if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .tint(themeManager.colors.accent)
                Text("Fetching article…")
            }
            .font(Typography.ui(12.5))
            .foregroundColor(themeManager.colors.muted)
        } else if pastedFromClipboard {
            Text("Pasted from clipboard")
                .font(Typography.ui(12.5))
                .foregroundColor(themeManager.colors.muted)
        }
    }

    // MARK: - Preview Card

    private func previewCard(_ result: ParseResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let imageUrl = result.leadImageUrl {
                    AsyncImageView(url: imageUrl, cornerRadius: 12)
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        themeManager.colors.surface
                        Image(systemName: "doc.text.image")
                            .foregroundColor(themeManager.colors.muted)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if let domain = result.domain {
                    Text(domain.replacingOccurrences(of: "www.", with: ""))
                        .font(Typography.ui(12, weight: .semibold, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.accent)
                        .lineLimit(1)
                }
                Text(result.title ?? "Untitled")
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(2)
                Text(previewMeta(result))
                    .font(Typography.ui(12.5, relativeTo: .caption))
                    .foregroundColor(themeManager.colors.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    private func previewMeta(_ result: ParseResult) -> String {
        var parts: [String] = []
        if let wordCount = result.wordCount {
            parts.append("\(Int(ceil(Double(wordCount) / 200.0))) min read")
        }
        parts.append("readable version ready")
        return parts.joined(separator: " · ")
    }

    private var previewSkeleton: some View {
        HStack(spacing: 14) {
            SkeletonView(width: 56, height: 56, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 16)
                SkeletonView(width: 140, height: 14)
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(Typography.fieldLabel)
                .foregroundColor(themeManager.colors.accent2)

            FlowLayout(spacing: 8) {
                ForEach(acceptedTags, id: \.self) { tag in
                    acceptedTagPill(tag)
                }
                ForEach(suggestedTags, id: \.self) { tag in
                    suggestedTagPill(tag)
                }
            }
        }
    }

    private func acceptedTagPill(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    acceptedTags.removeAll { $0 == tag }
                }
            }) {
                Image(systemName: "xmark")
                    .font(Typography.symbol(11, weight: .bold))
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove tag \(tag)")
        }
        .font(Typography.ui(13.5, weight: .semibold))
        .foregroundColor(themeManager.colors.page)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(themeManager.colors.accent)
        .clipShape(Capsule())
    }

    private func suggestedTagPill(_ tag: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                suggestedTags.removeAll { $0 == tag }
                acceptedTags.append(tag)
            }
        }) {
            Text("+ \(tag)")
                .font(Typography.ui(13.5, weight: .semibold))
                .foregroundColor(themeManager.colors.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule().strokeBorder(themeManager.colors.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add to Up next

    /// "Add to Up next" switch row in a bordered group.
    private var upNextRow: some View {
        Toggle(isOn: $addToQueue) {
            Text("Add to Up next")
                .font(Typography.ui(15))
                .foregroundColor(themeManager.colors.text)
        }
        .tint(themeManager.colors.accent)
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: { Task { await saveArticle() } }) {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(themeManager.colors.page)
                } else {
                    Text("Save to library")
                        .font(Typography.ui(16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundColor(themeManager.colors.page)
            .background(Capsule().fill(themeManager.colors.accent))
            .opacity(parseResult == nil ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(parseResult == nil || isSaving)
    }

    // MARK: - Actions

    private func pasteFromClipboardIfPossible() {
        guard url.isEmpty,
              let clipboardString = UIPasteboard.general.string,
              isPlausibleURL(clipboardString) else { return }
        suppressClipboardFlagClear = true
        pastedFromClipboard = true
        url = clipboardString
    }

    private func handleUrlChange(_ newValue: String) {
        if suppressClipboardFlagClear {
            suppressClipboardFlagClear = false
        } else {
            pastedFromClipboard = false
        }

        parseTask?.cancel()
        parseResult = nil
        errorMessage = nil
        acceptedTags = []
        suggestedTags = []

        guard isPlausibleURL(newValue) else { return }

        parseTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await parseUrl()
        }
    }

    private func isPlausibleURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return false }
        let candidate = (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")) ? trimmed : "https://\(trimmed)"
        guard let candidateURL = URL(string: candidate), let host = candidateURL.host, host.contains(".") else {
            return false
        }
        return true
    }

    private func parseUrl() async {
        isLoading = true
        errorMessage = nil

        var urlToUse = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlToUse.hasPrefix("http://") && !urlToUse.hasPrefix("https://") {
            urlToUse = "https://" + urlToUse
        }

        do {
            let result = try await ArticleParser.shared.parseUrl(urlToUse)
            parseResult = result
            suggestedTags = TagSuggestionService.suggestedTags(for: result)
        } catch {
            errorMessage = "Couldn't load this link. Check the URL and try again."
        }

        isLoading = false
    }

    private func saveArticle() async {
        guard let result = parseResult,
              let userId = authManager.user?.id.uuidString else { return }

        isSaving = true

        do {
            let saved = try await SupabaseService.shared.saveArticle(parsedData: result, userId: userId, tags: acceptedTags)
            if addToQueue {
                // Queueing is best-effort: the article is already saved, so don't fail the sheet.
                await ReadingQueueStore.shared.add(articleId: saved.id, userId: userId)
            }
            onArticleAdded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    AddArticleSheet(onArticleAdded: {})
        .environmentObject(ThemeManager.shared)
}
