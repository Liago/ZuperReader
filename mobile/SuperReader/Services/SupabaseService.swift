import Foundation
import Supabase

// MARK: - Supabase Configuration

enum SupabaseConfig {
    static let url = URL(string: "https://wjotvfawhnibnjgoaqud.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indqb3R2ZmF3aG5pYm5qZ29hcXVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTA0NDMxMDcsImV4cCI6MjAwNjAxOTEwN30.xtirkUL9f4ciRcJNvwtkGuWGTMcTfRKD3KW9kdZWBpo"
    static let parseFunctionUrl = "https://super-reader-parser.netlify.app/.netlify/functions/parse"
}

// MARK: - Supabase Service

actor SupabaseService {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
    
    // MARK: - Authentication
    
    var currentUser: User? {
        get async {
            try? await client.auth.session.user
        }
    }
    
    var currentSession: Session? {
        get async {
            try? await client.auth.session
        }
    }
    
    func signInWithOtp(email: String) async throws {
        let redirectUrl = "azreader://auth/confirm"
        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: redirectUrl)
        )
    }
    
    func verifyOtp(tokenHash: String, type: String) async throws {
        guard let otpType = EmailOTPType(rawValue: type) else {
            throw SupabaseError.invalidOtpType
        }
        try await client.auth.verifyOTP(tokenHash: tokenHash, type: otpType)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func onAuthStateChange() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            Task {
                for await (event, _) in client.auth.authStateChanges {
                    continuation.yield(event)
                }
            }
        }
    }
    
    // MARK: - Articles
    
    func getArticles(
        userId: String,
        limit: Int = 10,
        offset: Int = 0,
        filters: ArticleFilters? = nil,
        sort: ArticleSortOptions? = nil
    ) async throws -> (articles: [Article], hasMore: Bool) {
        var query = client
            .from("articles")
            .select() // Returns PostgrestTransformBuilder
            .eq("user_id", value: userId) // Returns PostgrestFilterBuilder
        
        // Apply filters
        if let filters = filters {
            if !filters.searchQuery.isEmpty {
                query = query.or("title.ilike.%\(filters.searchQuery)%,excerpt.ilike.%\(filters.searchQuery)%")
            }
            
            if let readingStatus = filters.readingStatus {
                query = query.eq("reading_status", value: readingStatus.rawValue)
            }
            
            if let isFavorite = filters.isFavorite, isFavorite {
                query = query.eq("is_favorite", value: true)
            }
            
            if let domain = filters.domain, !domain.isEmpty {
                query = query.eq("domain", value: domain)
            }
            
            if !filters.tags.isEmpty {
                query = query.contains("tags", value: filters.tags)
            }
        }
        
        // Apply sorting and pagination - We must cast or just chain from here since .order changes type
        let sortField = sort?.field.rawValue ?? "created_at"
        let ascending = sort?.order == .ascending
        
        // Note: query is PostgrestFilterBuilder. .order returns PostgrestTransformBuilder.
        // We create a new variable for the transformed query
        var orderedQuery = query.order(sortField, ascending: ascending)
        
        // Apply pagination
        orderedQuery = orderedQuery.range(from: offset, to: offset + limit - 1)
        
        let articles: [Article] = try await orderedQuery.execute().value
        let hasMore = articles.count == limit
        
        return (articles, hasMore)
    }
    
    func getArticleById(_ id: String) async throws -> Article? {
        let articles: [Article] = try await client
            .from("articles")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        
        return articles.first
    }
    
    func saveArticle(parsedData: ParseResult, userId: String) async throws -> Article {
        let domain = URL(string: parsedData.url)?.host ?? ""
        let estimatedReadTime = parsedData.wordCount.map { Int(ceil(Double($0) / 200.0)) }
        
        let articleData: [String: AnyJSON] = [
            "user_id": .string(userId),
            "url": .string(parsedData.url),
            "title": .string(parsedData.title ?? "Untitled"),
            "content": parsedData.content.map { .string($0) } ?? .null,
            "excerpt": parsedData.excerpt.map { .string($0) } ?? .null,
            "image_url": parsedData.leadImageUrl.map { .string($0) } ?? .null,
            "author": parsedData.author.map { .string($0) } ?? .null,
            "published_date": parsedData.datePublished.map { .string($0) } ?? .null,
            "domain": .string(domain),
            "estimated_read_time": estimatedReadTime.map { .integer($0) } ?? .null
        ]
        
        let articles: [Article] = try await client
            .from("articles")
            .insert(articleData)
            .select()
            .execute()
            .value
        
        guard let article = articles.first else {
            throw SupabaseError.insertFailed
        }
        
        return article
    }
    
    func deleteArticle(articleId: String) async throws {
        try await client
            .from("articles")
            .delete()
            .eq("id", value: articleId)
            .execute()
    }
    
    func toggleFavorite(articleId: String, isFavorite: Bool) async throws {
        try await client
            .from("articles")
            .update(["is_favorite": isFavorite])
            .eq("id", value: articleId)
            .execute()
    }
    
    func updateReadingStatus(articleId: String, status: ReadingStatus) async throws {
        try await client
            .from("articles")
            .update(["reading_status": status.rawValue])
            .eq("id", value: articleId)
            .execute()
    }
    
    func updateArticleTags(articleId: String, tags: [String]) async throws -> Article {
        let articles: [Article] = try await client
            .from("articles")
            .update(["tags": tags])
            .eq("id", value: articleId)
            .select()
            .execute()
            .value
        
        guard let article = articles.first else {
            throw SupabaseError.updateFailed
        }
        
        return article
    }
    
    // MARK: - Likes
    
    func toggleLike(articleId: String, userId: String) async throws -> (liked: Bool, likeCount: Int) {
        // Check if already liked
        let existingLikes: [Like] = try await client
            .from("likes")
            .select()
            .eq("article_id", value: articleId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let existingLike = existingLikes.first {
            // Unlike
            try await client
                .from("likes")
                .delete()
                .eq("id", value: existingLike.id)
                .execute()
            
            // Decrement count
            try await client
                .rpc("decrement_like_count", params: ["article_id_param": articleId])
                .execute()
            
            let count = try await getLikesCount(articleId: articleId)
            return (false, count)
        } else {
            // Like
            try await client
                .from("likes")
                .insert([
                    "article_id": articleId,
                    "user_id": userId
                ])
                .execute()
            
            // Increment count
            try await client
                .rpc("increment_like_count", params: ["article_id_param": articleId])
                .execute()
            
            let count = try await getLikesCount(articleId: articleId)
            return (true, count)
        }
    }
    
    func checkIfUserLiked(articleId: String, userId: String) async throws -> Bool {
        let likes: [Like] = try await client
            .from("likes")
            .select()
            .eq("article_id", value: articleId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return !likes.isEmpty
    }
    
    func getLikesCount(articleId: String) async throws -> Int {
        let result: [Article] = try await client
            .from("articles")
            .select("like_count")
            .eq("id", value: articleId)
            .limit(1)
            .execute()
            .value
        
        return result.first?.likeCount ?? 0
    }
    
    // MARK: - Comments
    
    func addComment(articleId: String, userId: String, content: String) async throws -> Comment {
        let comments: [Comment] = try await client
            .from("comments")
            .insert([
                "article_id": articleId,
                "user_id": userId,
                "content": content
            ])
            .select()
            .execute()
            .value
        
        guard let comment = comments.first else {
            throw SupabaseError.insertFailed
        }
        
        // Increment comment count
        try await client
            .rpc("increment_comment_count", params: ["article_id_param": articleId])
            .execute()
        
        return comment
    }
    
    func getComments(articleId: String) async throws -> [Comment] {
        let comments: [Comment] = try await client
            .from("comments")
            .select("*, user:user_profiles(*)")
            .eq("article_id", value: articleId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return comments
    }
    
    func deleteComment(commentId: String, articleId: String) async throws {
        try await client
            .from("comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
        
        // Decrement comment count
        try await client
            .rpc("decrement_comment_count", params: ["article_id_param": articleId])
            .execute()
    }
    
    // MARK: - User Profile
    
    func getUserProfile(userId: String) async throws -> UserProfile? {
        let profiles: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return profiles.first
    }
    
    func updateUserProfile(userId: String, displayName: String?, bio: String?) async throws -> UserProfile {
        var updates: [String: AnyJSON] = [:]
        if let displayName = displayName {
            updates["display_name"] = .string(displayName)
        }
        if let bio = bio {
            updates["bio"] = .string(bio)
        }
        
        let profiles: [UserProfile] = try await client
            .from("user_profiles")
            .update(updates)
            .eq("id", value: userId)
            .select()
            .execute()
            .value
        
        guard let profile = profiles.first else {
            throw SupabaseError.updateFailed
        }
        
        return profile
    }
    
    func searchUsers(query: String, currentUserId: String) async throws -> [UserProfile] {
        let profiles: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .or("display_name.ilike.%\(query)%,email.ilike.%\(query)%")
            .neq("id", value: currentUserId)
            .limit(20)
            .execute()
            .value
        
        return profiles
    }
    
    // MARK: - Friends
    
    func sendFriendRequest(requesterId: String, addresseeId: String) async throws -> Friendship {
        let friendships: [Friendship] = try await client
            .from("friendships")
            .insert([
                "requester_id": requesterId,
                "addressee_id": addresseeId,
                "status": "pending"
            ])
            .select()
            .execute()
            .value
        
        guard let friendship = friendships.first else {
            throw SupabaseError.insertFailed
        }
        
        return friendship
    }
    
    func respondToFriendRequest(friendshipId: String, status: String) async throws -> Friendship {
        let friendships: [Friendship] = try await client
            .from("friendships")
            .update(["status": status])
            .eq("id", value: friendshipId)
            .select()
            .execute()
            .value
        
        guard let friendship = friendships.first else {
            throw SupabaseError.updateFailed
        }
        
        return friendship
    }
    
    func removeFriend(friendshipId: String) async throws {
        try await client
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId)
            .execute()
    }
    
    func getFriends(userId: String) async throws -> [Friend] {
        // Get accepted friendships where user is requester or addressee
        let friendships: [Friendship] = try await client
            .from("friendships")
            .select("*, requester:user_profiles!requester_id(*), addressee:user_profiles!addressee_id(*)")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userId),addressee_id.eq.\(userId)")
            .execute()
            .value
        
        return friendships.compactMap { friendship in
            let isRequester = friendship.requesterId == userId
            let friendProfile = isRequester ? friendship.addressee : friendship.requester
            guard let profile = friendProfile else { return nil }
            
            return Friend(
                friendshipId: friendship.id,
                user: profile,
                status: friendship.status,
                createdAt: friendship.createdAt,
                isRequester: isRequester
            )
        }
    }
    
    func getPendingFriendRequests(userId: String) async throws -> [Friend] {
        let friendships: [Friendship] = try await client
            .from("friendships")
            .select("*, requester:user_profiles!requester_id(*)")
            .eq("addressee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return friendships.compactMap { friendship in
            guard let profile = friendship.requester else { return nil }
            
            return Friend(
                friendshipId: friendship.id,
                user: profile,
                status: friendship.status,
                createdAt: friendship.createdAt,
                isRequester: false
            )
        }
    }
    
    func getSentFriendRequests(userId: String) async throws -> [Friend] {
        let friendships: [Friendship] = try await client
            .from("friendships")
            .select("*, addressee:user_profiles!addressee_id(*)")
            .eq("requester_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return friendships.compactMap { friendship in
            guard let profile = friendship.addressee else { return nil }
            
            return Friend(
                friendshipId: friendship.id,
                user: profile,
                status: friendship.status,
                createdAt: friendship.createdAt,
                isRequester: true
            )
        }
    }
    
    // MARK: - Article Sharing
    
    func shareArticleWithFriend(
        articleId: String,
        sharedBy: String,
        sharedWith: String,
        message: String?
    ) async throws -> ArticleShare {
        var data: [String: AnyJSON] = [
            "article_id": .string(articleId),
            "shared_by": .string(sharedBy),
            "shared_with": .string(sharedWith)
        ]
        if let message = message {
            data["message"] = .string(message)
        }
        
        let shares: [ArticleShare] = try await client
            .from("article_shares")
            .insert(data)
            .select()
            .execute()
            .value
        
        guard let share = shares.first else {
            throw SupabaseError.insertFailed
        }
        
        return share
    }
    
    func getSharedWithMe(userId: String) async throws -> [ArticleShare] {
        let shares: [ArticleShare] = try await client
            .from("article_shares")
            .select("*, article:articles(*), sharer:user_profiles!shared_by(*)")
            .eq("shared_with", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return shares
    }
    
    func markShareAsRead(shareId: String) async throws {
        try await client
            .from("article_shares")
            .update(["is_read": true])
            .eq("id", value: shareId)
            .execute()
    }
    
    func getUnreadSharesCount(userId: String) async throws -> Int {
        let shares: [ArticleShare] = try await client
            .from("article_shares")
            .select("id")
            .eq("shared_with", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value
        
        return shares.count
    }
    
    func deleteArticleShare(shareId: String) async throws {
        try await client
            .from("article_shares")
            .delete()
            .eq("id", value: shareId)
            .execute()
    }
    
    // MARK: - Statistics
    
    func getUserStatistics(userId: String) async throws -> UserStatistics {
        // Get article counts
        let articles: [Article] = try await client
            .from("articles")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let totalArticles = articles.count
        let readArticles = articles.filter { $0.readingStatus == .completed }.count
        let favoriteArticles = articles.filter { $0.isFavorite }.count
        let totalLikesReceived = articles.reduce(0) { $0 + $1.likeCount }
        let totalCommentsReceived = articles.reduce(0) { $0 + $1.commentCount }
        
        // Get friends count
        let friends = try await getFriends(userId: userId)
        
        // Get shared counts
        let sharedWithMe = try await getSharedWithMe(userId: userId)
        
        let sharedByMe: [ArticleShare] = try await client
            .from("article_shares")
            .select()
            .eq("shared_by", value: userId)
            .execute()
            .value
        
        return UserStatistics(
            totalArticles: totalArticles,
            readArticles: readArticles,
            favoriteArticles: favoriteArticles,
            totalLikesReceived: totalLikesReceived,
            totalCommentsReceived: totalCommentsReceived,
            friendsCount: friends.count,
            sharedArticlesCount: sharedByMe.count,
            receivedArticlesCount: sharedWithMe.count
        )
    }
    
    // MARK: - User Preferences
    
    func getUserPreferences(userId: String) async throws -> UserPreferences? {
        let preferences: [UserPreferences] = try await client
            .from("user_preferences")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return preferences.first
    }
    
    func saveUserPreferences(preferences: UserPreferences) async throws -> UserPreferences {
        let data: [String: AnyJSON] = [
            "id": .string(preferences.id),
            "font_family": .string(preferences.fontFamily.rawValue),
            "font_size": .integer(preferences.fontSize),
            "color_theme": .string(preferences.colorTheme.rawValue),
            "line_height": .string(preferences.lineHeight.rawValue),
            "content_width": .string(preferences.contentWidth.rawValue),
            "view_mode": .string(preferences.viewMode.rawValue)
        ]
        
        let savedPrefs: [UserPreferences] = try await client
            .from("user_preferences")
            .upsert(data)
            .select()
            .execute()
            .value
        
        guard let prefs = savedPrefs.first else {
            throw SupabaseError.insertFailed
        }
        
        return prefs
    }
}

// MARK: - Supabase Errors

enum SupabaseError: LocalizedError {
    case invalidOtpType
    case insertFailed
    case updateFailed
    case deleteFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidOtpType:
            return "Invalid OTP type"
        case .insertFailed:
            return "Failed to insert record"
        case .updateFailed:
            return "Failed to update record"
        case .deleteFailed:
            return "Failed to delete record"
        case .notFound:
            return "Record not found"
        }
    }
}
