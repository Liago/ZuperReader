import SwiftUI

// MARK: - Magic Link Sent (follows the Login shell)

struct MagicLinkSentView: View {
    let email: String
    let onResend: () async -> Void
    let onTryDifferentEmail: () -> Void

    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var themeManager: ThemeManager

    @State private var manualLink = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var errorColor: Color { Color(hex: "#C0392B") }

    var body: some View {
        ZStack {
            AuthBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 150)

                    logo

                    Text("Check your\nemail.")
                        .font(Typography.caprasimo(40))
                        .lineSpacing(2)
                        .foregroundColor(themeManager.colors.text)
                        .padding(.top, 24)

                    (Text("We sent a magic link to ") + Text(email).fontWeight(.bold) + Text(". Tap it to sign in — you can close this screen."))
                        .font(Typography.figtree(16))
                        .lineSpacing(6)
                        .foregroundColor(themeManager.colors.muted)
                        .padding(.top, 16)

                    dividerRow
                        .padding(.top, 28)

                    manualLinkField
                        .padding(.top, 16)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.figtree(13))
                            .foregroundColor(errorColor)
                            .padding(.top, 8)
                    }

                    verifyButton
                        .padding(.top, 16)

                    actionButtons
                        .padding(.top, 24)
                }
                .padding(.horizontal, Spacing.loginHorizontal)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
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

    // MARK: - Divider

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle().fill(themeManager.colors.line).frame(height: 1)
            Text("or paste the link here")
                .font(Typography.figtree(12.5))
                .foregroundColor(themeManager.colors.muted)
                .fixedSize()
            Rectangle().fill(themeManager.colors.line).frame(height: 1)
        }
    }

    // MARK: - Manual Link Field

    private var manualLinkField: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundColor(themeManager.colors.muted)

            TextField(
                "",
                text: $manualLink,
                prompt: Text("azreader://auth/confirm?...").foregroundColor(themeManager.colors.muted)
            )
            .font(Typography.figtree(14))
            .foregroundColor(themeManager.colors.text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(themeManager.colors.card)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    private var verifyButton: some View {
        Button(action: { Task { await verifyLink() } }) {
            Group {
                if isVerifying {
                    ProgressView()
                        .tint(themeManager.colors.page)
                } else {
                    Text("Verify link")
                        .font(Typography.caprasimo(16.5))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(themeManager.colors.page)
            .padding(.vertical, 16)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
        }
        .disabled(isVerifying || manualLink.isEmpty)
        .opacity(manualLink.isEmpty ? 0.5 : 1)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button(action: { Task { await resend() } }) {
                if isResending {
                    ProgressView()
                        .tint(themeManager.colors.accent)
                } else {
                    Text("Didn't receive the email? Resend")
                        .font(Typography.figtree(14, weight: .semibold))
                        .foregroundColor(themeManager.colors.accent)
                }
            }
            .disabled(isResending)

            Button(action: onTryDifferentEmail) {
                Text("← Try a different email")
                    .font(Typography.figtree(14))
                    .foregroundColor(themeManager.colors.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func verifyLink() async {
        guard !manualLink.isEmpty else { return }

        isVerifying = true
        errorMessage = nil

        if let url = URL(string: manualLink) {
            let success = await authManager.handleDeepLink(url: url)
            if !success {
                errorMessage = "Invalid magic link. Please check and try again."
            }
        } else {
            errorMessage = "Invalid URL format."
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
    .environmentObject(ThemeManager.shared)
}
