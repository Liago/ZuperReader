/**
 * Custom extractor for unaparolaalgiorno.it
 * Handles word definition articles with minimal cleaning to preserve content
 */
module.exports = {
	domain: 'unaparolaalgiorno.it',
	title: {
		selectors: [
			'article.word h1',
			'h1',
			['meta[property="og:title"]', 'value'],
		],
	},
	author: {
		selectors: [
			['meta[name="author"]', 'value'],
		],
	},
	date_published: {
		selectors: [
			['meta[property="article:published_time"]', 'value'],
			'.word-datapub',
		],
	},
	lead_image_url: {
		selectors: [
			['meta[property="og:image"]', 'value'],
		],
	},
	content: {
		selectors: [
			// Use only the most specific selector
			'article.word .content',
		],
		clean: [
			'.social-share-container',
			'.social-share',
			'#quiz-section-container',
			'#daily-quiz-section',
			'script',
			'style',
			'.newsletter-box',
			'#comments-container',
			'#next-section-container',
		],
		// Don't clean too aggressively - keep all text content
		defaultCleaner: false,
	},
	excerpt: {
		selectors: [
			['meta[name="description"]', 'value'],
			['meta[property="og:description"]', 'value'],
			'.word-significato',
		],
	},
};
