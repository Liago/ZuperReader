import SwiftUI

// MARK: - Category Move Menu
//
// "Move to…" submenu: a manual correction of the smart grouping. The pick is
// stored with source `user`, so no classifier overwrites it later.

struct CategoryMoveMenu: View {
    let currentCategory: ArticleCategory?
    let onSelect: (ArticleCategory) -> Void

    var body: some View {
        Menu {
            ForEach(ArticleCategory.allCases) { category in
                Button {
                    onSelect(category)
                } label: {
                    if category == currentCategory {
                        Label(category.displayName, systemImage: "checkmark")
                    } else {
                        Label(category.displayName, systemImage: category.icon)
                    }
                }
            }
        } label: {
            Label("Move to…", systemImage: "folder")
        }
    }
}

// MARK: - Library Article Menu Items
//
// Long-press menu shared by the home shelves and the category page.
// HIG · Context menus: unavailable items are hidden, not dimmed.

struct LibraryArticleMenuItems: View {
    let article: Article
    let currentCategory: ArticleCategory?
    let queueState: QueueActionState?
    let onFavorite: () -> Void
    let onAddToQueue: () -> Void
    let onMove: (ArticleCategory) -> Void
    let onDelete: () -> Void

    var body: some View {
        if queueState == nil {
            Button(action: onAddToQueue) {
                Label("Add to Up next", systemImage: "text.badge.plus")
            }
        }

        Button(action: onFavorite) {
            Label(
                article.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: article.isFavorite ? "heart.slash" : "heart"
            )
        }

        CategoryMoveMenu(currentCategory: currentCategory, onSelect: onMove)

        if let url = URL(string: article.url) {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
}
