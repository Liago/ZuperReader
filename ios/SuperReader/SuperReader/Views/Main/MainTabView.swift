import SwiftUI
import Supabase
import UIKit


// MARK: - Main Tab View

struct MainTabView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    @State private var selectedTab = 0
    @State private var unreadSharesCount = 0
    @State private var pendingRequestsCount = 0

    private var peopleBadgeCount: Int {
        unreadSharesCount + pendingRequestsCount
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Library
            HomeView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(0)

            // Feeds
            RSSListView()
                .tabItem {
                    Label("Feeds", systemImage: "dot.radiowaves.up.forward")
                }
                .tag(1)

            // People — merged Shared Inbox + Friends (docs/revamp-ios/README.md · "07 People")
            PeopleView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }
                .badge(peopleBadgeCount > 0 ? peopleBadgeCount : 0)
                .tag(2)

            // You
            ProfileView()
                .tabItem {
                    Label("You", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
        .tint(themeManager.colors.accent)
        .environmentObject(themeManager)
        .observeSystemColorScheme()
        .task {
            await loadBadgeCounts()
        }
        .onAppear { updateTabBarAppearance() }
        .onChange(of: themeManager.resolvedTheme) { _, _ in updateTabBarAppearance() }
    }

    // Organic design system tab bar chrome (rail fill, 1pt top hairline).
    private func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(themeManager.colors.rail)
        appearance.shadowColor = UIColor(themeManager.colors.line)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func loadBadgeCounts() async {
        guard let userId = authManager.user?.id.uuidString else { return }
        
        do {
            unreadSharesCount = try await SupabaseService.shared.getUnreadSharesCount(userId: userId)
            let requests = try await SupabaseService.shared.getPendingFriendRequests(userId: userId)
            pendingRequestsCount = requests.count
        } catch {
            print("Failed to load badge counts: \(error)")
        }
    }
}

#Preview {
    MainTabView()
}
