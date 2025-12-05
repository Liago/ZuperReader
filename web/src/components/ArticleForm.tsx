'use client';

import { useState } from 'react';
import { parseArticle, saveArticle } from '../lib/api';

interface ArticleFormProps {
	userId: string;
	onArticleAdded: () => void;
}

export default function ArticleForm({ userId, onArticleAdded }: ArticleFormProps) {
	const [url, setUrl] = useState('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState('');

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');

		try {
			// Step 1: Parse the URL using Netlify Function
			const parsedData = await parseArticle(url, userId);

			// Step 2: Save to Supabase
			await saveArticle(parsedData, userId);

			setUrl('');
			onArticleAdded();
		} catch (err: any) {
			setError(err.message || 'Failed to add article. Please try again.');
		} finally {
			setLoading(false);
		}
	};

	return (
		<form onSubmit={handleSubmit} className="mb-8 p-6 bg-white rounded-lg shadow-md">
			<h2 className="text-xl font-bold mb-4 text-gray-800">Add New Article</h2>
			<div className="flex gap-4">
				<input
					type="url"
					value={url}
					onChange={(e) => setUrl(e.target.value)}
					placeholder="Enter article URL"
					required
					className="flex-1 p-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500 text-gray-900"
				/>
				<button
					type="submit"
					disabled={loading}
					className="px-6 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50 transition-colors"
				>
					{loading ? 'Adding...' : 'Add Article'}
				</button>
			</div>
			{error && <p className="mt-2 text-red-500 text-sm">{error}</p>}
		</form>
	);
}
