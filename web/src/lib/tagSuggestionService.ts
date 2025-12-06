import { Article } from './supabase';

// Predefined tag categories with keywords
const TAG_CATEGORIES: Record<string, string[]> = {
	// Technology
	'technology': ['tech', 'software', 'hardware', 'computer', 'digital', 'innovation', 'gadget', 'device'],
	'programming': ['code', 'coding', 'programming', 'developer', 'software', 'algorithm', 'function', 'api', 'framework', 'library'],
	'javascript': ['javascript', 'js', 'node', 'nodejs', 'react', 'vue', 'angular', 'typescript', 'npm'],
	'python': ['python', 'django', 'flask', 'pandas', 'numpy', 'pytorch', 'tensorflow'],
	'web-development': ['web', 'frontend', 'backend', 'fullstack', 'html', 'css', 'responsive', 'website'],
	'mobile': ['mobile', 'ios', 'android', 'app', 'smartphone', 'tablet', 'swift', 'kotlin'],
	'ai': ['artificial intelligence', 'ai', 'machine learning', 'ml', 'deep learning', 'neural', 'gpt', 'llm', 'chatgpt', 'claude'],
	'cybersecurity': ['security', 'cyber', 'hack', 'privacy', 'encryption', 'vulnerability', 'malware', 'firewall'],
	'cloud': ['cloud', 'aws', 'azure', 'gcp', 'kubernetes', 'docker', 'serverless', 'microservices'],
	'blockchain': ['blockchain', 'crypto', 'bitcoin', 'ethereum', 'nft', 'web3', 'defi', 'cryptocurrency'],

	// Science
	'science': ['science', 'scientific', 'research', 'study', 'experiment', 'discovery', 'laboratory'],
	'physics': ['physics', 'quantum', 'particle', 'relativity', 'gravity', 'energy', 'atom'],
	'biology': ['biology', 'cell', 'dna', 'gene', 'organism', 'evolution', 'species'],
	'medicine': ['medicine', 'medical', 'health', 'doctor', 'hospital', 'treatment', 'disease', 'vaccine'],
	'space': ['space', 'nasa', 'rocket', 'satellite', 'astronaut', 'mars', 'moon', 'planet', 'astronomy'],

	// Business
	'business': ['business', 'company', 'corporate', 'enterprise', 'organization', 'management'],
	'startup': ['startup', 'entrepreneur', 'founder', 'venture', 'seed', 'funding', 'unicorn'],
	'finance': ['finance', 'financial', 'money', 'investment', 'stock', 'market', 'banking', 'trading'],
	'marketing': ['marketing', 'brand', 'advertising', 'campaign', 'social media', 'seo', 'content'],
	'economy': ['economy', 'economic', 'gdp', 'inflation', 'recession', 'growth', 'trade'],

	// Lifestyle
	'lifestyle': ['lifestyle', 'living', 'life', 'daily', 'routine', 'habit'],
	'travel': ['travel', 'trip', 'vacation', 'tourism', 'destination', 'hotel', 'flight', 'adventure'],
	'food': ['food', 'recipe', 'cooking', 'cuisine', 'restaurant', 'meal', 'dish', 'ingredient'],
	'fitness': ['fitness', 'workout', 'exercise', 'gym', 'training', 'muscle', 'cardio'],
	'wellness': ['wellness', 'wellbeing', 'mindfulness', 'meditation', 'mental health', 'self-care'],

	// Entertainment
	'entertainment': ['entertainment', 'celebrity', 'show', 'performance', 'talent'],
	'movies': ['movie', 'film', 'cinema', 'director', 'actor', 'actress', 'hollywood', 'netflix'],
	'music': ['music', 'song', 'album', 'artist', 'concert', 'band', 'spotify', 'streaming'],
	'gaming': ['gaming', 'game', 'video game', 'esports', 'playstation', 'xbox', 'nintendo', 'steam'],
	'sports': ['sports', 'football', 'soccer', 'basketball', 'tennis', 'olympic', 'athlete', 'championship'],

	// Education
	'education': ['education', 'learning', 'school', 'university', 'student', 'course', 'teacher'],
	'tutorial': ['tutorial', 'guide', 'how to', 'step by step', 'learn', 'beginner', 'introduction'],
	'career': ['career', 'job', 'employment', 'resume', 'interview', 'hiring', 'salary', 'work'],

	// News & Politics
	'news': ['news', 'breaking', 'headline', 'report', 'update', 'announcement'],
	'politics': ['politics', 'political', 'government', 'election', 'president', 'congress', 'law', 'policy'],
	'world': ['world', 'global', 'international', 'country', 'nation', 'foreign'],

	// Other
	'design': ['design', 'ui', 'ux', 'graphic', 'creative', 'visual', 'aesthetic', 'figma'],
	'productivity': ['productivity', 'efficiency', 'time management', 'organization', 'tools', 'workflow'],
	'environment': ['environment', 'climate', 'sustainability', 'green', 'eco', 'renewable', 'carbon'],
	'data': ['data', 'analytics', 'database', 'sql', 'big data', 'visualization', 'statistics'],
};

