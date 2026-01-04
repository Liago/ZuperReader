import Foundation

struct RSSFeed: Codable, Identifiable, Hashable {
    let id: UUID
    let url: String
    let title: String
    let siteUrl: String?
    let folderId: UUID?
    let userId: UUID
    let createdAt: Date? // Make optional to be safe
    let updatedAt: Date?
    
    // Optional unread count from join or computation
    var unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, url, title
        case siteUrl = "site_url"
        case folderId = "folder_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
    }
}

struct RSSArticle: Codable, Identifiable, Hashable {
    let id: UUID
    let feedId: UUID
    let guid: String
    let title: String
    let link: String
    let author: String?
    let pubDate: Date?
    let content: String?
    let contentSnippet: String?
    let imageUrl: String?
    let isRead: Bool
    let readAt: Date?
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case id, guid, title, link, author, content
        case feedId = "feed_id"
        case pubDate = "pub_date"
        case contentSnippet = "content_snippet"
        case imageUrl = "image_url"
        case isRead = "is_read"
        case readAt = "read_at"
        case userId = "user_id"
    }
}

struct DiscoveredFeed: Codable, Identifiable, Hashable {
    var id: String { url }
    let url: String
    let title: String
    let type: String
    let siteUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case url, title, type, siteUrl
    }
}

struct FeedRefreshResult: Codable {
    let success: Bool
    let totalAdded: Int
    let totalExisting: Int
    let feedsRefreshed: Int
    let errors: [String]?
}
