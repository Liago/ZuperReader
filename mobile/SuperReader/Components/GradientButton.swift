import SwiftUI

// MARK: - Gradient Button

struct GradientButton: View {
    let title: String
    let icon: String?
    let gradient: LinearGradient
    let isLoading: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        gradient: LinearGradient = PremiumGradients.primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLoading)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(themeManager.colors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .background(themeManager.colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(themeManager.colors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let size: CGFloat
    let color: Color
    let backgroundColor: Color
    let badge: Int?
    let action: () -> Void
    
    init(
        icon: String,
        size: CGFloat = 20,
        color: Color = .gray,
        backgroundColor: Color = .white.opacity(0.8),
        badge: Int? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        self.backgroundColor = backgroundColor
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                
                if let badge = badge, badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GradientButton(title: "Add Article", icon: "plus") {
            print("Tapped")
        }
        
        GradientButton(title: "Loading...", isLoading: true) {
            print("Tapped")
        }
        
        SecondaryButton(title: "Cancel", icon: "xmark") {
            print("Cancel")
        }
        .environmentObject(ThemeManager.shared)
        
        HStack(spacing: 16) {
            IconButton(icon: "heart", badge: 5) { }
            IconButton(icon: "bell", badge: 12) { }
            IconButton(icon: "person.2") { }
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
