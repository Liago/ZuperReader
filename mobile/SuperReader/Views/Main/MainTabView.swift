import SwiftUI
import Supabase


// MARK: - Main Tab View

struct MainTabView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    @State private var selectedTab = 0
    @State private var unreadSharesCount = 0
    @State private var pendingRequestsCount = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home - Articles
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Shared Inbox
            SharedInboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .badge(unreadSharesCount > 0 ? unreadSharesCount : 0)
                .tag(1)
            
            // Friends
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .badge(pendingRequestsCount > 0 ? pendingRequestsCount : 0)
                .tag(2)
            
            // Profile
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
        .tint(themeManager.colors.accent)
        .environmentObject(themeManager)
        .task {
            await loadBadgeCounts()
        }
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
