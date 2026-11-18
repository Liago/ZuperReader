import SwiftUI

// MARK: - Comments View
//
// Editorial Teal (design canvas · "16 · Commenti"): a sheet with a
// "Comments · n" header and a close button, borderless comment rows and a
// pill composer with a round accent send button. Loading, posting, editing
// and deleting work as before.

struct CommentsView: View {
    let articleId: String
    let userId: String

    @EnvironmentObject var themeManager: ThemeManager
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var isPosting = false
    @State private var errorMessage: String?

    // Edit & Delete State
    @State private var editingComment: Comment?
    @FocusState private var isInputFocused: Bool
    @State private var commentToDelete: Comment?
    @State private var showDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss

    private var canSend: Bool {
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading && comments.isEmpty {
                LoadingView("Loading comments...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if comments.isEmpty {
                emptyState
            } else {
                commentsList
            }

            inputArea
        }
        .background(themeManager.colors.page)
        .task {
            await loadComments()
        }
        .alert("Delete Comment", isPresented: $showDeleteConfirmation, presenting: commentToDelete) { comment in
            Button("Delete", role: .destructive) {
                Task { await deleteComment(comment) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("Are you sure you want to delete this comment?")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(themeManager.colors.line)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                Text("Comments")
                    .font(Typography.ui(17, weight: .bold, relativeTo: .headline))
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityAddTraits(.isHeader)

                if !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(Typography.ui(15, relativeTo: .subheadline))
                        .foregroundColor(themeManager.colors.muted)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(Typography.symbol(13, weight: .bold))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(themeManager.colors.surface))
                }
                .buttonStyle(.plain)
                .minimumTapTarget()
                .accessibilityLabel("Close comments")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 6)

            Rectangle()
                .fill(themeManager.colors.line)
                .frame(height: 1)
        }
    }

    // MARK: - Components

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(Typography.symbol(34))
                .foregroundColor(themeManager.colors.muted)
                .accessibilityHidden(true)
            Text("No comments yet")
                .font(Typography.ui(17, weight: .semibold, relativeTo: .headline))
                .foregroundColor(themeManager.colors.text)
            Text("Be the first to share your thoughts!")
                .font(Typography.ui(14, relativeTo: .subheadline))
                .foregroundColor(themeManager.colors.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        currentUserId: userId,
                        onEdit: { startEditing(comment) },
                        onDelete: { confirmDelete(comment) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var inputArea: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(themeManager.colors.line)
                .frame(height: 1)

            if editingComment != nil {
                HStack {
                    Text("Editing comment")
                        .font(Typography.ui(12.5, weight: .medium, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                    Spacer()
                    Button("Cancel", action: cancelEditing)
                        .font(Typography.ui(13, weight: .semibold))
                        .foregroundColor(themeManager.colors.accent)
                        .buttonStyle(.plain)
                        .minimumTapTarget()
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $newComment,
                    prompt: Text(editingComment == nil ? "Add a comment…" : "Update your comment…")
                        .foregroundColor(themeManager.colors.muted),
                    axis: .vertical
                )
                .lineLimit(1...4)
                .font(Typography.ui(15, relativeTo: .subheadline))
                .foregroundColor(themeManager.colors.text)
                .focused($isInputFocused)
                .disabled(isPosting)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isInputFocused ? themeManager.colors.accent : themeManager.colors.line, lineWidth: 1)
                )

                Button(action: {
                    if editingComment != nil {
                        Task { await updateComment() }
                    } else {
                        Task { await postComment() }
                    }
                }) {
                    Group {
                        if isPosting {
                            ProgressView()
                                .tint(themeManager.colors.page)
                        } else {
                            Image(systemName: editingComment != nil ? "checkmark" : "arrow.up")
                                .font(Typography.symbol(16, weight: .bold))
                                .foregroundColor(themeManager.colors.page)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(themeManager.colors.accent))
                    .opacity(canSend || isPosting ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel(editingComment != nil ? "Save comment" : "Post comment")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(themeManager.colors.page)
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
        let content = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isPosting = true
        do {
            _ = try await SupabaseService.shared.addComment(
                articleId: articleId,
                userId: userId,
                content: content
            )

            await loadComments()
            newComment = ""
        } catch {
            print("Failed to post comment: \(error)")
        }
        isPosting = false
    }

    private func startEditing(_ comment: Comment) {
        editingComment = comment
        newComment = comment.content
        isInputFocused = true
    }

    private func cancelEditing() {
        editingComment = nil
        newComment = ""
        isInputFocused = false
    }

    private func updateComment() async {
        let content = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comment = editingComment, !content.isEmpty else { return }

        isPosting = true
        do {
            try await SupabaseService.shared.updateComment(commentId: comment.id, content: content)
            await loadComments()
            cancelEditing()
        } catch {
            print("Failed to update comment: \(error)")
        }
        isPosting = false
    }

    private func confirmDelete(_ comment: Comment) {
        commentToDelete = comment
        showDeleteConfirmation = true
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
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(
                imageUrl: comment.user?.avatarUrl,
                initials: comment.user?.initials ?? "??",
                size: 34
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user?.displayName ?? "Unknown")
                        .font(Typography.ui(13.5, weight: .semibold, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.text)

                    Text("· \(comment.formattedDate)")
                        .font(Typography.ui(13, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.muted)

                    Spacer()

                    if comment.userId == currentUserId {
                        Menu {
                            Button(action: onEdit) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(Typography.symbol(14))
                                .foregroundColor(themeManager.colors.muted)
                                .frame(width: 32, height: 28)
                        }
                        .accessibilityLabel("Comment options")
                    }
                }

                Text(comment.content)
                    .font(Typography.ui(14.5, relativeTo: .subheadline))
                    .lineSpacing(2)
                    .foregroundColor(themeManager.colors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
