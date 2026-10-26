import SwiftUI
import Combine
import Supabase
import Auth


// MARK: - Home View
//
// The Library tab, top to bottom:
//  1. "Up next" — the reading queue, the first thing on screen;
//  2. "Your library" — every other article, grouped into topic shelves by
//     the smart categorization (`ArticleCategoryStore`).
// Typing in the search bar swaps the shelves for the flat, paginated results.

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    /// Flat, paginated list used for search results.
    @StateObject private var viewModel = ArticleListViewModel()
    /// Whole Library behind the category shelves.
    @StateObject private var homeViewModel = LibraryHomeViewModel()
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared

    @State private var showAddArticle = false
    @State private var hasAppeared = false

    private var isSearching: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    // Header
                    headerView

                    if isSearching {
                        // Filter Bar
                        filterBar

                        // Search results
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
            if let userId = authManager.user?.id.uuidString {
                async let articles: Void = viewModel.loadArticles(userId: userId)
                async let library: Void = homeViewModel.load(userId: userId)
                async let queue: Void = queueStore.load(userId: userId)
                _ = await (articles, library, queue)
            }
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
        _ = await (library, queue)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Library")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)

                Spacer()

                HStack(spacing: Spacing.sm) {
                    // View Mode Toggle (shelves, search results and category pages):
                    // the glyph shows the mode a tap switches to.
                    IconCircleButton(
                        systemImage: themeManager.viewMode == .list ? "square.grid.2x2.fill" : "list.bullet",
                        label: themeManager.viewMode == .list ? "Switch to grid view" : "Switch to list view"
                    ) {
                        themeManager.toggleViewMode()
                    }

                    // Add Article Button
                    IconCircleButton(systemImage: "plus", label: "Save a link", style: .accent, glyphSize: 18) {
                        showAddArticle = true
                    }
                }
            }

            // Search Bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.colors.text.opacity(0.55))
                    .accessibilityHidden(true)

                TextField(
                    "",
                    text: $viewModel.searchQuery,
                    prompt: Text("Search articles").foregroundColor(themeManager.colors.muted)
                )
                .font(Typography.figtree(15, relativeTo: .subheadline))
                .foregroundColor(themeManager.colors.text)
                .submitLabel(.search)
                .accessibilityLabel("Search articles")

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
            .padding(.vertical, 11)
            .frame(minHeight: Spacing.minTapTarget)
            .background(themeManager.colors.sink)
            .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
    }

    // MARK: - Home Content (Up next + category shelves)

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                UpNextSectionView()

                librarySection
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .refreshable {
            await refreshHome()
        }
    }

    private var sections: [LibraryCategorySection] {
        homeViewModel.sections(
            readingStatus: viewModel.filters.readingStatus,
            excluding: queueStore.queuedArticleIds,
            categories: categoryStore
        )
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your library")
                        .font(Typography.sheetTitle)
                        .foregroundColor(themeManager.colors.text)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    if categoryStore.isRefining {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(themeManager.colors.accent)
                            Text("Sorting by topic…")
                                .font(Typography.meta)
                                .foregroundColor(themeManager.colors.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                filterBar
            }

            libraryBody
        }
    }

    @ViewBuilder
    private var libraryBody: some View {
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
        } else {
            let sections = self.sections
            if sections.isEmpty {
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
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(sections) { section in
                        CategoryShelfView(section: section, viewModel: homeViewModel)
                    }
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
                    .fill(themeManager.colors.sink)
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }
            .accessibilityHidden(true)

            Text(title)
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text(message)
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)

            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.figtree(15, weight: .bold))
                        .foregroundColor(themeManager.colors.page)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeManager.colors.accent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                FilterChip(
                    title: "All",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == nil,
                    action: { viewModel.setReadingStatusFilter(nil) }
                )

                FilterChip(
                    title: "Unread",
                    dotColor: themeManager.colors.accent2,
                    isSelected: viewModel.filters.readingStatus == .unread,
                    action: { viewModel.setReadingStatusFilter(.unread) }
                )

                FilterChip(
                    title: "Reading",
                    dotColor: themeManager.colors.accent,
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

// MARK: - Filter Chip

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
                    .font(Typography.figtree(13.5, weight: .semibold, relativeTo: .footnote))
            }
            .foregroundColor(isSelected ? themeManager.colors.page : themeManager.colors.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? themeManager.colors.text : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : themeManager.colors.line, lineWidth: 1)
            )
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
