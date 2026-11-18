import SwiftUI

// MARK: - Up Next Section (home)
//
// Editorial Teal (design canvas · "01 · Library (Home)"): the next article in
// the queue as an image-led hero — progress badge, "remove" bookmark, progress
// bar, title, excerpt and byline — followed by the next few articles as
// numbered rows. "See all" opens `QueueView` (full queue, reordering).

struct UpNextSectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var store = ReadingQueueStore.shared

    /// Rows shown under the hero; the rest live in `QueueView`.
    private let followingLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if store.isLoading && store.items.isEmpty {
                ArticleCardSkeleton()
            } else if store.items.isEmpty {
                emptyCard
            } else {
                content
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    private var queuedItems: [QueueItem] {
        store.items.filter { $0.article != nil }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Up next")
                .font(Typography.cardTitle)
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if !store.items.isEmpty {
                NavigationLink(destination: QueueView()) {
                    Text("See all")
                        .font(Typography.ui(13.5, weight: .medium))
                        .foregroundColor(themeManager.colors.accent)
                }
                .buttonStyle(.plain)
                .minimumTapTarget()
                .accessibilityLabel("See all Up next, \(countLabel)")
            }
        }
    }

    private var countLabel: String {
        let n = store.items.count
        var label = "\(n) \(n == 1 ? "article" : "articles")"
        let minutes = store.totalMinutes
        if minutes > 0 { label += ", \(minutes) minutes" }
        return label
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let items = queuedItems

        if let first = items.first, let article = first.article {
            NavigationLink(destination: ArticleReaderView(articleId: first.articleId)) {
                UpNextHeroCard(article: article)
            }
            .buttonStyle(ScaleButtonStyle())
            .contextMenu { menuItems(for: first, article: article) }
            // Outside the link's label, so the tap reaches the button.
            .overlay(alignment: .topTrailing) {
                Button {
                    Task { await store.remove(first) }
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(Typography.symbol(14, weight: .semibold))
                        .foregroundColor(themeManager.colors.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .minimumTapTarget()
                .padding(6)
                .accessibilityLabel("Remove from Up next")
            }
        }

        let following = Array(items.dropFirst().prefix(followingLimit))
        if !following.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(following.enumerated()), id: \.element.id) { offset, item in
                    if let article = item.article {
                        NavigationLink(destination: ArticleReaderView(articleId: item.articleId)) {
                            UpNextCompactRow(position: offset + 2, article: article)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menuItems(for: item, article: article) }

                        if offset < following.count - 1 {
                            Rectangle()
                                .fill(themeManager.colors.line)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func menuItems(for item: QueueItem, article: Article) -> some View {
        Button(role: .destructive) {
            Task { await store.remove(item) }
        } label: {
            Label("Remove from Up next", systemImage: "minus.circle")
        }

        if let url = URL(string: article.url) {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        PublicLinkMenuButton(article: article)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bookmark")
                .font(Typography.symbol(17, weight: .semibold))
                .foregroundColor(themeManager.colors.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(themeManager.colors.accent200))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing up next")
                    .font(Typography.ui(16, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)

                Text("Long-press an article below or in Feeds and choose “Add to Up next” to build your reading queue.")
                    .font(Typography.ui(13.5))
                    .lineSpacing(2)
                    .foregroundColor(themeManager.colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Up Next Hero Card

private struct UpNextHeroCard: View {
    let article: Article

    @EnvironmentObject var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var imageHeight: CGFloat = 176

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            imageBlock

            Text(article.title)
                .font(Typography.display(21, weight: .bold, relativeTo: .title3))
                .foregroundColor(themeManager.colors.text)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let excerpt = article.excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(Typography.ui(14, relativeTo: .subheadline))
                    .lineSpacing(2)
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            byline
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the next article in your queue")
    }

    // MARK: Image

    private var imageBlock: some View {
        ZStack(alignment: .topLeading) {
            themeManager.colors.accent200

            if article.imageUrl != nil {
                AsyncImageView(url: article.imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(Typography.symbol(32, weight: .light))
                    .foregroundColor(themeManager.colors.accent)
                    .opacity(0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }

            Text(badge)
                .font(Typography.ui(11.5, weight: .semibold, relativeTo: .caption2))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#16191A").opacity(0.62)))
                .padding(12)
        }
        .frame(height: imageHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { progressTrack }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }

    private var progressFraction: CGFloat {
        min(max(CGFloat(article.readingProgress) / 100, 0), 1)
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.55))
                Rectangle()
                    .fill(themeManager.colors.accent)
                    .frame(width: geometry.size.width * progressFraction)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var badge: String {
        article.readingProgress > 0 ? "Reading · \(article.readingProgress)%" : "Up next"
    }

    // MARK: Byline

    private var byline: some View {
        HStack(spacing: 4) {
            if let author = article.author?.trimmingCharacters(in: .whitespaces), !author.isEmpty {
                Text("By")
                    .foregroundColor(themeManager.colors.muted)
                Text(author)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)
            }

            if let source {
                Text(article.author?.isEmpty == false ? "for" : "From")
                    .foregroundColor(themeManager.colors.muted)
                    .padding(.leading, article.author?.isEmpty == false ? 4 : 0)
                Text(source)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let timeLabel {
                Text(timeLabel)
                    .foregroundColor(themeManager.colors.muted)
                    .layoutPriority(1)
            }
        }
        .font(Typography.ui(13, relativeTo: .footnote))
    }

    private var source: String? {
        guard let domain = article.domain, !domain.isEmpty else { return nil }
        return domain.replacingOccurrences(of: "www.", with: "")
    }

    /// "7 min left" while reading, the full estimate otherwise.
    private var timeLabel: String? {
        guard let minutes = article.estimatedReadTime, minutes > 0 else { return nil }
        guard article.readingProgress > 0, article.readingStatus != .completed else {
            return "\(minutes) min"
        }
        let left = Int((Double(minutes) * Double(100 - article.readingProgress) / 100).rounded(.up))
        return "\(max(left, 1)) min left"
    }
}

// MARK: - Up Next Compact Row

private struct UpNextCompactRow: View {
    let position: Int
    let article: Article

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(Typography.ui(13, weight: .bold))
                .foregroundColor(themeManager.colors.muted)
                .frame(width: 18)

            thumbnail
                .frame(width: 56, height: 56)
                .thumbnailClip(CornerRadius.smallThumbnail)

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(Typography.ui(14.5, weight: .semibold, relativeTo: .subheadline))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                metaLine
                    .font(Typography.ui(12, relativeTo: .caption))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(position). \(article.title)")
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            themeManager.colors.surface
            if article.imageUrl != nil {
                AsyncImageView(url: article.imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
            }
        }
        .accessibilityHidden(true)
    }

    /// "source · 9 min", with the time in the accent color.
    private var metaLine: some View {
        let domain = (article.domain ?? "").replacingOccurrences(of: "www.", with: "")
        let minutes = article.estimatedReadTime ?? 0

        return HStack(spacing: 0) {
            if !domain.isEmpty {
                Text(domain)
                    .foregroundColor(themeManager.colors.muted)
            }
            if !domain.isEmpty && minutes > 0 {
                Text(" · ")
                    .foregroundColor(themeManager.colors.muted)
            }
            if minutes > 0 {
                Text("\(minutes) min")
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.colors.accent)
            }
        }
    }
}
