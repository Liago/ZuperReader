import SwiftUI

// MARK: - Article Row View (Library · list)

struct ArticleRowView: View {
    let article: Article

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

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
                    .foregroundColor(article.readingStatus == .completed ? themeManager.colors.muted : themeManager.colors.text)
                    .lineLimit(2)

                progressTrack
            }
        }
        .padding(.vertical, 14)
    }

    private var thumbnail: some View {
        Group {
            if let imageUrl = article.imageUrl {
                AsyncImageView(url: imageUrl, cornerRadius: CornerRadius.listThumbnail)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    themeManager.colors.accent2_200
                    if let appIcon = Bundle.main.appIcon {
                        Image(uiImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "doc.text")
                            .foregroundColor(themeManager.colors.text.opacity(0.3))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))
            }
        }
        .frame(width: 66, height: 66)
        .clipped()
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(themeManager.colors.line)
                Rectangle()
                    .fill(article.readingStatus == .completed ? themeManager.colors.muted.opacity(0.45) : themeManager.colors.accent)
                    .frame(width: geometry.size.width * progressFraction)
            }
        }
        .frame(height: 2)
        .clipShape(Capsule())
    }

    private var progressFraction: CGFloat {
        if article.readingStatus == .completed { return 1 }
        return min(max(CGFloat(article.readingProgress) / 100, 0), 1)
    }
}

// MARK: - Reading State Dot

/// A 7pt colored dot for "unread"/"reading" rows, or a check glyph for "completed"
/// rows — shared between the Library grid card and list row (docs/revamp-ios/README.md).
struct ReadingStateDot: View {
    let status: ReadingStatus
    let accentColor: Color
    let accent2Color: Color
    let mutedColor: Color
    var size: CGFloat = 7

    var body: some View {
        Group {
            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: size + 1, weight: .bold))
                    .foregroundColor(mutedColor)
            } else {
                Circle()
                    .fill(status == .reading ? accentColor : accent2Color)
                    .frame(width: size, height: size)
            }
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
    VStack(spacing: 0) {
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
                readingStatus: .reading,
                readingProgress: 60,
                estimatedReadTime: 4,
                isPublic: false,
                scrapedAt: "",
                aiSummary: nil,
                aiSummaryGeneratedAt: nil,
                createdAt: "2023-11-20T10:00:00.000Z",
                updatedAt: ""
            )
        )
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
