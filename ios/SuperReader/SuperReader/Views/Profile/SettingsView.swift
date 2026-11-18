import SwiftUI
import Supabase
import Auth

// MARK: - Settings
//
// Editorial Teal (design canvas · "12 · Impostazioni"): grouped white cards
// on the light `rail` background. Pushed from the gear in the You tab; it
// gathers what used to sit at the bottom of the profile — appearance,
// reading defaults, feed sync, account and sign out.

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var preferencesManager = ReadingPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(RSSViewModel.autoRefreshIntervalKey) private var rawRefreshInterval: String = RSSRefreshInterval.fifteenMinutes.rawValue

    /// Shown under "Account"; passed in by the profile, which already loaded it.
    var email: String?

    @State private var showReadingDefaults = false
    @State private var showFeedSync = false
    @State private var confirmSignOut = false

    private var refreshInterval: RSSRefreshInterval {
        RSSRefreshInterval(rawValue: rawRefreshInterval) ?? .fifteenMinutes
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                group("Appearance") {
                    appearancePicker
                        .padding(12)
                }

                group("Reading") {
                    valueRow(icon: "textformat.size", title: "Reading defaults", value: readingSummary) {
                        showReadingDefaults = true
                    }
                }

                group("Feeds & sync") {
                    valueRow(icon: "arrow.triangle.2.circlepath", title: "Refresh feeds", value: refreshInterval.displayName) {
                        showFeedSync = true
                    }
                }

                group("Account") {
                    if let email, !email.isEmpty {
                        staticRow(icon: "person.crop.circle", title: "Signed in as", value: email)
                        divider
                    }
                    Button {
                        confirmSignOut = true
                    } label: {
                        HStack(spacing: 12) {
                            iconTile("rectangle.portrait.and.arrow.right", tint: Color(hex: "#B42318"))
                            Text("Sign out")
                                .font(Typography.ui(15, weight: .medium))
                                .foregroundColor(Color(hex: "#B42318"))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                group("About") {
                    staticRow(icon: "info.circle", title: "Version", value: appVersion)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, Spacing.scrollBottomInset)
        }
        .background(themeManager.colors.rail.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(themeManager.colors.accent)
        .sheet(isPresented: $showReadingDefaults) {
            ReadingPreferencesView(preferences: $preferencesManager.preferences)
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showFeedSync) {
            RSSSettingsView()
                .environmentObject(themeManager)
        }
        .alert("Sign Out", isPresented: $confirmSignOut) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    private var readingSummary: String {
        "\(preferencesManager.preferences.fontFamily.displayName) · \(preferencesManager.preferences.colorTheme.displayName)"
    }

    // MARK: - Appearance

    private var appearancePicker: some View {
        HStack(spacing: 2) {
            appearanceSegment(.cream, label: "Light", icon: "sun.max")
            appearanceSegment(.dark, label: "Dark", icon: "moon")
            appearanceSegment(.system, label: "System", icon: "circle.lefthalf.filled")
        }
        .padding(3)
        .background(themeManager.colors.surface)
        .clipShape(Capsule())
    }

    private func appearanceSegment(_ theme: ColorTheme, label: String, icon: String) -> some View {
        let isSelected = themeManager.currentTheme == theme
        return Button {
            themeManager.setTheme(theme)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Typography.symbol(13, weight: .semibold))
                Text(label)
                    .font(Typography.ui(14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? themeManager.colors.text : themeManager.colors.muted)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(isSelected ? themeManager.colors.page : Color.clear)
            .clipShape(Capsule())
            .shadow(color: isSelected ? Color(hex: "#16191A").opacity(0.12) : .clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) appearance")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Building blocks

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.sectionLabel)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundColor(themeManager.colors.muted)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content()
            }
            .background(themeManager.colors.card)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(themeManager.colors.line, lineWidth: 1)
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(themeManager.colors.line)
            .frame(height: 1)
            .padding(.leading, 14 + 32 + 12)
    }

    private func iconTile(_ systemImage: String, tint: Color? = nil) -> some View {
        Image(systemName: systemImage)
            .font(Typography.symbol(15, weight: .medium))
            .foregroundColor(tint ?? themeManager.colors.text)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 9).fill(themeManager.colors.surface))
            .accessibilityHidden(true)
    }

    private func valueRow(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconTile(icon)
                Text(title)
                    .font(Typography.ui(15))
                    .foregroundColor(themeManager.colors.text)
                Spacer(minLength: 8)
                Text(value)
                    .font(Typography.ui(14))
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(1)
                Image(systemName: "chevron.forward")
                    .font(Typography.symbol(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func staticRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconTile(icon)
            Text(title)
                .font(Typography.ui(15))
                .foregroundColor(themeManager.colors.text)
            Spacer(minLength: 8)
            Text(value)
                .font(Typography.ui(14))
                .foregroundColor(themeManager.colors.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SettingsView(email: "reader@example.com")
            .environmentObject(ThemeManager.shared)
    }
}
