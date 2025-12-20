const iconv = require('iconv-lite');
const jschardet = require('jschardet');
// const gotScraping = ... (moved to async function)

const url = 'https://www.ilpost.it/2025/12/19/roberto-dipiazza-comandare-da-una-donna-frase-sessista/';

// Copying detectEncoding from parse.js
function detectEncoding(buffer, contentTypeHeader) {
	let declaredEncoding = null;

	if (contentTypeHeader) {
		const charsetMatch = contentTypeHeader.match(/charset=([^;]+)/i);
		if (charsetMatch) {
			const charset = charsetMatch[1].trim().replace(/['"]/g, '');
			if (iconv.encodingExists(charset)) {
				declaredEncoding = charset;
			}
		}
	}

	if (!declaredEncoding) {
		const htmlStart = buffer.slice(0, 2048).toString('ascii');

		const html5Match = htmlStart.match(/<meta\s+charset=["']?([^"'\s>]+)/i);
		if (html5Match) {
			const charset = html5Match[1];
			if (iconv.encodingExists(charset)) {
				declaredEncoding = charset;
			}
		}

		if (!declaredEncoding) {
			const httpEquivMatch = htmlStart.match(/<meta\s+http-equiv=["']?content-type["']?\s+content=["']?[^"'>]*charset=([^"'\s>]+)/i);
			if (httpEquivMatch) {
				const charset = httpEquivMatch[1];
				if (iconv.encodingExists(charset)) {
					declaredEncoding = charset;
				}
			}
		}

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

	const detected = jschardet.detect(buffer);
	console.log(`Charset detection - Declared: ${declaredEncoding}, Detected: ${detected.encoding} (confidence: ${detected.confidence})`);

	if (declaredEncoding && detected.encoding) {
		const normalizedDeclared = declaredEncoding.toLowerCase().replace(/[-_]/g, '');
		const normalizedDetected = detected.encoding.toLowerCase().replace(/[-_]/g, '');

		if (normalizedDeclared === normalizedDetected) {
			console.log(`Using declared encoding: ${declaredEncoding}`);
			return declaredEncoding;
		}

		if (detected.confidence > 0.8) {
			const detectedEncoding = mapCharsetName(detected.encoding);
			if (iconv.encodingExists(detectedEncoding)) {
				console.log(`Using detected encoding with high confidence: ${detectedEncoding}`);
				return detectedEncoding;
			}
		}

		console.log(`Using declared encoding (low detection confidence): ${declaredEncoding}`);
		return declaredEncoding;
	}

	if (detected.encoding && detected.confidence > 0.7) {
		const detectedEncoding = mapCharsetName(detected.encoding);
		if (iconv.encodingExists(detectedEncoding)) {
			console.log(`Using detected encoding: ${detectedEncoding}`);
			return detectedEncoding;
		}
	}

	if (declaredEncoding) {
		console.log(`Using declared encoding (no detection): ${declaredEncoding}`);
		return declaredEncoding;
	}

	console.log('Defaulting to UTF-8');
	return 'utf-8';
}

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

async function run() {
	try {
		const { gotScraping } = await import('got-scraping');
		console.log(`Fetching URL: ${url}`);
		const response = await gotScraping({
			url,
			responseType: 'buffer',
			// mimic the real call options
			headerGeneratorOptions: {
				browsers: [{ name: 'chrome', minVersion: 110 }, { name: 'firefox', minVersion: 110 }],
				devices: ['desktop'],
				locales: ['en-US', 'it-IT'],
				operatingSystems: ['windows', 'linux', 'macos'],
			},
		});

		const contentTypeHeader = response.headers['content-type'];
		console.log('Content-Type:', contentTypeHeader);

		let detectedEncoding = detectEncoding(response.body, contentTypeHeader);
		console.log(`Using encoding: ${detectedEncoding}`);

		let content = iconv.decode(response.body, detectedEncoding);

		const replacementCharCount = (content.match(/\uFFFD/g) || []).length;
		console.log(`Replacement characters found: ${replacementCharCount}`);

		if (replacementCharCount > 0) {
			console.log('--- REPLACEMENT CHARACTERS DETECTED ---');
			console.log(content.substring(0, 500)); // Show snippet
		} else {
			console.log('No replacement characters.');
			// Check specific strings from the issue
			if (content.includes('Giovedì')) console.log('Found correct "Giovedì"');
			else console.log('Did NOT find "Giovedì"');

			if (content.includes('città')) console.log('Found correct "città"');
			else console.log('Did NOT find "città"');
		}

	} catch (error) {
		console.error(error);
	}
}

run();
