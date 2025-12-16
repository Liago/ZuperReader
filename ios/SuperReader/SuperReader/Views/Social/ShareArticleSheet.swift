import SwiftUI
import Supabase


// MARK: - Share Article Sheet

struct ShareArticleSheet: View {
    let articleId: String
    let articleTitle: String
    let userId: String
    
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var friends: [Friend] = []
    @State private var selectedFriends: Set<String> = []
    @State private var message = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        LoadingView("Loading friends...")
                    } else if friends.isEmpty {
                        noFriendsView
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            // Message Input
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Add a message (optional)")
                                    .font(.caption)
                                    .foregroundColor(themeManager.colors.textSecondary)
                                
                                TextField("Check this out...", text: $message)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            Text("Select Friends")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.textPrimary)
                                .padding(.horizontal)
                            
                            // Friend List
                            List {
                                ForEach(friends) { friend in
                                    ShareFriendRow(
                                        friend: friend,
                                        isSelected: selectedFriends.contains(friend.user.id)
                                    ) {
                                        toggleSelection(for: friend.user.id)
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                    
                    // Share Button
                    if !friends.isEmpty {
                        VStack {
                            Divider()
                            GradientButton(
                                title: "Share with \(selectedFriends.count) Friend\(selectedFriends.count == 1 ? "" : "s")",
                                icon: "paperplane.fill",
                                gradient: PremiumGradients.purple,
                                isLoading: isSending
                            ) {
                                Task { await shareArticle() }
                            }
                            .disabled(selectedFriends.isEmpty || isSending)
                            .padding()
                        }
                        .background(themeManager.colors.bgPrimary)
                    }
                }
            }
            .navigationTitle("Share Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadFriends()
            }
            .alert("Shared Successfully!", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private var noFriendsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No friends found")
                .font(.headline)
            Text("Add friends to share articles with them")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadFriends() async {
        isLoading = true
        do {
            friends = try await SupabaseService.shared.getFriends(userId: userId)
        } catch {
            print("Failed to load friends: \(error)")
        }
        isLoading = false
    }
    
    private func toggleSelection(for friendId: String) {
        if selectedFriends.contains(friendId) {
            selectedFriends.remove(friendId)
        } else {
            selectedFriends.insert(friendId)
        }
    }
    
    private func shareArticle() async {
        guard !selectedFriends.isEmpty else { return }
        isSending = true
        
        // Share with each selected friend
        // Note: In a real app, you might want a batch insert or parallel requests
        for friendId in selectedFriends {
            do {
                _ = try await SupabaseService.shared.shareArticleWithFriend(
                    articleId: articleId,
                    sharedBy: userId,
                    sharedWith: friendId,
                    message: message.isEmpty ? nil : message
                )
            } catch {
                print("Failed to share with \(friendId): \(error)")
            }
        }
        
        isSending = false
        showSuccess = true
    }
}

// MARK: - Share Friend Row

struct ShareFriendRow: View {
    let friend: Friend
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                AvatarView(
                    imageUrl: friend.user.avatarUrl,
                    initials: friend.user.initials,
                    size: 40
                )
                
                Text(friend.user.displayName ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .purple : .gray.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }
}
