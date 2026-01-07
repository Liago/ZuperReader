'use client';

import React, { useEffect, useState, useRef, useCallback } from 'react';
import ReactDOM from 'react-dom/client';
import { useParams, useRouter } from 'next/navigation';
import { getArticleById, deleteArticle, updateArticleTags, toggleFavorite, updateReadingStatus, updateReadingProgress } from '../../../lib/api';
import { Article } from '../../../lib/supabase';
import { useAuth } from '../../../contexts/AuthContext';
import { useReadingPreferences } from '../../../contexts/ReadingPreferencesContext';
import ReadingPreferencesModal from '../../../components/ReadingPreferencesModal';
import LinkPreviewModal from '../../../components/LinkPreviewModal';
import VideoModal from '../../../components/VideoModal';
import VideoPlaceholder, { VideoInfo, extractVideoInfo } from '../../../components/VideoPlaceholder';
import LikeButton from '../../../components/LikeButton';
import CommentsSection from '../../../components/CommentsSection';
import ShareButton from '../../../components/ShareButton';
import InternalShareButton from '../../../components/InternalShareButton';
import { TagList } from '../../../components/TagBadge';
import TagManagementModal from '../../../components/TagManagementModal';
import ReadingProgressIndicator from '../../../components/ReadingProgressIndicator';
import ImageGalleryModal from '../../../components/ImageGalleryModal';
import AISummaryModal from '../../../components/AISummaryModal';
import Link from 'next/link';

