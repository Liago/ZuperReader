import SwiftUI
import Supabase
import Auth

// MARK: - RSS Article List (per-feed) — same list/reader language as
// Library and Reader (docs/revamp-ios/README.md), applied to RSS articles.

struct RSSArticleListView: View {
    @State private var currentFeed: RSSFeed
    @ObservedObject var viewModel: RSSViewModel
    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var isMarkingRead = false
    @State private var errorMessage: String?
    @State private var showReadArticles = false // Default: hide read articles
    @State private var transitionDirection: TransitionDirection = .forward
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    enum TransitionDirection {
        case forward, backward
    }

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

    var body: some View {
        ZStack {
            themeManager.colors.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                RSSFeedHeader(
                    feed: currentFeed,
                    unreadCount: articles.filter { !$0.isRead }.count,
                    isMarkingRead: isMarkingRead,
                    hasPrev: hasPrev,
                    hasNext: hasNext,
                    onMarkAllRead: {
                        Task {
                            await markAllAsRead()
                        }
                    },
                    onPrev: {
                        if let idx = currentIndex, idx > 0 {
                            transitionDirection = .backward
                            withAnimation(.easeInOut(duration: 0.35)) {
                                currentFeed = viewModel.feeds[idx - 1]
                            }
                        }
                    },
                    onNext: {
                        if let idx = currentIndex, idx < viewModel.feeds.count - 1 {
                            transitionDirection = .forward
                            withAnimation(.easeInOut(duration: 0.35)) {
                                currentFeed = viewModel.feeds[idx + 1]
                            }
                        }
                    }
                )

                content
                    .id(currentFeed.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: transitionDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: transitionDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .clipped()
            }
        }
        .clipped()
        .navigationBarHidden(true)
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else {
            let displayedArticles = articles.filter { showReadArticles || !$0.isRead }
            if displayedArticles.isEmpty {
                emptyView
            } else {
                listView(displayedArticles)
            }
        }
    }

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
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
            Spacer()
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(themeManager.colors.sink)
                        .frame(width: 96, height: 96)
                    Image(systemName: articles.isEmpty ? "dot.radiowaves.up.forward" : "checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.colors.text.opacity(0.35))
                }

                if articles.isEmpty {
                    Text("No articles yet")
                        .font(Typography.sheetTitle)
                        .foregroundColor(themeManager.colors.text)
                } else {
                    Text("All caught up")
                        .font(Typography.sheetTitle)
                        .foregroundColor(themeManager.colors.text)

                    Button(action: { showReadArticles = true }) {
                        Text("Show read articles")
                            .font(Typography.figtree(14, weight: .semibold))
                            .foregroundColor(themeManager.colors.accent)
                    }
                }
            }
            .padding(.top, 100)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await refreshFeed()
        }
    }

    private func listView(_ displayedArticles: [RSSArticle]) -> some View {
        List {
            ForEach(Array(displayedArticles.enumerated()), id: \.element.id) { index, article in
                let originalIndex = articles.firstIndex(where: { $0.id == article.id }) ?? index

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
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.colors.page)
        .refreshable {
            await refreshFeed()
        }
    }

    // MARK: - Actions

    private func markAllAsRead() async {
        isMarkingRead = true
        await viewModel.markFeedAsRead(currentFeed)

        await MainActor.run {
            for i in articles.indices {
                articles[i].isRead = true
                articles[i].readAt = Date()
            }
        }

        try? await Task.sleep(nanoseconds: 400_000_000)
        isMarkingRead = false

        if let idx = currentIndex, idx < viewModel.feeds.count - 1 {
            transitionDirection = .forward
            withAnimation(.easeInOut(duration: 0.35)) {
                currentFeed = viewModel.feeds[idx + 1]
            }
        } else {
            dismiss()
        }
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
            var updatedArticle = article
            updatedArticle.isRead = true
            updatedArticle.readAt = Date()
            articles[index] = updatedArticle
        } catch {
            print("Failed to mark article as read: \(error)")
        }
    }
}

// MARK: - Feed Header

struct RSSFeedHeader: View {
    let feed: RSSFeed
    let unreadCount: Int
    let isMarkingRead: Bool
    let hasPrev: Bool
    let hasNext: Bool
    let onMarkAllRead: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showSafariView = false

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                iconButton(systemImage: "chevron.left", action: { dismiss() })

