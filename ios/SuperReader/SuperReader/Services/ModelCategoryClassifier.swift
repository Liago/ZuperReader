import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - On-device Model Category Classifier
//
// Second pass of the smart Library grouping: Apple's on-device language
// model (Foundation Models, iOS 26+, Apple Intelligence devices) reads the
// article and picks one category through guided generation, so the answer is
// always one of `ArticleCategory`'s raw values. Private and free: nothing
// leaves the device. Returns nil when the model is unavailable or fails —
// the heuristic result is kept in that case.

enum ModelCategoryClassifier {
    /// True when the on-device model can run now (supported device, Apple
    /// Intelligence enabled, model downloaded).
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel(useCase: .contentTagging).isAvailable
        }
        #endif
        return false
    }

    static func classify(_ input: CategoryInput) async -> ArticleCategory? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await FoundationModelCategoryClassifier.classify(input)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable
nonisolated struct CategoryVerdict {
    @Guide(
        description: "The one category that best describes the article's main topic",
        .anyOf(ArticleCategory.allCases.map(\.rawValue))
    )
    var category: String
}

@available(iOS 26.0, *)
private enum FoundationModelCategoryClassifier {
    /// The model's context window is small (4K tokens): keep the prompt short.
    private static let maxExcerptLength = 600
    private static let maxTextLength = 1200

    private static let instructions: String = {
        let categories = ArticleCategory.allCases
            .map { "- \($0.rawValue): \($0.definition)" }
            .joined(separator: "\n")
        return """
        You file articles saved in a read-later app into exactly one category.

        Categories:
        \(categories)

        Rules:
        - Choose the category of the article's main topic, not of a passing mention.
        - Prefer a specific category over "news"; use "news" only for general current affairs.
        - Use "other" only when no category fits.
        - Articles can be written in any language, often Italian or English.
        """
    }()

    static func classify(_ input: CategoryInput) async -> ArticleCategory? {
        let model = SystemLanguageModel(useCase: .contentTagging)
        guard model.isAvailable else { return nil }

        // A fresh session per article: sessions keep a transcript, and
        // previous articles must not bias the next answer.
        let session = LanguageModelSession(model: model, instructions: instructions)

        do {
            let response = try await session.respond(
                to: prompt(for: input),
                generating: CategoryVerdict.self,
                options: GenerationOptions(sampling: .greedy)
            )
            return ArticleCategory(rawValue: response.content.category)
        } catch {
            print("On-device categorization failed for \(input.id): \(error)")
            return nil
        }
    }

    private static func prompt(for input: CategoryInput) -> String {
        var lines = ["Title: \(input.title)"]
        if !input.domain.isEmpty {
            lines.append("Source: \(input.domain)")
        }
        lines.append("URL: \(input.url)")
        if !input.tags.isEmpty {
            lines.append("Tags: \(input.tags.joined(separator: ", "))")
        }
        if !input.excerpt.isEmpty {
            lines.append("Excerpt: \(input.excerpt.prefix(maxExcerptLength))")
        }
        if !input.text.isEmpty {
            lines.append("Text: \(input.text.prefix(maxTextLength))")
        }
        return "Categorize this article.\n\n" + lines.joined(separator: "\n")
    }
}

#endif
