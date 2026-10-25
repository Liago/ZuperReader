import Foundation
import NaturalLanguage

// MARK: - Category Input

/// What the classifiers read about an article: a Sendable snapshot, so the
/// work can leave the main actor.
nonisolated struct CategoryInput: Sendable {
    let id: String
    let title: String
    let excerpt: String
    let url: String
    let domain: String
    let tags: [String]
    /// Plain-text start of the body (empty when the row was loaded without content).
    let text: String
}

extension Article {
    var categoryInput: CategoryInput {
        let plainText = content.map { String($0.prefix(8000)).strippingHTML() } ?? ""
        return CategoryInput(
            id: id,
            title: title,
            excerpt: excerpt ?? "",
            url: url,
            domain: domain ?? URL(string: url)?.host ?? "",
            tags: tags,
            text: String(plainText.prefix(1500))
        )
    }
}

// MARK: - Heuristic Category Classifier
//
// Instant, offline fallback (and first pass) of the smart Library grouping.
// It adds up independent signals, strongest first:
//  1. known publisher domain (gazzetta.it → Sports, nature.com → Science…);
//  2. site section in the URL ("/sport/…", "/economia/…", "tech.example.com");
//  3. the article's tags;
//  4. Italian + English keywords in title, tags, excerpt and body;
//  5. semantic similarity (NLEmbedding sentence vectors) between the title +
//     excerpt and a definition of each category, in the article's language.
// The best total wins; weak evidence falls back to `.other`.

