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
			<div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
				<div className="flex flex-col items-center gap-4">
					<div className="w-12 h-12 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
					<p className="text-purple-600 font-medium">Loading...</p>
				</div>
			</div>
		);
	}

	if (!user) {
		return null; // Will redirect to login
	}

	return (
		<main className="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50 py-6 px-4 sm:py-12 sm:px-6 lg:px-8">
			<div className="max-w-7xl mx-auto">
				{/* Header con design moderno */}
				<header className="mb-8 sm:mb-12">
					<div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 sm:gap-0">
						<div className="w-full sm:w-auto">
							<h1 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent mb-2">
								SuperReader
							</h1>
							<p className="text-sm sm:text-lg text-gray-600">Save and read your favorite articles</p>
						</div>
						<div className="flex items-center gap-3 sm:gap-4 w-full sm:w-auto justify-between sm:justify-end">
							<span className="text-xs sm:text-sm text-gray-600 truncate max-w-[180px] sm:max-w-none">{user.email}</span>
							<button
								onClick={signOut}
								className="px-4 py-2 text-xs sm:text-sm bg-white/80 backdrop-blur-sm text-gray-700 rounded-lg hover:bg-white hover:shadow-md transition-all duration-200 font-medium border border-gray-200"
							>
								Sign Out
							</button>
						</div>
					</div>
				</header>

				<ArticleForm userId={user.id} onArticleAdded={handleArticleAdded} />
				<ArticleList userId={user.id} refreshTrigger={refreshTrigger} />
			</div>
		</main>
	);
}
