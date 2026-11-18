import SwiftUI
import Combine
import Auth

// MARK: - Public Link from article lists
//
// Long-press menus in the Library lists offer "Public Link". The menu item
// only records the article in `PublicLinkPresenter`; one sheet attached at
// the root (`publicLinkSheetHost()` in MainTabView) presents
// `PublicLinkSheet`, so each list does not need its own sheet state.

@MainActor
final class PublicLinkPresenter: ObservableObject {
    static let shared = PublicLinkPresenter()

    @Published var article: Article?

    private init() {}
}

/// Context-menu item that opens the public link sheet for `article`.
/// Hidden for articles the signed-in user does not own (HIG: unavailable
/// items are hidden, not dimmed).
struct PublicLinkMenuButton: View {
    let article: Article

    var body: some View {
        if isOwner {
            Button {
                PublicLinkPresenter.shared.article = article
            } label: {
                Label(
                    article.isPublicLinkActive ? "Public Link (On)" : "Public Link",
                    systemImage: "globe"
                )
            }
        }
    }

    private var isOwner: Bool {
        guard let userId = AuthManager.shared.user?.id.uuidString else { return false }
        return article.userId.lowercased() == userId.lowercased()
    }
}

private struct PublicLinkSheetHost: ViewModifier {
    @ObservedObject private var presenter = PublicLinkPresenter.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var didChange = false

    func body(content: Content) -> some View {
        content
            .sheet(item: $presenter.article, onDismiss: {
                // Lists reload so the menu label and the "Public links" view
                // reflect the new state.
                if didChange {
                    didChange = false
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshArticles"), object: nil)
                }
            }) { article in
                PublicLinkSheet(
                    articleId: article.id,
                    articleTitle: article.title,
                    initialToken: article.publicShareToken,
                    initialExpiresAt: article.publicLinkExpiresAt,
                    initialValidityDays: article.publicLinkValidityDays
                ) { _, _, _ in
                    didChange = true
                }
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    /// Presents `PublicLinkSheet` whenever a `PublicLinkMenuButton` is tapped.
    func publicLinkSheetHost() -> some View {
        modifier(PublicLinkSheetHost())
    }
}