actor HeuristicCategoryClassifier {
    static let shared = HeuristicCategoryClassifier()

    nonisolated private enum Weight {
        static let domain = 6.0
        static let generalNewsDomain = 2.0
        static let urlSection = 4.0
        static let tag = 4.0
        static let titleKeyword = 3.0
        static let tagKeyword = 2.0
        static let excerptKeyword = 1.5
        static let bodyKeyword = 0.5
        /// Multiplies the similarity margin over the mean of all categories.
        static let semantic = 12.0
        static let semanticCap = 3.0
        /// Matches counted per field, so a long body can't drown the title.
        static let keywordCap = 5
    }

    /// Below this total the evidence is too weak to pick a topic.
    nonisolated private static let minimumScore = 2.0

    nonisolated private struct CompiledKeywords: Sendable {
        var words: Set<String> = []
        var stems: [String] = []
        var phrases: [String] = []
    }

    nonisolated private static let compiledKeywords: [ArticleCategory: CompiledKeywords] = {
        var compiled: [ArticleCategory: CompiledKeywords] = [:]
        for (category, keywords) in CategoryLexicon.keywords {
            var entry = CompiledKeywords()
            for keyword in keywords {
                if keyword.contains(" ") {
                    entry.phrases.append(" \(keyword) ")
                } else if keyword.hasSuffix("*") {
                    entry.stems.append(String(keyword.dropLast()))
                } else {
                    entry.words.insert(keyword)
                }
            }
            compiled[category] = entry
        }
        return compiled
    }()

    private var embeddings: [NLLanguage: NLEmbedding] = [:]
    private var missingEmbeddings: Set<NLLanguage> = []
    private var definitionVectors: [NLLanguage: [ArticleCategory: [Double]]] = [:]

    // MARK: Public API

    func classify(_ inputs: [CategoryInput]) -> [String: ArticleCategory] {
        var results: [String: ArticleCategory] = [:]
        for input in inputs {
            results[input.id] = classify(input)
        }
        return results
    }

    func classify(_ input: CategoryInput) -> ArticleCategory {
        var scores: [ArticleCategory: Double] = [:]
        func add(_ category: ArticleCategory, _ value: Double) {
            scores[category, default: 0] += value
        }

        // 1. Publisher domain
        let host = Self.normalizedHost(for: input)
        if let category = Self.domainCategory(for: host) {
            add(category, Weight.domain)
        } else if Self.matchesDomain(host, in: CategoryLexicon.generalNewsDomains) {
            add(.news, Weight.generalNewsDomain)
        }

        // 2. Site sections (each category counted once)
        var sectionHits = Set<ArticleCategory>()
        for section in Self.sections(of: input.url, host: host) {
            if let category = CategoryLexicon.sectionCategories[section] {
                sectionHits.insert(category)
            }
        }
        sectionHits.forEach { add($0, Weight.urlSection) }

        // 3. Tags
        var tagHits = Set<ArticleCategory>()
        for tag in input.tags {
            if let category = CategoryLexicon.tagCategories[Self.normalize(tag).replacingOccurrences(of: " ", with: "-")] {
                tagHits.insert(category)
            }
        }
        tagHits.forEach { add($0, Weight.tag) }

        // 4. Keywords
        for (category, count) in Self.keywordMatches(in: input.title) {
            add(category, Double(count) * Weight.titleKeyword)
        }
        for (category, count) in Self.keywordMatches(in: input.tags.joined(separator: " ")) {
            add(category, Double(count) * Weight.tagKeyword)
        }
        for (category, count) in Self.keywordMatches(in: input.excerpt) {
            add(category, Double(count) * Weight.excerptKeyword)
        }
        for (category, count) in Self.keywordMatches(in: input.text) {
            add(category, Double(count) * Weight.bodyKeyword)
        }

        // 5. Semantic similarity
        let semanticText = [input.title, String(input.excerpt.prefix(400))]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        for (category, value) in semanticScores(for: semanticText) {
            add(category, value)
        }

        let ranked = scores
            .filter { $0.key != .other }
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key.sortRank < rhs.key.sortRank : lhs.value > rhs.value
            }

        guard let best = ranked.first, best.value >= Self.minimumScore else { return .other }
        return best.key
    }

    // MARK: Semantic similarity

    private func semanticScores(for text: String) -> [ArticleCategory: Double] {
        guard text.count >= 12 else { return [:] }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.italian, .english]
        recognizer.processString(text)
        let language: NLLanguage = recognizer.dominantLanguage == .italian ? .italian : .english

        guard let embedding = embedding(for: language),
              let textVector = embedding.vector(for: text) else { return [:] }

        let definitions = categoryVectors(for: language, embedding: embedding)
        guard !definitions.isEmpty else { return [:] }

        var similarities: [ArticleCategory: Double] = [:]
        for (category, vector) in definitions {
            similarities[category] = Self.cosine(textVector, vector)
        }

        let mean = similarities.values.reduce(0, +) / Double(similarities.count)
        var scores: [ArticleCategory: Double] = [:]
        for (category, similarity) in similarities where similarity > mean {
            scores[category] = min((similarity - mean) * Weight.semantic, Weight.semanticCap)
        }
        return scores
    }

    private func embedding(for language: NLLanguage) -> NLEmbedding? {
        if let cached = embeddings[language] { return cached }
        guard !missingEmbeddings.contains(language) else { return nil }

        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            missingEmbeddings.insert(language)
            return nil
        }
        embeddings[language] = embedding
        return embedding
    }

    private func categoryVectors(for language: NLLanguage, embedding: NLEmbedding) -> [ArticleCategory: [Double]] {
        if let cached = definitionVectors[language] { return cached }

        var vectors: [ArticleCategory: [Double]] = [:]
        for category in ArticleCategory.allCases where category != .other {
            let definition = language == .italian
                ? (CategoryLexicon.italianDefinitions[category] ?? category.definition)
                : "\(category.displayName): \(category.definition)"
            if let vector = embedding.vector(for: definition) {
                vectors[category] = vector
            }
        }
        definitionVectors[language] = vectors
        return vectors
    }

    nonisolated private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for index in a.indices {
            dot += a[index] * b[index]
            normA += a[index] * a[index]
            normB += b[index] * b[index]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }

    // MARK: Keywords

    nonisolated private static func keywordMatches(in text: String) -> [ArticleCategory: Int] {
        guard !text.isEmpty else { return [:] }

        let normalized = normalize(text)
        let tokens = Set(normalized.split(separator: " ").map(String.init))
        let padded = " \(normalized) "

        var matches: [ArticleCategory: Int] = [:]
        for (category, keywords) in compiledKeywords {
            var count = keywords.words.intersection(tokens).count
            for stem in keywords.stems where tokens.contains(where: { $0.hasPrefix(stem) }) {
                count += 1
            }
            for phrase in keywords.phrases where padded.contains(phrase) {
                count += 1
            }
            if count > 0 {
                matches[category] = min(count, Weight.keywordCap)
            }
        }
        return matches
    }

    // MARK: Domains & URL sections

    nonisolated private static func normalizedHost(for input: CategoryInput) -> String {
        let host = URL(string: input.url)?.host ?? input.domain
        return host.lowercased().replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    nonisolated private static func domainCategory(for host: String) -> ArticleCategory? {
        guard !host.isEmpty else { return nil }
        // Most specific first: "sport.sky.it" before "sky.it".
        var candidate = host
        while true {
            if let category = CategoryLexicon.domainCategories[candidate] { return category }
            guard let dot = candidate.firstIndex(of: ".") else { return nil }
            candidate = String(candidate[candidate.index(after: dot)...])
            if !candidate.contains(".") { return nil }
        }
    }

    nonisolated private static func matchesDomain(_ host: String, in domains: Set<String>) -> Bool {
        domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    /// Subdomain labels ("tech" in tech.example.com) and the first path
    /// segments ("/sport/calcio/…"), where publishers put their sections.
    nonisolated private static func sections(of urlString: String, host: String) -> [String] {
        var sections: [String] = []

        let labels = host.split(separator: ".").map(String.init)
        if labels.count > 2 {
            sections.append(contentsOf: labels.dropLast(2))
        }

        if let url = URL(string: urlString) {
            let segments = url.pathComponents
                .filter { $0 != "/" }
                .prefix(3)
                .map { normalize($0).replacingOccurrences(of: " ", with: "-") }
            sections.append(contentsOf: segments)
        }
        return sections
    }

    // MARK: Normalization

    /// Lowercase, no diacritics, punctuation turned into single spaces.
    nonisolated private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
