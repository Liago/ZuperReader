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

    @Published var systemColorScheme: ColorScheme = .light

    @Published var viewMode: ViewMode {
        didSet {
            UserDefaults.standard.set(viewMode.rawValue, forKey: "view_mode")
        }
    }

    var resolvedTheme: ColorTheme {
        currentTheme.resolvedTheme(for: systemColorScheme)
    }

    var colors: ThemeColors {
        resolvedTheme.colors
    }

    private init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = ColorTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .auto
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

    func updateSystemColorScheme(_ colorScheme: ColorScheme) {
        if systemColorScheme != colorScheme {
            withAnimation(.easeInOut(duration: 0.3)) {
                systemColorScheme = colorScheme
            }
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

// MARK: - System Color Scheme Observer

struct SystemColorSchemeObserver: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    private let themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: colorScheme) { _, newValue in
                themeManager.updateSystemColorScheme(newValue)
            }
            .onAppear {
                themeManager.updateSystemColorScheme(colorScheme)
            }
    }
}

extension View {
    func observeSystemColorScheme() -> some View {
        modifier(SystemColorSchemeObserver())
    }
}
