'use client';

import { useEffect, useState, useRef, useCallback, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { Search, ChevronDown, LayoutGrid, List as ListIcon, X, Sparkles, BookOpen } from 'lucide-react';
import { deleteArticle, updateArticleTags, toggleFavorite, addToQueue, ArticleFilters, ArticleSortOptions, ArticleSortField } from '../lib/api';
import { Article } from '../lib/supabase';
import { useReadingPreferences } from '../contexts/ReadingPreferencesContext';
import { useArticles } from '../contexts/ArticlesContext';
import { useArticleFilters, ArticleSortOrder } from '../contexts/ArticleFiltersContext';
import { useShell } from './shell/AppShell';
import TagManagementModal from './TagManagementModal';
import ArticleCard from './ArticleCard';
import ArticleRow from './ArticleRow';

interface ArticleListProps {
	userId: string;
}

type SortChoice = {
	label: string;
	field: ArticleSortField;
	order: ArticleSortOrder;
};

const SORT_CHOICES: SortChoice[] = [
	{ label: 'Newest', field: 'created_at', order: 'desc' },
	{ label: 'Oldest', field: 'created_at', order: 'asc' },
	{ label: 'Published', field: 'published_date', order: 'desc' },
	{ label: 'Most liked', field: 'like_count', order: 'desc' },
	{ label: 'Title A–Z', field: 'title', order: 'asc' },
];

function GridSkeleton() {
	return (
		<div className="overflow-hidden rounded-[28px] border border-app-line bg-app-card">
			<div className="aspect-16/10 animate-pulse bg-app-surface" />
			<div className="space-y-3 p-5">
				<div className="h-4 w-1/3 animate-pulse rounded bg-app-surface" />
				<div className="h-5 animate-pulse rounded bg-app-surface" />
				<div className="h-4 w-2/3 animate-pulse rounded bg-app-surface" />
			</div>
		</div>
	);
}

function RowSkeleton() {
	return (
		<div className="flex items-center gap-5 px-[22px] py-[18px]">
			<div className="h-[76px] w-28 flex-none animate-pulse rounded-2xl bg-app-surface" />
			<div className="flex-1 space-y-3">
				<div className="h-4 w-1/4 animate-pulse rounded bg-app-surface" />
				<div className="h-5 w-2/3 animate-pulse rounded bg-app-surface" />
				<div className="h-4 w-1/2 animate-pulse rounded bg-app-surface" />
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
	const [sortOpen, setSortOpen] = useState(false);

	const router = useRouter();
	const { openSummary } = useShell();
	const { preferences, updatePreferences } = useReadingPreferences();
	const viewMode = preferences.viewMode;

	const {
		filters,
		setSearchQuery,
		setSortField,
		setSortOrder,
	} = useArticleFilters();

	const {
		searchQuery,
		readingStatus,
		isFavorite,
		sortField,
		sortOrder,
		selectedTags,
		selectedDomain,
	} = filters;

	const observerTarget = useRef<HTMLDivElement>(null);
	const prevUserIdRef = useRef<string>('');
	const searchTimeoutRef = useRef<NodeJS.Timeout | null>(null);

	const activeSortLabel = useMemo(() => {
		const match = SORT_CHOICES.find((c) => c.field === sortField && c.order === sortOrder);
		return match?.label ?? 'Newest';
	}, [sortField, sortOrder]);

	const buildFiltersAndSort = useCallback(() => {
		const newFilters: ArticleFilters = {
			searchQuery: searchQuery || undefined,
			tags: selectedTags.length > 0 ? selectedTags : undefined,
			readingStatus,
			isFavorite,
			domain: selectedDomain || undefined,
		};

		const newSort: ArticleSortOptions = { field: sortField, order: sortOrder };
		return { filters: newFilters, sort: newSort };
	}, [searchQuery, selectedTags, readingStatus, isFavorite, selectedDomain, sortField, sortOrder]);

	const isFirstLoadRef = useRef(true);

	// Debounced filter application
	useEffect(() => {
		if (isFirstLoadRef.current) return;

		if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);
		searchTimeoutRef.current = setTimeout(() => {
			const { filters, sort } = buildFiltersAndSort();
			loadArticles(userId, true, filters, sort);
		}, 300);

		return () => {
			if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);
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

	// Infinite scroll observer
	const loadingStateRef = useRef({ loading, loadingMore });
	useEffect(() => {
		loadingStateRef.current = { loading, loadingMore };
	}, [loading, loadingMore]);

	useEffect(() => {
		const observer = new IntersectionObserver(
			(entries) => {
				const { loading: isLoading, loadingMore: isLoadingMore } = loadingStateRef.current;
				if (entries[0].isIntersecting && hasMore && !isLoading && !isLoadingMore) {
					loadArticles(userId, false);
				}
			},
			{ threshold: 0, rootMargin: '400px' }
		);

		const currentTarget = observerTarget.current;
		if (currentTarget) observer.observe(currentTarget);
		return () => {
			if (currentTarget) observer.unobserve(currentTarget);
		};
	}, [hasMore, loadArticles, userId, loading, loadingMore]);

	const handleArticleClick = (articleId: string) => {
		router.push(`/articles/${articleId}`);
	};

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

	const handleAddToQueue = async (e: React.MouseEvent, article: Article) => {
		e.stopPropagation();
		try {
			await addToQueue(userId, article.id);
		} catch (err) {
			console.error('Failed to add to queue:', err);
		}
	};

	const handleToggleFavorite = async (e: React.MouseEvent, article: Article) => {
		e.preventDefault();
		e.stopPropagation();
		const newStatus = !article.is_favorite;
		updateArticle(article.id, { is_favorite: newStatus });
		try {
			await toggleFavorite(article.id, newStatus);
		} catch (err) {
			console.error('Failed to toggle favorite', err);
			updateArticle(article.id, { is_favorite: !newStatus });
		}
	};

	const header = (
		<div className="mb-6 flex flex-wrap items-end justify-between gap-4 border-b border-app-line pb-[18px]">
			<div>
				<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">Saved by you</div>
				<h1 className="mt-1 font-heading text-[34px] leading-none text-ink">Library</h1>
			</div>

			<div className="flex flex-wrap items-center gap-2.5">
				{/* Search */}
				<div className="flex w-[264px] items-center gap-2 rounded-full border border-app-line bg-app-card px-3.5 py-2">
					<Search size={16} strokeWidth={2.75} className="flex-none text-app-muted" />
					<input
						type="text"
						value={searchQuery}
						onChange={(e) => setSearchQuery(e.target.value)}
						placeholder="Search titles, tags, notes"
						className="w-full bg-transparent text-[13.5px] text-ink placeholder:text-app-muted focus:outline-none"
					/>
					{searchQuery && (
						<button type="button" onClick={() => setSearchQuery('')} className="flex-none text-app-muted hover:text-ink">
							<X size={14} strokeWidth={2.75} />
						</button>
					)}
				</div>

				{/* Sort */}
				<div className="relative">
					<button
						type="button"
						onClick={() => setSortOpen((v) => !v)}
						className="flex items-center gap-1.5 rounded-full border border-app-line px-3.5 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover"
					>
						{activeSortLabel}
						<ChevronDown size={15} strokeWidth={2.75} className={sortOpen ? 'rotate-180' : ''} />
					</button>
					{sortOpen && (
						<>
							<div className="fixed inset-0 z-40" onClick={() => setSortOpen(false)} />
							<div className="absolute right-0 z-50 mt-2 w-44 overflow-hidden rounded-2xl border border-app-line bg-app-card py-1 [box-shadow:var(--shadow-modal)]">
								{SORT_CHOICES.map((choice) => {
									const active = choice.field === sortField && choice.order === sortOrder;
									return (
										<button
											key={choice.label}
											type="button"
											onClick={() => {
												setSortField(choice.field);
												setSortOrder(choice.order);
												setSortOpen(false);
											}}
											className={`block w-full px-4 py-2 text-left text-[13.5px] transition-colors hover:bg-app-hover ${
												active ? 'font-semibold text-accent' : 'text-ink'
											}`}
										>
											{choice.label}
										</button>
									);
								})}
							</div>
						</>
					)}
				</div>

				{/* Weekly summary */}
				<button
					type="button"
					onClick={openSummary}
					title="Weekly summary"
					className="flex h-[38px] w-[38px] items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
				>
					<Sparkles size={16} strokeWidth={2.75} />
				</button>

				{/* View toggle */}
				<div className="flex items-center gap-1 rounded-full border border-app-line p-1">
					<button
						type="button"
						onClick={() => updatePreferences({ viewMode: 'grid' })}
						title="Grid view"
						className={`flex h-[30px] w-[30px] items-center justify-center rounded-full transition-colors ${
							viewMode === 'grid' ? 'bg-ink text-app-page' : 'text-app-muted hover:text-ink'
						}`}
					>
						<LayoutGrid size={15} strokeWidth={2.75} />
					</button>
					<button
						type="button"
						onClick={() => updatePreferences({ viewMode: 'list' })}
						title="List view"
						className={`flex h-[30px] w-[30px] items-center justify-center rounded-full transition-colors ${
							viewMode === 'list' ? 'bg-ink text-app-page' : 'text-app-muted hover:text-ink'
						}`}
					>
						<ListIcon size={15} strokeWidth={2.75} />
					</button>
				</div>
			</div>
		</div>
	);

	return (
		<div className="mx-auto max-w-[1200px] px-9 py-7">
			{header}

			{/* Loading (initial) */}
			{loading && (
				viewMode === 'grid' ? (
					<div className="grid grid-cols-1 gap-[22px] md:grid-cols-2 lg:grid-cols-3">
						{[...Array(6)].map((_, i) => <GridSkeleton key={i} />)}
					</div>
				) : (
					<div className="divide-y divide-app-line overflow-hidden rounded-[28px] border border-app-line bg-app-card">
						{[...Array(5)].map((_, i) => <RowSkeleton key={i} />)}
					</div>
				)
			)}

			{/* Error */}
			{!loading && error && (
				<div className="rounded-[28px] border border-app-line bg-app-card px-6 py-16 text-center">
					<p className="font-semibold text-accent">{error}</p>
				</div>
			)}

			{/* Empty */}
			{!loading && !error && articles.length === 0 && (
				<div className="rounded-[28px] border border-app-line bg-app-card px-6 py-20 text-center">
					<div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-app-surface">
						<BookOpen size={28} className="text-accent opacity-60" strokeWidth={1.75} />
					</div>
					<p className="font-heading text-[21px] text-ink">Nothing here yet</p>
					<p className="mt-1.5 text-[13.5px] text-app-muted">
						Save a link from the sidebar to start your library.
					</p>
				</div>
			)}

			{/* Grid */}
			{!loading && !error && articles.length > 0 && viewMode === 'grid' && (
				<div className="grid grid-cols-1 gap-[22px] md:grid-cols-2 lg:grid-cols-3">
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

			{/* List */}
			{!loading && !error && articles.length > 0 && viewMode === 'list' && (
				<div className="divide-y divide-app-line overflow-hidden rounded-[28px] border border-app-line bg-app-card">
					{articles.map((article, index) => (
						<ArticleRow
							key={article.id}
							article={article}
							index={index}
							onClick={handleArticleClick}
							onToggleFavorite={handleToggleFavorite}
							onDelete={handleDeleteClick}
							onEditTags={handleTagClick}
							onAddToQueue={handleAddToQueue}
						/>
					))}
				</div>
			)}

			{/* Loading more */}
			{loadingMore && (
				<div className="flex justify-center py-8">
					<div className="h-7 w-7 animate-spin rounded-full border-2 border-app-line border-t-accent" />
				</div>
			)}

			<div ref={observerTarget} className="h-4" />

			{!hasMore && articles.length > 0 && (
				<div className="py-8 text-center text-[13px] text-app-muted">
					You&apos;ve reached the end of your library
				</div>
			)}

			{/* Delete confirmation */}
			{showDeleteConfirm && articleToDelete && (
				<div
					className="fixed inset-0 z-50 grid place-items-center p-4"
					style={{ background: 'rgba(32,30,29,.42)' }}
					onClick={handleDeleteCancel}
				>
					<div
						className="w-full max-w-[440px] rounded-[28px] border border-app-line bg-app-card p-6 [box-shadow:var(--shadow-modal)]"
						onClick={(e) => e.stopPropagation()}
					>
						<h2 className="font-heading text-[24px] text-ink">Delete article</h2>
						<p className="mt-2 text-[13.5px] text-app-muted">
							Remove &quot;{articleToDelete.title}&quot; from your library? This can&apos;t be undone.
						</p>
						<div className="mt-6 flex justify-end gap-2.5">
							<button
								type="button"
								onClick={handleDeleteCancel}
								disabled={isDeleting}
								className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover disabled:opacity-50"
							>
								Cancel
							</button>
							<button
								type="button"
								onClick={handleDeleteConfirm}
								disabled={isDeleting}
								className="rounded-full bg-accent px-4 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600 disabled:opacity-50"
							>
								{isDeleting ? 'Deleting…' : 'Delete'}
							</button>
						</div>
					</div>
				</div>
			)}

			{/* Tag management */}
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
		</div>
	);
}
