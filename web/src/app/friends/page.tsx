'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useFriends } from '@/contexts/FriendsContext';
import UserSearch from '@/components/UserSearch';
import FriendsList from '@/components/FriendsList';
import FriendRequestsManager from '@/components/FriendRequestsManager';

export default function FriendsPage() {
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const { friends, pendingRequests, sentRequests, loading: friendsLoading } = useFriends();
	const [activeTab, setActiveTab] = useState<'friends' | 'search' | 'requests'>('friends');

	useEffect(() => {
		if (!authLoading && !user) {
			router.push('/login');
		}
	}, [user, authLoading, router]);

	if (authLoading) {
		return (
			<div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
				<div className="flex flex-col items-center gap-4">
					<div className="w-12 h-12 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
					<p className="text-purple-600 font-medium">Caricamento...</p>
				</div>
			</div>
		);
	}

	if (!user) return null;

	const totalRequests = pendingRequests.length;

	return (
		<main className="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50 py-6 px-4 sm:py-12 sm:px-6 lg:px-8">
			<div className="max-w-4xl mx-auto">
				{/* Header */}
				<header className="mb-8">
					<div className="flex items-center gap-4">
						<Link
							href="/"
							className="p-2 hover:bg-white/80 rounded-lg transition-colors"
						>
							<svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
							</svg>
						</Link>
						<div>
							<h1 className="text-2xl sm:text-3xl font-bold text-gray-800">Amici</h1>
							<p className="text-gray-500 text-sm mt-1">
								Gestisci i tuoi amici e cerca nuovi utenti
							</p>
						</div>
					</div>
				</header>

				{/* Tabs */}
				<div className="bg-white rounded-2xl shadow-lg overflow-hidden">
					<div className="flex border-b border-gray-200">
						<button
							onClick={() => setActiveTab('friends')}
							className={`flex-1 py-4 px-6 text-sm font-medium transition-colors ${
								activeTab === 'friends'
									? 'text-purple-600 border-b-2 border-purple-600 bg-purple-50/50'
									: 'text-gray-500 hover:text-gray-700'
							}`}
						>
							<div className="flex items-center justify-center gap-2">
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
								</svg>
								<span>I miei amici</span>
								{friends.length > 0 && (
									<span className="px-2 py-0.5 bg-purple-100 text-purple-600 rounded-full text-xs">
										{friends.length}
									</span>
								)}
							</div>
						</button>
						<button
							onClick={() => setActiveTab('search')}
							className={`flex-1 py-4 px-6 text-sm font-medium transition-colors ${
								activeTab === 'search'
									? 'text-purple-600 border-b-2 border-purple-600 bg-purple-50/50'
									: 'text-gray-500 hover:text-gray-700'
							}`}
						>
							<div className="flex items-center justify-center gap-2">
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
								</svg>
								<span>Cerca utenti</span>
							</div>
						</button>
						<button
							onClick={() => setActiveTab('requests')}
							className={`flex-1 py-4 px-6 text-sm font-medium transition-colors relative ${
								activeTab === 'requests'
									? 'text-purple-600 border-b-2 border-purple-600 bg-purple-50/50'
									: 'text-gray-500 hover:text-gray-700'
							}`}
						>
							<div className="flex items-center justify-center gap-2">
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
								</svg>
								<span>Richieste</span>
								{totalRequests > 0 && (
									<span className="absolute top-2 right-1/4 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
										{totalRequests}
									</span>
								)}
							</div>
						</button>
					</div>

					<div className="p-6">
						{/* Friends List Tab */}
						{activeTab === 'friends' && (
							<div>
								{friendsLoading ? (
									<div className="flex items-center justify-center py-12">
										<div className="w-10 h-10 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
									</div>
								) : (
									<FriendsList friends={friends} />
								)}
							</div>
						)}

						{/* Search Tab */}
						{activeTab === 'search' && (
							<UserSearch />
						)}

						{/* Requests Tab */}
						{activeTab === 'requests' && (
							<FriendRequestsManager
								pendingRequests={pendingRequests}
								sentRequests={sentRequests}
							/>
						)}
					</div>
				</div>
			</div>
		</main>
	);
}
