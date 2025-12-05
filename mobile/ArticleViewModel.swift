import Foundation
import Combine

class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // TODO: Replace with actual authenticated user ID
    let userId = "test-user-id"
    
    func loadArticles() {
        isLoading = true
        errorMessage = nil
        
        SupabaseService.shared.fetchArticles(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let articles):
                    self?.articles = articles
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func addArticle(url: String) {
        isLoading = true
        errorMessage = nil
        
        // Step 1: Parse the URL
        SupabaseService.shared.parseUrl(url) { [weak self] result in
            switch result {
            case .success(let parsedData):
                // Step 2: Save to Supabase
                SupabaseService.shared.saveArticle(parsedData: parsedData, userId: self?.userId ?? "") { saveResult in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        switch saveResult {
                        case .success:
                            self?.loadArticles()
                        case .failure(let error):
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteArticle(_ article: Article) {
        SupabaseService.shared.deleteArticle(articleId: article.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.articles.removeAll { $0.id == article.id }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func toggleFavorite(_ article: Article) {
        let newValue = !article.is_favorite
        SupabaseService.shared.toggleFavorite(articleId: article.id, isFavorite: newValue) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self?.articles.firstIndex(where: { $0.id == article.id }) {
                        // Reload to get updated article
                        self?.loadArticles()
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