                iconButton(systemImage: "arrow.left", enabled: hasPrev, action: onPrev)

                Spacer(minLength: 4)

                centerContent

                Spacer(minLength: 4)

                iconButton(systemImage: "arrow.right", enabled: hasNext, action: onNext)

                Button(action: onMarkAllRead) {
                    Group {
                        if isMarkingRead {
                            ProgressView()
                                .tint(themeManager.colors.page)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(themeManager.colors.page)
                    .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                    .background(themeManager.colors.accent)
                    .clipShape(Circle())
                }
                .opacity(unreadCount > 0 ? 1 : 0.35)
                .disabled(unreadCount == 0 || isMarkingRead)
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)
            .padding(.bottom, 12)

            Rectangle()
                .fill(themeManager.colors.line)
                .frame(height: 1)
        }
        .background(themeManager.colors.page)
        .fullScreenCover(isPresented: $showSafariView) {
            if let siteUrlString = feed.siteUrl, let url = URL(string: siteUrlString) {
                SafariView(url: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private func iconButton(systemImage: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(themeManager.colors.text)
                .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                .background(themeManager.colors.sink)
                .clipShape(Circle())
        }
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }

    private var centerContent: some View {
        VStack(spacing: 2) {
            AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(feed.url)&sz=128")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                default:
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.colors.accent)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(themeManager.colors.sink))
                }
            }
            .id(feed.url)

            Text(feed.title)
                .font(Typography.figtree(15, weight: .bold))
                .foregroundColor(themeManager.colors.text)
                .lineLimit(1)
                .id(feed.id)

            Text("\(unreadCount) unread")
                .font(Typography.meta)
                .foregroundColor(themeManager.colors.muted)
                .contentTransition(.numericText())
        }
        .animation(.easeInOut(duration: 0.3), value: feed.id)
        .onTapGesture {
            if feed.siteUrl != nil {
                showSafariView = true
            }
        }
    }
}

// MARK: - Article Row

struct RSSArticleRow: View {
    let article: RSSArticle
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !article.isRead {
                        Circle().fill(themeManager.colors.accent).frame(width: 7, height: 7)
                    }
                    if let date = article.pubDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(Typography.meta)
                            .foregroundColor(themeManager.colors.muted)
                    }
                }

                Text(article.title)
                    .font(Typography.listRowTitle)
                    .foregroundColor(article.isRead ? themeManager.colors.muted : themeManager.colors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let snippet = article.contentSnippet {
                    Text(snippet.strippingHTML())
                        .font(Typography.bodyExcerpt)
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        Group {
            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                AsyncImageView(url: url.absoluteString, cornerRadius: CornerRadius.listThumbnail)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    themeManager.colors.accent200
                    Image(systemName: "dot.radiowaves.up.forward")
                        .foregroundColor(themeManager.colors.accent800.opacity(0.6))
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))
            }
        }
        .frame(width: 66, height: 66)
        .clipped()
    }
}

// MARK: - Article Reader (paged)

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
        .background(themeManager.colors.page)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .overlay(alignment: .bottom) {
            if let msg = saveMessage {
                Text(msg)
                    .font(Typography.figtree(14, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(themeManager.colors.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
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
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                    .background(themeManager.colors.sink)
                    .clipShape(Circle())
            }

            Text(topBarSubtitle)
                .font(Typography.figtree(13, weight: .bold))
                .foregroundColor(themeManager.colors.muted)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Button(action: { withAnimation { if currentIndex > 0 { currentIndex -= 1 } } }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                    .background(themeManager.colors.sink)
                    .clipShape(Circle())
            }
            .opacity(currentIndex == 0 ? 0.35 : 1)
            .disabled(currentIndex == 0)

            Button(action: { withAnimation { if currentIndex < articles.count - 1 { currentIndex += 1 } } }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                    .background(themeManager.colors.sink)
                    .clipShape(Circle())
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSaved ? themeManager.colors.page : themeManager.colors.text)
                .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                .background(isSaved ? themeManager.colors.accent : themeManager.colors.sink)
                .clipShape(Circle())
            }
            .disabled(isSaving || isSaved)
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

    private func resetState() {
        isSaved = false
        saveMessage = nil
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
