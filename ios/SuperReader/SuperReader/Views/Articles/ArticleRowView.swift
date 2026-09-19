import SwiftUI

// MARK: - Article Row View (Library · list)
//
// Stessa riga del canale feed (design 06b): miniatura 78pt radius 22, riga
// meta con dominio e tempo di lettura, titolo su due righe e — sotto — una
// sola informazione, lo snippet oppure la barra di avanzamento.

struct ArticleRowView: View {
    let article: Article
    /// "Up next" membership indicator (nil = not queued).
    var queueState: QueueActionState? = nil
    /// Tinta del segnaposto, alternata lungo la lista.
    var tint: MediaTint = .accent2

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        FeedArticleRow(
            imageUrl: article.imageUrl,
            state: article.feedItemState,
            metaLabel: article.domain?.replacingOccurrences(of: "www.", with: "").uppercased(),
            readTimeLabel: article.estimatedReadTime.map { "\($0) min" },
            title: article.title,
            snippet: article.excerpt,
            tint: tint,
            trailingBadge: queueState.map { AnyView(QueueStateGlyph(state: $0, size: 11)) }
        )
    }
}

// MARK: - Article → feed item state

extension Article {
    /// Mappa lo stato di lettura della Libreria sullo stato di riga condiviso
    /// con il canale feed.
    var feedItemState: FeedItemState {
        switch readingStatus {
        case .completed:
            return .read
        case .reading:
            return .reading(progress: Double(readingProgress) / 100)
        case .unread:
            return .unread
        }
    }
}

// MARK: - Queue State Glyph

/// Small "in Up next" marker shared by the Library list row and grid card:
/// a spinner while adding, a numbered-list glyph in `accent-2` once queued.
struct QueueStateGlyph: View {
    let state: QueueActionState
    var size: CGFloat = 13

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            switch state {
            case .saving:
                ProgressView()
                    .controlSize(.mini)
                    .tint(themeManager.colors.accent)
            case .done:
                Image(systemName: "list.number")
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(themeManager.colors.accent2)
            }
        }
        .accessibilityLabel(state == .done ? "In Up next" : "Adding to Up next")
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
