import SwiftUI
import Combine

// MARK: - Article List ViewModel

@MainActor
class ArticleListViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var filters = ArticleFilters()
    @Published var sortOptions = ArticleSortOptions()
    
    private var userId: String?
    private var offset = 0
    private let limit = 10
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if let savedStatus = UserDefaults.standard.string(forKey: "savedReadingStatusFilter"),
           let status = ReadingStatus(rawValue: savedStatus) {
            filters.readingStatus = status
        }

        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.filters.searchQuery = query
                Task { @MainActor in
                    if let userId = self.userId {
                        await self.loadArticles(userId: userId)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    var filteredArticles: [Article] { articles }
    
    func loadArticles(userId: String) async {
        print("🔍 ViewModel: Loading articles for userId: \(userId)")
        self.userId = userId
        offset = 0
        if articles.isEmpty && !isLoading {
            isLoading = true
        }
        if errorMessage != nil {
            errorMessage = nil
        }
        
        do {
            let result = try await SupabaseService.shared.getArticles(
                userId: userId,
                limit: limit,
                offset: offset,
                filters: filters,
                sort: sortOptions
            )
            
            print("✅ ViewModel: Received \(result.articles.count) articles. Has more: \(result.hasMore)")
            articles = result.articles
            hasMore = result.hasMore
            offset = articles.count
        } catch {
            print("❌ ViewModel Error: \(error)")
            // Only set error message if we don't have cached articles, to avoid disrupting UX
            let nsError = error as NSError
            if !(error is CancellationError) && nsError.code != URLError.cancelled.rawValue {
                if articles.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        // Always ensuring loading is false at the end
        if isLoading {
            isLoading = false
        }
    }
    
    func loadMore() async {
        guard let userId = userId,
              !isLoadingMore,
              hasMore else { return }
        
        isLoadingMore = true
        
        do {
            let result = try await SupabaseService.shared.getArticles(
                userId: userId,
                limit: limit,
                offset: offset,
                filters: filters,
                sort: sortOptions
            )
            
            articles.append(contentsOf: result.articles)
            hasMore = result.hasMore
            offset = articles.count
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    func refresh() async {
        guard let userId = userId else { return }
        await loadArticles(userId: userId)
    }
    
    func toggleFavorite(_ article: Article) async {
        let newValue = !article.isFavorite

        // Optimistic update
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            var updatedArticle = articles[index]
            updatedArticle = Article(
                id: updatedArticle.id,
                userId: updatedArticle.userId,
                url: updatedArticle.url,
                title: updatedArticle.title,
                content: updatedArticle.content,
                excerpt: updatedArticle.excerpt,
                imageUrl: updatedArticle.imageUrl,
                faviconUrl: updatedArticle.faviconUrl,
                author: updatedArticle.author,
                publishedDate: updatedArticle.publishedDate,
                domain: updatedArticle.domain,
                tags: updatedArticle.tags,
                isFavorite: newValue,
                likeCount: updatedArticle.likeCount,
                commentCount: updatedArticle.commentCount,
                readingStatus: updatedArticle.readingStatus,
                estimatedReadTime: updatedArticle.estimatedReadTime,
                isPublic: updatedArticle.isPublic,
                scrapedAt: updatedArticle.scrapedAt,
                aiSummary: updatedArticle.aiSummary,
                aiSummaryGeneratedAt: updatedArticle.aiSummaryGeneratedAt,
                createdAt: updatedArticle.createdAt,
                updatedAt: updatedArticle.updatedAt
            )
            articles[index] = updatedArticle
        }
        
        do {
            try await SupabaseService.shared.toggleFavorite(articleId: article.id, isFavorite: newValue)
        } catch {
            // Revert on error
            if let index = articles.firstIndex(where: { $0.id == article.id }) {
                var updatedArticle = articles[index]
                updatedArticle = Article(
                    id: updatedArticle.id,
                    userId: updatedArticle.userId,
                    url: updatedArticle.url,
                    title: updatedArticle.title,
                    content: updatedArticle.content,
                    excerpt: updatedArticle.excerpt,
                    imageUrl: updatedArticle.imageUrl,
                    faviconUrl: updatedArticle.faviconUrl,
                    author: updatedArticle.author,
                    publishedDate: updatedArticle.publishedDate,
                    domain: updatedArticle.domain,
                    tags: updatedArticle.tags,
                    isFavorite: !newValue,
                    likeCount: updatedArticle.likeCount,
                    commentCount: updatedArticle.commentCount,
                    readingStatus: updatedArticle.readingStatus,
                    estimatedReadTime: updatedArticle.estimatedReadTime,
                    isPublic: updatedArticle.isPublic,
                    scrapedAt: updatedArticle.scrapedAt,
                    aiSummary: updatedArticle.aiSummary,
                    aiSummaryGeneratedAt: updatedArticle.aiSummaryGeneratedAt,
                    createdAt: updatedArticle.createdAt,
                    updatedAt: updatedArticle.updatedAt
                )
                articles[index] = updatedArticle
            }
        }
    }
    
    func deleteArticle(_ article: Article) async {
        // Optimistic delete
        articles.removeAll { $0.id == article.id }
        
        do {
            try await SupabaseService.shared.deleteArticle(articleId: article.id)
        } catch {
            errorMessage = "Failed to delete article"
            await refresh()
        }
    }
    
    func setReadingStatusFilter(_ status: ReadingStatus?) {
        filters.readingStatus = status
        
        if let status = status {
            UserDefaults.standard.set(status.rawValue, forKey: "savedReadingStatusFilter")
        } else {
            UserDefaults.standard.removeObject(forKey: "savedReadingStatusFilter")
        }
        
        Task {
            if let userId = userId {
                await loadArticles(userId: userId)
            }
        }
    }
}

// MARK: - Article List View

struct ArticleListView: View {
    @ObservedObject var viewModel: ArticleListViewModel
    @EnvironmentObject var themeManager: ThemeManager
    var onAddArticle: () -> Void = {}

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.articles.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.articles.isEmpty {
                emptyView
            } else if themeManager.viewMode == .grid {
                gridView
            } else {
                listView
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            if themeManager.viewMode == .grid {
                LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        ArticleCardSkeleton()
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
            } else {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(0..<6, id: \.self) { _ in
                        ArticleRowSkeleton()
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(themeManager.colors.accent)
            Text("Error loading articles")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)
            Text(message)
                .font(Typography.figtree(13))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .font(Typography.figtree(15, weight: .bold))
            .foregroundColor(themeManager.colors.page)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: "book.closed")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }

            Text("No articles yet")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("Add your first article by tapping the + button above")
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)

            Button(action: onAddArticle) {
                Text("Add article")
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                ForEach(viewModel.filteredArticles) { article in
                    NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                        ArticleCardView(
                            article: article,
                            onFavorite: { Task { await viewModel.toggleFavorite(article) } },
                            onDelete: { Task { await viewModel.deleteArticle(article) } }
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Load more trigger
                if viewModel.hasMore {
                    ProgressView()
                        .tint(themeManager.colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onAppear {
                            Task { await viewModel.loadMore() }
                        }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - List View

    private var groupedArticles: [(label: String, articles: [Article])] {
        let calendar = Calendar.current
        var today: [Article] = []
        var thisWeek: [Article] = []
        var older: [Article] = []

        for article in viewModel.filteredArticles {
            guard let date = article.createdAtDate else {
                older.append(article)
                continue
            }
            if calendar.isDateInToday(date) {
                today.append(article)
            } else if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days <= 7 {
                thisWeek.append(article)
            } else {
                older.append(article)
            }
        }

        var groups: [(String, [Article])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !thisWeek.isEmpty { groups.append(("Earlier this week", thisWeek)) }
        if !older.isEmpty { groups.append(("Older", older)) }
        return groups
    }

    private var listView: some View {
        List {
            ForEach(groupedArticles, id: \.label) { group in
                Section {
                    ForEach(group.articles) { article in
                        ZStack {
                            NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                                EmptyView()
                            }
                            .opacity(0)

                            ArticleRowView(article: article)
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
                            Button {
                                Task { await viewModel.toggleFavorite(article) }
                            } label: {
                                Label(
                                    article.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: article.isFavorite ? "heart.slash" : "heart"
                                )
                            }
                            .tint(themeManager.colors.accent)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteArticle(article) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                Task { await viewModel.toggleFavorite(article) }
                            } label: {
                                Label(
                                    article.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: article.isFavorite ? "heart.slash" : "heart"
                                )
                            }
                            if let url = URL(string: article.url) {
                                ShareLink(item: url) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.deleteArticle(article) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.label.uppercased())
                        .font(Typography.figtree(12.5, weight: .bold))
                        .foregroundColor(themeManager.colors.muted)
                        .textCase(nil)
                }
            }

            // Load more trigger
            if viewModel.hasMore {
                HStack {
                    Spacer()
                    ProgressView().tint(themeManager.colors.accent)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onAppear {
                    Task { await viewModel.loadMore() }
                }
            }

            Color.clear
                .frame(height: Spacing.scrollBottomInset)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.colors.page)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

#Preview {
    NavigationStack {
        ArticleListView(viewModel: ArticleListViewModel())
        .environmentObject(ThemeManager.shared)
    }
}
