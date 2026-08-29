import Foundation

// MARK: - User Preferences (Reading preferences)

struct UserPreferences: Codable {
    var id: String // User ID
    var fontFamily: Typography.FontFamily
    var fontSize: Int // 12-50
    var colorTheme: ColorTheme
    var lineHeight: Typography.LineHeight
    var contentWidth: Typography.ContentWidth
    var viewMode: ViewMode
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fontFamily = "font_family"
        case fontSize = "font_size"
        case colorTheme = "color_theme"
        case lineHeight = "line_height"
        case contentWidth = "content_width"
        case viewMode = "view_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String,
        fontFamily: Typography.FontFamily = .lora,
        fontSize: Int = 18,
        colorTheme: ColorTheme = .system,
        lineHeight: Typography.LineHeight = .comfortable,
        contentWidth: Typography.ContentWidth = .normal,
        viewMode: ViewMode = .grid,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.colorTheme = colorTheme
        self.lineHeight = lineHeight
        self.contentWidth = contentWidth
        self.viewMode = viewMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func defaultPreferences(for userId: String) -> UserPreferences {
        UserPreferences(id: userId)
    }
}

// MARK: - Local Reading Preferences (for article reader)

struct ReadingPreferences: Equatable {
    var fontFamily: Typography.FontFamily = .lora
    var fontSize: CGFloat = 18.5
    /// `.system` follows the app's global theme (Cream/Dark); Cream, Sepia
    /// and Dark are explicit overrides set from the reading preferences
    /// sheet, independent of the app chrome's theme.
    var colorTheme: ColorTheme = .system
    var lineHeight: Typography.LineHeight = .comfortable
    var contentWidth: Typography.ContentWidth = .normal

    var fontSizeFormatted: String {
        String(format: "%.1f pt", fontSize)
    }

    mutating func increaseFontSize() {
        fontSize = min(28, fontSize + 0.5)
    }

    mutating func decreaseFontSize() {
        fontSize = max(14, fontSize - 0.5)
    }
}
