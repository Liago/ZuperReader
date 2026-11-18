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
                Text(FeedSourceBubble.monogram(for: currentFeed.title))
                    .font(Typography.display(26, weight: .heavy, relativeTo: .title))
                    .foregroundColor(themeManager.colors.text)
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(themeManager.colors.page))
                    .overlay(Circle().stroke(themeManager.colors.line, lineWidth: 1))
                    .accessibilityHidden(true)

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
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .clipped()
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
        // Il colore riempie anche la striscia della status bar, ma il contenuto
        // NON ignora la safe area: così l'inset della top bar arriva alle
        // pagine e il titolo non finisce sotto l'header (stessa struttura del
        // reader della Libreria, ArticleReaderView).
        .background(themeManager.colors.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .rssLibrarySaveBanner()
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

    private var topBar: some View {
        HStack(spacing: 12) {
            IconCircleButton(systemImage: "chevron.backward", label: "Back") {
                dismiss()
            }

            Text(topBarSubtitle)
                .font(Typography.ui(13, weight: .bold))
                .foregroundColor(themeManager.colors.muted)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            IconCircleButton(systemImage: "chevron.up", label: "Previous article", glyphSize: 14) {
                withAnimation { if currentIndex > 0 { currentIndex -= 1 } }
            }
            .opacity(currentIndex == 0 ? 0.35 : 1)
            .disabled(currentIndex == 0)

            IconCircleButton(systemImage: "chevron.down", label: "Next article", glyphSize: 14) {
                withAnimation { if currentIndex < articles.count - 1 { currentIndex += 1 } }
            }
            .opacity(currentIndex == articles.count - 1 ? 0.35 : 1)
            .disabled(currentIndex == articles.count - 1)

            Button(action: { Task { await saveArticle() } }) {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    }
                }
                .font(Typography.symbol(14, weight: .semibold))
                .foregroundColor(isSaved ? themeManager.colors.page : themeManager.colors.text)
                .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                .background(isSaved ? themeManager.colors.accent : themeManager.colors.sink)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel(isSaved ? "Saved to Library" : "Save to Library")
            .disabled(isSaving || isSaved)
            .animation(.easeInOut(duration: 0.2), value: isSaved)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.colors.page)
    }

    private var topBarSubtitle: String {
        var parts: [String] = []
        if let domain = getDomain(from: currentArticle.link) { parts.append(domain) }
        if let date = currentArticle.pubDate { parts.append(date.formatted(date: .abbreviated, time: .omitted)) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    /// Stato di salvataggio dell'articolo corrente, condiviso con l'action menu
    /// della lista (long press): salvando da lì il bookmark risulta già pieno.
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

struct RSSArticleDetailView: View {
    let article: RSSArticle
    let displayedContent: String
    let themeManager: ThemeManager
    let loadContentAction: () -> Void
    @State private var showSafariView = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(article.title)
                    .font(Typography.articleTitle)
                    .tracking(-0.3)
                    .foregroundColor(themeManager.colors.text)

                Text(metaLine)
                    .font(Typography.ui(13))
                    .foregroundColor(themeManager.colors.muted)

                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImageView(url: url.absoluteString, cornerRadius: 22)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 158)
                        .clipped()
                }

                Rectangle()
                    .fill(themeManager.colors.line)
                    .frame(height: 1)

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
                }

                if let originalUrl = URL(string: article.link) {
                    Button(action: { showSafariView = true }) {
                        HStack {
                            Text("Read Original")
                                .font(Typography.ui(15, weight: .bold))
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundColor(themeManager.colors.page)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                    .fullScreenCover(isPresented: $showSafariView) {
                        SafariView(url: originalUrl)
                            .edgesIgnoringSafeArea(.all)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, Spacing.readerColumn)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .background(themeManager.colors.page)
    }

    private var metaLine: String {
        var parts: [String] = []
        if let domain = getDomain(from: article.link) { parts.append(domain) }
        if let date = article.pubDate { parts.append(date.formatted(date: .abbreviated, time: .shortened)) }
        return parts.joined(separator: " · ")
    }

    private func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host()?.replacingOccurrences(of: "www.", with: "")
    }
}
