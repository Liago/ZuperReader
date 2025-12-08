'use client';

import { useEffect, useState, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { getArticleById, deleteArticle, updateArticleTags } from '../../../lib/api';
import { Article } from '../../../lib/supabase';
import { useAuth } from '../../../contexts/AuthContext';
import { useReadingPreferences } from '../../../contexts/ReadingPreferencesContext';
import ReadingPreferencesModal from '../../../components/ReadingPreferencesModal';
import LinkPreviewModal from '../../../components/LinkPreviewModal';
import LikeButton from '../../../components/LikeButton';
import CommentsSection from '../../../components/CommentsSection';
import ShareButton from '../../../components/ShareButton';
import InternalShareButton from '../../../components/InternalShareButton';
import { TagList } from '../../../components/TagBadge';
import TagManagementModal from '../../../components/TagManagementModal';
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
	const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
	const [isDeleting, setIsDeleting] = useState(false);
	const [showTagModal, setShowTagModal] = useState(false);
	const articleContentRef = useRef<HTMLDivElement>(null);

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

	// Helper function to get badge classes based on color theme
	const getBadgeClasses = (color: 'purple' | 'pink' | 'blue' | 'green') => {
		const isDark = preferences.colorTheme === 'dark';
		const isOcean = preferences.colorTheme === 'ocean';
		const isForest = preferences.colorTheme === 'forest';
		const isSunset = preferences.colorTheme === 'sunset';

		if (isDark) {
			const colorMap = {
				purple: 'bg-purple-900/30 text-purple-200 border-purple-700/50',
				pink: 'bg-pink-900/30 text-pink-200 border-pink-700/50',
				blue: 'bg-blue-900/30 text-blue-200 border-blue-700/50',
				green: 'bg-green-900/30 text-green-200 border-green-700/50',
			};
			return colorMap[color];
		}

		if (isOcean) {
			const colorMap = {
				purple: 'bg-sky-100 text-cyan-900 border-sky-300',
				pink: 'bg-sky-100 text-cyan-900 border-sky-300',
				blue: 'bg-sky-100 text-cyan-900 border-sky-300',
				green: 'bg-teal-100 text-teal-900 border-teal-300',
			};
			return colorMap[color];
		}

		if (isForest) {
			const colorMap = {
				purple: 'bg-emerald-100 text-emerald-900 border-emerald-300',
				pink: 'bg-emerald-100 text-emerald-900 border-emerald-300',
				blue: 'bg-emerald-100 text-emerald-900 border-emerald-300',
				green: 'bg-emerald-100 text-emerald-900 border-emerald-300',
			};
			return colorMap[color];
		}

		if (isSunset) {
			const colorMap = {
				purple: 'bg-violet-100 text-violet-900 border-violet-300',
				pink: 'bg-fuchsia-100 text-fuchsia-900 border-fuchsia-300',
				blue: 'bg-violet-100 text-violet-900 border-violet-300',
				green: 'bg-violet-100 text-violet-900 border-violet-300',
			};
			return colorMap[color];
		}

		// Light theme (default)
		const colorMap = {
			purple: 'bg-purple-50 text-purple-900 border-purple-100',
			pink: 'bg-pink-50 text-pink-900 border-pink-100',
			blue: 'bg-blue-50 text-blue-900 border-blue-100',
			green: 'bg-green-50 text-green-900 border-green-100',
		};
		return colorMap[color];
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
			} catch (err) {
				setError('Failed to load article');
			} finally {
				setLoading(false);
			}
		};

		fetchArticle();
	}, [id, user, authLoading, router]);

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

	if (authLoading || loading) {
		return (
			<div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
				<div className="flex flex-col items-center gap-4">
					<div className="w-16 h-16 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
					<div className="space-y-2 text-center">
						<p className="text-purple-600 font-medium text-lg">Loading article...</p>
						<div className="flex gap-1 justify-center">
							<div className="w-2 h-2 bg-purple-600 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
							<div className="w-2 h-2 bg-pink-600 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
							<div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
						</div>
					</div>
				</div>
			</div>
		);
	}

	if (error || !article) {
		return (
			<div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50 p-4">
				<div className="bg-white/80 backdrop-blur-sm p-8 rounded-2xl shadow-xl border border-gray-200 text-center max-w-md w-full">
					<div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-100 mb-4">
						<svg className="w-8 h-8 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
					</div>
					<h1 className="text-2xl font-bold text-gray-900 mb-2">Oops!</h1>
					<p className="text-gray-600 mb-6">{error || 'Article not found'}</p>
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
		<div className="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50 py-4 sm:py-8 px-4 sm:px-6 lg:px-8">
			<div className={`${getContentWidthClass()} mx-auto`}>
				{/* Back Button and Delete Button - Mobile First */}
				<div className="mb-4 sm:mb-6 flex flex-wrap gap-3 justify-between items-center">
					<Link href="/" className="inline-flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-sm text-gray-700 font-medium rounded-xl hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200">
						<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
						</svg>
						<span className="text-sm sm:text-base">Back to Dashboard</span>
					</Link>
					<button
						onClick={() => setShowDeleteConfirm(true)}
						className="inline-flex items-center gap-2 px-4 py-2 bg-red-500/80 backdrop-blur-sm text-white font-medium rounded-xl hover:bg-red-600 hover:shadow-md transition-all duration-200 border border-red-400"
					>
						<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
						</svg>
						<span className="text-sm sm:text-base">Delete Article</span>
					</button>
				</div>

				{/* Article Container */}
				<article className={`${colorTheme.bg}/95 backdrop-blur-sm rounded-2xl shadow-xl overflow-hidden border ${colorTheme.border}`}>
					{/* Header Image con gradient overlay */}
					{article.image_url && (
						<div className="relative w-full h-56 sm:h-72 md:h-96 overflow-hidden">
							<div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent z-10"></div>
							<img
								src={article.image_url}
								alt={article.title}
								className="w-full h-full object-cover transform hover:scale-105 transition-transform duration-700"
							/>
						</div>
					)}

					<div className="p-5 sm:p-8 md:p-12">
						{/* Article Header */}
						<header className="mb-8">
							{/* Titolo con gradient */}
							<h1 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-extrabold mb-6 leading-tight bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent">
								{article.title}
							</h1>

							{/* Meta informazioni */}
							<div className="flex flex-wrap gap-3 sm:gap-4 mb-6">
								{article.author && (
									<div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border ${getBadgeClasses('purple')}`}>
										<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
										</svg>
										<span className="text-sm font-medium">{article.author}</span>
									</div>
								)}
								{article.domain && (
									<div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border ${getBadgeClasses('pink')}`}>
										<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
										</svg>
										<span className="text-sm font-medium">{article.domain}</span>
									</div>
								)}
								{article.published_date && (
									<div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border ${getBadgeClasses('blue')}`}>
										<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
										</svg>
										<span className="text-sm font-medium">{new Date(article.published_date).toLocaleDateString()}</span>
									</div>
								)}
								{article.estimated_read_time && (
									<div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border ${getBadgeClasses('green')}`}>
										<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
										</svg>
										<span className="text-sm font-medium">{article.estimated_read_time} min read</span>
									</div>
								)}
							</div>

							{/* Tags Section */}
							<div className="mb-4 flex flex-wrap items-center gap-2">
								{article.tags && article.tags.length > 0 && (
									<TagList
										tags={article.tags}
										maxVisible={6}
										size="md"
									/>
								)}
								<button
									onClick={() => setShowTagModal(true)}
									className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg border transition-all hover:scale-105 ${
										preferences.colorTheme === 'dark'
											? 'bg-purple-900/30 text-purple-200 border-purple-700/50 hover:bg-purple-900/50'
											: preferences.colorTheme === 'ocean'
												? 'bg-sky-100 text-cyan-900 border-sky-300 hover:bg-sky-200'
												: preferences.colorTheme === 'forest'
													? 'bg-emerald-100 text-emerald-900 border-emerald-300 hover:bg-emerald-200'
													: preferences.colorTheme === 'sunset'
														? 'bg-violet-100 text-violet-900 border-violet-300 hover:bg-violet-200'
														: 'bg-purple-50 text-purple-700 border-purple-200 hover:bg-purple-100'
									}`}
								>
									<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
									</svg>
									<span className="text-sm font-medium">
										{article.tags && article.tags.length > 0 ? 'Manage Tags' : 'Add Tags'}
									</span>
								</button>
							</div>

							{/* Link originale */}
							{article.url && (
								<a
									href={article.url}
									target="_blank"
									rel="noopener noreferrer"
									className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-200"
								>
									<svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
									</svg>
									Read Original Article
								</a>
							)}
						</header>

						{/* Divider */}
						<div className={`h-px bg-gradient-to-r from-transparent to-transparent mb-8 ${
							preferences.colorTheme === 'dark'
								? 'via-gray-600'
								: preferences.colorTheme === 'ocean'
									? 'via-sky-300'
									: preferences.colorTheme === 'forest'
										? 'via-emerald-300'
										: preferences.colorTheme === 'sunset'
											? 'via-violet-300'
											: 'via-gray-300'
						}`}></div>

						{/* Article Content - Ottimizzato per lettura */}
						<div
							ref={articleContentRef}
							className={`prose ${getFontSizeStyle()} prose-slate max-w-none ${getFontFamilyClass()} ${getLineHeightClass()}
								prose-headings:font-bold ${colorTheme.proseHeadings}
								prose-h1:text-3xl prose-h1:mb-6 prose-h1:mt-8
								prose-h2:text-2xl prose-h2:mb-4 prose-h2:mt-6
								prose-h3:text-xl prose-h3:mb-3 prose-h3:mt-4
								${colorTheme.proseParagraphs} prose-p:mb-4
								${colorTheme.proseLinks} prose-a:no-underline hover:prose-a:underline prose-a:cursor-pointer
								${colorTheme.proseStrong} prose-strong:font-bold
								prose-ul:my-4 prose-ol:my-4
								${colorTheme.proseLi} prose-li:my-2
								prose-img:rounded-xl prose-img:shadow-lg prose-img:my-6
								prose-blockquote:border-l-4 ${colorTheme.proseBlockquote} prose-blockquote:py-2 prose-blockquote:px-4 prose-blockquote:rounded-r-lg
								${colorTheme.proseCode} prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded
								prose-pre:bg-gray-900 prose-pre:text-gray-100 prose-pre:rounded-xl prose-pre:shadow-lg`}
							style={{ fontSize: `${preferences.fontSize}px` }}
							dangerouslySetInnerHTML={{ __html: article.content || '' }}
						/>

						{/* Divider before social section */}
						<div className={`h-px bg-gradient-to-r from-transparent to-transparent mt-12 mb-8 ${
							preferences.colorTheme === 'dark'
								? 'via-gray-600'
								: preferences.colorTheme === 'ocean'
									? 'via-sky-300'
									: preferences.colorTheme === 'forest'
										? 'via-emerald-300'
										: preferences.colorTheme === 'sunset'
											? 'via-violet-300'
											: 'via-gray-300'
						}`}></div>

						{/* Social Actions */}
						<div className="mt-8 mb-8">
							<div className="flex flex-wrap gap-4 items-center">
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
						</div>

						{/* Comments Section */}
						<CommentsSection
							articleId={article.id}
							userId={user!.id}
							initialCommentCount={article.comment_count}
						/>
					</div>
				</article>

				{/* Footer con azioni */}
				<div className="mt-6 flex justify-center">
					<Link href="/" className="inline-flex items-center gap-2 px-6 py-3 bg-white/80 backdrop-blur-sm text-gray-700 font-medium rounded-xl hover:bg-white hover:shadow-lg transition-all duration-200 border border-gray-200">
						<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
						</svg>
						Back to All Articles
					</Link>
				</div>
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
			{linkPreviewUrl && (
				<LinkPreviewModal
					url={linkPreviewUrl}
					onClose={() => setLinkPreviewUrl(null)}
					onArticleSaved={() => {
						// Opzionalmente puoi ricaricare la lista degli articoli o mostrare un messaggio
						console.log('Article saved from link preview');
					}}
				/>
			)}

			{/* Delete Confirmation Modal */}
			{showDeleteConfirm && (
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
							Are you sure you want to delete "{article?.title}"? This will permanently remove the article from your library.
						</p>
						<div className="flex gap-3 justify-end">
							<button
								onClick={() => setShowDeleteConfirm(false)}
								disabled={isDeleting}
								className="px-4 py-2 bg-gray-100 text-gray-700 font-medium rounded-xl hover:bg-gray-200 transition-colors disabled:opacity-50"
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
		</div>
	);
}
