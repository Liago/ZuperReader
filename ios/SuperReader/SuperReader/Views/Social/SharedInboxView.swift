import SwiftUI
import Supabase


// MARK: - Shared Inbox View

struct SharedInboxView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    
    @State private var sharedArticles: [ArticleShare] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                Group {
                    if isLoading && sharedArticles.isEmpty {
                        LoadingView("Loading inbox...")
                    } else if sharedArticles.isEmpty {
                        emptyState
                    } else {
                        sharedList
                    }
                }
            }
            .navigationTitle("Shared Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(themeManager.colors.textSecondary.opacity(0.5))
            
            Text("No shared articles")
                .font(.headline)
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text("Articles shared by your friends will appear here")
                .font(.subheadline)
                .foregroundColor(themeManager.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - List
    
    private var sharedList: some View {
        List {
            ForEach(sharedArticles) { share in
                if let article = share.article {
                    SharedArticleRow(share: share, article: article)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deleteShare(share) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onAppear {
                            if !share.isRead {
                                Task { await markAsRead(share) }
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            sharedArticles = try await SupabaseService.shared.getSharedWithMe(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func markAsRead(_ share: ArticleShare) async {
        do {
            try await SupabaseService.shared.markShareAsRead(shareId: share.id)
            // Update local state
            if let index = sharedArticles.firstIndex(where: { $0.id == share.id }) {
                sharedArticles[index].isRead = true
            }
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }
    
    private func deleteShare(_ share: ArticleShare) async {
        do {
            try await SupabaseService.shared.deleteArticleShare(shareId: share.id)
            withAnimation {
                sharedArticles.removeAll { $0.id == share.id }
            }
        } catch {
            print("Failed to delete share: \(error)")
        }
    }
}

// MARK: - Shared Article Row

struct SharedArticleRow: View {
    let share: ArticleShare
    let article: Article
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationLink(destination: ArticleReaderView(articleId: article.id)) {
            HStack(alignment: .top, spacing: Spacing.md) {
                // Sharer Avatar
                AvatarView(
                    imageUrl: share.sharer?.avatarUrl,
                    initials: share.sharer?.initials ?? "??",
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Header
                    HStack {
                        Text(share.sharer?.displayName ?? "Unknown User")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("shared an article")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.colors.textSecondary)
                        
                        Spacer()
                        
                        Text(share.formattedDate)
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.colors.textSecondary)
                        
                        if !share.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Message bubble
                    if let message = share.message, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 13, weight: .regular))
                            .padding(Spacing.sm)
                            .background(themeManager.colors.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(themeManager.colors.border, lineWidth: 0.5)
                            )
                            .padding(.bottom, 2)
                    }
                    
                    // Article Content
                    HStack(spacing: Spacing.sm) {
                        AsyncImageView(url: article.imageUrl, cornerRadius: CornerRadius.sm)
                            .frame(width: 60, height: 60)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeManager.colors.textPrimary)
                                .lineLimit(2)
                            
                            if let domain = article.domain {
                                Text(domain)
                                    .font(.system(size: 11))
                                    .foregroundColor(themeManager.colors.textSecondary)
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .background(Color.white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(themeManager.colors.border, lineWidth: 0.5)
                    )
                }
            }
            .padding(Spacing.md)
            .background(themeManager.colors.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SharedInboxView()
        .environmentObject(ThemeManager.shared)
}
