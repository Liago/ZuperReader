import SwiftUI
import UIKit
import Supabase
import Auth

// MARK: - Public Links View

/// Editorial Teal (design canvas · "08 · Link pubblici"): a summary card,
/// Active / Expired tabs and one bordered card per link — thumbnail, title,
/// source and share date, an on/off switch (revoke or renew), the URL in a
/// pill with Copy and Share, and the validity menu. Presented from "You".
struct PublicLinksView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PublicLinkItem] = []
    @State private var isLoading = true
    @State private var busyIds: Set<String> = []
    @State private var copiedId: String?
    @State private var errorMessage: String?
    @State private var itemToRevoke: PublicLinkItem?
    @State private var showExpired = false

    private var activeItems: [PublicLinkItem] { items.filter(\.isActive) }
    private var expiredItems: [PublicLinkItem] { items.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.ui(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.accent800)
                    }

                    if isLoading {
                        ProgressView()
                            .tint(themeManager.colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if items.isEmpty {
                        emptyState
                    } else {
                        tabs

                        let shown = showExpired ? expiredItems : activeItems
                        if shown.isEmpty {
                            Text(showExpired ? "No expired links." : "No active links.")
                                .font(Typography.ui(14))
                                .foregroundColor(themeManager.colors.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(shown) { item in
                                    card(item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(themeManager.colors.page.ignoresSafeArea())
            .navigationTitle("Public links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(themeManager.colors.accent)
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .confirmationDialog(
                "Revoke public link?",
                isPresented: Binding(get: { itemToRevoke != nil }, set: { if !$0 { itemToRevoke = nil } }),
                titleVisibility: .visible,
                presenting: itemToRevoke
            ) { item in
                Button(item.isActive ? "Revoke" : "Remove", role: .destructive) {
                    Task { await revoke(item) }
                }
            } message: { item in
                Text("\"\(item.title)\" will no longer be readable by people who have the link.")
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 28) {
                summaryNumber(activeItems.count, label: activeItems.count == 1 ? "active link" : "active links")
                summaryNumber(expiredItems.count, label: "expired")
            }
            Text("Anyone with a link can read the article in the browser, no account needed. Changing the validity keeps the same link; turning it off revokes it at once.")
                .font(Typography.ui(13, relativeTo: .footnote))
                .lineSpacing(2)
                .foregroundColor(themeManager.colors.accent2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.colors.accent200)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryNumber(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(Typography.display(24, weight: .heavy, relativeTo: .title2))
                .foregroundColor(themeManager.colors.text)
            Text(label)
                .font(Typography.ui(12.5, relativeTo: .caption))
                .foregroundColor(themeManager.colors.accent2)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tabs

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton("Active · \(activeItems.count)", isSelected: !showExpired) { showExpired = false }
            tabButton("Expired · \(expiredItems.count)", isSelected: showExpired) { showExpired = true }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(themeManager.colors.line).frame(height: 1)
        }
    }

    private func tabButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .font(Typography.ui(14.5, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? themeManager.colors.accent : themeManager.colors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? themeManager.colors.accent : Color.clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "link")
                .font(Typography.symbol(28))
                .foregroundColor(themeManager.colors.muted)
                .frame(width: 64, height: 64)
                .background(Circle().fill(themeManager.colors.surface))
                .accessibilityHidden(true)
            Text("No public links")
                .font(Typography.ui(17, weight: .semibold, relativeTo: .headline))
                .foregroundColor(themeManager.colors.text)
            Text("Open an article and choose “Public Link” from the ••• menu to share it with anyone.")
                .font(Typography.ui(13.5, relativeTo: .footnote))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }

    // MARK: - Card

    private func card(_ item: PublicLinkItem) -> some View {
        let busy = busyIds.contains(item.id)
        let selected = PublicLinkValidity.from(expiresAt: item.publicLinkExpiresAt, storedDays: item.publicLinkValidityDays)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    themeManager.colors.surface
                    if item.imageUrl != nil {
                        AsyncImageView(url: item.imageUrl, cornerRadius: 0)
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: 48, height: 48)
                .thumbnailClip(CornerRadius.smallThumbnail)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(Typography.ui(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundColor(themeManager.colors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle(item))
                        .font(Typography.ui(12, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if busy {
                    ProgressView()
                        .tint(themeManager.colors.accent)
                        .frame(width: 51, height: 31)
                } else {
                    Toggle("", isOn: Binding(
                        get: { item.isActive },
                        set: { isOn in
                            if isOn {
                                Task { await setValidity(item, selected) }
                            } else {
                                itemToRevoke = item
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(themeManager.colors.accent)
                    .accessibilityLabel(item.isActive ? "Public link on" : "Public link off")
                }
            }

            if item.isActive, let url = item.url {
                HStack(spacing: 8) {
                    Text(url.absoluteString.replacingOccurrences(of: "https://", with: ""))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(themeManager.colors.accent2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.colors.surface))

                    Button(action: { copy(item, url: url) }) {
                        Image(systemName: copiedId == item.id ? "checkmark" : "doc.on.doc")
                            .font(Typography.symbol(15, weight: .medium))
                            .foregroundColor(copiedId == item.id ? themeManager.colors.accent : themeManager.colors.text)
                            .frame(width: 44, height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeManager.colors.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copiedId == item.id ? "Copied" : "Copy link")

                    ShareLink(item: url, subject: Text(item.title), message: Text(item.title)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(Typography.symbol(15, weight: .medium))
                            .foregroundColor(themeManager.colors.text)
                            .frame(width: 44, height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeManager.colors.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share link")
                }
            }

            HStack(spacing: 8) {
                Label(
                    PublicLinkValidity.label(storedDays: item.publicLinkValidityDays, expiresAt: item.publicLinkExpiresAt),
                    systemImage: item.publicLinkExpiresAt == nil ? "infinity" : "clock"
                )
                .font(Typography.ui(12.5, weight: .medium, relativeTo: .caption))
                .foregroundColor(themeManager.colors.text)

                if let expiry = PublicLinkValidity.parseDate(item.publicLinkExpiresAt) {
                    Text("· \(item.isActive ? "expires" : "expired") \(expiry.formatted(.relative(presentation: .named)))")
                        .font(Typography.ui(12, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Menu {
                    Section(item.isActive ? "Valid for (same link)" : "Renew for (new link)") {
                        ForEach(PublicLinkValidity.allCases) { option in
                            Button(action: { Task { await setValidity(item, option) } }) {
                                if item.isActive && option == selected {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: { itemToRevoke = item }) {
                        Label(item.isActive ? "Revoke link" : "Remove", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(Typography.symbol(15, weight: .semibold))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Validity and more")
            }
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
        .opacity(busy ? 0.6 : 1)
        .disabled(busy)
    }

    private func subtitle(_ item: PublicLinkItem) -> String {
        var parts: [String] = []
        if let domain = item.domain { parts.append(domain.replacingOccurrences(of: "www.", with: "")) }
        if let shared = PublicLinkValidity.parseDate(item.publicSharedAt) {
            parts.append("shared \(shared.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func load() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        do {
            items = try await SupabaseService.shared.getPublicLinks(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load your public links."
            print("❌ Public links error: \(error)")
        }
        isLoading = false
    }

    /// Active link: change validity (same token). Expired link: renew (new token).
    private func setValidity(_ item: PublicLinkItem, _ validity: PublicLinkValidity) async {
        busyIds.insert(item.id)
        defer { busyIds.remove(item.id) }
        errorMessage = nil

        do {
            let wasActive = item.isActive
            let result = try await SupabaseService.shared.enablePublicLink(articleId: item.id, validity: validity)
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[index].publicShareToken = result.token
            items[index].publicLinkExpiresAt = result.expiresAt
            items[index].publicLinkValidityDays = validity.days
            if !wasActive {
                items[index].publicSharedAt = ISO8601DateFormatter().string(from: Date())
            }
        } catch {
            errorMessage = "Could not update the public link."
            print("❌ Public link error: \(error)")
        }
    }

    private func revoke(_ item: PublicLinkItem) async {
        itemToRevoke = nil
        busyIds.insert(item.id)
        defer { busyIds.remove(item.id) }
        errorMessage = nil

        do {
            try await SupabaseService.shared.disablePublicLink(articleId: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Could not revoke the public link."
            print("❌ Public link error: \(error)")
        }
    }

    private func copy(_ item: PublicLinkItem, url: URL) {
        UIPasteboard.general.url = url
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        copiedId = item.id
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copiedId == item.id { copiedId = nil }
        }
    }
}
