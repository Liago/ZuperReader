import SwiftUI
import Supabase
import Auth

// MARK: - RSS Article List (per-feed)
//
// Schermata 06b del revamp (docs/revamp-ios/feed-channel/README.md): un solo
// canale, header compatto con monogramma del feed, filtro Unread/All che
// persiste per feed, articolo in evidenza con copertina e righe con miniatura
// 78pt. Le quattro frecce di navigazione tra feed che occupavano la testa della
// vista precedente sono state rimosse: si torna indietro e si sceglie un altro
// canale dall'elenco Feeds.

struct RSSArticleListView: View {
    let feed: RSSFeed
    @ObservedObject var viewModel: RSSViewModel

    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var isMarkingRead = false
    @State private var errorMessage: String?
    /// Filtro "Unread" / "All". Persiste per feed (design 06b · Comportamenti).
    @State private var showReadArticles = false
    /// Ultimo refresh riuscito in questa sessione; in mancanza si usa
    /// `feed.updatedAt`.
    @State private var lastRefreshedAt: Date?
    @State private var undo: UndoMarkAllRead?
    @State private var isHeaderCollapsed = false
    @State private var showSafariView = false
    @State private var showDeleteConfirmation = false

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// Articoli marcati come letti dall'ultimo "Mark all read", per l'undo.
    private struct UndoMarkAllRead: Identifiable {
        let id = UUID()
        let articleIds: [UUID]
    }

    init(feed: RSSFeed, viewModel: RSSViewModel) {
        self.feed = feed
        self.viewModel = viewModel
    }

    // MARK: - Derived state

    private var unreadCount: Int {
        articles.filter { !$0.isRead }.count
    }

    private var displayedArticles: [RSSArticle] {
        showReadArticles ? articles : articles.filter { !$0.isRead }
    }

    /// Il più recente non letto, promosso a articolo in evidenza solo se è in
    /// testa alla lista visualizzata (design 06b).
    private var featuredArticle: RSSArticle? {
        guard let first = displayedArticles.first, !first.isRead else { return nil }
        return first
    }

    private var rowArticles: [RSSArticle] {
        featuredArticle == nil ? displayedArticles : Array(displayedArticles.dropFirst())
    }

    /// Se il feed non pubblica mai immagini, righe e copertina collassano a
    /// testo pieno invece di ripetere un segnaposto vuoto.
    private var feedHasImages: Bool {
        articles.contains { ($0.imageUrl?.isEmpty == false) }
    }

    private var filterStorageKey: String {
        "feedShowReadArticles.\(feed.id.uuidString)"
    }

    private var lastUpdatedDate: Date? {
        lastRefreshedAt ?? feed.updatedAt
    }

