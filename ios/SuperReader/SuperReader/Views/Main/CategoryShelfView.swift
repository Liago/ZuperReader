import SwiftUI

// MARK: - Category Shelf (home · Library grouped by topic)
//
// One block per category, biggest first: a horizontal row of cards in grid
// mode, the first rows of the category in list mode (header toggle).
// "See all" opens the full category page; long-press an article for
// Up next / favorite / "Move to…".

struct CategoryShelfView: View {
    let section: LibraryCategorySection
    @ObservedObject var viewModel: LibraryHomeViewModel

    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared

    /// Cards on the shelf before "See all" (grid mode).
    private let shelfLimit = 10
    /// Rows under the header before "See all" (list mode).
    private let listLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .padding(.horizontal, Spacing.screenHorizontal)

            if themeManager.viewMode == .grid {
                cardsRow
            } else {
                listRows
                    .padding(.horizontal, Spacing.screenHorizontal)
            }
        }
    }

    // MARK: - Grid mode (horizontal cards)

    private var cardsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(section.articles.prefix(shelfLimit)) { article in
                    NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                        ShelfArticleCard(
                            article: article,
                            category: section.category,
                            queueState: queueState(for: article)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .contextMenu { menuItems(for: article) }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - List mode (compact rows)

    private var listRows: some View {
        let articles = Array(section.articles.prefix(listLimit))

        return VStack(spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                    ArticleRowView(article: article, queueState: queueState(for: article))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { menuItems(for: article) }

                if index < articles.count - 1 {
                    Rectangle()
                        .fill(themeManager.colors.line)
                        .frame(height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func menuItems(for article: Article) -> some View {
        LibraryArticleMenuItems(
            article: article,
            currentCategory: categoryStore.category(for: article),
            queueState: queueState(for: article),
            onFavorite: { Task { await viewModel.toggleFavorite(article) } },
            onAddToQueue: { Task { await viewModel.addToQueue(article) } },
            onMove: { viewModel.move(article, to: $0) },
            onDelete: { Task { await viewModel.delete(article) } }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(section.category.displayName)
                .font(Typography.ui(17, weight: .semibold, relativeTo: .headline))
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)

            Text("\(section.articles.count)")
                .font(Typography.ui(13, relativeTo: .footnote))
                .foregroundColor(themeManager.colors.muted)
                .accessibilityLabel("\(section.articles.count) articles")

            Spacer()

            NavigationLink(destination: CategoryArticlesView(category: section.category, viewModel: viewModel)) {
                Text("See all")
                    .font(Typography.ui(13.5, weight: .medium))
                    .foregroundColor(themeManager.colors.accent)
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel("See all \(section.category.displayName) articles")
        }
    }

    private func queueState(for article: Article) -> QueueActionState? {
        if queueStore.isPending(article.id) { return .saving }
        if queueStore.isQueued(article.id) { return .done }
        return nil
    }
}

// MARK: - Shelf Article Card

private struct ShelfArticleCard: View {
    let article: Article
    let category: ArticleCategory
    let queueState: QueueActionState?

    @EnvironmentObject var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 220

    // Editorial Teal shelf card: image tile on its own (no card fill, no
    // shadow), then source line, title and read time underneath.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(width: cardWidth, height: 124)
                .clipped()
                .overlay(alignment: .bottom) {
                    if progressFraction > 0 {
                        progressTrack
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))

            HStack(spacing: 6) {
                if let domain = article.domain {
                    Text(domain.replacingOccurrences(of: "www.", with: ""))
                        .font(Typography.ui(12, weight: .semibold, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.accent)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if article.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(Typography.symbol(10, weight: .bold))
                        .foregroundColor(themeManager.colors.accent)
                        .accessibilityLabel("Favorite")
                }
                if let queueState {
                    QueueStateGlyph(state: queueState, size: 10)
                }
            }

            Text(article.title)
                .font(Typography.ui(15, weight: .semibold, relativeTo: .subheadline))
                .foregroundColor(article.readingStatus == .completed ? themeManager.colors.muted : themeManager.colors.text)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let readTime = article.estimatedReadTime {
                Text(article.readingStatus == .completed ? "Read" : "\(readTime) min")
                    .font(Typography.ui(12, relativeTo: .caption))
                    .foregroundColor(themeManager.colors.muted)
            }
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageUrl = article.imageUrl {
            ZStack {
                themeManager.colors.accent200
                AsyncImageView(url: imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
            }
        } else {
            ZStack {
                themeManager.colors.surface
                Image(systemName: category.icon)
                    .font(Typography.symbol(28, weight: .regular))
                    .foregroundColor(themeManager.colors.muted)
            }
            .accessibilityHidden(true)
        }
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.6))
                Rectangle()
                    .fill(article.readingStatus == .completed ? themeManager.colors.muted : themeManager.colors.accent)
                    .frame(width: geometry.size.width * progressFraction)
            }
        }
        .frame(width: cardWidth, height: 3)
        .accessibilityHidden(true)
    }

    private var progressFraction: CGFloat {
        if article.readingStatus == .completed { return 1 }
        return min(max(CGFloat(article.readingProgress) / 100, 0), 1)
    }
}
