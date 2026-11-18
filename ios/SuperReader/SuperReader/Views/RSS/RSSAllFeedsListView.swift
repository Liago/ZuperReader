import SwiftUI
import Auth

// MARK: - All Feeds (combined, unread) — destination of the Feeds tab's
// "See all unread" link and of "All feeds" in the home sources row.

struct RSSAllFeedsListView: View {
    @ObservedObject var viewModel: RSSViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared

    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    /// Where the reader was left, to scroll back to that article (#134).
    @State private var readerPosition: RSSReaderPosition?
    /// Source / destination of the App Store–style article zoom (#135).
    @Namespace private var articleZoom

    var body: some View {
        ZStack {
            themeManager.colors.page.ignoresSafeArea()

            if isLoading && articles.isEmpty {
                ProgressView()
                    .tint(themeManager.colors.accent)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(Typography.ui(13))
                    .foregroundColor(themeManager.colors.muted)
                    .padding()
            } else if articles.isEmpty {
                emptyState
            } else {
                articleList
            }
        }
        .navigationTitle("All feeds")
        .navigationBarTitleDisplayMode(.inline)
        .rssLibrarySaveBanner(bottomPadding: 28)
        // Only the first appearance loads: coming back from the reader the
        // list keeps its rows (read ones dimmed) and its scroll position.
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await loadArticles()
        }
    }

    private var articleList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                        NavigationLink(
                            destination: RSSArticleReader(
                                articles: $articles,
                                initialIndex: index,
                                onPositionChange: { readerPosition = $0 }
                            )
                            .articleZoomDestination(id: article.id, in: articleZoom)
                        ) {
                            RSSArticleRow(article: article, feedTitle: feedTitle(for: article))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .articleZoomSource(id: article.id, in: articleZoom)
                        .rssArticleContextMenu(article: article) {
                            Task { await markAsRead(article: article, at: index) }
                        }

                        if index < articles.count - 1 {
                            Rectangle()
                                .fill(themeManager.colors.line)
                                .frame(height: 1)

                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.scrollBottomInset)
            }
            .refreshable { await loadArticles() }
            .onAppear {
                restoreScrollPosition(with: proxy)
            }
        }
    }

    /// Back from the reader: if the user paged to another article, scroll
    /// to it so the list stays where the reading ended (#134).
    private func restoreScrollPosition(with proxy: ScrollViewProxy) {
        guard let position = readerPosition else { return }
        readerPosition = nil
        guard position.currentId != position.openedId,
              articles.contains(where: { $0.id == position.currentId }) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(position.currentId, anchor: .center)
        }
    }

    private func feedTitle(for article: RSSArticle) -> String {
        viewModel.feeds.first(where: { $0.id == article.feedId })?.title ?? "Feed"
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.surface)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(Typography.symbol(34))
                    .foregroundColor(themeManager.colors.muted)
            }

            Text("All caught up")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("No unread articles across your feeds.")
                .font(Typography.ui(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func markAsRead(article: RSSArticle, at index: Int) async {
        guard let userId = authManager.user?.id.uuidString else { return }
        do {
            try await RSSService.shared.markArticleAsRead(articleId: article.id, userId: userId)
            guard articles.indices.contains(index), articles[index].id == article.id else { return }
            articles[index].isRead = true
            articles[index].readAt = Date()
        } catch {
            print("Failed to mark article as read: \(error)")
        }
    }

    private func loadArticles() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        isLoading = articles.isEmpty
        errorMessage = nil

        do {
            articles = try await RSSService.shared.getArticles(userId: userId, feedId: nil, limit: 100, includeRead: false)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
