import SwiftUI
import Combine
import Supabase
import Auth


// MARK: - Home View
//
// The Library tab — Editorial Teal (design canvas · "01 · Library (Home)"),
// top to bottom:
//  1. Header — avatar, greeting, "Your library", Search and "Save a link";
//  2. Feed sources — the user's RSS feeds as round monograms, with an accent
//     dot on the ones that have unread items ("All feeds" closes the row);
//  3. "Up next" — the reading queue: hero article + the next ones;
//  4. "Your shelves" — category chips over the topic shelves, plus the
//     "All articles" link to the whole Library (`CategoryArticlesView`, `.all`).
// The Search button opens the search field; typing swaps the home for the
// flat, paginated results.

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    /// Flat, paginated list used for search results.
    @StateObject private var viewModel = ArticleListViewModel()
    /// Whole Library behind the category shelves.
    @StateObject private var homeViewModel = LibraryHomeViewModel()
    /// Feeds behind the sources row (same data as the Feeds tab).
    @StateObject private var feedsViewModel = RSSViewModel()
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared

    @State private var showAddArticle = false
    @State private var hasAppeared = false
    @State private var isSearchOpen = false
    @State private var userProfile: UserProfile?
    /// Category chip selected under "Your shelves" (`nil` = All).
    @State private var selectedCategory: ArticleCategory?
    @FocusState private var searchFocused: Bool

    /// Feeds shown in the sources row before "All feeds".
    private let sourcesLimit = 12

    private var isSearching: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    headerView

                    if isSearching {
                        filterBar

                        ArticleListView(viewModel: viewModel, onAddArticle: { showAddArticle = true })
                    } else {
                        homeContent
                    }
                }
            }
            .onAppear {
                // Coming back from the reader: progress, status and queue may have changed.
                if hasAppeared {
                    Task { await refreshHome() }
                } else {
                    hasAppeared = true
                }
            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet(onArticleAdded: {
                    Task {
                        async let home: Void = refreshHome()
                        async let search: Void = viewModel.refresh()
                        _ = await (home, search)
                    }
                })
                .environmentObject(themeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .task {
            guard let userId = authManager.user?.id.uuidString else { return }
            async let articles: Void = viewModel.loadArticles(userId: userId)
            async let library: Void = homeViewModel.load(userId: userId)
            async let queue: Void = queueStore.load(userId: userId)
            async let feeds: Void = feedsViewModel.loadFeeds()
            async let profile: Void = loadProfile(userId: userId)
            _ = await (articles, library, queue, feeds, profile)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshArticles"))) { _ in
            Task {
                async let home: Void = refreshHome()
                async let search: Void = viewModel.refresh()
                _ = await (home, search)
            }
        }
    }

    private func refreshHome() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        async let library: Void = homeViewModel.load(userId: userId)
        async let queue: Void = queueStore.load(userId: userId)
        async let feeds: Void = feedsViewModel.loadFeeds()
        _ = await (library, queue, feeds)
    }

    private func loadProfile(userId: String) async {
        if let profile = try? await SupabaseService.shared.getUserProfile(userId: userId) {
            userProfile = profile
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(Typography.ui(12, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                    Text("Your library")
                        .font(Typography.ui(17, weight: .bold, relativeTo: .headline))
                        .foregroundColor(themeManager.colors.text)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer(minLength: 8)

                IconCircleButton(
                    systemImage: "magnifyingglass",
                    label: "Search your library",
                    style: .outline,
                    glyphSize: 17
                ) {
                    if isSearchOpen { closeSearch() } else { openSearch() }
                }

                IconCircleButton(systemImage: "plus", label: "Save a link", style: .accent, glyphSize: 18) {
                    showAddArticle = true
                }
            }

            if isSearchOpen {
                searchField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(themeManager.colors.accent200)

            if let url = userProfile?.avatarUrl, !url.isEmpty {
                AsyncImageView(url: url, cornerRadius: 22)
            } else {
                Text(avatarInitials)
                    .font(Typography.ui(15, weight: .bold))
                    .foregroundColor(themeManager.colors.accent700)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var avatarInitials: String {
        guard let profile = userProfile else { return "ZR" }
        let initials = profile.initials
        return initials == "??" ? "ZR" : initials
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.colors.muted)
                    .accessibilityHidden(true)

                TextField(
                    "",
                    text: $viewModel.searchQuery,
                    prompt: Text("Search your library").foregroundColor(themeManager.colors.muted)
                )
                .font(Typography.ui(15, relativeTo: .subheadline))
                .foregroundColor(themeManager.colors.text)
                .submitLabel(.search)
                .focused($searchFocused)
                .accessibilityLabel("Search your library")

                if isSearching {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.colors.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            .background(themeManager.colors.page)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        searchFocused ? themeManager.colors.accent : themeManager.colors.line,
                        lineWidth: searchFocused ? 1.5 : 1
                    )
            )

            Button {
                closeSearch()
            } label: {
                Text("Cancel")
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.accent)
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
        }
        .onAppear { searchFocused = true }
    }

    private func openSearch() {
        withAnimation(.easeOut(duration: 0.2)) { isSearchOpen = true }
    }

    private func closeSearch() {
        viewModel.searchQuery = ""
        searchFocused = false
        withAnimation(.easeOut(duration: 0.2)) { isSearchOpen = false }
    }

    // MARK: - Home Content (sources + Up next + shelves)

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !feedsViewModel.feeds.isEmpty {
                    feedSourcesRow
                }

                UpNextSectionView()

                shelvesSection
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            await refreshHome()
        }
    }

    // MARK: - Feed sources row

    /// Feeds with unread items first, then the rest, capped at `sourcesLimit`.
    private var sourceFeeds: [RSSFeed] {
        let counts = feedsViewModel.unreadCounts
        let sorted = feedsViewModel.feeds.enumerated().sorted { lhs, rhs in
            let left = counts[lhs.element.id] ?? 0
            let right = counts[rhs.element.id] ?? 0
            if (left > 0) != (right > 0) { return left > 0 }
            return lhs.offset < rhs.offset
        }
        return sorted.prefix(sourcesLimit).map { $0.element }
    }

    private var feedSourcesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(sourceFeeds) { feed in
                    NavigationLink(destination: RSSArticleListView(feed: feed, viewModel: feedsViewModel)) {
                        FeedSourceBubble(
                            feed: feed,
                            title: feed.title,
                            monogram: FeedSourceBubble.monogram(for: feed.title),
                            unreadCount: feedsViewModel.unreadCounts[feed.id] ?? 0
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                NavigationLink(destination: RSSAllFeedsListView(viewModel: feedsViewModel)) {
                    FeedSourceBubble(title: "All feeds", monogram: "···", unreadCount: 0)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    // MARK: - Your shelves

    private var sections: [LibraryCategorySection] {
        homeViewModel.sections(
            readingStatus: viewModel.filters.readingStatus,
            excluding: queueStore.queuedArticleIds,
            categories: categoryStore
        )
    }

    private var shelvesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 6) {
                Text("Your shelves")
                    .font(Typography.cardTitle)
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                shelvesOptionsMenu

                if !homeViewModel.articles.isEmpty {
                    NavigationLink(destination: CategoryArticlesView(scope: .all, viewModel: homeViewModel)) {
                        Text("All articles")
                            .font(Typography.ui(13.5, weight: .medium))
                            .foregroundColor(themeManager.colors.accent)
                    }
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                    .accessibilityHint("Shows every saved article, newest first")
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            if categoryStore.isRefining {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(themeManager.colors.accent)
                    Text("Sorting by topic…")
                        .font(Typography.meta)
                        .foregroundColor(themeManager.colors.muted)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .accessibilityElement(children: .combine)
            }

            let sections = self.sections
            if sections.count > 1 {
                categoryChips(sections)
            }

            libraryBody(sections)
        }
    }

    private var readingStatusBinding: Binding<ReadingStatus?> {
        Binding(
            get: { viewModel.filters.readingStatus },
            set: { viewModel.setReadingStatusFilter($0) }
        )
    }

    /// Reading-status filter and list / cards toggle, kept off the main
    /// header so the shelves match the design's single chip row.
    private var shelvesOptionsMenu: some View {
        let isFiltered = viewModel.filters.readingStatus != nil

        return Menu {
            Picker("Show", selection: readingStatusBinding) {
                Text("All").tag(ReadingStatus?.none)
                Text("Unread").tag(ReadingStatus?.some(.unread))
                Text("Reading").tag(ReadingStatus?.some(.reading))
                Text("Done").tag(ReadingStatus?.some(.completed))
            }

            Divider()

            Button {
                themeManager.toggleViewMode()
            } label: {
                Label(
                    themeManager.viewMode == .list ? "Show as cards" : "Show as list",
                    systemImage: themeManager.viewMode == .list ? "square.grid.2x2" : "list.bullet"
                )
            }
        } label: {
            Image(systemName: isFiltered
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(Typography.symbol(19))
                .foregroundColor(isFiltered ? themeManager.colors.accent : themeManager.colors.muted)
                .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
        }
        .accessibilityLabel(isFiltered ? "Shelf options, filtered" : "Shelf options")
    }

    private func categoryChips(_ sections: [LibraryCategorySection]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    dotColor: nil,
                    isSelected: selectedCategory == nil,
                    action: { withAnimation(.easeOut(duration: 0.2)) { selectedCategory = nil } }
                )

                ForEach(sections) { section in
                    FilterChip(
                        title: section.category.displayName,
                        dotColor: nil,
                        isSelected: selectedCategory == section.category,
                        action: { withAnimation(.easeOut(duration: 0.2)) { selectedCategory = section.category } }
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    @ViewBuilder
    private func libraryBody(_ sections: [LibraryCategorySection]) -> some View {
        if homeViewModel.isLoading && homeViewModel.articles.isEmpty {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        } else if let error = homeViewModel.errorMessage, homeViewModel.articles.isEmpty {
            libraryMessage(
                icon: "exclamationmark.triangle",
                title: "Couldn't load your library",
                message: error,
                actionTitle: "Retry",
                action: { Task { await refreshHome() } }
            )
        } else if homeViewModel.articles.isEmpty {
            libraryMessage(
                icon: "book.closed",
                title: "No articles yet",
                message: "Save your first link with the + button above.",
                actionTitle: "Add article",
                action: { showAddArticle = true }
            )
        } else if sections.isEmpty {
            libraryMessage(
                icon: viewModel.filters.readingStatus == nil ? "list.number" : "line.3.horizontal.decrease.circle",
                title: viewModel.filters.readingStatus == nil ? "Everything is up next" : "No articles here",
                message: viewModel.filters.readingStatus == nil
                    ? "All your saved articles are in the Up next queue."
                    : "No articles outside Up next match this filter.",
                actionTitle: viewModel.filters.readingStatus == nil ? nil : "Show all",
                action: { viewModel.setReadingStatusFilter(nil) }
            )
        } else {
            // A chip whose category has emptied out (filter, queue) falls back to All.
            let picked = sections.filter { $0.category == selectedCategory }
            let visible = picked.isEmpty ? sections : picked

            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(visible) { section in
                    CategoryShelfView(section: section, viewModel: homeViewModel)
                }
            }
        }
    }

    private func libraryMessage(
        icon: String,
        title: String,
        message: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.surface)
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(Typography.symbol(30))
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

            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.ui(15, weight: .semibold))
                        .foregroundColor(themeManager.colors.page)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .background(themeManager.colors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Bar (search results)

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == nil,
                    action: { viewModel.setReadingStatusFilter(nil) }
                )

                FilterChip(
                    title: "Unread",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == .unread,
                    action: { viewModel.setReadingStatusFilter(.unread) }
                )

                FilterChip(
                    title: "Reading",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == .reading,
                    action: { viewModel.setReadingStatusFilter(.reading) }
                )

                FilterChip(
                    title: "Done",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == .completed,
                    action: { viewModel.setReadingStatusFilter(.completed) }
                )
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }
}

// MARK: - Feed Source Bubble

/// One feed in the home sources row: a round monogram with an accent dot
/// when the feed has unread items, and its name underneath.
struct FeedSourceBubble: View {
    /// When set, the feed image fills the bubble as a cover.
    var feed: RSSFeed? = nil
    let title: String
    let monogram: String
    let unreadCount: Int

    @EnvironmentObject var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 52

    var body: some View {
        VStack(spacing: 6) {
            bubble
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0 {
                        Circle()
                            .fill(themeManager.colors.accent)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(themeManager.colors.page, lineWidth: 2))
                            .offset(x: -1, y: 1)
                    }
                }

            Text(title)
                .font(Typography.ui(11.5, relativeTo: .caption2))
                .foregroundColor(themeManager.colors.accent2)
                .lineLimit(1)
                .frame(width: size + 12)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unreadCount > 0 ? "\(title), \(unreadCount) unread" : title)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var bubble: some View {
        if let feed {
            FeedAvatar(feed: feed, size: size, monogramFont: Typography.ui(13, weight: .bold))
        } else {
            Text(monogram)
                .font(Typography.ui(13, weight: .bold))
                .foregroundColor(themeManager.colors.text)
                .frame(width: size, height: size)
                .background(Circle().fill(themeManager.colors.page))
                .overlay(Circle().stroke(themeManager.colors.line, lineWidth: 1))
        }
    }

    /// "Il Post" → "IP", "The Verge" → "TV", "Nautilus" → "Na".
    static func monogram(for title: String) -> String {
        let words = title
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "|" })
            .map(String.init)
            .filter { !$0.isEmpty }

        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        if let first = words.first {
            return String(first.prefix(2)).capitalized
        }
        return "··"
    }
}

// MARK: - Filter Chip

/// Editorial Teal chip: accent fill when selected, `surface` fill otherwise.
struct FilterChip: View {
    let title: String
    let dotColor: Color?
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(Typography.ui(13.5, weight: isSelected ? .semibold : .medium, relativeTo: .footnote))
            }
            .foregroundColor(isSelected ? themeManager.colors.page : themeManager.colors.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            .background(isSelected ? themeManager.colors.accent : themeManager.colors.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .minimumTapTarget()
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager.shared)
}
