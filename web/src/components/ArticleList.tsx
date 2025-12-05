'use client';

import { useEffect, useState } from 'react';
import { getArticles } from '../lib/api';
import { Article } from '../lib/supabase';

interface ArticleListProps {
	userId: string;
	refreshTrigger: number;
}

export default function ArticleList({ userId, refreshTrigger }: ArticleListProps) {
	const [articles, setArticles] = useState<Article[]>([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState('');
	const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');

	useEffect(() => {
		const fetchArticles = async () => {
			try {
				const data = await getArticles(userId);
				setArticles(data);
			} catch (err) {
				setError('Failed to load articles');
			} finally {
				setLoading(false);
			}
		};

		fetchArticles();
	}, [userId, refreshTrigger]);

	if (loading) return <div className="text-center py-8 text-gray-600">Loading articles...</div>;
	if (error) return <div className="text-center py-8 text-red-500">{error}</div>;
	if (articles.length === 0) return <div className="text-center py-8 text-gray-600">No articles found. Add one above!</div>;

	return (
		<div>
			<div className="flex justify-end mb-4">
				<div className="bg-white rounded-lg shadow p-1 flex">
					<button
						onClick={() => setViewMode('grid')}
						className={`p-2 rounded ${viewMode === 'grid' ? 'bg-blue-100 text-blue-600' : 'text-gray-400 hover:text-gray-600'}`}
						title="Grid View"
					>
						<svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
						</svg>
					</button>
					<button
						onClick={() => setViewMode('list')}
						className={`p-2 rounded ${viewMode === 'list' ? 'bg-blue-100 text-blue-600' : 'text-gray-400 hover:text-gray-600'}`}
						title="List View"
					>
						<svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
						</svg>
					</button>
				</div>
			</div>

			{viewMode === 'grid' ? (
				<div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
					{articles.map((article) => (
						<div key={article.id} className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
							{article.image_url && (
								<a href={`/articles/${article.id}`} className="block">
									<img src={article.image_url} alt={article.title} className="w-full h-48 object-cover hover:opacity-90 transition-opacity" />
								</a>
							)}
							<div className="p-4">
								<h3 className="text-lg font-bold mb-2 line-clamp-2 text-gray-900">
									<a href={`/articles/${article.id}`} className="hover:text-blue-600">
										{article.title}
									</a>
								</h3>
								<p className="text-gray-600 text-sm mb-4 line-clamp-3">{article.excerpt}</p>
								<div className="flex justify-between items-center text-xs text-gray-500">
									<span>{article.domain}</span>
									<span>{article.estimated_read_time ? `${article.estimated_read_time} min read` : ''}</span>
								</div>
								<div className="mt-2 text-right">
									<a href={article.url} target="_blank" rel="noopener noreferrer" className="text-xs text-blue-500 hover:underline">
										Original Link ↗
									</a>
								</div>
							</div>
						</div>
					))}
				</div>
			) : (
				<div className="space-y-4">
					{articles.map((article) => (
						<div key={article.id} className="bg-white rounded-lg shadow-md p-4 flex gap-4 hover:shadow-lg transition-shadow">
							{article.image_url && (
								<a href={`/articles/${article.id}`} className="flex-shrink-0">
									<img src={article.image_url} alt={article.title} className="w-24 h-24 object-cover rounded" />
								</a>
							)}
							<div className="flex-1 min-w-0">
								<h3 className="text-lg font-bold mb-1 text-gray-900 truncate">
									<a href={`/articles/${article.id}`} className="hover:text-blue-600">
										{article.title}
									</a>
								</h3>
								<p className="text-gray-600 text-sm mb-2 line-clamp-2">{article.excerpt}</p>
								<div className="flex justify-between items-center text-xs text-gray-500">
									<div className="flex gap-3">
										<span>{article.domain}</span>
										<span>{article.estimated_read_time ? `${article.estimated_read_time} min read` : ''}</span>
									</div>
									<a href={article.url} target="_blank" rel="noopener noreferrer" className="text-blue-500 hover:underline">
										Original Link ↗
									</a>
								</div>
							</div>
						</div>
					))}
				</div>
			)}
		</div>
	);
}
