import Foundation

// MARK: - Tag Suggestion Service
//
// Ported from web/src/lib/tagSuggestionService.ts — same keyword categories,
// domain map and scoring, adapted to run over a `ParseResult` instead of a
// saved `Article` (docs/revamp-ios/README.md · "09 Save a link").

enum TagSuggestionService {
    // MARK: Predefined tag categories with keywords

    private static let tagCategories: [String: [String]] = [
        // Technology
        "technology": ["tech", "software", "hardware", "computer", "digital", "innovation", "gadget", "device"],
        "programming": ["code", "coding", "programming", "developer", "software", "algorithm", "function", "api", "framework", "library"],
        "javascript": ["javascript", "js", "node", "nodejs", "react", "vue", "angular", "typescript", "npm"],
        "python": ["python", "django", "flask", "pandas", "numpy", "pytorch", "tensorflow"],
        "web-development": ["web", "frontend", "backend", "fullstack", "html", "css", "responsive", "website"],
        "mobile": ["mobile", "ios", "android", "app", "smartphone", "tablet", "swift", "kotlin"],
        "ai": ["artificial intelligence", "ai", "machine learning", "ml", "deep learning", "neural", "gpt", "llm", "chatgpt", "claude"],
        "cybersecurity": ["security", "cyber", "hack", "privacy", "encryption", "vulnerability", "malware", "firewall"],
        "cloud": ["cloud", "aws", "azure", "gcp", "kubernetes", "docker", "serverless", "microservices"],
        "blockchain": ["blockchain", "crypto", "bitcoin", "ethereum", "nft", "web3", "defi", "cryptocurrency"],

        // Science
        "science": ["science", "scientific", "research", "study", "experiment", "discovery", "laboratory"],
        "physics": ["physics", "quantum", "particle", "relativity", "gravity", "energy", "atom"],
        "biology": ["biology", "cell", "dna", "gene", "organism", "evolution", "species"],
        "medicine": ["medicine", "medical", "health", "doctor", "hospital", "treatment", "disease", "vaccine"],
        "space": ["space", "nasa", "rocket", "satellite", "astronaut", "mars", "moon", "planet", "astronomy"],

        // Business
        "business": ["business", "company", "corporate", "enterprise", "organization", "management"],
        "startup": ["startup", "entrepreneur", "founder", "venture", "seed", "funding", "unicorn"],
        "finance": ["finance", "financial", "money", "investment", "stock", "market", "banking", "trading"],
        "marketing": ["marketing", "brand", "advertising", "campaign", "social media", "seo", "content"],
        "economy": ["economy", "economic", "gdp", "inflation", "recession", "growth", "trade"],

        // Lifestyle
        "lifestyle": ["lifestyle", "living", "life", "daily", "routine", "habit"],
        "travel": ["travel", "trip", "vacation", "tourism", "destination", "hotel", "flight", "adventure"],
        "food": ["food", "recipe", "cooking", "cuisine", "restaurant", "meal", "dish", "ingredient"],
        "fitness": ["fitness", "workout", "exercise", "gym", "training", "muscle", "cardio"],
        "wellness": ["wellness", "wellbeing", "mindfulness", "meditation", "mental health", "self-care"],

        // Entertainment
        "entertainment": ["entertainment", "celebrity", "show", "performance", "talent"],
        "movies": ["movie", "film", "cinema", "director", "actor", "actress", "hollywood", "netflix"],
        "music": ["music", "song", "album", "artist", "concert", "band", "spotify", "streaming"],
        "gaming": ["gaming", "game", "video game", "esports", "playstation", "xbox", "nintendo", "steam"],
        "sports": ["sports", "football", "soccer", "basketball", "tennis", "olympic", "athlete", "championship"],

        // Education
        "education": ["education", "learning", "school", "university", "student", "course", "teacher"],
        "tutorial": ["tutorial", "guide", "how to", "step by step", "learn", "beginner", "introduction"],
        "career": ["career", "job", "employment", "resume", "interview", "hiring", "salary", "work"],

        // News & Politics
        "news": ["news", "breaking", "headline", "report", "update", "announcement"],
        "politics": ["politics", "political", "government", "election", "president", "congress", "law", "policy"],
        "world": ["world", "global", "international", "country", "nation", "foreign"],

        // Other
        "design": ["design", "ui", "ux", "graphic", "creative", "visual", "aesthetic", "figma"],
        "productivity": ["productivity", "efficiency", "time management", "organization", "tools", "workflow"],
        "environment": ["environment", "climate", "sustainability", "green", "eco", "renewable", "carbon"],
        "data": ["data", "analytics", "database", "sql", "big data", "visualization", "statistics"]
    ]

