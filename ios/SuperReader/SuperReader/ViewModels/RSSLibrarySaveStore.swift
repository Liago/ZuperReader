import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - RSS → Library Save Store
//
// Stato condiviso del salvataggio "articolo del feed → Libreria" (parse
// dell'URL originale via parser API + insert su Supabase). È la stessa
// operazione invocata dal bookmark del reader (RSSArticleReader), esposta
// anche all'action menu della lista (long press) così che i due entry point
// condividano stato e feedback.

@MainActor
class RSSLibrarySaveStore: ObservableObject {
    static let shared = RSSLibrarySaveStore()

    enum SaveState: Equatable {
        case saving
        case saved
    }

    struct Banner: Identifiable, Equatable {
        enum Style: Equatable {
            case progress
            case success
            case error
        }

        let id = UUID()
        let message: String
        let style: Style

        /// Il feedback di avanzamento resta finché il parsing non termina.
        var autoDismiss: Bool { style != .progress }
    }

    /// Stato per articolo RSS (nil = non salvato in questa sessione).
    @Published private(set) var states: [UUID: SaveState] = [:]
    /// Feedback corrente, mostrato come toast in fondo alla schermata.
    @Published var banner: Banner?

    private let supabaseService = SupabaseService.shared

    private init() {}

    // MARK: - Query

    func state(for article: RSSArticle) -> SaveState? {
        states[article.id]
    }

    func isSaving(_ article: RSSArticle) -> Bool {
        states[article.id] == .saving
    }

    func isSaved(_ article: RSSArticle) -> Bool {
        states[article.id] == .saved
    }

    // MARK: - Actions

    /// Parsa l'articolo del feed e lo salva nella Libreria.
    /// Idempotente nella sessione: se il salvataggio è in corso o già andato a
    /// buon fine non riparte, evitando duplicati da invocazioni ripetute.
    @discardableResult
    func saveToLibrary(_ article: RSSArticle) async -> Bool {
        if let state = states[article.id] {
            return state == .saved
        }

        states[article.id] = .saving
        show(message: "Saving to Library…", style: .progress)

        do {
            _ = try await supabaseService.saveRSSArticleWithParsing(article)
            states[article.id] = .saved
            show(message: "Saved to Library", style: .success)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            states[article.id] = nil
            show(message: "Failed to save: \(error.localizedDescription)", style: .error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    func dismissBanner() {
        banner = nil
    }

    private func show(message: String, style: Banner.Style) {
        withAnimation {
            banner = Banner(message: message, style: style)
        }
    }
}
