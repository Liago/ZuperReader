import SwiftUI
import Supabase
import Auth

// MARK: - You (08)

struct ProfileView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var preferencesManager = ReadingPreferencesManager.shared

    @AppStorage(RSSViewModel.autoRefreshIntervalKey) private var rawRefreshInterval: String = RSSRefreshInterval.fifteenMinutes.rawValue

    @State private var userProfile: UserProfile?
    @State private var stats: UserStatistics = .empty
    @State private var isLoading = false
    @State private var isSigningOut = false
    @State private var showEditProfile = false
    @State private var showReadingDefaults = false
    @State private var showFeedSync = false

    private var refreshInterval: RSSRefreshInterval {
        RSSRefreshInterval(rawValue: rawRefreshInterval) ?? .fifteenMinutes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                if isLoading {
                    ProfileSkeleton()
                        .padding(.top, 80)
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.xl) {
                            profileHeader
                            statsRow
                            appearanceControl
                            settingsList

                            Text("Version 1.0.0")
                                .font(Typography.figtree(12.5))
                                .foregroundColor(themeManager.colors.muted)
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.profileTop)
                        .padding(.bottom, Spacing.scrollBottomInset)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadProfile() }
            .refreshable { await loadProfile() }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(currentProfile: userProfile) {
                    Task { await loadProfile() }
                }
                .environmentObject(themeManager)
            }
            .sheet(isPresented: $showReadingDefaults) {
                ReadingPreferencesView(preferences: $preferencesManager.preferences)
                    .environmentObject(themeManager)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showFeedSync) {
                RSSSettingsView()
                    .environmentObject(themeManager)
            }
            .alert("Sign Out", isPresented: $isSigningOut) {
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
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.accent)

                if let avatarUrl = userProfile?.avatarUrl {
                    AsyncImageView(url: avatarUrl, cornerRadius: 36)
                        .aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                } else {
                    Text(userProfile?.initials ?? "??")
                        .font(Typography.caprasimo(26))
                        .foregroundColor(themeManager.colors.page)
                }
            }
            .frame(width: 72, height: 72)

            VStack(spacing: 4) {
                Text(userProfile?.displayName ?? "Reader")
                    .font(Typography.caprasimo(24))
                    .foregroundColor(themeManager.colors.text)

                Text(userProfile?.email ?? "")
                    .font(Typography.figtree(13.5))
                    .foregroundColor(themeManager.colors.muted)
            }

            Button(action: { showEditProfile = true }) {
                Text("Edit profile")
                    .font(Typography.figtree(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule().stroke(themeManager.colors.line, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(value: stats.totalArticles, label: "Saved")
            statDivider
            statColumn(value: stats.readArticles, label: "Read")
            statDivider
            statColumn(value: stats.sharedArticlesCount, label: "Shared")
            statDivider
            statColumn(value: stats.friendsCount, label: "Friends")
        }
        .padding(.vertical, 18)
        .overlay(hairline, alignment: .top)
        .overlay(hairline, alignment: .bottom)
    }

    private var statDivider: some View {
        Rectangle().fill(themeManager.colors.line).frame(width: 1)
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(Typography.statNumber)
                .foregroundColor(themeManager.colors.text)
            Text(label)
                .font(Typography.figtree(11.5, weight: .heavy))
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Appearance

    private var appearanceControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(Typography.sectionLabel)
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)

            HStack(spacing: 10) {
                appearanceSwatch(.cream, label: "Cream")
                appearanceSwatch(.dark, label: "Dark")
                appearanceSwatch(.system, label: "System")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appearanceSwatch(_ theme: ColorTheme, label: String) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let swatchColors = theme == .system ? themeManager.colors : theme.colors
        return Button(action: { themeManager.setTheme(theme) }) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(swatchColors.page)
                    .frame(height: 76)
                Text(label)
                    .font(Typography.figtree(12, weight: .bold))
                    .foregroundColor(swatchColors.text)
                    .padding(10)
            }
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(themeManager.colors.line, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .inset(by: 2)
                    .stroke(themeManager.colors.accent, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings List

    private var settingsList: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "textformat.size", title: "Reading defaults") {
                showReadingDefaults = true
            }
            hairline
            settingsRow(icon: "arrow.triangle.2.circlepath", title: "Feed sync", value: refreshInterval.displayName) {
                showFeedSync = true
            }
            hairline
            settingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out", tint: themeManager.colors.accent800) {
                isSigningOut = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow(
        icon: String,
        title: String,
        value: String? = nil,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(tint ?? themeManager.colors.text.opacity(0.65))
                    .frame(width: 24)

                Text(title)
                    .font(Typography.figtree(15))
                    .foregroundColor(tint ?? themeManager.colors.text)

                Spacer()

                if let value {
                    Text(value)
                        .font(Typography.figtree(14))
                        .foregroundColor(themeManager.colors.muted)
                }

                if tint == nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.colors.muted)
                }
            }
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
    }

    private var hairline: some View {
        Rectangle().fill(themeManager.colors.line).frame(height: 1)
    }

    // MARK: - Actions

    private func loadProfile() async {
        guard let userId = authManager.user?.id.uuidString else { return }

        isLoading = true

        do {
            async let profileTask = SupabaseService.shared.getUserProfile(userId: userId)
            async let statsTask = SupabaseService.shared.getUserStatistics(userId: userId)

            let (profile, statistics) = try await (profileTask, statsTask)

            self.userProfile = profile
            self.stats = statistics
        } catch {
            print("Failed to load profile: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    let currentProfile: UserProfile?
    let onSave: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Public Info")) {
                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .disabled(isLoading || displayName.isEmpty)
                }
            }
            .onAppear {
                if let profile = currentProfile {
                    displayName = profile.displayName ?? ""
                    bio = profile.bio ?? ""
                }
            }
        }
    }

    private func saveProfile() async {
        guard let userId = currentProfile?.id else { return }

        isLoading = true

        do {
            _ = try await SupabaseService.shared.updateUserProfile(
                userId: userId,
                displayName: displayName,
                bio: bio
            )
            onSave()
            dismiss()
        } catch {
            print("Failed to update profile: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(ThemeManager.shared)
}
