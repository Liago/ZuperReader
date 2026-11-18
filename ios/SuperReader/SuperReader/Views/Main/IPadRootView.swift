import SwiftUI
import Supabase
import Auth

// MARK: - iPad root (regular width)
//
// Editorial Teal for iPad (design canvas · "iPad orizzontale" / "iPad
// verticale"): the tab bar becomes
//  • a 264pt sidebar when there is room (landscape, ≥ 1100pt wide) — logo,
//    "Save a link", the sections with counts, the user's feeds with unread
//    counts and the profile row;
//  • a 72pt icon rail otherwise (portrait).
// The detail area hosts the same screens as the iPhone tabs; Up next, All
// articles and a single feed become root pages of their own.

enum IPadSection: Hashable {
    case library
    case upNext
    case allArticles
    case feeds
    case feed(UUID)
    case people
    case you
}

struct IPadRootView: View {
    let peopleBadgeCount: Int

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var feedsViewModel = RSSViewModel()
    @StateObject private var libraryViewModel = LibraryHomeViewModel()
    @ObservedObject private var queueStore = ReadingQueueStore.shared

    @State private var selection: IPadSection = .library
    @State private var userProfile: UserProfile?
    @State private var showAddArticle = false
    @ObservedObject private var quickActions = QuickActionRouter.shared

