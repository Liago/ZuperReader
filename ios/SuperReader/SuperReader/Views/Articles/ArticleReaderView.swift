import SwiftUI
import Supabase


// MARK: - Article Reader View

struct ArticleReaderView: View {
    let articleId: String
    
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var preferencesManager = ReadingPreferencesManager.shared

    @State private var article: Article?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPreferences = false
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showSummarySheet = false
    @State private var showComments = false
    @State private var showTagEditor = false
    @State private var readingProgress: Double = 0
    @State private var hasLiked = false
    @State private var likeCount = 0
    @State private var selectedLink: IdentifiableURL? // For link preview
    @State private var showSafariView = false // For "Read Original" in-app browser
    @State private var saveProgressTask: Task<Void, Never>? // For debouncing progress saves
    @State private var hasRestoredPosition = false // Track if we've restored scroll position
    @State private var scrollContentHeight: CGFloat = 0 // Total height of scroll content
    @State private var showMediaGallery = false // For media gallery
    @State private var mediaGalleryInitialIndex = 0 // Initial media index for gallery
    
    // Debug state
    @State private var initialScrollOffset: CGFloat? = nil

    // AI Summary State
    @State private var isGeneratingSummary = false
    @State private var summaryError: String?

    @Environment(\.dismiss) private var dismiss

    private var preferences: ReadingPreferences {
        preferencesManager.preferences
    }

