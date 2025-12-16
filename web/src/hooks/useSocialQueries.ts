import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
	toggleLike,
	checkIfUserLiked,
	addComment,
	getComments,
	deleteComment,
} from '../lib/api';
import { Comment, Article } from '../lib/supabase';
import { articleKeys } from './useArticleQueries';

/**
 * React Query hooks for social features (likes, comments) with caching and optimistic updates
 */

// Query keys factory
export const socialKeys = {
	likes: (articleId: string, userId: string) => ['likes', articleId, userId] as const,
	comments: (articleId: string) => ['comments', articleId] as const,
};

/**
 * Hook to fetch like status for an article
 */
export function useLikeStatus(articleId: string, userId: string, enabled = true) {
	return useQuery({
		queryKey: socialKeys.likes(articleId, userId),
		queryFn: () => checkIfUserLiked(articleId, userId),
		enabled: enabled && !!articleId && !!userId,
		staleTime: 5 * 60 * 1000, // 5 minutes
	});
}

/**
 * Hook to toggle like with optimistic update
 */
export function useToggleLike() {
	const queryClient = useQueryClient();

	return useMutation({
		mutationFn: async ({
			articleId,
			userId,
			isLiked,
		}: {
			articleId: string;
			userId: string;
			isLiked: boolean;
		}) => {
			const result = await toggleLike(articleId, userId);
			return { articleId, userId, isLiked, likeCount: result.likeCount };
		},
		onMutate: async ({ articleId, userId, isLiked }) => {
			// Cancel outgoing queries
			await queryClient.cancelQueries({ queryKey: socialKeys.likes(articleId, userId) });
			await queryClient.cancelQueries({ queryKey: articleKeys.detail(articleId) });

			// Snapshot previous values
			const previousLikeStatus = queryClient.getQueryData(socialKeys.likes(articleId, userId));
			const previousArticle = queryClient.getQueryData<Article>(articleKeys.detail(articleId));

			// Optimistically update like status
			queryClient.setQueryData(socialKeys.likes(articleId, userId), isLiked);

			// Optimistically update like count in article
			queryClient.setQueryData<Article>(articleKeys.detail(articleId), (old) => {
				if (!old) return old;
				return {
					...old,
					like_count: (old.like_count || 0) + (isLiked ? 1 : -1),
				};
			});

			// Update in lists as well
			queryClient.setQueriesData<{ articles: Article[]; hasMore: boolean }>(
				{ queryKey: articleKeys.lists() },
				(old) => {
					if (!old) return old;
					return {
						...old,
						articles: old.articles.map((article) =>
							article.id === articleId
								? {
										...article,
										like_count: (article.like_count || 0) + (isLiked ? 1 : -1),
								  }
								: article
						),
					};
				}
			);

			return { previousLikeStatus, previousArticle };
		},
		onError: (err, { articleId, userId }, context) => {
			// Rollback on error
			if (context?.previousLikeStatus !== undefined) {
				queryClient.setQueryData(socialKeys.likes(articleId, userId), context.previousLikeStatus);
			}
			if (context?.previousArticle) {
				queryClient.setQueryData(articleKeys.detail(articleId), context.previousArticle);
			}
			console.error('Failed to toggle like:', err);
		},
		onSettled: (data) => {
			if (data) {
				queryClient.invalidateQueries({ queryKey: socialKeys.likes(data.articleId, data.userId) });
				queryClient.invalidateQueries({ queryKey: articleKeys.detail(data.articleId) });
				queryClient.invalidateQueries({ queryKey: articleKeys.lists() });
			}
		},
	});
}

/**
 * Hook to fetch comments for an article
 */
export function useComments(articleId: string, enabled = true) {
	return useQuery({
		queryKey: socialKeys.comments(articleId),
		queryFn: () => getComments(articleId),
		enabled: enabled && !!articleId,
		staleTime: 2 * 60 * 1000, // 2 minutes
	});
}

/**
 * Hook to add a comment with optimistic update
 */
export function useAddComment() {
	const queryClient = useQueryClient();

	return useMutation({
		mutationFn: async ({
			articleId,
			userId,
			content,
		}: {
			articleId: string;
			userId: string;
			content: string;
		}) => {
			return await addComment(articleId, userId, content);
		},
		onMutate: async ({ articleId, userId, content }) => {
			await queryClient.cancelQueries({ queryKey: socialKeys.comments(articleId) });

			const previousComments = queryClient.getQueryData<Comment[]>(
				socialKeys.comments(articleId)
			);

			// Create optimistic comment
			const optimisticComment: Comment = {
				id: `temp-${Date.now()}`,
				article_id: articleId,
				user_id: userId,
				content,
				created_at: new Date().toISOString(),
				user_profile: null,
			};

			// Optimistically add the comment
			queryClient.setQueryData<Comment[]>(socialKeys.comments(articleId), (old) => {
				if (!old) return [optimisticComment];
				return [...old, optimisticComment];
			});

			// Update comment count
			queryClient.setQueryData<Article>(articleKeys.detail(articleId), (old) => {
				if (!old) return old;
				return {
					...old,
					comment_count: (old.comment_count || 0) + 1,
				};
			});

			return { previousComments };
		},
		onError: (err, { articleId }, context) => {
			// Rollback on error
			if (context?.previousComments) {
				queryClient.setQueryData(socialKeys.comments(articleId), context.previousComments);
			}
			console.error('Failed to add comment:', err);
		},
		onSettled: (data, error, { articleId }) => {
			// Refetch to get the real comment with ID
			queryClient.invalidateQueries({ queryKey: socialKeys.comments(articleId) });
			queryClient.invalidateQueries({ queryKey: articleKeys.detail(articleId) });
		},
	});
}

/**
 * Hook to delete a comment with optimistic update
 */
export function useDeleteComment() {
	const queryClient = useQueryClient();

	return useMutation({
		mutationFn: async ({ commentId, articleId }: { commentId: string; articleId: string }) => {
			await deleteComment(commentId, articleId);
			return { commentId, articleId };
		},
		onMutate: async ({ commentId, articleId }) => {
			await queryClient.cancelQueries({ queryKey: socialKeys.comments(articleId) });

			const previousComments = queryClient.getQueryData<Comment[]>(
				socialKeys.comments(articleId)
			);

			// Optimistically remove the comment
			queryClient.setQueryData<Comment[]>(socialKeys.comments(articleId), (old) => {
				if (!old) return old;
				return old.filter((comment) => comment.id !== commentId);
			});

			// Update comment count
			queryClient.setQueryData<Article>(articleKeys.detail(articleId), (old) => {
				if (!old) return old;
				return {
					...old,
					comment_count: Math.max(0, (old.comment_count || 0) - 1),
				};
			});

			return { previousComments };
		},
		onError: (err, { articleId }, context) => {
			// Rollback on error
			if (context?.previousComments) {
				queryClient.setQueryData(socialKeys.comments(articleId), context.previousComments);
			}
			console.error('Failed to delete comment:', err);
		},
		onSettled: (data) => {
			if (data) {
				queryClient.invalidateQueries({ queryKey: socialKeys.comments(data.articleId) });
				queryClient.invalidateQueries({ queryKey: articleKeys.detail(data.articleId) });
			}
		},
	});
}
