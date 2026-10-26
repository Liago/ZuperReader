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
    /// Articoli RSS in corso di aggiunta a Up next (parse + salvataggio + coda).
    @Published private(set) var queueSavingIds: Set<UUID> = []

    /// Articolo di Libreria creato (o ritrovato) per ogni articolo RSS.
    private var libraryArticleIds: [UUID: String] = [:]

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
            let saved = try await supabaseService.saveRSSArticleWithParsing(article)
            libraryArticleIds[article.id] = saved.id
            states[article.id] = .saved
            ArticleCategoryStore.shared.categorize([saved])
            NotificationCenter.default.post(name: NSNotification.Name("RefreshArticles"), object: nil)
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

    // MARK: - Up next

    /// nil = l'articolo può essere aggiunto a Up next.
    /// Derivato dalla coda reale, così torna disponibile se l'articolo viene
    /// tolto da Up next.
    func queueState(for article: RSSArticle) -> QueueActionState? {
        if queueSavingIds.contains(article.id) { return .saving }
        let queue = ReadingQueueStore.shared
        if let articleId = libraryArticleIds[article.id] {
            if queue.isPending(articleId) { return .saving }
            if queue.isQueued(articleId) { return .done }
        }
        if queue.items.contains(where: { $0.article?.url == article.link }) { return .done }
        return nil
    }

    /// Aggiunge un articolo del feed alla coda Up next. La coda contiene solo
    /// articoli della Libreria: se non è già stato salvato lo parsa e lo salva
    /// (come il bookmark), poi lo accoda e lo categorizza.
    func addToUpNext(_ article: RSSArticle) async {
        guard queueState(for: article) == nil, !isSaving(article) else { return }

        queueSavingIds.insert(article.id)
        defer { queueSavingIds.remove(article.id) }
        show(message: "Adding to Up next…", style: .progress)

        do {
            let libraryArticle = try await libraryArticle(for: article)
            let queue = ReadingQueueStore.shared
            await queue.add(articleId: libraryArticle.id, userId: article.userId.uuidString)
            guard queue.isQueued(libraryArticle.id) else {
                throw SupabaseError.custom("Couldn't add the article to Up next")
            }

            ArticleCategoryStore.shared.categorize([libraryArticle])
            NotificationCenter.default.post(name: NSNotification.Name("RefreshArticles"), object: nil)
            show(message: "Added to Up next", style: .success)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            show(message: "Failed to add to Up next: \(error.localizedDescription)", style: .error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// L'articolo di Libreria corrispondente: quello già salvato se esiste,
    /// altrimenti lo crea con parse dell'URL originale.
    private func libraryArticle(for article: RSSArticle) async throws -> Article {
        let userId = article.userId.uuidString
        if let articleId = libraryArticleIds[article.id],
           let existing = try await supabaseService.getArticleById(articleId) {
            return existing
        }
        if let existing = try await supabaseService.findArticle(userId: userId, url: article.link) {
            libraryArticleIds[article.id] = existing.id
            states[article.id] = .saved
            return existing
        }

        states[article.id] = .saving
        do {
            let saved = try await supabaseService.saveRSSArticleWithParsing(article)
            libraryArticleIds[article.id] = saved.id
            states[article.id] = .saved
            return saved
        } catch {
            states[article.id] = nil
            throw error
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
