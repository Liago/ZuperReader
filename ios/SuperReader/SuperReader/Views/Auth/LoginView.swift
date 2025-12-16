import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMagicLinkSent = false
    
    var body: some View {
        ZStack {
            // Animated background
            backgroundView
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 80)
                    
                    // Logo and Title
                    logoSection
                    
                    Spacer(minLength: 40)
                    
                    // Login Card
                    loginCard
                    
                    Spacer(minLength: 40)
                    
                    // Footer
                    footerText
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .fullScreenCover(isPresented: $showMagicLinkSent) {
            MagicLinkSentView(
                email: email,
                onResend: { await resendMagicLink() },
                onTryDifferentEmail: { showMagicLinkSent = false }
            )
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            PremiumGradients.login
                .ignoresSafeArea()
            
            // Floating circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 100, y: 300)
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: Spacing.md) {
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isLoading)
            
            VStack(spacing: Spacing.xs) {
                Text("Welcome to")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("SuperReader")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Sign in with a magic link – no password needed")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Login Card
    
    private var loginCard: some View {
        VStack(spacing: Spacing.lg) {
            // Email Input
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Email Address")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "at")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(size: 16))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Error Message
            if let error = errorMessage {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            
            // Submit Button
            Button(action: { Task { await sendMagicLink() } }) {
                HStack(spacing: Spacing.sm) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Magic Link")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md + 2)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isLoading || email.isEmpty)
            .opacity(email.isEmpty ? 0.6 : 1)
            .scaleEffect(isLoading ? 0.98 : 1)
            .animation(.spring(response: 0.3), value: isLoading)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(Color.white.opacity(0.95))
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Footer
    
    private var footerText: some View {
        Text("By signing in, you agree to our Terms of Service and Privacy Policy")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.6))
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Actions
    
    private func sendMagicLink() async {
        guard !email.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.signInWithMagicLink(email: email)
            showMagicLinkSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func resendMagicLink() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.signInWithMagicLink(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView()
}
