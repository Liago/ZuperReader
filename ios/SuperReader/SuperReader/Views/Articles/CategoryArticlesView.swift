import SwiftUI

// MARK: - Library Articles Scope

/// What a `CategoryArticlesView` page lists.
enum LibraryArticlesScope: Hashable {
    /// "See all" of a home shelf: one category, Up next items excluded.
    case category(ArticleCategory)
    /// "All articles": the whole Library, Up next included, newest save first,
    /// grouped by when it was saved.
    case all
}

// MARK: - Category Articles ("See all" of a home shelf / "All articles")
//
// The Library articles of one scope, honouring the home's reading-status
// filter and list/grid mode.

struct CategoryArticlesView: View {
    let scope: LibraryArticlesScope
    @ObservedObject var viewModel: LibraryHomeViewModel

    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("savedReadingStatusFilter") private var savedStatusFilter: String = ""

    private let gridColumns = [GridItem(.flexible(), spacing: Spacing.md)]

    init(category: ArticleCategory, viewModel: LibraryHomeViewModel) {
        self.init(scope: .category(category), viewModel: viewModel)
    }

    init(scope: LibraryArticlesScope, viewModel: LibraryHomeViewModel) {
        self.scope = scope
        self.viewModel = viewModel
    }

    private var readingStatus: ReadingStatus? {
        ReadingStatus(rawValue: savedStatusFilter)
    }

    private var articles: [Article] {
        switch scope {
        case .category(let category):
            return viewModel.articles(
                in: category,
                readingStatus: readingStatus,
                excluding: queueStore.queuedArticleIds,
                categories: categoryStore
            )
        case .all:
            return viewModel.allArticles(readingStatus: readingStatus)
        }
    }

    /// Category pages are one untitled block; "All articles" is split by save date.
    private var groups: [SavedDateGroup] {
        switch scope {
        case .category:
            return [SavedDateGroup(title: nil, articles: articles)]
        case .all:
            return SavedDateGroup.grouping(articles)
        }
    }

    private var title: String {
        switch scope {
        case .category(let category): return category.displayName
        case .all: return "All articles"
        }
    }

    private var icon: String {
        switch scope {
        case .category(let category): return category.icon
        case .all: return "tray.full"
        }
    }

    var body: some View {
        ZStack {
            themeManager.colors.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if articles.isEmpty {
                    emptyView
                } else if themeManager.viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                IconCircleButton(systemImage: "chevron.backward", label: "Back") {
                    dismiss()
                }
                Spacer()

                // Same toggle as the home header: the glyph shows the mode a tap switches to.
                IconCircleButton(
                    systemImage: themeManager.viewMode == .list ? "square.grid.2x2.fill" : "list.bullet",
                    label: themeManager.viewMode == .list ? "Switch to grid view" : "Switch to list view"
                ) {
                    themeManager.toggleViewMode()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(countLabel)
                    .font(Typography.figtree(11, weight: .bold))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundColor(themeManager.colors.muted)

                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(Typography.symbol(20, weight: .bold))
                        .foregroundColor(themeManager.colors.accent800)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(Typography.largeTitle)
                        .foregroundColor(themeManager.colors.text)
                }

                Text(subtitle)
                    .font(Typography.figtree(13.5))
                    .lineSpacing(3)
                    .foregroundColor(themeManager.colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var subtitle: String {
        switch scope {
        case .category:
            return "Sorted automatically by topic. Long-press an article and choose “Move to…” to change it."
        case .all:
            return "Everything you saved, newest first — Up next included."
        }
    }

    private var countLabel: String {
        let n = articles.count
        var label = "\(n) \(n == 1 ? "article" : "articles")"
        if let readingStatus {
            label += " · \(readingStatus.displayName)"
        }
        return label
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.figtree(11, weight: .bold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundColor(themeManager.colors.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.articles) { article in
                        listRow(for: article)
                    }
                } header: {
                    if let title = group.title {
                        groupHeader(title)
                            .padding(.top, Spacing.sm)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: Spacing.screenHorizontal,
                                bottom: 6,
                                trailing: Spacing.screenHorizontal
                            ))
                    }
                }
            }

            Color.clear
                .frame(height: Spacing.scrollBottomInset)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .background(themeManager.colors.page)
        .refreshable { await viewModel.refresh() }
    }

