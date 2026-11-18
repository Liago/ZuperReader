import SwiftUI
import Auth

// MARK: - Feeds tab
//
// Editorial Teal (design canvas · "02 · Feeds"), top to bottom:
//  1. Header — "Feeds", channels / unread / last sync, settings and "Add feed";
//  2. Search field — filters the loaded articles by title and snippet;
//  3. Chips — All, Unread, then the channels with unread items;
//  4. "Today in your feeds" — the newest articles with an image, as
//     overlay cards in a horizontal carousel;
//  5. "Latest" — newest articles across every feed ("Mark all read",
//     "See all" → `RSSAllFeedsListView`);
//  6. "Your channels" — every feed, opening its source page
//     (`RSSArticleListView`).

struct RSSListView: View {
    @StateObject private var viewModel = RSSViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared

    @State private var showingDiscovery = false
    @State private var showingSettings = false

    /// Newest articles across all feeds (read ones included, for "All").
    @State private var articles: [RSSArticle] = []
    @State private var isLoadingArticles = false
    @State private var isMarkingAllRead = false
    @State private var searchText = ""
    @State private var filter: FeedFilter = .all
    @State private var hasLoaded = false
    /// Articles unread when the "Unread" chip was picked: they stay listed
    /// after being read, so the list does not shift under the user (#134).
    @State private var keptUnreadIds: Set<UUID> = []
    /// Where the reader was left, to scroll back to that article (#134).
    @State private var readerPosition: RSSReaderPosition?
    /// Source / destination of the App Store–style article zoom (#135).
    @Namespace private var articleZoom

    /// Rows under "Latest" before "See all".
    private let latestLimit = 25
    /// Cards in "Today in your feeds".
    private let featuredLimit = 5