export default function ArticleReaderPage() {
	const params = useParams();
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const { preferences } = useReadingPreferences();
	const [article, setArticle] = useState<Article | null>(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState('');
	const [showPreferencesModal, setShowPreferencesModal] = useState(false);
	const [linkPreviewUrl, setLinkPreviewUrl] = useState<string | null>(null);
	const [videoSrc, setVideoSrc] = useState<string | null>(null);
	const [currentVideoInfo, setCurrentVideoInfo] = useState<VideoInfo | null>(null);
	const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
	const [isDeleting, setIsDeleting] = useState(false);
	const [showTagModal, setShowTagModal] = useState(false);
	const [showStickyToolbar, setShowStickyToolbar] = useState(false);
	const [hasRestoredPosition, setHasRestoredPosition] = useState(false);
	const [imageGallery, setImageGallery] = useState<{ images: string[]; captions: string[]; currentIndex: number } | null>(null);
	const [showAISummaryModal, setShowAISummaryModal] = useState(false);
	const articleContentRef = useRef<HTMLDivElement>(null);
	const actionBarRef = useRef<HTMLDivElement>(null);
	const saveProgressTimeoutRef = useRef<NodeJS.Timeout | null>(null);

	const id = params?.id as string;

	// Helper functions to map preferences to CSS classes
	const getFontFamilyClass = () => {
		switch (preferences.fontFamily) {
			case 'sans': return 'font-sans';
			case 'serif': return 'font-serif';
			case 'mono': return 'font-mono';
			case 'roboto': return 'font-roboto';
			case 'lato': return 'font-lato';
			case 'openSans': return 'font-open-sans';
			case 'ubuntu': return 'font-ubuntu';
			default: return 'font-serif';
		}
	};

	const getFontSizeStyle = () => {
		// Map font size to appropriate prose class based on size range
		if (preferences.fontSize <= 14) return 'prose-sm';
		if (preferences.fontSize <= 18) return 'prose-base';
		if (preferences.fontSize <= 22) return 'prose-lg';
		return 'prose-xl';
	};

	const getColorThemeClasses = () => {
		switch (preferences.colorTheme) {
			case 'light':
				return {
					bg: 'bg-white',
					text: 'text-gray-900',
					border: 'border-gray-200',
					proseHeadings: 'prose-headings:text-gray-900',
					proseParagraphs: 'prose-p:text-gray-700',
					proseLinks: 'prose-a:text-purple-600',
					proseStrong: 'prose-strong:text-gray-900',
					proseLi: 'prose-li:text-gray-700',
					proseBlockquote: 'prose-blockquote:border-purple-500 prose-blockquote:bg-purple-50',
					proseCode: 'prose-code:text-pink-600 prose-code:bg-pink-50',
				};
			case 'dark':
				return {
					bg: 'bg-slate-800',
					text: 'text-slate-100',
					border: 'border-slate-700',
					proseHeadings: 'prose-headings:text-slate-100',
					proseParagraphs: 'prose-p:text-slate-300',
					proseLinks: 'prose-a:text-blue-400',
					proseStrong: 'prose-strong:text-slate-100',
					proseLi: 'prose-li:text-slate-300',
					proseBlockquote: 'prose-blockquote:border-blue-500 prose-blockquote:bg-slate-700',
					proseCode: 'prose-code:text-blue-300 prose-code:bg-slate-700',
				};
			case 'ocean':
				return {
					bg: 'bg-sky-50',
					text: 'text-cyan-950',
					border: 'border-sky-200',
					proseHeadings: 'prose-headings:text-cyan-900',
					proseParagraphs: 'prose-p:text-cyan-900',
					proseLinks: 'prose-a:text-teal-600',
					proseStrong: 'prose-strong:text-cyan-950',
					proseLi: 'prose-li:text-cyan-900',
					proseBlockquote: 'prose-blockquote:border-teal-500 prose-blockquote:bg-sky-100',
					proseCode: 'prose-code:text-cyan-800 prose-code:bg-sky-100',
				};
			case 'forest':
				return {
					bg: 'bg-emerald-50',
					text: 'text-emerald-950',
					border: 'border-emerald-200',
					proseHeadings: 'prose-headings:text-emerald-900',
					proseParagraphs: 'prose-p:text-emerald-900',
					proseLinks: 'prose-a:text-green-700',
					proseStrong: 'prose-strong:text-emerald-950',
					proseLi: 'prose-li:text-emerald-900',
					proseBlockquote: 'prose-blockquote:border-green-600 prose-blockquote:bg-emerald-100',
					proseCode: 'prose-code:text-emerald-800 prose-code:bg-emerald-100',
				};
			case 'sunset':
				return {
					bg: 'bg-violet-50',
					text: 'text-violet-950',
					border: 'border-violet-200',
					proseHeadings: 'prose-headings:text-violet-900',
					proseParagraphs: 'prose-p:text-violet-900',
					proseLinks: 'prose-a:text-fuchsia-600',
					proseStrong: 'prose-strong:text-violet-950',
					proseLi: 'prose-li:text-violet-900',
					proseBlockquote: 'prose-blockquote:border-fuchsia-500 prose-blockquote:bg-violet-100',
					proseCode: 'prose-code:text-violet-800 prose-code:bg-violet-100',
				};
			default:
				return {
					bg: 'bg-white',
					text: 'text-gray-900',
					border: 'border-gray-200',
					proseHeadings: 'prose-headings:text-gray-900',
					proseParagraphs: 'prose-p:text-gray-700',
					proseLinks: 'prose-a:text-purple-600',
					proseStrong: 'prose-strong:text-gray-900',
					proseLi: 'prose-li:text-gray-700',
					proseBlockquote: 'prose-blockquote:border-purple-500 prose-blockquote:bg-purple-50',
					proseCode: 'prose-code:text-pink-600 prose-code:bg-pink-50',
				};
		}
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

	const getContentWidthClass = () => {
		switch (preferences.contentWidth) {
			case 'narrow': return 'max-w-2xl';
			case 'normal': return 'max-w-4xl';
			case 'wide': return 'max-w-6xl';
			default: return 'max-w-4xl';
		}
	};

	const colorTheme = getColorThemeClasses();

	// Helper function to get UI element colors based on theme
	const getUIThemeClasses = () => {
		const isDark = preferences.colorTheme === 'dark';

		return {
			// Page backgrounds
			pageBg: isDark ? 'bg-slate-900' : 'bg-white',
			// Toolbar/header backgrounds
			toolbarBg: isDark ? 'bg-slate-800/95' : 'bg-white/95',
			toolbarBorder: isDark ? 'border-slate-700' : 'border-gray-200',
			// Card backgrounds
			cardBg: isDark ? 'bg-slate-800' : 'bg-white',
			cardBorder: isDark ? 'border-slate-700' : 'border-gray-200',
			// Text colors
			textPrimary: isDark ? 'text-slate-100' : 'text-gray-900',
			textSecondary: isDark ? 'text-slate-400' : 'text-gray-500',
			textTertiary: isDark ? 'text-slate-500' : 'text-gray-400',
			// Button backgrounds
			buttonBg: isDark ? 'bg-slate-700 hover:bg-slate-600' : 'bg-gray-100 hover:bg-gray-200',
			buttonBorder: isDark ? 'border-slate-600' : 'border-gray-200',
			buttonText: isDark ? 'text-slate-200' : 'text-gray-700',
			// Divider
			divider: isDark ? 'bg-slate-700' : 'bg-gray-200',
			// Dropdown menu
			dropdownBg: isDark ? 'bg-slate-800' : 'bg-white',
			dropdownBorder: isDark ? 'border-slate-700' : 'border-gray-200',
			dropdownHover: isDark ? 'hover:bg-slate-700' : 'hover:bg-gray-50',
			// Modal backgrounds
			modalBg: isDark ? 'bg-slate-800' : 'bg-white',
			modalBackdrop: 'bg-black/50',
			// Loading spinner
			spinnerBg: isDark ? 'border-slate-700' : 'border-purple-200',
			spinnerFg: isDark ? 'border-slate-400' : 'border-purple-600',
		};
	};

	const uiTheme = getUIThemeClasses();

	// Save reading progress with debouncing (save after 2 seconds of no scroll)
	const handleProgressChange = useCallback((progress: number) => {
		if (!article) return;

		// Clear existing timeout
		if (saveProgressTimeoutRef.current) {
			clearTimeout(saveProgressTimeoutRef.current);
		}

		// Set new timeout to save progress after 2 seconds of no change
		saveProgressTimeoutRef.current = setTimeout(async () => {
			try {
				await updateReadingProgress(article.id, progress);
			} catch (error) {
				console.error('Failed to save reading progress:', error);
			}
		}, 2000);
	}, [article?.id]);

	// Restore scroll position based on saved reading progress
	useEffect(() => {
		if (!article || !articleContentRef.current || hasRestoredPosition) return;

		// Only restore if there's saved progress (> 0) and article is not completed
		if (article.reading_progress > 0 && article.reading_status !== 'completed') {
			// Wait for content to be fully rendered
			const restorePosition = () => {
				const contentElement = articleContentRef.current;
				if (!contentElement) return;

				const contentTop = contentElement.offsetTop;
				const contentHeight = contentElement.offsetHeight;
				const windowHeight = window.innerHeight;

				// Calculate scroll position based on saved progress
				const scrollRange = contentHeight - windowHeight;
				const targetScroll = contentTop + (scrollRange * article.reading_progress / 100);

				// Scroll to the saved position
				window.scrollTo({
					top: Math.max(0, targetScroll),
					behavior: 'smooth'
				});

				setHasRestoredPosition(true);
			};

			// Use a small delay to ensure content is rendered
			const timeoutId = setTimeout(restorePosition, 100);
			return () => clearTimeout(timeoutId);
		} else {
			setHasRestoredPosition(true);
		}
	}, [article?.id, article?.reading_progress, article?.reading_status, hasRestoredPosition]);

	// Cleanup timeout on unmount
	useEffect(() => {
		return () => {
			if (saveProgressTimeoutRef.current) {
				clearTimeout(saveProgressTimeoutRef.current);
			}
		};
	}, []);

	// Funzione per eliminare l'articolo
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

	// Funzione per salvare i tag
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
				if (!data) {
					setError('Article not found');
				} else {
					setArticle(data);
				}
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
	}, [article?.id]); // Only run when article.id changes

	// Track scroll to mark article as completed when reaching near the end
	// and handle sticky toolbar visibility
	useEffect(() => {
		if (!article) return;

		const handleScroll = () => {
			const contentElement = articleContentRef.current;
			const actionBar = actionBarRef.current;

			// Handle sticky toolbar visibility
			if (actionBar) {
				const actionBarBottom = actionBar.offsetTop + actionBar.offsetHeight;
				const scrollPosition = window.scrollY;

				// Show sticky toolbar when scrolled past the action bar
				setShowStickyToolbar(scrollPosition > actionBarBottom);
			}

			// Handle reading status
			if (article.reading_status === 'completed' || !contentElement) return;

			// Calculate scroll percentage correctly (aligned with ReadingProgressIndicator)
			const contentTop = contentElement.offsetTop;
			const contentBottom = contentTop + contentElement.offsetHeight;
			const windowHeight = window.innerHeight;
			const viewportTop = window.scrollY;

			const scrollStart = contentTop;
			const scrollEnd = contentBottom - windowHeight;
			const scrollRange = scrollEnd - scrollStart;

			let scrollPercentage = 0;
			if (scrollRange <= 0) {
				// Content is smaller than viewport
				scrollPercentage = viewportTop >= contentTop ? 100 : 0;
			} else {
				const scrollProgress = viewportTop - scrollStart;
				scrollPercentage = Math.max(0, Math.min(100, (scrollProgress / scrollRange) * 100));
			}

			// Mark as completed when user scrolls to 85% of the content
			if (scrollPercentage >= 85 && article.reading_status === 'reading') {
				const markAsCompleted = async () => {
					try {
						await updateReadingStatus(article.id, 'completed');
						setArticle({ ...article, reading_status: 'completed' });
					} catch (error) {
						console.error('Failed to update reading status to completed:', error);
					}
				};
				markAsCompleted();
			}
		};

		window.addEventListener('scroll', handleScroll);
		return () => window.removeEventListener('scroll', handleScroll);
	}, [article?.id, article?.reading_status]);

	// Enhance images in article content with lazy loading and gallery click handler
	useEffect(() => {
		const contentElement = articleContentRef.current;
		if (!contentElement) return;

		const images = contentElement.querySelectorAll('img');

		// Lazy loading observer
		const imageObserver = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting) {
						const img = entry.target as HTMLImageElement;
						// Add loading class
						img.classList.add('opacity-0', 'transition-opacity', 'duration-300');

						// Load the image if it has data-src (lazy loading)
						const dataSrc = img.getAttribute('data-src');
						if (dataSrc && !img.src) {
							img.src = dataSrc;
						}

						// When loaded, fade in
						img.onload = () => {
							img.classList.remove('opacity-0');
							img.classList.add('opacity-100');
						};

						// Stop observing this image
						imageObserver.unobserve(img);
					}
				});
			},
			{
				rootMargin: '50px',
			}
		);

		images.forEach((img) => {
			// Add loading attribute
			img.setAttribute('loading', 'lazy');
			img.setAttribute('decoding', 'async');
			// Add cursor pointer to indicate clickability
			img.style.cursor = 'pointer';
			imageObserver.observe(img);
		});

		// Click handler for opening image gallery
		const handleImageClick = (e: MouseEvent) => {
			const target = e.target as HTMLElement;
			if (target.tagName === 'IMG') {
				const clickedImg = target as HTMLImageElement;
				const allImages = Array.from(images).map(img => img.src);
				const allCaptions = Array.from(images).map((img: HTMLImageElement) => {
					// Try to get caption from alt, title, or figcaption
					const alt = img.getAttribute('alt');
					const title = img.getAttribute('title');

					// Check if image is inside a figure with figcaption
					const figure = img.closest('figure');
					const figcaption = figure?.querySelector('figcaption')?.textContent;

					// Return the first available caption (priority: figcaption > title > alt)
					return figcaption || title || alt || '';
				});
				const clickedIndex = allImages.indexOf(clickedImg.src);

				if (clickedIndex !== -1 && allImages.length > 0) {
					e.preventDefault();
					e.stopPropagation();
					setImageGallery({
						images: allImages,
						captions: allCaptions,
						currentIndex: clickedIndex
					});
				}
			}
		};

		contentElement.addEventListener('click', handleImageClick);

		return () => {
			imageObserver.disconnect();
			contentElement.removeEventListener('click', handleImageClick);
		};
	}, [article?.content]);

	// Intercetta i click sui link all'interno del contenuto dell'articolo
	useEffect(() => {
		const contentElement = articleContentRef.current;
		if (!contentElement) return;

		const handleLinkClick = (e: MouseEvent) => {
			const target = e.target as HTMLElement;

			// Trova il link più vicino (supporta click su elementi nested dentro link)
			const link = target.closest('a');
			if (!link) return;

			// Verifica se è un link esterno (non un anchor nella pagina)
			const href = link.getAttribute('href');
			if (!href || href.startsWith('#') || href.startsWith('mailto:') || href.startsWith('tel:')) {
				return;
			}

			// Previeni la navigazione di default
			e.preventDefault();
			e.stopPropagation();

			// Apri la modale di preview
			setLinkPreviewUrl(href);
		};

		// Aggiungi event listener
		contentElement.addEventListener('click', handleLinkClick);

		// Cleanup
		return () => {
			contentElement.removeEventListener('click', handleLinkClick);
		};
	}, [article]);

	// Process content to replace iframes with placeholder markers
	// This runs during render (and SSR), ensuring the initial HTML has divs instead of iframes
	const processedContent = React.useMemo(() => {
		if (!article?.content) return '';

		let content = article.content;

		// Regex to find iframes and extract src
		// Handles different quote styles and multiline attributes
		const iframeRegex = /<iframe[^>]+src=["']([^"']+)["'][^>]*>(?:<\/iframe>)?/gi;

		return content.replace(iframeRegex, (match, src) => {
			if (!src) return match;

			const videoInfo = extractVideoInfo(src);
			const isSupported = videoInfo.provider !== 'unknown' ||
				src.includes('youtube.com') ||
				src.includes('youtube-nocookie.com') ||
				src.includes('vimeo.com') ||
				src.includes('redditmedia.com');

			if (!isSupported) return match;

			// Replace with a marker div that we can hydrate later
			// encoding src to be safe in attribute
			const safeSrc = src.replace(/"/g, '&quot;');
			const provider = videoInfo.provider || 'unknown';

			return `<div class="video-placeholder-marker" data-video-src="${safeSrc}" data-provider="${provider}" style="width: 100%; min-height: 300px;"></div>`;
		});
	}, [article?.content]);

	// Hydrate the placeholder markers with the React component
	useEffect(() => {
		const contentElement = articleContentRef.current;
		console.log('HydrationDebug: Effect triggered');

		if (!contentElement) {
			console.log('HydrationDebug: No content element ref');
			return;
		}

		// Find our specific markers
		const markers = contentElement.querySelectorAll('.video-placeholder-marker');
		console.log(`HydrationDebug: Found ${markers.length} markers to hydrate`);

		const mountedRoots: Array<ReactDOM.Root> = [];

		markers.forEach((marker, index) => {
			// Skip if already hydrated (though useEffect cleanup should handle this)
			if (marker.hasAttribute('data-hydrated')) {
				console.log(`HydrationDebug: Marker ${index} already hydrated`);
				return;
			}

			const src = marker.getAttribute('data-video-src');
			console.log(`HydrationDebug: Marker ${index} src:`, src);

			if (!src) return;

			// We need videoInfo again for the component
			const videoInfo = extractVideoInfo(src);
			console.log(`HydrationDebug: hydrating marker ${index} for ${videoInfo.provider}`);

			try {
				const root = ReactDOM.createRoot(marker);
				root.render(
					React.createElement(VideoPlaceholder, {
						videoInfo,
						onClick: () => {
							setCurrentVideoInfo(videoInfo);
							setVideoSrc(src);
						},
						colorTheme: preferences.colorTheme,
					})
				);

				mountedRoots.push(root);
				marker.setAttribute('data-hydrated', 'true');
				console.log(`HydrationDebug: hydration successful for ${index}`);
			} catch (err) {
				console.error(`HydrationDebug: Error hydrating marker ${index}:`, err);
			}
		});

		return () => {
			console.log('HydrationDebug: Cleanup hydrating roots');
			mountedRoots.forEach(root => {
				// Use setTimeout to avoid synchronous unmounting conflicts during updates if needed
				setTimeout(() => {
					try {
						root.unmount();
					} catch (e) {
						// ignore
					}
				}, 0);
			});
		};
	}, [processedContent, preferences.colorTheme]);

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

	const handleReadingStatusChange = async (newStatus: 'unread' | 'reading' | 'completed') => {
		if (!article) return;

		const previousStatus = article.reading_status;
		setArticle({ ...article, reading_status: newStatus });

		try {
			await updateReadingStatus(article.id, newStatus);
		} catch (error) {
			console.error('Failed to update reading status:', error);
			setArticle({ ...article, reading_status: previousStatus });
		}
	};

	if (authLoading || loading) {
		const isDark = preferences.colorTheme === 'dark';
		return (
			<div className={`min-h-screen flex items-center justify-center ${isDark ? 'bg-slate-900' : 'bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50'}`}>
				<div className="flex flex-col items-center gap-4">
					<div className={`w-16 h-16 border-4 rounded-full animate-spin ${isDark ? 'border-slate-700 border-t-slate-400' : 'border-purple-200 border-t-purple-600'}`}></div>
					<div className="space-y-2 text-center">
						<p className={`font-medium text-lg ${isDark ? 'text-slate-300' : 'text-purple-600'}`}>Loading article...</p>
						<div className="flex gap-1 justify-center">
							<div className={`w-2 h-2 rounded-full animate-bounce ${isDark ? 'bg-slate-500' : 'bg-purple-600'}`} style={{ animationDelay: '0ms' }}></div>
							<div className={`w-2 h-2 rounded-full animate-bounce ${isDark ? 'bg-slate-400' : 'bg-pink-600'}`} style={{ animationDelay: '150ms' }}></div>
							<div className={`w-2 h-2 rounded-full animate-bounce ${isDark ? 'bg-slate-500' : 'bg-blue-600'}`} style={{ animationDelay: '300ms' }}></div>
						</div>
					</div>
				</div>
			</div>
		);
	}

	if (error || !article) {
		const isDark = preferences.colorTheme === 'dark';
		return (
			<div className={`min-h-screen flex flex-col items-center justify-center p-4 ${isDark ? 'bg-slate-900' : 'bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50'}`}>
				<div className={`p-8 rounded-2xl shadow-xl border text-center max-w-md w-full ${isDark ? 'bg-slate-800/80 border-slate-700' : 'bg-white/80 border-gray-200'} backdrop-blur-sm`}>
					<div className={`inline-flex items-center justify-center w-16 h-16 rounded-full mb-4 ${isDark ? 'bg-red-900/30' : 'bg-red-100'}`}>
						<svg className={`w-8 h-8 ${isDark ? 'text-red-400' : 'text-red-600'}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
					</div>
					<h1 className={`text-2xl font-bold mb-2 ${isDark ? 'text-slate-100' : 'text-gray-900'}`}>Oops!</h1>
					<p className={`mb-6 ${isDark ? 'text-slate-400' : 'text-gray-600'}`}>{error || 'Article not found'}</p>
					<Link href="/" className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-200">
						<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
						</svg>
						Back to Dashboard
					</Link>
				</div>
			</div>
		);
	}

	return (
		<div className={`min-h-screen py-4 sm:py-8 px-4 sm:px-6 lg:px-8 ${uiTheme.pageBg} dark:bg-slate-900`}>
			{/* Reading Progress Indicator */}
			<ReadingProgressIndicator
				contentRef={articleContentRef}
				hidden={showStickyToolbar}
				onProgressChange={handleProgressChange}
			/>

			{/* Sticky Toolbar */}
			<div
				className={`fixed top-0 left-0 right-0 backdrop-blur-md shadow-lg border-b z-40 transition-all duration-300 ${uiTheme.toolbarBg} ${uiTheme.toolbarBorder} ${showStickyToolbar ? 'translate-y-0 opacity-100' : '-translate-y-full opacity-0'
					}`}
			>
				<div className={`${getContentWidthClass()} mx-auto px-4 py-3`}>
					<div className="flex items-center justify-between gap-4">
						{/* Left side - Reading progress indicator and article title */}
						<div className="flex items-center gap-3 flex-1 min-w-0">
							{/* Back Button */}
							<Link
								href="/"
								className={`flex-shrink-0 p-1 rounded-full transition-colors ${uiTheme.textSecondary} ${preferences.colorTheme === 'dark' ? 'hover:bg-slate-700 hover:text-slate-100' : 'hover:bg-gray-100 hover:text-gray-900'}`}
								title="Go back"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
								</svg>
							</Link>

							{/* Reading Progress Indicator - Inline variant */}
							<div className="flex-shrink-0">
								<ReadingProgressIndicator
									contentRef={articleContentRef}
									variant="inline"
									onProgressChange={handleProgressChange}
								/>
							</div>
							{/* Article title (truncated) */}
							<h2 className={`text-sm font-semibold truncate ${uiTheme.textPrimary}`}>
								{article.title}
							</h2>
						</div>

						{/* Right side - Action buttons */}
						<div className="flex items-center gap-2 flex-shrink-0">
							{/* AI Summary button */}
							<button
								onClick={() => setShowAISummaryModal(true)}
								className={`p-2 rounded-full border transition-all ${article.ai_summary
									? 'bg-purple-50 border-purple-500 text-purple-600 hover:border-purple-600 hover:bg-purple-100'
									: preferences.colorTheme === 'dark'
										? 'bg-slate-700 border-slate-600 text-slate-400 hover:border-purple-500 hover:text-purple-400 hover:bg-slate-600'
										: 'bg-white border-gray-200 text-gray-500 hover:border-purple-300 hover:text-purple-600 hover:bg-purple-50'
									}`}
								title="Riassunto AI"
							>
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
								</svg>
							</button>

							{/* Reading Status Dropdown - compact version */}
							<div className="relative group">
								<button
									className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all shadow-sm ${article.reading_status === 'unread'
										? 'bg-blue-100 text-blue-700 hover:bg-blue-200'
										: article.reading_status === 'reading'
											? 'bg-amber-100 text-amber-700 hover:bg-amber-200'
											: 'bg-green-100 text-green-700 hover:bg-green-200'
										}`}
								>
									{article.reading_status === 'reading' && (
										<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
										</svg>
									)}
									<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
									</svg>
								</button>
								{/* Dropdown menu */}
								<div className={`absolute right-0 mt-2 w-40 rounded-xl shadow-lg border opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 ${uiTheme.dropdownBg} ${uiTheme.dropdownBorder}`}>
									<button
										onClick={() => handleReadingStatusChange('unread')}
										className={`w-full text-left px-4 py-2.5 text-sm transition-colors flex items-center gap-2 rounded-t-xl ${article.reading_status === 'unread'
											? 'bg-blue-50 text-blue-700 font-medium'
											: preferences.colorTheme === 'dark'
												? 'text-slate-300 hover:bg-slate-700'
												: 'text-gray-700 hover:bg-blue-50'
											}`}
									>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
										</svg>
										Unread
									</button>
									<button
										onClick={() => handleReadingStatusChange('reading')}
										className={`w-full text-left px-4 py-2.5 text-sm transition-colors flex items-center gap-2 ${article.reading_status === 'reading'
											? 'bg-amber-50 text-amber-700 font-medium'
											: preferences.colorTheme === 'dark'
												? 'text-slate-300 hover:bg-slate-700'
												: 'text-gray-700 hover:bg-amber-50'
											}`}
									>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
										</svg>
										Reading
									</button>
									<button
										onClick={() => handleReadingStatusChange('completed')}
										className={`w-full text-left px-4 py-2.5 text-sm transition-colors flex items-center gap-2 rounded-b-xl ${article.reading_status === 'completed'
											? 'bg-green-50 text-green-700 font-medium'
											: preferences.colorTheme === 'dark'
												? 'text-slate-300 hover:bg-slate-700'
												: 'text-gray-700 hover:bg-green-50'
											}`}
									>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
										</svg>
										Completed
									</button>
								</div>
							</div>

							{/* Favorite button */}
							<button
								onClick={handleToggleFavorite}
								className={`p-2 rounded-full border transition-all ${article.is_favorite
									? 'bg-red-50 border-red-200 text-red-600'
									: preferences.colorTheme === 'dark'
										? 'bg-slate-700 border-slate-600 text-slate-400 hover:border-slate-500 hover:text-slate-300'
										: 'bg-white border-gray-200 text-gray-500 hover:border-gray-300 hover:text-gray-700'
									}`}
								title={article.is_favorite ? "Remove from favorites" : "Add to favorites"}
							>
								<svg className={`w-4 h-4 ${article.is_favorite ? 'fill-current' : 'fill-none'}`} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
									<path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
								</svg>
							</button>

							{/* Like button - compact version */}
							<LikeButton
								articleId={article.id}
								userId={user!.id}
								initialLikeCount={article.like_count}
							/>

							{/* Internal Share button - compact version */}
							<InternalShareButton
								articleId={article.id}
								articleTitle={article.title}
							/>

							{/* Share button */}
							<ShareButton
								articleId={article.id}
								userId={user!.id}
								articleUrl={article.url}
								articleTitle={article.title}
							/>

							{/* Tags button */}
							<button
								onClick={() => setShowTagModal(true)}
								className={`p-2 rounded-full border transition-all ${preferences.colorTheme === 'dark'
									? 'bg-slate-700 border-slate-600 text-slate-400 hover:border-slate-500 hover:text-slate-300'
									: 'bg-white border-gray-200 text-gray-500 hover:border-gray-300 hover:text-gray-700'
									}`}
								title="Manage tags"
							>
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
									<path strokeLinecap="round" strokeLinejoin="round" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
								</svg>
							</button>
						</div>
					</div>
				</div>
			</div>

			<article className={`${getContentWidthClass()} mx-auto`}>
				{/* Navigation Row */}
				<header className="mb-8">
					<div className="flex justify-between items-center mb-6">
						<Link
							href="/"
							className={`inline-flex items-center gap-2 transition-colors font-medium ${uiTheme.textSecondary} ${preferences.colorTheme === 'dark' ? 'hover:text-slate-100' : 'hover:text-gray-900'}`}
						>
							<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
							</svg>
							Back
						</Link>

						<button
							onClick={() => setShowDeleteConfirm(true)}
							className={`transition-colors p-2 rounded-full ${preferences.colorTheme === 'dark'
								? 'text-slate-500 hover:text-red-400 hover:bg-red-900/30'
								: 'text-gray-400 hover:text-red-600 hover:bg-red-50'
								}`}
							title="Delete Article"
						>
							<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
							</svg>
						</button>
					</div>

					{/* Title */}
					<h1 className={`text-3xl sm:text-4xl md:text-5xl font-extrabold mb-6 leading-tight tracking-tight ${uiTheme.textPrimary}`}>
						{article.title}
					</h1>

					{/* Metadata Row - Badge stile moderno */}
					<div className="flex flex-wrap items-center gap-3 mb-8 pb-8 border-b border-gray-100 dark:border-slate-700">
						{article.author && (
							<div className="flex items-center gap-2.5">
								<div className={`w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white font-bold text-sm shadow-md ring-2 ${preferences.colorTheme === 'dark' ? 'ring-slate-800' : 'ring-white'}`}>
									{article.author.charAt(0).toUpperCase()}
								</div>
								<span className={`font-semibold text-base ${uiTheme.textPrimary}`}>{article.author}</span>
							</div>
						)}

						{article.domain && (
							<span className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-50 dark:bg-indigo-900/20 text-indigo-600 dark:text-indigo-400 text-sm font-medium rounded-full border border-indigo-100 dark:border-indigo-800 shadow-sm">
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
								</svg>
								{article.domain}
							</span>
						)}

						{article.estimated_read_time && (
							<span className="inline-flex items-center gap-2 px-4 py-2 bg-pink-50 dark:bg-pink-900/20 text-pink-600 dark:text-pink-400 text-sm font-medium rounded-full border border-pink-100 dark:border-pink-800 shadow-sm">
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
								</svg>
								{article.estimated_read_time} min lettura
							</span>
						)}

						{article.published_date && (
							<span className="inline-flex items-center gap-2 px-4 py-2 bg-gray-50 dark:bg-slate-700/50 text-gray-600 dark:text-slate-400 text-sm font-medium rounded-full border border-gray-100 dark:border-slate-600 shadow-sm">
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
								</svg>
								{new Date(article.published_date).toLocaleDateString()}
							</span>
						)}
					</div>

					{/* Action Bar */}
					<div ref={actionBarRef} className="flex flex-wrap items-center justify-between gap-4 mb-8">
						<div className="flex flex-wrap items-center gap-3">
							{article.url && (
								<a
									href={article.url}
									target="_blank"
									rel="noopener noreferrer"
									className={`inline-flex items-center gap-2 px-5 py-2.5 font-medium rounded-full hover:shadow-lg transition-all active:scale-95 ${preferences.colorTheme === 'dark'
										? 'bg-slate-700 text-slate-100 hover:bg-slate-600'
										: 'bg-gray-900 text-white hover:bg-gray-800'
										}`}
								>
									Read Original
									<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
									</svg>
								</a>
							)}

							<div className={`h-8 w-px mx-2 hidden sm:block ${uiTheme.divider}`}></div>

							{/* Reading Status Dropdown */}
							<div className="relative group">
								<button
									className={`inline-flex items-center gap-2 px-4 py-2.5 rounded-full font-medium transition-all shadow-sm ${article.reading_status === 'unread'
										? 'bg-blue-100 text-blue-700 hover:bg-blue-200'
										: article.reading_status === 'reading'
											? 'bg-amber-100 text-amber-700 hover:bg-amber-200'
											: 'bg-green-100 text-green-700 hover:bg-green-200'
										}`}
								>
									{article.reading_status === 'unread' && (
										<>
											<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
											</svg>
											Unread
										</>
									)}
									{article.reading_status === 'reading' && (
										<>
											<svg className="w-4 h-4 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
											</svg>
											Reading
										</>
									)}
									{article.reading_status === 'completed' && (
										<>
											<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
											</svg>
											Completed
										</>
									)}
									<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
									</svg>
								</button>
								{/* Dropdown menu */}
								<div className={`absolute left-0 mt-2 w-40 rounded-xl shadow-lg border opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-30 ${uiTheme.dropdownBg} ${uiTheme.dropdownBorder}`}>
									<button
										onClick={() => handleReadingStatusChange('unread')}
										className={`w-full text-left px-4 py-2.5 text-sm transition-colors flex items-center gap-2 rounded-t-xl ${article.reading_status === 'unread'
											? 'bg-blue-50 text-blue-700 font-medium'
											: preferences.colorTheme === 'dark'
												? 'text-slate-300 hover:bg-slate-700'
												: 'text-gray-700 hover:bg-blue-50'
											}`}
									>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
										</svg>
										Unread
									</button>
									<button
										onClick={() => handleReadingStatusChange('reading')}
										className={`w-full text-left px-4 py-2.5 text-sm transition-colors flex items-center gap-2 ${article.reading_status === 'reading'
											? 'bg-amber-50 text-amber-700 font-medium'
											: preferences.colorTheme === 'dark'
												? 'text-slate-300 hover:bg-slate-700'
												: 'text-gray-700 hover:bg-amber-50'
											}`}
									>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
										</svg>
										Reading
									</button>
									<button
										onClick={() => handleReadingStatusChange('completed')}
										className={`w-full text-left px-4 py-2.5 text-sm transition-colors flex items-center gap-2 rounded-b-xl ${article.reading_status === 'completed'
											? 'bg-green-50 text-green-700 font-medium'
											: preferences.colorTheme === 'dark'
												? 'text-slate-300 hover:bg-slate-700'
												: 'text-gray-700 hover:bg-green-50'
											}`}
									>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
										</svg>
										Completed
									</button>
								</div>
							</div>

							<div className={`h-8 w-px mx-2 hidden sm:block ${uiTheme.divider}`}></div>

							{/* AI Summary button */}
							<button
								onClick={() => setShowAISummaryModal(true)}
								className={`group p-2.5 rounded-full border transition-all ${article.ai_summary
									? 'bg-purple-50 border-purple-500 text-purple-600 hover:border-purple-600 hover:bg-purple-100'
									: preferences.colorTheme === 'dark'
										? 'bg-slate-700 border-slate-600 text-slate-400 hover:border-purple-500 hover:text-purple-400 hover:bg-slate-600'
										: 'bg-white border-gray-200 text-gray-500 hover:border-purple-300 hover:text-purple-600 hover:bg-purple-50'
									}`}
								title="Riassunto AI"
							>
								<svg className="w-5 h-5 group-hover:scale-110 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
								</svg>
							</button>

							<button
								onClick={handleToggleFavorite}
								className={`group p-2.5 rounded-full border transition-all ${article.is_favorite
									? 'bg-red-50 border-red-200 text-red-600'
									: preferences.colorTheme === 'dark'
										? 'bg-slate-700 border-slate-600 text-slate-400 hover:border-slate-500 hover:text-slate-300'
										: 'bg-white border-gray-200 text-gray-500 hover:border-gray-300 hover:text-gray-700'
									}`}
								title={article.is_favorite ? "Remove from favorites" : "Add to favorites"}
							>
								<svg className={`w-5 h-5 ${article.is_favorite ? 'fill-current' : 'fill-none group-hover:scale-110 transition-transform'}`} viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
								</svg>
							</button>

							<LikeButton
								articleId={article.id}
								userId={user!.id}
								initialLikeCount={article.like_count}
							/>

							<InternalShareButton
								articleId={article.id}
								articleTitle={article.title}
							/>

							<ShareButton
								articleId={article.id}
								userId={user!.id}
								articleUrl={article.url}
								articleTitle={article.title}
							/>
						</div>

						{/* Tags - moved to right side of action bar */}
						<div className="flex items-center gap-2">
							{article.tags && article.tags.length > 0 && (
								<TagList
									tags={article.tags}
									maxVisible={2}
									size="sm"
								/>
							)}
							<button
								onClick={() => setShowTagModal(true)}
								className={`text-xs font-medium transition-colors px-2 py-1 rounded-lg ${preferences.colorTheme === 'dark'
									? 'text-slate-400 hover:text-purple-400 hover:bg-purple-900/30'
									: 'text-gray-500 hover:text-purple-600 hover:bg-purple-50'
									}`}
							>
								{article.tags && article.tags.length > 0 ? 'Edit' : '+ Add Tags'}
							</button>
						</div>
					</div>
				</header>

				{/* Article Content */}
				<div
					ref={articleContentRef}
					className={`${colorTheme.bg} ${colorTheme.text} dark:bg-slate-800 dark:text-slate-100 p-8 rounded-2xl prose ${getFontSizeStyle()} prose-slate max-w-none ${getFontFamilyClass()} ${getLineHeightClass()}
								prose-headings:font-bold ${colorTheme.proseHeadings} dark:prose-headings:text-slate-100
								prose-h1:text-3xl prose-h1:mb-6 prose-h1:mt-8
								prose-h2:text-2xl prose-h2:mb-4 prose-h2:mt-6
								prose-h3:text-xl prose-h3:mb-3 prose-h3:mt-4
								${colorTheme.proseParagraphs} dark:prose-p:text-slate-300 prose-p:mb-4
								${colorTheme.proseLinks} dark:prose-a:text-blue-400 prose-a:no-underline hover:prose-a:underline prose-a:cursor-pointer
								${colorTheme.proseStrong} dark:prose-strong:text-slate-100 prose-strong:font-bold
								prose-ul:my-4 prose-ol:my-4
								${colorTheme.proseLi} dark:prose-li:text-slate-300 prose-li:my-2
								prose-img:rounded-xl prose-img:shadow-lg prose-img:my-6
								prose-blockquote:border-l-4 ${colorTheme.proseBlockquote} dark:prose-blockquote:border-blue-500 dark:prose-blockquote:bg-slate-700 prose-blockquote:py-2 prose-blockquote:px-4 prose-blockquote:rounded-r-lg
								${colorTheme.proseCode} dark:prose-code:text-blue-300 dark:prose-code:bg-slate-700 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded
								${preferences.colorTheme === 'dark' ? 'prose-pre:bg-slate-900 prose-pre:text-slate-100' : 'prose-pre:bg-gray-900 prose-pre:text-gray-100'} dark:prose-pre:bg-slate-900 dark:prose-pre:text-slate-100 prose-pre:rounded-xl prose-pre:shadow-lg`}
					style={{ fontSize: `${preferences.fontSize}px` }}
					dangerouslySetInnerHTML={{ __html: processedContent || '' }}
				/>

				{/* Divider before comments section */}
				<div className={`h-px bg-gradient-to-r from-transparent to-transparent mt-12 mb-8 ${preferences.colorTheme === 'dark'
					? 'via-gray-600'
					: preferences.colorTheme === 'ocean'
						? 'via-sky-300'
						: preferences.colorTheme === 'forest'
							? 'via-emerald-300'
							: preferences.colorTheme === 'sunset'
								? 'via-violet-300'
								: 'via-gray-300'
					}`}></div>

				{/* Comments Section */}
				<CommentsSection
					articleId={article.id}
					userId={user!.id}
					initialCommentCount={article.comment_count}
				/>
			</article>

			{/* Footer con azioni */}
			<div className="mt-6 flex justify-center">
				<Link href="/" className={`inline-flex items-center gap-2 px-6 py-3 font-medium rounded-xl hover:shadow-lg transition-all duration-200 border backdrop-blur-sm ${preferences.colorTheme === 'dark'
					? 'bg-slate-800/80 text-slate-200 border-slate-700 hover:bg-slate-700'
					: 'bg-white/80 text-gray-700 border-gray-200 hover:bg-white'
					}`}>
					<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
					</svg>
					Back to All Articles
				</Link>
			</div>

			{/* Floating Action Button for Reading Preferences */}
			<button
				onClick={() => setShowPreferencesModal(true)}
				className="fixed bottom-8 right-8 p-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-full shadow-2xl hover:shadow-purple-500/50 hover:scale-110 transition-all duration-200 z-30"
				aria-label="Reading Preferences"
				title="Customize Reading Experience"
			>
				<svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
				</svg>
			</button>

			{/* Reading Preferences Modal */}
			<ReadingPreferencesModal
				isOpen={showPreferencesModal}
				onClose={() => setShowPreferencesModal(false)}
			/>

			{/* Link Preview Modal */}
			{
				linkPreviewUrl && (
					<LinkPreviewModal
						url={linkPreviewUrl}
						onClose={() => setLinkPreviewUrl(null)}
						onArticleSaved={() => {
							// Opzionalmente puoi ricaricare la lista degli articoli o mostrare un messaggio
							console.log('Article saved from link preview');
						}}
					/>
				)
			}

			{/* Video Modal */}
			{
				videoSrc && (
					<VideoModal
						isOpen={true}
						onClose={() => {
							setVideoSrc(null);
							setCurrentVideoInfo(null);
						}}
						videoSrc={videoSrc}
						videoTitle={article?.title}
						videoInfo={currentVideoInfo || undefined}
					/>
				)
			}

			{/* Delete Confirmation Modal */}
			{
				showDeleteConfirm && (
					<div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
						<div className={`rounded-2xl shadow-2xl max-w-md w-full p-6 transform transition-all ${uiTheme.modalBg}`}>
							<div className="flex items-center gap-4 mb-4">
								<div className={`flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center ${preferences.colorTheme === 'dark'
									? 'bg-red-900/30'
									: 'bg-red-100'
									}`}>
									<svg className={`w-6 h-6 ${preferences.colorTheme === 'dark' ? 'text-red-400' : 'text-red-600'}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
									</svg>
								</div>
								<div>
									<h3 className={`text-lg font-bold ${uiTheme.textPrimary}`}>Delete Article</h3>
									<p className={`text-sm ${uiTheme.textSecondary}`}>This action cannot be undone</p>
								</div>
							</div>
							<p className={`mb-6 ${uiTheme.textSecondary}`}>
								Are you sure you want to delete &quot;{article?.title}&quot;? This will permanently remove the article from your library.
							</p>
							<div className="flex gap-3 justify-end">
								<button
									onClick={() => setShowDeleteConfirm(false)}
									disabled={isDeleting}
									className={`px-4 py-2 font-medium rounded-xl transition-colors disabled:opacity-50 ${preferences.colorTheme === 'dark'
										? 'bg-slate-700 text-slate-200 hover:bg-slate-600'
										: 'bg-gray-100 text-gray-700 hover:bg-gray-200'
										}`}
								>
									Cancel
								</button>
								<button
									onClick={handleDeleteArticle}
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
				)
			}

			{/* Tag Management Modal */}
			{
				showTagModal && article && (
					<TagManagementModal
						isOpen={showTagModal}
						onClose={() => setShowTagModal(false)}
						article={article}
						onSave={handleSaveTags}
					/>
				)
			}

			{/* Image Gallery Modal */}
			{
				imageGallery && (
					<ImageGalleryModal
						images={imageGallery.images}
						captions={imageGallery.captions}
						initialIndex={imageGallery.currentIndex}
						onClose={() => setImageGallery(null)}
					/>
				)
			}

			{/* AI Summary Modal */}
			{
				showAISummaryModal && article && (
					<AISummaryModal
						isOpen={showAISummaryModal}
						onClose={() => setShowAISummaryModal(false)}
						article={article}
						onSummaryUpdated={(updatedArticle) => setArticle(updatedArticle)}
					/>
				)
			}
		</div >
	);
}
