import SwiftUI

// MARK: - Article Card View

struct ArticleCardView: View {
    let article: Article
    let onFavorite: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDeleteConfirm = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Image Area
            ZStack(alignment: .topLeading) {
                // Main Image
                if let imageUrl = article.imageUrl {
                    AsyncImageView(url: imageUrl, cornerRadius: 0)
                        .aspectRatio(1.6, contentMode: .fill)
                        .clipped()
                } else {
                    // Fallback Gradient
                    LinearGradient(
                        colors: [
                            themeManager.colors.accent.opacity(0.1),
                            themeManager.colors.bgSecondary.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .aspectRatio(1.6, contentMode: .fill)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 40))
                            .foregroundColor(themeManager.colors.accent.opacity(0.3))
                    )
                }
                
                // Overlay Gradients
                ZStack {
                    // Bottom gradient for text readability (if we had text over image, but kept here for depth)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.2)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                
                // Floating Status Badge
                HStack(spacing: 6) {
                    StatusBadge(status: article.readingStatus)
                    
                    Spacer()
                    
                    // Fav Button (Floating)
                    Button(action: onFavorite) {
                        Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(article.isFavorite ? .red : .primary)
                            .padding(8)
                            .background(Material.ultraThin)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(12)
            }
            .frame(height: 180)
            .clipped()
            
            // MARK: - Content Area
            VStack(alignment: .leading, spacing: 12) {
                // Domain & Date Row
                HStack {
                    if let domain = article.domain {
                        Text(domain.replacingOccurrences(of: "www.", with: "").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(themeManager.colors.accent)
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
                        .foregroundColor(.secondary)
                    }
                }
                
                // Title
                Text(article.title)
                    .font(.system(size: 18, weight: .bold)) // Inter-like system font
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Excerpt (Optional)
                if let excerpt = article.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
                
                Divider()
                    .opacity(0.5)
                
                // Footer: Tags & Actions
                HStack {
                    // Tags
                    if !article.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(article.tags.prefix(2), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("No tags")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Delete Action
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(16)
            .background(themeManager.colors.cardBg)
        }
        .background(themeManager.colors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Material.thick, lineWidth: 1).opacity(0.5)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .alert("Delete Article", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete \"\(article.title)\"?")
        }
    }
}

// Helper Component for Status Badge
struct StatusBadge: View {
    let status: ReadingStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Material.thin)
        .background(statusColor.opacity(0.8))
        .clipShape(Capsule())
        .shadow(color: statusColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    var statusColor: Color {
        switch status {
        case .unread: return .blue
        case .reading: return .orange
        case .completed: return .green
        }
    }
    
    var statusText: String {
        switch status {
        case .unread: return "Unread"
        case .reading: return "Reading"
        case .completed: return "Done"
        }
    }
}

#Preview {
    ArticleCardView(
        article: Article(
            id: "1",
            userId: "user1",
            url: "https://example.com",
            title: "Reimagining the Future of Digital Typography",
            content: nil,
            excerpt: "How variable fonts and fluid type scales are changing the web.",
            imageUrl: "https://picsum.photos/400/300",
            faviconUrl: nil,
            author: "Jane Doe",
            publishedDate: "2024-01-15",
            domain: "typography.com",
            tags: ["Design", "Web"],
            isFavorite: true,
            likeCount: 24,
            commentCount: 8,
            readingStatus: .reading,
            estimatedReadTime: 6,
            isPublic: true,
            scrapedAt: "",
            aiSummary: nil,
            aiSummaryGeneratedAt: nil,
            createdAt: "",
            updatedAt: ""
        ),
        onFavorite: {},
        onDelete: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
    .environmentObject(ThemeManager.shared)
}
