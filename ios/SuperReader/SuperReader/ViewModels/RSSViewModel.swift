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

    /// Refresh all feeds with the on-device parser (offline fallback).
    func refreshFeeds() async {
        guard !isRefreshing else { return }
        guard authManager.isAuthenticated else { return }

        let feedsToRefresh = self.feeds
        guard !feedsToRefresh.isEmpty else { return }

        let service = rssService
        _ = await runBatchedRefresh(of: feedsToRefresh) { feed in
            _ = try await service.refreshFeed(feedId: feed.id, url: feed.url)
        }

        await finishRefresh()
    }

    /// Refresh all feeds through the web API (server-side, same path as the web app,
    /// which parses feeds with the robust `rss-parser` library). Falls back to the
    /// on-device client parser if the server is unreachable (offline resilience).
    ///
    /// Each source is refreshed with its own request (`/api/rss/feed`, action
    /// `refresh`) so the loader shows real per-source progress instead of a
    /// single opaque call with every row stuck on a spinner.
    func refreshFeedsViaAPI() async {
        guard !isRefreshing else { return }
        guard authManager.isAuthenticated else { return }

        let sources = self.feeds
        guard !sources.isEmpty else {
            lastRefreshDate = Date()
            return
        }

        let service = rssService
        let succeeded = await runBatchedRefresh(of: sources) { feed in
            try await service.refreshFeedViaAPI(feedId: feed.id, url: feed.url)
        }

        // Nessuna fonte aggiornata dal server → probabilmente offline o server
        // non raggiungibile: rilascia il guard e riprova con il parser on-device.
        if succeeded == 0 {
            print("refreshFeedsViaAPI: no source refreshed server-side, falling back to client parser")
            resetRefreshProgress()
            isRefreshing = false

            await refreshFeeds()
            lastRefreshDate = Date()
            return
        }

        lastRefreshDate = Date()
        await finishRefresh()
    }

    /// Scansiona le fonti a batch di 5 aggiornando la modale fonte per fonte.
    /// `refresh` esegue l'aggiornamento di una singola fonte (server o on-device);
    /// un `throw` marca la riga come fallita. Ritorna il numero di fonti riuscite.
    private func runBatchedRefresh(
        of feedsToRefresh: [RSSFeed],
        refresh: @escaping @Sendable (RSSFeed) async throws -> Void
    ) async -> Int {
        isRefreshing = true
        errorMessage = nil
        refreshProgress = "Starting update..."
        progressPercentage = 0.0
        processedFeedsCount = 0
        totalFeedsCount = feedsToRefresh.count
        hasDeterminateProgress = true
        scanItems = feedsToRefresh.map { FeedScanItem(id: $0.id, title: $0.title, state: .pending) }

        var completed = 0
        var succeeded = 0
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
                    group.addTask {
                        do {
                            try await refresh(feed)
                            return (feed.id, true)
                        } catch {
                            print("Error refreshing feed \(feed.title) (\(feed.url)): \(error.localizedDescription)")
                            return (feed.id, false)
                        }
                    }
                }

                // Ogni fonte aggiorna la modale appena finisce, non a fine batch.
                for await (feedId, success) in group {
                    completed += 1
                    if success { succeeded += 1 }
                    updateScanItem(feedId, to: success ? .done : .failed)
                    processedFeedsCount = completed
                    progressPercentage = Double(completed) / Double(totalFeedsCount)
                }
            }
        }

        return succeeded
    }

    /// Chiude il refresh: barra al 100%, ricarica feed + unread counts e lascia
    /// il tempo di vedere tutte le fonti completate prima di nascondere la modale.
    private func finishRefresh() async {
        refreshProgress = "Finalizing..."
        progressPercentage = 1.0

        await loadFeeds()

        try? await Task.sleep(nanoseconds: 800_000_000)

        resetRefreshProgress()
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
