const { gotScraping } = require('got-scraping');
const Mercury = require('../../lib/mercury');

exports.handler = async (event) => {
	// Handle CORS preflight
	if (event.httpMethod === 'OPTIONS') {
		return {
			statusCode: 200,
			headers: {
				'Access-Control-Allow-Origin': '*',
				'Access-Control-Allow-Headers': 'Content-Type',
				'Access-Control-Allow-Methods': 'POST, OPTIONS',
			},
			body: '',
		};
	}

	if (event.httpMethod !== 'POST') {
		return {
			statusCode: 405,
			headers: { 'Access-Control-Allow-Origin': '*' },
			body: JSON.stringify({ error: 'Method not allowed' }),
		};
	}

	try {
		const { url } = JSON.parse(event.body || '{}');

		if (!url) {
			return {
				statusCode: 400,
				headers: { 'Access-Control-Allow-Origin': '*' },
				body: JSON.stringify({ error: 'URL is required' }),
			};
		}

		console.log(`Fetching URL with got-scraping: ${url}`);

		// Use got-scraping to mimic a real browser request (TLS, headers, etc)
		const response = await gotScraping({
			url,
			headerGeneratorOptions: {
				browsers: [{ name: 'chrome', minVersion: 120 }],
				devices: ['desktop'],
				locales: ['en-US', 'en'],
				operatingSystems: ['windows', 'macos'],
			}
		});

		console.log(`Fetched status: ${response.statusCode}`);
		if (response.statusCode !== 200) {
			console.warn(`Non-200 status: ${response.statusCode}, Body preview: ${response.body.substring(0, 500)}`);
		}

		console.log('Parsing content with Mercury...');
		// Pass the HTML directly to Mercury
		const result = await Mercury.parse(url, { html: response.body });

		return {
			statusCode: 200,
			headers: {
				'Content-Type': 'application/json',
				'Access-Control-Allow-Origin': '*',
			},
			body: JSON.stringify(result),
		};

	} catch (error) {
		console.error('Parse error:', error);
		return {
			statusCode: 500,
			headers: { 'Access-Control-Allow-Origin': '*' },
			body: JSON.stringify({
				error: 'Failed to process URL',
				details: error.message,
				stack: error.stack
			}),
		};
	}
};
