import { createClient } from './supabase/client';
import type { Article, Comment, Share, UserProfile, Friendship, FriendshipStatus, ArticleShare, Friend, UserPreferences, RSSArticle, RSSFeed } from './supabase';

// Create a singleton supabase client for this module
const supabase = createClient();

const PARSE_FUNCTION_URL = process.env.NEXT_PUBLIC_PARSE_FUNCTION_URL || '/.netlify/functions/parse';

// ==================== SEARCH & FILTER TYPES ====================

export interface ArticleFilters {
	searchQuery?: string;
	tags?: string[];
	readingStatus?: 'unread' | 'reading' | 'completed' | 'all';
	isFavorite?: boolean;
	domain?: string;
	dateFrom?: string;
	dateTo?: string;
}

export type ArticleSortField = 'created_at' | 'published_date' | 'like_count' | 'title';
export type ArticleSortOrder = 'asc' | 'desc';

export interface ArticleSortOptions {
	field: ArticleSortField;
	order: ArticleSortOrder;
}

export async function parseArticle(url: string): Promise<{ content: string; title: string; excerpt: string; lead_image_url: string; author: string; date_published: string; domain: string; word_count: number; url: string }> {
	const response = await fetch(PARSE_FUNCTION_URL, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ url }),
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to parse article');
	}

	const data = await response.json();
	return { ...data, url };
}

