import SwiftUI
import Supabase
import Auth

struct RSSArticleListView: View {
    let feed: RSSFeed
    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @EnvironmentObject var themeManager: ThemeManager
    
    // We reuse the ArticleReader view if exists, or a simple WebLink
    
    var body: some View {
        ZStack {
            themeManager.colors.backgroundGradient
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red)
            } else if articles.isEmpty {
                Text("No articles found.")
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(articles) { article in
                        NavigationLink(destination: RSSArticleReader(article: article)) {
                           RSSArticleRow(article: article)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadArticles()
                }
            }
        }
        .navigationTitle(feed.title)
        .task {
            await loadArticles()
        }
    }
    
    private func loadArticles() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let userId = AuthManager.shared.user?.id.uuidString else { return }
            self.articles = try await RSSService.shared.getArticles(userId: userId, feedId: feed.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct RSSArticleRow: View {
    let article: RSSArticle
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
                .foregroundColor(article.isRead ? .gray : themeManager.colors.textPrimary)
                .lineLimit(2)
            
            if let snippet = article.contentSnippet {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
            }
            
            HStack {
                if let date = article.pubDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// Simple Reader Placeholder or real implementation
struct RSSArticleReader: View {
    let article: RSSArticle
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        // Here we could use a Webview or native parser display.
        // For feature parity, web has "Reader Mode" or "Link".
        // Let's assume we pass the link to a WebView for now or parsing logic?
        // Web uses `ReaderModal` which displays parsed content.
        // We have `NavigationStack` so pushing a view is better.
        
        // We will just show content formatted lightly or WebView.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title)
                    .bold()
                
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                }
                
                Text(article.content ?? article.contentSnippet ?? "")
                    .font(.body)
                
                Link("Read Original", destination: URL(string: article.link)!)
                    .padding()
            }
            .padding()
        }
        .onAppear {
             markAsRead()
        }
    }
    
    private func markAsRead() {
        Task {
            guard let userId = AuthManager.shared.user?.id.uuidString else { return }
            try? await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
        }
    }
}
