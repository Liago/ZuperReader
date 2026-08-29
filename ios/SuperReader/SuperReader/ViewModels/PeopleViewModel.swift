import Foundation
import SwiftUI

// MARK: - People View Model
//
// Wraps the existing getSharedWithMe / getPendingFriendRequests / getFriends /
// getSentFriendRequests calls behind one `segment` enum, backing the merged
// People screen (docs/revamp-ios/README.md · "07 People").

@MainActor
final class PeopleViewModel: ObservableObject {
    enum Segment {
        case shared
        case friends
    }

    @Published var segment: Segment = .shared

    @Published var sharedArticles: [ArticleShare] = []
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [Friend] = []
    @Published var sentRequests: [Friend] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authManager = AuthManager.shared

    func loadAll() async {
        guard let userId = authManager.user?.id.uuidString else { return }

        isLoading = true
        errorMessage = nil

        do {
            async let sharedTask = SupabaseService.shared.getSharedWithMe(userId: userId)
            async let friendsTask = SupabaseService.shared.getFriends(userId: userId)
            async let pendingTask = SupabaseService.shared.getPendingFriendRequests(userId: userId)
            async let sentTask = SupabaseService.shared.getSentFriendRequests(userId: userId)

            let (shared, friendsResult, pending, sent) = try await (sharedTask, friendsTask, pendingTask, sentTask)

            sharedArticles = shared
            friends = friendsResult
            pendingRequests = pending
            sentRequests = sent
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markAsRead(_ share: ArticleShare) async {
        do {
            try await SupabaseService.shared.markShareAsRead(shareId: share.id)
            if let index = sharedArticles.firstIndex(where: { $0.id == share.id }) {
                sharedArticles[index].isRead = true
            }
        } catch {
            print("Failed to mark share as read: \(error)")
        }
    }

    func deleteShare(_ share: ArticleShare) async {
        do {
            try await SupabaseService.shared.deleteArticleShare(shareId: share.id)
            withAnimation {
                sharedArticles.removeAll { $0.id == share.id }
            }
        } catch {
            print("Failed to delete share: \(error)")
        }
    }

    func acceptRequest(_ request: Friend) async {
        do {
            _ = try await SupabaseService.shared.respondToFriendRequest(friendshipId: request.friendshipId, status: "accepted")
            await loadAll()
        } catch {
            print("Failed to accept request: \(error)")
        }
    }

    func rejectRequest(_ request: Friend) async {
        do {
            _ = try await SupabaseService.shared.respondToFriendRequest(friendshipId: request.friendshipId, status: "rejected")
            await loadAll()
        } catch {
            print("Failed to reject request: \(error)")
        }
    }
}
