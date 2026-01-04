import Foundation
import SwiftUI
import Combine

@MainActor
class RSSDiscoveryViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [DiscoveredFeed] = []
    @Published var isSearching = false
    @Published var isSubscribing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // To notify parent to reload
    var onSubscribe: (() -> Void)?
    
    private let rssService = RSSService.shared
    
    func search() async {
        guard !query.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        results = []
        
        do {
            let feeds = try await rssService.discoverFeeds(query: query)
            self.results = feeds
            if feeds.isEmpty {
                self.errorMessage = "No feeds found for \"\(query)\""
            }
        } catch {
            self.errorMessage = "Search failed: \(error.localizedDescription)"
        }
        
        isSearching = false
    }
    
    func subscribe(to feed: DiscoveredFeed) async {
        isSubscribing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await rssService.addFeed(url: feed.url)
            self.successMessage = "Subscribed to \(feed.title)"
            onSubscribe?()
            
            // Remove from results to indicate done? Or just show button/icon?
            // Usually we might want to keep it but disabled button.
        } catch {
            self.errorMessage = "Failed to subscribe: \(error.localizedDescription)"
        }
        
        isSubscribing = false
    }
}
