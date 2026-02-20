import Foundation
import Supabase

// MARK: - API Response Types

struct APIErrorResponse: Codable {
    let error: String
}

class RSSService {
    static let shared = RSSService()
    
    private let session = URLSession.shared
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys // Web API returns camelCase properties usually, but models match
        return decoder
    }()
    
    private var webApiUrl: String {
        return SupabaseConfig.webApiUrl
    }
    
    // MARK: - API Operations
    
    func discoverFeeds(query: String) async throws -> [DiscoveredFeed] {
        guard var components = URLComponents(string: "\(webApiUrl)/api/rss/discover") else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NSError(domain: "RSSService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])
            }
            throw URLError(.badServerResponse)
        }
        
        struct DiscoveryResponse: Codable {
            let feeds: [DiscoveredFeed]?
            let error: String?
        }
        
        let result = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
        
        if let error = result.error {
             throw NSError(domain: "RSSService", code: 400, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        return result.feeds ?? []
    }
    
    func refreshAllFeeds() async throws -> FeedRefreshResult {
        // 1. Fetch all feeds for the user
        guard let user = await SupabaseService.shared.currentUser else {
             throw NSError(domain: "RSSService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        let feeds = try await getFeeds(userId: user.id.uuidString)
        
        // 2. Refresh concurrently
        return await withTaskGroup(of: (FeedRefreshResult?).self) { group in
            for feed in feeds {
                group.addTask {
                    try? await self.refreshFeed(feedId: feed.id, url: feed.url)
                }
            }
            
            var totalAdded = 0
            var totalExisting = 0
            var totalRefreshed = 0
            var errors: [String] = []
            
            for await result in group {
                if let result = result {
                    if result.success {
                        totalAdded += result.totalAdded
                        totalExisting += result.totalExisting
                        totalRefreshed += 1
                    }
                    if let errs = result.errors {
                        errors.append(contentsOf: errs)
                    }
                }
            }
            
            return FeedRefreshResult(
                success: true,
                totalAdded: totalAdded,
                totalExisting: totalExisting,
                feedsRefreshed: totalRefreshed,
                errors: errors.isEmpty ? nil : errors
            )
        }
    }
    
    func addFeed(url: String) async throws {
        try await performFeedAction(action: "add", url: url)
    }
    
    func deleteFeed(feedId: String) async throws {
        try await performFeedAction(action: "delete", feedId: feedId)
    }
    
    private func performFeedAction(action: String, url: String? = nil, feedId: String? = nil) async throws {
        guard let apiUrl = URL(string: "\(webApiUrl)/api/rss/feed") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await attachAuthHeader(to: &request)
        
        let body: [String: String?] = [
            "action": action,
            "url": url,
            "feedId": feedId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                 throw NSError(domain: "RSSService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])
            }
            throw URLError(.badServerResponse)
        }
    }
    
    private func attachAuthHeader(to request: inout URLRequest) async throws {
        guard let session = await SupabaseService.shared.currentSession else {
            throw NSError(domain: "RSSService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    }
    
    // MARK: - Supabase Data Access
    
    func getFeeds(userId: String) async throws -> [RSSFeed] {
        let feeds: [RSSFeed] = try await SupabaseService.shared.client
            .from("rss_feeds")
            .select()
            .eq("user_id", value: userId)
            .order("title", ascending: true) // Sort by title
            .execute()
            .value
        
        return feeds
    }

    func refreshFeed(feedId: UUID, url: String) async throws -> FeedRefreshResult {
        guard let feedUrl = URL(string: url) else {
             throw URLError(.badURL)
        }
        
        // 1. Fetch Data
        print("RSSService: Refreshing feed \(url)...")
        var request = URLRequest(url: feedUrl)
        request.timeoutInterval = 30
        // Some feeds block default user agents
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        print("RSSService: Received \(data.count) bytes for \(url). Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        
        // 2. Parse XML
        let parsedItems = await RSSParserService.shared.parse(data: data)
        guard !parsedItems.isEmpty else {
             return FeedRefreshResult(success: false, totalAdded: 0, totalExisting: 0, feedsRefreshed: 0, errors: ["No items found or failed to parse"])
        }
        
        // 3. Map to RSSArticle
        guard let user = await SupabaseService.shared.currentUser else {
             throw NSError(domain: "RSSService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        let articles: [RSSArticle] = parsedItems.map { item in
            RSSArticle(
                id: UUID(), // Supabase will generate this usually? No, the struct has let id: UUID. We can generate a temp one, the Upsert logic matching on GUID will ignore ID if it exists, or insert new one.
                feedId: feedId,
                guid: item.guid,
                title: item.title,
                link: item.link,
                author: item.author.isEmpty ? nil : item.author,
                pubDate: item.pubDate,
                content: item.content.isEmpty ? nil : item.content,
                contentSnippet: item.contentSnippet.isEmpty ? nil : item.contentSnippet,
                imageUrl: item.imageUrl,
                isRead: false,
                readAt: nil,
                userId: user.id
            )
        }
        
        // 4. Upsert to Supabase
        let (added, existing) = try await SupabaseService.shared.upsertRSSArticles(articles)
        
        return FeedRefreshResult(
            success: true,
            totalAdded: added,
            totalExisting: existing,
            feedsRefreshed: 1,
            errors: nil
        )
    }
    
    func getUnreadCounts(userId: String) async throws -> [UUID: Int] {
        struct UnreadItem: Decodable {
            let feedId: UUID
            
            enum CodingKeys: String, CodingKey {
                case feedId = "feed_id"
            }
        }
        
        // Correct order: filter then select usually, but select then filter works if builder supports it.
        // here sequence is select -> eq -> eq -> execute. This is Filters.
        let items: [UnreadItem] = try await SupabaseService.shared.client
            .from("rss_articles")
            .select("feed_id")
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value
            
        var counts = [UUID: Int]()
        for item in items {
            counts[item.feedId, default: 0] += 1
        }
        
        return counts
    }
    
    func getArticles(userId: String, feedId: UUID?, limit: Int = 50, includeRead: Bool = false) async throws -> [RSSArticle] {
        // Must apply filters BEFORE transforms (limit, order)
        var query = SupabaseService.shared.client
            .from("rss_articles")
            .select() // PostgrestFilterBuilder
            .eq("user_id", value: userId)
            
        if let feedId = feedId {
            query = query.eq("feed_id", value: feedId)
        }
        
        if !includeRead {
            query = query.eq("is_read", value: false)
        }
        
        // Apply transforms last because they change the builder type
        let articles: [RSSArticle] = try await query
            .order("pub_date", ascending: false) // Sort by date desc
            .limit(limit)
            .execute()
            .value
            
        return articles
    }
    
    func markArticleAsRead(articleId: UUID, userId: String) async throws {
        struct UpdatePayload: Encodable {
            let is_read: Bool
            let read_at: String
        }
        
        let payload = UpdatePayload(
            is_read: true,
            read_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await SupabaseService.shared.client
            .from("rss_articles")
            .update(payload)
            .eq("id", value: articleId)
            .eq("user_id", value: userId) // Security check
            .execute()
    }
    
    func markFeedAsRead(feedId: UUID, userId: String) async throws {
         struct UpdatePayload: Encodable {
             let is_read: Bool
             let read_at: String
         }
         
         let payload = UpdatePayload(
             is_read: true,
             read_at: ISO8601DateFormatter().string(from: Date())
         )
         
         try await SupabaseService.shared.client
             .from("rss_articles")
             .update(payload)
             .eq("feed_id", value: feedId)
             .eq("user_id", value: userId)
             .execute()
    }
}
