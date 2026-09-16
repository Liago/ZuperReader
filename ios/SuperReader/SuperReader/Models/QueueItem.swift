import Foundation

// MARK: - Queue Item ("Up next" · public.reading_queue)

/// One row of the per-user ordered reading queue, joined with its article
/// (`select("id, article_id, position, article:articles(*)")`). Mirrors the web
/// `QueueItem` in web/src/lib/api.ts.
struct QueueItem: Identifiable, Codable, Equatable {
    let id: String
    let articleId: String
    var position: Int
    /// Nil when the joined article no longer exists (orphaned row); callers drop those.
    var article: Article?

    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case position
        case article
    }

    static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position
    }
}

// MARK: - Queue Action State

/// Per-article state of the "Add to Up next" action (web `queueState`):
/// `.saving` while the insert is in flight, `.done` once the article is queued.
enum QueueActionState: Equatable {
    case saving
    case done
}
