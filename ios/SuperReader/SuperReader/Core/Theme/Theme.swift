import SwiftUI

// MARK: - Color Theme

/// App and reader color themes (Editorial Teal).
///
/// Raw values are persisted locally (`app_theme`) and in Supabase
/// (`user_preferences.color_theme`, shared with the web app), so the case
/// names stay as they were: `.cream` is now the white "Light" palette.
/// `.sepia` is offered only inside the reader (Reading preferences); the
/// app-wide appearance picker shows Light / Dark / System.
enum ColorTheme: String, CaseIterable, Codable {
    case cream
    case sepia
    case dark
    case system

    var displayName: String {
        switch self {
        case .cream: return "Light"
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
            // "Light" — Editorial Teal (design canvas · 05 Design system).
            // Solid muted grey: #5F6668 is 5.9:1 on white (WCAG AA).
            return ThemeColors(
                page: Color(hex: "#FFFFFF"),
                rail: Color(hex: "#F7F8F8"),
                card: Color(hex: "#FFFFFF"),
                surface: Color(hex: "#F1F3F3"),
                text: Color(hex: "#16191A"),
                muted: Color(hex: "#5F6668"),
                line: Color(hex: "#E3E6E7"),
                sink: Color(hex: "#16191A").opacity(0.04),
                // 6.4:1 on white; white text on it passes AA too.
                accent: Color(hex: "#33666C"),
                accent200: Color(hex: "#DCE7E8"),
                accent700: Color(hex: "#2F5F65"),
                accent800: Color(hex: "#234A4F"),
                // The new system has a single hue: the old sage "accent-2"
                // becomes a neutral slate so secondary marks stay distinct
                // without introducing a second color.
                accent2: Color(hex: "#3E4447"),
                accent2_200: Color(hex: "#F1F3F3")
            )
        case .sepia:
            // Reader-only palette (Reading preferences → Theme). Kept as a
            // full token set because the reader chrome is drawn with it.
            return ThemeColors(
                page: Color(hex: "#F4ECDD"),
                rail: Color(hex: "#EDE2CC"),
                card: Color(hex: "#F8F2E6"),
                surface: Color(hex: "#EDE2CC"),
                text: Color(hex: "#3B3226"),
                // 72% — Sepia's page is darker, so muted needs more ink to
                // reach 4.5:1.
                muted: Color(hex: "#3B3226").opacity(0.72),
                line: Color(hex: "#3B3226").opacity(0.14),
                sink: Color(hex: "#3B3226").opacity(0.05),
                // Deeper teal: 6.1:1 on the sepia page.
                accent: Color(hex: "#2F5F65"),
                accent200: Color(hex: "#D9E0D5"),
                accent700: Color(hex: "#234A4F"),
                accent800: Color(hex: "#1A383C"),
                accent2: Color(hex: "#4F4536"),
                accent2_200: Color(hex: "#EDE2CC")
            )
        case .dark:
            return ThemeColors(
                page: Color(hex: "#0F1213"),
                rail: Color(hex: "#151A1B"),
                card: Color(hex: "#1B2022"),
                surface: Color(hex: "#1B2022"),
                text: Color(hex: "#EEF1F1"),
                muted: Color(hex: "#9AA3A5"),
                line: Color(hex: "#2A3133"),
                sink: Color(hex: "#EEF1F1").opacity(0.05),
                accent: Color(hex: "#7FB3B9"),
                accent200: Color(hex: "#1E3436"),
                accent700: Color(hex: "#9CC6CB"),
                accent800: Color(hex: "#B9D8DB"),
                accent2: Color(hex: "#C5CCCE"),
                accent2_200: Color(hex: "#232A2C")
            )
        }
    }
}

// MARK: - Theme Colors

/// Semantic color tokens for the Editorial Teal design system
/// (design canvas "ZuperReader iOS Redesign" · Design system).
/// SwiftUI names → design names: page, surface, text, muted, line,
/// accent, accent200 = accentSoft.
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

    // MARK: Increase Contrast

    /// Variant served when the system "Increase Contrast" setting is on
    /// (HIG · Color: custom colors need "an increased contrast option for each
    /// variant"). Muted text and hairlines get more ink and the teal accent
    /// steps one shade darker (lighter in Dark) for extra margin over AA.
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
            accent: isDark ? Color(hex: "#A9D0D5") : accent800,
            accent200: accent200,
            accent700: isDark ? Color(hex: "#C8E1E4") : Color(hex: "#1A383C"),
            accent800: accent800,
            accent2: isDark ? Color(hex: "#DDE2E3") : text,
            accent2_200: accent2_200
        )
    }
}

// MARK: - Premium Gradients

