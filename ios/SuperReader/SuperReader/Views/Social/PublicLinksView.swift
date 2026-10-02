import SwiftUI
import UIKit
import Supabase
import Auth

// MARK: - Public Links View

/// Lists every article the user has made public, with the validity picked,
/// when the link expires and quick actions (copy, share, change validity,
/// renew, revoke). Presented from the "You" tab.
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

    private var activeItems: [PublicLinkItem] { items.filter(\.isActive) }
    private var expiredItems: [PublicLinkItem] { items.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Articles anyone can read through a link, without an account. Changing the validity keeps the same link; revoking it stops the link immediately.")
                        .font(Typography.figtree(13.5, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.figtree(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.accent)
                    }

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if items.isEmpty {
                        emptyState
                    } else {
                        if !activeItems.isEmpty {
                            section(title: "\(activeItems.count) ACTIVE", items: activeItems)
                        }
                        if !expiredItems.isEmpty {
                            section(title: "EXPIRED", items: expiredItems)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(themeManager.colors.page.ignoresSafeArea())
            .navigationTitle("Public Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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

    // MARK: - Sections

    private func section(title: String, items: [PublicLinkItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typography.figtree(11, weight: .bold, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundColor(themeManager.colors.muted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    row(item)
                    if item.id != items.last?.id {
                        Rectangle().fill(themeManager.colors.line).frame(height: 1)
                    }
                }
            }
            .background(themeManager.colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(themeManager.colors.line, lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(Typography.symbol(30))
                .foregroundColor(themeManager.colors.accent.opacity(0.6))
                .frame(width: 64, height: 64)
                .background(themeManager.colors.surface)
                .clipShape(Circle())
            Text("No public links")
                .font(Typography.caprasimo(21, relativeTo: .title3))
                .foregroundColor(themeManager.colors.text)
            Text("Open an article and choose “Public Link” from the ••• menu to share it with anyone.")
                .font(Typography.figtree(13.5, relativeTo: .footnote))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 20)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    // MARK: - Row

    private func row(_ item: PublicLinkItem) -> some View {
        let busy = busyIds.contains(item.id)
        let selected = PublicLinkValidity.from(expiresAt: item.publicLinkExpiresAt, storedDays: item.publicLinkValidityDays)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImageView(url: item.imageUrl, cornerRadius: 14)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    if let domain = item.domain {
                        Text(domain)
                            .font(Typography.figtree(12, weight: .semibold, relativeTo: .caption))
                            .foregroundColor(themeManager.colors.muted)
                    }
                    Text(item.title)
                        .font(Typography.figtree(15.5, weight: .bold, relativeTo: .subheadline))
                        .foregroundColor(themeManager.colors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    statusLine(item)
                }
                Spacer(minLength: 0)
            }

            // Actions
            HStack(spacing: 8) {
                if item.isActive, let url = item.url {
                    Button(action: { copy(item, url: url) }) {
                        Label(copiedId == item.id ? "Copied" : "Copy", systemImage: copiedId == item.id ? "checkmark" : "link")
                            .font(Typography.figtree(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.page)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(themeManager.colors.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: url, subject: Text(item.title), message: Text(item.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(Typography.figtree(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
                    }
                } else {
                    Button(action: { Task { await setValidity(item, selected) } }) {
                        Label("Renew", systemImage: "arrow.counterclockwise")
                            .font(Typography.figtree(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.page)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(themeManager.colors.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                if busy {
                    ProgressView()
                }

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
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(themeManager.colors.line, lineWidth: 1))
                        .contentShape(Circle())
                }
                .accessibilityLabel("More actions")
            }
            .disabled(busy)
        }
        .padding(16)
        .opacity(busy ? 0.6 : 1)
    }

    private func statusLine(_ item: PublicLinkItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.isActive ? "Active" : "Expired")
                    .font(Typography.figtree(11.5, weight: .bold, relativeTo: .caption2))
                    .foregroundColor(item.isActive ? themeManager.colors.text : themeManager.colors.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.isActive ? themeManager.colors.accent2_200 : themeManager.colors.surface)
                    .clipShape(Capsule())

                Label(
                    PublicLinkValidity.label(storedDays: item.publicLinkValidityDays, expiresAt: item.publicLinkExpiresAt),
                    systemImage: item.publicLinkExpiresAt == nil ? "infinity" : "clock"
                )
                .font(Typography.figtree(12.5, weight: .semibold, relativeTo: .caption))
                .foregroundColor(themeManager.colors.text)
            }
            .padding(.top, 4)

            if let expiry = PublicLinkValidity.parseDate(item.publicLinkExpiresAt) {
                Text("\(item.isActive ? "Expires" : "Expired") \(expiry.formatted(.relative(presentation: .named))) · \(expiry.formatted(date: .abbreviated, time: .shortened))")
                    .font(Typography.figtree(12, relativeTo: .caption))
                    .foregroundColor(themeManager.colors.muted)
            }
            if let shared = PublicLinkValidity.parseDate(item.publicSharedAt) {
                Text("Shared \(shared.formatted(.relative(presentation: .named)))")
                    .font(Typography.figtree(12, relativeTo: .caption))
                    .foregroundColor(themeManager.colors.muted)
            }
        }
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
