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
        totalFeedsCount = feeds.count

        if feeds.isEmpty {
            isRefreshing = false
            refreshProgress = nil
            return
        }

        do {
            // Call the web API endpoint (same as the web app)
            refreshProgress = "Updating feeds via server..."
            progressPercentage = 0.3

            let result = try await rssService.refreshFeedsViaAPI()

            progressPercentage = 0.9
            refreshProgress = "Finalizing..."

            if !result.success {
                let errorMsg = result.errors?.joined(separator: ", ") ?? "Unknown error"
                self.errorMessage = "Refresh failed: \(errorMsg)"
            }

            // Reload feeds and unread counts from Supabase
            progressPercentage = 1.0
            await loadFeeds()

        } catch {
            self.errorMessage = "Failed to refresh feeds: \(error.localizedDescription)"
            await loadFeeds()
        }

        // Small delay to let user see 100%
        try? await Task.sleep(nanoseconds: 1_000_000_000)

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
    
    func markFeedAsRead(_ feed: RSSFeed) async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        // Optimistic update
        let previousCount = unreadCounts[feed.id]
        unreadCounts[feed.id] = 0
        
        do {
            try await rssService.markFeedAsRead(feedId: feed.id, userId: userId)
        } catch {
            // Rollback
            unreadCounts[feed.id] = previousCount
            self.errorMessage = "Failed to mark feed as read: \(error.localizedDescription)"
        }
    }
    
    var totalUnreadCount: Int {
        unreadCounts.values.reduce(0, +)
    }
}
