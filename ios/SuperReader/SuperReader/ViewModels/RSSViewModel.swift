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

    static let lastAutoRefreshKey = "rss.lastAutoRefreshDate"
    static let autoRefreshIntervalKey = "rss.autoRefreshInterval"

    private var lastRefreshDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastAutoRefreshKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastAutoRefreshKey) }
    }

    static var autoRefreshInterval: RSSRefreshInterval {
        guard let raw = UserDefaults.standard.string(forKey: autoRefreshIntervalKey),
              let value = RSSRefreshInterval(rawValue: raw) else {
            return .fifteenMinutes
        }
        return value
    }

    func shouldAutoRefresh() -> Bool {
        guard let seconds = Self.autoRefreshInterval.seconds else { return false }
        guard let last = lastRefreshDate else { return true }
        return Date().timeIntervalSince(last) >= seconds
    }
    
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
    
    // MARK: - Refresh progress

    /// Stato di scansione di una singola fonte, mostrato nella modale di attesa.
    struct FeedScanItem: Identifiable, Equatable {
        enum State: Equatable {
            case pending
            case scanning
            case done
            case failed
        }

        let id: UUID
        let title: String
        var state: State
    }

    @Published var refreshProgress: String? = nil
    @Published var progressPercentage: Double = 0.0
    @Published var processedFeedsCount: Int = 0
    @Published var totalFeedsCount: Int = 0
    /// Fonti coinvolte nel refresh in corso, con il rispettivo stato.
    @Published var scanItems: [FeedScanItem] = []
    /// `true` solo quando conosciamo il progresso reale fonte per fonte (parser
    /// on-device). Il refresh server-side è una singola richiesta: sappiamo
    /// quante e quali fonti sono coinvolte, non quale sia in corso.
    @Published var hasDeterminateProgress: Bool = false

    private func updateScanItem(_ feedId: UUID, to state: FeedScanItem.State) {
        guard let index = scanItems.firstIndex(where: { $0.id == feedId }) else { return }
        scanItems[index].state = state
    }

    private func resetRefreshProgress() {
        refreshProgress = nil
        progressPercentage = 0.0
        processedFeedsCount = 0
        totalFeedsCount = 0
        scanItems = []
        hasDeterminateProgress = false
    }

    private func sourcesLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "source" : "sources")"
    }

    /// "Scanning 9to5Mac, The Verge +3 more…" per il batch in corso.
    private func scanningLabel(for batch: [RSSFeed]) -> String {
        let names = batch.prefix(2).map(\.title).joined(separator: ", ")
        if batch.count > 2 {
            return "Scanning \(names) +\(batch.count - 2) more…"
        }
        return "Scanning \(names)…"
    }

    func refreshFeeds() async {
        guard !isRefreshing else { return }
        guard authManager.isAuthenticated else { return }

        let feedsToRefresh = self.feeds
        guard !feedsToRefresh.isEmpty else { return }

        isRefreshing = true
        errorMessage = nil
        refreshProgress = "Starting update..."
        progressPercentage = 0.0
        processedFeedsCount = 0
        totalFeedsCount = feedsToRefresh.count
        hasDeterminateProgress = true
        scanItems = feedsToRefresh.map { FeedScanItem(id: $0.id, title: $0.title, state: .pending) }

        let service = rssService
        var completed = 0

        // Refresh feeds in batches of 5 with real progress tracking
        let batchSize = 5

        for i in stride(from: 0, to: feedsToRefresh.count, by: batchSize) {
            let end = min(i + batchSize, feedsToRefresh.count)
            let batch = Array(feedsToRefresh[i..<end])

            for feed in batch {
                updateScanItem(feed.id, to: .scanning)
            }
            refreshProgress = scanningLabel(for: batch)

            await withTaskGroup(of: (UUID, Bool).self) { group in
                for feed in batch {
                    let feedId = feed.id
                    let url = feed.url
                    let title = feed.title

                    group.addTask {
                        do {
                            _ = try await service.refreshFeed(feedId: feedId, url: url)
                            return (feedId, true)
                        } catch {
                            print("Error refreshing feed \(title) (\(url)): \(error.localizedDescription)")
                            return (feedId, false)
                        }
                    }
                }

                // Ogni fonte aggiorna la modale appena finisce, non a fine batch.
                for await (feedId, success) in group {
                    completed += 1
                    updateScanItem(feedId, to: success ? .done : .failed)
                    processedFeedsCount = completed
                    progressPercentage = Double(completed) / Double(totalFeedsCount)
                }
            }
        }

        refreshProgress = "Finalizing..."
        progressPercentage = 1.0

        // Reload feeds and unread counts from Supabase
        await loadFeeds()

        // Small delay to let user see 100%
        try? await Task.sleep(nanoseconds: 800_000_000)

        resetRefreshProgress()
        isRefreshing = false
    }

    /// Refresh all feeds through the web API (server-side, same path as the web app,
    /// which parses feeds with the robust `rss-parser` library). Falls back to the
    /// on-device client parser if the server is unreachable (offline resilience).
    func refreshFeedsViaAPI() async {
        guard !isRefreshing else { return }
        guard authManager.isAuthenticated else { return }

        let sources = self.feeds

        do {
            isRefreshing = true
            errorMessage = nil
            totalFeedsCount = sources.count
            processedFeedsCount = 0
            progressPercentage = 0.0
            // Il server aggiorna tutte le fonti in un colpo solo: le mostriamo
            // tutte in scansione, con barra indeterminata.
            hasDeterminateProgress = false
            scanItems = sources.map { FeedScanItem(id: $0.id, title: $0.title, state: .scanning) }
            refreshProgress = sources.isEmpty
                ? "Updating feeds…"
                : "Scanning \(sourcesLabel(sources.count))…"

            _ = try await rssService.refreshFeedsViaAPI()   // server-side, come il web
            lastRefreshDate = Date()

            for item in scanItems {
                updateScanItem(item.id, to: .done)
            }
            processedFeedsCount = sources.count
            progressPercentage = 1.0
            refreshProgress = "Finalizing…"

            await loadFeeds()                               // ricarica feed + unread counts

            resetRefreshProgress()
            isRefreshing = false
        } catch {
            // Fallback offline / server non raggiungibile → parser client on-device.
            // Release the guard first so refreshFeeds() can run its own lifecycle.
            print("refreshFeedsViaAPI server failed, falling back to client parser: \(error.localizedDescription)")
            resetRefreshProgress()
            isRefreshing = false

            await refreshFeeds()
            lastRefreshDate = Date()
        }
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

    /// "synced 4 minutes ago" for the Feeds header subtitle
    /// (docs/revamp-ios/README.md · "06 Feeds").
    var lastSyncedDescription: String {
        guard let last = lastRefreshDate else { return "not yet synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "synced \(formatter.localizedString(for: last, relativeTo: Date()))"
    }
}
