import SwiftUI

struct RSSListView: View {
    @StateObject private var viewModel = RSSViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDiscovery = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.feeds.isEmpty {
                    loadingView
                } else if viewModel.feeds.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            allFeedsRow
                            feedList
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.scrollBottomInset)
                    }
                    .refreshable {
                        await viewModel.refreshFeedsViaAPI()
                    }
                }

                if viewModel.isRefreshing {
                    RSSRefreshLoaderView(viewModel: viewModel)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingDiscovery) {
                RSSDiscoveryView {
                    Task { await viewModel.loadFeeds() }
                }
                .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingSettings) {
                RSSSettingsView()
                    .environmentObject(themeManager)
            }
            .task {
                await viewModel.loadFeeds()
                if viewModel.shouldAutoRefresh() {
                    await viewModel.refreshFeedsViaAPI()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Feeds")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)

                Spacer()

                HStack(spacing: Spacing.sm) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.colors.text)
                            .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                            .background(themeManager.colors.sink)
                            .clipShape(Circle())
                    }

                    Button(action: { showingDiscovery = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(themeManager.colors.page)
                            .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                            .background(themeManager.colors.accent)
                            .clipShape(Circle())
                    }
                }
            }

            Text(subtitle)
                .font(Typography.figtree(13.5))
                .foregroundColor(themeManager.colors.muted)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
        .padding(.bottom, Spacing.md)
        .background(themeManager.colors.page)
    }

    private var subtitle: String {
        let channels = viewModel.feeds.count
        let unread = viewModel.totalUnreadCount
        return "\(channels) channel\(channels == 1 ? "" : "s") · \(unread) unread · \(viewModel.lastSyncedDescription)"
    }

    // MARK: - All Feeds Hero Row

    private var allFeedsRow: some View {
        NavigationLink(destination: RSSAllFeedsListView(viewModel: viewModel)) {
            HStack(spacing: 14) {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 20, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("All feeds")
                        .font(Typography.caprasimo(16))
                    Text("Everything, newest first")
                        .font(Typography.figtree(12.5))
                        .opacity(0.85)
                }

                Spacer()

                if viewModel.totalUnreadCount > 0 {
                    Text("\(viewModel.totalUnreadCount)")
                        .font(Typography.figtree(14, weight: .heavy))
                }
            }
            .foregroundColor(themeManager.colors.page)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(themeManager.colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Feed List

    // Folders (`RSSFeed.folderId`) aren't backed by any folder CRUD yet on
    // either platform, so feeds render as one flat list rather than the
    // "Design" / "Long reads" grouping in the mock.
    private var feedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.feeds.enumerated()), id: \.element.id) { index, feed in
                NavigationLink(destination: RSSArticleListView(feed: feed, viewModel: viewModel)) {
                    RSSFeedRow(feed: feed, unreadCount: viewModel.unreadCounts[feed.id] ?? 0, monogramIndex: index)
                }
                .buttonStyle(ScaleButtonStyle())

                if index < viewModel.feeds.count - 1 {
                    Rectangle()
                        .fill(themeManager.colors.line)
                        .frame(height: 1)
                        .padding(.leading, 12 + 36 + 14)
                }
            }
        }
        .padding(.horizontal, 12)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.contentTop + 60)
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }

            Text("No feeds yet")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("Follow your favorite websites\nto see their latest articles here.")
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)

            Button(action: { showingDiscovery = true }) {
                Text("Discover feeds")
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Feed Row

struct RSSFeedRow: View {
    let feed: RSSFeed
    let unreadCount: Int
    let monogramIndex: Int
    @EnvironmentObject var themeManager: ThemeManager

    var domain: String {
        URL(string: feed.siteUrl ?? feed.url)?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    private var monogramLetter: String {
        String(feed.title.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    private var isFullyRead: Bool { unreadCount == 0 }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(monogramIndex % 2 == 0 ? themeManager.colors.accent200 : themeManager.colors.accent2_200)
                Text(monogramLetter)
                    .font(Typography.figtree(15, weight: .heavy))
                    .foregroundColor(monogramIndex % 2 == 0 ? themeManager.colors.accent800 : themeManager.colors.accent2)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)

                if !domain.isEmpty {
                    Text(domain)
                        .font(Typography.figtree(12.5))
                        .foregroundColor(themeManager.colors.muted)
                }
            }

            Spacer()

            if isFullyRead {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.colors.muted)
            } else {
                Text("\(unreadCount)")
                    .font(Typography.figtree(14, weight: .heavy))
                    .foregroundColor(themeManager.colors.accent)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .opacity(isFullyRead ? 0.62 : 1)
        .contentShape(Rectangle())
    }
}

#Preview {
    RSSListView()
        .environmentObject(ThemeManager.shared)
}
