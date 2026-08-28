import SwiftUI

// MARK: - Article Card View (Library · grid)

struct ArticleCardView: View {
    let article: Article
    let onFavorite: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            if article.imageUrl != nil {
                fullCard
            } else {
                compactCard
            }
        }
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
        .contextMenu {
            Button(action: onFavorite) {
                Label(
                    article.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: article.isFavorite ? "heart.slash" : "heart"
                )
            }
            if let url = URL(string: article.url) {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Full card (hero image)

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                themeManager.colors.accent200
                AsyncImageView(url: article.imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
                if let domain = article.domain {
                    sourcePill(domain)
                }
            }
            .frame(height: 150)
            .clipped()

            progressTrack

            VStack(alignment: .leading, spacing: 10) {
                stateRow

                Text(article.title)
                    .font(Typography.cardTitle)
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let excerpt = article.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(Typography.bodyExcerpt)
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(2)
                }

                footer
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private func sourcePill(_ domain: String) -> some View {
        Text(domain.replacingOccurrences(of: "www.", with: "").uppercased())
            .font(Typography.figtree(11, weight: .heavy))
            .tracking(1.1)
            .foregroundColor(themeManager.colors.accent800)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(themeManager.colors.card)
            .clipShape(Capsule())
            .padding(12)
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(themeManager.colors.line)
                Rectangle()
                    .fill(themeManager.colors.accent)
                    .frame(width: geometry.size.width * progressFraction)
            }
        }
        .frame(height: 3)
    }

    private var progressFraction: CGFloat {
        min(max(CGFloat(article.readingProgress) / 100, 0), 1)
    }

    private var stateRow: some View {
        HStack {
            HStack(spacing: 6) {
                ReadingStateDot(
                    status: article.readingStatus,
                    accentColor: themeManager.colors.accent,
                    accent2Color: themeManager.colors.accent2,
                    mutedColor: themeManager.colors.muted
                )
                Text(stateLabel)
                    .font(Typography.figtree(12.5, weight: .bold))
                    .foregroundColor(themeManager.colors.muted)
            }

            Spacer()

            if let readTime = article.estimatedReadTime {
                Text("\(readTime) min")
                    .font(Typography.meta)
                    .foregroundColor(themeManager.colors.muted)
            }
        }
    }

    private var stateLabel: String {
        switch article.readingStatus {
        case .unread: return "Unread"
        case .reading: return "Reading · \(article.readingProgress)%"
        case .completed: return "Done"
        }
    }

    private var footer: some View {
        HStack {
            if !article.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(article.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(Typography.figtree(12))
                            .foregroundColor(themeManager.colors.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(themeManager.colors.sink)
                            .clipShape(Capsule())
                    }
                }
            } else {
                Spacer(minLength: 0)
            }

            Spacer()

            HStack(spacing: 14) {
                Button(action: onFavorite) {
                    Image(systemName: article.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(article.isFavorite ? themeManager.colors.accent : themeManager.colors.text.opacity(0.55))
                }
                if let url = URL(string: article.url) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(themeManager.colors.text.opacity(0.55))
                    }
                }
            }
            .font(.system(size: 15, weight: .medium))
        }
    }

    // MARK: - Compact card (no hero image)

    private var compactCard: some View {
        HStack(spacing: 14) {
            ZStack {
                themeManager.colors.accent2_200
                if let appIcon = Bundle.main.appIcon {
                    Image(uiImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "doc.text.image")
                        .foregroundColor(themeManager.colors.text.opacity(0.3))
                }
            }
            .frame(width: 66, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ReadingStateDot(
                        status: article.readingStatus,
                        accentColor: themeManager.colors.accent,
                        accent2Color: themeManager.colors.accent2,
                        mutedColor: themeManager.colors.muted
                    )
                    if let domain = article.domain {
                        Text(domain.replacingOccurrences(of: "www.", with: "").uppercased())
                            .font(Typography.figtree(12, weight: .bold))
                            .foregroundColor(themeManager.colors.muted)
                    }
                    Spacer()
                    if let readTime = article.estimatedReadTime {
                        Text("\(readTime) min")
                            .font(Typography.meta)
                            .foregroundColor(themeManager.colors.muted)
                    }
                }

                Text(article.title)
                    .font(Typography.listRowTitle)
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(2)
            }
        }
        .padding(14)
    }
}

#Preview {
    VStack(spacing: 16) {
        ArticleCardView(
            article: Article(
                id: "1",
                userId: "user1",
                url: "https://theverge.com/article",
                title: "The quiet return of the personal website",
                content: nil,
                excerpt: "Why people are leaving platforms and building small corners of the web again.",
                imageUrl: "https://picsum.photos/400/300",
                faviconUrl: nil,
                author: "Jane Doe",
                publishedDate: "2024-01-15",
                domain: "theverge.com",
                tags: ["web", "culture"],
                isFavorite: true,
                likeCount: 24,
                commentCount: 8,
                readingStatus: .reading,
                readingProgress: 38,
                estimatedReadTime: 7,
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

        ArticleCardView(
            article: Article(
                id: "2",
                userId: "user1",
                url: "https://nautil.us/article",
                title: "What forests know about time",
                content: nil,
                excerpt: nil,
                imageUrl: nil,
                faviconUrl: nil,
                author: nil,
                publishedDate: nil,
                domain: "nautil.us",
                tags: [],
                isFavorite: false,
                likeCount: 0,
                commentCount: 0,
                readingStatus: .unread,
                readingProgress: 0,
                estimatedReadTime: 12,
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
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .environmentObject(ThemeManager.shared)
}
