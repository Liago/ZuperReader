import SwiftUI
import Supabase
import Auth


// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = ArticleListViewModel()
    @ObservedObject private var queueStore = ReadingQueueStore.shared

    @State private var showAddArticle = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    // Header
                    headerView

                    // Filter Bar
                    filterBar

                    // Article List
                    ArticleListView(viewModel: viewModel, onAddArticle: { showAddArticle = true })
                }

            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet(onArticleAdded: {
                    Task { await viewModel.refresh() }
                })
                .environmentObject(themeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .task {
            if let userId = authManager.user?.id.uuidString {
                async let articles: Void = viewModel.loadArticles(userId: userId)
                async let queue: Void = queueStore.load(userId: userId)
                _ = await (articles, queue)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Library")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)

                Spacer()

                HStack(spacing: Spacing.sm) {
                    // Up next (reading queue) — mirrors the web sidebar entry + count badge
                    NavigationLink(destination: QueueView()) {
                        IconCircleGlyph(systemImage: "list.number")
                            .overlay(alignment: .topTrailing) {
                                if queueStore.count > 0 {
                                    Text(queueStore.count > 99 ? "99+" : "\(queueStore.count)")
                                        .font(Typography.figtree(11, weight: .heavy, relativeTo: .caption2))
                                        .foregroundColor(themeManager.colors.page)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(themeManager.colors.accent2)
                                        .clipShape(Capsule())
                                        .offset(x: 5, y: -4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                    .accessibilityLabel("Up next")
                    .accessibilityValue(queueStore.count > 0 ? "\(queueStore.count) queued" : "Empty")

                    // View Mode Toggle
                    IconCircleButton(
                        systemImage: "square.grid.2x2.fill",
                        label: themeManager.viewMode == .list ? "Switch to grid view" : "Switch to list view",
                        style: themeManager.viewMode == .list ? .filled : .sink
                    ) {
                        themeManager.toggleViewMode()
                    }

                    // Add Article Button
                    IconCircleButton(systemImage: "plus", label: "Save a link", style: .accent, glyphSize: 18) {
                        showAddArticle = true
                    }
                }
            }

            // Search Bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.colors.text.opacity(0.55))
                    .accessibilityHidden(true)

                TextField(
                    "",
                    text: $viewModel.searchQuery,
                    prompt: Text("Search articles").foregroundColor(themeManager.colors.muted)
                )
                .font(Typography.figtree(15, relativeTo: .subheadline))
                .foregroundColor(themeManager.colors.text)
                .submitLabel(.search)
                .accessibilityLabel("Search articles")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: Spacing.minTapTarget)
            .background(themeManager.colors.sink)
            .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                FeedFilterPill(
                    title: "All",
                    isSelected: viewModel.filters.readingStatus == nil,
                    action: { viewModel.setReadingStatusFilter(nil) }
                )

                FeedFilterPill(
                    title: "Unread",
                    dotColor: themeManager.colors.accent2,
                    isSelected: viewModel.filters.readingStatus == .unread,
                    action: { viewModel.setReadingStatusFilter(.unread) }
                )

                FeedFilterPill(
                    title: "Reading",
                    dotColor: themeManager.colors.accent,
                    isSelected: viewModel.filters.readingStatus == .reading,
                    action: { viewModel.setReadingStatusFilter(.reading) }
                )

                FeedFilterPill(
                    title: "Done",
                    isSelected: viewModel.filters.readingStatus == .completed,
                    action: { viewModel.setReadingStatusFilter(.completed) }
                )
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager.shared)
}
