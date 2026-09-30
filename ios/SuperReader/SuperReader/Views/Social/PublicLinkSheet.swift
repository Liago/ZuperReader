import SwiftUI
import UIKit

// MARK: - Public Link Sheet

/// Lets the owner turn the public web link of an article on/off, choose its
/// validity (1 day, 1 week, never), copy it and share it. Anyone with the
/// link can read the parsed article without an account (web route /p/<token>).
struct PublicLinkSheet: View {
    let articleId: String
    let articleTitle: String
    /// Called after every successful change with the new token and expiry
    /// (token nil = revoked, expiresAt nil = never expires).
    let onChange: (_ token: String?, _ expiresAt: String?) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var token: String?
    @State private var expiresAt: String?
    @State private var validity: PublicLinkValidity
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var copied = false

    init(
        articleId: String,
        articleTitle: String,
        initialToken: String?,
        initialExpiresAt: String?,
        onChange: @escaping (_ token: String?, _ expiresAt: String?) -> Void
    ) {
        self.articleId = articleId
        self.articleTitle = articleTitle
        self.onChange = onChange

        let active = PublicLinkValidity.isActive(token: initialToken, expiresAt: initialExpiresAt)
        _token = State(initialValue: active ? initialToken : nil)
        _expiresAt = State(initialValue: active ? initialExpiresAt : nil)
        // Default for a new link: 1 week
        _validity = State(initialValue: active ? PublicLinkValidity.from(expiresAt: initialExpiresAt) : .oneWeek)
    }

    private var isPublic: Bool { token != nil }

    private var publicURL: URL? {
        token.flatMap { SupabaseConfig.publicArticleURL(token: $0) }
    }

    private var isPublicBinding: Binding<Bool> {
        Binding(
            get: { isPublic },
            set: { newValue in Task { await setPublic(newValue) } }
        )
    }

    private var validityBinding: Binding<PublicLinkValidity> {
        Binding(
            get: { validity },
            set: { newValue in
                validity = newValue
                // Active link: same token, new expiry
                if isPublic { Task { await enable(copyAfter: false) } }
            }
        )
    }

    private var expiryText: String {
        guard let date = PublicLinkValidity.parseDate(expiresAt) else { return "Never expires" }
        return "Expires \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Toggle + validity card
                    VStack(alignment: .leading, spacing: 14) {
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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("VALID FOR")
                                .font(Typography.figtree(11, weight: .bold, relativeTo: .caption2))
                                .tracking(1.2)
                                .foregroundColor(themeManager.colors.muted)

                            Picker("Valid for", selection: validityBinding) {
                                ForEach(PublicLinkValidity.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(isBusy)
                        }

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

                            Label(expiryText, systemImage: expiresAt == nil ? "infinity" : "clock")
                                .font(Typography.figtree(13, weight: .semibold, relativeTo: .footnote))
                                .foregroundColor(themeManager.colors.text)

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

                            Text("Changing the validity keeps the same link. Turning it off revokes it immediately.")
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
        guard !isBusy, makePublic != isPublic else { return }
        if makePublic {
            await enable(copyAfter: false)
        } else {
            await disable()
        }
    }

    private func enable(copyAfter: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let result = try await SupabaseService.shared.enablePublicLink(articleId: articleId, validity: validity)
            token = result.token
            expiresAt = result.expiresAt
            onChange(result.token, result.expiresAt)
            if copyAfter, let url = SupabaseConfig.publicArticleURL(token: result.token) {
                copy(url)
            }
        } catch {
            errorMessage = "Could not update the public link."
            print("❌ Public link error: \(error)")
        }
    }

    private func disable() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await SupabaseService.shared.disablePublicLink(articleId: articleId)
            token = nil
            expiresAt = nil
            onChange(nil, nil)
        } catch {
            errorMessage = "Could not disable the public link."
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
