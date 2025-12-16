import SwiftUI

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.purple)
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.purple.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .offset(y: bounceAnimation(index: index))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @State private var animating = false
    
    private func bounceAnimation(index: Int) -> CGFloat {
        withAnimation(
            .easeInOut(duration: 0.4)
            .repeatForever()
            .delay(Double(index) * 0.15)
        ) {
            animating ? -8 : 0
        }
        return 0
    }
}

// MARK: - Animated Loading Dots

struct AnimatedLoadingDots: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(gradientColors[index])
                    .frame(width: 10, height: 10)
                    .offset(y: animationPhase == index ? -10 : 0)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private var gradientColors: [Color] {
        [Color(hex: "#9333EA"), Color(hex: "#EC4899"), Color(hex: "#3B82F6")]
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Full Screen Loading

struct FullScreenLoadingView: View {
    let message: String
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.colors.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(
                            Color.purple.opacity(0.2),
                            lineWidth: 4
                        )
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            PremiumGradients.primary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(
                            .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                            value: UUID()
                        )
                }
                
                Text(message)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                AnimatedLoadingDots()
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingView("Loading articles...")
        
        AnimatedLoadingDots()
        
        FullScreenLoadingView(message: "Signing in...")
            .frame(height: 300)
    }
    .environmentObject(ThemeManager.shared)
}
