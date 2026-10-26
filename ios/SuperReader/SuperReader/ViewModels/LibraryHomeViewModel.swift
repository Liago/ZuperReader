import Foundation
import Combine

// MARK: - Library Category Section

/// One shelf of the home: the Library articles of a category.
struct LibraryCategorySection: Identifiable {
    let category: ArticleCategory
    let articles: [Article]

    var id: String { category.rawValue }
}

// MARK: - Library Home ViewModel
//
// Data behind the home: the whole Library in a light form (no body), grouped
// into category shelves by `ArticleCategoryStore`. Articles already in
// "Up next" are shown in the queue section only, not on the shelves.

@MainActor
final class LibraryHomeViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private var userId: String?

    // MARK: Loading

    func load(userId: String) async {
        self.userId = userId
        if articles.isEmpty && !hasLoaded { isLoading = true }
        errorMessage = nil

        do {
            let fetched = try await SupabaseService.shared.getLibraryOverview(userId: userId)
            articles = fetched
            hasLoaded = true

            let categoryStore = ArticleCategoryStore.shared
            categoryStore.prune(keeping: Set(fetched.map(\.id)))
            categoryStore.categorize(fetched)
        } catch {
            let nsError = error as NSError
            if !(error is CancellationError) && nsError.code != URLError.cancelled.rawValue {
                print("Failed to load library overview: \(error)")
                if articles.isEmpty { errorMessage = error.localizedDescription }
            }
        }

        isLoading = false
    }

    func refresh() async {
        guard let userId else { return }
        await load(userId: userId)
    }

    // MARK: Grouping

    /// Shelves with at least one article, biggest first ("Other" always last).
    func sections(
        readingStatus: ReadingStatus?,
        excluding queuedIds: Set<String>,
        categories: ArticleCategoryStore
    ) -> [LibraryCategorySection] {
        var grouped: [ArticleCategory: [Article]] = [:]
        for article in visibleArticles(readingStatus: readingStatus, excluding: queuedIds) {
            grouped[categories.category(for: article) ?? .other, default: []].append(article)
        }

        return grouped
            .map { LibraryCategorySection(category: $0.key, articles: $0.value) }
            .sorted { lhs, rhs in
                if (lhs.category == .other) != (rhs.category == .other) { return rhs.category == .other }
                if lhs.articles.count != rhs.articles.count { return lhs.articles.count > rhs.articles.count }
                return lhs.category.sortRank < rhs.category.sortRank
            }
    }

    func articles(
        in category: ArticleCategory,
        readingStatus: ReadingStatus?,
        excluding queuedIds: Set<String>,
        categories: ArticleCategoryStore
    ) -> [Article] {
        visibleArticles(readingStatus: readingStatus, excluding: queuedIds)
            .filter { (categories.category(for: $0) ?? .other) == category }
    }

    /// Library articles outside "Up next" matching the reading-status filter.
    func visibleArticles(readingStatus: ReadingStatus?, excluding queuedIds: Set<String>) -> [Article] {
        articles.filter { article in
            !queuedIds.contains(article.id) && (readingStatus == nil || article.readingStatus == readingStatus)
        }
    }

    // MARK: Actions

    func toggleFavorite(_ article: Article) async {
        guard let index = articles.firstIndex(where: { $0.id == article.id }) else { return }
        let newValue = !articles[index].isFavorite
        articles[index].isFavorite = newValue

        do {
            try await SupabaseService.shared.toggleFavorite(articleId: article.id, isFavorite: newValue)
        } catch {
            print("Failed to toggle favorite: \(error)")
            if let index = articles.firstIndex(where: { $0.id == article.id }) {
                articles[index].isFavorite = !newValue
            }
        }
    }

    func delete(_ article: Article) async {
        let previous = articles
        articles.removeAll { $0.id == article.id }
        ReadingQueueStore.shared.removeLocally(articleId: article.id)

        do {
            try await SupabaseService.shared.deleteArticle(articleId: article.id)
        } catch {
            print("Failed to delete article: \(error)")
            articles = previous
            await ReadingQueueStore.shared.refresh()
        }
    }

    func addToQueue(_ article: Article) async {
        guard let userId else { return }
        await ReadingQueueStore.shared.add(articleId: article.id, userId: userId)
    }

    func move(_ article: Article, to category: ArticleCategory) {
        ArticleCategoryStore.shared.setCategory(category, for: article)
    }
}
