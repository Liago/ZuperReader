import SwiftUI

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glassmorphism

extension View {
    func glassmorphism(
        cornerRadius: CGFloat = CornerRadius.lg,
        opacity: Double = 0.8,
        blur: CGFloat = 10
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    func premiumCard(theme: ThemeColors) -> some View {
        self
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + phase * geometry.size.width * 3)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 1.5)
                                .repeatForever(autoreverses: false)
                            ) {
                                phase = 1
                            }
                        }
                    }
                }
                .mask(content)
            )
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Hide Keyboard

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Reading Indicator

extension View {
    func readingProgressBar(_ progress: Double, color: Color = .purple) -> some View {
        self.overlay(alignment: .top) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(.easeOut(duration: 0.1), value: progress)
            }
            .frame(height: 3)
        }
    }
}
