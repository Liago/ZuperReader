import SwiftUI

struct RSSRefreshLoaderView: View {
    @ObservedObject var viewModel: RSSViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if viewModel.isRefreshing {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 20) {
                    // Header with Icon and Percentage
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                                    .animation(viewModel.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Updating RSS feeds")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.textPrimary)
                            
                            Text("\(viewModel.processedFeedsCount) of \(viewModel.totalFeedsCount) feeds processed")
                                .font(.subheadline)
                                .foregroundColor(themeManager.colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.progressPercentage * 100))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, min(geometry.size.width * CGFloat(viewModel.progressPercentage), geometry.size.width)), height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.progressPercentage)
                        }
                    }
                    .frame(height: 8)
                    
                    // Status
                    VStack(spacing: 8) {
                        Text(viewModel.refreshProgress ?? "Retrieving latest articles...")
                            .font(.caption)
                            .foregroundColor(themeManager.colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Text("You can continue reading while we update")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .background(themeManager.colors.bgPrimary)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
            }
            .zIndex(100)
        }
    }
}
