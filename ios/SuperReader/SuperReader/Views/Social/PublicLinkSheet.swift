import SwiftUI
import UIKit

// MARK: - Public Link Sheet

/// Lets the owner turn the public web link of an article on/off, copy it
/// and share it. Anyone with the link can read the parsed article without
/// an account (web route /p/<token>).
struct PublicLinkSheet: View {
    let articleId: String
    let articleTitle: String
    /// Current token (nil = private).
    let initialToken: String?
    /// Called after every successful change, with the new token (nil = revoked).
    let onChange: (String?) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var token: String?
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var copied = false

    init(articleId: String, articleTitle: String, initialToken: String?, onChange: @escaping (String?) -> Void) {
        self.articleId = articleId
        self.articleTitle = articleTitle
        self.initialToken = initialToken
        self.onChange = onChange
        _token = State(initialValue: initialToken)
    }

    private var publicURL: URL? {
        token.flatMap { SupabaseConfig.publicArticleURL(token: $0) }
    }

    private var isPublicBinding: Binding<Bool> {
        Binding(
            get: { token != nil },
            set: { newValue in Task { await setPublic(newValue) } }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Toggle card
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: isPublicBinding) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Public link")
                                    .font(Typography.figtree(16, weight: .semibold, relativeTo: .headline))
                                    .foregroundColor(themeManager.colors.text)
                                Text("Anyone with the link can read the clean version of this article, without an account.")
                                    .font(Typography.figtree(13, relativeTo: .footnote))
                                    .foregroundColor(themeManager.colors.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(themeManager.colors.accent)
                        .disabled(isBusy)

                        if isBusy {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Updating…")
                                    .font(Typography.figtree(13, relativeTo: .footnote))
                                    .foregroundColor(themeManager.colors.muted)
                            }
                        }
                    }
                    .padding(16)
                    .background(themeManager.colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(themeManager.colors.line, lineWidth: 1)
                    )

                    // Link + actions
                    if let url = publicURL, !isBusy {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(url.absoluteString)
                                .font(Typography.figtree(13, relativeTo: .footnote))
                                .foregroundColor(themeManager.colors.text)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(themeManager.colors.page)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))

                            HStack(spacing: 10) {
                                Button(action: { copy(url) }) {
                                    Label(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "link")
                                        .font(Typography.figtree(14, weight: .semibold, relativeTo: .subheadline))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundColor(themeManager.colors.text)
                                        .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                ShareLink(item: url, subject: Text(articleTitle), message: Text(articleTitle)) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(Typography.figtree(14, weight: .semibold, relativeTo: .subheadline))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundColor(themeManager.colors.page)
                                        .background(themeManager.colors.accent)
                                        .clipShape(Capsule())
                                }
                            }

                            Text("Turning it off revokes the link immediately. Turning it on again creates a new one.")
                                .font(Typography.figtree(12, relativeTo: .caption))
                                .foregroundColor(themeManager.colors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.figtree(13, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.accent)
                    }
                }
                .padding(20)
            }
            .background(themeManager.colors.page.ignoresSafeArea())
            .navigationTitle("Public Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Actions

    private func setPublic(_ makePublic: Bool) async {
        guard !isBusy, makePublic != (token != nil) else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            if makePublic {
                let newToken = try await SupabaseService.shared.enablePublicLink(articleId: articleId)
                token = newToken
                onChange(newToken)
            } else {
                try await SupabaseService.shared.disablePublicLink(articleId: articleId)
                token = nil
                onChange(nil)
            }
        } catch {
            errorMessage = makePublic ? "Could not create the public link." : "Could not disable the public link."
            print("❌ Public link error: \(error)")
        }
    }

    private func copy(_ url: URL) {
        UIPasteboard.general.url = url
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }
}