// Domain to tag mapping for quick categorization
const DOMAIN_TAGS: Record<string, string[]> = {
	'github.com': ['programming', 'open-source'],
	'stackoverflow.com': ['programming', 'tutorial'],
	'medium.com': ['blog', 'opinion'],
	'dev.to': ['programming', 'web-development'],
	'techcrunch.com': ['technology', 'startup', 'news'],
	'wired.com': ['technology', 'science'],
	'theverge.com': ['technology', 'gadgets'],
	'arstechnica.com': ['technology', 'science'],
	'hackernews.com': ['technology', 'startup'],
	'news.ycombinator.com': ['technology', 'startup'],
	'bbc.com': ['news', 'world'],
	'cnn.com': ['news'],
	'nytimes.com': ['news', 'opinion'],
	'theguardian.com': ['news', 'world'],
	'forbes.com': ['business', 'finance'],
	'bloomberg.com': ['business', 'finance', 'news'],
	'reuters.com': ['news', 'world'],
	'nature.com': ['science', 'research'],
	'sciencedaily.com': ['science', 'research'],
	'nasa.gov': ['space', 'science'],
	'youtube.com': ['video', 'entertainment'],
	'spotify.com': ['music', 'entertainment'],
	'netflix.com': ['movies', 'entertainment'],
	'amazon.com': ['shopping', 'e-commerce'],
	'producthunt.com': ['startup', 'technology', 'product'],
	'dribbble.com': ['design', 'creative'],
	'behance.net': ['design', 'creative'],
	'figma.com': ['design', 'ui'],
	'arxiv.org': ['research', 'science', 'ai'],
	'openai.com': ['ai', 'technology'],
	'anthropic.com': ['ai', 'technology'],
	'huggingface.co': ['ai', 'machine-learning'],
};

// Function to extract keywords from text
function extractKeywords(text: string): string[] {
	if (!text) return [];

	// Clean and normalize text
	const cleaned = text
		.toLowerCase()
		.replace(/[^\w\s-]/g, ' ')
		.replace(/\s+/g, ' ')
		.trim();

	// Split into words and filter short ones
	const words = cleaned.split(' ').filter(word => word.length > 3);

	// Count word frequency
	const wordCount: Record<string, number> = {};
	words.forEach(word => {
		wordCount[word] = (wordCount[word] || 0) + 1;
	});

	// Return unique words sorted by frequency
	return Object.entries(wordCount)
		.sort((a, b) => b[1] - a[1])
		.slice(0, 50)
		.map(([word]) => word);
}

// Function to match keywords against tag categories
function matchTagCategories(keywords: string[]): string[] {
	const matchedTags: Record<string, number> = {};

	keywords.forEach(keyword => {
		Object.entries(TAG_CATEGORIES).forEach(([tag, categoryKeywords]) => {
			categoryKeywords.forEach(categoryKeyword => {
				if (keyword.includes(categoryKeyword) || categoryKeyword.includes(keyword)) {
					matchedTags[tag] = (matchedTags[tag] || 0) + 1;
				}
			});
		});
	});

	// Sort by match count and return top tags
	return Object.entries(matchedTags)
		.sort((a, b) => b[1] - a[1])
		.slice(0, 5)
		.map(([tag]) => tag);
}

// Function to get tags from domain
function getTagsFromDomain(domain: string | null): string[] {
	if (!domain) return [];

	const normalizedDomain = domain.toLowerCase().replace(/^www\./, '');

	for (const [domainPattern, tags] of Object.entries(DOMAIN_TAGS)) {
		if (normalizedDomain.includes(domainPattern) || domainPattern.includes(normalizedDomain)) {
			return tags;
		}
	}

	return [];
}

// Function to analyze reading time for complexity tag
function getComplexityTag(estimatedReadTime: number | null): string | null {
	if (!estimatedReadTime) return null;

	if (estimatedReadTime <= 3) return 'quick-read';
	if (estimatedReadTime <= 10) return 'medium-read';
	return 'long-read';
}

