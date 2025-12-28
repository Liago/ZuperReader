const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'Content-Type',
	'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Cohere API configuration
const COHERE_API_KEY = process.env.COHERE_API_KEY || 'O2pO7lIlFe6nfZqyX4WhxTFE3Zgr79TCHtlVA6Vq';
const COHERE_API_URL = 'https://api.cohere.ai/v1/summarize';

/**
 * Strip HTML tags from content to get plain text
 */
function stripHtml(html) {
	if (!html) return '';

	// Remove script and style tags with their content
	let text = html.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
	text = text.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');

	// Remove HTML tags
	text = text.replace(/<[^>]+>/g, ' ');

	// Decode common HTML entities
	text = text.replace(/&nbsp;/g, ' ');
	text = text.replace(/&amp;/g, '&');
	text = text.replace(/&lt;/g, '<');
	text = text.replace(/&gt;/g, '>');
	text = text.replace(/&quot;/g, '"');
	text = text.replace(/&#39;/g, "'");

	// Clean up whitespace
	text = text.replace(/\s+/g, ' ').trim();

	return text;
}

/**
 * Generate AI summary using Cohere API
 */
async function generateSummaryWithCohere(text, length = 'medium') {
	try {
		// Cohere has a limit of ~100k characters, but we'll use a more conservative limit
		const maxLength = 50000;
		const truncatedText = text.length > maxLength ? text.substring(0, maxLength) : text;

		const response = await fetch(COHERE_API_URL, {
			method: 'POST',
			headers: {
				'Authorization': `Bearer ${COHERE_API_KEY}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				text: truncatedText,
				length: length, // 'short', 'medium', or 'long'
				format: 'paragraph',
				extractiveness: 'medium',
				temperature: 0.3,
			}),
		});

		if (!response.ok) {
			const errorData = await response.json().catch(() => ({}));
			throw new Error(`Cohere API error: ${response.status} - ${JSON.stringify(errorData)}`);
		}

		const data = await response.json();
		return data.summary;
	} catch (error) {
		console.error('Error calling Cohere API:', error);
		throw error;
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

	try {
		const body = JSON.parse(event.body || '{}');
		const { content, length = 'medium' } = body;

		if (!content) {
			return {
				statusCode: 400,
				headers: CORS_HEADERS,
				body: JSON.stringify({ error: 'Content is required' }),
			};
		}

		// Strip HTML tags to get plain text
		const plainText = stripHtml(content);

		if (plainText.length < 100) {
			return {
				statusCode: 400,
				headers: CORS_HEADERS,
				body: JSON.stringify({ error: 'Content is too short to summarize (minimum 100 characters)' }),
			};
		}

		console.log(`Generating summary for content (${plainText.length} characters)...`);

		// Generate summary using Cohere
		const summary = await generateSummaryWithCohere(plainText, length);

		console.log('Summary generated successfully');

		return {
			statusCode: 200,
			headers: {
				...CORS_HEADERS,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				summary,
				original_length: plainText.length,
				summary_length: summary.length,
			}),
		};

	} catch (error) {
		console.error('Summary generation error:', error);
		return {
			statusCode: 500,
			headers: CORS_HEADERS,
			body: JSON.stringify({
				error: 'Failed to generate summary',
				details: error.message,
			}),
		};
	}
};
