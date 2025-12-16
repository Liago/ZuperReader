import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isLoading {
                FullScreenLoadingView(message: "Starting up...")
                    .environmentObject(ThemeManager.shared)
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onOpenURL { url in
            Task {
                if await authManager.handleDeepLink(url: url) {
                    print("Magic Link verified successfully via deep link")
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    await ReadingPreferencesManager.shared.loadFromSupabase()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
