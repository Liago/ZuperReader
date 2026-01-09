import SwiftUI
import Supabase
import Auth

struct RSSArticleListView: View {
    let feed: RSSFeed
    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showReadArticles = false // Default: hide read articles
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.colors.backgroundGradient
                .ignoresSafeArea()
            
                if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                let displayedArticles = articles.filter { showReadArticles || !$0.isRead }
                
                if displayedArticles.isEmpty {
                     if articles.isEmpty {
                        Text("No articles found.").foregroundColor(.gray)
                     } else {
                        Text("All articles read.").foregroundColor(.gray)
                     }
                } else {
                    List {
                        ForEach(Array(displayedArticles.enumerated()), id: \.element.id) { index, article in
                            // Find original index for binding if needed, or just pass value and handle updates via store
                            // For simplicity with array state, we need careful index management if we pass binding
                            // But RSSArticleReader marks as read via service and local update.
                            // Let's pass the correct binding from the main array.
                            
                            let originalIndex = articles.firstIndex(where: { $0.id == article.id }) ?? index
                            
                            RSSArticleRow(article: article)
                                .background(
                                    NavigationLink("", destination: RSSArticleReader(articles: $articles, initialIndex: originalIndex))
                                        .opacity(0)
                                )
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            await markAsRead(article: article, at: originalIndex)
                                        }
                                    } label: {
                                        Label("Mark as Read", systemImage: "envelope.open")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshFeed()
                    }
                }
            }
        }
        .navigationTitle(feed.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showReadArticles.toggle() }) {
                    Image(systemName: showReadArticles ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help(showReadArticles ? "Show Unread Only" : "Show All")
            }
        }
        .task {
            // Reset to unread only on load if that's the desired default behavior every time
            showReadArticles = false
            await loadArticles()
        }
    }
    
    private func refreshFeed() async {
        do {
            _ = try await RSSService.shared.refreshFeed(feedId: feed.id, url: feed.url)
            await loadArticles()
        } catch {
            print("Failed to refresh feed: \(error)")
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
        HStack(alignment: .top, spacing: 12) {
            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(width: 80, height: 60)
                .cornerRadius(6)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline)
                    .foregroundColor(article.isRead ? .gray : themeManager.colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true) // Prevents truncation issues
                
                if let snippet = article.contentSnippet {
                    Text(snippet)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                HStack {
                    if let date = article.pubDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
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
                VStack(spacing: 0) {
                    // Hero Image
                    if let imageUrl = currentArticle.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImageView(url: url.absoluteString, cornerRadius: 0)
                            .aspectRatio(1.5, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                                    startPoint: .bottom,
                                    endPoint: .center
                                )
                            )
                    } else {
                        // Placeholder
                        ZStack {
                            LinearGradient(
                                colors: [themeManager.colors.accent.opacity(0.8), themeManager.colors.accent.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 12) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white)
                                Text("SuperReader")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .aspectRatio(1.5, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Info
                        VStack(alignment: .leading, spacing: 12) {
                            // Metadata Badges (Domain + Date)
                            HStack(spacing: 8) {
                                if let domain = getDomain(from: currentArticle.link) {
                                    Text(domain)
                                        .font(.caption)
                                        .foregroundStyle(themeManager.colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(themeManager.colors.bgSecondary)
                                        .clipShape(Capsule())
                                }
                                
                                if let date = currentArticle.pubDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(themeManager.colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(themeManager.colors.bgSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text(currentArticle.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(themeManager.colors.textPrimary)
                                .lineLimit(nil)
                        }
                        
                        Divider()
                            .overlay(themeManager.colors.border)
                        
                        // Content
                        // Content
                        if displayedContent.isEmpty {
                            // Skeleton Loader
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(0..<8, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(themeManager.colors.bgSecondary)
                                        .frame(height: 16)
                                        .frame(maxWidth: index == 7 ? 200 : .infinity)
                                        .opacity(0.3)
                                }
                            }
                            .padding(.vertical, 8)
                            .task(id: currentArticle.id) {
                                loadContent()
                            }
                        } else {
                            Text(displayedContent)
                                .font(.body)
                                .foregroundStyle(themeManager.colors.textPrimary)
                                .lineSpacing(6)
                        }
                        
                        // Primary Action
                        if let originalUrl = URL(string: currentArticle.link) {
                            Link(destination: originalUrl) {
                                HStack {
                                    Text("Read Original")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.colors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: themeManager.colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(24)
                    .background(themeManager.colors.bgPrimary)
                    // Pull up content over image slightly if image exists
                    .offset(y: currentArticle.imageUrl != nil ? -20 : 0)
                    .cornerRadius(currentArticle.imageUrl != nil ? 24 : 0, corners: [.topLeft, .topRight])
                    
                    // Spacer for bottom safe area
                    Spacer().frame(height: 50)
                }
                .frame(width: geometry.size.width) // Fix: Constrain content width to screen width
                .id(currentIndex) // Move ID here to reset scroll position
            }
            .ignoresSafeArea(edges: .top)
            .background(themeManager.colors.bgPrimary)
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
                            // Swipe left to right (go to previous)
                            if value.translation.width > threshold && currentIndex > 0 {
                                currentIndex -= 1
                                resetState()
                                markAsRead()
                            }
                            // Swipe right to left (go to next)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Navigation Arrows
                HStack(spacing: 20) {
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
        }
        .overlay(alignment: .bottom) {
             if let msg = saveMessage {
                 Text(msg)
                     .font(.subheadline)
                     .fontWeight(.medium)
                     .padding(.horizontal, 16)
                     .padding(.vertical, 12)
                     .background(saveMessage == "Saved to Library" ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
                     .foregroundColor(.white)
                     .cornerRadius(20)
                     .shadow(radius: 4)
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
        displayedContent = ""
        loadContent()
    }
    
    private func loadContent() {
        if let content = currentArticle.content {
            let decoded = content.decodedHTML
            Task { @MainActor in
                withAnimation {
                    displayedContent = decoded
                }
            }
        } else {
            displayedContent = currentArticle.contentSnippet ?? ""
        }
    }

    private func markAsRead() {
        // Debounce or just fire and forget
        let articleToMark = articles[currentIndex]
        guard !articleToMark.isRead else { return }
        
        Task {
            guard let userId = AuthManager.shared.user?.id.uuidString else { return }
            try? await RSSService.shared.markArticleAsRead(articleId: articleToMark.id, userId: userId)
            // Update local state is handled via binding index access or main thread updates
            // Since we bind to array, we should update the array at current index
            if articles.indices.contains(currentIndex) {
                await MainActor.run {
                    articles[currentIndex].isRead = true
                    articles[currentIndex].readAt = Date()
                }
            }
        }
    }

    private func saveArticle() async {
        isSaving = true
        do {
             _ = try await SupabaseService.shared.saveRSSArticleWithParsing(currentArticle)
             await MainActor.run {
                 withAnimation {
                     isSaved = true
                     saveMessage = "Saved to Library"
                     let generator = UINotificationFeedbackGenerator()
                     generator.notificationOccurred(.success)
                 }
             }
        } catch {
             await MainActor.run {
                 withAnimation {
                     saveMessage = "Failed to save: \(error.localizedDescription)"
                 }
             }
        }
        isSaving = false
    }
    
    private func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host()?.replacingOccurrences(of: "www.", with: "")
    }
}
