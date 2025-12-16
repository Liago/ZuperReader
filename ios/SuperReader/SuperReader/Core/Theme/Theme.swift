import SwiftUI

// MARK: - Color Theme

enum ColorTheme: String, CaseIterable, Codable {
    case light
    case dark
    case ocean
    case forest
    case sunset
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        }
    }
    
    var colors: ThemeColors {
        switch self {
        case .light:
            return ThemeColors(
                bgPrimary: Color(hex: "#FFFFFF"),
                bgSecondary: Color(hex: "#F9FAFB"),
                bgGradientFrom: Color(hex: "#FFFFFF"),
                bgGradientVia: Color(hex: "#FFFFFF"),
                bgGradientTo: Color(hex: "#FFFFFF"),
                textPrimary: Color(hex: "#111827"),
                textSecondary: Color(hex: "#6B7280"),
                border: Color(hex: "#E5E7EB"),
                cardBg: Color.white.opacity(0.8),
                accent: Color(hex: "#9333EA")
            )
        case .dark:
            return ThemeColors(
                bgPrimary: Color(hex: "#0F172A"),
                bgSecondary: Color(hex: "#1E293B"),
                bgGradientFrom: Color(hex: "#0F172A"),
                bgGradientVia: Color(hex: "#1E293B"),
                bgGradientTo: Color(hex: "#334155"),
                textPrimary: Color(hex: "#F1F5F9"),
                textSecondary: Color(hex: "#CBD5E1"),
                border: Color(hex: "#334155"),
                cardBg: Color(hex: "#1E293B").opacity(0.8),
                accent: Color(hex: "#818CF8")
            )
        case .ocean:
            return ThemeColors(
                bgPrimary: Color(hex: "#F0F9FF"),
                bgSecondary: Color(hex: "#E0F2FE"),
                bgGradientFrom: Color(hex: "#ECFEFF"),
                bgGradientVia: Color(hex: "#CFFAFE"),
                bgGradientTo: Color(hex: "#A5F3FC"),
                textPrimary: Color(hex: "#164E63"),
                textSecondary: Color(hex: "#0E7490"),
                border: Color(hex: "#A5F3FC"),
                cardBg: Color(hex: "#F0F9FF").opacity(0.8),
                accent: Color(hex: "#0891B2")
            )
        case .forest:
            return ThemeColors(
                bgPrimary: Color(hex: "#F0FDF4"),
                bgSecondary: Color(hex: "#DCFCE7"),
                bgGradientFrom: Color(hex: "#F0FDF4"),
                bgGradientVia: Color(hex: "#DCFCE7"),
                bgGradientTo: Color(hex: "#BBF7D0"),
                textPrimary: Color(hex: "#14532D"),
                textSecondary: Color(hex: "#166534"),
                border: Color(hex: "#BBF7D0"),
                cardBg: Color(hex: "#F0FDF4").opacity(0.8),
                accent: Color(hex: "#16A34A")
            )
        case .sunset:
            return ThemeColors(
                bgPrimary: Color(hex: "#FAF5FF"),
                bgSecondary: Color(hex: "#F3E8FF"),
                bgGradientFrom: Color(hex: "#FAF5FF"),
                bgGradientVia: Color(hex: "#F3E8FF"),
                bgGradientTo: Color(hex: "#E9D5FF"),
                textPrimary: Color(hex: "#581C87"),
                textSecondary: Color(hex: "#7C3AED"),
                border: Color(hex: "#E9D5FF"),
                cardBg: Color(hex: "#FAF5FF").opacity(0.8),
                accent: Color(hex: "#A855F7")
            )
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    let bgPrimary: Color
    let bgSecondary: Color
    let bgGradientFrom: Color
    let bgGradientVia: Color
    let bgGradientTo: Color
    let textPrimary: Color
    let textSecondary: Color
    let border: Color
    let cardBg: Color
    let accent: Color
    
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientFrom, bgGradientVia, bgGradientTo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Premium Gradients

struct PremiumGradients {
    static let primary = LinearGradient(
        colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899"), Color(hex: "#3B82F6")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let purple = LinearGradient(
        colors: [Color(hex: "#7C3AED"), Color(hex: "#8B5CF6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let pink = LinearGradient(
        colors: [Color(hex: "#EC4899"), Color(hex: "#F472B6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let indigo = LinearGradient(
        colors: [Color(hex: "#6366F1"), Color(hex: "#818CF8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let login = LinearGradient(
        colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6"), Color(hex: "#EC4899")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography

struct Typography {
    // Font Families
    enum FontFamily: String, CaseIterable, Codable {
        case sans
        case serif
        case mono
        case inter
        case poppins
        case lora
        case montserrat
        case crimsonText
        // Legacy/System fallback
        case roboto
        case lato
        case openSans
        case ubuntu
        
        var displayName: String {
            switch self {
            case .sans: return "System Sans"
            case .serif: return "System Serif"
            case .mono: return "Monospace"
            case .inter: return "Inter"
            case .poppins: return "Poppins"
            case .lora: return "Lora"
            case .montserrat: return "Montserrat"
            case .crimsonText: return "Crimson Text"
            case .roboto: return "Roboto (System)"
            case .lato: return "Lato (System)"
            case .openSans: return "Open Sans (System)"
            case .ubuntu: return "Ubuntu (System)"
            }
        }
        
        var font: Font {
            switch self {
            case .sans: return .system(.body, design: .default)
            case .serif: return .system(.body, design: .serif)
            case .mono: return .system(.body, design: .monospaced)
            case .inter: return .custom("Inter-Regular", size: 17)
            case .poppins: return .custom("Poppins-Regular", size: 17)
            case .lora: return .custom("Lora-Regular", size: 17)
            case .montserrat: return .custom("Montserrat-Regular", size: 17)
            case .crimsonText: return .custom("CrimsonText-Regular", size: 17)
            case .roboto: return .system(.body, design: .default)
            case .lato: return .system(.body, design: .rounded)
            case .openSans: return .system(.body, design: .default)
            case .ubuntu: return .system(.body, design: .monospaced)
            }
        }
        
        func font(size: CGFloat) -> Font {
            switch self {
            case .sans: return .system(size: size, design: .default)
            case .serif: return .system(size: size, design: .serif)
            case .mono: return .system(size: size, design: .monospaced)
            case .inter: return .custom("Inter-Regular", size: size)
            case .poppins: return .custom("Poppins-Regular", size: size)
            case .lora: return .custom("Lora-Regular", size: size)
            case .montserrat: return .custom("Montserrat-Regular", size: size)
            case .crimsonText: return .custom("CrimsonText-Regular", size: size)
            case .roboto: return .system(size: size, design: .default)
            case .lato: return .system(size: size, design: .rounded)
            case .openSans: return .system(size: size, design: .default)
            case .ubuntu: return .system(size: size, design: .monospaced)
            }
        }
    }
    
    // Line Height
    enum LineHeight: String, CaseIterable, Codable {
        case compact
        case normal
        case relaxed
        case loose
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var multiplier: CGFloat {
            switch self {
            case .compact: return 1.25
            case .normal: return 1.5
            case .relaxed: return 1.75
            case .loose: return 2.0
            }
        }
    }
    
    // Content Width
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
}

// MARK: - Spacing

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Shadows

struct AppShadows {
    static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
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
