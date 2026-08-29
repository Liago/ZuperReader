import SwiftUI
import Supabase

// MARK: - Save a Link Sheet (09)

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

    private var errorColor: Color { Color(hex: "#C0392B") }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(themeManager.colors.line)
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                    urlField
                    helperLine

                    if let result = parseResult {
                        previewCard(result)
                        tagsSection
                    } else if isLoading {
                        previewSkeleton
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }

            saveButton
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
        }
        .background(themeManager.colors.card)
        .cornerRadius(CornerRadius.sheet, corners: [.topLeft, .topRight])
        .onAppear { pasteFromClipboardIfPossible() }
        .onChange(of: url) { _, newValue in handleUrlChange(newValue) }
        .onDisappear { parseTask?.cancel() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Save a link")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .frame(width: 34, height: 34)
                    .background(themeManager.colors.sink)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - URL Field

    private var urlField: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundColor(errorMessage != nil ? errorColor : themeManager.colors.accent)

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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(themeManager.colors.card)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(errorMessage != nil ? errorColor : themeManager.colors.accent, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var helperLine: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(Typography.figtree(12.5))
                .foregroundColor(errorColor)
        } else if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .tint(themeManager.colors.accent)
                Text("Fetching article…")
            }
            .font(Typography.figtree(12.5))
            .foregroundColor(themeManager.colors.muted)
        } else if pastedFromClipboard {
            Text("Pasted from clipboard")
                .font(Typography.figtree(12.5))
                .foregroundColor(themeManager.colors.muted)
        }
    }

    // MARK: - Preview Card

    private func previewCard(_ result: ParseResult) -> some View {
        HStack(spacing: 14) {
            Group {
                if let imageUrl = result.leadImageUrl {
                    AsyncImageView(url: imageUrl, cornerRadius: 14)
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        themeManager.colors.accent200
                        Image(systemName: "doc.text.image")
                            .foregroundColor(themeManager.colors.accent800.opacity(0.6))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .frame(width: 56, height: 56)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title ?? "Untitled")
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(2)
                Text(previewMeta(result))
                    .font(Typography.meta)
                    .foregroundColor(themeManager.colors.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(themeManager.colors.sink)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func previewMeta(_ result: ParseResult) -> String {
        var parts: [String] = []
        if let domain = result.domain {
            parts.append(domain.replacingOccurrences(of: "www.", with: ""))
        }
        if let wordCount = result.wordCount {
            parts.append("\(Int(ceil(Double(wordCount) / 200.0))) min read")
        }
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
        .padding(16)
        .background(themeManager.colors.sink)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(Typography.sectionLabel)
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)

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
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .font(Typography.figtree(13.5, weight: .semibold))
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
                .font(Typography.figtree(13.5, weight: .semibold))
                .foregroundColor(themeManager.colors.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule().strokeBorder(themeManager.colors.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: { Task { await saveArticle() } }) {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(themeManager.colors.page)
                } else {
                    Text("Save article")
                        .font(Typography.caprasimo(16))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(themeManager.colors.page)
            .padding(.vertical, 16)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
            .opacity(parseResult == nil ? 0.5 : 1)
        }
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
            _ = try await SupabaseService.shared.saveArticle(parsedData: result, userId: userId, tags: acceptedTags)
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
