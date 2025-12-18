const chromium = require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core');
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

	let browser = null;
	let url = '';

	try {
		const body = JSON.parse(event.body || '{}');
		url = body.url;

		if (!url) {
			return {
				statusCode: 400,
				headers: { 'Access-Control-Allow-Origin': '*' },
				body: JSON.stringify({ error: 'URL is required' }),
			};
		}

		console.log(`Launching browser for URL: ${url}`);

		// Setup Chromium for Lambda
		browser = await puppeteer.launch({
			args: chromium.args,
			defaultViewport: chromium.defaultViewport,
			executablePath: await chromium.executablePath(),
			headless: chromium.headless,
			ignoreHTTPSErrors: true,
		});

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
		await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });

		// Extra safety check: fail if title indicates we are still challenged
		const title = await page.title();
		console.log(`Page title: ${title}`);

		if (title.includes('Just a moment') || title.includes('Cloudflare')) {
			// Wait a bit more if we are stuck on challenge page
			console.log('Detected Cloudflare challenge, waiting more...');
			await new Promise(r => setTimeout(r, 5000));
		}

		const content = await page.content();
		console.log('Content retrieved, length:', content.length);

		console.log('Parsing with Mercury...');
		const result = await Mercury.parse(url, { html: content });

		return {
			statusCode: 200,
			headers: {
				'Content-Type': 'application/json',
				'Access-Control-Allow-Origin': '*',
			},
			body: JSON.stringify(result),
		};

	} catch (error) {
		console.error('Puppeteer/Parse error:', error);
		return {
			statusCode: 500,
			headers: { 'Access-Control-Allow-Origin': '*' },
			body: JSON.stringify({
				error: 'Failed to process URL',
				details: error.message,
				stack: error.stack
			}),
		};
	} finally {
		if (browser !== null) {
			await browser.close();
		}
	}
};
