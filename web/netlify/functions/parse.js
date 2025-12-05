const Mercury = require('@postlight/parser');

exports.handler = async (event) => {
	// Only allow POST requests
	if (event.httpMethod !== 'POST') {
		return {
			statusCode: 405,
			body: JSON.stringify({ error: 'Method not allowed' }),
		};
	}

	try {
		const { url } = JSON.parse(event.body || '{}');

		if (!url) {
			return {
				statusCode: 400,
				body: JSON.stringify({ error: 'URL is required' }),
			};
		}

		const result = await Mercury.parse(url);

		return {
			statusCode: 200,
			headers: {
				'Content-Type': 'application/json',
				'Access-Control-Allow-Origin': '*',
				'Access-Control-Allow-Headers': 'Content-Type',
			},
			body: JSON.stringify({
				url: result.url,
				title: result.title,
				content: result.content,
				excerpt: result.excerpt,
				lead_image_url: result.lead_image_url,
				author: result.author,
				date_published: result.date_published,
				domain: result.domain,
				word_count: result.word_count,
			}),
		};
	} catch (error) {
		console.error('Parse error:', error);
		return {
			statusCode: 500,
			body: JSON.stringify({ error: 'Failed to parse URL' }),
		};
	}
};