    /// Below this width the sidebar collapses into the icon rail.
    private let sidebarMinWidth: CGFloat = 1100

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if geometry.size.width >= sidebarMinWidth {
                    sidebar
                        .frame(width: 264)
                        .transition(.move(edge: .leading))
                } else {
                    rail
                        .frame(width: 72)
                }

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.25), value: geometry.size.width >= sidebarMinWidth)
        }
        .background(themeManager.colors.page.ignoresSafeArea())
        .onReceive(quickActions.$pending) { action in
            guard action == .addArticle else { return }
            quickActions.pending = nil
            selection = .library
            showAddArticle = true
        }
        .sheet(isPresented: $showAddArticle) {
            AddArticleSheet(onArticleAdded: {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshArticles"), object: nil)
                Task { await reloadCounts() }
            })
            .environmentObject(themeManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .task { await initialLoad() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshArticles"))) { _ in
            Task { await reloadCounts() }
        }
    }

    // MARK: - Data

    private func initialLoad() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        async let feeds: Void = feedsViewModel.loadFeeds()
        async let library: Void = libraryViewModel.load(userId: userId)
        async let queue: Void = queueStore.load(userId: userId)
        async let profile: Void = loadProfile(userId: userId)
        _ = await (feeds, library, queue, profile)
    }

    private func reloadCounts() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        async let library: Void = libraryViewModel.load(userId: userId)
        async let queue: Void = queueStore.load(userId: userId)
        _ = await (library, queue)
    }

    private func loadProfile(userId: String) async {
        if let profile = try? await SupabaseService.shared.getUserProfile(userId: userId) {
            userProfile = profile
        }
    }

    private var initials: String {
        guard let value = userProfile?.initials, value != "??" else { return "ZR" }
        return value
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .library:
            HomeView()
        case .upNext:
            NavigationStack {
                QueueView(showsBackButton: false)
            }
        case .allArticles:
            NavigationStack {
                CategoryArticlesView(scope: .all, viewModel: libraryViewModel, showsBackButton: false)
            }
        case .feeds:
            RSSListView()
        case .feed(let id):
            if let feed = feedsViewModel.feeds.first(where: { $0.id == id }) {
                NavigationStack {
                    RSSArticleListView(feed: feed, viewModel: feedsViewModel)
                }
                .id(id)
            } else {
                RSSListView()
            }
        case .people:
            PeopleView()
        case .you:
            ProfileView()
        }
    }

    // MARK: - Sections

    private struct SectionItem: Identifiable {
        let section: IPadSection
        let title: String
        let systemImage: String
        let count: Int
        var id: String { title }
    }

    private var sections: [SectionItem] {
        [
            SectionItem(section: .library, title: "Library", systemImage: "house", count: 0),
            SectionItem(section: .upNext, title: "Up next", systemImage: "bookmark", count: queueStore.items.count),
            SectionItem(section: .allArticles, title: "All articles", systemImage: "list.bullet", count: libraryViewModel.articles.count),
            SectionItem(section: .feeds, title: "Feeds", systemImage: "dot.radiowaves.up.forward", count: feedsViewModel.totalUnreadCount),
            SectionItem(section: .people, title: "People", systemImage: "person.2", count: peopleBadgeCount),
            SectionItem(section: .you, title: "You", systemImage: "person.crop.circle", count: 0)
        ]
    }

    private func select(_ section: IPadSection) {
        selection = section
    }

    // MARK: - Sidebar (landscape)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                logo(size: 34)
                Text("ZuperReader")
                    .font(Typography.ui(17, weight: .bold, relativeTo: .headline))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(action: { showAddArticle = true }) {
                    Image(systemName: "plus")
                        .font(Typography.symbol(16, weight: .semibold))
                        .foregroundColor(themeManager.colors.page)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(themeManager.colors.accent))
                }
                .buttonStyle(ScaleButtonStyle())
                .minimumTapTarget()
                .accessibilityLabel("Save a link")
            }
            .padding(.horizontal, 6)

            VStack(spacing: 2) {
                ForEach(sections) { item in
                    sidebarRow(item)
                }
            }

            if !feedsViewModel.feeds.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feeds")
                        .font(Typography.sectionLabel)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundColor(themeManager.colors.muted)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(feedsViewModel.feeds) { feed in
                                feedRow(feed)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }

            Spacer(minLength: 0)

            Button(action: { select(.you) }) {
                HStack(spacing: 10) {
                    avatar(size: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(userProfile?.displayName ?? "Reader")
                            .font(Typography.ui(14, weight: .semibold))
                            .foregroundColor(themeManager.colors.text)
                            .lineLimit(1)
                        if let email = userProfile?.email {
                            Text(email)
                                .font(Typography.ui(12, relativeTo: .caption))
                                .foregroundColor(themeManager.colors.muted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selection == .you ? themeManager.colors.accent200 : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your profile")
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(themeManager.colors.rail.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(themeManager.colors.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    private func sidebarRow(_ item: SectionItem) -> some View {
        let isSelected = selection == item.section
        return Button(action: { select(item.section) }) {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(Typography.symbol(17, weight: .medium))
                    .foregroundColor(isSelected ? themeManager.colors.accent : themeManager.colors.accent2)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(Typography.ui(15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(themeManager.colors.text)
                Spacer(minLength: 4)
                if item.count > 0 {
                    Text("\(item.count)")
                        .font(Typography.ui(13, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.muted)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeManager.colors.accent200 : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.count > 0 ? "\(item.title), \(item.count)" : item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func feedRow(_ feed: RSSFeed) -> some View {
        let isSelected = selection == .feed(feed.id)
        let unread = feedsViewModel.unreadCounts[feed.id] ?? 0
        return Button(action: { select(.feed(feed.id)) }) {
            HStack(spacing: 10) {
                FeedAvatar(feed: feed, size: 24, monogramFont: Typography.ui(9, weight: .bold, relativeTo: .caption2))
                Text(feed.title)
                    .font(Typography.ui(14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if unread > 0 {
                    Text("\(unread)")
                        .font(Typography.ui(12.5, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeManager.colors.accent200 : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unread > 0 ? "\(feed.title), \(unread) unread" : feed.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Rail (portrait)

    private var rail: some View {
        VStack(spacing: 6) {
            logo(size: 40)
                .padding(.bottom, 10)

            Button(action: { showAddArticle = true }) {
                Image(systemName: "plus")
                    .font(Typography.symbol(18, weight: .semibold))
                    .foregroundColor(themeManager.colors.page)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(themeManager.colors.accent))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Save a link")
            .padding(.bottom, 14)

            ForEach(sections.filter { $0.section != .you }) { item in
                railButton(item)
            }

            Spacer(minLength: 0)

            Button(action: { select(.you) }) {
                avatar(size: 40)
                    .overlay(
                        Circle()
                            .stroke(themeManager.colors.accent, lineWidth: selection == .you ? 2 : 0)
                            .padding(-3)
                    )
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel("Your profile")
            .accessibilityAddTraits(selection == .you ? [.isSelected] : [])
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(themeManager.colors.rail.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(themeManager.colors.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    private func railButton(_ item: SectionItem) -> some View {
        let isSelected: Bool = {
            if case .feed = selection, item.section == .feeds { return true }
            return selection == item.section
        }()
        return Button(action: { select(item.section) }) {
            Image(systemName: item.systemImage)
                .font(Typography.symbol(21, weight: .medium))
                .foregroundColor(isSelected ? themeManager.colors.accent : themeManager.colors.accent2)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? themeManager.colors.accent200 : Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if item.section == .people && item.count > 0 {
                        Circle()
                            .fill(themeManager.colors.accent)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(themeManager.colors.rail, lineWidth: 2))
                            .offset(x: -9, y: 9)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.count > 0 ? "\(item.title), \(item.count)" : item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Shared bits

    private func logo(size: CGFloat) -> some View {
        Text("ZR")
            .font(Typography.ui(size * 0.36, weight: .heavy))
            .foregroundColor(themeManager.colors.page)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3).fill(themeManager.colors.accent))
            .accessibilityHidden(true)
    }

    private func avatar(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(themeManager.colors.accent200)
            if let url = userProfile?.avatarUrl, !url.isEmpty {
                AsyncImageView(url: url, cornerRadius: size / 2)
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(initials)
                    .font(Typography.ui(size * 0.36, weight: .bold))
                    .foregroundColor(themeManager.colors.accent700)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
