'use client';

import { useEffect, useState, useRef, useCallback, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { deleteArticle, updateArticleTags, toggleFavorite, ArticleFilters, ArticleSortOptions, ArticleSortField } from '../lib/api';
import { Article } from '../lib/supabase';
import { useReadingPreferences } from '../contexts/ReadingPreferencesContext';
import { useArticles } from '../contexts/ArticlesContext';
import { useArticleFilters } from '../contexts/ArticleFiltersContext';
import TagManagementModal from './TagManagementModal';
import ArticleCard from './ArticleCard';
import ArticleRow from './ArticleRow';

interface ArticleListProps {
	userId: string;
}

// Skeleton Loader per Grid View
function GridSkeleton() {
	return (
		<div className="bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm rounded-2xl overflow-hidden shadow-sm border border-gray-100 dark:border-slate-700">
			<div className="w-full h-48 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 animate-pulse bg-[length:200%_100%]"></div>
			<div className="p-5 space-y-3">
				<div className="h-6 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded w-3/4 animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded w-1/2 animate-pulse bg-[length:200%_100%]"></div>
			</div>
		</div>
	);
}

// Skeleton Loader per List View
function ListSkeleton() {
	return (
		<div className="bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm rounded-2xl p-4 flex gap-4 shadow-sm border border-gray-100 dark:border-slate-700">
			<div className="w-24 h-24 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded-xl animate-pulse bg-[length:200%_100%] flex-shrink-0"></div>
			<div className="flex-1 space-y-3">
				<div className="h-6 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded w-3/4 animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 rounded w-1/2 animate-pulse bg-[length:200%_100%]"></div>
			</div>
		</div>
	);
}

export default function ArticleList({ userId }: ArticleListProps) {
	const { state, loadArticles, updateArticle, removeArticle } = useArticles();
	const { articles, loading, loadingMore, error, hasMore, isInitialized } = state;

	const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
	const [articleToDelete, setArticleToDelete] = useState<Article | null>(null);
	const [isDeleting, setIsDeleting] = useState(false);
	const [showTagModal, setShowTagModal] = useState(false);
	const [articleForTags, setArticleForTags] = useState<Article | null>(null);

	const router = useRouter();
	const { preferences, updatePreferences } = useReadingPreferences();
	const viewMode = preferences.viewMode;

	// Use filter state from context instead of local state
	const {
		filters,
		setSearchQuery,
		setReadingStatus,
		setIsFavorite,
		setSortField,
		setSortOrder,
		setSelectedTags,
		setSelectedDomain,
		setShowAdvancedFilters,
		resetFilters,
	} = useArticleFilters();

	// Destructure filter values for easier access
	const {
		searchQuery,
		readingStatus,
		isFavorite,
		sortField,
		sortOrder,
		selectedTags,
		selectedDomain,
		showAdvancedFilters,
	} = filters;

	const observerTarget = useRef<HTMLDivElement>(null);
	const prevUserIdRef = useRef<string>('');
	const searchTimeoutRef = useRef<NodeJS.Timeout | null>(null);

	// Estrai tag e domini unici dagli articoli per i filtri
	const availableTags = useMemo(() => {
		const tagSet = new Set<string>();
		articles.forEach(article => {
			article.tags?.forEach(tag => tagSet.add(tag));
		});
		return Array.from(tagSet).sort();
	}, [articles]);

	const availableDomains = useMemo(() => {
		const domainSet = new Set<string>();
		articles.forEach(article => {
			if (article.domain) domainSet.add(article.domain);
		});
		return Array.from(domainSet).sort();
	}, [articles]);

	// Check if any filter is active
	const hasActiveFilters = searchQuery || readingStatus !== 'all' || isFavorite !== undefined ||
		selectedTags.length > 0 || selectedDomain || sortField !== 'created_at' || sortOrder !== 'desc';

	// Build current filters and sort
	const buildFiltersAndSort = useCallback(() => {
		const newFilters: ArticleFilters = {
			searchQuery: searchQuery || undefined,
			tags: selectedTags.length > 0 ? selectedTags : undefined,
			readingStatus,
			isFavorite,
			domain: selectedDomain || undefined,
		};

		const newSort: ArticleSortOptions = {
			field: sortField,
			order: sortOrder,
		};

		return { filters: newFilters, sort: newSort };
	}, [searchQuery, selectedTags, readingStatus, isFavorite, selectedDomain, sortField, sortOrder]);

	// Track if it's the first load
	const isFirstLoadRef = useRef(true);
	const filtersChangedRef = useRef(false);

	// Debounced filter application
	useEffect(() => {
		// Skip first render - will be handled by initial load effect
		if (isFirstLoadRef.current) {
			return;
		}

		filtersChangedRef.current = true;

		if (searchTimeoutRef.current) {
			clearTimeout(searchTimeoutRef.current);
		}
		searchTimeoutRef.current = setTimeout(() => {
			const { filters, sort } = buildFiltersAndSort();
			loadArticles(userId, true, filters, sort);
		}, 300);

		return () => {
			if (searchTimeoutRef.current) {
				clearTimeout(searchTimeoutRef.current);
			}
		};
	}, [searchQuery, selectedTags, readingStatus, isFavorite, selectedDomain, sortField, sortOrder, buildFiltersAndSort, loadArticles, userId]);

	// Initial load - only runs once per userId
	useEffect(() => {
		if (!isInitialized || userId !== prevUserIdRef.current) {
			prevUserIdRef.current = userId;
			isFirstLoadRef.current = false;
			const { filters, sort } = buildFiltersAndSort();
			loadArticles(userId, true, filters, sort);
		}
	}, [userId, isInitialized, loadArticles, buildFiltersAndSort]);

	// Track loading state in a ref to avoid recreating observer on every loading change
	const loadingStateRef = useRef({ loading, loadingMore });
	useEffect(() => {
		loadingStateRef.current = { loading, loadingMore };
	}, [loading, loadingMore]);

	// Intersection Observer per infinite scrolling
	useEffect(() => {
		const observer = new IntersectionObserver(
			(entries) => {
				const { loading: isLoading, loadingMore: isLoadingMore } = loadingStateRef.current;
				if (entries[0].isIntersecting && hasMore && !isLoading && !isLoadingMore) {
					loadArticles(userId, false);
				}
			},
			{
				threshold: 0,
				rootMargin: '400px' // Trigger loading when element is 400px away from viewport
			}
		);

		const currentTarget = observerTarget.current;
		if (currentTarget) {
			observer.observe(currentTarget);
		}

		return () => {
			if (currentTarget) {
				observer.unobserve(currentTarget);
			}
		};
	}, [hasMore, loadArticles, userId, loading, loadingMore]);

	// Clear all filters - now using context
	const clearFilters = () => {
		resetFilters();
	};

	// Toggle tag selection
	const toggleTag = (tag: string) => {
		if (selectedTags.includes(tag)) {
			setSelectedTags(selectedTags.filter(t => t !== tag));
		} else {
			setSelectedTags([...selectedTags, tag]);
		}
	};

	// Funzione per navigare all'articolo
	const handleArticleClick = (articleId: string) => {
		router.push(`/articles/${articleId}`);
	};

	// Gestione eliminazione articolo
	const handleDeleteClick = (e: React.MouseEvent, article: Article) => {
		e.stopPropagation();
		setArticleToDelete(article);
		setShowDeleteConfirm(true);
	};

	const handleDeleteConfirm = async () => {
		if (!articleToDelete) return;

		setIsDeleting(true);
		try {
			await deleteArticle(articleToDelete.id);
			removeArticle(articleToDelete.id);
			setShowDeleteConfirm(false);
			setArticleToDelete(null);
		} catch (error) {
			console.error('Failed to delete article:', error);
		} finally {
			setIsDeleting(false);
		}
	};

	const handleDeleteCancel = () => {
		setShowDeleteConfirm(false);
		setArticleToDelete(null);
	};

	// Tag management handlers
	const handleTagClick = (e: React.MouseEvent, article: Article) => {
		e.stopPropagation();
		setArticleForTags(article);
		setShowTagModal(true);
	};

	const handleSaveTags = async (tags: string[]) => {
		if (!articleForTags) return;

		try {
			const updatedArticle = await updateArticleTags(articleForTags.id, tags);
			updateArticle(articleForTags.id, { tags: updatedArticle.tags });
		} catch (error) {
			console.error('Failed to update tags:', error);
			throw error;
		}
	};

	const handleToggleFavorite = async (e: React.MouseEvent, article: Article) => {
		e.preventDefault();
		e.stopPropagation();

		// Optimistic update
		const newStatus = !article.is_favorite;
		updateArticle(article.id, { is_favorite: newStatus });

		try {
			await toggleFavorite(article.id, newStatus);
		} catch (err) {
			// Revert on error
			console.error('Failed to toggle favorite', err);
			updateArticle(article.id, { is_favorite: !newStatus });
		}
	};

	if (loading) {
		return (
			<div className="mt-8">
				{viewMode === 'grid' ? (
					<div className="grid gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
						{[...Array(6)].map((_, i) => (
							<GridSkeleton key={i} />
						))}
					</div>
				) : (
					<div className="space-y-4">
						{[...Array(4)].map((_, i) => (
							<ListSkeleton key={i} />
						))}
					</div>
				)}
			</div>
		);
	}

	if (error) {
		return (
			<div className="text-center py-12 px-4">
				<div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-100 mb-4">
					<svg className="w-8 h-8 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
				</div>
				<p className="text-red-600 font-medium">{error}</p>
			</div>
		);
	}

	return (
		<div className="mt-4">
			{/* Combined Toolbar: Title, Search, Filters, View Mode */}
			<div className="bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm rounded-2xl shadow-sm border border-gray-100 dark:border-slate-700 p-4 mb-6">
				{/* Top row: Title, Search, View Mode */}
				<div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
					{/* Title */}
					<h2 className="text-xl sm:text-2xl font-bold text-gray-800 dark:text-gray-100 whitespace-nowrap">
						My Articles
						<span className="ml-2 text-sm font-normal text-gray-500 dark:text-gray-400">({articles.length}{!hasMore ? '' : '+'})</span>
					</h2>

					{/* Search Bar */}
					<div className="flex-1 w-full sm:w-auto">
						<div className="relative">
							<div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
								<svg className="h-4 w-4 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
								</svg>
							</div>
							<input
								type="text"
								value={searchQuery}
								onChange={(e) => setSearchQuery(e.target.value)}
								placeholder="Search articles..."
								className="block w-full pl-9 pr-9 py-2 border border-gray-200 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent text-sm text-gray-900 dark:text-gray-100 bg-white dark:bg-slate-700 placeholder-gray-400 dark:placeholder-gray-500"
							/>
							{searchQuery && (
								<button
									onClick={() => setSearchQuery('')}
									className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
								>
									<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							)}
						</div>
					</div>

					{/* View Mode Toggle */}
					<div className="flex items-center gap-2">
						<div className="bg-gray-100 dark:bg-slate-700 rounded-xl p-1 flex">
							<button
								onClick={() => updatePreferences({ viewMode: 'grid' })}
								className={`p-2 rounded-lg transition-all duration-200 ${viewMode === 'grid'
									? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-md'
									: 'text-gray-400 hover:text-gray-600 dark:text-gray-400 dark:hover:text-gray-200'
									}`}
								title="Grid View"
							>
								<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
								</svg>
							</button>
							<button
								onClick={() => updatePreferences({ viewMode: 'list' })}
								className={`p-2 rounded-lg transition-all duration-200 ${viewMode === 'list'
									? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-md'
									: 'text-gray-400 hover:text-gray-600 dark:text-gray-400 dark:hover:text-gray-200'
									}`}
								title="List View"
							>
								<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
								</svg>
							</button>
						</div>
					</div>
				</div>

				{/* Second row: Quick Filters */}
				<div className="mt-4 flex flex-wrap items-center gap-2">
					{/* Reading Status Pills */}
					<div className="flex items-center gap-1 bg-gray-100 dark:bg-slate-700 rounded-xl p-1">
						{(['all', 'unread', 'reading', 'completed'] as const).map((status) => (
							<button
								key={status}
								onClick={() => setReadingStatus(status)}
								className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${readingStatus === status
									? 'bg-white dark:bg-slate-600 text-purple-600 dark:text-purple-400 shadow-sm'
									: 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
									}`}
							>
								{status === 'all' && 'All'}
								{status === 'unread' && 'Unread'}
								{status === 'reading' && 'Reading'}
								{status === 'completed' && 'Completed'}
							</button>
						))}
					</div>

					{/* Favorite Toggle */}
					<button
						onClick={() => setIsFavorite(isFavorite === true ? undefined : true)}
						className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium transition-all ${isFavorite === true
							? 'bg-pink-100 dark:bg-pink-900/30 text-pink-600 dark:text-pink-400 border border-pink-200 dark:border-pink-800'
							: 'bg-gray-100 dark:bg-slate-700 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
							}`}
					>
						<svg className={`w-4 h-4 ${isFavorite === true ? 'fill-current' : ''}`} fill={isFavorite === true ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
						</svg>
						Favorites
					</button>

					{/* Sort Dropdown */}
					<div className="flex items-center gap-1">
						<select
							value={sortField}
							onChange={(e) => setSortField(e.target.value as ArticleSortField)}
							className="px-3 py-1.5 bg-gray-100 dark:bg-slate-700 border-0 rounded-xl text-xs font-medium text-gray-600 dark:text-gray-300 focus:ring-2 focus:ring-purple-500 cursor-pointer"
						>
							<option value="created_at">Date Added</option>
							<option value="published_date">Published</option>
							<option value="like_count">Likes</option>
							<option value="title">Title</option>
						</select>
						<button
							onClick={() => setSortOrder(sortOrder === 'desc' ? 'asc' : 'desc')}
							className="p-1.5 bg-gray-100 dark:bg-slate-700 rounded-lg text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
							title={sortOrder === 'desc' ? 'Descending' : 'Ascending'}
						>
							<svg className={`w-4 h-4 transition-transform ${sortOrder === 'asc' ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
							</svg>
						</button>
					</div>

					{/* More Filters Button */}
					<button
						onClick={() => setShowAdvancedFilters(!showAdvancedFilters)}
						className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium transition-all ${showAdvancedFilters || selectedTags.length > 0 || selectedDomain
							? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 border border-purple-200 dark:border-purple-800'
							: 'bg-gray-100 dark:bg-slate-700 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
							}`}
					>
						<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
						</svg>
						More
						{(selectedTags.length > 0 || selectedDomain) && (
							<span className="w-4 h-4 bg-purple-500 text-white text-[10px] rounded-full flex items-center justify-center">
								{selectedTags.length + (selectedDomain ? 1 : 0)}
							</span>
						)}
					</button>

					{/* Clear Filters */}
					{hasActiveFilters && (
						<button
							onClick={clearFilters}
							className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-red-500 dark:text-red-400 hover:text-red-600 dark:hover:text-red-300 transition-colors"
						>
							<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
							</svg>
							Clear
						</button>
					)}
				</div>

				{/* Advanced Filters Panel */}
				{showAdvancedFilters && (
					<div className="mt-4 pt-4 border-t border-gray-100 dark:border-slate-700 space-y-4">
						{/* Tags Filter */}
						{availableTags.length > 0 && (
							<div>
								<label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-2">Tags</label>
								<div className="flex flex-wrap gap-2">
									{availableTags.map((tag) => (
										<button
											key={tag}
											onClick={() => toggleTag(tag)}
											className={`px-3 py-1 rounded-lg text-xs font-medium transition-colors ${selectedTags.includes(tag)
												? 'bg-purple-600 text-white'
												: 'bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-slate-600'
												}`}
										>
											{tag}
										</button>
									))}
								</div>
							</div>
						)}

						{/* Domain Filter */}
						{availableDomains.length > 0 && (
							<div>
								<label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-2">Domain</label>
								<select
									value={selectedDomain}
									onChange={(e) => setSelectedDomain(e.target.value)}
									className="block w-full sm:w-auto px-3 py-2 border border-gray-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-purple-500 focus:border-transparent"
								>
									<option value="">All domains</option>
									{availableDomains.map((domain) => (
										<option key={domain} value={domain}>
											{domain}
										</option>
									))}
								</select>
							</div>
						)}
					</div>
				)}
			</div>

			{/* Empty State */}
			{articles.length === 0 && (
				<div className="text-center py-16 px-4">
					<div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-purple-100 to-pink-100 dark:from-purple-900/30 dark:to-pink-900/30 mb-4">
						<svg className="w-10 h-10 text-purple-600 dark:text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
						</svg>
					</div>
					<p className="text-gray-600 dark:text-gray-300 text-lg font-medium">No articles found</p>
					<p className="text-gray-500 dark:text-gray-400 text-sm mt-2">
						{hasActiveFilters ? 'Try adjusting your filters' : 'Add your first article to get started!'}
					</p>
				</div>
			)}

			{/* Grid View */}
			{articles.length > 0 && viewMode === 'grid' && (
				<div className="grid gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
					{articles.map((article, index) => (
						<ArticleCard
							key={article.id}
							article={article}
							index={index}
							onClick={handleArticleClick}
							onToggleFavorite={handleToggleFavorite}
							onDelete={handleDeleteClick}
							onEditTags={handleTagClick}
						/>
					))}
				</div>
			)}

			{/* List View */}
			{articles.length > 0 && viewMode === 'list' && (
				<div className="space-y-4">
					{articles.map((article, index) => (
						<ArticleRow
							key={article.id}
							article={article}
							index={index}
							onClick={handleArticleClick}
							onToggleFavorite={handleToggleFavorite}
							onDelete={handleDeleteClick}
							onEditTags={handleTagClick}
						/>
					))}
				</div>
			)}

			{/* Loading indicator per infinite scrolling */}
			{loadingMore && (
				<div className="flex justify-center items-center py-8">
					<div className="flex flex-col items-center gap-3">
						<div className="w-8 h-8 border-3 border-purple-200 dark:border-purple-900 border-t-purple-600 dark:border-t-purple-400 rounded-full animate-spin"></div>
						<p className="text-purple-600 dark:text-purple-400 text-sm font-medium">Loading more articles...</p>
					</div>
				</div>
			)}

			{/* Elemento osservatore per infinite scrolling */}
			<div ref={observerTarget} className="h-4"></div>

			{/* Messaggio fine lista */}
			{!hasMore && articles.length > 0 && (
				<div className="text-center py-8">
					<p className="text-gray-500 dark:text-gray-400 text-sm">You&apos;ve reached the end of your articles</p>
				</div>
			)}

			{/* Delete Confirmation Modal */}
			{showDeleteConfirm && articleToDelete && (
				<div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
					<div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl max-w-md w-full p-6 transform transition-all">
						<div className="flex items-center gap-4 mb-4">
							<div className="flex-shrink-0 w-12 h-12 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
								<svg className="w-6 h-6 text-red-600 dark:text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
								</svg>
							</div>
							<div>
								<h3 className="text-lg font-bold text-gray-900 dark:text-gray-100">Delete Article</h3>
								<p className="text-sm text-gray-600 dark:text-gray-400">This action cannot be undone</p>
							</div>
						</div>
						<p className="text-gray-700 dark:text-gray-300 mb-6">
							Are you sure you want to delete &quot;{articleToDelete.title}&quot;? This will permanently remove the article from your library.
						</p>
						<div className="flex gap-3 justify-end">
							<button
								onClick={handleDeleteCancel}
								disabled={isDeleting}
								className="px-4 py-2 bg-gray-100 dark:bg-slate-700 text-gray-700 dark:text-gray-200 font-medium rounded-xl hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors disabled:opacity-50"
							>
								Cancel
							</button>
							<button
								onClick={handleDeleteConfirm}
								disabled={isDeleting}
								className="px-4 py-2 bg-red-600 text-white font-medium rounded-xl hover:bg-red-700 transition-colors disabled:opacity-50 flex items-center gap-2"
							>
								{isDeleting ? (
									<>
										<div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
										Deleting...
									</>
								) : (
									<>
										<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
										</svg>
										Delete
									</>
								)}
							</button>
						</div>
					</div>
				</div>
			)}

			{/* Tag Management Modal */}
			{showTagModal && articleForTags && (
				<TagManagementModal
					isOpen={showTagModal}
					onClose={() => {
						setShowTagModal(false);
						setArticleForTags(null);
					}}
					article={articleForTags}
					onSave={handleSaveTags}
				/>
			)}

			{/* CSS Animations */}
			<style jsx>{`
				@keyframes fadeInUp {
					from {
						opacity: 0;
						transform: translateY(20px);
					}
					to {
						opacity: 1;
						transform: translateY(0);
					}
				}
			`}</style>

		</div>
	);
}
