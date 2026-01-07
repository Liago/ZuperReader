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
                        RSSArticleRow(article: article)
                            .background(
                                NavigationLink("", destination: RSSArticleReader(articles: $articles, initialIndex: index))
                                    .opacity(0)
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task {
                                        await markAsRead(article: article, at: index)
                                    }
                                } label: {
                                    Label(article.isRead ? "Read" : "Mark as Read", systemImage: "envelope.open")
                                }
                                .tint(article.isRead ? .gray : .blue)
                                .disabled(article.isRead)
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
            self.articles = try await RSSService.shared.getArticles(userId: userId, feedId: feed.id, includeRead: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func markAsRead(article: RSSArticle, at index: Int) async {
        guard let userId = AuthManager.shared.user?.id.uuidString else { return }
        do {
            try await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
            // Update local state
            var updatedArticle = article
            updatedArticle.isRead = true
            updatedArticle.readAt = Date()
            articles[index] = updatedArticle
        } catch {
            print("Failed to mark article as read: \(error)")
        }
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
    @Binding var articles: [RSSArticle]
    let initialIndex: Int
    @State private var currentIndex: Int = 0
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var isSaving = false
    @State private var isSaved = false
    @State private var saveMessage: String?
    @State private var dragOffset: CGFloat = 0
    @State private var hasInitialized = false
    @State private var displayedContent: String = ""

    var currentArticle: RSSArticle {
        if articles.indices.contains(currentIndex) {
            return articles[currentIndex]
        }
        return articles[0] // Fallback
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if articles.indices.contains(currentIndex) {
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
                    Text(displayedContent.isEmpty ? (currentArticle.contentSnippet ?? "") : displayedContent)
                        .font(.body)
                        .lineSpacing(4)
                        .task(id: currentArticle.id) {
                            if let content = currentArticle.content {
                                // Decode off main actor if possible, but NSAttributedString might need main thread.
                                // However, putting it in a task allows the view update to finish *before* this runs.
                                let decoded = content.decodedHTML
                                await MainActor.run {
                                    withAnimation {
                                        displayedContent = decoded
                                    }
                                }
                            } else {
                                displayedContent = currentArticle.contentSnippet ?? ""
                            }
                        }

                    if let originalUrl = URL(string: currentArticle.link) {
                        Link("Read Original", destination: originalUrl)
                            .padding()
                    }
                }
                .padding()
                .id(currentIndex) // Move ID here to reset scroll position but keep view identity
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow horizontal swipe
                        if abs(value.translation.width) > abs(value.translation.height) {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = geometry.size.width * 0.25

                        withAnimation(.easeOut(duration: 0.2)) {
                            // Swipe left to right (go to previous article)
                            if value.translation.width > threshold && currentIndex > 0 {
                                currentIndex -= 1
                                resetState()
                                markAsRead()
                            }
                            // Swipe right to left (go to next article)
                            else if value.translation.width < -threshold && currentIndex < articles.count - 1 {
                                currentIndex += 1
                                resetState()
                                markAsRead()
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .navigationTitle(articles.indices.contains(currentIndex) ? currentArticle.title : "")
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
                     .background(saveMessage == "Saved to Library" ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
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
             if !hasInitialized {
                 currentIndex = initialIndex
                 hasInitialized = true
             }
             markAsRead()
        }
    }

    private func resetState() {
        isSaved = false
        saveMessage = nil
    }

    private func markAsRead() {
        Task {
            guard let userId = AuthManager.shared.user?.id.uuidString else { return }
            try? await RSSService.shared.markArticleAsRead(articleId: articles[currentIndex].id, userId: userId)
            // Update local state
            articles[currentIndex].isRead = true
            articles[currentIndex].readAt = Date()
        }
    }

    private func saveArticle() async {
        isSaving = true
        do {
             _ = try await SupabaseService.shared.saveRSSArticleWithParsing(currentArticle)
             withAnimation {
                 isSaved = true
                 saveMessage = "Saved to Library"
             }
        } catch {
             withAnimation {
                 saveMessage = "Failed to save: \(error.localizedDescription)"
             }
        }
        isSaving = false
    }
}
