'use client';

import React, { useEffect, useState, useRef, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft, Type, Sparkles, Bookmark, Eye, Trash2, Tag } from 'lucide-react';
import { getArticleById, deleteArticle, updateArticleTags, toggleFavorite, updateReadingStatus, updateReadingProgress, removeFromQueueByArticle } from '../../../lib/api';
import { Article } from '../../../lib/supabase';
import { useAuth } from '../../../contexts/AuthContext';
import { useReadingPreferences } from '../../../contexts/ReadingPreferencesContext';
import AppShell from '../../../components/shell/AppShell';
import ReadingSheet from '../../../components/ReadingSheet';
import LinkPreviewModal from '../../../components/LinkPreviewModal';
import VideoModal from '../../../components/VideoModal';
import VideoPlaceholder, { VideoInfo, extractVideoInfo } from '../../../components/VideoPlaceholder';
import CommentsSection from '../../../components/CommentsSection';
import ShareButton from '../../../components/ShareButton';
import InternalShareButton from '../../../components/InternalShareButton';
import { TagList } from '../../../components/TagBadge';
import TagManagementModal from '../../../components/TagManagementModal';
import ImageGalleryModal from '../../../components/ImageGalleryModal';
import AISummaryModal from '../../../components/AISummaryModal';

interface OutlineEntry {
	id: string;
	text: string;
	level: number;
}

