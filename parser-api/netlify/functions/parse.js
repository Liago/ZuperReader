const chromium = require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core');
const Mercury = require('@postlight/mercury-parser');

const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'Content-Type',
	'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

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

	let browser = null;
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

		console.log(`Launching browser for URL: ${url}`);

		// Setup Chromium for Lambda
		// Wrap launch in try/catch to catch startup errors specifically
		try {
			browser = await puppeteer.launch({
				args: chromium.args,
				defaultViewport: chromium.defaultViewport,
				executablePath: await chromium.executablePath(),
				headless: chromium.headless,
				ignoreHTTPSErrors: true,
			});
		} catch (launchError) {
			console.error('Failed to launch browser:', launchError);
			return {
				statusCode: 500,
				headers: CORS_HEADERS,
				body: JSON.stringify({
					error: 'Failed to launch browser',
					details: launchError.message
				}),
			};
		}

		const page = await browser.newPage();

		await page.setRequestInterception(true);
		page.on('request', (req) => {
			if (['image', 'stylesheet', 'font', 'media'].includes(req.resourceType())) {
				req.abort();
			} else {
				req.continue();
			}
		});

		// mimic real browser to bypass generic bot detection
		await page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36');

		console.log('Navigating to page...');
		// Optimize: Wait for DOM ready instead of network idle to speed up processing
		// Increased timeout to 30s to be safe
		await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });

		// Extra safety check: fail if title indicates we are still challenged
		const isCloudflare = async () => {
			const t = await page.title();
			const c = await page.content();
			return t.includes('Just a moment') ||
				t.includes('Cloudflare') ||
				c.includes('Verifying you are human') ||
				c.includes('genesys.com') ||
				c.includes('needs to review the security');
		};

		let retries = 0;
		const MAX_RETRIES = 5;

		if (await isCloudflare()) {
			console.log('Detected Cloudflare challenge initially, entering wait loop...');

			while ((await isCloudflare()) && retries < MAX_RETRIES) {
				console.log(`Still seeing Cloudflare challenge (attempt ${retries + 1}/${MAX_RETRIES}), waiting 4s...`);
				await new Promise(r => setTimeout(r, 4000));
				retries++;
			}

			if (await isCloudflare()) {
				console.log('Exceeded max retries, challenge still present. Attempting to parse anyway...');
			} else {
				console.log('Cloudflare challenge appears to have cleared.');
			}
		}

		const content = await page.content();
		console.log('Content retrieved, length:', content.length);

		console.log('Parsing with Mercury...');
		const result = await Mercury.parse(url, { html: content });

		return {
			statusCode: 200,
			headers: {
				...CORS_HEADERS,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(result),
		};

	} catch (error) {
		console.error('Puppeteer/Parse error:', error);
		return {
			statusCode: 500,
			headers: CORS_HEADERS,
			body: JSON.stringify({
				error: 'Failed to process URL',
				details: error.message,
				stack: error.stack
			}),
		};
	} finally {
		if (browser !== null) {
			try {
				await browser.close();
			} catch (closeError) {
				console.error('Error closing browser:', closeError);
			}
		}
	}
};