export async function saveArticle(parsedData: { url: string; title: string; content: string; excerpt: string | null; lead_image_url: string | null; author: string | null; date_published: string | null; word_count: number }, userId: string): Promise<Article> {
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


export async function getArticles(
	userId: string,
	limit: number = 10,
	offset: number = 0,
	filters?: ArticleFilters,
	sort?: ArticleSortOptions
): Promise<{ articles: Article[], hasMore: boolean }> {
	// Start building the query
	let query = supabase
		.from('articles')
		.select('*')
		.eq('user_id', userId);

	// Apply full-text search if provided
	if (filters?.searchQuery && filters.searchQuery.trim()) {
		// Convert search query to tsquery format
		const tsQuery = filters.searchQuery.trim().split(/\s+/).join(' & ');
		query = query.textSearch('search_vector', tsQuery);
	}

	// Apply tag filter if provided
	if (filters?.tags && filters.tags.length > 0) {
		query = query.contains('tags', filters.tags);
	}

	// Apply reading status filter if provided
	if (filters?.readingStatus && filters.readingStatus !== 'all') {
		query = query.eq('reading_status', filters.readingStatus);
	}

	// Apply favorite filter if provided
	if (filters?.isFavorite !== undefined) {
		query = query.eq('is_favorite', filters.isFavorite);
	}

	// Apply domain filter if provided
	if (filters?.domain) {
		query = query.eq('domain', filters.domain);
	}

	// Apply date range filters if provided
	if (filters?.dateFrom) {
		query = query.gte('created_at', filters.dateFrom);
	}
	if (filters?.dateTo) {
		query = query.lte('created_at', filters.dateTo);
	}

	// Apply sorting (default to created_at desc)
	const sortField = sort?.field || 'created_at';
	const sortOrder = sort?.order || 'desc';
	const ascending = sortOrder === 'asc';

	query = query.order(sortField, { ascending });

	// Fetch limit + 1 to check if there are more articles
	query = query.range(offset, offset + limit);

	const { data, error } = await query;

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

export async function updateReadingProgress(articleId: string, progress: number): Promise<void> {
	// Ensure progress is between 0 and 100
	const clampedProgress = Math.max(0, Math.min(100, Math.round(progress)));

	const { error } = await supabase
		.from('articles')
		.update({ reading_progress: clampedProgress })
		.eq('id', articleId);

	if (error) throw new Error(error.message);
}

export async function getReadingProgress(articleId: string): Promise<number> {
	const { data, error } = await supabase
		.from('articles')
		.select('reading_progress')
		.eq('id', articleId)
		.single();

	if (error) throw new Error(error.message);
	return data?.reading_progress || 0;
}

export async function updateArticleTags(articleId: string, tags: string[]): Promise<Article> {
	const { data, error } = await supabase
		.from('articles')
		.update({ tags })
		.eq('id', articleId)
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
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

		// Decrement like_count atomically
		const { error: updateError } = await supabase.rpc('decrement_like_count', { article_id: articleId });
		if (updateError) throw new Error(updateError.message);

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

		// Increment like_count atomically
		const { error: updateError } = await supabase.rpc('increment_like_count', { article_id: articleId });
		if (updateError) throw new Error(updateError.message);

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
		.select(`
			*,
			user_profiles (
				display_name,
				avatar_url
			)
		`)
		.single();

	if (error) throw new Error(error.message);

	// Increment comment_count atomically
	const { error: updateError } = await supabase.rpc('increment_comment_count', { article_id: articleId });
	if (updateError) throw new Error(updateError.message);

	// Transform the data to flatten the user_profiles object
	const { user_profiles, ...commentData } = data;
	const comment: Comment = {
		...commentData,
		author_display_name: user_profiles?.display_name || null,
		author_avatar_url: user_profiles?.avatar_url || null,
	};

	return comment;
}

export async function getComments(articleId: string): Promise<Comment[]> {
	const { data, error } = await supabase
		.from('comments')
		.select(`
			*,
			user_profiles (
				display_name,
				avatar_url
			)
		`)
		.eq('article_id', articleId)
		.order('created_at', { ascending: false });

	if (error) throw new Error(error.message);

	// Transform the data to flatten the user_profiles object
	const comments = (data || []).map(item => {
		const { user_profiles, ...commentData } = item;
		return {
			...commentData,
			author_display_name: user_profiles?.display_name || null,
			author_avatar_url: user_profiles?.avatar_url || null,
		} as Comment;
	});

	return comments;
}

export async function deleteComment(commentId: string, articleId: string): Promise<void> {
	const { error } = await supabase
		.from('comments')
		.delete()
		.eq('id', commentId);

	if (error) throw new Error(error.message);

	// Decrement comment_count atomically
	const { error: updateError } = await supabase.rpc('decrement_comment_count', { article_id: articleId });
	if (updateError) throw new Error(updateError.message);
}

export async function updateComment(commentId: string, content: string): Promise<Comment> {
	const { data, error } = await supabase
		.from('comments')
		.update({ content })
		.eq('id', commentId)
		.select(`
			*,
			user_profiles (
				display_name,
				avatar_url
			)
		`)
		.single();

	if (error) throw new Error(error.message);

	// Transform the data to flatten the user_profiles object
	const { user_profiles, ...commentData } = data;
	const comment: Comment = {
		...commentData,
		author_display_name: user_profiles?.display_name || null,
		author_avatar_url: user_profiles?.avatar_url || null,
	};

	return comment;
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

// ==================== USER PROFILE FUNCTIONS ====================

export async function getUserProfile(userId: string): Promise<UserProfile | null> {
	const { data, error } = await supabase
		.from('user_profiles')
		.select('*')
		.eq('id', userId)
		.single();

	if (error) return null;
	return data;
}

export async function updateUserProfile(userId: string, updates: Partial<UserProfile>): Promise<UserProfile> {
	const { data, error } = await supabase
		.from('user_profiles')
		.update(updates)
		.eq('id', userId)
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function createUserProfile(userId: string, displayName: string): Promise<UserProfile> {
	const { data, error } = await supabase
		.from('user_profiles')
		.insert([{ id: userId, display_name: displayName }])
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function searchUsers(query: string, currentUserId: string): Promise<UserProfile[]> {
	// Search by display_name using ilike for case-insensitive partial match
	const { data: profileData, error: profileError } = await supabase
		.from('user_profiles')
		.select('*')
		.neq('id', currentUserId)
		.ilike('display_name', `%${query}%`)
		.limit(20);

	if (profileError) throw new Error(profileError.message);

	// We need to also get user emails for searching
	// This requires getting the user info from auth.users
	// Since we can't directly query auth.users, we'll use the view or RPC
	// For now, return profile data only
	return profileData || [];
}

// ==================== FRIENDSHIP FUNCTIONS ====================

export async function sendFriendRequest(requesterId: string, addresseeId: string): Promise<Friendship> {
	// Check if a friendship already exists
	const { data: existing } = await supabase
		.from('friendships')
		.select('*')
		.or(`and(requester_id.eq.${requesterId},addressee_id.eq.${addresseeId}),and(requester_id.eq.${addresseeId},addressee_id.eq.${requesterId})`)
		.single();

	if (existing) {
		throw new Error('A friendship request already exists between these users');
	}

	const { data, error } = await supabase
		.from('friendships')
		.insert([{ requester_id: requesterId, addressee_id: addresseeId, status: 'pending' }])
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function respondToFriendRequest(friendshipId: string, status: 'accepted' | 'rejected'): Promise<Friendship> {
	const { data, error } = await supabase
		.from('friendships')
		.update({ status })
		.eq('id', friendshipId)
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function removeFriend(friendshipId: string): Promise<void> {
	const { error } = await supabase
		.from('friendships')
		.delete()
		.eq('id', friendshipId);

	if (error) throw new Error(error.message);
}

export async function getFriends(userId: string): Promise<Friend[]> {
	// Get all accepted friendships where user is either requester or addressee
	const { data, error } = await supabase
		.from('friendships')
		.select(`
			id,
			requester_id,
			addressee_id,
			status,
			created_at,
			requester:user_profiles!friendships_requester_id_fkey(*),
			addressee:user_profiles!friendships_addressee_id_fkey(*)
		`)
		.eq('status', 'accepted')
		.or(`requester_id.eq.${userId},addressee_id.eq.${userId}`);

	if (error) throw new Error(error.message);

	// Transform data to Friend array
	return (data || []).map(friendship => {
		const isRequester = friendship.requester_id === userId;
		// Supabase returns arrays for joins, so we need to get the first element
		const friendProfile = isRequester
			? (Array.isArray(friendship.addressee) ? friendship.addressee[0] : friendship.addressee)
			: (Array.isArray(friendship.requester) ? friendship.requester[0] : friendship.requester);

		return {
			friendship_id: friendship.id,
			user: friendProfile as unknown as UserProfile,
			status: friendship.status as FriendshipStatus,
			created_at: friendship.created_at,
			is_requester: isRequester
		};
	});
}

export async function getPendingFriendRequests(userId: string): Promise<Friend[]> {
	// Get pending requests where user is the addressee (received requests)
	const { data, error } = await supabase
		.from('friendships')
		.select(`
			id,
			requester_id,
			addressee_id,
			status,
			created_at,
			requester:user_profiles!friendships_requester_id_fkey(*)
		`)
		.eq('status', 'pending')
		.eq('addressee_id', userId);

	if (error) throw new Error(error.message);

	return (data || []).map(friendship => {
		const requesterProfile = Array.isArray(friendship.requester) ? friendship.requester[0] : friendship.requester;
		return {
			friendship_id: friendship.id,
			user: requesterProfile as unknown as UserProfile,
			status: friendship.status as FriendshipStatus,
			created_at: friendship.created_at,
			is_requester: false
		};
	});
}

export async function getSentFriendRequests(userId: string): Promise<Friend[]> {
	// Get pending requests where user is the requester (sent requests)
	const { data, error } = await supabase
		.from('friendships')
		.select(`
			id,
			requester_id,
			addressee_id,
			status,
			created_at,
			addressee:user_profiles!friendships_addressee_id_fkey(*)
		`)
		.eq('status', 'pending')
		.eq('requester_id', userId);

	if (error) throw new Error(error.message);

	return (data || []).map(friendship => {
		const addresseeProfile = Array.isArray(friendship.addressee) ? friendship.addressee[0] : friendship.addressee;
		return {
			friendship_id: friendship.id,
			user: addresseeProfile as unknown as UserProfile,
			status: friendship.status as FriendshipStatus,
			created_at: friendship.created_at,
			is_requester: true
		};
	});
}

export async function getFriendshipStatus(userId: string, otherUserId: string): Promise<Friendship | null> {
	const { data, error } = await supabase
		.from('friendships')
		.select('*')
		.or(`and(requester_id.eq.${userId},addressee_id.eq.${otherUserId}),and(requester_id.eq.${otherUserId},addressee_id.eq.${userId})`)
		.single();

	if (error) return null;
	return data;
}

// ==================== INTERNAL ARTICLE SHARING FUNCTIONS ====================

export async function shareArticleWithFriend(
	articleId: string,
	sharedBy: string,
	sharedWith: string,
	message?: string
): Promise<ArticleShare> {
	const { data, error } = await supabase
		.from('article_shares')
		.insert([{
			article_id: articleId,
			shared_by: sharedBy,
			shared_with: sharedWith,
			message: message || null
		}])
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

export async function getSharedWithMe(userId: string): Promise<ArticleShare[]> {
	const { data, error } = await supabase
		.from('article_shares')
		.select(`
			*,
			article:articles(*),
			sharer:user_profiles!article_shares_shared_by_profile_fkey(*)
		`)
		.eq('shared_with', userId)
		.order('created_at', { ascending: false });

	if (error) throw new Error(error.message);
	return data || [];
}

export async function getSharedByMe(userId: string): Promise<ArticleShare[]> {
	const { data, error } = await supabase
		.from('article_shares')
		.select(`
			*,
			article:articles(*),
			recipient:user_profiles!article_shares_shared_with_profile_fkey(*)
		`)
		.eq('shared_by', userId)
		.order('created_at', { ascending: false });

	if (error) throw new Error(error.message);
	return data || [];
}

export async function markShareAsRead(shareId: string): Promise<void> {
	const { error } = await supabase
		.from('article_shares')
		.update({ is_read: true })
		.eq('id', shareId);

	if (error) throw new Error(error.message);
}

export async function getUnreadSharesCount(userId: string): Promise<number> {
	const { count, error } = await supabase
		.from('article_shares')
		.select('*', { count: 'exact', head: true })
		.eq('shared_with', userId)
		.eq('is_read', false);

	if (error) throw new Error(error.message);
	return count || 0;
}

export async function deleteArticleShare(shareId: string): Promise<void> {
	const { error } = await supabase
		.from('article_shares')
		.delete()
		.eq('id', shareId);

	if (error) throw new Error(error.message);
}

// ==================== STATISTICS FUNCTIONS ====================

export async function getUserStatistics(userId: string): Promise<{
	totalArticles: number;
	readArticles: number;
	favoriteArticles: number;
	totalLikesReceived: number;
	totalCommentsReceived: number;
	friendsCount: number;
	sharedArticlesCount: number;
	receivedArticlesCount: number;
}> {
	// Get article stats
	const { data: articles } = await supabase
		.from('articles')
		.select('id, reading_status, is_favorite, like_count, comment_count')
		.eq('user_id', userId);

	const totalArticles = articles?.length || 0;
	const readArticles = articles?.filter(a => a.reading_status === 'completed').length || 0;
	const favoriteArticles = articles?.filter(a => a.is_favorite).length || 0;
	const totalLikesReceived = articles?.reduce((sum, a) => sum + (a.like_count || 0), 0) || 0;
	const totalCommentsReceived = articles?.reduce((sum, a) => sum + (a.comment_count || 0), 0) || 0;

	// Get friends count
	const { count: friendsCount } = await supabase
		.from('friendships')
		.select('*', { count: 'exact', head: true })
		.eq('status', 'accepted')
		.or(`requester_id.eq.${userId},addressee_id.eq.${userId}`);

	// Get shared articles count
	const { count: sharedArticlesCount } = await supabase
		.from('article_shares')
		.select('*', { count: 'exact', head: true })
		.eq('shared_by', userId);

	// Get received articles count
	const { count: receivedArticlesCount } = await supabase
		.from('article_shares')
		.select('*', { count: 'exact', head: true })
		.eq('shared_with', userId);

	return {
		totalArticles,
		readArticles,
		favoriteArticles,
		totalLikesReceived,
		totalCommentsReceived,
		friendsCount: friendsCount || 0,
		sharedArticlesCount: sharedArticlesCount || 0,
		receivedArticlesCount: receivedArticlesCount || 0
	};
}

// ==================== ARTICLE SUMMARY FUNCTIONS ====================

/**
 * Get articles from the last N days for summary generation
 */
export async function getArticlesForSummary(
	userId: string,
	days: 7 | 30
): Promise<Article[]> {
	const now = new Date();
	const startDate = new Date(now);
	startDate.setDate(now.getDate() - days);

	const { data, error } = await supabase
		.from('articles')
		.select('*')
		.eq('user_id', userId)
		.gte('created_at', startDate.toISOString())
		.order('created_at', { ascending: false });

	if (error) throw new Error(error.message);
	return data || [];
}

/**
 * Generate a summary text from articles
 */
export function generateArticleSummary(articles: Article[], days: 7 | 30): {
	summary: string;
	stats: {
		total: number;
		read: number;
		reading: number;
		unread: number;
		favorites: number;
		totalReadTime: number;
		topDomains: { domain: string; count: number }[];
		topTags: { tag: string; count: number }[];
	};
} {
	const stats = {
		total: articles.length,
		read: articles.filter(a => a.reading_status === 'completed').length,
		reading: articles.filter(a => a.reading_status === 'reading').length,
		unread: articles.filter(a => a.reading_status === 'unread').length,
		favorites: articles.filter(a => a.is_favorite).length,
		totalReadTime: articles.reduce((sum, a) => sum + (a.estimated_read_time || 0), 0),
		topDomains: [] as { domain: string; count: number }[],
		topTags: [] as { tag: string; count: number }[]
	};

	// Calculate top domains
	const domainCounts = new Map<string, number>();
	articles.forEach(article => {
		if (article.domain) {
			domainCounts.set(article.domain, (domainCounts.get(article.domain) || 0) + 1);
		}
	});
	stats.topDomains = Array.from(domainCounts.entries())
		.map(([domain, count]) => ({ domain, count }))
		.sort((a, b) => b.count - a.count)
		.slice(0, 5);

	// Calculate top tags
	const tagCounts = new Map<string, number>();
	articles.forEach(article => {
		article.tags.forEach(tag => {
			tagCounts.set(tag, (tagCounts.get(tag) || 0) + 1);
		});
	});
	stats.topTags = Array.from(tagCounts.entries())
		.map(([tag, count]) => ({ tag, count }))
		.sort((a, b) => b.count - a.count)
		.slice(0, 5);

	// Generate summary text
	const period = days === 7 ? 'ultima settimana' : 'ultimi 30 giorni';
	let summary = `Negli ${period}, hai salvato **${stats.total} articoli**. `;

	if (stats.read > 0) {
		summary += `Ne hai completati **${stats.read}** (${Math.round((stats.read / stats.total) * 100)}%), `;
	}
	if (stats.reading > 0) {
		summary += `**${stats.reading}** sono in corso di lettura, `;
	}
	if (stats.unread > 0) {
		summary += `e **${stats.unread}** sono ancora da leggere. `;
	}

	if (stats.favorites > 0) {
		summary += `\n\nHai aggiunto **${stats.favorites} articoli ai preferiti**. `;
	}

	if (stats.totalReadTime > 0) {
		const hours = Math.floor(stats.totalReadTime / 60);
		const minutes = stats.totalReadTime % 60;
		summary += `\n\nTempo di lettura stimato totale: **${hours > 0 ? `${hours}h ` : ''}${minutes}min**. `;
	}

	if (stats.topDomains.length > 0) {
		summary += `\n\n### Fonti principali\n`;
		stats.topDomains.forEach(({ domain, count }) => {
			summary += `- **${domain}**: ${count} articol${count > 1 ? 'i' : 'o'}\n`;
		});
	}

	if (stats.topTags.length > 0) {
		summary += `\n### Tag più utilizzati\n`;
		stats.topTags.forEach(({ tag, count }) => {
			summary += `- **${tag}**: ${count} articol${count > 1 ? 'i' : 'o'}\n`;
		});
	}

	return { summary, stats };
}

// ==================== RSS ARTICLE TRACKING FUNCTIONS ====================

/**
 * Get RSS articles for a specific feed with read status
 */
export async function getRSSArticles(
	userId: string,
	feedId: string,
	limit: number = 50,
	includeRead: boolean = true
): Promise<RSSArticle[]> {
	let query = supabase
		.from('rss_articles')
		.select('*')
		.eq('user_id', userId)
		.eq('feed_id', feedId)
		.order('pub_date', { ascending: false })
		.limit(limit);

	if (!includeRead) {
		query = query.eq('is_read', false);
	}

	const { data, error } = await query;

	if (error) throw new Error(error.message);
	return data || [];
}

/**
 * Get all RSS articles for a user (across all feeds)
 */
export async function getAllRSSArticles(
	userId: string,
	limit: number = 100
): Promise<RSSArticle[]> {
	const { data, error } = await supabase
		.from('rss_articles')
		.select('*')
		.eq('user_id', userId)
		.order('pub_date', { ascending: false })
		.limit(limit);

	if (error) throw new Error(error.message);
	return data || [];
}

/**
 * Sync RSS articles - add new articles from feed
 */
export async function syncRSSArticles(
	userId: string,
	feedId: string,
	articles: Array<{
		guid: string;
		title: string;
		link: string;
		pubDate?: string;
		author?: string;
		content?: string;
		contentSnippet?: string;
		imageUrl?: string;
	}>,
	supabaseClient?: any // Optional authenticated client
): Promise<{ added: number; existing: number; errors: string[] }> {
	const db = supabaseClient || supabase;
	let added = 0;
	let existing = 0;
	const errors: string[] = [];

	for (const article of articles) {
		try {
			const { error } = await db
				.from('rss_articles')
				.insert([{
					user_id: userId,
					feed_id: feedId,
					guid: article.guid,
					title: article.title,
					link: article.link,
					pub_date: article.pubDate || null,
					author: article.author || null,
					content: article.content || null,
					content_snippet: article.contentSnippet || null,
					image_url: article.imageUrl || null,
					is_read: false
				}]);

			if (error) {
				// Check if it's a duplicate key error (article already exists)
				if (error.code === '23505') {
					existing++;
				} else {
					console.error('Error syncing RSS article:', error);
					errors.push(`Error for '${article.title}': ${error.message} (${error.code})`);
				}
			} else {
				added++;
			}
		} catch (err) {
			console.error('Unexpected error syncing article:', err);
			errors.push(`Unexpected error for '${article.title}': ${(err as Error).message}`);
		}
	}

	return { added, existing, errors };
}

/**
 * Mark an RSS article as read
 */
export async function markRSSArticleAsRead(articleId: string, userId: string): Promise<void> {
	const { error } = await supabase
		.from('rss_articles')
		.update({
			is_read: true,
			read_at: new Date().toISOString()
		})
		.eq('id', articleId)
		.eq('user_id', userId);

	if (error) throw new Error(error.message);
}

/**
 * Mark an RSS article as unread
 */
export async function markRSSArticleAsUnread(articleId: string, userId: string): Promise<void> {
	const { error } = await supabase
		.from('rss_articles')
		.update({
			is_read: false,
			read_at: null
		})
		.eq('id', articleId)
		.eq('user_id', userId);

	if (error) throw new Error(error.message);
}

/**
 * Mark multiple RSS articles as read
 */
export async function markMultipleRSSArticlesAsRead(articleIds: string[], userId: string): Promise<void> {
	const { error } = await supabase
		.from('rss_articles')
		.update({
			is_read: true,
			read_at: new Date().toISOString()
		})
		.in('id', articleIds)
		.eq('user_id', userId);

	if (error) throw new Error(error.message);
}

/**
 * Get unread count for a specific feed
 */
export async function getFeedUnreadCount(userId: string, feedId: string, supabaseClient?: any): Promise<number> {
	const db = supabaseClient || supabase;
	const { count, error } = await db
		.from('rss_articles')
		.select('*', { count: 'exact', head: true })
		.eq('user_id', userId)
		.eq('feed_id', feedId)
		.eq('is_read', false);

	if (error) throw new Error(error.message);
	return count || 0;
}

/**
 * Get unread counts for all feeds
 */
export async function getAllFeedsUnreadCounts(userId: string, supabaseClient?: any): Promise<Map<string, number>> {
	const db = supabaseClient || supabase;
	const { data, error } = await db
		.from('rss_articles')
		.select('feed_id')
		.eq('user_id', userId)
		.eq('is_read', false);

	if (error) throw new Error(error.message);

	const counts = new Map<string, number>();
	(data || []).forEach((item: { feed_id: string }) => {
		counts.set(item.feed_id, (counts.get(item.feed_id) || 0) + 1);
	});

	return counts;
}

/**
 * Get RSS feeds with unread counts
 */
export async function getRSSFeedsWithUnreadCounts(userId: string, supabaseClient?: any): Promise<RSSFeed[]> {
	const db = supabaseClient || supabase;
	// Get all feeds
	const { data: feeds, error: feedsError } = await db
		.from('rss_feeds')
		.select('*')
		.eq('user_id', userId)
		.order('created_at', { ascending: false });

	if (feedsError) throw new Error(feedsError.message);

	// Get unread counts
	const unreadCounts = await getAllFeedsUnreadCounts(userId, db);

	// Merge unread counts with feeds
	const feedsWithCounts: RSSFeed[] = (feeds || []).map((feed: any) => ({
		...feed,
		unread_count: unreadCounts.get(feed.id) || 0
	}));

	return feedsWithCounts;
}

/**
 * Delete old RSS articles (cleanup function)
 */
export async function deleteOldRSSArticles(
	userId: string,
	daysToKeep: number = 30
): Promise<number> {
	const cutoffDate = new Date();
	cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

	const { data, error } = await supabase
		.from('rss_articles')
		.delete()
		.eq('user_id', userId)
		.eq('is_read', true)
		.lt('pub_date', cutoffDate.toISOString())
		.select('id');

	if (error) throw new Error(error.message);
	return data?.length || 0;
}

// ==================== AI SUMMARY FUNCTIONS ====================

const SUMMARY_FUNCTION_URL = process.env.NEXT_PUBLIC_SUMMARY_FUNCTION_URL || '/.netlify/functions/generate-summary';

/**
 * Generate AI summary for article content
 */
export async function generateAISummary(
	content: string,
	length: 'short' | 'medium' | 'long' = 'medium',
	format: 'summary' | 'bullet' | 'periodical' = 'summary'
): Promise<string> {
	const response = await fetch(SUMMARY_FUNCTION_URL, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ content, length, format }),
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to generate summary');
	}

	const data = await response.json();
	return data.summary;
}

/**
 * Generate and save AI summary for an article
 */
export async function generateAndSaveArticleSummary(
	articleId: string,
	content: string,
	length: 'short' | 'medium' | 'long' = 'medium',
	format: 'summary' | 'bullet' | 'periodical' = 'summary'
): Promise<Article> {
	// Generate summary
	const summary = await generateAISummary(content, length, format);

	// Save to database
	const { data, error } = await supabase
		.from('articles')
		.update({
			ai_summary: summary,
			ai_summary_generated_at: new Date().toISOString()
		})
		.eq('id', articleId)
		.select()
		.single();

	if (error) throw new Error(error.message);
	return data;
}

/**
 * Regenerate AI summary for an article
 */
export async function regenerateArticleSummary(
	articleId: string,
	length: 'short' | 'medium' | 'long' = 'medium',
	format: 'summary' | 'bullet' | 'periodical' = 'summary'
): Promise<Article> {
	// Get article content
	const article = await getArticleById(articleId);
	if (!article || !article.content) {
		throw new Error('Article not found or has no content');
	}

	// Generate and save new summary
	return generateAndSaveArticleSummary(articleId, article.content, length, format);
}

// ==================== USER PREFERENCES ====================

/**
 * Get user reading preferences from database
 */
export async function getUserPreferences(userId: string): Promise<UserPreferences | null> {
	const { data, error } = await supabase
		.from('user_preferences')
		.select('*')
		.eq('id', userId)
		.single();

	if (error) {
		// If no preferences exist, return null (not an error)
		if (error.code === 'PGRST116') {
			return null;
		}
		throw new Error(error.message);
	}

	return data;
}

/**
 * Save or update user reading preferences
 */
export async function saveUserPreferences(
	userId: string,
	preferences: Omit<UserPreferences, 'id' | 'created_at' | 'updated_at'>
): Promise<UserPreferences> {
	// Try to update first
	const { data: existingData } = await supabase
		.from('user_preferences')
		.select('id')
		.eq('id', userId)
		.single();

	if (existingData) {
		// Update existing preferences
		const { data, error } = await supabase
			.from('user_preferences')
			.update(preferences)
			.eq('id', userId)
			.select()
			.single();

		if (error) throw new Error(error.message);
		return data;
	} else {
		// Insert new preferences
		const { data, error } = await supabase
			.from('user_preferences')
			.insert([{ ...preferences, id: userId }])
			.select()
			.single();

		if (error) throw new Error(error.message);
		return data;
	}
}

/**
 * Delete user reading preferences
 */
export async function deleteUserPreferences(userId: string): Promise<void> {
	const { error } = await supabase
		.from('user_preferences')
		.delete()
		.eq('id', userId);

	if (error) throw new Error(error.message);
}
