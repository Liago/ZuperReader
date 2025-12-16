import SwiftUI
import Supabase


// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    
    @State private var userProfile: UserProfile?
    @State private var stats: UserStatistics = .empty
    @State private var isLoading = false
    @State private var isSigningOut = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if isLoading {
                            ProfileSkeleton()
                                .padding(.top, 40)
                        } else {
                            // Profile Header
                            profileHeader
                            
                            // Stats Grid
                            statsGrid
                            
                            // Menu Options
                            menuOptions
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadProfile()
            }
            .refreshable {
                await loadProfile()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(currentProfile: userProfile) {
                    Task { await loadProfile() }
                }
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
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    imageUrl: userProfile?.avatarUrl,
                    initials: userProfile?.initials ?? "??",
                    size: 100,
                    gradient: PremiumGradients.primary
                )
                
                Button(action: { showEditProfile = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .offset(x: 0, y: 0)
            }
            
            VStack(spacing: Spacing.xs) {
                Text(userProfile?.displayName ?? "Reader")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text(userProfile?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(themeManager.colors.textSecondary)
                
                if let bio = userProfile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(themeManager.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        VStack(spacing: Spacing.md) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                StatCard(
                    title: "Articles",
                    value: "\(stats.totalArticles)",
                    icon: "doc.text.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Read",
                    value: "\(stats.readArticles)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Friends",
                    value: "\(stats.friendsCount)",
                    icon: "person.2.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Likes",
                    value: "\(stats.totalLikesReceived)",
                    icon: "heart.fill",
                    color: .pink
                )
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Menu Options
    
    private var menuOptions: some View {
        VStack(spacing: Spacing.md) {
            // Sign Out Button
            Button(action: { isSigningOut = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                    Spacer()
                }
                .foregroundColor(.red)
                .padding()
                .background(themeManager.colors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(themeManager.colors.textSecondary)
                .padding(.top)
        }
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

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(themeManager.colors.textPrimary)
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(themeManager.colors.textSecondary)
        }
        .padding()
        .background(themeManager.colors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