    private var headerSubtitle: String {
        var parts: [String] = []
        parts.append(unreadCount == 1 ? "1 unread" : "\(unreadCount) unread")
        if let lastUpdatedDate {
            parts.append("updated \(FeedDateFormat.relativeString(from: lastUpdatedDate))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Body

    var body: some View {
        // Il colore riempie anche la striscia della status bar, ma il contenuto
        // resta dentro la safe area: l'header parte a 22pt dal suo bordo, come
        // nel design, senza padding "a mano" per la status bar.
        VStack(spacing: 0) {
            header
            filterBar
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(themeManager.colors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .rssLibrarySaveBanner(bottomPadding: 28)
        .overlay(alignment: .bottom) { undoToast }
        .fullScreenCover(isPresented: $showSafariView) {
            if let siteUrlString = feed.siteUrl, let url = URL(string: siteUrlString) {
                SafariView(url: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .confirmationDialog(
            "Remove \(feed.title)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove feed", role: .destructive) {
                Task {
                    await viewModel.deleteFeed(feed)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its articles will no longer appear in your feeds.")
        }
        .task {
            showReadArticles = UserDefaults.standard.bool(forKey: filterStorageKey)
            await loadArticles(showLoadingIndicator: true)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            IconCircleButton(
                systemImage: "chevron.backward",
                label: "Back",
                glyphWeight: .bold,
                glyphSize: 14,
                size: Spacing.channelIconButtonSize
            ) {
                dismiss()
            }

            HStack(spacing: 11) {
                ChannelMonogram(
                    feed: feed,
                    size: isHeaderCollapsed ? 24 : Spacing.channelAvatarSize
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.title)
                        .font(isHeaderCollapsed ? Typography.caprasimo(17, relativeTo: .body) : Typography.channelTitle)
                        .foregroundColor(themeManager.colors.text)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !isHeaderCollapsed {
                        Text(headerSubtitle)
                            .font(Typography.meta)
                            .foregroundColor(themeManager.colors.muted)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            overflowMenu
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, isHeaderCollapsed ? 10 : 22)
        .padding(.bottom, isHeaderCollapsed ? 10 : 18)
        .background(themeManager.colors.page)
        .animation(.easeInOut(duration: 0.22), value: isHeaderCollapsed)
        .accessibilityElement(children: .contain)
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                Task { await markAllAsRead() }
            } label: {
                Label("Mark all as read", systemImage: "checkmark.circle")
            }
            .disabled(unreadCount == 0 || isMarkingRead)

            Button {
                Task { await refreshFeed() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            if feed.siteUrl != nil {
                Button {
                    showSafariView = true
                } label: {
                    Label("Open site", systemImage: "safari")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove feed", systemImage: "trash")
            }
        } label: {
            IconCircleGlyph(
                systemImage: "ellipsis",
                glyphWeight: .bold,
                glyphSize: 14,
                size: Spacing.channelIconButtonSize
            )
        }
        .minimumTapTarget()
        .accessibilityLabel("Feed options")
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 7) {
            FeedFilterPill(
                title: "Unread",
                dotColor: themeManager.colors.accent2,
                isSelected: !showReadArticles
            ) {
                setShowReadArticles(false)
            }

            FeedFilterPill(title: "All", isSelected: showReadArticles) {
                setShowReadArticles(true)
            }

            Spacer(minLength: 8)

            if unreadCount > 0 {
                FeedActionPill(
                    title: "Mark all read",
                    systemImage: "checkmark",
                    isBusy: isMarkingRead
                ) {
                    Task { await markAllAsRead() }
                }
                .disabled(isMarkingRead)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, 16)
        .background(themeManager.colors.page)
        .animation(.easeInOut(duration: 0.2), value: unreadCount > 0)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if displayedArticles.isEmpty {
            emptyView
        } else {
            listView
        }
    }

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Text(message)
                .font(Typography.figtree(13))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Button("Retry") {
                Task { await loadArticles(showLoadingIndicator: true) }
            }
            .font(Typography.figtree(14, weight: .bold))
            .foregroundColor(themeManager.colors.accent)
            Spacer()
        }
    }

    /// Lista vuota con filtro Unread: testo centrato + link "Show all
    /// articles", nessuna illustrazione (design 06b · Comportamenti).
    private var emptyView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                if articles.isEmpty {
                    Text("No articles yet")
                        .font(Typography.sheetTitle)
                        .foregroundColor(themeManager.colors.text)
                    Text("Pull to refresh this channel.")
                        .font(Typography.figtree(14))
                        .foregroundColor(themeManager.colors.muted)
                } else {
                    Text("All caught up")
                        .font(Typography.sheetTitle)
                        .foregroundColor(themeManager.colors.text)

                    Button {
                        setShowReadArticles(true)
                    } label: {
                        Text("Show all articles")
                            .font(Typography.figtree(14, weight: .bold))
                            .foregroundColor(themeManager.colors.accent)
                    }
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                }
            }
            .padding(.top, 90)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await refreshFeed()
        }
    }

    private var listView: some View {
        List {
            if let featured = featuredArticle {
                articleLink(for: featured) {
                    FeaturedArticleCard(
                        imageUrl: featured.imageUrl,
                        state: state(for: featured),
                        dateLabel: featured.pubDate.map(FeedDateFormat.rowLabel(from:)),
                        readTimeLabel: featured.estimatedReadTime.map { "\($0) min" },
                        title: featured.title,
                        snippet: featured.plainSnippet,
                        showsCover: feedHasImages
                    )
                    .padding(.bottom, 22)
                }
                .listRowSeparator(.hidden)
            }

            ForEach(Array(rowArticles.enumerated()), id: \.element.id) { index, article in
                articleLink(for: article) {
                    FeedArticleRow(
                        imageUrl: article.imageUrl,
                        state: state(for: article),
                        metaLabel: article.pubDate.map(FeedDateFormat.rowLabel(from:)),
                        readTimeLabel: article.estimatedReadTime.map { "\($0) min" },
                        title: article.title,
                        snippet: article.plainSnippet,
                        tint: MediaTint.alternating(index),
                        showsThumbnail: feedHasImages,
                        trailingBadge: saveBadge(for: article)
                    )
                }
                .feedRowSeparator(
                    themeManager.colors.line,
                    inset: feedHasImages ? Spacing.rowSeparatorInset : 0
                )
            }

            // La tab bar copre 84pt: senza questo inset l'ultima riga ci finisce
            // sotto (design 06b · Tab bar).
            Color.clear
                .frame(height: Spacing.scrollBottomInset)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.colors.page)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            let collapsed = offset > 24
            if collapsed != isHeaderCollapsed {
                isHeaderCollapsed = collapsed
            }
        }
        .refreshable {
            await refreshFeed()
        }
    }

    /// Riga tappabile che porta al reader, con swipe e context menu allegati.
    private func articleLink<Content: View>(
        for article: RSSArticle,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let originalIndex = articles.firstIndex(where: { $0.id == article.id })

        return ZStack {
            if let originalIndex {
                NavigationLink(destination: RSSArticleReader(articles: $articles, initialIndex: originalIndex)) {
                    EmptyView()
                }
                .opacity(0)
            }

            content()
        }
        .listRowInsets(EdgeInsets(
            top: 0,
            leading: Spacing.screenHorizontal,
            bottom: 0,
            trailing: Spacing.screenHorizontal
        ))
        .listRowBackground(themeManager.colors.page)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await setRead(!article.isRead, for: article) }
            } label: {
                Label(
                    article.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: article.isRead ? "envelope.badge" : "envelope.open"
                )
            }
            .tint(themeManager.colors.accent)
        }
        .rssArticleContextMenu(article: article) {
            Task { await setRead(true, for: article) }
        }
    }

    private func saveBadge(for article: RSSArticle) -> AnyView? {
        AnyView(RSSArticleSaveBadge(article: article))
    }

    private func state(for article: RSSArticle) -> FeedItemState {
        article.isRead ? .read : .unread
    }

    // MARK: - Undo toast

    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            UndoToast(
                message: undo.articleIds.count == 1
                    ? "1 article marked as read"
                    : "\(undo.articleIds.count) articles marked as read",
                undoTitle: "Undo",
                onUndo: {
                    Task { await undoMarkAllRead(undo) }
                },
                onDismiss: { withAnimation { self.undo = nil } }
            )
            .padding(.bottom, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: undo.id) {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation { self.undo = nil }
            }
        }
    }

    // MARK: - Actions

    private func setShowReadArticles(_ value: Bool) {
        guard value != showReadArticles else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showReadArticles = value
        }
        UserDefaults.standard.set(value, forKey: filterStorageKey)
    }

