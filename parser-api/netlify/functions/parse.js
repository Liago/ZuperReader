const Mercury = require('@postlight/mercury-parser');
const he = require('he');
const iconv = require('iconv-lite');
const jschardet = require('jschardet');

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
			'article.word .content',
			'.word .content',
			'article.word',
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
 * Detect encoding from HTTP headers, HTML meta tags, and content analysis
 */
function detectEncoding(buffer, contentTypeHeader) {
	let declaredEncoding = null;

	// First, try to get encoding from Content-Type header
	if (contentTypeHeader) {
		const charsetMatch = contentTypeHeader.match(/charset=([^;]+)/i);
		if (charsetMatch) {
			const charset = charsetMatch[1].trim().replace(/['"]/g, '');
			if (iconv.encodingExists(charset)) {
				declaredEncoding = charset;
			}
		}
	}

	// If not found in headers, check HTML meta tags
	// Convert first 2KB to ASCII to search for charset declaration
	if (!declaredEncoding) {
		const htmlStart = buffer.slice(0, 2048).toString('ascii');

		// Check for HTML5 meta charset
		const html5Match = htmlStart.match(/<meta\s+charset=["']?([^"'\s>]+)/i);
		if (html5Match) {
			const charset = html5Match[1];
			if (iconv.encodingExists(charset)) {
				declaredEncoding = charset;
			}
		}

		// Check for older meta http-equiv
		if (!declaredEncoding) {
			const httpEquivMatch = htmlStart.match(/<meta\s+http-equiv=["']?content-type["']?\s+content=["']?[^"'>]*charset=([^"'\s>]+)/i);
			if (httpEquivMatch) {
				const charset = httpEquivMatch[1];
				if (iconv.encodingExists(charset)) {
					declaredEncoding = charset;
				}
			}
		}

		// Check for content-type meta tag
		if (!declaredEncoding) {
			const contentMatch = htmlStart.match(/<meta\s+content=["']?[^"'>]*charset=([^"'\s>]+)/i);
			if (contentMatch) {
				const charset = contentMatch[1];
				if (iconv.encodingExists(charset)) {
					declaredEncoding = charset;
				}
			}
		}
	}

	// Use content-based detection with jschardet as additional validation
	const detected = jschardet.detect(buffer);
	console.log(`Charset detection - Declared: ${declaredEncoding}, Detected: ${detected.encoding} (confidence: ${detected.confidence})`);

	// If we have a declared encoding and high confidence detection, compare them
	if (declaredEncoding && detected.encoding) {
		const normalizedDeclared = declaredEncoding.toLowerCase().replace(/[-_]/g, '');
		const normalizedDetected = detected.encoding.toLowerCase().replace(/[-_]/g, '');

		// If they match, use declared encoding
		if (normalizedDeclared === normalizedDetected) {
			console.log(`Using declared encoding: ${declaredEncoding}`);
			return declaredEncoding;
		}

		// If detection has high confidence (>0.8), prefer detected encoding
		if (detected.confidence > 0.8) {
			const detectedEncoding = mapCharsetName(detected.encoding);
			if (iconv.encodingExists(detectedEncoding)) {
				console.log(`Using detected encoding with high confidence: ${detectedEncoding}`);
				return detectedEncoding;
			}
		}

		// Otherwise, use declared encoding
		console.log(`Using declared encoding (low detection confidence): ${declaredEncoding}`);
		return declaredEncoding;
	}

	// If only detected encoding is available
	if (detected.encoding && detected.confidence > 0.7) {
		const detectedEncoding = mapCharsetName(detected.encoding);
		if (iconv.encodingExists(detectedEncoding)) {
			console.log(`Using detected encoding: ${detectedEncoding}`);
			return detectedEncoding;
		}
	}

	// If only declared encoding is available
	if (declaredEncoding) {
		console.log(`Using declared encoding (no detection): ${declaredEncoding}`);
		return declaredEncoding;
	}

	// Default to UTF-8
	console.log('Defaulting to UTF-8');
	return 'utf-8';
}

/**
 * Map charset names from jschardet to iconv-lite compatible names
 */
function mapCharsetName(charset) {
	if (!charset) return 'utf-8';

	const normalizedCharset = charset.toLowerCase();
	const charsetMap = {
		'iso-8859-1': 'latin1',
		'iso-8859-2': 'latin2',
		'windows-1252': 'win1252',
		'windows-1251': 'win1251',
		'gb2312': 'gb2312',
		'gbk': 'gbk',
		'big5': 'big5',
		'shift_jis': 'shift_jis',
		'euc-jp': 'eucjp',
		'euc-kr': 'euckr',
		'utf-8': 'utf8',
		'ascii': 'ascii',
	};

	return charsetMap[normalizedCharset] || charset;
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
		let content = iconv.decode(response.body, detectedEncoding);

		// Check if the decoded content contains replacement characters (�)
		// This indicates encoding issues
		const replacementCharCount = (content.match(/\uFFFD/g) || []).length;
		if (replacementCharCount > 0) {
			console.log(`Warning: Found ${replacementCharCount} replacement characters (�) in decoded content`);

			// Try alternative encodings commonly used for European languages
			const alternativeEncodings = ['windows-1252', 'iso-8859-1', 'utf-8'];
			let bestContent = content;
			let minReplacements = replacementCharCount;

			for (const altEncoding of alternativeEncodings) {
				if (altEncoding.toLowerCase() === detectedEncoding.toLowerCase()) continue;

				try {
					const altContent = iconv.decode(response.body, altEncoding);
					const altReplacements = (altContent.match(/\uFFFD/g) || []).length;

					console.log(`Trying ${altEncoding}: ${altReplacements} replacement characters`);

					if (altReplacements < minReplacements) {
						minReplacements = altReplacements;
						bestContent = altContent;
						console.log(`Using ${altEncoding} instead (fewer replacement characters)`);
					}
				} catch (err) {
					console.log(`Failed to decode with ${altEncoding}:`, err.message);
				}
			}

			content = bestContent;
		}

		console.log('Content retrieved, length:', content.length);

		// Decode HTML entities BEFORE parsing with Mercury
		// This ensures special characters like ŏ (o with breve) are properly decoded
		console.log('Decoding HTML entities in source...');
		content = he.decode(content);

		console.log('Parsing with Mercury...');
		const result = await Mercury.parse(url, { html: content });

		// Double-decode to catch any entities that Mercury might have escaped
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
