import SwiftUI

// MARK: - Login (10)

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var themeManager: ThemeManager

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMagicLinkSent = false

    private var errorColor: Color { Color(hex: "#C0392B") }

    var body: some View {
        ZStack {
            AuthBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 150)

                    logo

                    Text("Everything you meant\nto read.")
                        .font(Typography.caprasimo(40))
                        .lineSpacing(2)
                        .foregroundColor(themeManager.colors.text)
                        .padding(.top, 24)

                    Text("Sign in with a link. No password to remember, nothing to reset.")
                        .font(Typography.figtree(16))
                        .lineSpacing(6)
                        .foregroundColor(themeManager.colors.muted)
                        .frame(maxWidth: 280, alignment: .leading)
                        .padding(.top, 16)

                    emailField
                        .padding(.top, 32)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.figtree(13))
                            .foregroundColor(errorColor)
                            .padding(.top, 8)
                    }

                    sendButton
                        .padding(.top, 16)

                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(Typography.figtree(12.5))
                        .foregroundColor(themeManager.colors.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }
                .padding(.horizontal, Spacing.loginHorizontal)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showMagicLinkSent) {
            MagicLinkSentView(
                email: email,
                onResend: { await resendMagicLink() },
                onTryDifferentEmail: { showMagicLinkSent = false }
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Logo

    private var logo: some View {
        Text("Z")
            .font(Typography.caprasimo(30))
            .foregroundColor(themeManager.colors.page)
            .frame(width: 64, height: 64)
            .background(themeManager.colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Email Field

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(Typography.fieldLabel)
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .foregroundColor(themeManager.colors.muted)

                TextField(
                    "",
                    text: $email,
                    prompt: Text("you@example.com").foregroundColor(themeManager.colors.muted)
                )
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(themeManager.colors.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(themeManager.colors.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(themeManager.colors.line, lineWidth: 1)
            )
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button(action: { Task { await sendMagicLink() } }) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(themeManager.colors.page)
                } else {
                    Text("Send magic link")
                        .font(Typography.caprasimo(16.5))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(themeManager.colors.page)
            .padding(.vertical, 16)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
        }
        .disabled(isLoading || email.isEmpty)
        .opacity(email.isEmpty ? 0.6 : 1)
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

// MARK: - Shared Auth Shell Background

/// Two soft off-screen circles over a flat `page` background — shared by
/// LoginView and MagicLinkSentView (docs/revamp-ios/README.md · "10 Login").
struct AuthBackground: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.colors.page

            Circle()
                .fill(themeManager.colors.accent200)
                .frame(width: 280, height: 280)
                .offset(x: 90, y: -70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Circle()
                .fill(themeManager.colors.accent2_200)
                .frame(width: 220, height: 220)
                .offset(x: -70, y: 70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .ignoresSafeArea()
        .clipped()
    }
}

#Preview {
    LoginView()
        .environmentObject(ThemeManager.shared)
}
