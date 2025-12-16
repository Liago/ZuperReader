import SwiftUI

// MARK: - Magic Link Sent View

struct MagicLinkSentView: View {
    let email: String
    let onResend: () async -> Void
    let onTryDifferentEmail: () -> Void
    
    @StateObject private var authManager = AuthManager.shared
    @State private var manualLink = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer(minLength: 60)
                    
                    // Success Card
                    successCard
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            PremiumGradients.login
                .ignoresSafeArea()
            
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
    
    // MARK: - Success Card
    
    private var successCard: some View {
        VStack(spacing: Spacing.lg) {
            // Email Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                
                Image(systemName: "envelope.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("Check your email")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                
                Text("We've sent a magic link to")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Text(email)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            Text("Click the link in the email to sign in. You can close this screen.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            // Divider with text
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("or paste the link here")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Manual Link Input
            VStack(spacing: Spacing.sm) {
                TextField("azreader://auth/confirm?...", text: $manualLink)
                    .font(.system(size: 14))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: { Task { await verifyLink() } }) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify Link")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm + 4)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .disabled(isVerifying || manualLink.isEmpty)
                .opacity(manualLink.isEmpty ? 0.5 : 1)
            }
            
            // Action Buttons
            VStack(spacing: Spacing.md) {
                Button(action: { Task { await resend() } }) {
                    if isResending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    } else {
                        Text("Didn't receive the email? Resend")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6366F1"))
                    }
                }
                .disabled(isResending)
                
                Button(action: onTryDifferentEmail) {
                    Text("← Try a different email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(Color.white.opacity(0.95))
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Actions
    
    private func verifyLink() async {
        guard !manualLink.isEmpty else { return }
        
        isVerifying = true
        errorMessage = nil
        
        if let url = URL(string: manualLink) {
            let success = await authManager.handleDeepLink(url: url)
            if !success {
                errorMessage = "Invalid Magic Link. Please check and try again."
            }
        } else {
            errorMessage = "Invalid URL format"
        }
        
        isVerifying = false
    }
    
    private func resend() async {
        isResending = true
        await onResend()
        isResending = false
    }
}

#Preview {
    MagicLinkSentView(
        email: "user@example.com",
        onResend: {},
        onTryDifferentEmail: {}
    )
}
