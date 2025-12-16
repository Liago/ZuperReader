import Foundation

// MARK: - User Profile

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var email: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var initials: String {
        if let name = displayName, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            if components.count > 1 {
                return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        if let email = email, !email.isEmpty {
            return String(email.prefix(2)).uppercased()
        }
        return "??"
    }
    
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Friendship Status

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case blocked
}

// MARK: - Friendship

struct Friendship: Identifiable, Codable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let status: FriendshipStatus
    let createdAt: String
    let updatedAt: String
    var requester: UserProfile?
    var addressee: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case requester
        case addressee
    }
}

// MARK: - Friend (with profile info)

struct Friend: Identifiable, Equatable {
    var id: String { friendshipId }
    let friendshipId: String
    let user: UserProfile
    let status: FriendshipStatus
    let createdAt: String
    let isRequester: Bool // true if current user sent the request
    
    static func == (lhs: Friend, rhs: Friend) -> Bool {
        lhs.friendshipId == rhs.friendshipId
    }
}

// MARK: - User Statistics

struct UserStatistics: Codable {
    let totalArticles: Int
    let readArticles: Int
    let favoriteArticles: Int
    let totalLikesReceived: Int
    let totalCommentsReceived: Int
    let friendsCount: Int
    let sharedArticlesCount: Int
    let receivedArticlesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case totalArticles = "total_articles"
        case readArticles = "read_articles"
        case favoriteArticles = "favorite_articles"
        case totalLikesReceived = "total_likes_received"
        case totalCommentsReceived = "total_comments_received"
        case friendsCount = "friends_count"
        case sharedArticlesCount = "shared_articles_count"
        case receivedArticlesCount = "received_articles_count"
    }
    
    static var empty: UserStatistics {
        UserStatistics(
            totalArticles: 0,
            readArticles: 0,
            favoriteArticles: 0,
            totalLikesReceived: 0,
            totalCommentsReceived: 0,
            friendsCount: 0,
            sharedArticlesCount: 0,
            receivedArticlesCount: 0
        )
    }
}
