import Foundation
import SwiftUI
import Combine
import Supabase

// MARK: - Reading Preferences Manager

@MainActor
class ReadingPreferencesManager: ObservableObject {
    static let shared = ReadingPreferencesManager()

    @Published var preferences: ReadingPreferences {
        didSet {
            saveToUserDefaults()
            syncToSupabaseDebounced()
        }
    }

    private let userDefaultsKey = "readingPreferences"
    private var syncWorkItem: DispatchWorkItem?

    private init() {
        self.preferences = Self.loadFromUserDefaults()
    }

    // MARK: - UserDefaults Persistence

    private static func loadFromUserDefaults() -> ReadingPreferences {
        guard let data = UserDefaults.standard.data(forKey: "readingPreferences"),
              let decoded = try? JSONDecoder().decode(ReadingPreferencesStorage.self, from: data) else {
            return ReadingPreferences()
        }
        return decoded.toReadingPreferences()
    }

    private func saveToUserDefaults() {
        let storage = ReadingPreferencesStorage(from: preferences)
        if let encoded = try? JSONEncoder().encode(storage) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    // MARK: - Supabase Sync (debounced)

    private func syncToSupabaseDebounced() {
        syncWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.syncToSupabase()
            }
        }
        syncWorkItem = workItem

        // Debounce: sync after 2 seconds of no changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func syncToSupabase() async {
        guard let userId = AuthManager.shared.user?.id.uuidString else { return }

        let userPrefs = UserPreferences(
            id: userId,
            fontFamily: preferences.fontFamily,
            fontSize: Int(preferences.fontSize),
            colorTheme: preferences.colorTheme,
            lineHeight: preferences.lineHeight,
            contentWidth: preferences.contentWidth,
            viewMode: .list
        )

        do {
            _ = try await SupabaseService.shared.saveUserPreferences(preferences: userPrefs)
        } catch {
            print("Failed to sync preferences to Supabase: \(error)")
        }
    }

    // MARK: - Load from Supabase

    func loadFromSupabase() async {
        guard let userId = AuthManager.shared.user?.id.uuidString else { return }

        do {
            if let userPrefs = try await SupabaseService.shared.getUserPreferences(userId: userId) {
                await MainActor.run {
                    self.preferences = ReadingPreferences(
                        fontFamily: userPrefs.fontFamily,
                        fontSize: CGFloat(userPrefs.fontSize),
                        colorTheme: userPrefs.colorTheme,
                        lineHeight: userPrefs.lineHeight,
                        contentWidth: userPrefs.contentWidth
                    )
                }
            }
        } catch {
            print("Failed to load preferences from Supabase: \(error)")
        }
    }
}

// MARK: - Storage Model for UserDefaults

private struct ReadingPreferencesStorage: Codable {
    let fontFamily: String
    let fontSize: CGFloat
    let colorTheme: String
    let lineHeight: String
    let contentWidth: String

    init(from preferences: ReadingPreferences) {
        self.fontFamily = preferences.fontFamily.rawValue
        self.fontSize = preferences.fontSize
        self.colorTheme = preferences.colorTheme.rawValue
        self.lineHeight = preferences.lineHeight.rawValue
        self.contentWidth = preferences.contentWidth.rawValue
    }

    func toReadingPreferences() -> ReadingPreferences {
        ReadingPreferences(
            fontFamily: Typography.FontFamily(rawValue: fontFamily) ?? .serif,
            fontSize: fontSize,
            colorTheme: ColorTheme(rawValue: colorTheme) ?? .light,
            lineHeight: Typography.LineHeight(rawValue: lineHeight) ?? .relaxed,
            contentWidth: Typography.ContentWidth(rawValue: contentWidth) ?? .normal
        )
    }
}
