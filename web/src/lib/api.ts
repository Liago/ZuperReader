import { supabase, Article } from './supabase';

const PARSE_FUNCTION_URL = process.env.NEXT_PUBLIC_PARSE_FUNCTION_URL || '/.netlify/functions/parse';

export async function parseArticle(url: string, userId: string): Promise<{ content: string; title: string; excerpt: string; lead_image_url: string; author: string; date_published: string; domain: string; word_count: number }> {
	const response = await fetch(PARSE_FUNCTION_URL, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ url }),
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to parse article');
	}

	return response.json();
}

export async function saveArticle(parsedData: any, userId: string): Promise<Article> {
	const urlObj = new URL(parsedData.url);
	const domain = urlObj.hostname;
	const estimatedReadTime = parsedData.word_count ? Math.ceil(parsedData.word_count / 200) : null;

	const { data, error } = await supabase
		.from('articles')
		.insert([{
			user_id: userId,
			url: parsedData.url,
			title: parsedData.title || 'Untitled',
			content: parsedData.content,
			excerpt: parsedData.excerpt,
			image_url: parsedData.lead_image_url,
			author: parsedData.author,
			published_date: parsedData.date_published,
			domain: domain,
			estimated_read_time: estimatedReadTime,
		}])
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function getArticles(userId: string): Promise<Article[]> {
	const { data, error } = await supabase
		.from('articles')
		.select('*')
		.eq('user_id', userId)
		.order('created_at', { ascending: false });

	if (error) throw new Error(error.message);
	return data || [];
}

export async function getArticleById(id: string): Promise<Article | null> {
	const { data, error } = await supabase
		.from('articles')
		.select('*')
		.eq('id', id)
		.single();

	if (error) return null;
	return data;
}

export async function deleteArticle(articleId: string): Promise<void> {
	const { error } = await supabase
		.from('articles')
		.delete()
		.eq('id', articleId);

	if (error) throw new Error(error.message);
}

export async function toggleFavorite(articleId: string, isFavorite: boolean): Promise<void> {
	const { error } = await supabase
		.from('articles')
		.update({ is_favorite: isFavorite })
		.eq('id', articleId);

	if (error) throw new Error(error.message);
}

export async function updateReadingStatus(articleId: string, status: 'unread' | 'reading' | 'completed'): Promise<void> {
	const { error } = await supabase
		.from('articles')
		.update({ reading_status: status })
		.eq('id', articleId);

	if (error) throw new Error(error.message);
}
