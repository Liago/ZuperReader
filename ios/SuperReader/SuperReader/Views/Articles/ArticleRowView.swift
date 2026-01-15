import SwiftUI

// MARK: - Article Row View (List Mode)

struct ArticleRowView: View {
    let article: Article
    let onFavorite: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: - Thumbnail
            ZStack(alignment: .topTrailing) { // Request 3: Spostato a in alto a destra
                if let imageUrl = article.imageUrl {
                    AsyncImageView(url: imageUrl, cornerRadius: 16)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(16)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.colors.bgSecondary)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "doc.text")
                                .foregroundColor(themeManager.colors.accent.opacity(0.4))
                        )
                }
                
                // Mini Status Dot
                StatusDot(status: article.readingStatus)
                    .padding(8)
            }
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // MARK: - Content
            VStack(alignment: .leading, spacing: 6) {
                // Top Meta: Domain & Date
                HStack {
                    if let domain = article.domain {
                        Text(domain.replacingOccurrences(of: "www.", with: "").capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeManager.colors.accent)
                    }
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let date = article.createdAtDate {
                        Text(date.formatted(.dateTime.day().month()))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Title
                Text(article.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(2)
                    .lineSpacing(2)
                
                Spacer()
                
                // Bottom Actions & Info
                HStack {
                    // Read Time
                    if let readTime = article.estimatedReadTime {
                        HStack(spacing: 2) {
                            Image(systemName: "book")
                                .font(.system(size: 10))
                            Text("\(readTime) min")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    // Request 4: Icona commenti a sinistra del cuore
                    if article.commentCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 14))
                            Text("\(article.commentCount)")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                    }
                    
                    // Favorite Button
                    Button(action: onFavorite) {
                        Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(article.isFavorite ? .red : .gray.opacity(0.5))
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.colors.cardBg)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.03), lineWidth: 1)
        )
    }
}

// Minimal Status Dot for List View
struct StatusDot: View {
    let status: ReadingStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .shadow(color: statusColor.opacity(0.5), radius: 2, x: 0, y: 1)
    }
    
    var statusColor: Color {
        switch status {
        case .unread: return .blue
        case .reading: return .orange
        case .completed: return .green
        }
    }
}

// Extension to get Date from string safely (mocking what might be in model)
extension Article {
    var createdAtDate: Date? {
        guard !createdAt.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt)
    }
}

#Preview {
    ArticleRowView(
        article: Article(
            id: "1",
            userId: "u1",
            url: "http://test.com",
            title: "SwiftUI Layout System",
            content: nil,
            excerpt: "Deep dive into layout",
            imageUrl: "https://picsum.photos/100",
            faviconUrl: nil,
            author: nil,
            publishedDate: nil,
            domain: "apple.com",
            tags: ["iOS"],
            isFavorite: true,
            likeCount: 0,
            commentCount: 5,
            readingStatus: .unread,
            estimatedReadTime: 4,
            isPublic: false,
            scrapedAt: "",
            aiSummary: nil,
            aiSummaryGeneratedAt: nil,
            createdAt: "2023-11-20T10:00:00.000Z",
            updatedAt: ""
        ),
        onFavorite: {}
    )
    .padding()
    .environmentObject(ThemeManager.shared)
}
