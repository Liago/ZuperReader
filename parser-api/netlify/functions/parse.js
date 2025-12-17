const Mercury = require('../../lib/mercury');
const https = require('https');
const { URL } = require('url');

function rawRequest(url) {
	return new Promise((resolve) => {
		try {
			const parsedUrl = new URL(url);
			const options = {
				hostname: parsedUrl.hostname,
				path: parsedUrl.pathname + parsedUrl.search,
				method: 'GET',
				headers: {
					'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
					'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
					'Accept-Language': 'en-US,en;q=0.9',
					'Cache-Control': 'no-cache'
				}
			};

			const req = https.request(options, (res) => {
				let data = '';
				res.on('data', chunk => data += chunk);
				res.on('end', () => {
					resolve({
						status: res.statusCode,
						headers: res.headers,
						preview: data.substring(0, 1000) // First 1000 chars of body
					});
				});
			});

			req.on('error', e => resolve({ error: e.message }));
			req.end();
		} catch (e) {
			resolve({ error: e.message });
		}
	});
}

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

		console.log(`Parsing URL: ${url}`);
		const result = await Mercury.parse(url, {
			headers: {
				'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
				'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
				'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
				'Referer': 'https://www.google.com/',
				'Upgrade-Insecure-Requests': '1',
				'Sec-Fetch-Dest': 'document',
				'Sec-Fetch-Mode': 'navigate',
				'Sec-Fetch-Site': 'cross-site',
				'Sec-Fetch-User': '?1',
				'Cache-Control': 'max-age=0'
			}
		});

		if (result.error) {
			console.error('Mercury Parser returned error:', result);
			const debugInfo = await rawRequest(url);
			result.debug_info = debugInfo;
		}

		return {
			statusCode: 200,
			headers: {
				'Content-Type': 'application/json',
				'Access-Control-Allow-Origin': '*',
			},
			body: JSON.stringify(result), // Return full result for debugging
		};
	} catch (error) {
		console.error('Parse error:', error);
		return {
			statusCode: 500,
			headers: { 'Access-Control-Allow-Origin': '*' },
			body: JSON.stringify({ error: 'Failed to parse URL', details: error.message }),
		};
	}
};
