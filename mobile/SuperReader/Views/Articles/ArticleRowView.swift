import SwiftUI

// MARK: - Article Row View (List Mode)

struct ArticleRowView: View {
    let article: Article
    let onFavorite: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            AsyncImageView(url: article.imageUrl, cornerRadius: CornerRadius.md)
                .frame(width: 80, height: 80)
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Domain
                HStack {
                    if let domain = article.domain {
                        Text(domain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.colors.accent)
                    }
                    
                    Spacer()
                    
                    // Favorite
                    Button(action: onFavorite) {
                        Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(article.isFavorite ? .red : themeManager.colors.textSecondary)
                    }
                }
                
                // Title
                Text(article.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(2)
                
                Spacer()
                
                // Meta row
                HStack(spacing: Spacing.md) {
                    ReadingStatusBadge(status: article.readingStatus)
                    
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
                    
                    // Engagement
                    HStack(spacing: Spacing.sm) {
                        if article.likeCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                Text("\(article.likeCount)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.pink)
                        }
                        
                        if article.commentCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 10))
                                Text("\(article.commentCount)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background(themeManager.colors.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 12) {
        ArticleRowView(
            article: Article(
                id: "1",
                userId: "user1",
                url: "https://example.com",
                title: "Understanding SwiftUI Navigation in iOS 17",
                content: nil,
                excerpt: "A comprehensive guide",
                imageUrl: "https://picsum.photos/200",
                faviconUrl: nil,
                author: "John Doe",
                publishedDate: nil,
                domain: "example.com",
                tags: ["Swift"],
                isFavorite: true,
                likeCount: 12,
                commentCount: 5,
                readingStatus: .reading,
                estimatedReadTime: 8,
                isPublic: false,
                scrapedAt: "",
                createdAt: "",
                updatedAt: ""
            ),
            onFavorite: {}
        )
        
        ArticleRowView(
            article: Article(
                id: "2",
                userId: "user1",
                url: "https://example.com",
                title: "Getting Started with Combine",
                content: nil,
                excerpt: nil,
                imageUrl: nil,
                faviconUrl: nil,
                author: nil,
                publishedDate: nil,
                domain: "apple.com",
                tags: [],
                isFavorite: false,
                likeCount: 0,
                commentCount: 0,
                readingStatus: .unread,
                estimatedReadTime: 5,
                isPublic: false,
                scrapedAt: "",
                createdAt: "",
                updatedAt: ""
            ),
            onFavorite: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .environmentObject(ThemeManager.shared)
}
