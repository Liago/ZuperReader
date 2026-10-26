import Foundation

// MARK: - Article Category (smart Library grouping)
//
// Topic used by the home to group the Library. Stored in `articles.category`
// (web/supabase-migration-article-category.sql); keep the raw values aligned
// with the CHECK constraint there.

nonisolated enum ArticleCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case news
    case politics
    case business
    case technology
    case science
    case health
    case sports
    case culture
    case lifestyle
    case environment
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .news: return "News"
        case .politics: return "Politics"
        case .business: return "Business"
        case .technology: return "Technology"
        case .science: return "Science"
        case .health: return "Health"
        case .sports: return "Sports"
        case .culture: return "Culture"
        case .lifestyle: return "Lifestyle"
        case .environment: return "Environment"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .news: return "newspaper"
        case .politics: return "building.columns"
        case .business: return "chart.line.uptrend.xyaxis"
        case .technology: return "cpu"
        case .science: return "atom"
        case .health: return "heart.text.square"
        case .sports: return "sportscourt"
        case .culture: return "theatermasks"
        case .lifestyle: return "cup.and.saucer"
        case .environment: return "leaf"
        case .other: return "square.stack"
        }
    }

    /// What belongs here — fed to the language model as the category definition.
    var definition: String {
        switch self {
        case .news: return "general current affairs, breaking news, crime and local news that fit no more specific topic"
        case .politics: return "government, elections, parties, laws, public policy, diplomacy, wars and international relations"
        case .business: return "economy, companies, markets, finance, jobs, startups, personal finance"
        case .technology: return "software, hardware, internet, AI, gadgets, programming, cybersecurity, tech companies' products"
        case .science: return "research, discoveries, physics, biology, chemistry, space and astronomy, mathematics"
        case .health: return "medicine, diseases, nutrition science, mental health, fitness and wellbeing"
        case .sports: return "football, soccer, tennis, cycling, motorsport, Olympics, athletes, teams and matches"
        case .culture: return "books, cinema, TV series, music, art, theatre, history, philosophy, celebrities"
        case .lifestyle: return "travel, food and recipes, fashion, home, design, relationships, hobbies, games"
        case .environment: return "climate change, energy transition, pollution, nature, wildlife, sustainability"
        case .other: return "anything that clearly fits none of the other categories"
        }
    }

    /// Order of the shelves when two categories hold the same number of articles.
    var sortRank: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

// MARK: - Category Source

/// Who assigned the category; a higher rank is never overwritten by a lower one.
nonisolated enum ArticleCategorySource: String, Codable, Sendable {
    case user
    case model
    case heuristic

    var rank: Int {
        switch self {
        case .user: return 3
        case .model: return 2
        case .heuristic: return 1
        }
    }
}

// MARK: - Category Assignment

nonisolated struct ArticleCategoryAssignment: Codable, Equatable, Sendable {
    let category: ArticleCategory
    let source: ArticleCategorySource
}

extension Article {
    /// The category stored in Supabase, if any (nil before the migration or
    /// before the article was first categorized).
    var remoteCategoryAssignment: ArticleCategoryAssignment? {
        guard let raw = category, let category = ArticleCategory(rawValue: raw) else { return nil }
        let source = categorySource.flatMap(ArticleCategorySource.init(rawValue:)) ?? .heuristic
        return ArticleCategoryAssignment(category: category, source: source)
    }
}
