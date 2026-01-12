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
    @State private var showComments = false
    @State private var showTagEditor = false
    @State private var readingProgress: Double = 0
    @State private var hasLiked = false
    @State private var likeCount = 0
    @State private var selectedLink: IdentifiableURL? // For link preview

    @Environment(\.dismiss) private var dismiss

    private var preferences: ReadingPreferences {
        preferencesManager.preferences
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
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
                    }

                    // Comments button
                    commentsButton(article)

                    // Original Link
                    if let url = URL(string: article.url) {
                        Link(destination: url) {
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
                }
                .padding(Spacing.lg)
                .padding(.bottom, 100) // Extra padding for comments/navigation
            }
        }
        .background(preferences.colorTheme.colors.bgPrimary)
        .overlay(alignment: .top) {
            // Reading progress bar
            GeometryReader { _ in
                Rectangle()
                    .fill(PremiumGradients.primary)
                    .frame(width: UIScreen.main.bounds.width * readingProgress, height: 3)
            }
            .frame(height: 3)
        }
        // Floating preferences button
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
    
    // MARK: - Actions
    
    private func loadArticle() async {
        isLoading = true
        
        do {
            article = try await SupabaseService.shared.getArticleById(articleId)
            if let article = article {
                likeCount = article.likeCount
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
        guard var currentArticle = article else { return }
        let newValue = !currentArticle.isFavorite
        
        // Optimistic update using same pattern
        if let updatedArticle = try? await SupabaseService.shared.getArticleById(articleId) {
            article = updatedArticle
        }
        
        do {
            try await SupabaseService.shared.toggleFavorite(articleId: articleId, isFavorite: newValue)
            article = try await SupabaseService.shared.getArticleById(articleId)
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
    
    private func toggleLike() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        do {
            let result = try await SupabaseService.shared.toggleLike(articleId: articleId, userId: userId)
            hasLiked = result.liked
            likeCount = result.likeCount
        } catch {
            print("Failed to toggle like: \(error)")
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