    private func markAllAsRead() async {
        guard !isMarkingRead else { return }
        let unreadIds = articles.filter { !$0.isRead }.map(\.id)
        guard !unreadIds.isEmpty else { return }

        isMarkingRead = true
        await viewModel.markFeedAsRead(feed)

        let now = Date()
        for index in articles.indices where !articles[index].isRead {
            articles[index].isRead = true
            articles[index].readAt = now
        }
        isMarkingRead = false

        withAnimation {
            undo = UndoMarkAllRead(articleIds: unreadIds)
        }
    }

    private func undoMarkAllRead(_ undo: UndoMarkAllRead) async {
        guard let userId = AuthManager.shared.user?.id.uuidString else { return }
        withAnimation { self.undo = nil }

        do {
            try await RSSService.shared.markArticlesAsUnread(articleIds: undo.articleIds, userId: userId)
            let restored = Set(undo.articleIds)
            for index in articles.indices where restored.contains(articles[index].id) {
                articles[index].isRead = false
                articles[index].readAt = nil
            }
            await viewModel.loadFeeds()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshFeed() async {
        do {
            _ = try await RSSService.shared.refreshFeed(feedId: feed.id, url: feed.url)
            lastRefreshedAt = Date()
            await loadArticles(showLoadingIndicator: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadArticles(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            isLoading = true
        }
        errorMessage = nil
        defer { isLoading = false }

        guard let userId = AuthManager.shared.user?.id.uuidString else { return }
        do {
            articles = try await RSSService.shared.getArticles(
                userId: userId,
                feedId: feed.id,
                includeRead: true
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setRead(_ isRead: Bool, for article: RSSArticle) async {
        guard let userId = AuthManager.shared.user?.id.uuidString,
              let index = articles.firstIndex(where: { $0.id == article.id }) else { return }
        do {
            if isRead {
                try await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
            } else {
                try await RSSService.shared.markArticlesAsUnread(articleIds: [article.id], userId: userId)
            }
            articles[index].isRead = isRead
            articles[index].readAt = isRead ? Date() : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Channel monogram

/// Quadrato 40pt radius 14 con la favicon del canale; senza favicon mostra
/// l'iniziale in Caprasimo su fondo `accent-2-200` (design 06b · Header).
struct ChannelMonogram: View {
    let feed: RSSFeed
    var size: CGFloat = Spacing.channelAvatarSize

    @EnvironmentObject private var themeManager: ThemeManager

    private var initial: String {
        let trimmed = feed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first.map(String.init) ?? "?").uppercased()
    }

    private var faviconURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(feed.url)&sz=128")
    }

    var body: some View {
        ZStack {
            themeManager.colors.accent2_200

            AsyncImage(url: faviconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Text(initial)
                        .font(Typography.caprasimo(size * 0.425, relativeTo: .body))
                        .foregroundColor(themeManager.colors.accent2_800)
                }
            }
            .id(feed.url)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.35, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Save badge

/// Esito dell'action menu (long press → Save to Library) mostrato accanto alla
/// meta della riga.
struct RSSArticleSaveBadge: View {
    let article: RSSArticle

    @ObservedObject private var saveStore = RSSLibrarySaveStore.shared
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
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
        }
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
                .font(Typography.figtree(13, weight: .bold))
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
                    .font(Typography.figtree(13))
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
                                .font(Typography.figtree(15, weight: .bold))
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
