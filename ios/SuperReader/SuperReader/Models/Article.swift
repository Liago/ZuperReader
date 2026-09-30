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
    var readingProgress: Int = 0
    let estimatedReadTime: Int?
    let isPublic: Bool?
    let scrapedAt: String?
    let aiSummary: String?
    let aiSummaryGeneratedAt: String?
    let createdAt: String
    let updatedAt: String
    /// Non-nil = readable by anyone via the public web link (/p/<token>).
    var publicShareToken: String? = nil
    var publicSharedAt: String? = nil
    /// nil = the public link never expires.
    var publicLinkExpiresAt: String? = nil
    
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
        case readingProgress = "reading_progress"
        case estimatedReadTime = "estimated_read_time"
        case isPublic = "is_public"
        case scrapedAt = "scraped_at"
        case aiSummary = "ai_summary"
        case aiSummaryGeneratedAt = "ai_summary_generated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case publicShareToken = "public_share_token"
        case publicSharedAt = "public_shared_at"
        case publicLinkExpiresAt = "public_link_expires_at"
    }
    
    /// True when the article has a public link that has not expired yet.
    var isPublicLinkActive: Bool {
        PublicLinkValidity.isActive(token: publicShareToken, expiresAt: publicLinkExpiresAt)
    }

    /// Public web URL when the article has an active public link.
    var publicURL: URL? {
        guard isPublicLinkActive, let token = publicShareToken else { return nil }
        return SupabaseConfig.publicArticleURL(token: token)
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

// MARK: - Public Link Validity

/// Validity of a public article link: 1 day, 1 week or never.
enum PublicLinkValidity: Int, CaseIterable, Identifiable {
    case oneDay = 1
    case oneWeek = 7
    case never = 0

    var id: Int { rawValue }

    /// Value sent to `enable_article_public_link` (nil = never expires).
    var days: Int? { self == .never ? nil : rawValue }

    var label: String {
        switch self {
        case .oneDay: return "1 day"
        case .oneWeek: return "1 week"
        case .never: return "Never"
        }
    }

    /// Closest option for a saved expiry (used to preselect the picker).
    static func from(expiresAt: String?) -> PublicLinkValidity {
        guard let date = parseDate(expiresAt) else { return .never }
        return date.timeIntervalSinceNow > 24 * 3600 ? .oneWeek : .oneDay
    }

    static func isActive(token: String?, expiresAt: String?) -> Bool {
        guard token != nil else { return false }
        guard let expiresAt else { return true }
        // An unparseable date should not hide an active link
        guard let date = parseDate(expiresAt) else { return true }
        return date > Date()
    }

    /// Parses Postgres timestamptz strings, with or without fractional seconds.
    static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}
