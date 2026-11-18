import SwiftUI
import Supabase
import Auth

// MARK: - People View — merged Shared Inbox + Friends
//
// Editorial Teal (design canvas · "09 · People"): large title with an
// outline "Find people" button, a pill segmented control, shares as an
// activity feed (who shared what, with the article as a bordered card) and
// friends as a plain hairline list.

struct PeopleView: View {
    @StateObject private var viewModel = PeopleViewModel()
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                if viewModel.isLoading && isCurrentSegmentEmpty {
                    loadingView
                } else {
                    content
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSearch) {
                UserSearchSheet()
                    .environmentObject(themeManager)
            }
            .task { await viewModel.loadAll() }
        }
    }

    private var isCurrentSegmentEmpty: Bool {
        switch viewModel.segment {
        case .shared: return viewModel.sharedArticles.isEmpty
        case .friends: return viewModel.friends.isEmpty && viewModel.pendingRequests.isEmpty
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("People")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)

                Spacer()

                IconCircleButton(systemImage: "person.badge.plus", label: "Find people", style: .outline, glyphSize: 17) {
                    showSearch = true
                }
            }

            segmentedPill
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
        .padding(.bottom, Spacing.md)
        .background(themeManager.colors.page)
    }

    private var segmentedPill: some View {
        HStack(spacing: 2) {
            segmentButton(.shared, title: "Shared with me")
            segmentButton(.friends, title: viewModel.friends.isEmpty ? "Friends" : "Friends · \(viewModel.friends.count)")
        }
        .padding(3)
        .background(themeManager.colors.surface)
        .clipShape(Capsule())
    }

    private func segmentButton(_ segment: PeopleViewModel.Segment, title: String) -> some View {
        let isSelected = viewModel.segment == segment
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.segment = segment }
        }) {
            Text(title)
                .font(Typography.ui(14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? themeManager.colors.text : themeManager.colors.muted)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isSelected ? themeManager.colors.page : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color(hex: "#16191A").opacity(0.12) : .clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.segment {
        case .shared: sharedContent
        case .friends: friendsContent
        }
    }

    // MARK: Shared with me

    private var sharedContent: some View {
        Group {
            if viewModel.sharedArticles.isEmpty {
                emptyState(
                    icon: "tray",
                    title: "No shared articles",
                    message: "Articles shared by your friends will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.sharedArticles) { share in
                            if let article = share.article {
                                NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                                    ShareCard(share: share, article: article)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if !share.isRead {
                                        Task { await viewModel.markAsRead(share) }
                                    }
                                }
                                .contextMenu {
                                    // HIG · Context menus: unavailable items are hidden, not dimmed.
                                    if !queueStore.isQueued(share.articleId) && !queueStore.isPending(share.articleId) {
                                        Button {
                                            Task { await viewModel.addToQueue(share) }
                                        } label: {
                                            Label("Add to Up next", systemImage: "text.badge.plus")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteShare(share) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.scrollBottomInset)
                }
                .refreshable { await viewModel.loadAll() }
            }
        }
    }

    // MARK: Friends

    private var friendsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if !viewModel.pendingRequests.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.pendingRequests) { request in
                            PendingRequestRow(
                                request: request,
                                onAccept: { Task { await viewModel.acceptRequest(request) } },
                                onReject: { Task { await viewModel.rejectRequest(request) } }
                            )
                        }
                    }
                }

                if !viewModel.sentRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sent requests")
                            .font(Typography.ui(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundColor(themeManager.colors.accent2)

                        VStack(spacing: 0) {
                            ForEach(viewModel.sentRequests) { request in
                                SentRequestRow(request: request)
                            }
                        }
                    }
                }

                if viewModel.friends.isEmpty {
                    if viewModel.pendingRequests.isEmpty && viewModel.sentRequests.isEmpty {
                        emptyState(
                            icon: "person.2",
                            title: "No friends yet",
                            message: "Search for people to connect with them."
                        )
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Friends")
                            .font(Typography.cardTitle)
                            .foregroundColor(themeManager.colors.text)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, 4)

                        ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                            FriendRow(friend: friend)
                            if index < viewModel.friends.count - 1 {
                                Rectangle()
                                    .fill(themeManager.colors.line)
                                    .frame(height: 1)
                                    .padding(.leading, 44 + 14)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .refreshable { await viewModel.loadAll() }
    }

    // MARK: Shared bits

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.surface)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(Typography.symbol(34))
                    .foregroundColor(themeManager.colors.muted)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)
            Text(message)
                .font(Typography.ui(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
        }
    }
}

// MARK: - Pending Request Row

private struct PendingRequestRow: View {
    let request: Friend
    let onAccept: () -> Void
    let onReject: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(imageUrl: request.user.avatarUrl, initials: request.user.initials, size: 40)

            (Text(request.user.displayName ?? "Someone").fontWeight(.bold) + Text(" wants to connect"))
                .font(Typography.ui(14))
                .foregroundColor(themeManager.colors.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onReject) {
                Image(systemName: "xmark")
                    .font(Typography.symbol(12, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(themeManager.colors.surface))
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel("Decline request")

            Button(action: onAccept) {
                Text("Accept")
                    .font(Typography.ui(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(themeManager.colors.accent))
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
        }
        .padding(14)
        .background(themeManager.colors.accent200)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }
}

// MARK: - Sent Request Row

private struct SentRequestRow: View {
    let request: Friend
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(imageUrl: request.user.avatarUrl, initials: request.user.initials, size: 32)
            Text(request.user.displayName ?? "Unknown")
                .font(Typography.ui(14, weight: .semibold))
                .foregroundColor(themeManager.colors.text)
            Spacer()
            Text("Pending")
                .font(Typography.meta)
                .foregroundColor(themeManager.colors.muted)
        }
        .padding(.vertical, 8)
        .opacity(0.7)
    }
}

