'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '../contexts/AuthContext';
import { useFriends } from '../contexts/FriendsContext';
import { useArticles } from '../contexts/ArticlesContext';
import ArticleList from '../components/ArticleList';
import AddArticleModal from '../components/AddArticleModal';
import ArticleSummaryModal from '../components/ArticleSummaryModal';
import ThemeSelector from '../components/ThemeSelector';
import AvatarMenu from '../components/AvatarMenu';

export default function Home() {
	const [showAddModal, setShowAddModal] = useState(false);
	const [showSummaryModal, setShowSummaryModal] = useState(false);
	const { user, loading, signOut } = useAuth();
	const { pendingRequests, unreadSharesCount } = useFriends();
	const { refreshArticles } = useArticles();
	const router = useRouter();

	useEffect(() => {
		if (!loading && !user) {
			router.push('/login');
		}
	}, [user, loading, router]);

	const handleArticleAdded = () => {
		if (user) {
			// Refresh with default filters/sort - the ArticleList will rebuild filters
			refreshArticles(user.id);
		}
	};

	if (loading) {
		return (
			<div className="min-h-screen flex items-center justify-center app-bg-gradient">
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
		<main className="min-h-screen app-bg-gradient py-6 px-4 sm:py-12 sm:px-6 lg:px-8">
			<div className="max-w-7xl mx-auto">
				{/* Header con design moderno */}
				<header className="mb-8 sm:mb-12">
					<div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 sm:gap-0">
						<div className="w-full sm:w-auto">
							<h1 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent mb-2">
								SuperReader
							</h1>
							<p className="text-sm sm:text-lg app-text-secondary">Save and read your favorite articles</p>
						</div>
						<div className="flex items-center gap-2 sm:gap-3 w-full sm:w-auto justify-between sm:justify-end flex-wrap">
							{/* Theme Selector */}
							<ThemeSelector />

							{/* Summary Button */}
							<button
								onClick={() => setShowSummaryModal(true)}
								className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-indigo-600 to-purple-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-200"
								title="Riassunto settimanale/mensile"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
								</svg>
								<span className="hidden sm:inline">Riassunto</span>
							</button>

							{/* Add Article Button */}
							<button
								onClick={() => setShowAddModal(true)}
								className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-200"
								title="Add new article"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
								</svg>
								<span className="hidden sm:inline">Add Article</span>
							</button>

							{/* Navigation Icons */}
							<div className="flex items-center gap-1 sm:gap-2">
								{/* Shared Articles */}
								<Link
									href="/shared"
									className="relative p-2 bg-white/80 backdrop-blur-sm text-gray-600 rounded-lg hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200"
									title="Articoli condivisi"
								>
									<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
									</svg>
									{unreadSharesCount > 0 && (
										<span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center font-medium">
											{unreadSharesCount > 9 ? '9+' : unreadSharesCount}
										</span>
									)}
								</Link>

								{/* Friends */}
								<Link
									href="/friends"
									className="relative p-2 bg-white/80 backdrop-blur-sm text-gray-600 rounded-lg hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200"
									title="Amici"
								>
									<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
									</svg>
									{pendingRequests.length > 0 && (
										<span className="absolute -top-1 -right-1 w-5 h-5 bg-purple-500 text-white text-xs rounded-full flex items-center justify-center font-medium">
											{pendingRequests.length > 9 ? '9+' : pendingRequests.length}
										</span>
									)}
								</Link>

								{/* Profile */}
								<Link
									href="/profile"
									className="p-2 bg-white/80 backdrop-blur-sm text-gray-600 rounded-lg hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200"
									title="Profilo"
								>
									<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
									</svg>
								</Link>
							</div>

							<AvatarMenu userEmail={user.email} onSignOut={signOut} />
						</div>
					</div>
				</header>

				<ArticleList userId={user.id} />
			</div>

			{/* Add Article Modal */}
			<AddArticleModal
				isOpen={showAddModal}
				onClose={() => setShowAddModal(false)}
				userId={user.id}
				onArticleAdded={handleArticleAdded}
			/>

			{/* Article Summary Modal */}
			<ArticleSummaryModal
				isOpen={showSummaryModal}
				onClose={() => setShowSummaryModal(false)}
				userId={user.id}
			/>
		</main>
	);
}
