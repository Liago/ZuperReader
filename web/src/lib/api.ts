import { supabase, Article, Comment, Share, UserProfile, Friendship, FriendshipStatus, ArticleShare, Friend, UserPreferences } from './supabase';

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
		.select()
		.single();

	if (error) throw new Error(error.message);

	// Increment comment_count atomically
	const { error: updateError } = await supabase.rpc('increment_comment_count', { article_id: articleId });
	if (updateError) throw new Error(updateError.message);

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

	// Decrement comment_count atomically
	const { error: updateError } = await supabase.rpc('decrement_comment_count', { article_id: articleId });
	if (updateError) throw new Error(updateError.message);
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
