import SwiftUI
import Supabase


// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = ArticleListViewModel()
    
    @State private var showAddArticle = false
    @State private var showThemeSelector = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Filter Bar
                    filterBar
                    
                    // Article List
                    ArticleListView(viewModel: viewModel)
                }

            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet(onArticleAdded: {
                    Task { await viewModel.refresh() }
                })
                .environmentObject(themeManager)
            }
            .sheet(isPresented: $showThemeSelector) {
                ThemeSelectorSheet()
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
        VStack(spacing: Spacing.sm) {
            HStack {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("SuperReader")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(PremiumGradients.primary)
                    
                    Text("Save and read your favorite articles")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.colors.textSecondary)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: Spacing.sm) {
                    // Theme Button
                    Button(action: { showThemeSelector = true }) {
                        Image(systemName: themeManager.currentTheme == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundColor(themeManager.colors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(themeManager.colors.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    
                    // Add Article Button
                    Button(action: { showAddArticle = true }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Add")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(PremiumGradients.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                }
            }
            
            // View Mode Toggle & Search
            HStack(spacing: Spacing.sm) {
                // Search Bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.colors.textSecondary)
                    
                    TextField("Search articles...", text: $viewModel.searchQuery)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(themeManager.colors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                
                // View Mode Toggle
                Button(action: { themeManager.toggleViewMode() }) {
                    Image(systemName: themeManager.viewMode.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(themeManager.colors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // All
                FilterChip(
                    title: "Tutti",
                    isSelected: viewModel.filters.readingStatus == nil,
                    action: { viewModel.setReadingStatusFilter(nil) }
                )
                
                // Read / Started (Letti use .reading based on elimination)
                FilterChip(
                    title: "Letti",
                    isSelected: viewModel.filters.readingStatus == .reading,
                    action: { viewModel.setReadingStatusFilter(.reading) }
                )
                
                // Unread (Non Letti)
                FilterChip(
                    title: "Non Letti",
                    isSelected: viewModel.filters.readingStatus == .unread,
                    action: { viewModel.setReadingStatusFilter(.unread) }
                )
                
                // Completed (Completati)
                FilterChip(
                    title: "Completati",
                    isSelected: viewModel.filters.readingStatus == .completed,
                    action: { viewModel.setReadingStatusFilter(.completed) }
                )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : themeManager.colors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(PremiumGradients.primary) : AnyShapeStyle(themeManager.colors.bgSecondary)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : themeManager.colors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Theme Selector Sheet

struct ThemeSelectorSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
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
                            
                            VStack(alignment: .leading) {
                                Text(theme.displayName)
                                    .font(.headline)
                                    .foregroundColor(themeManager.colors.textPrimary)
                            }
                            
                            Spacer()
                            
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
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
