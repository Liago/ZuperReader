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
        guard let url = URL(string: "\(webApiUrl)/api/rss/refresh") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try await attachAuthHeader(to: &request)
        
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
        
        return try JSONDecoder().decode(FeedRefreshResult.self, from: data)
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
       // Re-using performFeedAction logic but simplified for specific return type
       guard let apiUrl = URL(string: "\(webApiUrl)/api/rss/feed") else {
           throw URLError(.badURL)
       }
       
       var request = URLRequest(url: apiUrl)
       request.httpMethod = "POST"
       request.setValue("application/json", forHTTPHeaderField: "Content-Type")
       try await attachAuthHeader(to: &request)
       
       let body: [String: String?] = [
           "action": "refresh",
           "url": url,
           "feedId": feedId.uuidString
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
        
       // We can reuse FeedRefreshResult but we need to fill the struct properly
       // The API returns { success: true, added: X, existing: Y }
       // We need to decode that partial response and map to FeedRefreshResult
       struct PartialRefreshResult: Codable {
           let success: Bool
           let added: Int
           let existing: Int
       }
       
       let partial = try JSONDecoder().decode(PartialRefreshResult.self, from: data)
       
       return FeedRefreshResult(
           success: partial.success,
           totalAdded: partial.added,
           totalExisting: partial.existing,
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
}
