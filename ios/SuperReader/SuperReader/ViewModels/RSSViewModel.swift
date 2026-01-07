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

    func refreshFeeds() async {
        guard authManager.isAuthenticated else { return }
        
        isRefreshing = true
        errorMessage = nil
        refreshProgress = "Starting update..."
        
        // 1. Get current feeds to refresh
        let feedsToRefresh = self.feeds
        if feedsToRefresh.isEmpty {
            isRefreshing = false
            refreshProgress = nil
            return
        }
        
        let total = feedsToRefresh.count
        var completed = 0
        
        // 2. Refresh in batches of 5
        let batchSize = 5
        
        do {
            // We use a task group to run batches
            // Since we want to limit concurrency to 5, we can just loop through chunks
            // OR use a semaphore. Chunks is easier to implement without extra deps.
            
            for i in stride(from: 0, to: total, by: batchSize) {
                let end = min(i + batchSize, total)
                let batch = feedsToRefresh[i..<end]
                
                refreshProgress = "Updating \(completed)/\(total)..."
                
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for feed in batch {
                        group.addTask {
                            _ = try await self.rssService.refreshFeed(feedId: feed.id, url: feed.url)
                        }
                    }
                    // Wait for all in this batch
                    try await group.waitForAll()
                }
                
                completed += batch.count
            }
            
            refreshProgress = "Finalizing..."
            
            // 3. Reload everything
            await loadFeeds()
            
        } catch {
            self.errorMessage = "Failed to refresh some feeds: \(error.localizedDescription)"
            await loadFeeds() // Reload anyway to show what succeeded
        }
        
        refreshProgress = nil
        isRefreshing = false
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
