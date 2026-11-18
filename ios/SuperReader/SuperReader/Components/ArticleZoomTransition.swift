import SwiftUI

// MARK: - Article zoom transition (App Store "card" effect)
//
// Every article opened from a list, a shelf or a card grows out of the
// tapped element (and shrinks back into it on dismiss, also with the
// interactive drag-down), like the App Store Today cards.
//
// Usage, inside the view that owns the NavigationLink:
//
//     @Namespace private var articleZoom
//
//     NavigationLink {
//         ArticleReaderView(articleId: article.id)
//             .articleZoomDestination(id: article.id, in: articleZoom)
//     } label: { … }
//     .articleZoomSource(id: article.id, in: articleZoom)

extension View {
    /// Marks the element the article zooms out of.
    func articleZoomSource<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        cornerRadius: CGFloat = CornerRadius.card
    ) -> some View {
        matchedTransitionSource(id: id, in: namespace) { source in
            source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Applies the zoom transition to the pushed reader.
    func articleZoomDestination<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        navigationTransition(.zoom(sourceID: id, in: namespace))
    }
}
