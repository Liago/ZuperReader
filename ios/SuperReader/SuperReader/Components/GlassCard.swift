import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        cornerRadius: CGFloat = CornerRadius.lg,
        padding: CGFloat = Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(themeManager.colors.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(themeManager.colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Simple Card

struct SimpleCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        cornerRadius: CGFloat = CornerRadius.lg,
        padding: CGFloat = Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(themeManager.colors.bgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Card")
                    .font(.headline)
                Text("This is a glassmorphic card with blur effect")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .environmentObject(ThemeManager.shared)
        
        SimpleCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Simple Card")
                    .font(.headline)
                Text("This is a simple card with shadow")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .environmentObject(ThemeManager.shared)
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.purple.opacity(0.1), .blue.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