// Main function to suggest tags for an article
export function suggestTagsForArticle(article: Article): string[] {
	const suggestedTags: Set<string> = new Set();

	// 1. Get tags from domain
	const domainTags = getTagsFromDomain(article.domain);
	domainTags.forEach(tag => suggestedTags.add(tag));

	// 2. Extract keywords from title
	const titleKeywords = extractKeywords(article.title);
	const titleTags = matchTagCategories(titleKeywords);
	titleTags.forEach(tag => suggestedTags.add(tag));

	// 3. Extract keywords from excerpt
	if (article.excerpt) {
		const excerptKeywords = extractKeywords(article.excerpt);
		const excerptTags = matchTagCategories(excerptKeywords);
		excerptTags.forEach(tag => suggestedTags.add(tag));
	}

	// 4. Extract keywords from content (first 2000 characters for performance)
	if (article.content) {
		// Strip HTML tags for content analysis
		const textContent = article.content
			.replace(/<[^>]*>/g, ' ')
			.replace(/\s+/g, ' ')
			.substring(0, 2000);

		const contentKeywords = extractKeywords(textContent);
		const contentTags = matchTagCategories(contentKeywords);
		contentTags.forEach(tag => suggestedTags.add(tag));
	}

	// 5. Add complexity tag based on reading time
	const complexityTag = getComplexityTag(article.estimated_read_time);
	if (complexityTag) {
		suggestedTags.add(complexityTag);
	}

	// 6. Add author-based tag if author is well-known
	if (article.author) {
		const authorLower = article.author.toLowerCase();
		if (authorLower.includes('official') || authorLower.includes('team')) {
			suggestedTags.add('official');
		}
	}

	// Convert to array and limit to 8 suggestions
	return Array.from(suggestedTags).slice(0, 8);
}

// Function to get all available predefined tags
export function getAllPredefinedTags(): string[] {
	return Object.keys(TAG_CATEGORIES).sort();
}

// Function to search tags by query
export function searchTags(query: string): string[] {
	if (!query || query.length < 2) return [];

	const queryLower = query.toLowerCase();
	const allTags = getAllPredefinedTags();

	return allTags.filter(tag =>
		tag.toLowerCase().includes(queryLower)
	).slice(0, 10);
}

// Tag colors for display
export const TAG_COLORS: Record<string, { bg: string; text: string; border: string }> = {
	// Technology
	'technology': { bg: 'bg-blue-100', text: 'text-blue-800', border: 'border-blue-200' },
	'programming': { bg: 'bg-purple-100', text: 'text-purple-800', border: 'border-purple-200' },
	'javascript': { bg: 'bg-yellow-100', text: 'text-yellow-800', border: 'border-yellow-200' },
	'python': { bg: 'bg-green-100', text: 'text-green-800', border: 'border-green-200' },
	'web-development': { bg: 'bg-indigo-100', text: 'text-indigo-800', border: 'border-indigo-200' },
	'mobile': { bg: 'bg-pink-100', text: 'text-pink-800', border: 'border-pink-200' },
	'ai': { bg: 'bg-violet-100', text: 'text-violet-800', border: 'border-violet-200' },
	'cybersecurity': { bg: 'bg-red-100', text: 'text-red-800', border: 'border-red-200' },
	'cloud': { bg: 'bg-sky-100', text: 'text-sky-800', border: 'border-sky-200' },
	'blockchain': { bg: 'bg-orange-100', text: 'text-orange-800', border: 'border-orange-200' },

	// Science
	'science': { bg: 'bg-emerald-100', text: 'text-emerald-800', border: 'border-emerald-200' },
	'physics': { bg: 'bg-cyan-100', text: 'text-cyan-800', border: 'border-cyan-200' },
	'biology': { bg: 'bg-lime-100', text: 'text-lime-800', border: 'border-lime-200' },
	'medicine': { bg: 'bg-rose-100', text: 'text-rose-800', border: 'border-rose-200' },
	'space': { bg: 'bg-slate-100', text: 'text-slate-800', border: 'border-slate-200' },

	// Business
	'business': { bg: 'bg-amber-100', text: 'text-amber-800', border: 'border-amber-200' },
	'startup': { bg: 'bg-fuchsia-100', text: 'text-fuchsia-800', border: 'border-fuchsia-200' },
	'finance': { bg: 'bg-teal-100', text: 'text-teal-800', border: 'border-teal-200' },
	'marketing': { bg: 'bg-orange-100', text: 'text-orange-800', border: 'border-orange-200' },
	'economy': { bg: 'bg-zinc-100', text: 'text-zinc-800', border: 'border-zinc-200' },

	// Reading complexity
	'quick-read': { bg: 'bg-green-100', text: 'text-green-800', border: 'border-green-200' },
	'medium-read': { bg: 'bg-yellow-100', text: 'text-yellow-800', border: 'border-yellow-200' },
	'long-read': { bg: 'bg-red-100', text: 'text-red-800', border: 'border-red-200' },

	// Default
	'default': { bg: 'bg-gray-100', text: 'text-gray-800', border: 'border-gray-200' },
};

export function getTagColor(tag: string): { bg: string; text: string; border: string } {
	return TAG_COLORS[tag.toLowerCase()] || TAG_COLORS['default'];
}
