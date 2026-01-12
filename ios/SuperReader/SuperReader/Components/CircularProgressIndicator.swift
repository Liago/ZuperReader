import SwiftUI

// MARK: - Circular Progress Indicator

/// A circular/radial progress indicator that displays reading progress as a percentage.
/// Matches the web ReadingProgressIndicator component design.
struct CircularProgressIndicator: View {
    let progress: Double // 0.0 to 1.0
    var size: CGFloat = 60
    var strokeWidth: CGFloat = 4
    
    // Gradient colors matching web version (purple to pink)
    private var gradientColors: [Color] {
        [
            Color(hex: "9333ea"), // Purple
            Color(hex: "db2777"), // Pink
            Color(hex: "ec4899")  // Light Pink
        ]
    }
    
    private var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        ZStack {
            // White background with shadow
            Circle()
                .fill(Color.white)
                .frame(width: size + 8, height: size + 8)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            // Background track
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: strokeWidth
                )
                .frame(width: size, height: size)
            
            // Progress arc with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
            
            // Percentage text
            Text("\(progressPercentage)%")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundColor(.gray)
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CircularProgressIndicator(progress: 0.0)
        CircularProgressIndicator(progress: 0.25)
        CircularProgressIndicator(progress: 0.5)
        CircularProgressIndicator(progress: 0.75)
        CircularProgressIndicator(progress: 1.0)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
