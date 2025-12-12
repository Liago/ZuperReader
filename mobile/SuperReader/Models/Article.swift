import Foundation

// MARK: - Reading Status

enum ReadingStatus: String, CaseIterable, Codable {
    case unread
    case reading
    case completed
    
    var displayName: String {
        switch self {
        case .unread: return "Unread"
        case .reading: return "Reading"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .unread: return "book.closed"
        case .reading: return "eye"
        case .completed: return "checkmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .unread: return "#3B82F6" // blue
        case .reading: return "#F59E0B" // amber
        case .completed: return "#10B981" // green
        }
    }
}

// MARK: - Article

struct Article: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let url: String
    let title: String
    let content: String?
    let excerpt: String?
    let imageUrl: String?
    let faviconUrl: String?
    let author: String?
    let publishedDate: String?
    let domain: String?
    let tags: [String]
    let isFavorite: Bool
    let likeCount: Int
    let commentCount: Int
    let readingStatus: ReadingStatus
    let estimatedReadTime: Int?
    let isPublic: Bool?
    let scrapedAt: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case url
        case title
        case content
        case excerpt
        case imageUrl = "image_url"
        case faviconUrl = "favicon_url"
        case author
        case publishedDate = "published_date"
        case domain
        case tags
        case isFavorite = "is_favorite"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case readingStatus = "reading_status"
        case estimatedReadTime = "estimated_read_time"
        case isPublic = "is_public"
        case scrapedAt = "scraped_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Formatted read time
    var formattedReadTime: String? {
        guard let time = estimatedReadTime else { return nil }
        return "\(time) min read"
    }
    
    // Formatted date
    var formattedDate: String? {
        guard let dateString = publishedDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return nil
    }
    
    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Parse Result (from API)

struct ParseResult: Codable {
    let url: String
    let title: String?
    let content: String?
    let excerpt: String?
    let leadImageUrl: String?
    let author: String?
    let datePublished: String?
    let domain: String?
    let wordCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case url
        case title
        case content
        case excerpt
        case leadImageUrl = "lead_image_url"
        case author
        case datePublished = "date_published"
        case domain
        case wordCount = "word_count"
    }
}

// MARK: - Article Filters

struct ArticleFilters {
    var searchQuery: String = ""
    var tags: [String] = []
    var readingStatus: ReadingStatus? = nil
    var isFavorite: Bool? = nil
    var domain: String? = nil
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    
    var isEmpty: Bool {
        searchQuery.isEmpty &&
        tags.isEmpty &&
        readingStatus == nil &&
        isFavorite == nil &&
        domain == nil &&
        dateFrom == nil &&
        dateTo == nil
    }
    
    mutating func clear() {
        searchQuery = ""
        tags = []
        readingStatus = nil
        isFavorite = nil
        domain = nil
        dateFrom = nil
        dateTo = nil
    }
}

// MARK: - Sort Options

enum ArticleSortField: String, CaseIterable {
    case createdAt = "created_at"
    case publishedDate = "published_date"
    case title = "title"
    case readingStatus = "reading_status"
    
    var displayName: String {
        switch self {
        case .createdAt: return "Date Added"
        case .publishedDate: return "Published Date"
        case .title: return "Title"
        case .readingStatus: return "Status"
        }
    }
}

enum SortOrder: String, CaseIterable {
    case ascending = "asc"
    case descending = "desc"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
}

struct ArticleSortOptions {
    var field: ArticleSortField = .createdAt
    var order: SortOrder = .descending
}
