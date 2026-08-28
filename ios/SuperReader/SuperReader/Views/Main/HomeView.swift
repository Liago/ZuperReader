import SwiftUI
import Supabase


// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = ArticleListViewModel()

    @State private var showAddArticle = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    // Header
                    headerView

                    // Filter Bar
                    filterBar

                    // Article List
                    ArticleListView(viewModel: viewModel, onAddArticle: { showAddArticle = true })
                }

            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet(onArticleAdded: {
                    Task { await viewModel.refresh() }
                })
                .environmentObject(themeManager)
            }
        }
        .task {
            if let userId = authManager.user?.id.uuidString {
                await viewModel.loadArticles(userId: userId)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Library")
                    .font(Typography.largeTitle)
                    .foregroundColor(themeManager.colors.text)

                Spacer()

                HStack(spacing: Spacing.sm) {
                    // View Mode Toggle
                    Button(action: { themeManager.toggleViewMode() }) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.viewMode == .list ? themeManager.colors.page : themeManager.colors.text)
                            .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                            .background(themeManager.viewMode == .list ? themeManager.colors.text : themeManager.colors.sink)
                            .clipShape(Circle())
                    }

                    // Add Article Button
                    Button(action: { showAddArticle = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(themeManager.colors.page)
                            .frame(width: Spacing.iconButtonSize, height: Spacing.iconButtonSize)
                            .background(themeManager.colors.accent)
                            .clipShape(Circle())
                    }
                }
            }

            // Search Bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.colors.text.opacity(0.55))

                TextField(
                    "",
                    text: $viewModel.searchQuery,
                    prompt: Text("Search articles").foregroundColor(themeManager.colors.muted)
                )
                .font(Typography.figtree(15))
                .foregroundColor(themeManager.colors.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(themeManager.colors.sink)
            .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.contentTop)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                FilterChip(
                    title: "All",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == nil,
                    action: { viewModel.setReadingStatusFilter(nil) }
                )

                FilterChip(
                    title: "Unread",
                    dotColor: themeManager.colors.accent2,
                    isSelected: viewModel.filters.readingStatus == .unread,
                    action: { viewModel.setReadingStatusFilter(.unread) }
                )

                FilterChip(
                    title: "Reading",
                    dotColor: themeManager.colors.accent,
                    isSelected: viewModel.filters.readingStatus == .reading,
                    action: { viewModel.setReadingStatusFilter(.reading) }
                )

                FilterChip(
                    title: "Done",
                    dotColor: nil,
                    isSelected: viewModel.filters.readingStatus == .completed,
                    action: { viewModel.setReadingStatusFilter(.completed) }
                )
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let dotColor: Color?
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(Typography.figtree(13.5, weight: .semibold))
            }
            .foregroundColor(isSelected ? themeManager.colors.page : themeManager.colors.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? themeManager.colors.text : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : themeManager.colors.line, lineWidth: 1)
            )
        }
    }
}

// MARK: - Theme Selector Sheet

struct ThemeSelectorSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private func previewTheme(_ theme: ColorTheme) -> ColorTheme {
        if theme == .system {
            return colorScheme == .dark ? .dark : .cream
        }
        return theme
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(ColorTheme.allCases, id: \.self) { theme in
                    Button(action: {
                        themeManager.setTheme(theme)
                        dismiss()
                    }) {
                        HStack {
                            // Theme preview
                            if theme == .system {
                                ZStack {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(ColorTheme.cream.colors.bgPrimary)
                                        Rectangle()
                                            .fill(ColorTheme.dark.colors.bgPrimary)
                                    }
                                    Image(systemName: "circle.lefthalf.filled")
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                theme.colors.bgGradientFrom,
                                                theme.colors.bgGradientVia,
                                                theme.colors.bgGradientTo
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(theme.colors.border, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading) {
                                Text(theme.displayName)
                                    .font(.headline)
                                    .foregroundColor(themeManager.colors.textPrimary)
                                if theme == .system {
                                    Text("Follows system setting")
                                        .font(.caption)
                                        .foregroundColor(themeManager.colors.textSecondary)
                                }
                            }

                            Spacer()

                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(themeManager.colors.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager.shared)
}
