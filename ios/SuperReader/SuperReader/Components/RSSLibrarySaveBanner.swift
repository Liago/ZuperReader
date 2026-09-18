import SwiftUI

// MARK: - RSS → Library Save Banner
//
// Toast condiviso per il salvataggio degli articoli dei feed in Libreria.
// Stessa capsule già usata dal reader, resa riutilizzabile così che il
// feedback sia identico da action menu (long press) e da bookmark del reader.

struct RSSLibrarySaveBannerModifier: ViewModifier {
    @ObservedObject private var store = RSSLibrarySaveStore.shared
    @EnvironmentObject private var themeManager: ThemeManager

    /// Distanza dal bordo inferiore (una tab bar richiede più margine).
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let banner = store.banner {
                    bannerView(banner)
                        .id(banner.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: banner.id) {
                            guard banner.autoDismiss else { return }
                            try? await Task.sleep(nanoseconds: 2_200_000_000)
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                withAnimation {
                                    store.dismissBanner()
                                }
                            }
                        }
                }
            }
    }

    private func bannerView(_ banner: RSSLibrarySaveStore.Banner) -> some View {
        HStack(spacing: 10) {
            if banner.style == .progress {
                ProgressView()
                    .controlSize(.small)
                    .tint(themeManager.colors.accent)
            }

            Text(banner.message)
                .font(Typography.figtree(14, weight: .semibold))
                .foregroundColor(themeManager.colors.text)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.colors.card)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(banner.style == .error ? themeManager.colors.accent2 : themeManager.colors.line, lineWidth: 1)
        )
        .shadow(color: AppShadows.card.color, radius: 8, x: 0, y: 4)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, bottomPadding)
        // HIG · Accessibility: time-boxed elements need an explicit way out
        // too — tap dismisses, and VoiceOver hears the message as it appears.
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation { store.dismissBanner() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Dismiss") {
            withAnimation { store.dismissBanner() }
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: banner.message)
        }
    }
}

extension View {
    /// Mostra il feedback del salvataggio "Feed → Libreria" in fondo alla schermata.
    func rssLibrarySaveBanner(bottomPadding: CGFloat = 20) -> some View {
        modifier(RSSLibrarySaveBannerModifier(bottomPadding: bottomPadding))
    }
}
