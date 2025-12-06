import { supabase, Article, Like, Comment, Share } from './supabase';

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

export async function getArticles(userId: string, limit: number = 10, offset: number = 0): Promise<{ articles: Article[], hasMore: boolean }> {
	// Fetch limit + 1 to check if there are more articles
	const { data, error } = await supabase
		.from('articles')
		.select('*')
		.eq('user_id', userId)
		.order('created_at', { ascending: false })
		.range(offset, offset + limit);

	if (error) throw new Error(error.message);

	const articles = data || [];
	const hasMore = articles.length > limit;

	// Return only the requested limit
	return {
		articles: hasMore ? articles.slice(0, limit) : articles,
		hasMore
	};
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

// ==================== LIKE FUNCTIONS ====================

export async function toggleLike(articleId: string, userId: string): Promise<{ liked: boolean; likeCount: number }> {
	// Check if user already liked this article
	const { data: existingLike } = await supabase
		.from('likes')
		.select('*')
		.eq('article_id', articleId)
		.eq('user_id', userId)
		.single();

	if (existingLike) {
		// Unlike: remove the like
		const { error: deleteLikeError } = await supabase
			.from('likes')
			.delete()
			.eq('article_id', articleId)
			.eq('user_id', userId);

		if (deleteLikeError) throw new Error(deleteLikeError.message);

		// Decrement like_count
		const { error: updateArticleError } = await supabase.rpc('decrement_like_count', { article_id: articleId });
		if (updateArticleError) {
			// Fallback if RPC doesn't exist
			const { data: article } = await supabase.from('articles').select('like_count').eq('id', articleId).single();
			const newCount = Math.max(0, (article?.like_count || 0) - 1);
			await supabase.from('articles').update({ like_count: newCount }).eq('id', articleId);
		}

		// Get updated count
		const { data: updatedArticle } = await supabase
			.from('articles')
			.select('like_count')
			.eq('id', articleId)
			.single();

		return { liked: false, likeCount: updatedArticle?.like_count || 0 };
	} else {
		// Like: add the like
		const { error: insertLikeError } = await supabase
			.from('likes')
			.insert([{ article_id: articleId, user_id: userId }]);

		if (insertLikeError) throw new Error(insertLikeError.message);

		// Increment like_count
		const { error: updateArticleError } = await supabase.rpc('increment_like_count', { article_id: articleId });
		if (updateArticleError) {
			// Fallback if RPC doesn't exist
			const { data: article } = await supabase.from('articles').select('like_count').eq('id', articleId).single();
			const newCount = (article?.like_count || 0) + 1;
			await supabase.from('articles').update({ like_count: newCount }).eq('id', articleId);
		}

		// Get updated count
		const { data: updatedArticle } = await supabase
			.from('articles')
			.select('like_count')
			.eq('id', articleId)
			.single();

		return { liked: true, likeCount: updatedArticle?.like_count || 0 };
	}
}

export async function checkIfUserLiked(articleId: string, userId: string): Promise<boolean> {
	const { data } = await supabase
		.from('likes')
		.select('*')
		.eq('article_id', articleId)
		.eq('user_id', userId)
		.single();

	return !!data;
}

export async function getLikesCount(articleId: string): Promise<number> {
	const { data } = await supabase
		.from('articles')
		.select('like_count')
		.eq('id', articleId)
		.single();

	return data?.like_count || 0;
}

// ==================== COMMENT FUNCTIONS ====================

export async function addComment(articleId: string, userId: string, content: string): Promise<Comment> {
	const { data, error } = await supabase
		.from('comments')
		.insert([{ article_id: articleId, user_id: userId, content }])
		.select()
		.single();

	if (error) throw new Error(error.message);

	// Increment comment_count
	const { error: updateArticleError } = await supabase.rpc('increment_comment_count', { article_id: articleId });
	if (updateArticleError) {
		// Fallback if RPC doesn't exist
		const { data: article } = await supabase.from('articles').select('comment_count').eq('id', articleId).single();
		const newCount = (article?.comment_count || 0) + 1;
		await supabase.from('articles').update({ comment_count: newCount }).eq('id', articleId);
	}

	return data;
}

export async function getComments(articleId: string): Promise<Comment[]> {
	const { data, error } = await supabase
		.from('comments')
		.select('*')
		.eq('article_id', articleId)
		.order('created_at', { ascending: false });

	if (error) throw new Error(error.message);
	return data || [];
}

export async function deleteComment(commentId: string, articleId: string): Promise<void> {
	const { error } = await supabase
		.from('comments')
		.delete()
		.eq('id', commentId);

	if (error) throw new Error(error.message);

	// Decrement comment_count
	const { error: updateArticleError } = await supabase.rpc('decrement_comment_count', { article_id: articleId });
	if (updateArticleError) {
		// Fallback if RPC doesn't exist
		const { data: article } = await supabase.from('articles').select('comment_count').eq('id', articleId).single();
		const newCount = Math.max(0, (article?.comment_count || 0) - 1);
		await supabase.from('articles').update({ comment_count: newCount }).eq('id', articleId);
	}
}

export async function updateComment(commentId: string, content: string): Promise<Comment> {
	const { data, error } = await supabase
		.from('comments')
		.update({ content })
		.eq('id', commentId)
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

// ==================== SHARE FUNCTIONS ====================

export async function shareArticle(articleId: string, userId: string): Promise<Share> {
	const { data, error } = await supabase
		.from('shares')
		.insert([{ article_id: articleId, user_id: userId }])
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function getSharesCount(articleId: string): Promise<number> {
	const { count, error } = await supabase
		.from('shares')
		.select('*', { count: 'exact', head: true })
		.eq('article_id', articleId);

	if (error) throw new Error(error.message);
	return count || 0;
}