// Editorial Teal has no gradient washes: each "gradient" is now two
// near-identical stops, so it reads as a flat fill. Names are kept so
// existing call sites (avatars, buttons, badges) don't change yet; they
// will become plain Color fills as each screen is migrated. Every fill
// carries white text, so all stops stay dark enough for AA.
struct PremiumGradients {
    static let primary = LinearGradient(
        colors: [Color(hex: "#33666C"), Color(hex: "#2F5F65")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purple = LinearGradient(
        colors: [Color(hex: "#5F6668"), Color(hex: "#3E4447")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pink = LinearGradient(
        colors: [Color(hex: "#2F5F65"), Color(hex: "#234A4F")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let indigo = LinearGradient(
        colors: [Color(hex: "#2B3A3C"), Color(hex: "#16191A")],
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

    // MARK: UI type ramp (SF Pro)
    //
    // Editorial Teal sets every UI string in the system face, SF Pro (the
    // iOS counterpart of Inter in the design canvas). Each design size maps
    // onto the nearest Dynamic Type text style, so the whole ramp follows the
    // user's text-size setting live and needs no bundled font files.
    // Bundled Figtree / Lora / … are now used only by the reader body.

    /// Nearest Dynamic Type text style for a design point size.
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2
        case ..<12.5: return .caption
        case ..<14: return .footnote
        case ..<15.5: return .subheadline
        case ..<16.5: return .callout
        case ..<19: return .body
        case ..<21: return .title3
        case ..<25: return .title2
        case ..<31: return .title
        default: return .largeTitle
        }
    }

    /// Title face: screen titles, article titles, card titles, stats.
    /// Pass `relativeTo` when the role matters more than the exact size.
    static func display(
        _ size: CGFloat,
        weight: Font.Weight = .bold,
        relativeTo style: Font.TextStyle? = nil
    ) -> Font {
        .system(style ?? textStyle(for: size), design: .default, weight: weight)
    }

    /// Interface face: rows, labels, buttons, meta. Black / heavy weights
    /// from the previous ramp are capped at bold — SF Pro Heavy reads much
    /// darker than Figtree ExtraBold did.
    static func ui(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle? = nil
    ) -> Font {
        let capped: Font.Weight = (weight == .heavy || weight == .black) ? .bold : weight
        return .system(style ?? textStyle(for: size), design: .default, weight: capped)
    }

    /// Dynamic Type–aware replacement for `.system(size:weight:)` on SF Symbols
    /// and system text. Fixed point sizes never scale; this maps the design
    /// size onto the closest system text style, which does.
    static func symbol(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(textStyle(for: size), design: design, weight: weight)
    }

    /// Screen title — Library / Feeds / People / You headers (28/800).
    static let largeTitle = display(28, weight: .heavy, relativeTo: .title)
    /// Reader article title (26/700).
    static let articleTitle = display(26, weight: .bold, relativeTo: .title)
    /// Library card / section title (20/700).
    static let cardTitle = display(20, weight: .bold, relativeTo: .title3)
    /// Sheet titles — Reading preferences, Save a link (17/600).
    static let sheetTitle = display(17, weight: .semibold, relativeTo: .headline)
    /// "You" screen stat numbers (20/700).
    static let statNumber = display(20, weight: .bold, relativeTo: .title3)

    /// List row title (Library list, Feeds, People) — 15/600.
    static let listRowTitle = ui(15, weight: .semibold, relativeTo: .subheadline)
    /// Card excerpt / general body copy — 14/400.
    static let bodyExcerpt = ui(14, relativeTo: .subheadline)
    /// Uppercase section label — 12/700, tracked.
    static let sectionLabel = ui(12, weight: .bold, relativeTo: .caption)
    /// Field label (Save a link, Login) — 13/600.
    static let fieldLabel = ui(13, weight: .semibold, relativeTo: .footnote)
    /// Meta / caption text (timestamps, read time, domain) — 13/400.
    static let meta = ui(13, relativeTo: .footnote)
    /// Tab bar label — 11, semibold when selected.
    static func tabLabel(selected: Bool) -> Font {
        ui(11, weight: selected ? .semibold : .medium, relativeTo: .caption2)
    }
    /// Status / sync banner copy — 14/600.
    static let statusBar = ui(14, weight: .semibold, relativeTo: .subheadline)

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
    static let contentTop: CGFloat = 12
    static let profileTop: CGFloat = 30
    static let tabBarHeight: CGFloat = 84
    static let scrollBottomInset: CGFloat = 100
    static let minTapTarget: CGFloat = 44
    static let readerActionBarHeight: CGFloat = 60
    /// Editorial Teal header buttons are full 44pt circles.
    static let iconButtonSize: CGFloat = 44
}

// MARK: - Corner Radius

struct CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999

    // Editorial Teal radii: card 16, thumbnail 14, pill / button 999.
    static let card: CGFloat = 16
    static let sheet: CGFloat = 22
    static let listThumbnail: CGFloat = 14
    static let smallThumbnail: CGFloat = 12
    static let pill: CGFloat = 999
}

// MARK: - Shadows

struct AppShadows {
    static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)

    // Editorial Teal shadows — neutral ink, used sparingly: cards rely on a
    // 1pt `line` border, only floating chrome and sheets cast a shadow.
    static let card = Shadow(color: Color(hex: "#16191A").opacity(0.06), radius: 12, x: 0, y: 2)
    static let floatingBar = Shadow(color: Color(hex: "#16191A").opacity(0.12), radius: 24, x: 0, y: 8)
    static let sheet = Shadow(color: Color(hex: "#16191A").opacity(0.18), radius: 32, x: 0, y: -8)
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
