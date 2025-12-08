'use client';

import { useEffect, useState, useRef, useCallback, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { deleteArticle, updateArticleTags, ArticleFilters, ArticleSortOptions, ArticleSortField, ArticleSortOrder } from '../lib/api';
import { Article } from '../lib/supabase';
import { useReadingPreferences } from '../contexts/ReadingPreferencesContext';
import { useArticles } from '../contexts/ArticlesContext';
import { TagList } from './TagBadge';
import TagManagementModal from './TagManagementModal';

interface ArticleListProps {
	userId: string;
}

// Skeleton Loader per Grid View
function GridSkeleton() {
	return (
		<div className="bg-white/60 backdrop-blur-sm rounded-2xl overflow-hidden shadow-sm border border-gray-100">
			<div className="w-full h-48 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 animate-pulse bg-[length:200%_100%]"></div>
			<div className="p-5 space-y-3">
				<div className="h-6 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded w-3/4 animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded w-1/2 animate-pulse bg-[length:200%_100%]"></div>
			</div>
		</div>
	);
}

// Skeleton Loader per List View
function ListSkeleton() {
	return (
		<div className="bg-white/60 backdrop-blur-sm rounded-2xl p-4 flex gap-4 shadow-sm border border-gray-100">
			<div className="w-24 h-24 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded-xl animate-pulse bg-[length:200%_100%] flex-shrink-0"></div>
			<div className="flex-1 space-y-3">
				<div className="h-6 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded w-3/4 animate-pulse bg-[length:200%_100%]"></div>
				<div className="h-4 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded w-1/2 animate-pulse bg-[length:200%_100%]"></div>
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

	// Local filter states for UI
	const [searchQuery, setSearchQuery] = useState('');
	const [readingStatus, setReadingStatus] = useState<'all' | 'unread' | 'reading' | 'completed'>('all');
	const [isFavorite, setIsFavorite] = useState<boolean | undefined>(undefined);
	const [sortField, setSortField] = useState<ArticleSortField>('created_at');
	const [sortOrder, setSortOrder] = useState<ArticleSortOrder>('desc');
	const [showAdvancedFilters, setShowAdvancedFilters] = useState(false);
	const [selectedTags, setSelectedTags] = useState<string[]>([]);
	const [selectedDomain, setSelectedDomain] = useState('');

	const router = useRouter();
	const { preferences, updatePreferences } = useReadingPreferences();
	const viewMode = preferences.viewMode;

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
	}, [hasMore, loadArticles, userId]);

	// Clear all filters
	const clearFilters = () => {
		setSearchQuery('');
		setSelectedTags([]);
		setReadingStatus('all');
		setIsFavorite(undefined);
		setSelectedDomain('');
		setSortField('created_at');
		setSortOrder('desc');
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

	// Previeni la propagazione del click per i link esterni
	const handleExternalLinkClick = (e: React.MouseEvent) => {
		e.stopPropagation();
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
			<div className="bg-white/80 backdrop-blur-sm rounded-2xl shadow-sm border border-gray-100 p-4 mb-6">
				{/* Top row: Title, Search, View Mode */}
				<div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
					{/* Title */}
					<h2 className="text-xl sm:text-2xl font-bold text-gray-800 whitespace-nowrap">
						My Articles
						<span className="ml-2 text-sm font-normal text-gray-500">({articles.length}{!hasMore ? '' : '+'})</span>
					</h2>

					{/* Search Bar */}
					<div className="flex-1 w-full sm:w-auto">
						<div className="relative">
							<div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
								<svg className="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
								</svg>
							</div>
							<input
								type="text"
								value={searchQuery}
								onChange={(e) => setSearchQuery(e.target.value)}
								placeholder="Search articles..."
								className="block w-full pl-9 pr-9 py-2 border border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent text-sm text-gray-900 placeholder-gray-400"
							/>
							{searchQuery && (
								<button
									onClick={() => setSearchQuery('')}
									className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
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
						<div className="bg-gray-100 rounded-xl p-1 flex">
							<button
								onClick={() => updatePreferences({ viewMode: 'grid' })}
								className={`p-2 rounded-lg transition-all duration-200 ${
									viewMode === 'grid'
										? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-md'
										: 'text-gray-400 hover:text-gray-600'
								}`}
								title="Grid View"
							>
								<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
								</svg>
							</button>
							<button
								onClick={() => updatePreferences({ viewMode: 'list' })}
								className={`p-2 rounded-lg transition-all duration-200 ${
									viewMode === 'list'
										? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-md'
										: 'text-gray-400 hover:text-gray-600'
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
					<div className="flex items-center gap-1 bg-gray-100 rounded-xl p-1">
						{(['all', 'unread', 'reading', 'completed'] as const).map((status) => (
							<button
								key={status}
								onClick={() => setReadingStatus(status)}
								className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
									readingStatus === status
										? 'bg-white text-purple-600 shadow-sm'
										: 'text-gray-500 hover:text-gray-700'
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
						className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium transition-all ${
							isFavorite === true
								? 'bg-pink-100 text-pink-600 border border-pink-200'
								: 'bg-gray-100 text-gray-500 hover:text-gray-700'
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
							className="px-3 py-1.5 bg-gray-100 border-0 rounded-xl text-xs font-medium text-gray-600 focus:ring-2 focus:ring-purple-500 cursor-pointer"
						>
							<option value="created_at">Date Added</option>
							<option value="published_date">Published</option>
							<option value="like_count">Likes</option>
							<option value="title">Title</option>
						</select>
						<button
							onClick={() => setSortOrder(sortOrder === 'desc' ? 'asc' : 'desc')}
							className="p-1.5 bg-gray-100 rounded-lg text-gray-500 hover:text-gray-700 transition-colors"
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
						className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium transition-all ${
							showAdvancedFilters || selectedTags.length > 0 || selectedDomain
								? 'bg-purple-100 text-purple-600 border border-purple-200'
								: 'bg-gray-100 text-gray-500 hover:text-gray-700'
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
							className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-red-500 hover:text-red-600 transition-colors"
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
					<div className="mt-4 pt-4 border-t border-gray-100 space-y-4">
						{/* Tags Filter */}
						{availableTags.length > 0 && (
							<div>
								<label className="block text-xs font-medium text-gray-600 mb-2">Tags</label>
								<div className="flex flex-wrap gap-2">
									{availableTags.map((tag) => (
										<button
											key={tag}
											onClick={() => toggleTag(tag)}
											className={`px-3 py-1 rounded-lg text-xs font-medium transition-colors ${
												selectedTags.includes(tag)
													? 'bg-purple-600 text-white'
													: 'bg-gray-100 text-gray-600 hover:bg-gray-200'
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
								<label className="block text-xs font-medium text-gray-600 mb-2">Domain</label>
								<select
									value={selectedDomain}
									onChange={(e) => setSelectedDomain(e.target.value)}
									className="block w-full sm:w-auto px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:border-transparent"
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
					<div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-purple-100 to-pink-100 mb-4">
						<svg className="w-10 h-10 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
						</svg>
					</div>
					<p className="text-gray-600 text-lg font-medium">No articles found</p>
					<p className="text-gray-500 text-sm mt-2">
						{hasActiveFilters ? 'Try adjusting your filters' : 'Add your first article to get started!'}
					</p>
				</div>
			)}

			{/* Grid View - Card moderne con effetti */}
			{articles.length > 0 && viewMode === 'grid' && (
				<div className="grid gap-5 sm:gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
					{articles.map((article, index) => (
						<article
							key={article.id}
							onClick={() => handleArticleClick(article.id)}
							className="group bg-white/80 backdrop-blur-sm rounded-2xl overflow-hidden shadow-md hover:shadow-2xl transition-all duration-300 border border-gray-100 hover:border-purple-200 hover:-translate-y-1 cursor-pointer relative"
							style={{
								animation: `fadeInUp 0.5s ease-out ${index * 0.1}s both`,
							}}
						>
							{/* Delete Button */}
							<button
								onClick={(e) => handleDeleteClick(e, article)}
								className="absolute top-3 right-3 z-20 p-2 bg-red-500/90 hover:bg-red-600 text-white rounded-lg shadow-lg opacity-0 group-hover:opacity-100 transition-all duration-200 hover:scale-110"
								title="Delete article"
							>
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
								</svg>
							</button>

							{/* Immagine con overlay gradient */}
							{article.image_url && (
								<div className="block relative overflow-hidden">
									<div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 z-10"></div>
									<img
										src={article.image_url}
										alt={article.title}
										className="w-full h-48 sm:h-52 object-cover transform group-hover:scale-105 transition-transform duration-500"
										loading="lazy"
									/>
								</div>
							)}

							{/* Content */}
							<div className="p-5">
								<h3 className="text-lg font-bold mb-2 line-clamp-2 text-gray-900 group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-purple-600 group-hover:to-pink-600 transition-all duration-300">
									{article.title}
								</h3>
								<p className="text-gray-600 text-sm mb-4 line-clamp-3 leading-relaxed">{article.excerpt}</p>

								{/* Meta info */}
								<div className="flex justify-between items-center text-xs text-gray-500 mb-3">
									<span className="flex items-center gap-1">
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
										</svg>
										{article.domain}
									</span>
									{article.estimated_read_time && (
										<span className="flex items-center gap-1">
											<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
											</svg>
											{article.estimated_read_time} min
										</span>
									)}
								</div>

								{/* Engagement stats */}
								<div className="flex items-center gap-4 text-xs text-gray-500 mb-3">
									<span className="flex items-center gap-1">
										<svg className="w-4 h-4 text-red-400" fill="currentColor" viewBox="0 0 24 24">
											<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
										</svg>
										{article.like_count || 0}
									</span>
									<span className="flex items-center gap-1">
										<svg className="w-4 h-4 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
										</svg>
										{article.comment_count || 0}
									</span>
								</div>

								{/* Tags */}
								<div className="mb-3 flex items-center gap-2">
									{article.tags && article.tags.length > 0 ? (
										<div onClick={(e) => e.stopPropagation()}>
											<TagList
												tags={article.tags}
												maxVisible={3}
												size="sm"
											/>
										</div>
									) : null}
									<button
										onClick={(e) => handleTagClick(e, article)}
										className="inline-flex items-center gap-1 px-2 py-0.5 text-xs text-purple-600 hover:text-pink-600 hover:bg-purple-50 rounded-full transition-colors border border-transparent hover:border-purple-200"
										title="Manage tags"
									>
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
										</svg>
										{article.tags && article.tags.length > 0 ? 'Edit' : 'Add tags'}
									</button>
								</div>

								{/* Link esterno */}
								<a
									href={article.url}
									target="_blank"
									rel="noopener noreferrer"
									onClick={handleExternalLinkClick}
									className="inline-flex items-center gap-1 text-xs text-purple-600 hover:text-pink-600 font-medium transition-colors"
								>
									View Original
									<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
									</svg>
								</a>
							</div>
						</article>
					))}
				</div>
			)}

			{/* List View - Design moderno */}
			{articles.length > 0 && viewMode === 'list' && (
				<div className="space-y-4">
					{articles.map((article, index) => (
						<article
							key={article.id}
							onClick={() => handleArticleClick(article.id)}
							className="group bg-white/80 backdrop-blur-sm rounded-2xl p-4 sm:p-5 flex gap-4 shadow-md hover:shadow-xl transition-all duration-300 border border-gray-100 hover:border-purple-200 cursor-pointer relative"
							style={{
								animation: `fadeInUp 0.5s ease-out ${index * 0.1}s both`,
							}}
						>
							{/* Immagine */}
							{article.image_url && (
								<div className="flex-shrink-0">
									<img
										src={article.image_url}
										alt={article.title}
										className="w-20 h-20 sm:w-28 sm:h-28 object-cover rounded-xl transform group-hover:scale-105 transition-transform duration-300"
										loading="lazy"
									/>
								</div>
							)}

							{/* Content */}
							<div className="flex-1 min-w-0 flex flex-col">
								<h3 className="text-base sm:text-lg font-bold mb-1 text-gray-900 line-clamp-1 group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-purple-600 group-hover:to-pink-600 transition-all">
									{article.title}
								</h3>
								<p className="text-gray-600 text-sm mb-2 line-clamp-2 flex-1">{article.excerpt}</p>

								{/* Tags in List View */}
								<div className="mb-2 flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
									{article.tags && article.tags.length > 0 && (
										<TagList
											tags={article.tags}
											maxVisible={4}
											size="sm"
										/>
									)}
									<button
										onClick={(e) => handleTagClick(e, article)}
										className="inline-flex items-center gap-1 px-2 py-0.5 text-xs text-purple-600 hover:text-pink-600 hover:bg-purple-50 rounded-full transition-colors"
										title="Manage tags"
									>
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
										</svg>
										{article.tags && article.tags.length > 0 ? '' : 'Add tags'}
									</button>
								</div>

								{/* Meta info */}
								<div className="flex flex-wrap gap-3 items-center text-xs text-gray-500">
									<span className="flex items-center gap-1">
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
										</svg>
										{article.domain}
									</span>
									{article.estimated_read_time && (
										<span className="flex items-center gap-1">
											<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
											</svg>
											{article.estimated_read_time} min
										</span>
									)}
									{/* Engagement stats */}
									<span className="flex items-center gap-1">
										<svg className="w-3 h-3 text-red-400" fill="currentColor" viewBox="0 0 24 24">
											<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
										</svg>
										{article.like_count || 0}
									</span>
									<span className="flex items-center gap-1">
										<svg className="w-3 h-3 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
										</svg>
										{article.comment_count || 0}
									</span>
									<a
										href={article.url}
										target="_blank"
										rel="noopener noreferrer"
										onClick={handleExternalLinkClick}
										className="ml-auto text-purple-600 hover:text-pink-600 font-medium inline-flex items-center gap-1"
									>
										View Original
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
										</svg>
									</a>
								</div>
							</div>

							{/* Delete Button */}
							<button
								onClick={(e) => handleDeleteClick(e, article)}
								className="self-start p-2 bg-red-500/90 hover:bg-red-600 text-white rounded-lg shadow-lg opacity-0 group-hover:opacity-100 transition-all duration-200 hover:scale-110"
								title="Delete article"
							>
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
								</svg>
							</button>
						</article>
					))}
				</div>
			)}

			{/* Loading indicator per infinite scrolling */}
			{loadingMore && (
				<div className="flex justify-center items-center py-8">
					<div className="flex flex-col items-center gap-3">
						<div className="w-8 h-8 border-3 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
						<p className="text-purple-600 text-sm font-medium">Loading more articles...</p>
					</div>
				</div>
			)}

			{/* Elemento osservatore per infinite scrolling */}
			<div ref={observerTarget} className="h-4"></div>

			{/* Messaggio fine lista */}
			{!hasMore && articles.length > 0 && (
				<div className="text-center py-8">
					<p className="text-gray-500 text-sm">You've reached the end of your articles</p>
				</div>
			)}

			{/* Delete Confirmation Modal */}
			{showDeleteConfirm && articleToDelete && (
				<div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
					<div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-6 transform transition-all">
						<div className="flex items-center gap-4 mb-4">
							<div className="flex-shrink-0 w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
								<svg className="w-6 h-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
								</svg>
							</div>
							<div>
								<h3 className="text-lg font-bold text-gray-900">Delete Article</h3>
								<p className="text-sm text-gray-600">This action cannot be undone</p>
							</div>
						</div>
						<p className="text-gray-700 mb-6">
							Are you sure you want to delete "{articleToDelete.title}"? This will permanently remove the article from your library.
						</p>
						<div className="flex gap-3 justify-end">
							<button
								onClick={handleDeleteCancel}
								disabled={isDeleting}
								className="px-4 py-2 bg-gray-100 text-gray-700 font-medium rounded-xl hover:bg-gray-200 transition-colors disabled:opacity-50"
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
