'use client';

import { useEffect, useState, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { getArticles } from '../lib/api';
import { Article } from '../lib/supabase';

interface ArticleListProps {
	userId: string;
	refreshTrigger: number;
}

const ITEMS_PER_PAGE = 10;

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

export default function ArticleList({ userId, refreshTrigger }: ArticleListProps) {
	const [articles, setArticles] = useState<Article[]>([]);
	const [loading, setLoading] = useState(true);
	const [loadingMore, setLoadingMore] = useState(false);
	const [error, setError] = useState('');
	const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
	const [hasMore, setHasMore] = useState(true);
	const [offset, setOffset] = useState(0);
	const router = useRouter();

	const observerTarget = useRef<HTMLDivElement>(null);

	// Funzione per caricare gli articoli
	const loadArticles = useCallback(async (reset: boolean = false) => {
		const currentOffset = reset ? 0 : offset;

		if (reset) {
			setLoading(true);
		} else {
			setLoadingMore(true);
		}

		try {
			const { articles: newArticles, hasMore: more } = await getArticles(userId, ITEMS_PER_PAGE, currentOffset);

			if (reset) {
				setArticles(newArticles);
				setOffset(ITEMS_PER_PAGE);
			} else {
				setArticles((prev) => [...prev, ...newArticles]);
				setOffset((prev) => prev + ITEMS_PER_PAGE);
			}

			setHasMore(more);
			setError('');
		} catch (err) {
			setError('Failed to load articles');
			console.error(err);
		} finally {
			setLoading(false);
			setLoadingMore(false);
		}
	}, [userId, offset]);

	// Carica articoli iniziali o quando refreshTrigger cambia
	useEffect(() => {
		setOffset(0);
		loadArticles(true);
	}, [userId, refreshTrigger]);

	// Intersection Observer per infinite scrolling
	useEffect(() => {
		const observer = new IntersectionObserver(
			(entries) => {
				if (entries[0].isIntersecting && hasMore && !loading && !loadingMore) {
					loadArticles(false);
				}
			},
			{ threshold: 0.1 }
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
	}, [hasMore, loading, loadingMore, loadArticles]);

	// Funzione per navigare all'articolo
	const handleArticleClick = (articleId: string) => {
		router.push(`/articles/${articleId}`);
	};

	// Previeni la propagazione del click per i link esterni
	const handleExternalLinkClick = (e: React.MouseEvent) => {
		e.stopPropagation();
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

	if (articles.length === 0) {
		return (
			<div className="text-center py-16 px-4">
				<div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-purple-100 to-pink-100 mb-4">
					<svg className="w-10 h-10 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
					</svg>
				</div>
				<p className="text-gray-600 text-lg font-medium">No articles found</p>
				<p className="text-gray-500 text-sm mt-2">Add your first article above!</p>
			</div>
		);
	}

	return (
		<div className="mt-8">
			{/* Toggle View Mode - Mobile First */}
			<div className="flex justify-between items-center mb-6">
				<h2 className="text-xl sm:text-2xl font-bold text-gray-800">
					My Articles
					<span className="ml-2 text-sm font-normal text-gray-500">({articles.length}{!hasMore ? '' : '+'})</span>
				</h2>
				<div className="bg-white/80 backdrop-blur-sm rounded-xl shadow-sm p-1 flex border border-gray-200">
					<button
						onClick={() => setViewMode('grid')}
						className={`p-2 rounded-lg transition-all duration-200 ${
							viewMode === 'grid'
								? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-md'
								: 'text-gray-400 hover:text-gray-600'
						}`}
						title="Grid View"
					>
						<svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
						</svg>
					</button>
					<button
						onClick={() => setViewMode('list')}
						className={`p-2 rounded-lg transition-all duration-200 ${
							viewMode === 'list'
								? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-md'
								: 'text-gray-400 hover:text-gray-600'
						}`}
						title="List View"
					>
						<svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
						</svg>
					</button>
				</div>
			</div>

			{/* Grid View - Card moderne con effetti */}
			{viewMode === 'grid' ? (
				<div className="grid gap-5 sm:gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
					{articles.map((article, index) => (
						<article
							key={article.id}
							onClick={() => handleArticleClick(article.id)}
							className="group bg-white/80 backdrop-blur-sm rounded-2xl overflow-hidden shadow-md hover:shadow-2xl transition-all duration-300 border border-gray-100 hover:border-purple-200 hover:-translate-y-1 cursor-pointer"
							style={{
								animation: `fadeInUp 0.5s ease-out ${index * 0.1}s both`,
							}}
						>
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
			) : (
				/* List View - Design moderno */
				<div className="space-y-4">
					{articles.map((article, index) => (
						<article
							key={article.id}
							onClick={() => handleArticleClick(article.id)}
							className="group bg-white/80 backdrop-blur-sm rounded-2xl p-4 sm:p-5 flex gap-4 shadow-md hover:shadow-xl transition-all duration-300 border border-gray-100 hover:border-purple-200 cursor-pointer"
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
								<p className="text-gray-600 text-sm mb-3 line-clamp-2 flex-1">{article.excerpt}</p>

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
