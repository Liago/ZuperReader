import SwiftUI
import Supabase
import Auth

struct RSSArticleListView: View {
    let feed: RSSFeed
    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @EnvironmentObject var themeManager: ThemeManager
    
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
                    ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                        NavigationLink(destination: RSSArticleReader(articles: articles, initialIndex: index)) {
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

struct RSSArticleReader: View {
    let articles: [RSSArticle]
    @State private var currentIndex: Int
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isSaving = false
    @State private var isSaved = false
    @State private var saveMessage: String?
    
    init(articles: [RSSArticle], initialIndex: Int) {
        self.articles = articles
        _currentIndex = State(initialValue: initialIndex)
    }
    
    var currentArticle: RSSArticle {
        articles[currentIndex]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentArticle.title)
                    .font(.title)
                    .bold()
                
                if let imageUrl = currentArticle.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                }
                
                // Clean HTML content
                Text(currentArticle.content?.decodedHTML ?? currentArticle.contentSnippet ?? "")
                    .font(.body)
                    .lineSpacing(4)
                
                Link("Read Original", destination: URL(string: currentArticle.link)!)
                    .padding()
            }
            .padding()
        }
        .navigationTitle(currentArticle.title) // Updates navbar title
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Previous
                Button(action: {
                    withAnimation {
                        if currentIndex > 0 {
                            currentIndex -= 1
                            resetState()
                            markAsRead()
                        }
                    }
                }) {
                    Image(systemName: "chevron.up")
                }
                .disabled(currentIndex == 0)
                
                // Next
                Button(action: {
                    withAnimation {
                        if currentIndex < articles.count - 1 {
                            currentIndex += 1
                            resetState()
                            markAsRead()
                        }
                    }
                }) {
                    Image(systemName: "chevron.down")
                }
                .disabled(currentIndex == articles.count - 1)
                
                // Save
                Button(action: {
                    Task { await saveArticle() }
                }) {
                    if isSaving {
                         ProgressView()
                    } else {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isSaved ? .green : .accentColor)
                    }
                }
                .disabled(isSaving || isSaved)
            }
        }
        .overlay(alignment: .bottom) {
             if let msg = saveMessage {
                 Text(msg)
                     .padding()
                     .background(Color.green.opacity(0.9))
                     .foregroundColor(.white)
                     .cornerRadius(8)
                     .padding(.bottom, 20)
                     .transition(.move(edge: .bottom).combined(with: .opacity))
                     .onAppear {
                         DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                             withAnimation { saveMessage = nil }
                         }
                     }
             }
        }
        .onAppear {
             markAsRead()
        }
        .id(currentIndex) // Force refresh scrollview when index changes
    }
    
    private func resetState() {
        isSaved = false
        saveMessage = nil
    }
    
    private func markAsRead() {
        let article = currentArticle
        Task {
            guard let userId = AuthManager.shared.user?.id.uuidString else { return }
            try? await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
        }
    }
    
    private func saveArticle() async {
        isSaving = true
        do {
             _ = try await SupabaseService.shared.saveRSSArticle(currentArticle)
             withAnimation {
                 isSaved = true
                 saveMessage = "Saved to Library"
             }
        } catch {
             saveMessage = "Failed to save"
        }
        isSaving = false
    }
}
