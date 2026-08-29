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
    @State private var isFocusMode = false

    // Parsed Content
    @State private var contentBlocks: [ContentBlock] = []
    @State private var selectedVideoUrl: IdentifiableString?

    // Debug state
    @State private var initialScrollOffset: CGFloat? = nil

    // AI Summary State
    @State private var isGeneratingSummary = false
    @State private var summaryError: String?

    @Environment(\.dismiss) private var dismiss

    private var preferences: ReadingPreferences {
        preferencesManager.preferences
    }

    /// Reading preferences with colorTheme overridden by the app theme, and —
    /// in Focus mode — type overridden to the fixed Lora 19/1.78 spec
    /// (docs/revamp-ios/README.md · "04 Focus").
    private var themedPreferences: ReadingPreferences {
        var prefs = preferences
        prefs.colorTheme = themeManager.resolvedTheme
        if isFocusMode {
            prefs.fontFamily = .lora
            prefs.fontSize = 19
            prefs.lineHeight = .relaxed
        }
        return prefs
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .statusBar(hidden: isFocusMode)
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
        .fullScreenCover(item: $selectedVideoUrl) { item in
            MediaPlayerView(videoUrl: item.value)
                .edgesIgnoringSafeArea(.all)
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
                VStack(alignment: .leading, spacing: 0) {
                    if !isFocusMode {
                        Text(article.title)
                            .font(Typography.articleTitle)
                            .tracking(-0.3)
                            .lineSpacing(6)
                            .foregroundColor(themeManager.colors.text)
                            .padding(.horizontal, Spacing.readerColumn)
                            .padding(.top, 20)

                        bylineRow(article)
                            .padding(.horizontal, Spacing.readerColumn)
                            .padding(.top, 14)

                        if let imageUrl = article.imageUrl {
                            AsyncImageView(url: imageUrl, cornerRadius: 22)
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 158)
                                .clipped()
                                .padding(.horizontal, Spacing.readerColumn)
                                .padding(.top, 20)
                                .onTapGesture {
                                    mediaGalleryInitialIndex = 0
                                    showMediaGallery = true
                                }
                        }
                    } else {
                        Spacer().frame(height: 78)
                    }

                    contentColumn(article)
                        .padding(.horizontal, isFocusMode ? Spacing.focusHorizontal : Spacing.readerColumn)
                        .padding(.top, 20)
                        .padding(.bottom, isFocusMode ? 140 : 220)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isFocusMode {
                        withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = false }
                    }
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
        .background(themeManager.colors.page)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !isFocusMode {
                readerTopChrome(article)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .bottom) {
            if !isFocusMode {
                floatingActionBar(article)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if let label = focusTimeRemainingLabel(article) {
                Text(label)
                    .font(Typography.figtree(12.5, weight: .bold))
                    .foregroundColor(themeManager.colors.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.colors.sink)
                    .clipShape(Capsule())
                    .padding(.bottom, 34)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if isFocusMode {
                focusProgressLine
                    .ignoresSafeArea(edges: .top)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFocusMode)
        .onDisappear {
            saveProgressTask?.cancel()
        }
    }

    // MARK: - Top Chrome (Reader)

    private func readerTopChrome(_ article: Article) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                        .background(themeManager.colors.sink)
                        .clipShape(Circle())
                }

                Text(topBarSubtitle(article))
                    .font(Typography.figtree(13, weight: .bold))
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Button(action: { showPreferences = true }) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                        .background(themeManager.colors.sink)
                        .clipShape(Circle())
                }

                Menu {
                    Button(action: { showTagEditor = true }) {
                        Label("Manage Tags", systemImage: "tag")
                    }
                    Menu("Reading Status") {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Button(action: { Task { await updateReadingStatus(status) } }) {
                                Label(status.displayName, systemImage: status.icon)
                            }
                        }
                    }
                    Button(action: { Task { await toggleLike() } }) {
                        Label(
                            hasLiked ? "Unlike" : (likeCount > 0 ? "Like (\(likeCount))" : "Like"),
                            systemImage: hasLiked ? "hand.thumbsup.fill" : "hand.thumbsup"
                        )
                    }
                    Divider()
                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Label("Delete Article", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                        .background(themeManager.colors.sink)
                        .clipShape(Circle())
                }

                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = true } }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.colors.page)
                        .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                        .background(themeManager.colors.text)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(themeManager.colors.line)
                    Rectangle()
                        .fill(themeManager.colors.accent)
                        .frame(width: geometry.size.width * readingProgress)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
        }
        .background(themeManager.colors.page)
    }

    private func topBarSubtitle(_ article: Article) -> String {
        var parts: [String] = []
        if let domain = article.domain { parts.append(domain) }
        if let readTime = article.estimatedReadTime { parts.append("\(readTime) min") }
        return parts.joined(separator: " · ")
    }

    private var focusProgressLine: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(themeManager.colors.accent)
                .frame(width: geometry.size.width * readingProgress, height: 2)
        }
        .frame(height: 2)
    }

    private func focusTimeRemainingLabel(_ article: Article) -> String? {
        guard let total = article.estimatedReadTime else { return nil }
        let remaining = max(0, Int(ceil(Double(total) * (1 - readingProgress))))
        return remaining <= 1 ? "1 min left" : "\(remaining) min left"
    }

    // MARK: - Byline

    @ViewBuilder
    private func bylineRow(_ article: Article) -> some View {
        if let author = article.author {
            HStack(spacing: 10) {
                AvatarView(initials: String(author.prefix(2)), size: 30, gradient: PremiumGradients.primary)
                HStack(spacing: 4) {
                    Text(author)
                        .fontWeight(.bold)
                    if let date = article.formattedDate {
                        Text("· \(date)")
                    }
                }
                .font(Typography.figtree(13))
                .foregroundColor(themeManager.colors.text)
            }
        }
    }

    // MARK: - Floating Action Bar

    private func floatingActionBar(_ article: Article) -> some View {
        HStack(spacing: 22) {
            Button(action: { Task { await toggleFavorite() } }) {
                Image(systemName: article.isFavorite ? "heart.fill" : "heart")
            }
            .foregroundColor(article.isFavorite ? themeManager.colors.accent : themeManager.colors.text)

            Button(action: { showComments = true }) {
                Image(systemName: "bubble.left")
            }
            .foregroundColor(themeManager.colors.text)

            if let url = URL(string: article.url) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundColor(themeManager.colors.text)
            }

            Button(action: { showSummarySheet = true }) {
                Image(systemName: "wand.and.stars")
            }
            .foregroundColor(themeManager.colors.text)

            Spacer(minLength: 0)

            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = true } }) {
                Text("Focus")
                    .font(Typography.caprasimo(13.5))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
        }
        .font(.system(size: 18, weight: .medium))
        .padding(.horizontal, 18)
        .frame(height: Spacing.readerActionBarHeight)
        .background(themeManager.colors.card)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(themeManager.colors.line, lineWidth: 1)
        )
        .shadow(
            color: AppShadows.floatingBar.color,
            radius: AppShadows.floatingBar.radius,
            x: AppShadows.floatingBar.x,
            y: AppShadows.floatingBar.y
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    // MARK: - Content Column

    @ViewBuilder
    private func contentColumn(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: isFocusMode ? 22 : 18) {
            if contentBlocks.isEmpty {
                if let content = article.content {
                    articleTextContent(content)
                }
            } else {
                ForEach(Array(contentBlocks.enumerated()), id: \.element.id) { index, block in
                    switch block.type {
                    case .html(let html):
                        SelfSizingHTMLView(
                            htmlContent: html,
                            preferences: themedPreferences,
                            onLinkTap: { url in
                                selectedLink = IdentifiableURL(url: url)
                            },
                            onImageTap: { url, localIndex in
                                // Calculate global index for this image
                                // Start with hero image offset if present
                                var globalIndex = (article.imageUrl != nil) ? 1 : 0

                                // Add image counts from previous blocks
                                for i in 0..<index {
                                    if case .html(let prevHtml) = contentBlocks[i].type {
                                        let count = HTMLContentView.extractImageUrls(from: prevHtml).count
                                        globalIndex += count
                                    }
                                }

                                // Add local index within this block
                                globalIndex += localIndex

                                mediaGalleryInitialIndex = globalIndex
                                showMediaGallery = true
                            },
                            onBodyTap: exitFocusModeIfNeeded
                        )
                        // Use stable ID based on block ID (UUID) + prefs, not content hash
                        .id("\(preferences.fontFamily)-\(preferences.fontSize)-\(themeManager.resolvedTheme)-\(isFocusMode)-\(block.id)")

                    case .video(let url):
                        VideoPreviewView(
                            videoUrl: url,
                            onPlay: {
                                selectedVideoUrl = IdentifiableString(value: url)
                            }
                        )
                        .padding(.vertical, 8)
                    }
                }
            }

            if !isFocusMode {
                readOriginalButton(article)
                commentsButton(article)
            }
        }
    }

    private func exitFocusModeIfNeeded() {
        if isFocusMode {
            withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = false }
        }
    }

    // MARK: - Text Content

    @State private var contentHeight: CGFloat = 100 // Legacy single-block height

    private func articleTextContent(_ content: String) -> some View {
        HTMLContentView(
            htmlContent: content,
            preferences: themedPreferences,
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
            },
            onBodyTap: exitFocusModeIfNeeded
        )
        .id("\(preferences.fontFamily)-\(preferences.fontSize)-\(themeManager.resolvedTheme)-\(preferences.lineHeight)-\(isFocusMode)") // Force view recreation when preferences change
        .frame(height: contentHeight)
        .frame(maxWidth: .infinity)
    }

    // Wrapper for list usage that manages its own height
    struct SelfSizingHTMLView: View {
        let htmlContent: String
        let preferences: ReadingPreferences
        let onLinkTap: ((URL) -> Void)?
        let onImageTap: ((String, Int) -> Void)?
        var onBodyTap: (() -> Void)? = nil

        @State private var height: CGFloat = 100

        var body: some View {
            HTMLContentView(
                htmlContent: htmlContent,
                preferences: preferences,
                dynamicHeight: $height,
                onLinkTap: onLinkTap,
                onImageTap: onImageTap,
                onBodyTap: onBodyTap
            )
            .frame(height: height)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Read Original

    @ViewBuilder
    private func readOriginalButton(_ article: Article) -> some View {
        if URL(string: article.url) != nil {
            Button(action: { showSafariView = true }) {
                HStack {
                    Text("Read Original")
                        .font(Typography.figtree(15, weight: .bold))
                    Image(systemName: "arrow.up.right")
                }
                .foregroundColor(themeManager.colors.page)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(themeManager.colors.text)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }

    // MARK: - Comments Button

    private func commentsButton(_ article: Article) -> some View {
        Button(action: { showComments = true }) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("Comments")
                    .font(Typography.figtree(15, weight: .semibold))
                Spacer()
                if article.commentCount > 0 {
                    Text("\(article.commentCount)")
                        .font(Typography.figtree(13, weight: .bold))
                        .foregroundColor(themeManager.colors.page)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(themeManager.colors.accent)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
            }
            .foregroundColor(themeManager.colors.text)
            .padding()
            .background(themeManager.colors.sink)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(themeManager.colors.accent)

            Text("Failed to load article")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            if let error = errorMessage {
                Text(error)
                    .font(Typography.figtree(13))
                    .foregroundColor(themeManager.colors.muted)
                    .multilineTextAlignment(.center)
            }

            Button("Go Back") {
                dismiss()
            }
            .font(Typography.figtree(15, weight: .bold))
            .foregroundColor(themeManager.colors.page)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.colors.page)
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
                // Parse Content
                if let content = article.content {
                    self.contentBlocks = ContentParser.shared.parse(content: content)
                }

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

// Extension to make String identifiable for sheets
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}
