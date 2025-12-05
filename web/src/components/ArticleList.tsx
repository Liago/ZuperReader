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
		<div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
			{articles.map((article) => (
				<div key={article.id} className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
					{article.image_url && (
						<img src={article.image_url} alt={article.title} className="w-full h-48 object-cover" />
					)}
					<div className="p-4">
						<h3 className="text-lg font-bold mb-2 line-clamp-2 text-gray-900">
							<a href={article.url} target="_blank" rel="noopener noreferrer" className="hover:text-blue-600">
								{article.title}
							</a>
						</h3>
						<p className="text-gray-600 text-sm mb-4 line-clamp-3">{article.excerpt}</p>
						<div className="flex justify-between text-xs text-gray-500">
							<span>{article.domain}</span>
							<span>{article.estimated_read_time ? `${article.estimated_read_time} min read` : ''}</span>
						</div>
					</div>
				</div>
			))}
		</div>
	);
}
