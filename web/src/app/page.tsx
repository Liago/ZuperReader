'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../contexts/AuthContext';
import ArticleForm from '../components/ArticleForm';
import ArticleList from '../components/ArticleList';

export default function Home() {
	const [refreshTrigger, setRefreshTrigger] = useState(0);
	const { user, loading, signOut } = useAuth();
	const router = useRouter();

	useEffect(() => {
		if (!loading && !user) {
			router.push('/login');
		}
	}, [user, loading, router]);

	const handleArticleAdded = () => {
		setRefreshTrigger((prev) => prev + 1);
	};

	if (loading) {
		return (
			<div className="min-h-screen flex items-center justify-center bg-gray-100">
				<div className="text-gray-600">Loading...</div>
			</div>
		);
	}

	if (!user) {
		return null; // Will redirect to login
	}

	return (
		<main className="min-h-screen bg-gray-100 py-12 px-4 sm:px-6 lg:px-8">
			<div className="max-w-7xl mx-auto">
				<header className="mb-12 flex justify-between items-center">
					<div>
						<h1 className="text-4xl font-extrabold text-gray-900 mb-2">SuperReader</h1>
						<p className="text-lg text-gray-600">Save and read your favorite articles</p>
					</div>
					<div className="flex items-center gap-4">
						<span className="text-sm text-gray-600">{user.email}</span>
						<button
							onClick={signOut}
							className="px-4 py-2 text-sm bg-gray-200 text-gray-700 rounded hover:bg-gray-300 transition-colors"
						>
							Sign Out
						</button>
					</div>
				</header>

				<ArticleForm userId={user.id} onArticleAdded={handleArticleAdded} />
				<ArticleList userId={user.id} refreshTrigger={refreshTrigger} />
			</div>
		</main>
	);
}
