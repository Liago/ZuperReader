import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.scenePhase) var scenePhase
    @State private var isProcessingSharedURLs = false

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
                    await processSharedURLs()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && authManager.isAuthenticated {
                Task {
                    await processSharedURLs()
                }
            }
        }
    }
    
    private func processSharedURLs() async {
        guard !isProcessingSharedURLs,
              let user = await SupabaseService.shared.currentUser else { return }
        
        isProcessingSharedURLs = true
        defer { isProcessingSharedURLs = false }
        
        let appGroupIdentifier = "group.liagosoft.SuperReader"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        
        let pendingUrls = sharedDefaults.stringArray(forKey: "PendingSharedURLs") ?? []
        guard !pendingUrls.isEmpty else { return }
        
        // Clear the queue before processing to avoid duplicates if more are shared while parsing
        sharedDefaults.removeObject(forKey: "PendingSharedURLs")
        
        print("Processing \(pendingUrls.count) shared URLs...")
        
        for urlString in pendingUrls {
            do {
                let parsedData = try await SupabaseService.shared.parseArticleUrl(urlString)
                _ = try await SupabaseService.shared.saveArticle(parsedData: parsedData, userId: user.id.uuidString)
                print("Successfully saved shared article: \(urlString)")
                
                // Notify the reading list to refresh
                NotificationCenter.default.post(name: NSNotification.Name("RefreshArticles"), object: nil)
            } catch {
                print("Failed to save shared article \(urlString): \(error)")
                // Optionally put the failed URL back in the queue
            }
        }
    }
}

#Preview {
    ContentView()
}
