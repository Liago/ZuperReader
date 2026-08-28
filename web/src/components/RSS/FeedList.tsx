'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { FeedItem } from '@/lib/rssService';
import { parseArticle, saveArticle, getRSSArticles, markRSSArticleAsRead, markAllFeedArticlesAsRead } from '@/lib/api';
import type { RSSArticle } from '@/lib/supabase';
import { ArrowLeft, Bookmark, ExternalLink, CheckCheck } from 'lucide-react';
import ReaderModal from './ReaderModal';
import OptimizedImage from '@/components/OptimizedImage';

interface FeedListProps {
	feedUrl: string | null;
	feedId: string | null;
	userId: string;
	onFeedUpdated?: () => void;
	onBack?: () => void;
}

export default function FeedList({ feedUrl, feedId, userId, onFeedUpdated, onBack }: FeedListProps) {
	const [items, setItems] = useState<FeedItem[]>([]);
	const [feedTitle, setFeedTitle] = useState<string>('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [savingId, setSavingId] = useState<string | null>(null);
	const [rssArticles, setRssArticles] = useState<RSSArticle[]>([]);
	const [showReadArticles, setShowReadArticles] = useState(false);

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
				const data = await getFeedContent(feedUrl, feedId || undefined);

				if (data.error) throw new Error(data.error);
				if (data.feed) {
					setFeedTitle(data.feed.title || 'Untitled Feed');
					setItems(data.feed.items);

					if (data.syncStats && data.syncStats.added > 0 && onFeedUpdated) {
						onFeedUpdated();
					}
				}

				if (feedId) {
					const trackedArticles = await getRSSArticles(userId, feedId);
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
				word_count: parsed.word_count || 0,
			}, userId);
		} catch (err) {
			console.error('Failed to save', err);
			alert('Failed to save article to library');
		} finally {
			setSavingId(null);
		}
	};

	// Mark an article as read (reusable)
	const markArticleAsRead = useCallback(async (item: FeedItem) => {
		if (!feedId) return;

		const articleGuid = item.guid || item.link || item.title;
		const trackedArticle = rssArticles.find((a) => a.guid === articleGuid);

		if (trackedArticle && !trackedArticle.is_read) {
			try {
				await markRSSArticleAsRead(trackedArticle.id, userId);
				setRssArticles((prev) =>
					prev.map((a) => (a.id === trackedArticle.id ? { ...a, is_read: true, read_at: new Date().toISOString() } : a))
				);
			} catch (err) {
				console.error('Failed to mark article as read:', err);
			}
		}
	}, [feedId, rssArticles, userId]);

	const handleRead = async (item: FeedItem) => {
		if (!item.link) return;
		setReaderUrl(item.link);
		setIsReaderOpen(true);
		await markArticleAsRead(item);
	};

	const handleMarkAllRead = async () => {
		if (!feedId) return;
		try {
			await markAllFeedArticlesAsRead(feedId, userId);
			setRssArticles((prev) => prev.map((a) => ({ ...a, is_read: true, read_at: a.read_at || new Date().toISOString() })));
			if (onFeedUpdated) onFeedUpdated();
		} catch (err) {
			console.error('Failed to mark all as read:', err);
		}
	};

	const isArticleRead = (item: FeedItem): boolean => {
		if (!feedId || rssArticles.length === 0) return false;
		const articleGuid = item.guid || item.link || item.title;
		const trackedArticle = rssArticles.find((a) => a.guid === articleGuid);
		return trackedArticle?.is_read || false;
	};

	// Filter: show only unread by default, or all if showReadArticles is true
	const { filteredItems, readCount } = useMemo(() => {
		if (!feedId || rssArticles.length === 0) {
			return { filteredItems: items, readCount: 0 };
		}

		const readArticles: FeedItem[] = [];
		const unreadArticles: FeedItem[] = [];

		items.forEach((item) => {
			const articleGuid = item.guid || item.link || item.title;
			const trackedArticle = rssArticles.find((a) => a.guid === articleGuid);
			if (trackedArticle?.is_read) readArticles.push(item);
			else unreadArticles.push(item);
		});

		return {
			filteredItems: showReadArticles ? items : unreadArticles,
			readCount: readArticles.length,
		};
	}, [items, rssArticles, feedId, showReadArticles]);

	// Mark articles as read when scrolled past
	useEffect(() => {
		if (!feedId || items.length === 0) return;

		const observerCallback: IntersectionObserverCallback = (entries) => {
			entries.forEach((entry) => {
				if (!entry.isIntersecting && entry.boundingClientRect.top < 0) {
					const articleIndex = parseInt(entry.target.getAttribute('data-article-index') || '-1');
					if (articleIndex >= 0 && articleIndex < items.length) {
						markArticleAsRead(items[articleIndex]);
					}
				}
			});
		};

		const observer = new IntersectionObserver(observerCallback, {
			root: null,
			rootMargin: '-80px 0px 0px 0px',
			threshold: 0,
		});

		const articleElements = document.querySelectorAll('[data-article-index]');
		articleElements.forEach((el) => observer.observe(el));

		return () => observer.disconnect();
	}, [items, feedId, markArticleAsRead]);

	if (loading) {
		return (
			<div className="flex h-full flex-1 items-center justify-center">
				<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
			</div>
		);
	}

	if (error) {
		return (
			<div className="flex h-full flex-1 items-center justify-center px-4 text-center">
				<p className="font-semibold text-accent">Error: {error}</p>
			</div>
		);
	}

	if (!feedUrl) {
		return (
			<div className="flex h-full flex-1 items-center justify-center px-4 text-center">
				<p className="font-heading text-[24px] text-app-muted">Select a feed to start reading</p>
			</div>
		);
	}

	const unreadCount = feedId ? Math.max(0, items.length - readCount) : items.length;

	return (
		<div className="mx-auto h-full w-full max-w-[820px] overflow-y-auto px-8 py-7">
			{/* Header */}
			<div className="mb-6 border-b border-app-line pb-5">
				<div className="flex items-center gap-2">
					{onBack && (
						<button
							onClick={onBack}
							className="-ml-1 flex h-8 w-8 items-center justify-center rounded-full text-app-muted transition-colors hover:bg-app-hover hover:text-ink md:hidden"
							title="Back to feeds"
						>
							<ArrowLeft size={18} strokeWidth={2.75} />
						</button>
					)}
					<span className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">{unreadCount} unread</span>
				</div>
				<div className="mt-1 flex items-center justify-between gap-4">
					<h1 className="truncate font-heading text-[34px] leading-none text-ink">{feedTitle}</h1>
					{feedId && unreadCount > 0 && (
						<button
							onClick={handleMarkAllRead}
							className="flex flex-none items-center gap-1.5 rounded-full border border-app-line px-3.5 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							<CheckCheck size={15} strokeWidth={2.75} />
							Mark all read
						</button>
					)}
				</div>
			</div>

			{/* List */}
			<div>
				{filteredItems.map((item, idx) => {
					const isRead = isArticleRead(item);
					return (
						<div
							key={idx}
							data-article-index={idx}
							onClick={() => handleRead(item)}
							className={`group flex cursor-pointer gap-4 border-b border-app-line py-4 transition-opacity ${isRead ? 'opacity-55' : ''}`}
						>
							<span className={`mt-2 h-2 w-2 flex-none rounded-full ${isRead ? 'bg-accent/35' : 'bg-accent'}`} />

							<div className="min-w-0 flex-1">
								<h3 className={`text-pretty text-[17px] font-bold leading-[1.3] ${isRead ? 'text-app-muted' : 'text-ink'}`}>
									{item.title}
								</h3>
								<div className="mt-1 flex items-center gap-3 text-[12.5px] text-app-muted">
									{item.author && <span className="truncate">{item.author}</span>}
									{(item.pubDate || item.isoDate) && (
										<span>
											{new Date(item.pubDate || item.isoDate!).toLocaleDateString('en-US', {
												day: 'numeric',
												month: 'short',
												year: 'numeric',
											})}
										</span>
									)}
									<span className="ml-auto flex items-center gap-2 opacity-0 transition-opacity group-hover:opacity-100">
										<button
											onClick={(e) => {
												e.stopPropagation();
												handleSaveToLibrary(item);
											}}
											disabled={savingId === item.link}
											className="p-1 text-app-muted transition-colors hover:text-accent"
											title="Save to Library"
										>
											<Bookmark size={15} strokeWidth={2.75} className={savingId === item.link ? 'animate-pulse' : ''} />
										</button>
										<a
											href={item.link}
											target="_blank"
											rel="noopener noreferrer"
											onClick={(e) => e.stopPropagation()}
											className="p-1 text-app-muted transition-colors hover:text-accent"
											title="Open original"
										>
											<ExternalLink size={15} strokeWidth={2.75} />
										</a>
									</span>
								</div>
							</div>

							{item.imageUrl && (
								<div className="hidden h-[68px] w-[104px] flex-none overflow-hidden rounded-[14px] bg-app-surface sm:block">
									<OptimizedImage
										src={item.imageUrl}
										alt={item.title || 'Article thumbnail'}
										className="washed h-full w-full object-cover"
										width={104}
										height={68}
									/>
								</div>
							)}
						</div>
					);
				})}

				{/* Show / hide read */}
				{readCount > 0 && filteredItems.length > 0 && (
					<div className="flex justify-center py-6">
						<button
							onClick={() => setShowReadArticles(!showReadArticles)}
							className="rounded-full border border-app-line px-4 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							{showReadArticles ? 'Hide read articles' : `Show ${readCount} read articles`}
						</button>
					</div>
				)}
			</div>

			{/* Empty State */}
			{filteredItems.length === 0 && (
				<div className="rounded-[28px] border border-app-line bg-app-card px-6 py-16 text-center">
					<p className="font-heading text-[21px] text-ink">No new articles</p>
					<p className="mt-1.5 text-[13.5px] text-app-muted">
						{showReadArticles ? "You've read everything in this feed." : 'There are no unread articles in this feed.'}
					</p>
					{!showReadArticles && readCount > 0 && (
						<button
							onClick={() => setShowReadArticles(true)}
							className="mt-6 rounded-full border border-app-line px-4 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							Show {readCount} read articles
						</button>
					)}
				</div>
			)}

			<ReaderModal
				isOpen={isReaderOpen}
				onClose={() => setIsReaderOpen(false)}
				url={readerUrl}
				userId={userId}
				onNext={() => {
					const currentIndex = filteredItems.findIndex((item) => item.link === readerUrl);
					if (currentIndex < filteredItems.length - 1) {
						const nextItem = filteredItems[currentIndex + 1];
						setReaderUrl(nextItem.link || null);
						markArticleAsRead(nextItem);
					}
				}}
				onPrevious={() => {
					const currentIndex = filteredItems.findIndex((item) => item.link === readerUrl);
					if (currentIndex > 0) {
						const prevItem = filteredItems[currentIndex - 1];
						setReaderUrl(prevItem.link || null);
						markArticleAsRead(prevItem);
					}
				}}
				hasNext={!!readerUrl && filteredItems.findIndex((item) => item.link === readerUrl) < filteredItems.length - 1}
				hasPrevious={!!readerUrl && filteredItems.findIndex((item) => item.link === readerUrl) > 0}
			/>
		</div>
	);
}
