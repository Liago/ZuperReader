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
	// Keep track of current filters/sort for pagination
	const currentFiltersRef = useRef<ArticleFilters>({});
	const currentSortRef = useRef<ArticleSortOptions>({ field: 'created_at', order: 'desc' });

	const loadArticles = useCallback(async (
		userId: string,
		reset: boolean = false,
		filters?: ArticleFilters,
		sort?: ArticleSortOptions
	) => {
		// If reset is requested and a load is in progress, allow reset to proceed
		// Otherwise prevent concurrent loads
		if (loadingRef.current && !reset) return;
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

		// Get current offset from state for pagination
		let currentOffset = 0;
		setState(prev => {
			currentOffset = reset ? 0 : prev.offset;
			return {
				...prev,
				loading: reset,
				loadingMore: !reset,
				error: '',
			};
		});

		try {
			const { articles: newArticles, hasMore: more } = await getArticles(
				userId,
				ITEMS_PER_PAGE,
				currentOffset,
				currentFiltersRef.current,
				currentSortRef.current
			);

			// Double-check we should still apply these results
			// If userId changed during the request, ignore the results
			if (currentUserIdRef.current !== userId) {
				return;
			}

			setState(prev => ({
				...prev,
				articles: reset ? newArticles : [...prev.articles, ...newArticles],
				offset: reset ? ITEMS_PER_PAGE : prev.offset + ITEMS_PER_PAGE,
				hasMore: more,
				loading: false,
				loadingMore: false,
				isInitialized: true,
				error: '',
			}));
		} catch (err) {
			setState(prev => ({
				...prev,
				error: 'Failed to load articles',
				loading: false,
				loadingMore: false,
			}));
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
