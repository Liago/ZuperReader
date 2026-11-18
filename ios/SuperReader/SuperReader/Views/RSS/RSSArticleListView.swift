import SwiftUI
import Supabase
import Auth

// MARK: - Feed source page (per-feed article list)
//
// Editorial Teal (design canvas · "03 · Scheda fonte"): a centered profile
// of the feed — monogram, name, site, three stats, "Mark all read" and
// site / share buttons — then Unread / All tabs over the article rows.
// The top bar keeps previous / next feed and a menu with Open website and
// Unfollow.

struct RSSArticleListView: View {
    @State private var currentFeed: RSSFeed
    @ObservedObject var viewModel: RSSViewModel
    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var isMarkingRead = false
    @State private var errorMessage: String?
    @State private var showReadArticles = false // Default: hide read articles
    @State private var showSafariView = false
    @State private var confirmUnfollow = false
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    init(feed: RSSFeed, viewModel: RSSViewModel) {
        self._currentFeed = State(initialValue: feed)
        self.viewModel = viewModel
    }

    private var currentIndex: Int? {
        viewModel.feeds.firstIndex(where: { $0.id == currentFeed.id })
    }

    private var hasPrev: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    private var hasNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < viewModel.feeds.count - 1
    }

    private var unreadCount: Int { articles.filter { !$0.isRead }.count }

    private var siteURL: URL? {
        URL(string: currentFeed.siteUrl ?? currentFeed.url)
    }

    private var domain: String {
        siteURL?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    var body: some View {
        ZStack {
            themeManager.colors.page
                .ignoresSafeArea()

            List {
                Section {
                    profileHeader
                        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.screenHorizontal, bottom: 0, trailing: Spacing.screenHorizontal))
                        .listRowSeparator(.hidden)
                        .listRowBackground(themeManager.colors.page)
                }

                Section {
                    content
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(themeManager.colors.page)
            .id(currentFeed.id)
            .refreshable {
                await refreshFeed()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .navigationBarHidden(true)
        .rssLibrarySaveBanner(bottomPadding: 28)
        .fullScreenCover(isPresented: $showSafariView) {
            if let siteURL {
                SafariView(url: siteURL)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .confirmationDialog(
            "Unfollow \(currentFeed.title)?",
            isPresented: $confirmUnfollow,
            titleVisibility: .visible
        ) {
            Button("Unfollow", role: .destructive) {
                Task {
                    await viewModel.deleteFeed(currentFeed)
                    dismiss()
                }
            }
        } message: {
            Text("Its articles will no longer appear in Feeds.")
        }
        .task {
            showReadArticles = false
            await loadArticles(showLoadingIndicator: true)
        }
        .onChange(of: currentFeed.id) { _, _ in
            Task {
                showReadArticles = false
                await loadArticles(showLoadingIndicator: true)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 4) {
            IconCircleButton(systemImage: "chevron.backward", label: "Back", style: .outline, glyphWeight: .semibold, glyphSize: 16) {
                dismiss()
            }

            Spacer()

            IconCircleButton(systemImage: "chevron.up", label: "Previous feed", style: .outline, glyphSize: 15) {
                goToFeed(offset: -1)
            }
            .opacity(hasPrev ? 1 : 0.35)
            .disabled(!hasPrev)

            IconCircleButton(systemImage: "chevron.down", label: "Next feed", style: .outline, glyphSize: 15) {
                goToFeed(offset: 1)
            }
            .opacity(hasNext ? 1 : 0.35)
            .disabled(!hasNext)

            Menu {
                if siteURL != nil {
                    Button {
                        showSafariView = true
                    } label: {
                        Label("Open website", systemImage: "safari")
                    }
                }

                Button {
                    Task { await markAllAsRead() }
                } label: {
                    Label("Mark all as read", systemImage: "checkmark.circle")
                }
                .disabled(unreadCount == 0)

                Divider()

                Button(role: .destructive) {
                    confirmUnfollow = true
                } label: {
                    Label("Unfollow", systemImage: "minus.circle")
                }
            } label: {
                IconCircleGlyph(systemImage: "ellipsis", style: .outline, glyphSize: 16)
            }
            .minimumTapTarget()
            .accessibilityLabel("Feed options")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(themeManager.colors.page)
    }

    private func goToFeed(offset: Int) {
        guard let idx = currentIndex else { return }
        let target = idx + offset
        guard viewModel.feeds.indices.contains(target) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentFeed = viewModel.feeds[target]
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                FeedAvatar(feed: currentFeed, size: 92, monogramFont: Typography.display(26, weight: .heavy, relativeTo: .title))

                Text(currentFeed.title)
                    .font(Typography.display(24, weight: .bold, relativeTo: .title2))
                    .foregroundColor(themeManager.colors.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if !domain.isEmpty {
                    Text("Synced from \(domain)")
                        .font(Typography.ui(13.5, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                statTile(value: "\(unreadCount)", label: "Unread")
                statTile(value: "\(articles.count)", label: "Articles")
                statTile(value: "\(articles.count - unreadCount)", label: "Read")
            }

            HStack(spacing: 10) {
                Button {
                    Task { await markAllAsRead() }
                } label: {
                    HStack(spacing: 8) {
                        if isMarkingRead {
                            ProgressView()
                                .tint(themeManager.colors.page)
                        } else {
                            Image(systemName: "checkmark")
                                .font(Typography.symbol(14, weight: .semibold))
                        }
                        Text(unreadCount > 0 ? "Mark all read" : "All caught up")
                            .font(Typography.ui(15, weight: .semibold))
                    }
                    .foregroundColor(themeManager.colors.page)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(themeManager.colors.accent))
                    .opacity(unreadCount > 0 ? 1 : 0.5)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(unreadCount == 0 || isMarkingRead)

                if siteURL != nil {
                    IconCircleButton(systemImage: "safari", label: "Open website", style: .outline, glyphSize: 17) {
                        showSafariView = true
                    }
                }

                if let siteURL {
                    ShareLink(item: siteURL) {
                        IconCircleGlyph(systemImage: "square.and.arrow.up", style: .outline, glyphSize: 17)
                    }
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                    .accessibilityLabel("Share feed")
                }
            }

            tabs
        }
        .padding(.top, 8)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.display(19, weight: .bold, relativeTo: .title3))
                .foregroundColor(themeManager.colors.text)
                .contentTransition(.numericText())
            Text(label)
                .font(Typography.ui(12, relativeTo: .caption))
                .foregroundColor(themeManager.colors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton(title: "Unread", isSelected: !showReadArticles) { showReadArticles = false }
            tabButton(title: "All", isSelected: showReadArticles) { showReadArticles = true }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeManager.colors.line)
                .frame(height: 1)
        }
    }

    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .font(Typography.ui(14.5, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? themeManager.colors.accent : themeManager.colors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? themeManager.colors.accent : Color.clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ForEach(0..<4, id: \.self) { _ in
                ArticleRowSkeleton()
                    .listRowSeparator(.hidden)
                    .listRowBackground(themeManager.colors.page)
            }
        } else if let error = errorMessage {
            stateRow {
                Text(error)
                    .font(Typography.ui(13))
                    .foregroundColor(themeManager.colors.muted)
                    .multilineTextAlignment(.center)
            }
        } else {
            let displayedArticles = articles.filter { showReadArticles || !$0.isRead }
            if displayedArticles.isEmpty {
                stateRow {
                    VStack(spacing: 10) {
                        Text(articles.isEmpty ? "No articles yet" : "All caught up")
                            .font(Typography.sheetTitle)
                            .foregroundColor(themeManager.colors.text)

                        if !articles.isEmpty {
                            Button("Show read articles") { showReadArticles = true }
                                .font(Typography.ui(14, weight: .semibold))
                                .foregroundColor(themeManager.colors.accent)
                                .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ForEach(displayedArticles) { article in
                    let originalIndex = articles.firstIndex(where: { $0.id == article.id }) ?? 0

                    ZStack {
                        NavigationLink(destination: RSSArticleReader(articles: $articles, initialIndex: originalIndex)) {
                            EmptyView()
                        }
                        .opacity(0)

                        RSSArticleRow(article: article)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.screenHorizontal, bottom: 0, trailing: Spacing.screenHorizontal))
                    .listRowSeparatorTint(themeManager.colors.line)
                    .listRowBackground(themeManager.colors.page)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                await markAsRead(article: article, at: originalIndex)
                            }
                        } label: {
                            Label("Mark as Read", systemImage: "envelope.open")
                        }
                        .tint(themeManager.colors.accent)
                    }
                    .rssArticleContextMenu(article: article) {
                        Task {
                            await markAsRead(article: article, at: originalIndex)
                        }
                    }
                }
            }
        }
    }

    private func stateRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .listRowSeparator(.hidden)
            .listRowBackground(themeManager.colors.page)
    }

    // MARK: - Actions

    private func markAllAsRead() async {
        isMarkingRead = true
        await viewModel.markFeedAsRead(currentFeed)

        for i in articles.indices {
            articles[i].isRead = true
            articles[i].readAt = Date()
        }

        isMarkingRead = false
    }

    private func refreshFeed() async {
        do {
            _ = try await RSSService.shared.refreshFeed(feedId: currentFeed.id, url: currentFeed.url)
            await loadArticles(showLoadingIndicator: false)
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
            self.articles = try await RSSService.shared.getArticles(userId: userId, feedId: currentFeed.id, includeRead: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func markAsRead(article: RSSArticle, at index: Int) async {
        guard let userId = AuthManager.shared.user?.id.uuidString else { return }
        do {
            try await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
            guard articles.indices.contains(index), articles[index].id == article.id else { return }
            articles[index].isRead = true
            articles[index].readAt = Date()
            if let count = viewModel.unreadCounts[article.feedId], count > 0 {
                viewModel.unreadCounts[article.feedId] = count - 1
            }
        } catch {
            print("Failed to mark article as read: \(error)")
        }
    }
}

// MARK: - Article Row

/// Editorial Teal article row, shared by the Feeds tab, All feeds and the
/// feed source page: thumbnail, source (or unread dot) and time, title,
/// one line of snippet. `feedTitle` is shown when the list mixes feeds.
struct RSSArticleRow: View {
    let article: RSSArticle
    var feedTitle: String? = nil
    @ObservedObject private var saveStore = RSSLibrarySaveStore.shared
    @EnvironmentObject var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var thumbSize: CGFloat = 84

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if !article.isRead {
                        Circle()
                            .fill(themeManager.colors.accent)
                            .frame(width: 7, height: 7)
                            .accessibilityLabel("Unread")
                    }

                    if let feedTitle {
                        Text(feedTitle)
                            .font(Typography.ui(12, weight: .semibold, relativeTo: .caption))
                            .foregroundColor(themeManager.colors.accent)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // Outcome of the long-press "Save to Library".
                    if saveStore.isSaving(article) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(themeManager.colors.accent)
                    } else if saveStore.isSaved(article) {
                        Image(systemName: "bookmark.fill")
                            .font(Typography.symbol(10))
                            .foregroundColor(themeManager.colors.accent)
                            .accessibilityLabel("Saved to Library")
                    }

                    if let date = article.pubDate {
                        Text(date, style: .relative)
                            .font(Typography.ui(12, relativeTo: .caption))
                            .foregroundColor(themeManager.colors.muted)
                            .lineLimit(1)
                    }
                }

                Text(article.title)
                    .font(Typography.ui(15, weight: .semibold, relativeTo: .subheadline))
                    .foregroundColor(article.isRead ? themeManager.colors.muted : themeManager.colors.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let snippet = article.contentSnippet?.strippingHTML(), !snippet.isEmpty {
                    Text(snippet)
                        .font(Typography.ui(13, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        Group {
            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                AsyncImageView(url: url.absoluteString, cornerRadius: CornerRadius.listThumbnail)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    themeManager.colors.surface
                    Image(systemName: "dot.radiowaves.up.forward")
                        .foregroundColor(themeManager.colors.muted)
                }
                            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .thumbnailClip()
        .accessibilityHidden(true)
    }
}

// MARK: - Article Reader (paged)

struct RSSArticleReader: View {
    @Binding var articles: [RSSArticle]
    let initialIndex: Int
    @State private var currentIndex: Int = 0
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject private var saveStore = RSSLibrarySaveStore.shared
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
                    displayedContent: index == currentIndex ? displayedContent : "",
                    themeManager: themeManager,
                    loadContentAction: {
                        if index == currentIndex { loadContent() }
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // The color also fills the status bar strip, but the content does NOT
        // ignore the safe area, so the top bar inset reaches the pages (same
        // structure as the Library reader, ArticleReaderView).
        .background(themeManager.colors.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .rssLibrarySaveBanner(bottomPadding: 80)
        .onAppear {
            if !hasInitialized {
                currentIndex = initialIndex
                hasInitialized = true
            }
            markAsRead()
        }
        .onChange(of: currentIndex) { _, _ in
            resetState()
            markAsRead()
        }
        .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 && abs(value.translation.width) < value.translation.height {
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
    }

    // MARK: - Top Bar

    /// Editorial Teal reader bar: back, source in the center, previous /
    /// next article.
    private var topBar: some View {
        HStack(spacing: 4) {
            plainIconButton("chevron.backward", label: "Back", size: 19) {
                dismiss()
            }

            Spacer(minLength: 4)

            if let domain = getDomain(from: currentArticle.link) {
                HStack(spacing: 8) {
                    Text(FeedSourceBubble.monogram(for: domain))
                        .font(Typography.ui(10, weight: .bold, relativeTo: .caption2))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(themeManager.colors.line, lineWidth: 1))
                        .accessibilityHidden(true)
                    Text(domain)
                        .font(Typography.ui(16, weight: .semibold, relativeTo: .callout))
                        .foregroundColor(themeManager.colors.text)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            plainIconButton("chevron.up", label: "Previous article", size: 17) {
                withAnimation { if currentIndex > 0 { currentIndex -= 1 } }
            }
            .opacity(currentIndex == 0 ? 0.35 : 1)
            .disabled(currentIndex == 0)

            plainIconButton("chevron.down", label: "Next article", size: 17) {
                withAnimation { if currentIndex < articles.count - 1 { currentIndex += 1 } }
            }
            .opacity(currentIndex == articles.count - 1 ? 0.35 : 1)
            .disabled(currentIndex == articles.count - 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(themeManager.colors.page)
    }

    private func plainIconButton(_ systemImage: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Typography.symbol(size, weight: .semibold))
                .foregroundColor(themeManager.colors.text)
                .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Action Bar

    /// Docked bar: Save to Library, Add to Up next, Share, Read original.
    private var actionBar: some View {
        let queueState = saveStore.queueState(for: currentArticle)

        return HStack(spacing: 0) {
            barButton(
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                title: isSaved ? "Saved" : "Save",
                tint: isSaved ? themeManager.colors.accent : nil,
                isBusy: isSaving,
                label: isSaved ? "Saved to Library" : "Save to Library"
            ) {
                Task { await saveArticle() }
            }
            .disabled(isSaving || isSaved)

            barButton(
                systemImage: queueState == .done ? "checkmark.circle.fill" : "text.badge.plus",
                title: queueState == .done ? "In Up next" : "Up next",
                tint: queueState == .done ? themeManager.colors.accent : nil,
                isBusy: queueState == .saving,
                label: queueState == .done ? "In Up next" : "Add to Up next"
            ) {
                Task { await saveStore.addToUpNext(currentArticle) }
            }
            .disabled(queueState != nil)

            if let url = URL(string: currentArticle.link) {
                ShareLink(item: url) {
                    barLabel(systemImage: "square.and.arrow.up", title: "Share", tint: nil, isBusy: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")

                barButton(systemImage: "safari", title: "Original", tint: nil, isBusy: false, label: "Read original") {
                    openURL(url)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(themeManager.colors.page.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themeManager.colors.line)
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isSaved)
    }

    private func barButton(
        systemImage: String,
        title: String,
        tint: Color?,
        isBusy: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            barLabel(systemImage: systemImage, title: title, tint: tint, isBusy: isBusy)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func barLabel(systemImage: String, title: String, tint: Color?, isBusy: Bool) -> some View {
        VStack(spacing: 3) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(themeManager.colors.accent)
                } else {
                    Image(systemName: systemImage)
                        .font(Typography.symbol(19))
                }
            }
            .frame(height: 24)
            Text(title)
                .font(Typography.ui(11, weight: .medium, relativeTo: .caption2))
        }
        .foregroundColor(tint ?? themeManager.colors.text)
        .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    /// Save state of the current article, shared with the list's long-press
    /// menu: saving from there already shows the bookmark filled.
    private var isSaving: Bool {
        saveStore.isSaving(currentArticle)
    }

    private var isSaved: Bool {
        saveStore.isSaved(currentArticle)
    }

    private func resetState() {
        displayedContent = ""
        loadContent()
    }

    private func loadContent() {
        let article = currentArticle
        if let content = article.content {
            let decoded = content.decodedHTML
            Task { @MainActor in
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
        await saveStore.saveToLibrary(currentArticle)
    }

    private func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host()?.replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - Article Detail (single page)

/// One page of the feed reader — Editorial Teal: edge-to-edge hero, title,
/// byline / date, serif body and a "Read the original" card.
struct RSSArticleDetailView: View {
    let article: RSSArticle
    let displayedContent: String
    let themeManager: ThemeManager
    let loadContentAction: () -> Void
    @State private var showSafariView = false
    @ScaledMetric(relativeTo: .body) private var heroHeight: CGFloat = 246

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    ZStack {
                        themeManager.colors.surface
                        AsyncImageView(url: url.absoluteString, cornerRadius: 0)
                            .aspectRatio(contentMode: .fill)
                    }
                    .frame(height: heroHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(article.title)
                        .font(Typography.articleTitle)
                        .tracking(-0.3)
                        .lineSpacing(4)
                        .foregroundColor(themeManager.colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    bylineRow

                    if displayedContent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(0..<8, id: \.self) { index in
                                SkeletonView(height: 16, cornerRadius: 4)
                                    .frame(maxWidth: index == 7 ? 200 : .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                        .onAppear {
                            loadContentAction()
                        }
                    } else {
                        Text(displayedContent)
                            .font(Typography.readerBody)
                            .foregroundColor(themeManager.colors.text)
                            .lineSpacing(8)
                            .padding(.top, 4)
                    }

                    if let originalUrl = URL(string: article.link) {
                        Button(action: { showSafariView = true }) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Read the original")
                                        .font(Typography.ui(15, weight: .semibold))
                                        .foregroundColor(themeManager.colors.text)
                                    if let domain = getDomain(from: article.link) {
                                        Text(domain)
                                            .font(Typography.ui(13, relativeTo: .footnote))
                                            .foregroundColor(themeManager.colors.muted)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                                    .font(Typography.symbol(17, weight: .medium))
                                    .foregroundColor(themeManager.colors.text)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.card)
                                    .stroke(themeManager.colors.line, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .fullScreenCover(isPresented: $showSafariView) {
                            SafariView(url: originalUrl)
                                .edgesIgnoringSafeArea(.all)
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, Spacing.readerColumn)
                .padding(.top, 22)
                .padding(.bottom, 40)
            }
        }
        .background(themeManager.colors.page)
    }

    @ViewBuilder
    private var bylineRow: some View {
        HStack(spacing: 6) {
            if let author = article.author?.trimmingCharacters(in: .whitespaces), !author.isEmpty {
                Text("By")
                    .foregroundColor(themeManager.colors.muted)
                Text(author)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let date = article.pubDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(Typography.symbol(13))
                        .accessibilityHidden(true)
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                }
                .foregroundColor(themeManager.colors.muted)
            }
        }
        .font(Typography.ui(13.5, relativeTo: .footnote))
        .accessibilityElement(children: .combine)
    }

    private func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host()?.replacingOccurrences(of: "www.", with: "")
    }
}
