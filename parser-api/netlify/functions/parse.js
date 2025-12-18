const Mercury = require('@postlight/mercury-parser');
const he = require('he');
const iconv = require('iconv-lite');

const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'Content-Type',
	'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/**
 * Detect encoding from HTTP headers or HTML meta tags
 */
function detectEncoding(buffer, contentTypeHeader) {
	// First, try to get encoding from Content-Type header
	if (contentTypeHeader) {
		const charsetMatch = contentTypeHeader.match(/charset=([^;]+)/i);
		if (charsetMatch) {
			const charset = charsetMatch[1].trim().replace(/['"]/g, '');
			if (iconv.encodingExists(charset)) {
				return charset;
			}
		}
	}

	// If not found in headers, check HTML meta tags
	// Convert first 2KB to ASCII to search for charset declaration
	const htmlStart = buffer.slice(0, 2048).toString('ascii');

	// Check for HTML5 meta charset
	const html5Match = htmlStart.match(/<meta\s+charset=["']?([^"'\s>]+)/i);
	if (html5Match) {
		const charset = html5Match[1];
		if (iconv.encodingExists(charset)) {
			return charset;
		}
	}

	// Check for older meta http-equiv
	const httpEquivMatch = htmlStart.match(/<meta\s+http-equiv=["']?content-type["']?\s+content=["']?[^"'>]*charset=([^"'\s>]+)/i);
	if (httpEquivMatch) {
		const charset = httpEquivMatch[1];
		if (iconv.encodingExists(charset)) {
			return charset;
		}
	}

	// Check for content-type meta tag
	const contentMatch = htmlStart.match(/<meta\s+content=["']?[^"'>]*charset=([^"'\s>]+)/i);
	if (contentMatch) {
		const charset = contentMatch[1];
		if (iconv.encodingExists(charset)) {
			return charset;
		}
	}

	// Default to UTF-8
	return 'utf-8';
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

		const response = await gotScraping({
			url,
			responseType: 'buffer', // Fetch as buffer to properly handle encoding
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

		// Detect the correct encoding
		const contentTypeHeader = response.headers['content-type'];
		const detectedEncoding = detectEncoding(response.body, contentTypeHeader);
		console.log(`Detected encoding: ${detectedEncoding}`);

		// Convert to UTF-8 string
		const content = iconv.decode(response.body, detectedEncoding);
		console.log('Content retrieved, length:', content.length);

		console.log('Parsing with Mercury...');
		const result = await Mercury.parse(url, { html: content });

		// Decode HTML entities in all text fields
		if (result) {
			if (result.title) result.title = he.decode(result.title);
			if (result.content) result.content = he.decode(result.content);
			if (result.excerpt) result.excerpt = he.decode(result.excerpt);
			if (result.author) result.author = he.decode(result.author);
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
