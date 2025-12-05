'use client';

import { useState } from 'react';
import ArticleForm from '../components/ArticleForm';
import ArticleList from '../components/ArticleList';

export default function Home() {
	const [refreshTrigger, setRefreshTrigger] = useState(0);

	// TODO: Replace with actual user authentication
	// This should come from your auth context/provider
	const userId = 'test-user-id';

	const handleArticleAdded = () => {
		setRefreshTrigger((prev) => prev + 1);
	};

	return (
		<main className="min-h-screen bg-gray-100 py-12 px-4 sm:px-6 lg:px-8">
			<div className="max-w-7xl mx-auto">
				<header className="mb-12 text-center">
					<h1 className="text-4xl font-extrabold text-gray-900 mb-2">SuperReader</h1>
					<p className="text-lg text-gray-600">Save and read your favorite articles</p>
				</header>

				<ArticleForm userId={userId} onArticleAdded={handleArticleAdded} />
				<ArticleList userId={userId} refreshTrigger={refreshTrigger} />
			</div>
		</main>
	);
}