    enum FeedFilter: Hashable {
        case all
        case unread
        case feed(UUID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.feeds.isEmpty {
                    loadingView
                } else if viewModel.feeds.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                searchField
                                    .padding(.horizontal, Spacing.screenHorizontal)

                                chipsRow

                                if !isSearching && !featuredArticles.isEmpty {
                                    featuredSection
                                }

                                latestSection
                                    .padding(.horizontal, Spacing.screenHorizontal)

                                if !isSearching {
                                    channelsSection
                                        .padding(.horizontal, Spacing.screenHorizontal)
                                }
                            }
                            .padding(.top, Spacing.xs)
                            .padding(.bottom, Spacing.scrollBottomInset)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .refreshable {
                            await viewModel.refreshFeedsViaAPI()
                            await loadArticles()
                        }
                        .onAppear {
                            restoreScrollPosition(with: proxy)
                        }
                    }
                }

                if viewModel.isRefreshing {
                    RSSRefreshLoaderView(viewModel: viewModel)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .toolbar(.hidden, for: .navigationBar)
            .rssLibrarySaveBanner(bottomPadding: 28)
            .sheet(isPresented: $showingDiscovery) {
                RSSDiscoveryView {
                    Task {
                        await viewModel.loadFeeds()
                        await loadArticles()
                    }
                }
                .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingSettings) {
                RSSSettingsView()
                    .environmentObject(themeManager)
            }
            .task {
                // Back from a reader or a feed page: the list keeps its
                // articles (and scroll position), only read states and
                // unread counts are synced (#134).
                if hasLoaded {
                    await viewModel.loadFeeds()
                    await syncReadState()
                    return
                }
                hasLoaded = true
                await viewModel.loadFeeds()
                await loadArticles()
                if viewModel.shouldAutoRefresh() {
                    await viewModel.refreshFeedsViaAPI()
                    await loadArticles()
                }
            }
            .onChange(of: filter) { _, newFilter in
                if newFilter == .unread {
                    keptUnreadIds = Set(articles.filter { !$0.isRead }.map(\.id))
                }
            }
        }
    }

    // MARK: - Data

    private func loadArticles() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        isLoadingArticles = articles.isEmpty
        do {
            articles = try await RSSService.shared.getArticles(userId: userId, feedId: nil, limit: 100, includeRead: true)
        } catch {
            print("Failed to load feed articles: \(error)")
        }
        isLoadingArticles = false
    }

    /// Updates read state of the loaded articles without replacing the
    /// array, so rows and scroll position stay where they are.
    private func syncReadState() async {
        guard let userId = authManager.user?.id.uuidString, !articles.isEmpty else { return }
        do {
            let fresh = try await RSSService.shared.getArticles(userId: userId, feedId: nil, limit: 100, includeRead: true)
            let byId = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for index in articles.indices {
                guard let updated = byId[articles[index].id],
                      updated.isRead != articles[index].isRead else { continue }
                articles[index].isRead = updated.isRead
                articles[index].readAt = updated.readAt
            }
        } catch {
            print("Failed to sync feed articles: \(error)")
        }
    }

    /// Back from the reader: if the user paged to another article, scroll
    /// to it so the list stays where the reading ended (#134).
    private func restoreScrollPosition(with proxy: ScrollViewProxy) {
        guard let position = readerPosition else { return }
        readerPosition = nil
        guard position.currentId != position.openedId,
              latestArticles.contains(where: { $0.article.id == position.currentId }) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(position.currentId, anchor: .center)
        }
    }

    private func markAsRead(_ article: RSSArticle) async {
        guard let userId = authManager.user?.id.uuidString else { return }
        do {
            try await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
            if let index = articles.firstIndex(where: { $0.id == article.id }) {
                articles[index].isRead = true
                articles[index].readAt = Date()
            }
            // An explicit "Mark as read" removes the row from Unread.
            keptUnreadIds.remove(article.id)
            if let count = viewModel.unreadCounts[article.feedId], count > 0 {
                viewModel.unreadCounts[article.feedId] = count - 1
            }
        } catch {
            print("Failed to mark article as read: \(error)")
        }
    }

    /// Marks every feed with unread items as read (one call per feed).
    private func markAllAsRead() async {
        isMarkingAllRead = true
        let unreadFeeds = viewModel.feeds.filter { (viewModel.unreadCounts[$0.id] ?? 0) > 0 }
        for feed in unreadFeeds {
            await viewModel.markFeedAsRead(feed)
        }
        for index in articles.indices where !articles[index].isRead {
            articles[index].isRead = true
            articles[index].readAt = Date()
        }
        keptUnreadIds = []
        isMarkingAllRead = false
    }

    private func feed(for article: RSSArticle) -> RSSFeed? {
        viewModel.feeds.first(where: { $0.id == article.feedId })
    }

    // MARK: - Filtering

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Articles matching the chip and the search text, with their index in
    /// `articles` (the reader pages through the full array).
    private var filteredArticles: [IndexedRSSArticle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return articles.enumerated().compactMap { (index, article) -> IndexedRSSArticle? in
            switch filter {
            case .all: break
            case .unread: if article.isRead && !keptUnreadIds.contains(article.id) { return nil }
            case .feed(let id): if article.feedId != id { return nil }
            }
            if !query.isEmpty {
                let haystack = (article.title + " " + (article.contentSnippet ?? "")).lowercased()
                if !haystack.contains(query) { return nil }
            }
            return IndexedRSSArticle(index: index, article: article)
        }
    }

    private var featuredArticles: [IndexedRSSArticle] {
        Array(filteredArticles.filter { $0.article.imageUrl != nil }.prefix(featuredLimit))
    }

    /// Latest rows, without the articles already shown as featured cards.
    private var latestArticles: [IndexedRSSArticle] {
        let featuredIds: Set<UUID> = isSearching ? [] : Set(featuredArticles.map { $0.article.id })
        return Array(filteredArticles.filter { !featuredIds.contains($0.article.id) }.prefix(latestLimit))
    }

    /// Channels with unread items, most unread first, for the chip row.
    private var chipFeeds: [RSSFeed] {
        viewModel.feeds
            .filter { (viewModel.unreadCounts[$0.id] ?? 0) > 0 }
            .sorted { (viewModel.unreadCounts[$0.id] ?? 0) > (viewModel.unreadCounts[$1.id] ?? 0) }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Feeds")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(Typography.ui(13, relativeTo: .footnote))
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            IconCircleButton(systemImage: "gearshape", label: "Feed settings", style: .outline, glyphSize: 17) {
                showingSettings = true
            }

            IconCircleButton(systemImage: "plus", label: "Add feed", style: .accent, glyphSize: 18) {
                showingDiscovery = true
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
        .padding(.bottom, 12)
        .background(themeManager.colors.page)
    }

    private var subtitle: String {
        let channels = viewModel.feeds.count
        let unread = viewModel.totalUnreadCount
        return "\(channels) channel\(channels == 1 ? "" : "s") · \(unread) unread · \(viewModel.lastSyncedDescription)"
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.colors.muted)
                .accessibilityHidden(true)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search articles…").foregroundColor(themeManager.colors.muted)
            )
            .font(Typography.ui(15, relativeTo: .subheadline))
            .foregroundColor(themeManager.colors.text)
            .submitLabel(.search)
            .accessibilityLabel("Search articles")

            if isSearching {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.colors.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
    }

    // MARK: - Chips

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", dotColor: nil, isSelected: filter == .all) {
                    withAnimation(.easeOut(duration: 0.2)) { filter = .all }
                }

                FilterChip(title: "Unread", dotColor: nil, isSelected: filter == .unread) {
                    withAnimation(.easeOut(duration: 0.2)) { filter = .unread }
                }

                ForEach(chipFeeds) { feed in
                    FilterChip(title: feed.title, dotColor: nil, isSelected: filter == .feed(feed.id)) {
                        withAnimation(.easeOut(duration: 0.2)) { filter = .feed(feed.id) }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    // MARK: - Today in your feeds

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today in your feeds")
                .font(Typography.cardTitle)
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Spacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(featuredArticles) { item in
                        NavigationLink(destination: reader(for: item)) {
                            RSSFeaturedCard(article: item.article, feedTitle: feed(for: item.article)?.title)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .articleZoomSource(id: item.article.id, in: articleZoom, cornerRadius: 18)
                        .rssArticleContextMenu(article: item.article) {
                            Task { await markAsRead(item.article) }
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Spacing.screenHorizontal)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    /// Paged reader opened with the zoom transition from the tapped item.
    private func reader(for item: IndexedRSSArticle) -> some View {
        RSSArticleReader(
            articles: $articles,
            initialIndex: item.index,
            onPositionChange: { readerPosition = $0 }
        )
        .articleZoomDestination(id: item.article.id, in: articleZoom)
    }

    // MARK: - Latest

    private var latestSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(isSearching ? "Results" : "Latest")
                    .font(Typography.cardTitle)
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if viewModel.totalUnreadCount > 0 && !isSearching {
                    Button {
                        Task { await markAllAsRead() }
                    } label: {
                        if isMarkingAllRead {
                            ProgressView()
                                .controlSize(.small)
                                .tint(themeManager.colors.accent)
                        } else {
                            Text("Mark all read")
                                .font(Typography.ui(13.5, weight: .medium))
                                .foregroundColor(themeManager.colors.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isMarkingAllRead)
                    .minimumTapTarget()
                }
            }

            let rows = latestArticles
            if isLoadingArticles && articles.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in ArticleRowSkeleton() }
                }
            } else if rows.isEmpty {
                Text(isSearching ? "No articles match “\(searchText)”." : "You're all caught up.")
                    .font(Typography.ui(14))
                    .foregroundColor(themeManager.colors.muted)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { item in
                        NavigationLink(destination: reader(for: item)) {
                            RSSArticleRow(article: item.article, feedTitle: feed(for: item.article)?.title)
                        }
                        .buttonStyle(.plain)
                        .articleZoomSource(id: item.article.id, in: articleZoom)
                        .rssArticleContextMenu(article: item.article) {
                            Task { await markAsRead(item.article) }
                        }

                        Rectangle()
                            .fill(themeManager.colors.line)
                            .frame(height: 1)
                    }
                }

                NavigationLink(destination: RSSAllFeedsListView(viewModel: viewModel)) {
                    HStack(spacing: 6) {
                        Text("See all unread")
                            .font(Typography.ui(14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(Typography.symbol(12, weight: .semibold))
                    }
                    .foregroundColor(themeManager.colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .minimumTapTarget()
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Your channels

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your channels")
                .font(Typography.cardTitle)
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)

            // Folders (`RSSFeed.folderId`) have no CRUD yet on either platform,
            // so feeds render as one flat list.
            ForEach(Array(viewModel.feeds.enumerated()), id: \.element.id) { index, feed in
                NavigationLink(destination: RSSArticleListView(feed: feed, viewModel: viewModel)) {
                    RSSFeedRow(feed: feed, unreadCount: viewModel.unreadCounts[feed.id] ?? 0, monogramIndex: index)
                }
                .buttonStyle(.plain)

                if index < viewModel.feeds.count - 1 {
                    Rectangle()
                        .fill(themeManager.colors.line)
                        .frame(height: 1)
                        .padding(.leading, 44 + 14)
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.surface)
                    .frame(width: 96, height: 96)
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(Typography.symbol(36))
                    .foregroundColor(themeManager.colors.muted)
            }
            .accessibilityHidden(true)

            Text("No feeds yet")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("Follow your favorite websites\nto see their latest articles here.")
                .font(Typography.ui(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)

            Button(action: { showingDiscovery = true }) {
                Text("Discover feeds")
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Indexed article

/// An article plus its position in the array the reader pages through.
struct IndexedRSSArticle: Identifiable {
    let index: Int
    let article: RSSArticle
    var id: UUID { article.id }
}

// MARK: - Featured Card ("Today in your feeds")

struct RSSFeaturedCard: View {
    let article: RSSArticle
    let feedTitle: String?

    @EnvironmentObject var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 300
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 184

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(hex: "#2B3A3C")

            if let imageUrl = article.imageUrl {
                AsyncImageView(url: imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color(hex: "#0A0E0F").opacity(0.85), Color(hex: "#0A0E0F").opacity(0)],
                startPoint: .bottom,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 4) {
                if let feedTitle {
                    Text(feedTitle)
                        .font(Typography.ui(12, weight: .semibold, relativeTo: .caption))
                        .foregroundColor(Color(hex: "#C9D9DA"))
                        .lineLimit(1)
                }
                Text(article.title)
                    .font(Typography.ui(18, weight: .bold, relativeTo: .headline))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) {
            if !article.isRead {
                Text("New")
                    .font(Typography.ui(12, weight: .semibold, relativeTo: .caption))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#33666C")))
                    .padding(14)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let date = article.pubDate {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(Typography.symbol(11, weight: .semibold))
                    Text(date, style: .relative)
                        .font(Typography.ui(12, weight: .medium, relativeTo: .caption))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Feed Row ("Your channels")

struct RSSFeedRow: View {
    let feed: RSSFeed
    let unreadCount: Int
    let monogramIndex: Int
    @EnvironmentObject var themeManager: ThemeManager

    var domain: String {
        URL(string: feed.siteUrl ?? feed.url)?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    private var isFullyRead: Bool { unreadCount == 0 }

    var body: some View {
        HStack(spacing: 14) {
            FeedAvatar(feed: feed, size: 44, monogramFont: Typography.ui(13, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)

                if !domain.isEmpty {
                    Text(domain)
                        .font(Typography.ui(12.5, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isFullyRead {
                Image(systemName: "checkmark")
                    .font(Typography.symbol(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.muted)
                    .accessibilityLabel("All read")
            } else {
                Text("\(unreadCount)")
                    .font(Typography.ui(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 24)
                    .background(Capsule().fill(themeManager.colors.accent))
                    .accessibilityLabel("\(unreadCount) unread")
            }

            Image(systemName: "chevron.right")
                .font(Typography.symbol(12, weight: .semibold))
                .foregroundColor(themeManager.colors.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RSSListView()
        .environmentObject(ThemeManager.shared)
}
