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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.feeds) { feed in
                                NavigationLink(destination: RSSArticleListView(feed: feed)) {
                                    RSSFeedRow(feed: feed, unreadCount: viewModel.unreadCounts[feed.id] ?? 0)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        // Create a detached task to avoid cancellation when view updates
                        Task {
                            await viewModel.refreshFeeds()
                        }
                    }
                }
                
                if viewModel.isRefreshing {
                    RSSRefreshLoaderView(viewModel: viewModel)
                }
            }
            .navigationTitle("Feeds")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingDiscovery = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
        VStack(spacing: 24) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 72))
                .foregroundColor(themeManager.colors.textSecondary.opacity(0.3))
                .padding()
                .background(
                    Circle()
                        .fill(themeManager.colors.bgSecondary)
                        .frame(width: 120, height: 120)
                )
            
            VStack(spacing: 8) {
                Text("No RSS Feeds")
                    .font(.title2.bold())
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("Follow your favorite websites\nto see their latest articles here.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            
            Button(action: { showingDiscovery = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Discover Feeds")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 12)
        }
        .padding()
    }
}

struct RSSFeedRow: View {
    let feed: RSSFeed
    let unreadCount: Int
    @EnvironmentObject var themeManager: ThemeManager
    
    var domain: String {
        URL(string: feed.siteUrl ?? feed.url)?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Favicon with glow
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(feed.url)&sz=128")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "rss")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(feed.title)
                    .font(.headline)
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(1)
                
                if !domain.isEmpty {
                    Text(domain)
                        .font(.caption)
                        .foregroundColor(themeManager.colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Unread Badge
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .padding(.horizontal, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.colors.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(themeManager.colors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// Helper Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
