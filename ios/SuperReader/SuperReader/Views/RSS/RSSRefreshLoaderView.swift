import SwiftUI

// MARK: - Feeds Refresh Loader
//
// Modale di attesa del refresh: mostra quante fonti sono coinvolte e quali
// stanno venendo scansionate. Sul parser on-device il progresso è reale fonte
// per fonte; sul refresh server-side (singola richiesta) mostriamo l'elenco
// delle fonti coinvolte con barra indeterminata.

struct RSSRefreshLoaderView: View {
    @ObservedObject var viewModel: RSSViewModel
    @EnvironmentObject var themeManager: ThemeManager

    /// Anima la barra indeterminata quando non abbiamo progresso per fonte.
    @State private var animateBar = false

    private let listMaxHeight: CGFloat = 168

    var body: some View {
        if viewModel.isRefreshing {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 18) {
                    header

                    progressBar
                        .frame(height: 8)

                    if !viewModel.scanItems.isEmpty {
                        sourceList
                    }

                    Text(viewModel.refreshProgress ?? "Retrieving latest articles...")
                        .font(Typography.figtree(12.5))
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(themeManager.colors.accent)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(Typography.symbol(24, weight: .bold))
                        .foregroundColor(themeManager.colors.page)
                        .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                        .animation(
                            viewModel.isRefreshing
                                ? Animation.linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: viewModel.isRefreshing
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Updating feeds")
                    .font(Typography.figtree(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)

                Text(countLabel)
                    .font(Typography.meta)
                    .foregroundColor(themeManager.colors.muted)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: viewModel.processedFeedsCount)
            }

            Spacer(minLength: 0)
        }
    }

    /// "3 of 12 sources" quando il progresso è reale, "12 sources" altrimenti.
    private var countLabel: String {
        let total = viewModel.totalFeedsCount
        guard total > 0 else { return "Retrieving latest articles" }

        let noun = total == 1 ? "source" : "sources"
        if viewModel.hasDeterminateProgress {
            return "\(viewModel.processedFeedsCount) of \(total) \(noun)"
        }
        return "\(total) \(noun)"
    }

    // MARK: - Progress bar

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(themeManager.colors.sink)
                    .frame(height: 8)

                if viewModel.hasDeterminateProgress {
                    Capsule()
                        .fill(themeManager.colors.accent)
                        .frame(width: max(8, barWidth * viewModel.progressPercentage), height: 8)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.progressPercentage)
                } else {
                    let segment = barWidth * 0.4
                    Capsule()
                        .fill(themeManager.colors.accent)
                        .frame(width: segment, height: 8)
                        .offset(x: animateBar ? barWidth : -segment)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: animateBar)
                }
            }
            .clipShape(Capsule())
        }
    }

    // MARK: - Sources

    private var sourceList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.scanItems) { item in
                        sourceRow(item)
                            .id(item.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: listMaxHeight)
            .onChange(of: viewModel.processedFeedsCount) { _, _ in
                guard let target = activeItemId else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    /// Prima fonte non ancora completata: è quella da tenere in vista.
    private var activeItemId: UUID? {
        viewModel.scanItems.first(where: { $0.state == .scanning })?.id
            ?? viewModel.scanItems.first(where: { $0.state == .pending })?.id
    }

    private func sourceRow(_ item: RSSViewModel.FeedScanItem) -> some View {
        HStack(spacing: 10) {
            stateGlyph(item.state)
                .frame(width: 16, height: 16)

            Text(item.title)
                .font(Typography.figtree(13, weight: item.state == .scanning ? .semibold : .regular))
                .foregroundColor(titleColor(for: item.state))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: item.state)
    }

    @ViewBuilder
    private func stateGlyph(_ state: RSSViewModel.FeedScanItem.State) -> some View {
        switch state {
        case .pending:
            Circle()
                .stroke(themeManager.colors.muted.opacity(0.4), lineWidth: 1.5)
                .frame(width: 8, height: 8)
        case .scanning:
            ProgressView()
                .controlSize(.mini)
                .tint(themeManager.colors.accent)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.symbol(13, weight: .bold))
                .foregroundColor(themeManager.colors.accent)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Typography.symbol(12, weight: .bold))
                .foregroundColor(themeManager.colors.accent2)
        }
    }

    private func titleColor(for state: RSSViewModel.FeedScanItem.State) -> Color {
        switch state {
        case .pending:
            return themeManager.colors.muted
        case .scanning, .done:
            return themeManager.colors.text
        case .failed:
            return themeManager.colors.muted
        }
    }
}
