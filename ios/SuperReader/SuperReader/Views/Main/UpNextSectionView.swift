import SwiftUI

// MARK: - Up Next Section (home · first thing on screen)
//
// The reading queue opens the home: the next article as a hero card, then
// the following ones as a short numbered list. Reordering and the full queue
// live in `QueueView` ("Reorder" / "See all").

struct UpNextSectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var store = ReadingQueueStore.shared

    /// Rows shown under the hero before "See all".
    private let followingLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Up next")
                    .font(Typography.sheetTitle)
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityAddTraits(.isHeader)

                if !store.items.isEmpty {
                    Text(countLabel)
                        .font(Typography.meta)
                        .foregroundColor(themeManager.colors.muted)
                }
            }

            Spacer()

            if !store.items.isEmpty {
                NavigationLink(destination: QueueView()) {
                    Text(store.items.count > 1 ? "Reorder" : "Open")
                        .font(Typography.figtree(13.5, weight: .semibold))
                        .foregroundColor(themeManager.colors.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .minimumTapTarget()
                .accessibilityLabel("Open Up next queue")
            }
        }
    }

    private var countLabel: String {
        let n = store.items.count
        var label = "\(n) \(n == 1 ? "article" : "articles")"
        let minutes = store.totalMinutes
        if minutes > 0 { label += " · \(minutes) min" }
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
                                .padding(.leading, 26 + 14)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(themeManager.colors.card)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))
        }

        let hidden = items.count - 1 - following.count
        if hidden > 0 {
            NavigationLink(destination: QueueView()) {
                HStack(spacing: 6) {
                    Text("See all · \(hidden) more in your queue")
                        .font(Typography.figtree(13.5, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(Typography.symbol(11, weight: .bold))
                }
                .foregroundColor(themeManager.colors.accent800)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
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
    }

    // MARK: - Empty

    private var emptyCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.accent2_200)
                    .frame(width: 44, height: 44)
                Image(systemName: "list.number")
                    .font(Typography.symbol(17, weight: .bold))
                    .foregroundColor(themeManager.colors.accent2)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing up next")
                    .font(Typography.figtree(16, weight: .bold))
                    .foregroundColor(themeManager.colors.text)

                Text("Long-press an article below or in Feeds and choose “Add to Up next” to build your reading queue.")
                    .font(Typography.figtree(13.5))
                    .lineSpacing(2)
                    .foregroundColor(themeManager.colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.colors.sink)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listThumbnail))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Up Next Hero Card

private struct UpNextHeroCard: View {
    let article: Article

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if article.imageUrl != nil {
                ZStack(alignment: .topLeading) {
                    themeManager.colors.accent200
                    AsyncImageView(url: article.imageUrl, cornerRadius: 0)
                        .aspectRatio(contentMode: .fill)
                    nextPill
                        .padding(12)
                }
                .frame(height: 170)
                .clipped()
            }

            progressTrack

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    if article.imageUrl == nil {
                        nextPill
                    }
                    Text(meta)
                        .font(Typography.figtree(12, weight: .bold))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                }

                Text(article.title)
                    .font(Typography.cardTitle)
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let excerpt = article.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(Typography.bodyExcerpt)
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(Typography.symbol(12, weight: .bold))
                    Text(article.readingProgress > 0 ? "Continue reading" : "Start reading")
                        .font(Typography.figtree(13.5, weight: .bold))
                }
                .foregroundColor(themeManager.colors.page)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(themeManager.colors.accent)
                .clipShape(Capsule())
                .padding(.top, 4)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.colors.card)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the next article in your queue")
    }

    private var nextPill: some View {
        Text("1 · NEXT")
            .font(Typography.figtree(11, weight: .heavy))
            .tracking(1.1)
            .foregroundColor(themeManager.colors.page)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(themeManager.colors.line)
                Rectangle()
                    .fill(themeManager.colors.accent)
                    .frame(width: geometry.size.width * min(max(CGFloat(article.readingProgress) / 100, 0), 1))
            }
        }
        .frame(height: 3)
    }

    private var meta: String {
        var parts: [String] = []
        if let domain = article.domain, !domain.isEmpty {
            parts.append(domain.replacingOccurrences(of: "www.", with: "").uppercased())
        }
        if let minutes = article.estimatedReadTime, minutes > 0 {
            parts.append("\(minutes) MIN")
        }
        if article.readingProgress > 0 && article.readingStatus != .completed {
            parts.append("\(article.readingProgress)%")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Up Next Compact Row

private struct UpNextCompactRow: View {
    let position: Int
    let article: Article

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            Text("\(position)")
                .font(Typography.figtree(12.5, weight: .bold))
                .foregroundColor(themeManager.colors.muted)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(themeManager.colors.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(meta)
                    .font(Typography.meta)
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(Typography.symbol(12, weight: .bold))
                .foregroundColor(themeManager.colors.muted.opacity(0.6))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(position). \(article.title)")
    }

    private var meta: String {
        var parts: [String] = []
        if let domain = article.domain, !domain.isEmpty {
            parts.append(domain.replacingOccurrences(of: "www.", with: ""))
        }
        if let minutes = article.estimatedReadTime, minutes > 0 {
            parts.append("\(minutes) min")
        }
        return parts.joined(separator: " · ")
    }
}