    private func listRow(for article: Article) -> some View {
        ZStack {
            NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                EmptyView()
            }
            .opacity(0)

            ArticleRowView(article: article, queueState: queueState(for: article))
        }
        .listRowInsets(EdgeInsets(
            top: 0,
            leading: Spacing.screenHorizontal,
            bottom: 0,
            trailing: Spacing.screenHorizontal
        ))
        .listRowSeparatorTint(themeManager.colors.line)
        .listRowBackground(themeManager.colors.page)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if queueState(for: article) == nil {
                Button {
                    Task { await viewModel.addToQueue(article) }
                } label: {
                    Label("Up next", systemImage: "text.badge.plus")
                }
                .tint(themeManager.colors.accent2)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.delete(article) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu { menuItems(for: article) }
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.articles) { article in
                            NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                                ArticleCardView(
                                    article: article,
                                    queueState: queueState(for: article),
                                    onFavorite: { Task { await viewModel.toggleFavorite(article) } },
                                    onAddToQueue: { Task { await viewModel.addToQueue(article) } },
                                    onDelete: { Task { await viewModel.delete(article) } },
                                    currentCategory: categoryStore.category(for: article),
                                    onMoveToCategory: { viewModel.move(article, to: $0) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        if let title = group.title {
                            groupHeader(title)
                                .padding(.top, Spacing.sm)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func menuItems(for article: Article) -> some View {
        LibraryArticleMenuItems(
            article: article,
            currentCategory: categoryStore.category(for: article),
            queueState: queueState(for: article),
            onFavorite: { Task { await viewModel.toggleFavorite(article) } },
            onAddToQueue: { Task { await viewModel.addToQueue(article) } },
            onMove: { viewModel.move(article, to: $0) },
            onDelete: { Task { await viewModel.delete(article) } }
        )
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }

            Text("Nothing here right now")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text(emptyMessage)
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        switch scope {
        case .category:
            return "Articles of this topic moved elsewhere, went to Up next or don't match the current filter."
        case .all:
            return readingStatus == nil
                ? "Save your first link with the + button on the Library."
                : "No articles match the current filter."
        }
    }

    private func queueState(for article: Article) -> QueueActionState? {
        if queueStore.isPending(article.id) { return .saving }
        if queueStore.isQueued(article.id) { return .done }
        return nil
    }
}

// MARK: - Saved Date Group

/// A run of articles saved in the same period ("Today", "This week", "March 2026"…).
private struct SavedDateGroup: Identifiable {
    let title: String?
    let articles: [Article]

    var id: String { title ?? "all" }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    private static let fallbackParser = ISO8601DateFormatter()

    /// Keeps the incoming order (newest first) and starts a new group whenever the period changes.
    static func grouping(_ articles: [Article], now: Date = Date()) -> [SavedDateGroup] {
        var groups: [SavedDateGroup] = []
        var currentTitle: String?
        var current: [Article] = []

        for article in articles {
            let title = periodTitle(for: savedDate(of: article), now: now)
            if title != currentTitle, !current.isEmpty {
                groups.append(SavedDateGroup(title: currentTitle, articles: current))
                current = []
            }
            currentTitle = title
            current.append(article)
        }
        if !current.isEmpty {
            groups.append(SavedDateGroup(title: currentTitle, articles: current))
        }
        return groups
    }

    private static func savedDate(of article: Article) -> Date? {
        article.createdAtDate ?? fallbackParser.date(from: article.createdAt)
    }

    private static func periodTitle(for date: Date?, now: Date) -> String {
        guard let date else { return "Earlier" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return "This week" }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) { return "This month" }
        return monthFormatter.string(from: date)
    }
}
