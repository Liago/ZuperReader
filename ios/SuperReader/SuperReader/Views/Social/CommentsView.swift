import SwiftUI

// MARK: - Comments View

struct CommentsView: View {
    let articleId: String
    let userId: String
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && comments.isEmpty {
                    LoadingView("Loading comments...")
                } else if comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }
                
                // Input Area
                inputArea
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadComments()
            }
        }
    }
    
    // MARK: - Components
    
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(themeManager.colors.textSecondary.opacity(0.5))
            Text("No comments yet")
                .font(.headline)
            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(themeManager.colors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(themeManager.colors.bgPrimary)
    }
    
    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, currentUserId: userId) {
                        Task { await deleteComment(comment) }
                    }
                }
            }
            .padding()
        }
        .background(themeManager.colors.bgPrimary)
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: Spacing.md) {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isPosting)
                
                Button(action: { Task { await postComment() } }) {
                    if isPosting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(newComment.isEmpty ? .gray : .blue)
                    }
                }
                .disabled(newComment.isEmpty || isPosting)
            }
            .padding()
            .background(themeManager.colors.bgSecondary)
        }
    }
    
    // MARK: - Actions
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await SupabaseService.shared.getComments(articleId: articleId)
        } catch {
            print("Failed to load comments: \(error)")
        }
        isLoading = false
    }
    
    private func postComment() async {
        guard !newComment.isEmpty else { return }
        
        isPosting = true
        do {
            let comment = try await SupabaseService.shared.addComment(
                articleId: articleId,
                userId: userId,
                content: newComment
            )
            
            // Fetch fresh to get user relation
            await loadComments()
            newComment = ""
        } catch {
            print("Failed to post comment: \(error)")
        }
        isPosting = false
    }
    
    private func deleteComment(_ comment: Comment) async {
        do {
            try await SupabaseService.shared.deleteComment(commentId: comment.id, articleId: articleId)
            comments.removeAll { $0.id == comment.id }
        } catch {
            print("Failed to delete comment: \(error)")
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Comment
    let currentUserId: String
    let onDelete: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            AvatarView(
                imageUrl: comment.user?.avatarUrl,
                initials: comment.user?.initials ?? "??",
                size: 36
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.user?.displayName ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text(comment.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.colors.textSecondary)
                    
                    Spacer()
                    
                    if comment.userId == currentUserId {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.colors.textPrimary)
            }
            .padding(Spacing.sm)
            .background(themeManager.colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        }
    }
}
