import Foundation
import SwiftUI
import Combine
import Supabase
import Auth

@MainActor
class RSSViewModel: ObservableObject {
    @Published var feeds: [RSSFeed] = []
    @Published var unreadCounts: [UUID: Int] = [:]
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    
    private let rssService = RSSService.shared
    private let authManager = AuthManager.shared
    
    func loadFeeds() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let feedsTask = rssService.getFeeds(userId: userId)
            async let countsTask = rssService.getUnreadCounts(userId: userId)
            
            let (fetchedFeeds, fetchedCounts) = try await (feedsTask, countsTask)
            
            // Merge counts into feeds for display logic if needed (or just use map)
            // But we keep them separate in VM to update counts independently easily
            
            self.feeds = fetchedFeeds
            self.unreadCounts = fetchedCounts
            
        } catch {
            self.errorMessage = "Failed to load feeds: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @Published var refreshProgress: String? = nil
    @Published var progressPercentage: Double = 0.0
    @Published var processedFeedsCount: Int = 0
    @Published var totalFeedsCount: Int = 0

    func refreshFeeds() async {
        guard !isRefreshing else { return }
        guard authManager.isAuthenticated else { return }
        
        isRefreshing = true
        errorMessage = nil
        refreshProgress = "Starting update..."
        progressPercentage = 0.0
        processedFeedsCount = 0
        
        // 1. Get current feeds to refresh
        let feedsToRefresh = self.feeds
        if feedsToRefresh.isEmpty {
            isRefreshing = false
            refreshProgress = nil
            return
        }
        
        totalFeedsCount = feedsToRefresh.count
        var completed = 0
        
        // 2. Refresh in batches of 5
        let batchSize = 5
        
        do {
            for i in stride(from: 0, to: totalFeedsCount, by: batchSize) {
                let end = min(i + batchSize, totalFeedsCount)
                let batch = feedsToRefresh[i..<end]
                
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for feed in batch {
                        group.addTask {
                            do {
                                _ = try await self.rssService.refreshFeed(feedId: feed.id, url: feed.url)
                            } catch {
                                print("Error refreshing feed \(feed.title) (\(feed.url)): \(error.localizedDescription)")
                            }
                        }
                    }
                    // Wait for all in this batch
                    try await group.waitForAll()
                }
                
                completed += batch.count
                processedFeedsCount = completed
                progressPercentage = Double(completed) / Double(totalFeedsCount)
                refreshProgress = "Updating \(completed)/\(totalFeedsCount)..."
            }
            
            refreshProgress = "Finalizing..."
            progressPercentage = 1.0
            
            // 3. Reload everything
            await loadFeeds()
            
        } catch {
            self.errorMessage = "Failed to refresh feeds: \(error.localizedDescription)"
            await loadFeeds() 
        }
        
        // Add a small delay to let user see 100%
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay to see the result
        
        refreshProgress = nil
        isRefreshing = false
        progressPercentage = 0.0
        processedFeedsCount = 0
        totalFeedsCount = 0
    }
    
    func deleteFeed(_ feed: RSSFeed) async {
        guard let index = feeds.firstIndex(where: { $0.id == feed.id }) else { return }
        
        // Optimistic update
        let removedFeed = feeds.remove(at: index)
        
        do {
            try await rssService.deleteFeed(feedId: feed.id.uuidString)
        } catch {
            // Rollback
            self.feeds.insert(removedFeed, at: index)
            self.errorMessage = "Failed to delete feed: \(error.localizedDescription)"
        }
    }
}
