import SwiftUI
import Supabase
import Auth

// MARK: - Up Next (reading queue)
//
// iOS counterpart of the web `/queue` page: an ordered shortlist to read next.
// Drag to reorder (long-press a row, or tap "Reorder"), swipe / × to remove;
// finishing an article in the reader advances the queue.

struct QueueView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var store = ReadingQueueStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var editMode: EditMode = .inactive

    var body: some View {
        ZStack {
            themeManager.colors.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if store.isLoading && store.items.isEmpty {
                    loadingView
                } else if let error = store.errorMessage, store.items.isEmpty {
                    errorView(error)
                } else if store.items.isEmpty {
                    emptyView
                } else {
                    queueList
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let userId = authManager.user?.id.uuidString {
                await store.load(userId: userId)
            }
        }
        .onChange(of: store.items.isEmpty) { _, isEmpty in
            if isEmpty { editMode = .inactive }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.colors.text)
                        .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                        .background(themeManager.colors.sink)
                        .clipShape(Circle())
                }

                Spacer()

                if store.items.count > 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }) {
                        Text(editMode == .active ? "Done" : "Reorder")
                            .font(Typography.figtree(13.5, weight: .semibold))
                            .foregroundColor(editMode == .active ? themeManager.colors.page : themeManager.colors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(editMode == .active ? themeManager.colors.text : Color.clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(editMode == .active ? Color.clear : themeManager.colors.line, lineWidth: 1)
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(countLabel)
                    .font(Typography.figtree(11, weight: .bold))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundColor(themeManager.colors.muted)

                Text("Up next")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)

                Text("An ordered shortlist to read next. Drag to reorder — finishing an article advances the queue.")
                    .font(Typography.figtree(13.5))
                    .lineSpacing(3)
                    .foregroundColor(themeManager.colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var countLabel: String {
        let n = store.items.count
        var label = "\(n) \(n == 1 ? "article" : "articles")"
        let minutes = store.totalMinutes
        if minutes > 0 { label += " · \(minutes) minutes" }
        return label
    }

    // MARK: - List

    private var queueList: some View {
        List {
            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                if let article = item.article {
                    ZStack {
                        NavigationLink(destination: ArticleReaderView(articleId: item.articleId)) {
                            EmptyView()
                        }
                        .opacity(0)

                        QueueRowView(
                            index: index,
                            article: article,
                            isEditing: editMode == .active,
                            onRemove: { Task { await store.remove(item) } }
                        )
                    }
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: Spacing.screenHorizontal,
                        bottom: 0,
                        trailing: Spacing.screenHorizontal
                    ))
                    .listRowSeparatorTint(themeManager.colors.line)
                    .listRowBackground(themeManager.colors.page)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await store.remove(item) }
                        } label: {
                            Label("Remove", systemImage: "xmark")
                        }
                    }
                }
            }
            .onMove { source, destination in
                Task { await store.move(from: source, to: destination) }
            }
            .onDelete { offsets in
                let removed = offsets.map { store.items[$0] }
                Task {
                    for item in removed { await store.remove(item) }
                }
            }

            Color.clear
                .frame(height: Spacing.scrollBottomInset)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .moveDisabled(true)
                .deleteDisabled(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.colors.page)
        .environment(\.editMode, $editMode)
        .refreshable {
            await store.refresh()
        }
    }

    // MARK: - Loading / Error / Empty

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    ArticleRowSkeleton()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(themeManager.colors.accent)
            Text("Couldn't load your queue")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)
            Text(message)
                .font(Typography.figtree(13))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await store.refresh() }
            }
            .font(Typography.figtree(15, weight: .bold))
            .foregroundColor(themeManager.colors.page)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.sink)
                    .frame(width: 96, height: 96)
                Image(systemName: "list.number")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.colors.text.opacity(0.35))
            }

            Text("Your queue is empty")
                .font(Typography.sheetTitle)
                .foregroundColor(themeManager.colors.text)

            Text("Add articles to Up next from the Library or when you save a link.")
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.muted)
                .multilineTextAlignment(.center)

            Button(action: { dismiss() }) {
                Text("Go to Library")
                    .font(Typography.figtree(15, weight: .bold))
                    .foregroundColor(themeManager.colors.page)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Queue Row

private struct QueueRowView: View {
    let index: Int
    let article: Article
    let isEditing: Bool
    let onRemove: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var isFirst: Bool { index == 0 }

    var body: some View {
        HStack(spacing: 14) {
            positionBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(Typography.figtree(16, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(2)

                Text(meta)
                    .font(Typography.meta)
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !isEditing {
                if isFirst {
                    Text("Continue")
                        .font(Typography.figtree(12.5, weight: .bold))
                        .foregroundColor(themeManager.colors.accent800)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(themeManager.colors.accent200)
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.colors.muted.opacity(0.5))
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.colors.muted.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var positionBadge: some View {
        Text("\(index + 1)")
            .font(Typography.figtree(12.5, weight: .bold))
            .foregroundColor(isFirst ? themeManager.colors.page : themeManager.colors.muted)
            .frame(width: 26, height: 26)
            .background(isFirst ? themeManager.colors.accent : Color.clear)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(isFirst ? Color.clear : themeManager.colors.line, lineWidth: 1)
            )
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

#Preview {
    NavigationStack {
        QueueView()
            .environmentObject(ThemeManager.shared)
    }
}