    // MARK: Domain to tag mapping for quick categorization

    private static let domainTagsMap: [String: [String]] = [
        "github.com": ["programming", "open-source"],
        "stackoverflow.com": ["programming", "tutorial"],
        "medium.com": ["blog", "opinion"],
        "dev.to": ["programming", "web-development"],
        "techcrunch.com": ["technology", "startup", "news"],
        "wired.com": ["technology", "science"],
        "theverge.com": ["technology", "gadgets"],
        "arstechnica.com": ["technology", "science"],
        "hackernews.com": ["technology", "startup"],
        "news.ycombinator.com": ["technology", "startup"],
        "bbc.com": ["news", "world"],
        "cnn.com": ["news"],
        "nytimes.com": ["news", "opinion"],
        "theguardian.com": ["news", "world"],
        "forbes.com": ["business", "finance"],
        "bloomberg.com": ["business", "finance", "news"],
        "reuters.com": ["news", "world"],
        "nature.com": ["science", "research"],
        "sciencedaily.com": ["science", "research"],
        "nasa.gov": ["space", "science"],
        "youtube.com": ["video", "entertainment"],
        "spotify.com": ["music", "entertainment"],
        "netflix.com": ["movies", "entertainment"],
        "amazon.com": ["shopping", "e-commerce"],
        "producthunt.com": ["startup", "technology", "product"],
        "dribbble.com": ["design", "creative"],
        "behance.net": ["design", "creative"],
        "figma.com": ["design", "ui"],
        "arxiv.org": ["research", "science", "ai"],
        "openai.com": ["ai", "technology"],
        "anthropic.com": ["ai", "technology"],
        "huggingface.co": ["ai", "machine-learning"]
    ]

    // MARK: Public API

    /// Suggests up to 8 tags for a just-parsed link, in priority order:
    /// domain, title, excerpt, content, reading-time complexity, author.
    static func suggestedTags(for result: ParseResult) -> [String] {
        var tags: [String] = []
        var seen = Set<String>()
        func add(_ tag: String) {
            guard seen.insert(tag).inserted else { return }
            tags.append(tag)
        }

        domainTags(for: result.domain).forEach(add)

        matchCategories(extractKeywords(result.title ?? "")).forEach(add)

        if let excerpt = result.excerpt {
            matchCategories(extractKeywords(excerpt)).forEach(add)
        }

        if let content = result.content {
            let stripped = content.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            let collapsed = stripped.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            matchCategories(extractKeywords(String(collapsed.prefix(2000)))).forEach(add)
        }

        if let wordCount = result.wordCount {
            let readTime = Int(ceil(Double(wordCount) / 200.0))
            if readTime <= 3 {
                add("quick-read")
            } else if readTime <= 10 {
                add("medium-read")
            } else {
                add("long-read")
            }
        }

        if let author = result.author?.lowercased(), author.contains("official") || author.contains("team") {
            add("official")
        }

        return Array(tags.prefix(8))
    }

    // MARK: Keyword extraction

    private static func extractKeywords(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let cleaned = text.lowercased()
            .replacingOccurrences(of: "[^\\w\\s-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let words = cleaned.split(separator: " ").map(String.init).filter { $0.count > 3 }

        var counts: [String: Int] = [:]
        for word in words {
            counts[word, default: 0] += 1
        }

        return counts.sorted { $0.value > $1.value }.prefix(50).map { $0.key }
    }

    private static func matchCategories(_ keywords: [String]) -> [String] {
        var matched: [String: Int] = [:]
        for keyword in keywords {
            for (tag, categoryKeywords) in tagCategories {
                for categoryKeyword in categoryKeywords where keyword.contains(categoryKeyword) || categoryKeyword.contains(keyword) {
                    matched[tag, default: 0] += 1
                }
            }
        }
        return matched.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }

    private static func domainTags(for domain: String?) -> [String] {
        guard let domain else { return [] }
        let normalized = domain.lowercased().replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)

        for (pattern, tags) in domainTagsMap where normalized.contains(pattern) || pattern.contains(normalized) {
            return tags
        }
        return []
    }
}
