import SwiftUI
import Supabase

// MARK: - People View (07) — merged Shared Inbox + Friends

struct PeopleView: View {
    @StateObject private var viewModel = PeopleViewModel()
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

                Button(action: { showSearch = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.colors.page)
                        .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                        .background(themeManager.colors.accent)
                        .clipShape(Circle())
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
        HStack(spacing: 4) {
            segmentButton(.shared, title: "Shared with me")
            segmentButton(.friends, title: "Friends")
        }
        .padding(4)
        .background(themeManager.colors.sink)
        .clipShape(Capsule())
    }

    private func segmentButton(_ segment: PeopleViewModel.Segment, title: String) -> some View {
        let isSelected = viewModel.segment == segment
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.segment = segment }
        }) {
            Text(title)
                .font(Typography.figtree(13.5, weight: .semibold))
                .foregroundColor(isSelected ? themeManager.colors.text : themeManager.colors.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? themeManager.colors.card : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.black.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(viewModel.sharedArticles) { share in
                            if let article = share.article {
                                NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                                    ShareCard(share: share, article: article)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .onAppear {
                                    if !share.isRead {
                                        Task { await viewModel.markAsRead(share) }
                                    }
                                }
                                .contextMenu {
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
                    .padding(.top, Spacing.md)
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
                        Text("Sent")
                            .font(Typography.sectionLabel)
                            .textCase(.uppercase)
                            .foregroundColor(themeManager.colors.muted)

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
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                            FriendRow(friend: friend)
                            if index < viewModel.friends.count - 1 {
                                Rectangle()
                                    .fill(themeManager.colors.line)
                                    .frame(height: 1)
                                    .padding(.leading, 40 + 14 + 12)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(themeManager.colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
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
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }
            Text(title)
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)
            Text(message)
                .font(Typography.figtree(15))
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
                .font(Typography.figtree(14))
                .foregroundColor(themeManager.colors.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onReject) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.colors.muted)
                    .frame(width: 28, height: 28)
                    .background(themeManager.colors.sink)
                    .clipShape(Circle())
            }

            Button(action: onAccept) {
                Text("Accept")
                    .font(Typography.figtree(13, weight: .bold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.colors.accent, lineWidth: 1)
        )
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
                .font(Typography.figtree(14, weight: .semibold))
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
            AvatarView(imageUrl: friend.user.avatarUrl, initials: friend.user.initials, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.user.displayName ?? "Unknown")
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                if let bio = friend.user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.figtree(12.5))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AvatarView(imageUrl: share.sharer?.avatarUrl, initials: share.sharer?.initials ?? "??", size: 32)

                (Text(share.sharer?.displayName ?? "Someone").fontWeight(.bold) + Text(" shared this"))
                    .font(Typography.figtree(14))
                    .foregroundColor(themeManager.colors.text)

                Spacer()

                if !share.isRead {
                    Circle().fill(themeManager.colors.accent).frame(width: 8, height: 8)
                }
            }

            if let message = share.message, !message.isEmpty {
                Text(message)
                    .font(Typography.figtree(14.5))
                    .lineSpacing(8)
                    .foregroundColor(themeManager.colors.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(themeManager.colors.sink)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 12) {
                Group {
                    if let imageUrl = article.imageUrl {
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
                    Text(article.title)
                        .font(Typography.figtree(14.5, weight: .bold))
                        .foregroundColor(themeManager.colors.text)
                        .lineLimit(2)
                    Text(articleMeta)
                        .font(Typography.meta)
                        .foregroundColor(themeManager.colors.muted)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .opacity(share.isRead ? 0.75 : 1)
    }

    private var articleMeta: String {
        var parts: [String] = []
        if let domain = article.domain { parts.append(domain) }
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
                        .foregroundColor(themeManager.colors.text.opacity(0.55))
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
                .padding(.vertical, 11)
                .background(themeManager.colors.sink)
                .clipShape(Capsule())
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)

                if isLoading {
                    ProgressView()
                        .tint(themeManager.colors.accent)
                    Spacer()
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    Text("No users found")
                        .font(Typography.figtree(14))
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
            AvatarView(imageUrl: user.avatarUrl, initials: user.initials, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Unknown")
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.figtree(12.5))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { Task { await sendRequest(to: user) } }) {
                if sentTo.contains(user.id) {
                    Text("Sent")
                        .font(Typography.figtree(12.5, weight: .bold))
                        .foregroundColor(themeManager.colors.accent)
                } else {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(themeManager.colors.accent)
                }
            }
            .disabled(sentTo.contains(user.id))
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
