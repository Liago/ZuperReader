import SwiftUI

// MARK: - Icon Circle Button
//
// The 38×38 circular icon button used in every screen header and in the
// reader / feed top bars (docs/revamp-ios/README.md · "Spacing, radii,
// elevation"). Built to the HIG rules the raw pattern was missing:
//
// - hit target is at least 44×44 even though the circle stays 38pt;
// - the circle and glyph follow Dynamic Type (`@ScaledMetric`);
// - every instance carries a VoiceOver label, since the glyph alone is mute.

struct IconCircleButton: View {
    enum Style {
        /// `sink` fill, `text` glyph — the default secondary button.
        case sink
        /// `accent` fill, `page` glyph — the screen's primary action.
        case accent
        /// `text` fill, `page` glyph — an active / toggled state.
        case filled
    }

    let systemImage: String
    let label: String
    var style: Style = .sink
    var glyphWeight: Font.Weight = .semibold
    var glyphSize: CGFloat = 15
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var circleSize = Spacing.iconButtonSize

    var body: some View {
        Button(action: action) {
            IconCircleGlyph(
                systemImage: systemImage,
                style: style,
                glyphWeight: glyphWeight,
                glyphSize: glyphSize
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .minimumTapTarget()
        .accessibilityLabel(label)
    }
}

/// The visual part of `IconCircleButton`, reusable as a `Menu` / `NavigationLink`
/// label where a `Button` isn't the container.
struct IconCircleGlyph: View {
    let systemImage: String
    var style: IconCircleButton.Style = .sink
    var glyphWeight: Font.Weight = .semibold
    var glyphSize: CGFloat = 15

    @EnvironmentObject private var themeManager: ThemeManager
    @ScaledMetric(relativeTo: .body) private var circleSize = Spacing.iconButtonSize

    private var foreground: Color {
        switch style {
        case .sink: return themeManager.colors.text
        case .accent, .filled: return themeManager.colors.page
        }
    }

    private var background: Color {
        switch style {
        case .sink: return themeManager.colors.sink
        case .accent: return themeManager.colors.accent
        case .filled: return themeManager.colors.text
        }
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(Typography.symbol(glyphSize, weight: glyphWeight))
            .foregroundColor(foreground)
            .frame(width: circleSize, height: circleSize)
            .background(background)
            .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 12) {
        IconCircleButton(systemImage: "chevron.backward", label: "Back") {}
        IconCircleButton(systemImage: "plus", label: "Add", style: .accent, glyphSize: 18) {}
        IconCircleButton(systemImage: "square.grid.2x2.fill", label: "Grid", style: .filled) {}
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
