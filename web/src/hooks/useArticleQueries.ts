import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
	getArticles,
	getArticleById,
	toggleFavorite,
	updateReadingStatus,
	deleteArticle,
	ArticleFilters,
	ArticleSortOptions,
} from '../lib/api';
import { Article } from '../lib/supabase';

/**
 * React Query hooks for article operations with caching and optimistic updates
 */

// Query keys factory
export const articleKeys = {
	all: ['articles'] as const,
	lists: () => [...articleKeys.all, 'list'] as const,
	list: (userId: string, filters?: ArticleFilters, sort?: ArticleSortOptions) =>
		[...articleKeys.lists(), { userId, filters, sort }] as const,
	details: () => [...articleKeys.all, 'detail'] as const,
	detail: (id: string) => [...articleKeys.details(), id] as const,
};

/**
 * Hook to fetch articles with filters and sorting
 */
export function useArticles(
	userId: string,
	filters?: ArticleFilters,
	sort?: ArticleSortOptions,
	enabled = true
) {
	return useQuery({
		queryKey: articleKeys.list(userId, filters, sort),
		queryFn: async () => {
			const result = await getArticles(userId, 50, 0, filters, sort);
			return result;
		},
		enabled: enabled && !!userId,
		staleTime: 2 * 60 * 1000, // 2 minutes
	});
}

/**
 * Hook to fetch a single article by ID
 */
export function useArticle(articleId: string, enabled = true) {
	return useQuery({
		queryKey: articleKeys.detail(articleId),
		queryFn: () => getArticleById(articleId),
		enabled: enabled && !!articleId,
		staleTime: 5 * 60 * 1000, // 5 minutes
	});
}

/**
 * Hook to toggle article favorite status with optimistic update
 */
export function useToggleFavorite() {
	const queryClient = useQueryClient();

	return useMutation({
		mutationFn: async ({ articleId, isFavorite }: { articleId: string; isFavorite: boolean }) => {
			await toggleFavorite(articleId, isFavorite);
			return { articleId, isFavorite };
		},
		onMutate: async ({ articleId, isFavorite }) => {
			// Cancel any outgoing refetches
			await queryClient.cancelQueries({ queryKey: articleKeys.detail(articleId) });

			// Snapshot the previous value
			const previousArticle = queryClient.getQueryData<Article>(articleKeys.detail(articleId));

			// Optimistically update the article
			queryClient.setQueryData<Article>(articleKeys.detail(articleId), (old) => {
				if (!old) return old;
				return { ...old, is_favorite: isFavorite };
			});

			// Also update in lists
			queryClient.setQueriesData<{ articles: Article[]; hasMore: boolean }>(
				{ queryKey: articleKeys.lists() },
				(old) => {
					if (!old) return old;
					return {
						...old,
						articles: old.articles.map((article) =>
							article.id === articleId ? { ...article, is_favorite: isFavorite } : article
						),
					};
				}
			);

			return { previousArticle };
		},
		onError: (err, { articleId }, context) => {
			// Rollback on error
			if (context?.previousArticle) {
				queryClient.setQueryData(articleKeys.detail(articleId), context.previousArticle);
			}
			console.error('Failed to toggle favorite:', err);
		},
		onSettled: (data) => {
			// Refetch to ensure consistency
			if (data) {
				queryClient.invalidateQueries({ queryKey: articleKeys.detail(data.articleId) });
				queryClient.invalidateQueries({ queryKey: articleKeys.lists() });
			}
		},
	});
}

/**
 * Hook to update reading status with optimistic update
 */
export function useUpdateReadingStatus() {
	const queryClient = useQueryClient();

	return useMutation({
		mutationFn: async ({
			articleId,
			status,
		}: {
			articleId: string;
			status: 'unread' | 'reading' | 'completed';
		}) => {
			await updateReadingStatus(articleId, status);
			return { articleId, status };
		},
		onMutate: async ({ articleId, status }) => {
			await queryClient.cancelQueries({ queryKey: articleKeys.detail(articleId) });

			const previousArticle = queryClient.getQueryData<Article>(articleKeys.detail(articleId));

			queryClient.setQueryData<Article>(articleKeys.detail(articleId), (old) => {
				if (!old) return old;
				return { ...old, reading_status: status };
			});

			queryClient.setQueriesData<{ articles: Article[]; hasMore: boolean }>(
				{ queryKey: articleKeys.lists() },
				(old) => {
					if (!old) return old;
					return {
						...old,
						articles: old.articles.map((article) =>
							article.id === articleId ? { ...article, reading_status: status } : article
						),
					};
				}
			);

			return { previousArticle };
		},
		onError: (err, { articleId }, context) => {
			if (context?.previousArticle) {
				queryClient.setQueryData(articleKeys.detail(articleId), context.previousArticle);
			}
			console.error('Failed to update reading status:', err);
		},
		onSettled: (data) => {
			if (data) {
				queryClient.invalidateQueries({ queryKey: articleKeys.detail(data.articleId) });
				queryClient.invalidateQueries({ queryKey: articleKeys.lists() });
			}
		},
	});
}

/**
 * Hook to delete an article with optimistic update
 */
export function useDeleteArticle() {
	const queryClient = useQueryClient();

	return useMutation({
		mutationFn: async (articleId: string) => {
			await deleteArticle(articleId);
			return articleId;
		},
		onMutate: async (articleId) => {
			await queryClient.cancelQueries({ queryKey: articleKeys.lists() });

			const previousLists = queryClient.getQueriesData<{ articles: Article[]; hasMore: boolean }>(
				{ queryKey: articleKeys.lists() }
			);

			// Optimistically remove from all lists
			queryClient.setQueriesData<{ articles: Article[]; hasMore: boolean }>(
				{ queryKey: articleKeys.lists() },
				(old) => {
					if (!old) return old;
					return {
						...old,
						articles: old.articles.filter((article) => article.id !== articleId),
					};
				}
			);

			return { previousLists };
		},
		onError: (err, articleId, context) => {
			// Rollback on error
			if (context?.previousLists) {
				context.previousLists.forEach(([queryKey, data]) => {
					queryClient.setQueryData(queryKey, data);
				});
			}
			console.error('Failed to delete article:', err);
		},
		onSettled: () => {
			// Refetch lists
			queryClient.invalidateQueries({ queryKey: articleKeys.lists() });
		},
	});
}
