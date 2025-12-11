import Foundation

// MARK: - Article Share (internal sharing between users)

struct ArticleShare: Identifiable, Codable, Equatable {
    let id: String
    let articleId: String
    let sharedBy: String
    let sharedWith: String
    let message: String?
    var isRead: Bool
    let createdAt: String
    var article: Article?
    var sharer: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case sharedBy = "shared_by"
        case sharedWith = "shared_with"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
        case article
        case sharer
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: createdAt) {
            let now = Date()
            let diff = now.timeIntervalSince(date)
            
            if diff < 60 {
                return "Just now"
            } else if diff < 3600 {
                let minutes = Int(diff / 60)
                return "\(minutes)m ago"
            } else if diff < 86400 {
                let hours = Int(diff / 3600)
                return "\(hours)h ago"
            } else if diff < 604800 {
                let days = Int(diff / 86400)
                return "\(days)d ago"
            } else {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                return displayFormatter.string(from: date)
            }
        }
        return ""
    }
    
    static func == (lhs: ArticleShare, rhs: ArticleShare) -> Bool {
        lhs.id == rhs.id
    }
}
