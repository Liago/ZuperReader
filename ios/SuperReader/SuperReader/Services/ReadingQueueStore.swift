import Foundation
import Combine
import SwiftUI

// MARK: - Reading Queue Store ("Up next")

/// Single source of truth for the user's "Up next" queue, shared by the Library
/// header badge, the per-article "Add to Up next" actions and the Up next screen —
/// the iOS counterpart of the web sidebar count + `/queue` page state.
@MainActor
final class ReadingQueueStore: ObservableObject {
    static let shared = ReadingQueueStore()

    @Published private(set) var items: [QueueItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Article ids currently being added (spinner state on rows).
    @Published private(set) var pendingArticleIds: Set<String> = []

    private var userId: String?
    private var hasLoaded = false

    private init() {}

    var count: Int { items.count }

    var queuedArticleIds: Set<String> { Set(items.map(\.articleId)) }

    var totalMinutes: Int {
        items.reduce(0) { $0 + ($1.article?.estimatedReadTime ?? 0) }
    }

    func isQueued(_ articleId: String) -> Bool {
        queuedArticleIds.contains(articleId)
    }

    func isPending(_ articleId: String) -> Bool {
        pendingArticleIds.contains(articleId)
    }

    // MARK: Loading

    func load(userId: String) async {
        self.userId = userId
        if items.isEmpty && !hasLoaded { isLoading = true }
        errorMessage = nil

        do {
            items = try await SupabaseService.shared.getReadingQueue(userId: userId)
            hasLoaded = true
        } catch {
            if !(error is CancellationError) {
                print("Failed to load queue: \(error)")
                if items.isEmpty { errorMessage = error.localizedDescription }
            }
        }

        isLoading = false
    }

    func refresh() async {
        guard let userId else { return }
        await load(userId: userId)
    }

    /// Called on sign-out so the next user doesn't see a stale queue.
    func reset() {
        items = []
        pendingArticleIds = []
        userId = nil
        hasLoaded = false
        errorMessage = nil
    }

    // MARK: Mutations

    /// Append an article to the end of the queue. No-op if already queued or saving.
    func add(articleId: String, userId: String) async {
        guard !isQueued(articleId), !isPending(articleId) else { return }
        self.userId = userId
        pendingArticleIds.insert(articleId)
        defer { pendingArticleIds.remove(articleId) }

        do {
            try await SupabaseService.shared.addToQueue(userId: userId, articleId: articleId)
            // Reload to pick up the server-side row id + joined article.
            items = try await SupabaseService.shared.getReadingQueue(userId: userId)
        } catch {
            print("Failed to add to queue: \(error)")
        }
    }

    func remove(_ item: QueueItem) async {
        let previous = items
        items.removeAll { $0.id == item.id }

        do {
            try await SupabaseService.shared.removeFromQueue(queueItemId: item.id)
        } catch {
            print("Failed to remove from queue: \(error)")
            items = previous
        }
    }

    /// Drop an article from the local queue after it was removed server-side
    /// (e.g. the reader advancing the queue on completion).
    func removeLocally(articleId: String) {
        items.removeAll { $0.articleId == articleId }
    }

    /// Reorder using `List.onMove` semantics; persists the new positions.
    func move(from source: IndexSet, to destination: Int) async {
        let previous = items
        var next = items
        next.move(fromOffsets: source, toOffset: destination)
        for index in next.indices { next[index].position = index }
        items = next

        do {
            try await SupabaseService.shared.reorderQueue(orderedIds: next.map(\.id))
        } catch {
            print("Failed to reorder queue: \(error)")
            items = previous
        }
    }
}