    // Get all media items from article
    private var mediaItems: [MediaItem] {
        var items: [MediaItem] = []

        // Add hero image first
        if let heroUrl = article?.imageUrl {
            items.append(MediaItem(url: heroUrl, type: .image))
        }

        // Add inline images from content
        if let content = article?.content {
            let imageUrls = HTMLContentView.extractImageUrls(from: content)
            items.append(contentsOf: imageUrls.map { MediaItem(url: $0, type: .image) })
        }

        return items
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                FullScreenLoadingView(message: "Loading article...")
                    .environmentObject(themeManager)
            } else if let article = article {
                articleContent(article)
            } else {
                errorView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if article != nil {
                    toolbarMenu
                }
            }
        }
        .sheet(isPresented: $showPreferences) {
            ReadingPreferencesView(preferences: $preferencesManager.preferences)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showSummarySheet) {
            if let article = article {
                AISummaryView(
                    article: article,
                    fontFamily: preferences.fontFamily,
                    onGenerate: { length, format in
                        Task { await generateSummary(length: length, format: format) }
                    },
                    isGenerating: isGeneratingSummary,
                    error: summaryError
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showComments) {
            if let article = article, let userId = authManager.user?.id.uuidString {
                CommentsView(articleId: article.id, userId: userId)
                    .environmentObject(themeManager)
            }
        }

        .sheet(isPresented: $showTagEditor) {
            if let article = article {
                TagManagementView(
                    currentTags: article.tags,
                    onSave: { tags in
                        Task { await updateTags(tags) }
                    }
                )
                .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let article = article, let userId = authManager.user?.id.uuidString {
                ShareArticleSheet(
                    articleId: article.id,
                    articleTitle: article.title,
                    userId: userId
                )
                .environmentObject(themeManager)
            }
        }
        .sheet(item: $selectedLink) { item in
            if let userId = authManager.user?.id.uuidString {
                ArticleLinkPreviewView(url: item.url)
                    .environmentObject(themeManager)
            }
        }
        .fullScreenCover(isPresented: $showSafariView) {
            if let urlStr = article?.url, let url = URL(string: urlStr) {
                SafariView(url: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .fullScreenCover(isPresented: $showMediaGallery) {
            MediaGalleryView(
                mediaItems: mediaItems,
                initialIndex: mediaGalleryInitialIndex,
                onClose: { showMediaGallery = false }
            )
        }
        .alert("Delete Article", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteArticle() }
            }
        } message: {
            Text("Are you sure you want to delete this article? This cannot be undone.")
        }
        .task {
            await loadArticle()
            await checkLikeStatus()
            await markAsReading()
        }
    }
    
    // MARK: - Article Content
    
    @ViewBuilder
    private func articleContent(_ article: Article) -> some View {
        GeometryReader { outerGeometry in
            ScrollView {
                // Main Content
                VStack(alignment: .leading, spacing: 0) {
                    // Hero Image
                    if let imageUrl = article.imageUrl {
                        AsyncImageView(url: imageUrl, cornerRadius: 0)
                            .frame(height: 250)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .onTapGesture {
                                // Open media gallery with hero image as first item
                                mediaGalleryInitialIndex = 0
                                showMediaGallery = true
                            }
                    }
                    
                    // Content section with padding
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // Title
                        Text(article.title)
                            .font(preferences.fontFamily.font(size: preferences.fontSize * 1.6))
                            .fontWeight(.bold)
                            .foregroundColor(preferences.colorTheme.colors.textPrimary)
                        
                        // Metadata
                        metadataRow(article)
                        
                        // AI Summary
                        // AI Summary Banner
                        Button(action: { showSummarySheet = true }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Text(article.aiSummary != nil ? "Leggi Riassunto AI" : "Genera Riassunto AI")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        
                        // Action Bar
                        actionBar(article)
                        
                        Divider()
                            .background(preferences.colorTheme.colors.border)
                        
                        // Tags
                        if !article.tags.isEmpty {
                            TagListView(tags: article.tags)
                        }
                        
                        // Content
                        if let content = article.content {
                            articleTextContent(content)
                                .padding(.bottom, 40)
                        }
                        
                        // Original Link
                        if let url = URL(string: article.url) {
                            Button(action: { showSafariView = true }) {
                                HStack {
                                    Text("Read Original")
                                        .font(.system(size: 16, weight: .semibold))
                                    Image(systemName: "arrow.up.right")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                            }
                            }
                            
                            // Comments button
                            commentsButton(article)
                        }
                        .padding(Spacing.lg)
                        .padding(.bottom, 220)
                    }
                    .overlay(
                        GeometryReader { contentGeometry in
                            ZStack {
                                Color.clear.preference(
                                    key: ContentHeightPreferenceKey.self,
                                    value: contentGeometry.size.height
                                )
                                
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).minY
                                )
                            }
                        }
                    )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollY in
                updateReadingProgress(currentY: scrollY, viewHeight: outerGeometry.size.height, article: article)
            }
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                scrollContentHeight = height
            }
            .onAppear {
                if article.readingProgress > 0 && !hasRestoredPosition {
                     hasRestoredPosition = true
                }
            }
        }
        .background(preferences.colorTheme.colors.bgPrimary)
        // Circular progress indicator - bottom left
        .overlay(alignment: .bottomLeading) {
            CircularProgressIndicator(progress: readingProgress)
                .padding(Spacing.lg)
                .opacity(readingProgress > 0 ? 0.95 : 0.7)
                .animation(.easeInOut(duration: 0.2), value: readingProgress)
        }

        
        // Floating preferences button - bottom right
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showPreferences = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(PremiumGradients.primary)
                    )
                    .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.lg)
        }
        .onDisappear {
            saveProgressTask?.cancel()
        }
    }
    

    
    // MARK: - Metadata Row
    
    private func metadataRow(_ article: Article) -> some View {
        HStack(spacing: Spacing.md) {
            if let author = article.author {
                HStack(spacing: Spacing.xs) {
                    AvatarView(initials: String(author.prefix(2)), size: 28)
                    Text(author)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(preferences.colorTheme.colors.textPrimary)
            }
            
            if let domain = article.domain {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                    Text(domain)
                        .font(.system(size: 13))
                }
                .foregroundColor(preferences.colorTheme.colors.textSecondary)
            }
            
            if let readTime = article.formattedReadTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(readTime)
                        .font(.system(size: 13))
                }
                .foregroundColor(preferences.colorTheme.colors.textSecondary)
            }
        }
    }
    
    // MARK: - Action Bar
    
    private func actionBar(_ article: Article) -> some View {
        HStack(spacing: Spacing.md) {
            // Reading Status
            Menu {
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Button(action: {
                        Task { await updateReadingStatus(status) }
                    }) {
                        Label(status.displayName, systemImage: status.icon)
                    }
                }
            } label: {
                ReadingStatusBadge(status: article.readingStatus)
            }
            
            Spacer()
            
            // Favorite
            Button(action: { Task { await toggleFavorite() } }) {
                Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(article.isFavorite ? .red : preferences.colorTheme.colors.textSecondary)
            }
            
            // Like
            Button(action: { Task { await toggleLike() } }) {
                HStack(spacing: 4) {
                    Image(systemName: hasLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    if likeCount > 0 {
                        Text("\(likeCount)")
                    }
                }
                .font(.system(size: 16))
                .foregroundColor(hasLiked ? .blue : preferences.colorTheme.colors.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(hasLiked ? Color.blue.opacity(0.1) : Color.clear)
                )
            }
            
            // Share
            Button(action: { showShareSheet = true }) {
                Image(systemName: "paperplane")
                    .font(.system(size: 18))
                    .foregroundColor(preferences.colorTheme.colors.textSecondary)
            }
            
            // Tags
            Button(action: { showTagEditor = true }) {
                Image(systemName: "tag")
                    .font(.system(size: 18))
                    .foregroundColor(preferences.colorTheme.colors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
    
    // MARK: - Text Content
    
    @State private var contentHeight: CGFloat = 100 // Initial estimate

    private func articleTextContent(_ content: String) -> some View {
        HTMLContentView(
            htmlContent: content,
            preferences: preferences,
            dynamicHeight: $contentHeight,
            onLinkTap: { url in
                selectedLink = IdentifiableURL(url: url)
            },
            onImageTap: { url, index in
                // Open media gallery with the tapped image
                // Add 1 to index if hero image exists (it's at index 0)
                let adjustedIndex = article?.imageUrl != nil ? index + 1 : index
                mediaGalleryInitialIndex = adjustedIndex
                showMediaGallery = true
            }
        )
        .id("\(preferences.fontFamily)-\(preferences.fontSize)-\(preferences.colorTheme)-\(preferences.lineHeight)") // Force view recreation when preferences change
        .frame(height: contentHeight)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Comments Button
    
    private func commentsButton(_ article: Article) -> some View {
        Button(action: { showComments = true }) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("Comments")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                if article.commentCount > 0 {
                    Text("\(article.commentCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
            }
            .foregroundColor(preferences.colorTheme.colors.textPrimary)
            .padding()
            .background(preferences.colorTheme.colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Failed to load article")
                .font(.headline)
            
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("Go Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Toolbar Menu
    
    private var toolbarMenu: some View {
        Menu {
            Button(action: { showPreferences = true }) {
                Label("Reading Preferences", systemImage: "textformat.size")
            }
            
            Button(action: { showTagEditor = true }) {
                Label("Manage Tags", systemImage: "tag")
            }
            
            Divider()
            
            if let url = article?.url, let shareUrl = URL(string: url) {
                ShareLink(item: shareUrl) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label("Delete Article", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
        }
    }
    

    
    private func updateReadingProgress(currentY: CGFloat, viewHeight: CGFloat, article: Article) {
        guard scrollContentHeight > 0 else { return }
        
        if initialScrollOffset == nil {
            initialScrollOffset = currentY
        }
        
        let initialY = initialScrollOffset ?? currentY
        
        // Named Coordinate Space Logic:
        // Top = 0 (or close to 0)
        // Scroll Down -> Content moves UP -> Y becomes NEGATIVE
        // Scrolled Amount = Initial - Current
        // Example: 0 - (-100) = 100 pixels scrolled
        let scrolledAmount = initialY - currentY
        
        // Adjust content height by view height to get scrollable distance
        
        // Adjust content height by view height to get scrollable distance
        let scrollableDistance = max(1, scrollContentHeight - viewHeight)
        
        let progress = min(1.0, max(0.0, scrolledAmount / scrollableDistance))
        
        // Only update if change is significant (> 1%)
        if abs(progress - readingProgress) > 0.01 {
            readingProgress = progress
        }
        
        let progressPercent = Int(progress * 100)
        
        if progressPercent >= 85 && article.readingStatus == .reading {
            Task { await markAsCompleted() }
        }
        
        saveProgressTask?.cancel()
        saveProgressTask = Task {
             try? await Task.sleep(nanoseconds: 2_000_000_000)
             guard !Task.isCancelled else { return }
             try? await SupabaseService.shared.updateReadingProgress(
                 articleId: articleId,
                 progress: progressPercent
             )
         }
    }
    
    // MARK: - Actions
    
    private func loadArticle() async {
        isLoading = true
        
        do {
            article = try await SupabaseService.shared.getArticleById(articleId)
            if let article = article {
                likeCount = article.likeCount
                if let userId = authManager.user?.id.uuidString {
                    hasLiked = try await SupabaseService.shared.checkIfUserLiked(articleId: articleId, userId: userId)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func checkLikeStatus() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        do {
            hasLiked = try await SupabaseService.shared.checkIfUserLiked(articleId: articleId, userId: userId)
        } catch {
            print("Failed to check like status: \(error)")
        }
    }
    
    private func markAsReading() async {
        guard let article = article, article.readingStatus == .unread else { return }
        
        do {
            try await SupabaseService.shared.updateReadingStatus(articleId: articleId, status: .reading)
            self.article = try await SupabaseService.shared.getArticleById(articleId)
        } catch {
            print("Failed to mark as reading: \(error)")
        }
    }
    
    private func toggleFavorite() async {
        guard let currentArticle = article else { return }
        let newValue = !currentArticle.isFavorite
        
        do {
            try await SupabaseService.shared.toggleFavorite(articleId: articleId, isFavorite: newValue)
            article = try await SupabaseService.shared.getArticleById(articleId)
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
    
    private func toggleLike() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        let originalState = hasLiked
        let originalCount = likeCount
        
        // Optimistic update
        hasLiked.toggle()
        if hasLiked {
            likeCount += 1
        } else {
            likeCount = max(0, likeCount - 1)
        }
        
        do {
            let result = try await SupabaseService.shared.toggleLike(articleId: articleId, userId: userId)
            hasLiked = result.liked
            likeCount = result.likeCount
        } catch {
            print("Failed to toggle like: \(error)")
            // Revert
            hasLiked = originalState
            likeCount = originalCount
        }
    }
    
    private func updateReadingStatus(_ status: ReadingStatus) async {
        do {
            try await SupabaseService.shared.updateReadingStatus(articleId: articleId, status: status)
            article = try await SupabaseService.shared.getArticleById(articleId)
        } catch {
            print("Failed to update reading status: \(error)")
        }
    }
    
    private func updateTags(_ tags: [String]) async {
        do {
            let updated = try await SupabaseService.shared.updateArticleTags(articleId: articleId, tags: tags)
            article = updated
        } catch {
            print("Failed to update tags: \(error)")
        }
    }
    
    private func deleteArticle() async {
        do {
            try await SupabaseService.shared.deleteArticle(articleId: articleId)
            dismiss()
        } catch {
            print("Failed to delete article: \(error)")
        }
    }
    
    private func markAsCompleted() async {
        do {
            try await SupabaseService.shared.updateReadingStatus(articleId: articleId, status: .completed)
            self.article = try await SupabaseService.shared.getArticleById(articleId)
        } catch {
            print("Failed to mark as completed: \(error)")
        }
    }
    
    private func generateSummary(length: String, format: String) async {
        guard let currentArticle = article else { return }
        isGeneratingSummary = true
        summaryError = nil
        
        do {
            let updated = try await SupabaseService.shared.generateArticleSummary(article: currentArticle, length: length, format: format)
            article = updated
        } catch {
            summaryError = error.localizedDescription
        }
        
        isGeneratingSummary = false
    }
}

#Preview {
    NavigationStack {
        ArticleReaderView(articleId: "test-id")
            .environmentObject(ThemeManager.shared)
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Preference Keys for Scroll Tracking

/// Tracks the scroll offset for reading progress calculation
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue() // Keep most recent
    }
}

/// Tracks the content height for reading progress calculation
struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
