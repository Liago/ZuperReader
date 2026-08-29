import SwiftUI

struct RSSRefreshLoaderView: View {
    @ObservedObject var viewModel: RSSViewModel
    @EnvironmentObject var themeManager: ThemeManager

    // Drives the indeterminate progress bar sweep. Real per-feed progress isn't
    // available because the refresh runs as a single server-side request.
    @State private var animateBar = false

    var body: some View {
        if viewModel.isRefreshing {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    // Header with Icon and Title
                    HStack(spacing: 16) {
                        Circle()
                            .fill(themeManager.colors.accent)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(themeManager.colors.page)
                                    .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                                    .animation(viewModel.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                            )

                        Text("Updating feeds")
                            .font(Typography.figtree(15, weight: .semibold))
                            .foregroundColor(themeManager.colors.text)

                        Spacer()
                    }

                    // Indeterminate Progress Bar (server-side refresh has no granular progress)
                    GeometryReader { geometry in
                        let barWidth = geometry.size.width
                        let segment = barWidth * 0.4
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(themeManager.colors.sink)
                                .frame(height: 8)

                            Capsule()
                                .fill(themeManager.colors.accent)
                                .frame(width: segment, height: 8)
                                .offset(x: animateBar ? barWidth : -segment)
                                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: animateBar)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)

                    // Status
                    Text(viewModel.refreshProgress ?? "Retrieving latest articles...")
                        .font(Typography.figtree(12.5))
                        .foregroundColor(themeManager.colors.muted)
                        .multilineTextAlignment(.center)
                }
                .onAppear { animateBar = true }
                .onDisappear { animateBar = false }
                .padding(24)
                .background(themeManager.colors.card)
                .cornerRadius(CornerRadius.card)
                .shadow(
                    color: AppShadows.floatingBar.color,
                    radius: AppShadows.floatingBar.radius,
                    x: AppShadows.floatingBar.x,
                    y: AppShadows.floatingBar.y
                )
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
            }
            .zIndex(100)
        }
    }
}
