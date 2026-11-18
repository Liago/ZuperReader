import SwiftUI
import UIKit
import Combine

// MARK: - Home Screen Quick Actions
//
// Long-pressing the app icon shows the static items declared in Info.plist
// (`UIApplicationShortcutItems`). SwiftUI has no hook for them, so a small
// app/scene delegate pair forwards the selected item to `QuickActionRouter`,
// and the Library screens react to `pending`.

enum QuickAction: String {
    /// Opens the "Add article" sheet (paste a link → parse → save).
    case addArticle = "liagosoft.SuperReader.addArticle"
}

@MainActor
final class QuickActionRouter: ObservableObject {
    static let shared = QuickActionRouter()

    /// Action waiting to be handled. Screens observing it reset it to `nil`
    /// once handled; it stays set across sign-in so a cold launch from the
    /// icon still opens the sheet after the session is restored.
    @Published var pending: QuickAction?

    private init() {}

    @discardableResult
    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let action = QuickAction(rawValue: item.type) else { return false }
        pending = action
        return true
    }
}

final class SuperReaderAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold launch from a quick action: the item arrives here, not in
        // `windowScene(_:performActionFor:)`.
        if let item = options.shortcutItem {
            Task { @MainActor in QuickActionRouter.shared.handle(item) }
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SuperReaderSceneDelegate.self
        return configuration
    }
}

final class SuperReaderSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            completionHandler(QuickActionRouter.shared.handle(shortcutItem))
        }
    }
}
