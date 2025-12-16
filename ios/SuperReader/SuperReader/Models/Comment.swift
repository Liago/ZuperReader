import Foundation

// MARK: - Comment

struct Comment: Identifiable, Codable, Equatable {
    let id: String
    let articleId: String
    let userId: String
    let content: String
    let createdAt: String
    let updatedAt: String
    var user: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
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
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Like

struct Like: Identifiable, Codable {
    let id: String
    let articleId: String
    let userId: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

// MARK: - Share (external)

struct Share: Identifiable, Codable {
    let id: String
    let articleId: String
    let userId: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
