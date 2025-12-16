import SwiftUI

// MARK: - Skeleton View

struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isAnimating = false
    
    init(
        width: CGFloat? = nil,
        height: CGFloat = 20,
        cornerRadius: CGFloat = CornerRadius.sm
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0),
                            Color.white.opacity(0.3),
                            Color.gray.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: isAnimating ? geometry.size.width * 1.5 : -geometry.size.width * 0.5)
                }
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius)
                )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Article Card Skeleton

struct ArticleCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Image placeholder
            SkeletonView(height: 150, cornerRadius: CornerRadius.md)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Domain
                SkeletonView(width: 80, height: 14)
                
                // Title
                SkeletonView(height: 18)
                SkeletonView(width: 200, height: 18)
                
                // Excerpt
                SkeletonView(height: 14)
                SkeletonView(width: 180, height: 14)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Article Row Skeleton

struct ArticleRowSkeleton: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            SkeletonView(width: 80, height: 80, cornerRadius: CornerRadius.md)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title
                SkeletonView(height: 16)
                SkeletonView(width: 150, height: 16)
                
                Spacer()
                
                // Meta info
                HStack(spacing: Spacing.sm) {
                    SkeletonView(width: 60, height: 12)
                    SkeletonView(width: 80, height: 12)
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Profile Skeleton

struct ProfileSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Avatar
            SkeletonView(width: 100, height: 100, cornerRadius: 50)
            
            // Name
            SkeletonView(width: 150, height: 24)
            
            // Email
            SkeletonView(width: 200, height: 16)
            
            // Stats
            HStack(spacing: Spacing.lg) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: Spacing.xs) {
                        SkeletonView(width: 40, height: 28)
                        SkeletonView(width: 60, height: 14)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SkeletonView(width: 200, height: 20)
        
        ArticleCardSkeleton()
            .frame(width: 280)
        
        ArticleRowSkeleton()
        
        ProfileSkeleton()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
