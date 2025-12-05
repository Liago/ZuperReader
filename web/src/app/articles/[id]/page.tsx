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
			<div className="min-h-screen flex items-center justify-center bg-gray-100">
				<div className="text-gray-600">Loading article...</div>
			</div>
		);
	}

	if (error || !article) {
		return (
			<div className="min-h-screen flex flex-col items-center justify-center bg-gray-100 p-4">
				<div className="bg-white p-8 rounded-lg shadow-md text-center">
					<h1 className="text-2xl font-bold text-red-600 mb-4">Error</h1>
					<p className="text-gray-600 mb-6">{error || 'Article not found'}</p>
					<Link href="/" className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors">
						Back to Dashboard
					</Link>
				</div>
			</div>
		);
	}

	return (
		<div className="min-h-screen bg-gray-50 py-8 px-4 sm:px-6 lg:px-8">
			<div className="max-w-3xl mx-auto bg-white rounded-xl shadow-lg overflow-hidden">
				{/* Header Image */}
				{article.image_url && (
					<div className="w-full h-64 sm:h-96 relative">
						<img
							src={article.image_url}
							alt={article.title}
							className="w-full h-full object-cover"
						/>
					</div>
				)}

				<div className="p-8 sm:p-12">
					{/* Back Button */}
					<Link href="/" className="inline-flex items-center text-sm text-gray-500 hover:text-blue-600 mb-8 transition-colors">
						<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
						</svg>
						Back to Dashboard
					</Link>

					{/* Article Header */}
					<header className="mb-8">
						<h1 className="text-3xl sm:text-4xl font-bold text-gray-900 mb-4 leading-tight">
							{article.title}
						</h1>

						<div className="flex flex-wrap items-center text-sm text-gray-500 gap-4">
							{article.author && (
								<span className="flex items-center">
									<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
									</svg>
									{article.author}
								</span>
							)}
							{article.domain && (
								<span className="flex items-center">
									<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
									</svg>
									{article.domain}
								</span>
							)}
							{article.published_date && (
								<span className="flex items-center">
									<svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
									{new Date(article.published_date).toLocaleDateString()}
								</span>
							)}
							{article.url && (
								<a href={article.url} target="_blank" rel="noopener noreferrer" className="text-blue-500 hover:underline flex items-center">
									Original Link ↗
								</a>
							)}
						</div>
					</header>

					{/* Article Content */}
					<article
						className="prose prose-lg prose-blue max-w-none text-gray-800"
						dangerouslySetInnerHTML={{ __html: article.content || '' }}
					/>
				</div>
			</div>
		</div>
	);
}