// MARK: - Friend Row

private struct FriendRow: View {
    let friend: Friend
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(imageUrl: friend.user.avatarUrl, initials: friend.user.initials, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.user.displayName ?? "Unknown")
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                if let bio = friend.user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.ui(12.5))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Share Card

private struct ShareCard: View {
    let share: ArticleShare
    let article: Article
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(imageUrl: share.sharer?.avatarUrl, initials: share.sharer?.initials ?? "??", size: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(share.sharer?.displayName ?? "Someone")
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.colors.text)
                    Text("shared")
                        .foregroundColor(themeManager.colors.accent2)

                    Spacer(minLength: 4)

                    if !share.isRead {
                        Circle()
                            .fill(themeManager.colors.accent)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("New")
                    }
                }
                .font(Typography.ui(14, relativeTo: .subheadline))

                if let message = share.message, !message.isEmpty {
                    Text("“\(message)”")
                        .font(Typography.ui(14.5, relativeTo: .subheadline))
                        .lineSpacing(3)
                        .foregroundColor(themeManager.colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Group {
                        if let imageUrl = article.imageUrl {
                            AsyncImageView(url: imageUrl, cornerRadius: CornerRadius.smallThumbnail)
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                themeManager.colors.surface
                                Image(systemName: "doc.text.image")
                                    .foregroundColor(themeManager.colors.muted)
                            }
                        }
                    }
                    .frame(width: 56, height: 56)
                    .thumbnailClip(CornerRadius.smallThumbnail)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(Typography.ui(14.5, weight: .semibold, relativeTo: .subheadline))
                            .foregroundColor(themeManager.colors.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(articleMeta)
                            .font(Typography.ui(12, relativeTo: .caption))
                            .foregroundColor(themeManager.colors.muted)
                    }

                    Spacer(minLength: 0)
                }
                .padding(10)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .stroke(themeManager.colors.line, lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeManager.colors.line)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .opacity(share.isRead ? 0.8 : 1)
        .accessibilityElement(children: .combine)
    }

    private var articleMeta: String {
        var parts: [String] = []
        if let domain = article.domain { parts.append(domain.replacingOccurrences(of: "www.", with: "")) }
        if let time = article.estimatedReadTime { parts.append("\(time) min") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - User Search Sheet (Add friends)

struct UserSearchSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var searchQuery = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isLoading = false
    @State private var sentTo: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.colors.muted)
                        .accessibilityHidden(true)
                    TextField(
                        "",
                        text: $searchQuery,
                        prompt: Text("Search by name or email").foregroundColor(themeManager.colors.muted)
                    )
                    .foregroundColor(themeManager.colors.text)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await performSearch() } }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)

                if isLoading {
                    ProgressView()
                        .tint(themeManager.colors.accent)
                    Spacer()
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    Text("No users found")
                        .font(Typography.ui(14))
                        .foregroundColor(themeManager.colors.muted)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { user in
                                searchRow(user)
                                if user.id != searchResults.last?.id {
                                    Rectangle()
                                        .fill(themeManager.colors.line)
                                        .frame(height: 1)
                                        .padding(.leading, 40 + 14)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }
                    Spacer(minLength: 0)
                }
            }
            .background(themeManager.colors.page)
            .navigationTitle("Add friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func searchRow(_ user: UserProfile) -> some View {
        HStack(spacing: 14) {
            AvatarView(imageUrl: user.avatarUrl, initials: user.initials, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Unknown")
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.ui(12.5))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { Task { await sendRequest(to: user) } }) {
                let sent = sentTo.contains(user.id)
                Text(sent ? "Sent" : "Add")
                    .font(Typography.ui(13, weight: .semibold))
                    .foregroundColor(sent ? themeManager.colors.muted : themeManager.colors.page)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(sent ? themeManager.colors.surface : themeManager.colors.accent))
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .disabled(sentTo.contains(user.id))
            .accessibilityLabel(sentTo.contains(user.id) ? "Request sent" : "Add \(user.displayName ?? "user") as friend")
        }
        .padding(.vertical, 12)
    }

    private func performSearch() async {
        guard !searchQuery.isEmpty, let currentUserId = authManager.user?.id.uuidString else { return }
        isLoading = true
        do {
            searchResults = try await SupabaseService.shared.searchUsers(query: searchQuery, currentUserId: currentUserId)
        } catch {
            print("Search failed: \(error)")
        }
        isLoading = false
    }

    private func sendRequest(to user: UserProfile) async {
        guard let currentUserId = authManager.user?.id.uuidString else { return }
        do {
            _ = try await SupabaseService.shared.sendFriendRequest(requesterId: currentUserId, addresseeId: user.id)
            sentTo.insert(user.id)
        } catch {
            print("Failed to send request: \(error)")
        }
    }
}

#Preview {
    PeopleView()
        .environmentObject(ThemeManager.shared)
}
