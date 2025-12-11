import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        }
    }
    
    @Published var viewMode: ViewMode {
        didSet {
            UserDefaults.standard.set(viewMode.rawValue, forKey: "view_mode")
        }
    }
    
    var colors: ThemeColors {
        currentTheme.colors
    }
    
    private init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = ColorTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .light
        }
        
        // Load saved view mode
        if let savedMode = UserDefaults.standard.string(forKey: "view_mode"),
           let mode = ViewMode(rawValue: savedMode) {
            self.viewMode = mode
        } else {
            self.viewMode = .grid
        }
    }
    
    func setTheme(_ theme: ColorTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
    
    func toggleViewMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewMode = viewMode == .grid ? .list : .grid
        }
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
