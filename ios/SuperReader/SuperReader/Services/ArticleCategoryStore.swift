import Foundation
import Combine
import SwiftUI

// MARK: - Article Category Store (smart Library grouping)
//
// Single source of truth for "which shelf does this article go on".
//
// Pipeline, per uncategorized article:
//  1. `HeuristicCategoryClassifier` answers instantly (off the main actor), so
//     the home can group everything on first launch;
//  2. when Apple's on-device model is available, `ModelCategoryClassifier`
//     refines heuristic answers one article at a time, in the background;
//  3. results are saved in `articles.category` / `category_source`, so other
//     devices (and the web app) reuse them instead of classifying again.
//
// A manual "Move to…" is stored with source `user` and never overwritten.
// Local results are also cached on disk, so the grouping survives restarts
// even when the DB migration has not been applied yet.

@MainActor
final class ArticleCategoryStore: ObservableObject {
    static let shared = ArticleCategoryStore()

    /// Results computed or picked on this device, keyed by article id. They
    /// take precedence over the DB value until the DB catches up.
    @Published private(set) var localAssignments: [String: ArticleCategoryAssignment] = [:]
    /// True while the on-device model is refining categories.
    @Published private(set) var isRefining = false

    /// Local results not saved to the DB yet.
    private var unsyncedIds: Set<String> = []
    private var heuristicInFlight: Set<String> = []
    private var modelAttempted: Set<String> = []
    private var modelQueue: [CategoryInput] = []
    private var modelTask: Task<Void, Never>?
    private var remoteQueue: [(articleId: String, assignment: ArticleCategoryAssignment)] = []
    private var remoteTask: Task<Void, Never>?
    private var remoteWritesDisabled = false
    private var saveTask: Task<Void, Never>?

    private init() {
        loadCache()
    }

    // MARK: Query

    func assignment(for article: Article) -> ArticleCategoryAssignment? {
        localAssignments[article.id] ?? article.remoteCategoryAssignment
    }

    /// The shelf the article belongs on; nil only for the instant before the
    /// first heuristic pass lands.
    func category(for article: Article) -> ArticleCategory? {
        assignment(for: article)?.category
    }

    // MARK: Categorization

    /// Categorizes whatever is missing among `articles` (call it after every
    /// fetch). Already-categorized articles cost nothing.
    func categorize(_ articles: [Article]) {
        let modelAvailable = ModelCategoryClassifier.isAvailable
        var heuristicInputs: [CategoryInput] = []

        for article in articles {
            reconcile(article)

            let current = assignment(for: article)
            if current == nil, !heuristicInFlight.contains(article.id) {
                heuristicInFlight.insert(article.id)
                heuristicInputs.append(article.categoryInput)
            }

            // Retry writes that didn't reach the DB in a previous session.
            if unsyncedIds.contains(article.id), let local = localAssignments[article.id],
               !remoteQueue.contains(where: { $0.articleId == article.id }) {
                enqueueRemoteWrite(articleId: article.id, assignment: local)
            }

            let canImprove = current == nil || current?.source == .heuristic
            if modelAvailable, canImprove, !modelAttempted.contains(article.id),
               !modelQueue.contains(where: { $0.id == article.id }) {
                modelQueue.append(article.categoryInput)
            }
        }

        if !heuristicInputs.isEmpty {
            let inputs = heuristicInputs
            Task {
                let results = await HeuristicCategoryClassifier.shared.classify(inputs)
                for (articleId, category) in results {
                    heuristicInFlight.remove(articleId)
                    // With the model coming, only its answer is worth a DB write.
                    record(
                        ArticleCategoryAssignment(category: category, source: .heuristic),
                        for: articleId,
                        syncRemotely: !modelAvailable
                    )
                }
            }
        }

        startModelPassIfNeeded()
    }

    /// Manual "Move to…": wins over every classifier, on every device.
    func setCategory(_ category: ArticleCategory, for article: Article) {
        modelQueue.removeAll { $0.id == article.id }
        modelAttempted.insert(article.id)
        record(ArticleCategoryAssignment(category: category, source: .user), for: article.id, syncRemotely: true, force: true)
    }

    /// Drops cached entries of articles no longer in the Library.
    func prune(keeping articleIds: Set<String>) {
        let stale = localAssignments.keys.filter { !articleIds.contains($0) }
        guard !stale.isEmpty else { return }
        stale.forEach {
            localAssignments.removeValue(forKey: $0)
            unsyncedIds.remove($0)
        }
        scheduleSave()
    }

