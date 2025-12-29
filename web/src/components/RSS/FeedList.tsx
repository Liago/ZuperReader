'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { FeedData, FeedItem } from '@/lib/rssService';
import { parseArticle, saveArticle, getRSSArticles, markRSSArticleAsRead } from '@/lib/api';
import type { RSSArticle } from '@/lib/supabase';
import ReaderModal from './ReaderModal';

interface FeedListProps {
	feedUrl: string | null;
	feedId: string | null;
	userId: string;
	onFeedUpdated?: () => void;
}

export default function FeedList({ feedUrl, feedId, userId, onFeedUpdated }: FeedListProps) {
	const [items, setItems] = useState<FeedItem[]>([]);
	const [feedTitle, setFeedTitle] = useState<string>('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [savingId, setSavingId] = useState<string | null>(null);
	const [rssArticles, setRssArticles] = useState<RSSArticle[]>([]);

	// Reader Modal State
	const [readerUrl, setReaderUrl] = useState<string | null>(null);
	const [isReaderOpen, setIsReaderOpen] = useState(false);

	useEffect(() => {
		if (!feedUrl) {
			setItems([]);
			setFeedTitle('Select a feed to read');
			setRssArticles([]);
			return;
		}

		const loadFeed = async () => {
			setLoading(true);
			setError(null);
			try {
				const { getFeedContent } = await import('@/app/actions/rss');

				console.log('🔄 Loading feed:', { feedUrl, feedId });

				// Pass feedId to sync articles to database
				const data = await getFeedContent(feedUrl, feedId || undefined);

				console.log('📦 Feed data received:', {
					hasError: !!data.error,
					itemsCount: data.feed?.items?.length || 0,
					syncStats: data.syncStats
				});

				if (data.error) throw new Error(data.error);
				if (data.feed) {
					setFeedTitle(data.feed.title || 'Untitled Feed');
					setItems(data.feed.items);

					if (data.syncStats) {
						console.log('✅ Synced to database:', data.syncStats);

						if (data.syncStats.added > 0 && onFeedUpdated) {
							onFeedUpdated();
						}
					}
				}

				// Load tracked articles from database
				if (feedId) {
					const trackedArticles = await getRSSArticles(userId, feedId);
					console.log('📊 Tracked articles loaded:', trackedArticles.length);
					setRssArticles(trackedArticles);
				}
			} catch (err) {
				console.error('❌ Error loading feed:', err);
				setError((err as Error).message);
			} finally {
				setLoading(false);
			}
		};

		loadFeed();
	}, [feedUrl, feedId, userId]);

	const handleSaveToLibrary = async (item: FeedItem) => {
		if (!item.link) return;
		setSavingId(item.link);

		try {
			const parsed = await parseArticle(item.link);

			await saveArticle({
				url: item.link,
				title: parsed.title || item.title || 'Untitled',
				content: parsed.content || item.content || '',
				excerpt: parsed.excerpt || item.contentSnippet || null,
				lead_image_url: parsed.lead_image_url || null,
				author: parsed.author || item.author || null,
				date_published: parsed.date_published || item.pubDate || null,
				word_count: parsed.word_count || 0
			}, userId);

		} catch (err) {
			console.error('Failed to save', err);
			alert('Failed to save article to library');
		} finally {
			setSavingId(null);
		}
	};

	// Mark an article as read (extracted to reusable function)
	const markArticleAsRead = useCallback(async (item: FeedItem) => {
		if (!feedId) return;

		const articleGuid = item.guid || item.link || item.title;
		const trackedArticle = rssArticles.find(a => a.guid === articleGuid);

		if (trackedArticle && !trackedArticle.is_read) {
			try {
				await markRSSArticleAsRead(trackedArticle.id, userId);
				// Update local state
				setRssArticles(prev => prev.map(a =>
					a.id === trackedArticle.id ? { ...a, is_read: true, read_at: new Date().toISOString() } : a
				));
			} catch (err) {
				console.error('Failed to mark article as read:', err);
			}
		}
	}, [feedId, rssArticles, userId]);

	const handleRead = async (item: FeedItem) => {
		if (!item.link) return;
		setReaderUrl(item.link);
		setIsReaderOpen(true);

		// Also mark as read when opening in modal
		await markArticleAsRead(item);
	};

	// Helper function to check if an article is read
	const isArticleRead = (item: FeedItem): boolean => {
		if (!feedId || rssArticles.length === 0) return false;
		const articleGuid = item.guid || item.link || item.title;
		const trackedArticle = rssArticles.find(a => a.guid === articleGuid);
		return trackedArticle?.is_read || false;
	};

	// Intersection Observer to mark articles as read when scrolled past
	useEffect(() => {
		if (!feedId || items.length === 0) return;

		const observerCallback: IntersectionObserverCallback = (entries) => {
			entries.forEach((entry) => {
				// Mark as read when article exits viewport from top (scrolling down)
				if (!entry.isIntersecting && entry.boundingClientRect.top < 0) {
					const articleIndex = parseInt(entry.target.getAttribute('data-article-index') || '-1');
					if (articleIndex >= 0 && articleIndex < items.length) {
						const item = items[articleIndex];
						// Debounce: only mark if article has been scrolled past completely
						markArticleAsRead(item);
					}
				}
			});
		};

		const observer = new IntersectionObserver(observerCallback, {
			root: null, // viewport
			rootMargin: '-80px 0px 0px 0px', // Trigger when article is 80px past top (after header)
			threshold: 0
		});

		// Observe all article elements
		const articleElements = document.querySelectorAll('[data-article-index]');
		articleElements.forEach(el => observer.observe(el));

		return () => {
			observer.disconnect();
		};
	}, [items, feedId, markArticleAsRead]);

	if (loading) {
		return (
			<div className="flex-1 p-8 flex items-center justify-center">
				<div className="flex flex-col items-center gap-4">
					<div className="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full animate-spin"></div>
					<p className="text-orange-600 font-medium">Loading feed...</p>
				</div>
			</div>
		);
	}

	if (error) {
		return (
			<div className="flex-1 p-8 flex items-center justify-center">
				<div className="bg-white/60 backdrop-blur-sm p-8 rounded-2xl shadow-lg text-center">
					<p className="text-red-600 font-semibold">Error: {error}</p>
				</div>
			</div>
		);
	}

	if (!feedUrl) {
		return (
			<div className="flex-1 p-8 flex items-center justify-center">
				<div className="text-center">
					<div className="w-20 h-20 mx-auto mb-4 bg-gradient-to-br from-orange-500 to-pink-500 rounded-2xl flex items-center justify-center">
						<svg className="w-12 h-12 text-white" fill="currentColor" viewBox="0 0 20 20">
							<path d="M5 3a1 1 0 000 2c5.523 0 10 4.477 10 10a1 1 0 102 0C17 8.373 11.627 3 5 3z" />
							<path d="M5 9a1 1 0 000 2 4.002 4.002 0 014 4 1 1 0 102 0 6.002 6.002 0 00-6-6z" />
							<path d="M5 15a1 1 0 100 2 1 1 0 000-2z" />
						</svg>
					</div>
					<p className="text-2xl font-bold bg-gradient-to-r from-orange-600 via-pink-600 to-purple-600 bg-clip-text text-transparent">Select a feed to start reading</p>
				</div>
			</div>
		);
	}

	return (
		<div className="flex-1 overflow-y-auto p-4 sm:p-6">
			<h1 className="text-2xl font-bold mb-4 bg-gradient-to-r from-orange-600 via-pink-600 to-purple-600 bg-clip-text text-transparent border-b border-gray-200 pb-3">{feedTitle}</h1>

			{/* List View - Compact */}
			<div className="max-w-5xl mx-auto">
				{items.map((item, idx) => {
					const isRead = isArticleRead(item);
					return (
						<div
							key={idx}
							data-article-index={idx}
							className={`
                    border-b border-gray-200 py-3 px-2
                    hover:bg-orange-50/50 transition-colors cursor-pointer
                    ${isRead ? 'bg-gray-50/50' : 'bg-white'}
                  `}
							onClick={() => handleRead(item)}
						>
							{/* Header Row: Title + Status */}
							<div className="flex items-start gap-3 mb-1">
								{/* Unread Indicator Dot */}
								{!isRead && (
									<div className="flex-shrink-0 mt-1.5">
										<div className="w-2 h-2 rounded-full bg-gradient-to-r from-orange-500 to-pink-500"></div>
									</div>
								)}
								{isRead && (
									<div className="flex-shrink-0 mt-1.5">
										<div className="w-2 h-2 rounded-full bg-gray-300"></div>
									</div>
								)}

								{/* Title */}
								<div className="flex-1 min-w-0">
									<h3 className={`
                              text-base font-semibold leading-tight
                              ${isRead ? 'text-gray-500' : 'text-gray-900'}
                              hover:text-orange-600 transition-colors
                          `}>
										{item.title}
									</h3>
								</div>

								{/* Read Badge */}
								{isRead && (
									<span className="flex-shrink-0 text-xs bg-gray-200 text-gray-600 px-2 py-0.5 rounded-full font-medium">
										Read
									</span>
								)}
							</div>

							{/* Metadata Row */}
							<div className="flex items-center gap-4 text-xs text-gray-500 ml-5">
								{item.author && (
									<span className="flex items-center gap-1">
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
										</svg>
										{item.author}
									</span>
								)}
								{(item.pubDate || item.isoDate) && (
									<span className="flex items-center gap-1">
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
										</svg>
										{new Date(item.pubDate || item.isoDate!).toLocaleDateString('it-IT', {
											day: 'numeric',
											month: 'short',
											year: 'numeric'
										})}
									</span>
								)}

								{/* Quick Actions */}
								<div className="ml-auto flex items-center gap-2">
									<button
										onClick={(e) => {
											e.stopPropagation();
											handleSaveToLibrary(item);
										}}
										disabled={savingId === item.link}
										className="text-gray-400 hover:text-orange-600 transition-colors p-1"
										title="Save to Library"
									>
										{savingId === item.link ? (
											<svg className="animate-spin h-3 w-3" fill="none" viewBox="0 0 24 24">
												<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
												<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
											</svg>
										) : (
											<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
											</svg>
										)}
									</button>

									<a
										href={item.link}
										target="_blank"
										rel="noopener noreferrer"
										onClick={(e) => e.stopPropagation()}
										className="text-gray-400 hover:text-orange-600 transition-colors p-1"
										title="Open original"
									>
										<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
										</svg>
									</a>
								</div>
							</div>
						</div>
					);
				})}
			</div>

			<ReaderModal
				isOpen={isReaderOpen}
				onClose={() => setIsReaderOpen(false)}
				url={readerUrl}
				userId={userId}
			/>
		</div>
	);
}
