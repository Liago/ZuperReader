'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { getArticleById } from '../../../lib/api';
import { Article } from '../../../lib/supabase';
import { useAuth } from '../../../contexts/AuthContext';
import Link from 'next/link';

export default function ArticleReaderPage() {
	const params = useParams();
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const [article, setArticle] = useState<Article | null>(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState('');

	const id = params?.id as string;

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
			<div className="max-w-4xl mx-auto">
				{/* Back Button - Mobile First */}
				<div className="mb-4 sm:mb-6">
					<Link href="/" className="inline-flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-sm text-gray-700 font-medium rounded-xl hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200">
						<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
						</svg>
						<span className="text-sm sm:text-base">Back to Dashboard</span>
					</Link>
				</div>

				{/* Article Container */}
				<article className="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl overflow-hidden border border-gray-200">
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
									<div className="flex items-center gap-2 px-3 py-1.5 bg-purple-50 rounded-lg border border-purple-100">
										<svg className="h-4 w-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
										</svg>
										<span className="text-sm font-medium text-purple-900">{article.author}</span>
									</div>
								)}
								{article.domain && (
									<div className="flex items-center gap-2 px-3 py-1.5 bg-pink-50 rounded-lg border border-pink-100">
										<svg className="h-4 w-4 text-pink-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
										</svg>
										<span className="text-sm font-medium text-pink-900">{article.domain}</span>
									</div>
								)}
								{article.published_date && (
									<div className="flex items-center gap-2 px-3 py-1.5 bg-blue-50 rounded-lg border border-blue-100">
										<svg className="h-4 w-4 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
										</svg>
										<span className="text-sm font-medium text-blue-900">{new Date(article.published_date).toLocaleDateString()}</span>
									</div>
								)}
								{article.estimated_read_time && (
									<div className="flex items-center gap-2 px-3 py-1.5 bg-green-50 rounded-lg border border-green-100">
										<svg className="h-4 w-4 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
										</svg>
										<span className="text-sm font-medium text-green-900">{article.estimated_read_time} min read</span>
									</div>
								)}
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
						<div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent mb-8"></div>

						{/* Article Content - Ottimizzato per lettura */}
						<div
							className="prose prose-lg prose-slate max-w-none
								prose-headings:font-bold prose-headings:text-gray-900
								prose-h1:text-3xl prose-h1:mb-6 prose-h1:mt-8
								prose-h2:text-2xl prose-h2:mb-4 prose-h2:mt-6
								prose-h3:text-xl prose-h3:mb-3 prose-h3:mt-4
								prose-p:text-gray-700 prose-p:leading-relaxed prose-p:mb-4
								prose-a:text-purple-600 prose-a:no-underline hover:prose-a:underline
								prose-strong:text-gray-900 prose-strong:font-bold
								prose-ul:my-4 prose-ol:my-4
								prose-li:text-gray-700 prose-li:my-2
								prose-img:rounded-xl prose-img:shadow-lg prose-img:my-6
								prose-blockquote:border-l-4 prose-blockquote:border-purple-500 prose-blockquote:bg-purple-50 prose-blockquote:py-2 prose-blockquote:px-4 prose-blockquote:rounded-r-lg
								prose-code:text-pink-600 prose-code:bg-pink-50 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded
								prose-pre:bg-gray-900 prose-pre:text-gray-100 prose-pre:rounded-xl prose-pre:shadow-lg"
							dangerouslySetInnerHTML={{ __html: article.content || '' }}
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
		</div>
	);
}
