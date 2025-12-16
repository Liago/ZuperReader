import Foundation
import Combine
import Supabase

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var user: User?
    @Published var isLoading = true
    @Published var isAuthenticated = false
    
    private var authStateTask: Task<Void, Never>?
    
    private init() {
        Task {
            await checkSession()
            observeAuthState()
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Check existing session
    
    func checkSession() async {
        isLoading = true
        
        if let user = await SupabaseService.shared.currentUser {
            self.user = user
            self.isAuthenticated = true
        } else {
            self.user = nil
            self.isAuthenticated = false
        }
        
        isLoading = false
    }
    
    // MARK: - Observe auth state changes
    
    private func observeAuthState() {
        authStateTask = Task {
            for await event in await SupabaseService.shared.onAuthStateChange() {
                switch event {
                case .signedIn:
                    if let user = await SupabaseService.shared.currentUser {
                        self.user = user
                        self.isAuthenticated = true
                    }
                case .signedOut:
                    self.user = nil
                    self.isAuthenticated = false
                case .tokenRefreshed:
                    if let user = await SupabaseService.shared.currentUser {
                        self.user = user
                    }
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Sign in with Magic Link
    
    func signInWithMagicLink(email: String) async throws {
        try await SupabaseService.shared.signInWithOtp(email: email)
    }
    
    // MARK: - Verify OTP from deep link
    
    func verifyMagicLink(tokenHash: String, type: String) async throws {
        try await SupabaseService.shared.verifyOtp(tokenHash: tokenHash, type: type)
        await checkSession()
    }
    
    // MARK: - Sign out
    
    func signOut() async throws {
        try await SupabaseService.shared.signOut()
        user = nil
        isAuthenticated = false
    }
    
    // MARK: - Handle deep link
    
    func handleDeepLink(url: URL) async -> Bool {
        // Expected format: azreader://auth/confirm?token_hash=...&type=...
        guard url.scheme == "azreader",
              url.host == "auth",
              url.path == "/confirm" else {
            return false
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let tokenHash = components?.queryItems?.first(where: { $0.name == "token_hash" })?.value,
              let type = components?.queryItems?.first(where: { $0.name == "type" })?.value else {
            return false
        }
        
        do {
            try await verifyMagicLink(tokenHash: tokenHash, type: type)
            return true
        } catch {
            print("Failed to verify magic link: \(error)")
            return false
        }
    }
}
