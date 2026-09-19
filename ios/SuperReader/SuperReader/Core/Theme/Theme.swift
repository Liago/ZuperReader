import SwiftUI

// MARK: - Color Theme

enum ColorTheme: String, CaseIterable, Codable {
    case cream
    case sepia
    case dark
    case system

    var displayName: String {
        switch self {
        case .cream: return "Cream"
        case .sepia: return "Sepia"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var iconName: String {
        switch self {
        case .cream: return "sun.max.fill"
        case .sepia: return "book.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    func resolvedTheme(for colorScheme: ColorScheme) -> ColorTheme {
        if self == .system {
            return colorScheme == .dark ? .dark : .cream
        }
        return self
    }

    var colors: ThemeColors {
        switch self {
        case .system:
            return ColorTheme.cream.colors
        case .cream:
            return ThemeColors(
                page: Color(hex: "#F5EAD8"),
                rail: Color(hex: "#EFE2CA"),
                card: Color(hex: "#FFFAF1"),
                surface: Color(hex: "#FFFAF1"),
                text: Color(hex: "#201E1D"),
                // 64% (not the spec's 58%) — the lowest opacity at which muted
                // meta text clears WCAG AA 4.5:1 on `page` (HIG · Accessibility).
                muted: Color(hex: "#201E1D").opacity(0.64),
                line: Color(hex: "#201E1D").opacity(0.12),
                sink: Color(hex: "#201E1D").opacity(0.045),
                accent: Color(hex: "#C67139"),
                accent200: Color(hex: "#F0CBA9"),
                accent700: Color(hex: "#8A4B22"),
                accent800: Color(hex: "#6B3A19"),
                accent2: Color(hex: "#7A8A5E"),
                accent2_200: Color(hex: "#D6DDC5"),
                accent2_800: Color(hex: "#3D472B")
            )
        case .sepia:
            // Only page / text / accent are specified for the reader-only Sepia
            // palette (docs/revamp-ios/README.md); the surrounding surfaces are
            // interpolated to match Cream's structure since Sepia is also a
            // selectable app-wide ColorTheme case, not just a reader overlay.
            return ThemeColors(
                page: Color(hex: "#EFE0C4"),
                rail: Color(hex: "#E6D3AC"),
                card: Color(hex: "#F7ECD3"),
                surface: Color(hex: "#F7ECD3"),
                text: Color(hex: "#3A2F1F"),
                // 72% — Sepia's page is darker, so muted needs more ink to
                // reach 4.5:1.
                muted: Color(hex: "#3A2F1F").opacity(0.72),
                line: Color(hex: "#3A2F1F").opacity(0.12),
                sink: Color(hex: "#3A2F1F").opacity(0.045),
                accent: Color(hex: "#C67139"),
                accent200: Color(hex: "#F0CBA9"),
                accent700: Color(hex: "#8A4B22"),
                accent800: Color(hex: "#6B3A19"),
                accent2: Color(hex: "#7A8A5E"),
                accent2_200: Color(hex: "#D6DDC5"),
                accent2_800: Color(hex: "#3D472B")
            )
        case .dark:
            return ThemeColors(
                page: Color(hex: "#23201C"),
                rail: Color(hex: "#1C1A17"),
                card: Color(hex: "#2B2823"),
                surface: Color(hex: "#332F28"),
                text: Color(hex: "#F3EBDF"),
                muted: Color(hex: "#F3EBDF").opacity(0.60),
                line: Color(hex: "#F3EBDF").opacity(0.14),
                sink: Color(hex: "#F3EBDF").opacity(0.05),
                accent: Color(hex: "#E2975F"),
                // Ramp steps beyond accent/accent-2 aren't specified for Dark;
                // Cream's steps are reused as the closest approximation.
                accent200: Color(hex: "#F0CBA9"),
                accent700: Color(hex: "#8A4B22"),
                accent800: Color(hex: "#6B3A19"),
                accent2: Color(hex: "#A9BD8C"),
                accent2_200: Color(hex: "#D6DDC5"),
                accent2_800: Color(hex: "#3D472B")
            )
        }
    }
}

// MARK: - Theme Colors

/// Semantic color tokens for the Organic design system
/// (docs/revamp-ios/README.md · "Design tokens").
struct ThemeColors {
    let page: Color
    let rail: Color
    let card: Color
    let surface: Color
    let text: Color
    let muted: Color
    let line: Color
    let sink: Color
    let accent: Color
    let accent200: Color
    let accent700: Color
    let accent800: Color
    let accent2: Color
    let accent2_200: Color
    /// Ramp step used for text sitting on an `accent2_200` fill (channel
    /// monograms): #3D472B, 8.6:1 on #D6DDC5 in both palettes.
    let accent2_800: Color

    // MARK: Compatibility bridge
    // Pre-revamp screens still read these names; they map onto the Organic
    // tokens above and can be dropped once every screen is migrated.
    var bgPrimary: Color { page }
    var bgSecondary: Color { rail }
    var bgGradientFrom: Color { page }
    var bgGradientVia: Color { page }
    var bgGradientTo: Color { page }
    var textPrimary: Color { text }
    var textSecondary: Color { muted }
    var border: Color { line }
    var cardBg: Color { card }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientFrom, bgGradientVia, bgGradientTo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Increase Contrast

    /// Variant served when the system "Increase Contrast" setting is on
    /// (HIG · Color: custom colors need "an increased contrast option for each
    /// variant"). Muted text and hairlines get more ink, and the terracotta
    /// accent — 3:1 against `page` in the light palettes — steps down the ramp
    /// to accent-700 (5.7:1) so accent-filled buttons and accent text clear
    /// WCAG AA. The dark palette lifts the accent instead.
    func increasedContrast(isDark: Bool) -> ThemeColors {
        ThemeColors(
            page: page,
            rail: rail,
            card: card,
            surface: surface,
            text: text,
            muted: text.opacity(0.82),
            line: text.opacity(0.32),
            sink: text.opacity(0.08),
            accent: isDark ? Color(hex: "#F0B584") : accent700,
            accent200: accent200,
            accent700: isDark ? Color(hex: "#F0B584") : accent800,
            accent800: accent800,
            accent2: isDark ? Color(hex: "#C5D6A8") : Color(hex: "#55643E"),
            accent2_200: accent2_200,
            accent2_800: accent2_800
        )
    }
}

// MARK: - Premium Gradients

// Colors only — the purple/pink/blue gradient language is gone, replaced by
// the single warm Organic palette. Names are kept so existing call sites
// don't need to change yet; they'll be renamed to solid Organic fills as
// each screen is migrated.
struct PremiumGradients {
    static let primary = LinearGradient(
        colors: [Color(hex: "#C67139"), Color(hex: "#8A4B22")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purple = LinearGradient(
        colors: [Color(hex: "#7A8A5E"), Color(hex: "#5F6E47")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pink = LinearGradient(
        colors: [Color(hex: "#F0CBA9"), Color(hex: "#C67139")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let indigo = LinearGradient(
        colors: [Color(hex: "#D6DDC5"), Color(hex: "#7A8A5E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography

struct Typography {
    // MARK: Reader body font (user-selectable)

    enum FontFamily: String, CaseIterable, Codable {
        case lora
        case literata
        case merriweather
        case figtree
        case atkinson
        case nunito
        case mono

        var displayName: String {
            switch self {
            case .lora: return "Lora"
            case .literata: return "Literata"
            case .merriweather: return "Merriweather"
            case .figtree: return "Figtree"
            case .atkinson: return "Atkinson"
            case .nunito: return "Nunito"
            case .mono: return "Mono"
            }
        }

        /// PostScript name of the Regular cut bundled in Resources/Fonts
        /// (nil for the system monospaced face).
        var regularFontName: String? {
            switch self {
            case .lora: return "Lora-Regular"
            case .literata: return "Literata-Regular"
            case .merriweather: return "Merriweather-Regular"
            case .figtree: return "Figtree-Regular"
            case .atkinson: return "AtkinsonHyperlegible-Regular"
            case .nunito: return "Nunito-Regular"
            case .mono: return nil
            }
        }

        var font: Font { font(size: 17) }

        func font(size: CGFloat) -> Font {
            guard let name = regularFontName else {
                // No named face to hand to `.custom(_:size:relativeTo:)`, so
                // scale the point size through UIFontMetrics instead.
                let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
                return .system(size: scaled, design: .monospaced)
            }
            return .custom(name, size: size, relativeTo: .body)
        }

        /// Maps legacy stored raw values (sans, serif, mono, inter, poppins,
        /// montserrat, crimsonText, roboto, lato, openSans, ubuntu) onto the
        /// bundled families, per docs/revamp-ios/README.md · "State".
        static func migrated(from legacyRawValue: String) -> FontFamily {
            switch legacyRawValue {
            case "mono":
                return .mono
            case "serif", "lora", "crimsonText":
                return .lora
            default:
                return .figtree
            }
        }
    }

    // MARK: Line Height

    enum LineHeight: String, CaseIterable, Codable {
        case tight
        case comfortable
        case loose

        var displayName: String {
            switch self {
            case .tight: return "Tight"
            case .comfortable: return "Comfortable"
            case .loose: return "Loose"
            }
        }

        var multiplier: CGFloat {
            switch self {
            case .tight: return 1.3
            case .comfortable: return 1.72
            case .loose: return 2.0
            }
        }

        /// Maps legacy stored raw values (compact, normal, relaxed) onto the
        /// reduced three-value set — "loose" already matches directly — per
        /// docs/revamp-ios/README.md · "05 Reading preferences sheet".
        static func migrated(from legacyRawValue: String) -> LineHeight {
            switch legacyRawValue {
            case "compact": return .tight
            case "loose": return .loose
            default: return .comfortable
            }
        }
    }

    // MARK: Content Width

    enum ContentWidth: String, CaseIterable, Codable {
        case narrow
        case normal
        case wide

        var displayName: String {
            rawValue.capitalized
        }

        var maxWidth: CGFloat {
            switch self {
            case .narrow: return 600
            case .normal: return 800
            case .wide: return 1000
            }
        }
    }

    // MARK: Display (Caprasimo) / UI (Figtree) type ramp
    //
    // Figtree-* (Regular…Black) are bundled in Resources/Fonts. Caprasimo
    // falls back to the system font automatically until Caprasimo-Regular is
    // bundled too (see docs/revamp-ios/README.md · "Assets").

    /// Display face. `relativeTo` ties the size to a Dynamic Type text style so
    /// the ramp follows the user's text-size setting (HIG · Designing for iOS:
    /// "adapt seamlessly to … Dynamic Type").
    static func caprasimo(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Caprasimo-Regular", size: size, relativeTo: style)
    }

    static func figtree(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        let name: String
        switch weight {
        case .black: name = "Figtree-Black"
        case .heavy: name = "Figtree-ExtraBold"
        case .bold: name = "Figtree-Bold"
        case .semibold: name = "Figtree-SemiBold"
        case .medium: name = "Figtree-Medium"
        default: name = "Figtree-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    /// Dynamic Type–aware replacement for `.system(size:weight:)` on SF Symbols
    /// and system text. Fixed point sizes never scale; this maps the design
    /// size onto the closest system text style, which does.
    static func symbol(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let style: Font.TextStyle
        switch size {
        case ..<11.5: style = .caption2
        case ..<12.5: style = .caption
        case ..<14: style = .footnote
        case ..<15.5: style = .subheadline
        case ..<16.5: style = .callout
        case ..<19: style = .body
        case ..<21: style = .title3
        case ..<25: style = .title2
        case ..<31: style = .title
        default: style = .largeTitle
        }
        return .system(style, design: design, weight: weight)
    }

    /// Screen title — Library / Feeds / People / You headers.
    static let largeTitle = caprasimo(34, relativeTo: .largeTitle)
    /// Reader article title.
    static let articleTitle = caprasimo(31, relativeTo: .largeTitle)
    /// Library grid card title.
    static let cardTitle = caprasimo(20, relativeTo: .title3)
    /// Reading preferences / Save-a-link sheet titles.
    static let sheetTitle = caprasimo(22, relativeTo: .title2)
    /// "You" screen stat numbers.
    static let statNumber = caprasimo(24, relativeTo: .title2)
    /// Feed channel header title (06b).
    static let channelTitle = caprasimo(21, relativeTo: .title2)
    /// Initial inside a 40pt channel monogram.
    static let channelMonogram = caprasimo(17, relativeTo: .body)
    /// Featured (hero) article title in a channel / Library list.
    static let featuredTitle = figtree(19, weight: .heavy, relativeTo: .title3)

    /// List row title (Library list, Feeds, People).
    static let listRowTitle = figtree(15.5, weight: .semibold, relativeTo: .subheadline)
    /// Card excerpt / general body copy.
    static let bodyExcerpt = figtree(14, relativeTo: .footnote)
    /// Uppercase section label.
    static let sectionLabel = figtree(12, weight: .heavy, relativeTo: .caption)
    /// Uppercase field label (Save a link, Login).
    static let fieldLabel = figtree(11.5, weight: .heavy, relativeTo: .caption2)
    /// Meta / caption text (timestamps, read time, domain).
    static let meta = figtree(12.5, relativeTo: .caption)
    /// Row meta line inside a channel / Library list row.
    static let rowMeta = figtree(12, relativeTo: .caption)
    /// Uppercase date on the featured article.
    static let featuredMeta = figtree(12, weight: .bold, relativeTo: .caption)
    /// One-line snippet under a list row title.
    static let rowSnippet = figtree(13, relativeTo: .footnote)
    /// Two-line snippet under the featured article title.
    static let featuredSnippet = figtree(13.5, relativeTo: .footnote)
    /// Filter pill label.
    static func filterPill(selected: Bool) -> Font {
        figtree(13.5, weight: selected ? .bold : .semibold, relativeTo: .footnote)
    }
    /// Tab bar label.
    static func tabLabel(selected: Bool) -> Font {
        figtree(10.5, weight: selected ? .heavy : .bold, relativeTo: .caption2)
    }
    /// Status / sync banner copy.
    static let statusBar = figtree(14.5, weight: .heavy, relativeTo: .subheadline)

    /// Reader body default (Lora, "Comfortable" line height).
    static let readerBody = Font.custom("Lora-Regular", size: 18.5, relativeTo: .body)
    /// Focus-mode body.
    static let focusBody = Font.custom("Lora-Regular", size: 19, relativeTo: .body)
}

// MARK: - Spacing

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // Organic design system — screen-specific spacing (docs/revamp-ios/README.md).
    static let screenHorizontal: CGFloat = 20
    static let readerColumn: CGFloat = 26
    static let focusHorizontal: CGFloat = 30
    static let loginHorizontal: CGFloat = 32
    static let contentTop: CGFloat = 26
    static let profileTop: CGFloat = 30
    static let tabBarHeight: CGFloat = 84
    static let scrollBottomInset: CGFloat = 100
    static let minTapTarget: CGFloat = 44
    static let readerActionBarHeight: CGFloat = 60
    static let iconButtonSize: CGFloat = 38
    /// Circular header button on the feed channel screen (06b).
    static let channelIconButtonSize: CGFloat = 36
    /// Channel monogram / favicon square in the channel header.
    static let channelAvatarSize: CGFloat = 40
    /// Thumbnail edge on a channel / Library list row (06b).
    static let feedThumbnailSize: CGFloat = 78
    /// Height of the featured article cover.
    static let featuredCoverHeight: CGFloat = 168
    /// Leading inset of a list-row separator: thumbnail + gap.
    static let rowSeparatorInset: CGFloat = 92
}

// MARK: - Corner Radius

struct CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999

    // Organic design system radii (docs/revamp-ios/README.md).
    static let card: CGFloat = 26
    static let sheet: CGFloat = 32
    static let listThumbnail: CGFloat = 18
    static let smallThumbnail: CGFloat = 14
    static let pill: CGFloat = 999
    /// Feed channel list-row thumbnail — softer corners than `listThumbnail`.
    static let feedThumbnail: CGFloat = 22
    /// Channel monogram / favicon square.
    static let channelAvatar: CGFloat = 14
    /// Featured article cover (same radius as a Library card).
    static let featuredCover: CGFloat = 26
}

// MARK: - Shadows

struct AppShadows {
    static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)

    // Organic design system shadows — warm near-black (docs/revamp-ios/README.md).
    static let card = Shadow(color: Color(hex: "#2E2B25").opacity(0.08), radius: 22, x: 0, y: 6)
    static let floatingBar = Shadow(color: Color(hex: "#2E2B25").opacity(0.16), radius: 30, x: 0, y: 10)
    static let sheet = Shadow(color: Color(hex: "#2E2B25").opacity(0.22), radius: 40, x: 0, y: -12)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Codable {
    case grid
    case list

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}
