const Mercury = require('@postlight/mercury-parser');
const he = require('he');
// Custom extractor for unaparolaalgiorno.it
const unaparolaalgiornoltExtractor = {
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

// Add custom extractor to Mercury Parser
Mercury.addExtractor(unaparolaalgiornoltExtractor);

const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'Content-Type',
	'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/**
 * Repair mojibake - fix text where UTF-8 bytes were incorrectly decoded as ISO-8859-1
 */
function repairMojibake(text) {
	if (!text) return text;

	try {
		// Convert the string to bytes as if it were ISO-8859-1
		const bytes = Buffer.from(text, 'latin1');
		// Then decode those bytes as UTF-8
		return bytes.toString('utf-8');
	} catch (e) {
		// If repair fails, return original
		return text;
	}
}

exports.handler = async (event) => {
	// Handle CORS preflight
	if (event.httpMethod === 'OPTIONS') {
		return {
			statusCode: 200,
			headers: CORS_HEADERS,
			body: '',
		};
	}

	if (event.httpMethod !== 'POST') {
		return {
			statusCode: 405,
			headers: CORS_HEADERS,
			body: JSON.stringify({ error: 'Method not allowed' }),
		};
	}

	let url = '';

	try {
		const body = JSON.parse(event.body || '{}');
		url = body.url;

		if (!url) {
			return {
				statusCode: 400,
				headers: CORS_HEADERS,
				body: JSON.stringify({ error: 'URL is required' }),
			};
		}

		console.log(`Fetching URL with got-scraping: ${url}`);

		// Load got-scraping dynamically (ESM module)
		const { gotScraping } = await import('got-scraping');

		// Use got-scraping with default settings (auto-decodes based on headers/content)
		const response = await gotScraping({
			url,
			// responseType: 'text' is the default, which handles encoding automatically
			headerGeneratorOptions: {
				browsers: [
					{
						name: 'chrome',
						minVersion: 110,
					},
					{
						name: 'firefox',
						minVersion: 110,
					}
				],
				devices: ['desktop'],
				locales: ['en-US', 'it-IT'],
				operatingSystems: ['windows', 'linux', 'macos'],
			},
		});

		const content = response.body;

		// Log encoding information for debugging
		console.log(`Content Type: ${response.headers['content-type']}`);
		console.log('Content retrieved, length:', content.length);

		console.log('Parsing with Mercury...');
		const result = await Mercury.parse(url, { html: content });

		// Decode HTML entities in all text fields after Mercury parsing
		if (result) {
			if (result.title) result.title = he.decode(result.title);
			if (result.content) result.content = he.decode(result.content);
			if (result.excerpt) result.excerpt = he.decode(result.excerpt);
			if (result.author) result.author = he.decode(result.author);
		}

		// For unaparolaalgiorno.it, repair mojibake (UTF-8 decoded as ISO-8859-1)
		if (url.includes('unaparolaalgiorno.it') && result) {
			console.log('Repairing mojibake for unaparolaalgiorno.it');
			if (result.title) result.title = repairMojibake(result.title);
			if (result.content) result.content = repairMojibake(result.content);
			if (result.excerpt) result.excerpt = repairMojibake(result.excerpt);
			if (result.author) result.author = repairMojibake(result.author);
		}

		return {
			statusCode: 200,
			headers: {
				...CORS_HEADERS,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(result),
		};

	} catch (error) {
		console.error('Fetch/Parse error:', error);
		return {
			statusCode: 500,
			headers: CORS_HEADERS,
			body: JSON.stringify({
				error: 'Failed to process URL',
				details: error.message,
				stack: error.stack
			}),
		};
	}
};
