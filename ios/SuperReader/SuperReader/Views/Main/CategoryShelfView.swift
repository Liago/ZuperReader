import SwiftUI

// MARK: - Category Shelf (home · Library grouped by topic)
//
// One horizontal row per category, biggest first. "See all" opens the full
// category page; long-press a card for Up next / favorite / "Move to…".

struct CategoryShelfView: View {
    let section: LibraryCategorySection
    @ObservedObject var viewModel: LibraryHomeViewModel

    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared

    /// Cards on the shelf before "See all".
    private let shelfLimit = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .padding(.horizontal, Spacing.screenHorizontal)

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
                        .contextMenu {
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
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, 8)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: section.category.icon)
                .font(Typography.symbol(14, weight: .bold))
                .foregroundColor(themeManager.colors.accent800)
                .frame(width: 30, height: 30)
                .background(themeManager.colors.accent200)
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(section.category.displayName)
                .font(Typography.figtree(18, weight: .bold, relativeTo: .headline))
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)

            Text("\(section.articles.count)")
                .font(Typography.figtree(12.5, weight: .bold))
                .foregroundColor(themeManager.colors.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.colors.sink)
                .clipShape(Capsule())
                .accessibilityLabel("\(section.articles.count) articles")

            Spacer()

            NavigationLink(destination: CategoryArticlesView(category: section.category, viewModel: viewModel)) {
                HStack(spacing: 4) {
                    Text("See all")
                        .font(Typography.figtree(13.5, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(Typography.symbol(11, weight: .bold))
                }
                .foregroundColor(themeManager.colors.accent800)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
                .frame(width: cardWidth, height: 124)
                .clipped()

            progressTrack

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ReadingStateDot(
                        status: article.readingStatus,
                        accentColor: themeManager.colors.accent,
                        accent2Color: themeManager.colors.accent2,
                        mutedColor: themeManager.colors.muted
                    )
                    if let domain = article.domain {
                        Text(domain.replacingOccurrences(of: "www.", with: "").uppercased())
                            .font(Typography.figtree(11, weight: .bold))
                            .foregroundColor(themeManager.colors.muted)
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
                    .font(Typography.figtree(15, weight: .bold, relativeTo: .subheadline))
                    .foregroundColor(article.readingStatus == .completed ? themeManager.colors.muted : themeManager.colors.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)

                if let readTime = article.estimatedReadTime {
                    Text("\(readTime) min")
                        .font(Typography.meta)
                        .foregroundColor(themeManager.colors.muted)
                }
            }
            .padding(14)
            .frame(width: cardWidth, height: 128, alignment: .topLeading)
        }
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))
        .shadow(color: AppShadows.card.color, radius: 12, x: 0, y: 4)
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
                themeManager.colors.accent2_200
                Image(systemName: category.icon)
                    .font(Typography.symbol(30, weight: .semibold))
                    .foregroundColor(themeManager.colors.accent2)
            }
            .accessibilityHidden(true)
        }
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(themeManager.colors.line)
                Rectangle()
                    .fill(article.readingStatus == .completed ? themeManager.colors.muted.opacity(0.45) : themeManager.colors.accent)
                    .frame(width: geometry.size.width * progressFraction)
            }
        }
        .frame(width: cardWidth, height: 2)
    }

    private var progressFraction: CGFloat {
        if article.readingStatus == .completed { return 1 }
        return min(max(CGFloat(article.readingProgress) / 100, 0), 1)
    }
}
