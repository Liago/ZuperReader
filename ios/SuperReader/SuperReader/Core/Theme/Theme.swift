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
                muted: Color(hex: "#201E1D").opacity(0.58),
                line: Color(hex: "#201E1D").opacity(0.12),
                sink: Color(hex: "#201E1D").opacity(0.045),
                accent: Color(hex: "#C67139"),
                accent200: Color(hex: "#F0CBA9"),
                accent700: Color(hex: "#8A4B22"),
                accent800: Color(hex: "#6B3A19"),
                accent2: Color(hex: "#7A8A5E"),
                accent2_200: Color(hex: "#D6DDC5")
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
                muted: Color(hex: "#3A2F1F").opacity(0.58),
                line: Color(hex: "#3A2F1F").opacity(0.12),
                sink: Color(hex: "#3A2F1F").opacity(0.045),
                accent: Color(hex: "#C67139"),
                accent200: Color(hex: "#F0CBA9"),
                accent700: Color(hex: "#8A4B22"),
                accent800: Color(hex: "#6B3A19"),
                accent2: Color(hex: "#7A8A5E"),
                accent2_200: Color(hex: "#D6DDC5")
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
                accent2_200: Color(hex: "#D6DDC5")
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
        case figtree
        case mono

        var displayName: String {
            switch self {
            case .lora: return "Lora"
            case .figtree: return "Figtree"
            case .mono: return "Mono"
            }
        }

        var font: Font { font(size: 17) }

        func font(size: CGFloat) -> Font {
            switch self {
            case .lora: return .custom("Lora-Regular", size: size)
            case .figtree: return .custom("Figtree-Regular", size: size)
            case .mono: return .system(size: size, design: .monospaced)
            }
        }

        /// Maps legacy stored raw values (sans, serif, mono, inter, poppins,
        /// montserrat, crimsonText, roboto, lato, openSans, ubuntu) onto the
        /// reduced three-value set, per docs/revamp-ios/README.md · "State".
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
    // Falls back to the system font automatically if Caprasimo-Regular /
    // Figtree-* aren't bundled yet in Resources/Fonts (see
    // docs/revamp-ios/README.md · "Assets").

    static func caprasimo(_ size: CGFloat) -> Font {
        .custom("Caprasimo-Regular", size: size)
    }

    static func figtree(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black: name = "Figtree-Black"
        case .heavy: name = "Figtree-ExtraBold"
        case .bold: name = "Figtree-Bold"
        case .semibold: name = "Figtree-SemiBold"
        case .medium: name = "Figtree-Medium"
        default: name = "Figtree-Regular"
        }
        return .custom(name, size: size)
    }

    /// Screen title — Library / Feeds / People / You headers.
    static let largeTitle = caprasimo(34)
    /// Reader article title.
    static let articleTitle = caprasimo(31)
    /// Library grid card title.
    static let cardTitle = caprasimo(20)
    /// Reading preferences / Save-a-link sheet titles.
    static let sheetTitle = caprasimo(22)
    /// "You" screen stat numbers.
    static let statNumber = caprasimo(24)

    /// List row title (Library list, Feeds, People).
    static let listRowTitle = figtree(15.5, weight: .semibold)
    /// Card excerpt / general body copy.
    static let bodyExcerpt = figtree(14)
    /// Uppercase section label.
    static let sectionLabel = figtree(12, weight: .heavy)
    /// Uppercase field label (Save a link, Login).
    static let fieldLabel = figtree(11.5, weight: .heavy)
    /// Meta / caption text (timestamps, read time, domain).
    static let meta = figtree(12.5)
    /// Tab bar label.
    static func tabLabel(selected: Bool) -> Font {
        figtree(10.5, weight: selected ? .heavy : .bold)
    }
    /// Status / sync banner copy.
    static let statusBar = figtree(14.5, weight: .heavy)

    /// Reader body default (Lora, "Comfortable" line height).
    static let readerBody = Font.custom("Lora-Regular", size: 18.5)
    /// Focus-mode body.
    static let focusBody = Font.custom("Lora-Regular", size: 19)
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
