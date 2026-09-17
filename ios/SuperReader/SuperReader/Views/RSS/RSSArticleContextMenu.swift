import SwiftUI

// MARK: - RSS Article Context Menu
//
// Action menu (long press) su una riga di articolo del feed. L'azione
// principale è la stessa del bookmark nel reader: parse dell'URL originale e
// salvataggio in Libreria (RSSLibrarySaveStore → SupabaseService
// .saveRSSArticleWithParsing), senza aprire il dettaglio.

struct RSSArticleContextMenuModifier: ViewModifier {
    let article: RSSArticle
    /// Passato dalla lista che possiede lo stato locale degli articoli.
    let onMarkAsRead: (() -> Void)?

    @ObservedObject private var saveStore = RSSLibrarySaveStore.shared
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                Task {
                    await saveStore.saveToLibrary(article)
                }
            } label: {
                Label(saveTitle, systemImage: saveIcon)
            }
            .disabled(saveStore.state(for: article) != nil)

            if let onMarkAsRead, !article.isRead {
                Button(action: onMarkAsRead) {
                    Label("Mark as Read", systemImage: "envelope.open")
                }
            }

            if let url = URL(string: article.link) {
                Button {
                    openURL(url)
                } label: {
                    Label("Read Original", systemImage: "safari")
                }

                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var saveTitle: String {
        switch saveStore.state(for: article) {
        case .saving:
            return "Saving to Library…"
        case .saved:
            return "Saved to Library"
        case nil:
            return "Save to Library"
        }
    }

    private var saveIcon: String {
        switch saveStore.state(for: article) {
        case .saving:
            return "arrow.triangle.2.circlepath"
        case .saved:
            return "checkmark"
        case nil:
            return "bookmark"
        }
    }
}

extension View {
    /// Action menu su long press per un articolo del feed.
    func rssArticleContextMenu(
        article: RSSArticle,
        onMarkAsRead: (() -> Void)? = nil
    ) -> some View {
        modifier(RSSArticleContextMenuModifier(article: article, onMarkAsRead: onMarkAsRead))
    }
}
