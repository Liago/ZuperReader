const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'Content-Type',
	'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Cohere API configuration
const COHERE_API_KEY = process.env.COHERE_API_KEY || 'O2pO7lIlFe6nfZqyX4WhxTFE3Zgr79TCHtlVA6Vq';
const COHERE_API_URL = 'https://api.cohere.ai/v1/chat';
const COHERE_MODEL = 'command-r-08-2024'; // Recommended model for summarization

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
 * Generate AI summary using Cohere Chat API
 */
async function generateSummaryWithCohere(text, length = 'medium', format = 'summary') {
	try {
		// Command R models support 128k context length, but we'll use a conservative limit
		const maxLength = 100000;
		const truncatedText = text.length > maxLength ? text.substring(0, maxLength) : text;

		// Map length to specific instructions
		const lengthInstructions = {
			short: 'in 2-3 concise sentences',
			medium: 'in a single paragraph of 4-6 sentences',
			long: 'in 2-3 detailed paragraphs',
		};

		const lengthInstruction = lengthInstructions[length] || lengthInstructions.medium;

		// Create the summarization prompt based on format
		let prompt;
		if (format === 'bullet') {
			// Bullet point format
			prompt = `Riassumi questo articolo in stile punto elenco in lingua italiana. Utilizza il seguente formato:

[Titolo dell'articolo]
…………………………………

- [Punto chiave 1]
- [Punto chiave 2]
- [Punto chiave 3]
- [Punti aggiuntivi se necessario]

Assicurati di catturare i punti principali e le informazioni essenziali ${lengthInstruction}. Ecco il testo:

${truncatedText}`;
		} else if (format === 'periodical') {
			// Periodical/Narrative format for multiple articles
			prompt = `Sei un assistente editoriale intelligente. Il tuo compito è creare un riassunto discorsivo e coinvolgente delle letture dell'utente basato sugli articoli che ha salvato/letto di recente.

Ecco la lista degli articoli (Titolo e breve estratto):
${truncatedText}

Scrivi un racconto fluido e naturale che colleghi questi argomenti, iniziando con frasi come "In questi giorni ti sei interessato a..." oppure "Le tue letture recenti hanno spaziato da...".
Non fare un semplice elenco. Cerca di trovare fili conduttori o contrasti tra gli argomenti se possibile. Usa un tono colloquiale ma curato.
La lunghezza deve essere adeguata a una lettura piacevole (circa 2-3 paragrafi). Concludi con una breve frase di sintesi o riflessione.`;
		} else {
			// Standard summary format (default)
			prompt = `Leggi attentamente questo articolo e fornisci un riassunto dettagliato ${lengthInstruction} in lingua italiana, suddividendo le informazioni principali in sezioni. Evidenzia i punti chiave, gli argomenti essenziali e le conclusioni finali, mantenendo chiarezza e coerenza con il testo originale.

${truncatedText}`;
		}

		const response = await fetch(COHERE_API_URL, {
			method: 'POST',
			headers: {
				'Authorization': `Bearer ${COHERE_API_KEY}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				model: COHERE_MODEL,
				message: prompt,
				temperature: 0.3,
				max_tokens: 500, // Limit summary length
			}),
		});

		if (!response.ok) {
			const errorData = await response.json().catch(() => ({}));
			throw new Error(`Cohere API error: ${response.status} - ${JSON.stringify(errorData)}`);
		}

		const data = await response.json();
		return data.text;
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
		const { content, length = 'medium', format = 'summary' } = body;

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

		console.log(`Generating ${format} summary for content (${plainText.length} characters)...`);

		// Generate summary using Cohere
		const summary = await generateSummaryWithCohere(plainText, length, format);

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
