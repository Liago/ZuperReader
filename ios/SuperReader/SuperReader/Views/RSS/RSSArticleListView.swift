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
                    ScrollView {
                        VStack(spacing: 20) {
                            if articles.isEmpty {
                                Text("No articles found.").foregroundColor(.gray)
                            } else {
                                Text("All articles read.").foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100) // Give some space
                    }
                    .refreshable {
                        await refreshFeed()
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
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await refreshFeed()
                    }
                }
            }
        }

        .navigationTitle(feed.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(feed.url)&sz=128")) { phase in
                         switch phase {
                         case .success(let image):
                             image.resizable().aspectRatio(contentMode: .fit).frame(width: 24, height: 24).clipShape(Circle())
                         default: EmptyView()
                         }
                    }
                    Button(action: { showReadArticles.toggle() }) {
                        Image(systemName: showReadArticles ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .help(showReadArticles ? "Show Unread Only" : "Show All")
                }
            }
        }
        .task {
            // Reset to unread only on load if that's the desired default behavior every time
            showReadArticles = false
            await loadArticles(showLoadingIndicator: true)
        }
    }
    
    private func refreshFeed() async {
        do {
            _ = try await RSSService.shared.refreshFeed(feedId: feed.id, url: feed.url)
            await loadArticles(showLoadingIndicator: false) // Don't show full screen loader on refresh
        } catch {
            print("Failed to refresh feed: \(error)")
        }
    }
    
    private func loadArticles(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            isLoading = true
        }
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
                    Text(snippet.strippingHTML())
                        .font(.subheadline)
                        .foregroundColor(themeManager.colors.textSecondary)
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
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(themeManager.colors.border)
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
    @State private var hasInitialized = false
    @State private var displayedContent: String = ""
    
    // Track vertical drag for dismissal
    @State private var dragOffset: CGSize = .zero

    var currentArticle: RSSArticle {
        if articles.indices.contains(currentIndex) {
            return articles[currentIndex]
        }
        return articles[0]
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(articles.indices, id: \.self) { index in
                RSSArticleDetailView(
                    article: articles[index],
                    displayedContent: index == currentIndex ? displayedContent : "", // Only show content for active
                    themeManager: themeManager,
                    loadContentAction: {
                        if index == currentIndex { loadContent() }
                    }
                )
                .tag(index)
                // Add a transparent overlay to catch swipes slightly better if needed, 
                // but TabView usually handles horizontal well.
                // We add the vertical drag gesture here or on the parent.
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(themeManager.colors.bgPrimary)
        .ignoresSafeArea(edges: .top) // TabView itself ignores top
        .navigationBarTitleDisplayMode(.inline)
        // Toolbar controls
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Navigation Arrows
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            if currentIndex > 0 {
                                currentIndex -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.up") // Up for previous? User asked for previous/next. 
                        // Usually up/down arrows in RSS readers mean "Previous Article" (Up) and "Next Article" (Down) in the list context.
                        // Or Left/Right. existing code used chevron.up/down. I'll keep them as they map to list order.
                    }
                    .disabled(currentIndex == 0)

                    Button(action: {
                        withAnimation {
                            if currentIndex < articles.count - 1 {
                                currentIndex += 1
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
             markAsRead() // Mark initial article
        }
        .onChange(of: currentIndex) { _ in
            resetState()
            markAsRead()
        }
        .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
        // Swipe Down Gesture to Dismiss
        // Use simultaneousGesture to allow it to work alongside ScrollView
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    // Only track if mainly vertical and downwards
                    if value.translation.height > 0 && abs(value.translation.width) < value.translation.height {
                        // Dampen the drag a bit
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 && abs(value.translation.width) < value.translation.height {
                         dismiss()
                    }
                    withAnimation {
                        dragOffset = .zero
                    }
                }
        )
        // Animate the view down if dragging?
        // It's tricky with native NavigationStack push. We'll just trigger dismiss.
    }

    private func resetState() {
        isSaved = false
        saveMessage = nil
        displayedContent = ""
        loadContent()
    }
    
    private func loadContent() {
        let article = currentArticle // use local access
        if let content = article.content {
            let decoded = content.decodedHTML
            Task { @MainActor in
                // Small delay to allow transition to start smoothly
                // try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation {
                    displayedContent = decoded
                }
            }
        } else {
            displayedContent = article.contentSnippet ?? ""
        }
    }

    private func markAsRead() {
        let index = currentIndex
        guard articles.indices.contains(index) else { return }
        let articleToMark = articles[index]
        guard !articleToMark.isRead else { return }
        
        Task {
            guard let userId = AuthManager.shared.user?.id.uuidString else { return }
            try? await RSSService.shared.markArticleAsRead(articleId: articleToMark.id, userId: userId)
            
            if articles.indices.contains(index) {
                await MainActor.run {
                    articles[index].isRead = true
                    articles[index].readAt = Date()
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
    
    // Helper needed for the subview? No, moved logic to view or parent.
    // We can't access getDomain easily inside the subview unless we pass it or make it static/helper.
    // Let's duplicate or make static.
    private func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host()?.replacingOccurrences(of: "www.", with: "")
    }
}

// Extracted Subview for cleaner TabView loop
struct RSSArticleDetailView: View {
    let article: RSSArticle
    let displayedContent: String
    let themeManager: ThemeManager
    let loadContentAction: () -> Void
    @State private var showSafariView = false


    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image
                    if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
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
                                if let domain = getDomain(from: article.link) {
                                    Text(domain)
                                        .font(.caption)
                                        .foregroundStyle(themeManager.colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(themeManager.colors.bgSecondary)
                                        .clipShape(Capsule())
                                }
                                
                                if let date = article.pubDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(themeManager.colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(themeManager.colors.bgSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text(article.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(themeManager.colors.textPrimary)
                                .lineLimit(nil)
                        }
                        
                        Divider()
                            .overlay(themeManager.colors.border)
                        
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
                            .onAppear {
                                loadContentAction()
                            }
                        } else {
                            Text(displayedContent)
                                .font(.body)
                                .foregroundStyle(themeManager.colors.textPrimary)
                                .lineSpacing(6)
                        }
                        
                        // Primary Action
                        if let originalUrl = URL(string: article.link) {
                            Button(action: { showSafariView = true }) {
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
                            .fullScreenCover(isPresented: $showSafariView) {
                                SafariView(url: originalUrl)
                                    .edgesIgnoringSafeArea(.all)
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(24)
                    .background(themeManager.colors.bgPrimary)
                    // Pull up content over image slightly if image exists
                    .offset(y: article.imageUrl != nil ? -20 : 0)
                    .cornerRadius(article.imageUrl != nil ? 24 : 0, corners: [.topLeft, .topRight])
                    
                    // Spacer for bottom safe area
                    Spacer().frame(height: 50)
                }
                .frame(width: geometry.size.width) // Constrain content width
            }
        }
    }
    
    private func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host()?.replacingOccurrences(of: "www.", with: "")
    }
}
