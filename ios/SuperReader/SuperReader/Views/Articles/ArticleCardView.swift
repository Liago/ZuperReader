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
            // Image Area
            ZStack(alignment: .topTrailing) {
                AsyncImageView(url: article.imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                
                // Gradient Overlay for Text Readability (Bottom)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Top Gradient for Buttons
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Action Buttons
                HStack(spacing: 8) {
                    Spacer()
                    
                    Button(action: onFavorite) {
                        Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(article.isFavorite ? .red : .white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(12)
            }
            .frame(height: 180)
            .clipped()
            
            // Content Area
            VStack(alignment: .leading, spacing: 12) {
                // Meta Header
                HStack {
                    if let domain = article.domain {
                        HStack(spacing: 6) {
                            if let faviconUrl = article.faviconUrl {
                                AsyncImageView(url: faviconUrl, cornerRadius: 4)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "globe")
                                    .font(.caption2)
                                    .foregroundColor(themeManager.colors.accent)
                            }
                            
                            Text(domain.replacingOccurrences(of: "www.", with: "").capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(themeManager.colors.accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.colors.accent.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    if let readTime = article.formattedReadTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(readTime)
                                .font(.caption2)
                        }
                        .foregroundColor(themeManager.colors.textSecondary)
                    }
                }
                
                // Title
                Text(article.title)
                    .font(Typography.FontFamily.inter.font(size: 17).weight(.bold))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Footer
                HStack {
                    ReadingStatusBadge(status: article.readingStatus)
                    
                    Spacer()
                    
                    // Engagement
                    if article.likeCount > 0 || article.commentCount > 0 {
                        HStack(spacing: 12) {
                            if article.likeCount > 0 {
                                Label("\(article.likeCount)", systemImage: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(.pink)
                            }
                            if article.commentCount > 0 {
                                Label("\(article.commentCount)", systemImage: "bubble.left.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(themeManager.colors.cardBg)
        }
        .background(themeManager.colors.cardBg)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        )
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
            aiSummary: nil,
            aiSummaryGeneratedAt: nil,
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
