import SwiftUI
import Supabase
import Auth


// MARK: - Article Reader View

struct ArticleReaderView: View {
    let articleId: String

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var preferencesManager = ReadingPreferencesManager.shared
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared
    /// Edge-to-edge hero image height (design · "04 · Reader").
    @ScaledMetric(relativeTo: .body) private var heroHeight: CGFloat = 246

    @State private var article: Article?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPreferences = false
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showPublicLinkSheet = false
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

    /// Reading preferences with `.system` resolved to the app's current theme,
    /// and — in Focus mode — type overridden to the fixed Lora 19/1.78 spec
    /// (docs/revamp-ios/README.md · "04 Focus"). An explicit Cream/Sepia/Dark
    /// choice from the reading preferences sheet is left untouched, so the
    /// reading pane can intentionally diverge from the app's own theme.
    private var themedPreferences: ReadingPreferences {
        var prefs = preferences
        if prefs.colorTheme == .system {
            prefs.colorTheme = themeManager.resolvedTheme
        }
        if isFocusMode {
            prefs.fontFamily = .lora
            prefs.fontSize = 19
            prefs.lineHeight = .comfortable
        }
        return prefs
    }

    /// Colors for the reading surface itself (title, byline, page background,
    /// body text) — follows `themedPreferences.colorTheme`, which may diverge
    /// from `themeManager.colors` used by the reader's chrome (top bar,
    /// floating action bar).
    private var readingColors: ThemeColors {
        themeManager.colors(for: themedPreferences.colorTheme)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
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
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
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
        .sheet(isPresented: $showPublicLinkSheet) {
            if let article = article {
                PublicLinkSheet(
                    articleId: article.id,
                    articleTitle: article.title,
                    initialToken: article.publicShareToken,
                    initialExpiresAt: article.publicLinkExpiresAt,
                    initialValidityDays: article.publicLinkValidityDays
                ) { token, expiresAt, validityDays in
                    self.article?.publicShareToken = token
                    self.article?.publicLinkExpiresAt = expiresAt
                    self.article?.publicLinkValidityDays = validityDays
                    self.article?.publicSharedAt = token == nil ? nil : (self.article?.publicSharedAt ?? ISO8601DateFormatter().string(from: Date()))
                }
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                        // Editorial Teal: edge-to-edge hero, then title,
                        // byline and meta on the reader column.
                        if let imageUrl = article.imageUrl {
                            ZStack {
                                readingColors.surface
                                AsyncImageView(url: imageUrl, cornerRadius: 0)
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(height: heroHeight)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                mediaGalleryInitialIndex = 0
                                showMediaGallery = true
                            }
                            .accessibilityLabel("Article image")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Opens the image gallery")
                        }

                        Text(article.title)
                            .font(Typography.articleTitle)
                            .tracking(-0.3)
                            .lineSpacing(4)
                            .foregroundColor(readingColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Spacing.readerColumn)
                            .padding(.top, 22)
                            .accessibilityAddTraits(.isHeader)

                        bylineRow(article)
                            .padding(.horizontal, Spacing.readerColumn)
                            .padding(.top, 14)

                        metaRow(article)
                            .padding(.horizontal, Spacing.readerColumn)
                            .padding(.top, 10)
                    } else {
                        Spacer().frame(height: 78)
                    }

                    contentColumn(article)
                        .padding(.horizontal, isFocusMode ? Spacing.focusHorizontal : Spacing.readerColumn)
                        .padding(.top, 18)
                        .padding(.bottom, isFocusMode ? 140 : 40)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isFocusMode {
                        withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = false }
                    }
                }
                .accessibilityAction(named: "Exit Focus mode") {
                    withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = false }
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
        .background(readingColors.page)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !isFocusMode {
                readerTopChrome(article)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isFocusMode {
                readerActionBar(article)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .overlay(alignment: .bottom) {
            if isFocusMode, let label = focusTimeRemainingLabel(article) {
                Text(label)
                    .font(Typography.ui(12.5, weight: .bold))
                    .foregroundColor(readingColors.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(readingColors.sink)
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

    /// Editorial Teal (design canvas · "04 · Reader"): back, source in the
    /// center, "Aa" and the More menu. Drawn with the reader palette so the
    /// chrome follows Light / Sepia / Dark.
    private func readerTopChrome(_ article: Article) -> some View {
        HStack(spacing: 4) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .font(Typography.symbol(19, weight: .semibold))
                    .foregroundColor(readingColors.text)
                    .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer(minLength: 4)

            sourceLabel(article)

            Spacer(minLength: 4)

            Button(action: { showPreferences = true }) {
                Text("Aa")
                    .font(Typography.ui(16, weight: .bold, relativeTo: .callout))
                    .foregroundColor(readingColors.text)
                    .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reading preferences")

            Menu {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isFocusMode = true } }) {
                    Label("Focus mode", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button(action: { Task { await toggleFavorite() } }) {
                    Label(
                        article.isFavorite ? "Remove from favorites" : "Add to favorites",
                        systemImage: article.isFavorite ? "star.slash" : "star"
                    )
                }
                Button(action: { showTagEditor = true }) {
                    Label("Manage Tags", systemImage: "tag")
                }
                if isOwner(article) {
                    Button(action: { showPublicLinkSheet = true }) {
                        Label(
                            article.isPublicLinkActive ? "Public Link (On)" : "Public Link",
                            systemImage: "globe"
                        )
                    }
                }
                Button(action: { showShareSheet = true }) {
                    Label("Share with friends", systemImage: "person.2")
                }
                Menu("Reading Status") {
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                        Button(action: { Task { await updateReadingStatus(status) } }) {
                            Label(status.displayName, systemImage: status.icon)
                        }
                    }
                }
                if URL(string: article.url) != nil {
                    Button(action: { showSafariView = true }) {
                        Label("Read Original", systemImage: "safari")
                    }
                }
                Divider()
                Button(role: .destructive, action: { showDeleteConfirm = true }) {
                    Label("Delete Article", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(Typography.symbol(18, weight: .semibold))
                    .foregroundColor(readingColors.text)
                    .rotationEffect(.degrees(90))
                    .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
            }
            .accessibilityLabel("More: focus mode, favorites, tags, public link, delete")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(readingColors.page)
    }

    /// Source monogram + name in the top bar.
    @ViewBuilder
    private func sourceLabel(_ article: Article) -> some View {
        let source = sourceName(article)
        if !source.isEmpty {
            HStack(spacing: 8) {
                Text(FeedSourceBubble.monogram(for: source))
                    .font(Typography.ui(10, weight: .bold, relativeTo: .caption2))
                    .foregroundColor(readingColors.text)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(readingColors.line, lineWidth: 1))
                    .accessibilityHidden(true)
                Text(source)
                    .font(Typography.ui(16, weight: .semibold, relativeTo: .callout))
                    .foregroundColor(readingColors.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private func sourceName(_ article: Article) -> String {
        (article.domain ?? "").replacingOccurrences(of: "www.", with: "")
    }

    /// Only the owner can make an article public (enforced server-side too).
    /// `uuidString` is uppercase while Postgres returns lowercase UUIDs.
    private func isOwner(_ article: Article) -> Bool {
        guard let userId = authManager.user?.id.uuidString else { return false }
        return article.userId.lowercased() == userId.lowercased()
    }

    private var focusProgressLine: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(readingColors.accent)
                .frame(width: geometry.size.width * readingProgress, height: 2)
        }
        .frame(height: 2)
    }

    private func focusTimeRemainingLabel(_ article: Article) -> String? {
        guard let total = article.estimatedReadTime else { return nil }
        let remaining = max(0, Int(ceil(Double(total) * (1 - readingProgress))))
        return remaining <= 1 ? "1 min left" : "\(remaining) min left"
    }

    // MARK: - Byline & meta

    /// "By Andrew Cunningham  For Ars Technica".
    @ViewBuilder
    private func bylineRow(_ article: Article) -> some View {
        let author = article.author?.trimmingCharacters(in: .whitespaces) ?? ""
        let source = sourceName(article)
        if !author.isEmpty || !source.isEmpty {
            HStack(spacing: 6) {
                if !author.isEmpty {
                    Text("By")
                        .foregroundColor(readingColors.muted)
                    Text(author)
                        .fontWeight(.medium)
                        .foregroundColor(readingColors.text)
                        .lineLimit(1)
                }
                if !source.isEmpty {
                    Text("For")
                        .foregroundColor(readingColors.muted)
                        .padding(.leading, author.isEmpty ? 0 : 6)
                    Text(source)
                        .fontWeight(.medium)
                        .foregroundColor(readingColors.text)
                        .lineLimit(1)
                }
            }
            .font(Typography.ui(13.5, relativeTo: .footnote))
            .accessibilityElement(children: .combine)
        }
    }

    /// "Technology · 9 min read          Saved 2 h ago".
    private func metaRow(_ article: Article) -> some View {
        HStack(spacing: 8) {
            if let category = categoryStore.category(for: article) {
                Text(category.displayName)
                    .font(Typography.ui(13.5, weight: .semibold, relativeTo: .footnote))
                    .foregroundColor(readingColors.accent)
            }

            if categoryStore.category(for: article) != nil, article.estimatedReadTime != nil {
                Circle()
                    .fill(readingColors.muted)
                    .frame(width: 3, height: 3)
                    .accessibilityHidden(true)
            }

            if let readTime = article.estimatedReadTime {
                Text("\(readTime) min read")
                    .font(Typography.ui(13.5, relativeTo: .footnote))
                    .foregroundColor(readingColors.muted)
            }

            Spacer(minLength: 8)

            if let date = article.formattedDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(Typography.symbol(13))
                        .accessibilityHidden(true)
                    Text("Saved \(date)")
                        .lineLimit(1)
                }
                .font(Typography.ui(13.5, relativeTo: .footnote))
                .foregroundColor(readingColors.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Action Bar

    /// Docked bar (design · "04 · Reader"): reading progress on top, then
    /// Like, Comments, AI summary, Share and Up next.
    private func readerActionBar(_ article: Article) -> some View {
        let queued = queueStore.isQueued(article.id)

        return VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(readingColors.line)
                    Rectangle()
                        .fill(readingColors.accent)
                        .frame(width: geometry.size.width * readingProgress)
                }
            }
            .frame(height: 3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reading progress")
            .accessibilityValue("\(Int(readingProgress * 100)) percent")

            HStack(spacing: 0) {
                actionBarButton(
                    systemImage: hasLiked ? "heart.fill" : "heart",
                    label: hasLiked ? "Unlike, \(likeCount) likes" : "Like, \(likeCount) likes",
                    count: likeCount,
                    tint: hasLiked ? readingColors.accent : nil
                ) {
                    Task { await toggleLike() }
                }

                Spacer(minLength: 0)

                actionBarButton(
                    systemImage: "bubble.left",
                    label: "Comments, \(article.commentCount)",
                    count: article.commentCount
                ) {
                    showComments = true
                }

                Spacer(minLength: 0)

                actionBarButton(systemImage: "sparkles", label: "AI summary") {
                    showSummarySheet = true
                }

                Spacer(minLength: 0)

                if let url = URL(string: article.url) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(Typography.symbol(19))
                            .foregroundColor(readingColors.text)
                            .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share")

                    Spacer(minLength: 0)
                }

                actionBarButton(
                    systemImage: queued ? "bookmark.fill" : "bookmark",
                    label: queued ? "In Up next, remove" : "Add to Up next",
                    tint: queued ? readingColors.accent : nil
                ) {
                    Task { await toggleUpNext(article) }
                }
                .disabled(queueStore.isPending(article.id))
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .background(
            readingColors.page
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(readingColors.line)
                .frame(height: 1)
        }
    }

    /// One 44pt target in the action bar, with an optional count beside it.
    private func actionBarButton(
        systemImage: String,
        label: String,
        count: Int? = nil,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(Typography.symbol(19))
                    .foregroundColor(tint ?? readingColors.text)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(Typography.ui(14.5, relativeTo: .subheadline))
                        .foregroundColor(readingColors.muted)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 6)
            .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
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
                HStack(spacing: 14) {
                    Text(FeedSourceBubble.monogram(for: sourceName(article).isEmpty ? "Web" : sourceName(article)))
                        .font(Typography.ui(12, weight: .bold))
                        .foregroundColor(readingColors.text)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(readingColors.line, lineWidth: 1))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read the original")
                            .font(Typography.ui(15, weight: .semibold))
                            .foregroundColor(readingColors.text)
                        if !sourceName(article).isEmpty {
                            Text(sourceName(article))
                                .font(Typography.ui(13, relativeTo: .footnote))
                                .foregroundColor(readingColors.muted)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(Typography.symbol(17, weight: .medium))
                        .foregroundColor(readingColors.text)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .stroke(readingColors.line, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 8)
        }
    }

    // MARK: - Comments Button

    private func commentsButton(_ article: Article) -> some View {
        Button(action: { showComments = true }) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left")
                    .font(Typography.symbol(17))
                    .accessibilityHidden(true)
                Text("Comments")
                    .font(Typography.ui(15, weight: .semibold))
                Spacer()
                if article.commentCount > 0 {
                    Text("\(article.commentCount)")
                        .font(Typography.ui(13, weight: .semibold))
                        .foregroundColor(readingColors.page)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 24)
                        .background(Capsule().fill(readingColors.accent))
                }
                Image(systemName: "chevron.forward")
                    .font(Typography.symbol(13, weight: .semibold))
                    .foregroundColor(readingColors.muted)
                    .accessibilityHidden(true)
            }
            .foregroundColor(readingColors.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(readingColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Comments, \(article.commentCount)")
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
                    .font(Typography.ui(13))
                    .foregroundColor(themeManager.colors.muted)
                    .multilineTextAlignment(.center)
            }

            Button("Go Back") {
                dismiss()
            }
            .font(Typography.ui(15, weight: .bold))
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
            if status == .completed { await advanceQueue() }
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
            await advanceQueue()
        } catch {
            print("Failed to mark as completed: \(error)")
        }
    }

    /// Bookmark in the action bar: adds the article to "Up next" or removes it.
    private func toggleUpNext(_ article: Article) async {
        guard let userId = authManager.user?.id.uuidString else { return }
        if let item = queueStore.items.first(where: { $0.articleId.lowercased() == article.id.lowercased() }) {
            await queueStore.remove(item)
        } else {
            await queueStore.add(articleId: article.id, userId: userId)
        }
    }

    /// Finishing an article advances "Up next": drop it from the queue (web reader parity).
    private func advanceQueue() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        do {
            try await SupabaseService.shared.removeFromQueueByArticle(userId: userId, articleId: articleId)
            ReadingQueueStore.shared.removeLocally(articleId: articleId)
        } catch {
            print("Failed to advance queue: \(error)")
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
