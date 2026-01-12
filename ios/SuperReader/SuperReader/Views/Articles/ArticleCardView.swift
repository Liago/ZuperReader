import SwiftUI

// MARK: - Article Card View

struct ArticleCardView: View {
    let article: Article
    let onFavorite: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .topTrailing) {
                AsyncImageView(url: article.imageUrl, cornerRadius: 0)
                    .frame(height: 140)
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Actions
                HStack(spacing: Spacing.xs) {
                    // Favorite button
                    Button(action: onFavorite) {
                        Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(article.isFavorite ? .red : .white)
                            .padding(Spacing.xs + 2)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    
                    // Delete button
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(Spacing.xs + 2)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(Spacing.sm)
            }
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Domain & Reading Status
                HStack {
                    if let domain = article.domain {
                        Text(domain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.colors.accent)
                    }
                    
                    Spacer()
                    
                    ReadingStatusBadge(status: article.readingStatus)
                }
                
                // Title
                Text(article.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(2)
                
                // Excerpt
                if let excerpt = article.excerpt {
                    Text(excerpt)
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .lineLimit(2)
                }
                
                // Meta info
                HStack(spacing: Spacing.sm) {
                    if let readTime = article.formattedReadTime {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(readTime)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(themeManager.colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Tags
                    if !article.tags.isEmpty {
                        TagListView(tags: article.tags, maxVisible: 1)
                    }
                }
            }
            .padding(Spacing.sm)
        }
        .background(themeManager.colors.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .alert("Delete Article", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete \"\(article.title)\"?")
        }
    }
}

#Preview {
    ArticleCardView(
        article: Article(
            id: "1",
            userId: "user1",
            url: "https://example.com",
            title: "Understanding SwiftUI Navigation",
            content: nil,
            excerpt: "A comprehensive guide to navigation in SwiftUI apps",
            imageUrl: "https://picsum.photos/400/200",
            faviconUrl: nil,
            author: "John Doe",
            publishedDate: "2024-01-15",
            domain: "example.com",
            tags: ["SwiftUI", "iOS"],
            isFavorite: true,
            likeCount: 5,
            commentCount: 3,
            readingStatus: .reading,
            estimatedReadTime: 5,
            isPublic: false,
            scrapedAt: "",
            createdAt: "",
            updatedAt: ""
        ),
        onFavorite: {},
        onDelete: {}
    )
    .frame(width: 180)
    .padding()
    .environmentObject(ThemeManager.shared)
}
