'use client';

import { createContext, useContext, useState, useCallback, useRef, ReactNode } from 'react';
import { Article } from '../lib/supabase';
import { getArticles, ArticleFilters, ArticleSortOptions } from '../lib/api';

const ITEMS_PER_PAGE = 10;

interface ArticlesState {
	articles: Article[];
	loading: boolean;
	loadingMore: boolean;
	error: string;
	hasMore: boolean;
	offset: number;
	isInitialized: boolean;
}

interface ArticlesContextType {
	state: ArticlesState;
	loadArticles: (userId: string, reset?: boolean, filters?: ArticleFilters, sort?: ArticleSortOptions) => Promise<void>;
	updateArticle: (articleId: string, updates: Partial<Article>) => void;
	removeArticle: (articleId: string) => void;
	addArticle: (article: Article) => void;
	resetState: () => void;
	refreshArticles: (userId: string, filters?: ArticleFilters, sort?: ArticleSortOptions) => Promise<void>;
}

const defaultState: ArticlesState = {
	articles: [],
	loading: false,
	loadingMore: false,
	error: '',
	hasMore: true,
	offset: 0,
	isInitialized: false,
};

const ArticlesContext = createContext<ArticlesContextType | undefined>(undefined);

export function ArticlesProvider({ children }: { children: ReactNode }) {
	const [state, setState] = useState<ArticlesState>(defaultState);
	const loadingRef = useRef(false);
	const currentUserIdRef = useRef<string | null>(null);
	const requestIdRef = useRef(0); // Track request order
	// Keep track of current filters/sort for pagination
	const currentFiltersRef = useRef<ArticleFilters>({});
	const currentSortRef = useRef<ArticleSortOptions>({ field: 'created_at', order: 'desc' });

	const offsetRef = useRef(0);

	const loadArticles = useCallback(async (
		userId: string,
		reset: boolean = false,
		filters?: ArticleFilters,
		sort?: ArticleSortOptions
	) => {
		// Prevent concurrent non-reset loads
		if (loadingRef.current && !reset) {
			console.log('[ArticlesContext] Blocked concurrent load, reset:', reset);
			return;
		}

		// Generate unique request ID
		requestIdRef.current += 1;
		const thisRequestId = requestIdRef.current;

		console.log('[ArticlesContext] Starting load, requestId:', thisRequestId, 'reset:', reset);

		loadingRef.current = true;

		// Track current user
		currentUserIdRef.current = userId;

		// Update refs if new filters/sort provided
		if (filters !== undefined) {
			currentFiltersRef.current = filters;
		}
		if (sort !== undefined) {
			currentSortRef.current = sort;
		}

		// Determine offset to use using Ref source of truth
		if (reset) {
			offsetRef.current = 0;
		}
		const currentOffset = offsetRef.current;

		// Optimistically update state
		setState(prev => ({
			...prev,
			loading: reset,
			loadingMore: !reset,
			error: '',
			// For UI consistency, though logic uses ref
			offset: currentOffset
		}));

		try {
			console.log('[ArticlesContext] Fetching with offset:', currentOffset);
			const { articles: newArticles, hasMore: more } = await getArticles(
				userId,
				ITEMS_PER_PAGE,
				currentOffset,
				currentFiltersRef.current,
				currentSortRef.current
			);

			console.log('[ArticlesContext] Received', newArticles.length, 'articles, hasMore:', more, 'requestId:', thisRequestId);

			// Ignore stale responses
			if (thisRequestId !== requestIdRef.current || currentUserIdRef.current !== userId) {
				console.log('[ArticlesContext] Ignoring stale response');
				return;
			}

			// Update offset for next call
			if (more) {
				offsetRef.current = currentOffset + ITEMS_PER_PAGE;
			}

			setState(prev => {
				let updatedArticles;
				if (reset) {
					updatedArticles = newArticles;
				} else {
					// Filter out any duplicates when appending
					const existingIds = new Set(prev.articles.map(a => a.id));
					const uniqueNewArticles = newArticles.filter(a => !existingIds.has(a.id));
					updatedArticles = [...prev.articles, ...uniqueNewArticles];
				}

				return {
					...prev,
					articles: updatedArticles,
					offset: offsetRef.current,
					hasMore: more,
					loading: false,
					loadingMore: false,
					isInitialized: true,
					error: '',
				};
			});
		} catch (err) {
			// Only update error state if this is still the latest request
			if (thisRequestId === requestIdRef.current) {
				setState(prev => ({
					...prev,
					error: 'Failed to load articles',
					loading: false,
					loadingMore: false,
				}));
			}
			console.error(err);
		} finally {
			loadingRef.current = false;
		}
	}, []);

	const updateArticle = useCallback((articleId: string, updates: Partial<Article>) => {
		setState(prev => ({
			...prev,
			articles: prev.articles.map(a =>
				a.id === articleId ? { ...a, ...updates } : a
			),
		}));
	}, []);

	const removeArticle = useCallback((articleId: string) => {
		setState(prev => ({
			...prev,
			articles: prev.articles.filter(a => a.id !== articleId),
		}));
	}, []);

	const addArticle = useCallback((article: Article) => {
		setState(prev => ({
			...prev,
			articles: [article, ...prev.articles],
		}));
	}, []);

	const resetState = useCallback(() => {
		setState(defaultState);
		currentUserIdRef.current = null;
		currentFiltersRef.current = {};
		currentSortRef.current = { field: 'created_at', order: 'desc' };
	}, []);

	const refreshArticles = useCallback(async (
		userId: string,
		filters?: ArticleFilters,
		sort?: ArticleSortOptions
	) => {
		// Force a fresh load from server
		loadingRef.current = false;
		setState(prev => ({
			...prev,
			offset: 0,
		}));
		await loadArticles(userId, true, filters, sort);
	}, [loadArticles]);

	return (
		<ArticlesContext.Provider value={{
			state,
			loadArticles,
			updateArticle,
			removeArticle,
			addArticle,
			resetState,
			refreshArticles,
		}}>
			{children}
		</ArticlesContext.Provider>
	);
}

export function useArticles() {
	const context = useContext(ArticlesContext);
	if (context === undefined) {
		throw new Error('useArticles must be used within an ArticlesProvider');
	}
	return context;
}