export default function ArticleReaderPage() {
	const params = useParams();
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const { preferences } = useReadingPreferences();
	const [article, setArticle] = useState<Article | null>(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState('');
	const [showReadingSheet, setShowReadingSheet] = useState(false);
	const [linkPreviewUrl, setLinkPreviewUrl] = useState<string | null>(null);
	const [videoSrc, setVideoSrc] = useState<string | null>(null);
	const [currentVideoInfo, setCurrentVideoInfo] = useState<VideoInfo | null>(null);
	const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
	const [isDeleting, setIsDeleting] = useState(false);
	const [showTagModal, setShowTagModal] = useState(false);
	const [hasRestoredPosition, setHasRestoredPosition] = useState(false);
	const [imageGallery, setImageGallery] = useState<{ images: string[]; captions: string[]; currentIndex: number } | null>(null);
	const [showAISummaryModal, setShowAISummaryModal] = useState(false);
	const [focus, setFocus] = useState(false);
	const [scrollPct, setScrollPct] = useState(0);
	const [outline, setOutline] = useState<OutlineEntry[]>([]);
	const [activeHeadingId, setActiveHeadingId] = useState('');
	const articleContentRef = useRef<HTMLDivElement>(null);
	const saveProgressTimeoutRef = useRef<NodeJS.Timeout | null>(null);

	const id = params?.id as string;
	const isSerif = preferences.fontFamily === 'serif';

	const getFontSizeStyle = () => {
		if (preferences.fontSize <= 14) return 'prose-sm';
		if (preferences.fontSize <= 18) return 'prose-base';
		if (preferences.fontSize <= 22) return 'prose-lg';
		return 'prose-xl';
	};

	const getLineHeightClass = () => {
		switch (preferences.lineHeight) {
			case 'compact': return 'leading-snug';
			case 'normal': return 'leading-normal';
			case 'relaxed': return 'leading-relaxed';
			case 'loose': return 'leading-loose';
			default: return 'leading-relaxed';
		}
	};

	// Save reading progress with debouncing (save after 2 seconds of no change)
	const handleProgressChange = useCallback((progress: number) => {
		if (!article) return;
		if (saveProgressTimeoutRef.current) clearTimeout(saveProgressTimeoutRef.current);
		saveProgressTimeoutRef.current = setTimeout(async () => {
			try {
				await updateReadingProgress(article.id, progress);
			} catch (error) {
				console.error('Failed to save reading progress:', error);
			}
		}, 2000);
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [article?.id]);

	// Restore scroll position based on saved reading progress
	useEffect(() => {
		if (!article || !articleContentRef.current || hasRestoredPosition) return;

		if (article.reading_progress > 0 && article.reading_status !== 'completed') {
			const restorePosition = () => {
				const contentElement = articleContentRef.current;
				if (!contentElement) return;

				const contentTop = contentElement.offsetTop;
				const contentHeight = contentElement.offsetHeight;
				const windowHeight = window.innerHeight;
				const scrollRange = contentHeight - windowHeight;
				const targetScroll = contentTop + (scrollRange * article.reading_progress / 100);

				window.scrollTo({ top: Math.max(0, targetScroll), behavior: 'smooth' });
				setHasRestoredPosition(true);
			};

			const timeoutId = setTimeout(restorePosition, 100);
			return () => clearTimeout(timeoutId);
		} else {
			setHasRestoredPosition(true);
		}
	}, [article?.id, article?.reading_progress, article?.reading_status, hasRestoredPosition]);

	// Cleanup timeout on unmount
	useEffect(() => {
		return () => {
			if (saveProgressTimeoutRef.current) clearTimeout(saveProgressTimeoutRef.current);
		};
	}, []);

	const handleDeleteArticle = async () => {
		if (!article) return;
		setIsDeleting(true);
		try {
			await deleteArticle(article.id);
			router.push('/');
		} catch (error) {
			console.error('Failed to delete article:', error);
			setError('Failed to delete article');
			setIsDeleting(false);
			setShowDeleteConfirm(false);
		}
	};

	const handleSaveTags = async (tags: string[]) => {
		if (!article) return;
		try {
			const updatedArticle = await updateArticleTags(article.id, tags);
			setArticle({ ...article, tags: updatedArticle.tags });
		} catch (error) {
			console.error('Failed to update tags:', error);
			throw error;
		}
	};

	useEffect(() => {
		if (!authLoading && !user) {
			router.push('/login');
			return;
		}
		if (authLoading) return;
		if (!id) {
			setError('Invalid article ID');
			setLoading(false);
			return;
		}

		const fetchArticle = async () => {
			try {
				const data = await getArticleById(id);
				if (!data) setError('Article not found');
				else setArticle(data);
			} catch {
				setError('Failed to load article');
			} finally {
				setLoading(false);
			}
		};

		fetchArticle();
	}, [id, user, authLoading, router]);

	// Auto-mark article as "reading" when opened (if it's unread)
	useEffect(() => {
		if (article && article.reading_status === 'unread') {
			const markAsReading = async () => {
				try {
					await updateReadingStatus(article.id, 'reading');
					setArticle({ ...article, reading_status: 'reading' });
				} catch (error) {
					console.error('Failed to update reading status:', error);
				}
			};
			markAsReading();
		}
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [article?.id]);

	// Track scroll: progress percentage, save, active heading, and completion.
	useEffect(() => {
		if (!article) return;

		const handleScroll = () => {
			const contentElement = articleContentRef.current;
			if (!contentElement) return;

			const contentTop = contentElement.offsetTop;
			const contentBottom = contentTop + contentElement.offsetHeight;
			const windowHeight = window.innerHeight;
			const viewportTop = window.scrollY;

			const scrollStart = contentTop;
			const scrollEnd = contentBottom - windowHeight;
			const scrollRange = scrollEnd - scrollStart;

			let pct = 0;
			if (scrollRange <= 0) {
				pct = viewportTop >= contentTop ? 100 : 0;
			} else {
				pct = Math.max(0, Math.min(100, ((viewportTop - scrollStart) / scrollRange) * 100));
			}
			const rounded = Math.round(pct);
			setScrollPct(rounded);
			handleProgressChange(rounded);

			// Active heading for the outline
			const headings = contentElement.querySelectorAll<HTMLElement>('h2, h3');
			let current = '';
			headings.forEach((h) => {
				if (h.getBoundingClientRect().top <= 120) current = h.id;
			});
			if (current) setActiveHeadingId(current);

			// Mark completed at 85% and advance the queue (remove this article from Up next)
			if (pct >= 85 && article.reading_status === 'reading') {
				(async () => {
					try {
						await updateReadingStatus(article.id, 'completed');
						setArticle((prev) => (prev ? { ...prev, reading_status: 'completed' } : prev));
						if (user) {
							removeFromQueueByArticle(user.id, article.id).catch(() => {});
						}
					} catch (error) {
						console.error('Failed to update reading status to completed:', error);
					}
				})();
			}
		};

		window.addEventListener('scroll', handleScroll, { passive: true });
		handleScroll();
		return () => window.removeEventListener('scroll', handleScroll);
	}, [article?.id, article?.reading_status, handleProgressChange]);

	// Enhance images: lazy loading + gallery click handler
	useEffect(() => {
		const contentElement = articleContentRef.current;
		if (!contentElement) return;

		const images = contentElement.querySelectorAll('img');

		const imageObserver = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting) {
						const img = entry.target as HTMLImageElement;
						img.classList.add('opacity-0', 'transition-opacity', 'duration-300');
						const dataSrc = img.getAttribute('data-src');
						if (dataSrc && !img.src) img.src = dataSrc;
						img.onload = () => {
							img.classList.remove('opacity-0');
							img.classList.add('opacity-100');
						};
						imageObserver.unobserve(img);
					}
				});
			},
			{ rootMargin: '50px' }
		);

		images.forEach((img) => {
			img.setAttribute('loading', 'lazy');
			img.setAttribute('decoding', 'async');
			img.style.cursor = 'pointer';
			imageObserver.observe(img);
		});

		const handleImageClick = (e: MouseEvent) => {
			const target = e.target as HTMLElement;
			if (target.tagName === 'IMG') {
				const clickedImg = target as HTMLImageElement;
				const allImages = Array.from(images).map((img) => img.src);
				const allCaptions = Array.from(images).map((img: HTMLImageElement) => {
					const alt = img.getAttribute('alt');
					const title = img.getAttribute('title');
					const figure = img.closest('figure');
					const figcaption = figure?.querySelector('figcaption')?.textContent;
					return figcaption || title || alt || '';
				});
				const clickedIndex = allImages.indexOf(clickedImg.src);
				if (clickedIndex !== -1 && allImages.length > 0) {
					e.preventDefault();
					e.stopPropagation();
					setImageGallery({ images: allImages, captions: allCaptions, currentIndex: clickedIndex });
				}
			}
		};

		contentElement.addEventListener('click', handleImageClick);
		return () => {
			imageObserver.disconnect();
			contentElement.removeEventListener('click', handleImageClick);
		};
	}, [article?.content]);

	// Intercept clicks on external links inside the article content
	useEffect(() => {
		const contentElement = articleContentRef.current;
		if (!contentElement) return;

		const handleLinkClick = (e: MouseEvent) => {
			const target = e.target as HTMLElement;
			const link = target.closest('a');
			if (!link) return;
			const href = link.getAttribute('href');
			if (!href || href.startsWith('#') || href.startsWith('mailto:') || href.startsWith('tel:')) return;
			e.preventDefault();
			e.stopPropagation();
			setLinkPreviewUrl(href);
		};

		contentElement.addEventListener('click', handleLinkClick);
		return () => contentElement.removeEventListener('click', handleLinkClick);
	}, [article]);

	// Build the "In this article" outline from rendered headings.
	useEffect(() => {
		if (!article?.content) return;
		const contentElement = articleContentRef.current;
		if (!contentElement) return;

		const timeout = setTimeout(() => {
			const headings = Array.from(contentElement.querySelectorAll<HTMLElement>('h2, h3'));
			const entries: OutlineEntry[] = headings.map((h, i) => {
				if (!h.id) h.id = `section-${i}`;
				return { id: h.id, text: h.textContent?.trim() || `Section ${i + 1}`, level: h.tagName === 'H3' ? 3 : 2 };
			});
			setOutline(entries);
		}, 150);

		return () => clearTimeout(timeout);
	}, [article?.content]);

	// Split content into HTML chunks and Video components
	const contentParts = React.useMemo(() => {
		if (!article?.content) return [];

		const content = article.content;
		const iframeSplitRegex = /(<iframe[^>]+src=["']([^"']+)["'][^>]*>(?:<\/iframe>)?)/gi;
		const parts = content.split(iframeSplitRegex);
		const components: React.ReactNode[] = [];

		for (let i = 0; i < parts.length; i++) {
			const part = parts[i];
			if (i % 3 === 0) {
				if (part) {
					components.push(
						<div key={`html-${i}`} dangerouslySetInnerHTML={{ __html: part }} className="html-chunk" />
					);
				}
			} else if (i % 3 === 1) {
				continue;
			} else if (i % 3 === 2) {
				const src = part;
				const videoInfo = extractVideoInfo(src);
				const isSupported = videoInfo.provider !== 'unknown' ||
					src.includes('youtube.com') ||
					src.includes('youtube-nocookie.com') ||
					src.includes('vimeo.com') ||
					src.includes('redditmedia.com');

				if (isSupported) {
					components.push(
						<VideoPlaceholder
							key={`video-${i}`}
							videoInfo={videoInfo}
							onClick={() => {
								setCurrentVideoInfo(videoInfo);
								setVideoSrc(src);
							}}
							colorTheme={preferences.colorTheme}
						/>
					);
				} else {
					const originalTag = parts[i - 1];
					components.push(<div key={`iframe-${i}`} dangerouslySetInnerHTML={{ __html: originalTag }} />);
				}
			}
		}

		return components;
	}, [article?.content, preferences.colorTheme]);

	const handleToggleFavorite = async () => {
		if (!article) return;
		const newStatus = !article.is_favorite;
		setArticle({ ...article, is_favorite: newStatus });
		try {
			await toggleFavorite(article.id, newStatus);
		} catch {
			setArticle({ ...article, is_favorite: !newStatus });
			console.error('Failed to toggle favorite');
		}
	};

	const scrollToHeading = (headingId: string) => {
		const el = document.getElementById(headingId);
		if (el) {
			const top = el.getBoundingClientRect().top + window.scrollY - 90;
			window.scrollTo({ top, behavior: 'smooth' });
		}
	};

	if (authLoading || loading) {
		return (
			<div className="flex min-h-screen items-center justify-center bg-app-page">
				<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
			</div>
		);
	}

	if (error || !article) {
		return (
			<div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-app-page px-4 text-center">
				<h1 className="font-heading text-[34px] text-ink">Oops!</h1>
				<p className="text-[14px] text-app-muted">{error || 'Article not found'}</p>
				<Link
					href="/"
					className="rounded-full bg-accent px-5 py-2.5 font-heading text-[15px] text-app-page transition-colors hover:bg-accent-600"
				>
					Back to Library
				</Link>
			</div>
		);
	}

	// Kicker: domain · date · read time
	const kickerParts: string[] = [];
	if (article.domain) kickerParts.push(article.domain);
	if (article.published_date) {
		kickerParts.push(new Date(article.published_date).toLocaleDateString('en-US', { day: 'numeric', month: 'long', year: 'numeric' }));
	}
	if (article.estimated_read_time) kickerParts.push(`${article.estimated_read_time} min read`);

	const minLeft = article.estimated_read_time
		? Math.max(0, Math.round(article.estimated_read_time * (1 - scrollPct / 100)))
		: null;

	const proseStyle: React.CSSProperties & Record<string, string> = {
		fontSize: `${preferences.fontSize}px`,
		fontFamily: isSerif ? 'Georgia, serif' : 'var(--font-body)',
		'--tw-prose-body': 'var(--app-ink)',
		'--tw-prose-headings': 'var(--app-ink)',
		'--tw-prose-links': 'var(--app-accent)',
		'--tw-prose-bold': 'var(--app-ink)',
		'--tw-prose-quotes': 'var(--app-muted)',
		'--tw-prose-quote-borders': 'var(--app-sage)',
		'--tw-prose-bullets': 'var(--app-muted)',
		'--tw-prose-counters': 'var(--app-muted)',
		'--tw-prose-code': 'var(--app-ink)',
		'--tw-prose-hr': 'var(--app-line)',
		'--tw-prose-captions': 'var(--app-muted)',
	};

	const circleBtn =
		'flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink';

	return (
		<AppShell hideSidebar={focus} documentScroll>
			{/* Top bar (sticky) */}
			<div className="sticky top-0 z-30 bg-app-page">
				{/* Progress */}
				<div className="h-[3px] w-full bg-app-line">
					<div className="h-full bg-accent transition-[width] duration-150" style={{ width: `${scrollPct}%` }} />
				</div>

				<div className="flex items-center gap-3 border-b border-app-line px-7 py-3">
					<Link href="/" className={circleBtn} title="Back to Library">
						<ArrowLeft size={16} strokeWidth={2.75} />
					</Link>

					<div className="min-w-0 flex-1">
						{article.domain && (
							<span className="text-[12.5px] font-bold text-accent">{article.domain}</span>
						)}
						<span className="ml-2 truncate text-[13.5px] text-app-muted">{article.title}</span>
					</div>

					<div className="flex flex-none items-center gap-2">
						<span className="rounded-full bg-accent-200 px-3 py-1.5 text-[12.5px] font-bold text-accent-800">
							{scrollPct}%{minLeft !== null && ` · ${minLeft} min left`}
						</span>

						<button
							type="button"
							onClick={() => setShowReadingSheet(true)}
							title="Reading settings"
							className={`${circleBtn} ${showReadingSheet ? 'bg-ink text-app-page hover:bg-ink hover:text-app-page' : ''}`}
						>
							<Type size={16} strokeWidth={2.75} />
						</button>

						<button
							type="button"
							onClick={() => setShowAISummaryModal(true)}
							title="Summarise"
							className={`${circleBtn} ${article.ai_summary ? 'text-accent' : ''}`}
						>
							<Sparkles size={16} strokeWidth={2.75} />
						</button>

						<button
							type="button"
							onClick={handleToggleFavorite}
							title={article.is_favorite ? 'Remove from favourites' : 'Save'}
							className={`${circleBtn} ${article.is_favorite ? 'text-accent' : ''}`}
						>
							<Bookmark size={16} strokeWidth={2.75} fill={article.is_favorite ? 'currentColor' : 'none'} />
						</button>

						<InternalShareButton articleId={article.id} articleTitle={article.title} />
						<ShareButton articleId={article.id} userId={user!.id} articleUrl={article.url} articleTitle={article.title} />

						<button
							type="button"
							onClick={() => setFocus((v) => !v)}
							title="Focus mode"
							className={`flex items-center gap-1.5 rounded-full border border-app-line px-3 py-1.5 text-[12.5px] font-bold transition-colors ${
								focus ? 'bg-ink text-app-page' : 'text-ink hover:bg-app-hover'
							}`}
						>
							<Eye size={15} strokeWidth={2.75} />
							Focus
						</button>
					</div>
				</div>
			</div>

			{/* Body */}
			<div className={`mx-auto flex gap-9 px-8 py-11 ${focus ? 'max-w-[664px]' : 'max-w-[980px]'}`}>
				<article className="min-w-0 flex-1">
					{/* Kicker */}
					{kickerParts.length > 0 && (
						<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
							{kickerParts.join(' · ')}
						</div>
					)}

					{/* Title */}
					<h1 className="text-pretty mt-3 font-heading text-[44px] leading-[1.06] tracking-[-0.02em] text-ink">
						{article.title}
					</h1>

					{/* Byline */}
					<div className="mt-5 flex items-center justify-between gap-4 border-b border-app-line pb-6">
						<div className="flex items-center gap-2.5">
							<span className="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full bg-sage text-[13px] font-semibold text-app-page">
								{(article.author || article.domain || '?').charAt(0).toUpperCase()}
							</span>
							{(article.author || article.domain) && (
								<span className="text-[14px] font-semibold text-ink">{article.author || article.domain}</span>
							)}
						</div>

						<div className="flex items-center gap-2">
							{article.tags && article.tags.length > 0 && (
								<TagList tags={article.tags} maxVisible={2} size="sm" />
							)}
							<button type="button" onClick={() => setShowTagModal(true)} title="Edit tags" className="text-app-muted transition-colors hover:text-accent">
								<Tag size={17} strokeWidth={2.75} />
							</button>
							<button type="button" onClick={() => setShowDeleteConfirm(true)} title="Delete article" className="text-app-muted transition-colors hover:text-accent">
								<Trash2 size={17} strokeWidth={2.75} />
							</button>
						</div>
					</div>

					{/* Content */}
					<div
						ref={articleContentRef}
						className={`prose ${getFontSizeStyle()} ${getLineHeightClass()} mt-8 max-w-none prose-headings:font-heading prose-a:no-underline hover:prose-a:underline prose-img:rounded-2xl prose-blockquote:border-l-[3px] prose-blockquote:not-italic prose-blockquote:pl-5 prose-blockquote:font-normal`}
						style={proseStyle}
					>
						{contentParts}
					</div>

					{/* Comments */}
					<div className="mt-12 border-t border-app-line pt-8">
						<CommentsSection articleId={article.id} userId={user!.id} initialCommentCount={article.comment_count} />
					</div>
				</article>

				{/* Right rail */}
				{!focus && (
					<aside className="hidden w-[236px] flex-none lg:block">
						<div className="sticky top-24 flex flex-col gap-6">
							{/* In this article */}
							{outline.length > 0 && (
								<div>
									<div className="mb-2 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
										In this article
									</div>
									<nav className="flex flex-col">
										{outline.map((entry) => (
											<button
												key={entry.id}
												type="button"
												onClick={() => scrollToHeading(entry.id)}
												className={`border-l-2 px-3 py-1.5 text-left text-[13.5px] transition-colors ${
													activeHeadingId === entry.id
														? 'border-accent text-ink'
														: 'border-app-line text-app-muted hover:text-ink'
												} ${entry.level === 3 ? 'pl-6' : ''}`}
											>
												{entry.text}
											</button>
										))}
									</nav>
								</div>
							)}

							{/* Summary */}
							<div className="rounded-[22px] border border-app-line bg-app-card p-4">
								<div className="mb-1.5 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
									Summary
								</div>
								<p className="mb-3 text-[13px] leading-[1.5] text-app-muted">
									Generated once and kept with the article.
								</p>
								<button
									type="button"
									onClick={() => setShowAISummaryModal(true)}
									className="flex w-full items-center justify-center gap-1.5 rounded-full bg-accent px-3 py-2 text-[13px] font-semibold text-app-page transition-colors hover:bg-accent-600"
								>
									<Sparkles size={15} strokeWidth={2.75} />
									{article.ai_summary ? 'View summary' : 'Summarise'}
								</button>
							</div>
						</div>
					</aside>
				)}
			</div>

			{/* Reading side sheet */}
			<ReadingSheet isOpen={showReadingSheet} onClose={() => setShowReadingSheet(false)} />

			{/* Link Preview Modal */}
			{linkPreviewUrl && (
				<LinkPreviewModal
					url={linkPreviewUrl}
					onClose={() => setLinkPreviewUrl(null)}
					onArticleSaved={() => console.log('Article saved from link preview')}
				/>
			)}

			{/* Video Modal */}
			{videoSrc && (
				<VideoModal
					isOpen
					onClose={() => {
						setVideoSrc(null);
						setCurrentVideoInfo(null);
					}}
					videoSrc={videoSrc}
					videoTitle={article?.title}
					videoInfo={currentVideoInfo || undefined}
				/>
			)}

			{/* Delete Confirmation Modal */}
			{showDeleteConfirm && (
				<div
					className="fixed inset-0 z-50 grid place-items-center p-4"
					style={{ background: 'rgba(32,30,29,.42)' }}
					onClick={() => setShowDeleteConfirm(false)}
				>
					<div
						className="w-full max-w-[440px] rounded-[28px] border border-app-line bg-app-card p-6 [box-shadow:var(--shadow-modal)]"
						onClick={(e) => e.stopPropagation()}
					>
						<h2 className="font-heading text-[24px] text-ink">Delete article</h2>
						<p className="mt-2 text-[13.5px] text-app-muted">
							Remove &quot;{article?.title}&quot; from your library? This can&apos;t be undone.
						</p>
						<div className="mt-6 flex justify-end gap-2.5">
							<button
								type="button"
								onClick={() => setShowDeleteConfirm(false)}
								disabled={isDeleting}
								className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover disabled:opacity-50"
							>
								Cancel
							</button>
							<button
								type="button"
								onClick={handleDeleteArticle}
								disabled={isDeleting}
								className="rounded-full bg-accent px-4 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600 disabled:opacity-50"
							>
								{isDeleting ? 'Deleting…' : 'Delete'}
							</button>
						</div>
					</div>
				</div>
			)}

			{/* Tag Management Modal */}
			{showTagModal && article && (
				<TagManagementModal
					isOpen={showTagModal}
					onClose={() => setShowTagModal(false)}
					article={article}
					onSave={handleSaveTags}
				/>
			)}

			{/* Image Gallery Modal */}
			{imageGallery && (
				<ImageGalleryModal
					images={imageGallery.images}
					captions={imageGallery.captions}
					initialIndex={imageGallery.currentIndex}
					onClose={() => setImageGallery(null)}
				/>
			)}

			{/* AI Summary Modal */}
			{showAISummaryModal && article && (
				<AISummaryModal
					isOpen={showAISummaryModal}
					onClose={() => setShowAISummaryModal(false)}
					article={article}
					onSummaryUpdated={(updatedArticle) => setArticle(updatedArticle)}
				/>
			)}
		</AppShell>
	);
}
