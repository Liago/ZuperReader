import SwiftUI
import Supabase


// MARK: - Friends View

struct FriendsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    
    @State private var friends: [Friend] = []
    @State private var pendingRequests: [Friend] = []
    @State private var sentRequests: [Friend] = []
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom segmented picker
                    Picker("Tabs", selection: $selectedTab) {
                        Text("My Friends").tag(0)
                        Text("Requests").tag(1)
                        Text("Search").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if isLoading && friends.isEmpty && pendingRequests.isEmpty {
                        LoadingView("Loading friends...")
                    } else {
                        TabView(selection: $selectedTab) {
                            // My Friends Tab
                            FriendsList(friends: friends)
                                .tag(0)
                            
                            // Requests Tab
                            FriendRequestsList(
                                pendingRequests: pendingRequests,
                                sentRequests: sentRequests,
                                onAccept: acceptRequest,
                                onReject: rejectRequest
                            )
                            .tag(1)
                            
                            // Search Tab
                            UserSearchView()
                                .tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let friendsTask = SupabaseService.shared.getFriends(userId: userId)
            async let pendingTask = SupabaseService.shared.getPendingFriendRequests(userId: userId)
            async let sentTask = SupabaseService.shared.getSentFriendRequests(userId: userId)
            
            let (friendsResult, pendingResult, sentResult) = try await (friendsTask, pendingTask, sentTask)
            
            friends = friendsResult
            pendingRequests = pendingResult
            sentRequests = sentResult
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func acceptRequest(_ request: Friend) async {
        do {
            _ = try await SupabaseService.shared.respondToFriendRequest(friendshipId: request.friendshipId, status: "accepted")
            await loadData()
        } catch {
            print("Failed to accept request: \(error)")
        }
    }
    
    private func rejectRequest(_ request: Friend) async {
        do {
            _ = try await SupabaseService.shared.respondToFriendRequest(friendshipId: request.friendshipId, status: "rejected")
            await loadData()
        } catch {
            print("Failed to reject request: \(error)")
        }
    }
}

// MARK: - Friends List

struct FriendsList: View {
    let friends: [Friend]
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if friends.isEmpty {
            VStack(spacing: Spacing.md) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 50))
                    .foregroundColor(themeManager.colors.textSecondary.opacity(0.5))
                Text("No friends yet")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.textPrimary)
                Text("Search for users to add them as friends")
                    .font(.subheadline)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(friends) { friend in
                    HStack(spacing: Spacing.md) {
                        AvatarView(
                            imageUrl: friend.user.avatarUrl,
                            initials: friend.user.initials,
                            size: 40
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.user.displayName ?? "Unknown User")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(themeManager.colors.textPrimary)
                            
                            if let bio = friend.user.bio {
                                Text(bio)
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Friend Requests List

struct FriendRequestsList: View {
    let pendingRequests: [Friend]
    let sentRequests: [Friend]
    let onAccept: (Friend) async -> Void
    let onReject: (Friend) async -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        List {
            if !pendingRequests.isEmpty {
                Section(header: Text("Received Requests")) {
                    ForEach(pendingRequests) { request in
                        RequestRow(
                            request: request,
                            isSent: false,
                            onAccept: { Task { await onAccept(request) } },
                            onReject: { Task { await onReject(request) } }
                        )
                    }
                }
            }
            
            if !sentRequests.isEmpty {
                Section(header: Text("Sent Requests")) {
                    ForEach(sentRequests) { request in
                        RequestRow(
                            request: request,
                            isSent: true,
                            onAccept: {},
                            onReject: {}
                        )
                    }
                }
            }
            
            if pendingRequests.isEmpty && sentRequests.isEmpty {
                ContentUnavailableView(
                    "No Requests",
                    systemImage: "tray",
                    description: Text("You don't have any pending friend requests")
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Request Row

struct RequestRow: View {
    let request: Friend
    let isSent: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(
                imageUrl: request.user.avatarUrl,
                initials: request.user.initials,
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.user.displayName ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text(isSent ? "Waiting for response..." : "Wants to be friends")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            
            Spacer()
            
            if !isSent {
                HStack(spacing: Spacing.sm) {
                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onReject) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User Search View

struct UserSearchView: View {
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var searchQuery = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Search Bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.colors.textSecondary)
                
                TextField("Search by name or email...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await performSearch() }
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(themeManager.colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal)
            
            // Results
            if isLoading {
                ProgressView()
                    .padding()
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                Text("No users found")
                    .foregroundColor(themeManager.colors.textSecondary)
                    .padding()
            } else {
                List {
                    ForEach(searchResults) { user in
                        UserSearchResultRow(user: user)
                    }
                }
                .listStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.top)
    }
    
    private func performSearch() async {
        guard !searchQuery.isEmpty,
              let currentUserId = authManager.user?.id.uuidString else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            searchResults = try await SupabaseService.shared.searchUsers(query: searchQuery, currentUserId: currentUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - User Search Result Row

struct UserSearchResultRow: View {
    let user: UserProfile
    @State private var isRequestSent = false
    @State private var isLoading = false
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(
                imageUrl: user.avatarUrl,
                initials: user.initials,
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: sendRequest) {
                if isLoading {
                    ProgressView()
                } else if isRequestSent {
                    Text("Sent")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(themeManager.colors.accent)
                }
            }
            .disabled(isRequestSent || isLoading)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func sendRequest() {
        guard let currentUserId = authManager.user?.id.uuidString else { return }
        
        isLoading = true
        
        Task {
            do {
                _ = try await SupabaseService.shared.sendFriendRequest(requesterId: currentUserId, addresseeId: user.id)
                await MainActor.run {
                    isRequestSent = true
                    isLoading = false
                }
            } catch {
                print("Failed to send request: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(ThemeManager.shared)
}
