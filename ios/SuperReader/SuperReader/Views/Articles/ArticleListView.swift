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
    private var searchDebounceTask: Task<Void, Never>?
    
    init() {
        if let savedStatus = UserDefaults.standard.string(forKey: "savedReadingStatusFilter"),
           let status = ReadingStatus(rawValue: savedStatus) {
            filters.readingStatus = status
        }
    }
    
    var filteredArticles: [Article] {
        guard !searchQuery.isEmpty else { return articles }
        
        let query = searchQuery.lowercased()
        return articles.filter { article in
            article.title.lowercased().contains(query) ||
            (article.excerpt?.lowercased().contains(query) ?? false) ||
            (article.domain?.lowercased().contains(query) ?? false)
        }
    }
    
    func loadArticles(userId: String) async {
        print("🔍 ViewModel: Loading articles for userId: \(userId)")
        self.userId = userId
        offset = 0
        if articles.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
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
            if articles.isEmpty {
                errorMessage = error.localizedDescription
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
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md)
    ]
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.articles.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    Text("Error loading articles")
                    .font(.headline)
                    Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.refresh() }
                    }
                    .padding()
                }
                .padding()
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
                .padding(Spacing.md)
            } else {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(0..<6, id: \.self) { _ in
                        ArticleRowSkeleton()
                    }
                }
                .padding(Spacing.md)
            }
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "newspaper")
            .font(.system(size: 60))
            .foregroundColor(themeManager.colors.textSecondary.opacity(0.5))
            
            Text("No articles yet")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(themeManager.colors.textPrimary)
            
            Text("Add your first article by tapping the + button above")
            .font(.system(size: 15))
            .foregroundColor(themeManager.colors.textSecondary)
            .multilineTextAlignment(.center)
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
                    .frame(maxWidth: .infinity)
                    .padding()
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        ScrollView {
            // Request 2: Ridotto spazio tra card (Spacing.sm o anche 8/10)
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredArticles) { article in
                    NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                        ArticleRowView(
                            article: article,
                            onFavorite: { Task { await viewModel.toggleFavorite(article) } }
                        )
                    }
                    .buttonStyle(.plain) // Request 1: Togli simbolo > (rimosso stile navigazione List)
                    .contextMenu {
                         Button(role: .destructive) {
                             Task { await viewModel.deleteArticle(article) }
                         } label: {
                             Label("Delete", systemImage: "trash")
                         }
                    }
                }
                
                // Load more trigger
                if viewModel.hasMore {
                    ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
                }
            }
            .padding(10) // Padding uniforme esterno
        }
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
