import SwiftUI

// MARK: - All Feeds (combined, unread) — destination of the Feeds screen's
// "All feeds" hero row (docs/revamp-ios/README.md · "06 Feeds").

struct RSSAllFeedsListView: View {
    @ObservedObject var viewModel: RSSViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared

    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            themeManager.colors.page.ignoresSafeArea()

            if isLoading && articles.isEmpty {
                ProgressView()
                    .tint(themeManager.colors.accent)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(Typography.figtree(13))
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
        .task { await loadArticles() }
    }

    private var articleList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(destination: RSSArticleReader(articles: $articles, initialIndex: index)) {
                        row(for: article)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if index < articles.count - 1 {
                        Rectangle()
                            .fill(themeManager.colors.line)
                            .frame(height: 1)
                            .padding(.leading, 56 + 14)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .refreshable { await loadArticles() }
    }

    private func row(for article: RSSArticle) -> some View {
        HStack(spacing: 14) {
            Group {
                if let imageUrl = article.imageUrl {
                    AsyncImageView(url: imageUrl, cornerRadius: CornerRadius.listThumbnail)
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
            .frame(width: 56, height: 56)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !article.isRead {
                        Circle().fill(themeManager.colors.accent).frame(width: 6, height: 6)
                    }
                    Text(feedTitle(for: article).uppercased())
                        .font(Typography.figtree(11, weight: .bold))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                    Spacer()
                    if let date = article.pubDate {
                        Text(date, style: .relative)
                            .font(Typography.meta)
                            .foregroundColor(themeManager.colors.muted)
                    }
                }

                Text(article.title)
                    .font(Typography.listRowTitle)
                    .foregroundColor(article.isRead ? themeManager.colors.muted : themeManager.colors.text)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func feedTitle(for article: RSSArticle) -> String {
        viewModel.feeds.first(where: { $0.id == article.feedId })?.title ?? "Feed"
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(.system(size: 36))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }

            Text("All caught up")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("No unread articles across your feeds.")
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadArticles() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        isLoading = true
        errorMessage = nil

        do {
            articles = try await RSSService.shared.getArticles(userId: userId, feedId: nil, limit: 100, includeRead: false)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
