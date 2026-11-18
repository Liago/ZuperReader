import SwiftUI
import Supabase
import Auth

// MARK: - You
//
// Editorial Teal (design canvas · "07 · Profilo"): large title with the
// Settings gear, identity row (avatar, name, email, friends), Edit profile,
// a "Your reading" card with the library stats and a menu of icon rows.
// Appearance, feed sync and sign out live in `SettingsView`.

struct ProfileView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var preferencesManager = ReadingPreferencesManager.shared

    @AppStorage(RSSViewModel.autoRefreshIntervalKey) private var rawRefreshInterval: String = RSSRefreshInterval.fifteenMinutes.rawValue

    @State private var userProfile: UserProfile?
    @State private var stats: UserStatistics = .empty
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showReadingDefaults = false
    @State private var showFeedSync = false
    @State private var showPublicLinks = false

    private var refreshInterval: RSSRefreshInterval {
        RSSRefreshInterval(rawValue: rawRefreshInterval) ?? .fifteenMinutes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.page
                    .ignoresSafeArea()

                if isLoading && userProfile == nil {
                    ProfileSkeleton()
                        .padding(.top, 80)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            header
                            identityRow
                            editProfileButton
                            readingCard
                            menu
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.contentTop)
                        .padding(.bottom, Spacing.scrollBottomInset)
                    }
                    .refreshable { await loadProfile() }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadProfile() }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(currentProfile: userProfile) {
                    Task { await loadProfile() }
                }
                .environmentObject(themeManager)
            }
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
            .sheet(isPresented: $showPublicLinks) {
                PublicLinksView()
                    .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("You")
                .font(Typography.largeTitle)
                .foregroundColor(themeManager.colors.text)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            NavigationLink(destination: SettingsView(email: userProfile?.email ?? authManager.user?.email)) {
                IconCircleGlyph(systemImage: "gearshape", style: .outline, glyphSize: 18)
            }
            .buttonStyle(ScaleButtonStyle())
            .minimumTapTarget()
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Identity

    private var identityRow: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.accent200)

                if let avatarUrl = userProfile?.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImageView(url: avatarUrl, cornerRadius: 36)
                        .aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                } else {
                    Text(userProfile?.initials ?? "??")
                        .font(Typography.display(24, weight: .heavy, relativeTo: .title2))
                        .foregroundColor(themeManager.colors.accent700)
                }
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(userProfile?.displayName ?? "Reader")
                    .font(Typography.display(20, weight: .bold, relativeTo: .title3))
                    .foregroundColor(themeManager.colors.text)
                    .lineLimit(1)

                if let email = userProfile?.email, !email.isEmpty {
                    Text(email)
                        .font(Typography.ui(13.5, relativeTo: .footnote))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 4) {
                    Text("\(stats.friendsCount)")
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.colors.text)
                    Text(stats.friendsCount == 1 ? "friend" : "friends")
                        .foregroundColor(themeManager.colors.muted)
                }
                .font(Typography.ui(13, relativeTo: .footnote))
                .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var editProfileButton: some View {
        Button(action: { showEditProfile = true }) {
            Text("Edit profile")
                .font(Typography.ui(14.5, weight: .semibold))
                .foregroundColor(themeManager.colors.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Your reading

    private var readingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your reading")
                    .font(Typography.ui(15, weight: .bold))
                    .foregroundColor(themeManager.colors.text)
                Spacer()
                if stats.totalArticles > 0 {
                    Text("\(readPercent)% read")
                        .font(Typography.ui(12.5, relativeTo: .caption))
                        .foregroundColor(themeManager.colors.muted)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 14) {
                statCell(stats.totalArticles, label: "Saved")
                statCell(stats.readArticles, label: "Read")
                statCell(stats.favoriteArticles, label: "Favorites")
                statCell(stats.sharedArticlesCount, label: "Shared")
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(themeManager.colors.accent200)
                    Capsule()
                        .fill(themeManager.colors.accent)
                        .frame(width: geometry.size.width * CGFloat(readPercent) / 100)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Library read")
            .accessibilityValue("\(readPercent) percent")
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(themeManager.colors.line, lineWidth: 1)
        )
    }

    private var readPercent: Int {
        guard stats.totalArticles > 0 else { return 0 }
        return min(100, Int((Double(stats.readArticles) / Double(stats.totalArticles) * 100).rounded()))
    }

    private func statCell(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(Typography.statNumber)
                .foregroundColor(themeManager.colors.text)
                .contentTransition(.numericText())
            Text(label)
                .font(Typography.ui(12, relativeTo: .caption))
                .foregroundColor(themeManager.colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            menuRow(icon: "link", title: "Public links") {
                showPublicLinks = true
            }
            hairline
            menuRow(icon: "textformat.size", title: "Reading preferences", value: preferencesManager.preferences.fontFamily.displayName) {
                showReadingDefaults = true
            }
            hairline
            menuRow(icon: "arrow.triangle.2.circlepath", title: "Feed sync", value: refreshInterval.displayName) {
                showFeedSync = true
            }
            hairline
            NavigationLink(destination: SettingsView(email: userProfile?.email ?? authManager.user?.email)) {
                menuRowLabel(icon: "gearshape", title: "Settings", value: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func menuRow(icon: String, title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            menuRowLabel(icon: icon, title: title, value: value)
        }
        .buttonStyle(.plain)
    }

    private func menuRowLabel(icon: String, title: String, value: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(Typography.symbol(16, weight: .medium))
                .foregroundColor(themeManager.colors.text)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.colors.surface))
                .accessibilityHidden(true)

            Text(title)
                .font(Typography.ui(15.5, weight: .medium))
                .foregroundColor(themeManager.colors.text)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(Typography.ui(14))
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.forward")
                .font(Typography.symbol(13, weight: .semibold))
                .foregroundColor(themeManager.colors.muted)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var hairline: some View {
        Rectangle()
            .fill(themeManager.colors.line)
            .frame(height: 1)
            .padding(.leading, 36 + 14)
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
