import SwiftUI

struct RSSListView: View {
    @StateObject private var viewModel = RSSViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDiscovery = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.feeds.isEmpty {
                    ProgressView()
                } else if viewModel.feeds.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.feeds) { feed in
                            NavigationLink(destination: RSSArticleListView(feed: feed)) {
                                RSSFeedRow(feed: feed, unreadCount: viewModel.unreadCounts[feed.id] ?? 0)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let feed = viewModel.feeds[index]
                                Task { await viewModel.deleteFeed(feed) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.refreshFeeds()
                    }
                }
                // end of list

                if viewModel.isRefreshing {
                    RSSRefreshLoaderView(viewModel: viewModel)
                }
            }
            .navigationTitle("Feeds")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingDiscovery = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDiscovery) {
                RSSDiscoveryView {
                    Task { await viewModel.loadFeeds() }
                }
                .environmentObject(themeManager)
            }
            .task {
                await viewModel.loadFeeds()
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No RSS Feeds")
                .font(.title2.bold())
                .foregroundColor(themeManager.colors.textPrimary)
            Text("Follow your favorite websites to see their latest articles here.")
                .multilineTextAlignment(.center)
                .foregroundColor(themeManager.colors.textSecondary)
                .padding(.horizontal)
            
            Button(action: { showingDiscovery = true }) {
                Text("Discover Feeds")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(themeManager.colors.accent)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct RSSFeedRow: View {
    let feed: RSSFeed
    let unreadCount: Int
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            // Favicon
            AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(feed.url)&sz=128")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(4)
                case .failure:
                    Image(systemName: "rss")
                        .foregroundColor(.orange)
                case .empty:
                     Color.gray.opacity(0.1)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 30, height: 30)
            .background(Color.white) // readable on dark backgrounds too
            .cornerRadius(4)
            
            Text(feed.title)
                .font(.body)
                .foregroundColor(themeManager.colors.textPrimary)
            
            Spacer()
            
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
    }
}