    // MARK: Private · bookkeeping

    /// Once the DB holds an answer at least as good as the local one, the DB
    /// becomes the truth (it may carry a newer choice made on another device).
    private func reconcile(_ article: Article) {
        guard let local = localAssignments[article.id],
              let remote = article.remoteCategoryAssignment,
              !unsyncedIds.contains(article.id),
              remote.source.rank >= local.source.rank else { return }
        localAssignments.removeValue(forKey: article.id)
        scheduleSave()
    }

    private func record(
        _ assignment: ArticleCategoryAssignment,
        for articleId: String,
        syncRemotely: Bool,
        force: Bool = false
    ) {
        if !force, let current = localAssignments[articleId], current.source.rank > assignment.source.rank {
            return
        }
        localAssignments[articleId] = assignment
        scheduleSave()
        if syncRemotely {
            enqueueRemoteWrite(articleId: articleId, assignment: assignment)
        }
    }

    // MARK: Private · on-device model pass

    private func startModelPassIfNeeded() {
        guard modelTask == nil, !modelQueue.isEmpty else { return }
        isRefining = true

        modelTask = Task { [weak self] in
            while let input = self?.dequeueModelInput() {
                let category = await ModelCategoryClassifier.classify(input)
                guard let self else { return }

                if let category {
                    self.record(ArticleCategoryAssignment(category: category, source: .model), for: input.id, syncRemotely: true)
                } else if let fallback = self.localAssignments[input.id], fallback.source == .heuristic {
                    // Model failed for this one: the heuristic answer is final.
                    self.enqueueRemoteWrite(articleId: input.id, assignment: fallback)
                }
            }
            self?.modelTask = nil
            self?.isRefining = false
        }
    }

    private func dequeueModelInput() -> CategoryInput? {
        guard !modelQueue.isEmpty else { return nil }
        let input = modelQueue.removeFirst()
        modelAttempted.insert(input.id)
        return input
    }

    // MARK: Private · DB sync

    private func enqueueRemoteWrite(articleId: String, assignment: ArticleCategoryAssignment) {
        unsyncedIds.insert(articleId)
        guard !remoteWritesDisabled else { return }

        remoteQueue.removeAll { $0.articleId == articleId }
        remoteQueue.append((articleId, assignment))
        guard remoteTask == nil else { return }

        remoteTask = Task { [weak self] in
            while let next = self?.dequeueRemoteWrite() {
                do {
                    try await SupabaseService.shared.updateArticleCategory(
                        articleId: next.articleId,
                        category: next.assignment.category,
                        source: next.assignment.source
                    )
                    if self?.localAssignments[next.articleId] == next.assignment {
                        self?.unsyncedIds.remove(next.articleId)
                        self?.scheduleSave()
                    }
                } catch {
                    if SupabaseService.isMissingColumnError(error) || (error as? SupabaseError) != nil {
                        // Migration not applied: keep categories on-device only.
                        print("⚠️ Article categories stay local: \(error)")
                        self?.remoteWritesDisabled = true
                        self?.remoteQueue.removeAll()
                    } else {
                        print("Failed to save category for \(next.articleId): \(error)")
                    }
                }
            }
            self?.remoteTask = nil
        }
    }

    private func dequeueRemoteWrite() -> (articleId: String, assignment: ArticleCategoryAssignment)? {
        guard !remoteQueue.isEmpty else { return nil }
        return remoteQueue.removeFirst()
    }

    // MARK: Private · disk cache

    private struct Cache: Codable {
        var assignments: [String: ArticleCategoryAssignment]
        var unsyncedIds: [String]
    }

    private static var cacheURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("article-categories.json")
    }

    private func loadCache() {
        guard let url = Self.cacheURL,
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return }
        localAssignments = cache.assignments
        unsyncedIds = Set(cache.unsyncedIds)
    }

    /// Coalesces bursts of updates (a whole Library pass) into one write.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self else { return }
            self.writeCache()
        }
    }

    private func writeCache() {
        guard let url = Self.cacheURL else { return }
        let cache = Cache(assignments: localAssignments, unsyncedIds: Array(unsyncedIds))
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to write category cache: \(error)")
        }
    }
}
