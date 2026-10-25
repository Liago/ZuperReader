import SwiftUI

// MARK: - Category Articles ("See all" of a home shelf)
//
// Every Library article of one category (Up next items excluded, same as the
// shelf), honouring the home's reading-status filter and list/grid mode.

struct CategoryArticlesView: View {
    let category: ArticleCategory
    @ObservedObject var viewModel: LibraryHomeViewModel

    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var queueStore = ReadingQueueStore.shared
    @ObservedObject private var categoryStore = ArticleCategoryStore.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("savedReadingStatusFilter") private var savedStatusFilter: String = ""

    private let gridColumns = [GridItem(.flexible(), spacing: Spacing.md)]

    private var readingStatus: ReadingStatus? {
        ReadingStatus(rawValue: savedStatusFilter)
    }

    private var articles: [Article] {
        viewModel.articles(
            in: category,
            readingStatus: readingStatus,
            excluding: queueStore.queuedArticleIds,
            categories: categoryStore
        )
    }

    var body: some View {
        ZStack {
            themeManager.colors.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if articles.isEmpty {
                    emptyView
                } else if themeManager.viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                IconCircleButton(systemImage: "chevron.backward", label: "Back") {
                    dismiss()
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(countLabel)
                    .font(Typography.figtree(11, weight: .bold))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundColor(themeManager.colors.muted)

                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(Typography.symbol(20, weight: .bold))
                        .foregroundColor(themeManager.colors.accent800)
                        .accessibilityHidden(true)
                    Text(category.displayName)
                        .font(Typography.largeTitle)
                        .foregroundColor(themeManager.colors.text)
                }

                Text("Sorted automatically by topic. Long-press an article and choose “Move to…” to change it.")
                    .font(Typography.figtree(13.5))
                    .lineSpacing(3)
                    .foregroundColor(themeManager.colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var countLabel: String {
        let n = articles.count
        var label = "\(n) \(n == 1 ? "article" : "articles")"
        if let readingStatus {
            label += " · \(readingStatus.displayName)"
        }
        return label
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(articles) { article in
                ZStack {
                    NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                        EmptyView()
                    }
                    .opacity(0)

                    ArticleRowView(article: article, queueState: queueState(for: article))
                }
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: Spacing.screenHorizontal,
                    bottom: 0,
                    trailing: Spacing.screenHorizontal
                ))
                .listRowSeparatorTint(themeManager.colors.line)
                .listRowBackground(themeManager.colors.page)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if queueState(for: article) == nil {
                        Button {
                            Task { await viewModel.addToQueue(article) }
                        } label: {
                            Label("Up next", systemImage: "text.badge.plus")
                        }
                        .tint(themeManager.colors.accent2)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(article) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu { menuItems(for: article) }
            }

            Color.clear
                .frame(height: Spacing.scrollBottomInset)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.colors.page)
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                ForEach(articles) { article in
                    NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
                        ArticleCardView(
                            article: article,
                            queueState: queueState(for: article),
                            onFavorite: { Task { await viewModel.toggleFavorite(article) } },
                            onAddToQueue: { Task { await viewModel.addToQueue(article) } },
                            onDelete: { Task { await viewModel.delete(article) } },
                            currentCategory: categoryStore.category(for: article),
                            onMoveToCategory: { viewModel.move(article, to: $0) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .refreshable { await viewModel.refresh() }
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

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: category.icon)
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }

            Text("Nothing here right now")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("Articles of this topic moved elsewhere, went to Up next or don't match the current filter.")
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func queueState(for article: Article) -> QueueActionState? {
        if queueStore.isPending(article.id) { return .saving }
        if queueStore.isQueued(article.id) { return .done }
        return nil
    }
}
