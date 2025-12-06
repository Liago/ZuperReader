'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useFriends } from '@/contexts/FriendsContext';
import { getUserStatistics, updateUserProfile } from '@/lib/api';
import FriendRequestsManager from '@/components/FriendRequestsManager';

interface Statistics {
	totalArticles: number;
	readArticles: number;
	favoriteArticles: number;
	totalLikesReceived: number;
	totalCommentsReceived: number;
	friendsCount: number;
	sharedArticlesCount: number;
	receivedArticlesCount: number;
}

export default function ProfilePage() {
	const router = useRouter();
	const { user, loading: authLoading, signOut } = useAuth();
	const { userProfile, pendingRequests, sentRequests, refreshFriends, refreshPendingRequests } = useFriends();
	const [statistics, setStatistics] = useState<Statistics | null>(null);
	const [loadingStats, setLoadingStats] = useState(true);
	const [activeTab, setActiveTab] = useState<'stats' | 'requests' | 'settings'>('stats');

	// Edit profile state
	const [isEditing, setIsEditing] = useState(false);
	const [displayName, setDisplayName] = useState('');
	const [bio, setBio] = useState('');
	const [saving, setSaving] = useState(false);

	useEffect(() => {
		if (!authLoading && !user) {
			router.push('/login');
		}
	}, [user, authLoading, router]);

	useEffect(() => {
		if (userProfile) {
			setDisplayName(userProfile.display_name || '');
			setBio(userProfile.bio || '');
		}
	}, [userProfile]);

	useEffect(() => {
		const loadStatistics = async () => {
			if (!user) return;
			setLoadingStats(true);
			try {
				const stats = await getUserStatistics(user.id);
				setStatistics(stats);
			} catch (err) {
				console.error('Error loading statistics:', err);
			} finally {
				setLoadingStats(false);
			}
		};

		loadStatistics();
	}, [user]);

	const handleSaveProfile = async () => {
		if (!user) return;
		setSaving(true);
		try {
			await updateUserProfile(user.id, {
				display_name: displayName,
				bio: bio
			});
			setIsEditing(false);
			// Refresh the context
			await refreshFriends();
		} catch (err) {
			console.error('Error saving profile:', err);
		} finally {
			setSaving(false);
		}
	};

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

	const totalRequests = pendingRequests.length + sentRequests.length;

	return (
		<main className="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50 py-6 px-4 sm:py-12 sm:px-6 lg:px-8">
			<div className="max-w-4xl mx-auto">
				{/* Header */}
				<header className="mb-8">
					<div className="flex items-center justify-between">
						<div className="flex items-center gap-4">
							<Link
								href="/"
								className="p-2 hover:bg-white/80 rounded-lg transition-colors"
							>
								<svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
								</svg>
							</Link>
							<h1 className="text-2xl sm:text-3xl font-bold text-gray-800">Il mio profilo</h1>
						</div>
						<button
							onClick={signOut}
							className="px-4 py-2 text-sm bg-white/80 backdrop-blur-sm text-gray-700 rounded-lg hover:bg-white hover:shadow-md transition-all font-medium border border-gray-200"
						>
							Esci
						</button>
					</div>
				</header>

				{/* Profile Card */}
				<div className="bg-white rounded-2xl shadow-lg overflow-hidden mb-6">
					<div className="bg-gradient-to-r from-purple-500 to-pink-500 h-24 sm:h-32"></div>
					<div className="px-6 pb-6">
						<div className="flex flex-col sm:flex-row sm:items-end gap-4 -mt-12 sm:-mt-16">
							<div className="w-24 h-24 sm:w-32 sm:h-32 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center text-white text-3xl sm:text-4xl font-bold border-4 border-white shadow-lg">
								{userProfile?.display_name?.charAt(0).toUpperCase() || user.email?.charAt(0).toUpperCase() || '?'}
							</div>
							<div className="flex-1 sm:pb-2">
								{isEditing ? (
									<div className="space-y-3">
										<input
											type="text"
											value={displayName}
											onChange={(e) => setDisplayName(e.target.value)}
											placeholder="Nome visualizzato"
											className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
										/>
										<textarea
											value={bio}
											onChange={(e) => setBio(e.target.value)}
											placeholder="Bio (opzionale)"
											rows={2}
											className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none"
										/>
										<div className="flex gap-2">
											<button
												onClick={handleSaveProfile}
												disabled={saving}
												className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 text-sm font-medium"
											>
												{saving ? 'Salvataggio...' : 'Salva'}
											</button>
											<button
												onClick={() => {
													setIsEditing(false);
													setDisplayName(userProfile?.display_name || '');
													setBio(userProfile?.bio || '');
												}}
												className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium"
											>
												Annulla
											</button>
										</div>
									</div>
								) : (
									<>
										<div className="flex items-center gap-3">
											<h2 className="text-xl sm:text-2xl font-bold text-gray-800">
												{userProfile?.display_name || user.email?.split('@')[0] || 'Utente'}
											</h2>
											<button
												onClick={() => setIsEditing(true)}
												className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors"
											>
												<svg className="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
												</svg>
											</button>
										</div>
										<p className="text-gray-500 text-sm mt-1">{user.email}</p>
										{userProfile?.bio && (
											<p className="text-gray-600 mt-2">{userProfile.bio}</p>
										)}
									</>
								)}
							</div>
						</div>
					</div>
				</div>

				{/* Tabs */}
				<div className="bg-white rounded-2xl shadow-lg overflow-hidden">
					<div className="flex border-b border-gray-200">
						<button
							onClick={() => setActiveTab('stats')}
							className={`flex-1 py-4 px-6 text-sm font-medium transition-colors ${
								activeTab === 'stats'
									? 'text-purple-600 border-b-2 border-purple-600 bg-purple-50/50'
									: 'text-gray-500 hover:text-gray-700'
							}`}
						>
							<div className="flex items-center justify-center gap-2">
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
								</svg>
								<span>Statistiche</span>
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
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
								</svg>
								<span>Richieste</span>
								{totalRequests > 0 && (
									<span className="absolute top-2 right-1/4 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
										{totalRequests}
									</span>
								)}
							</div>
						</button>
						<button
							onClick={() => setActiveTab('settings')}
							className={`flex-1 py-4 px-6 text-sm font-medium transition-colors ${
								activeTab === 'settings'
									? 'text-purple-600 border-b-2 border-purple-600 bg-purple-50/50'
									: 'text-gray-500 hover:text-gray-700'
							}`}
						>
							<div className="flex items-center justify-center gap-2">
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
								</svg>
								<span>Impostazioni</span>
							</div>
						</button>
					</div>

					<div className="p-6">
						{/* Statistics Tab */}
						{activeTab === 'stats' && (
							<div>
								{loadingStats ? (
									<div className="flex items-center justify-center py-12">
										<div className="w-10 h-10 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
									</div>
								) : statistics ? (
									<div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
												</svg>
											}
											label="Articoli salvati"
											value={statistics.totalArticles}
											color="purple"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
												</svg>
											}
											label="Articoli letti"
											value={statistics.readArticles}
											color="green"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
												</svg>
											}
											label="Preferiti"
											value={statistics.favoriteArticles}
											color="yellow"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
												</svg>
											}
											label="Like ricevuti"
											value={statistics.totalLikesReceived}
											color="red"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
												</svg>
											}
											label="Commenti ricevuti"
											value={statistics.totalCommentsReceived}
											color="blue"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
												</svg>
											}
											label="Amici"
											value={statistics.friendsCount}
											color="pink"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
												</svg>
											}
											label="Articoli condivisi"
											value={statistics.sharedArticlesCount}
											color="indigo"
										/>
										<StatCard
											icon={
												<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
												</svg>
											}
											label="Articoli ricevuti"
											value={statistics.receivedArticlesCount}
											color="teal"
										/>
									</div>
								) : (
									<p className="text-center text-gray-500 py-8">
										Impossibile caricare le statistiche
									</p>
								)}
							</div>
						)}

						{/* Requests Tab */}
						{activeTab === 'requests' && (
							<FriendRequestsManager
								pendingRequests={pendingRequests}
								sentRequests={sentRequests}
							/>
						)}

						{/* Settings Tab */}
						{activeTab === 'settings' && (
							<div className="space-y-6">
								<div className="bg-gray-50 rounded-xl p-4">
									<h3 className="font-semibold text-gray-800 mb-2">Account</h3>
									<p className="text-sm text-gray-600 mb-4">
										Email: <span className="font-medium">{user.email}</span>
									</p>
									<p className="text-sm text-gray-500">
										Membro dal {new Date(user.created_at || '').toLocaleDateString('it-IT', {
											day: 'numeric',
											month: 'long',
											year: 'numeric'
										})}
									</p>
								</div>

								<div className="bg-gray-50 rounded-xl p-4">
									<h3 className="font-semibold text-gray-800 mb-2">Link rapidi</h3>
									<div className="space-y-2">
										<Link
											href="/friends"
											className="flex items-center gap-3 p-3 bg-white rounded-lg hover:bg-purple-50 transition-colors"
										>
											<svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
											</svg>
											<span className="text-gray-700">Gestisci amici</span>
										</Link>
										<Link
											href="/shared"
											className="flex items-center gap-3 p-3 bg-white rounded-lg hover:bg-purple-50 transition-colors"
										>
											<svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
											</svg>
											<span className="text-gray-700">Articoli condivisi con me</span>
										</Link>
									</div>
								</div>

								<div className="bg-red-50 rounded-xl p-4">
									<h3 className="font-semibold text-red-700 mb-2">Zona pericolosa</h3>
									<p className="text-sm text-red-600 mb-4">
										Queste azioni sono irreversibili.
									</p>
									<button
										onClick={signOut}
										className="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors text-sm font-medium"
									>
										Disconnetti
									</button>
								</div>
							</div>
						)}
					</div>
				</div>
			</div>
		</main>
	);
}

interface StatCardProps {
	icon: React.ReactNode;
	label: string;
	value: number;
	color: string;
}

function StatCard({ icon, label, value, color }: StatCardProps) {
	const colorClasses: Record<string, string> = {
		purple: 'bg-purple-100 text-purple-600',
		green: 'bg-green-100 text-green-600',
		yellow: 'bg-yellow-100 text-yellow-600',
		red: 'bg-red-100 text-red-600',
		blue: 'bg-blue-100 text-blue-600',
		pink: 'bg-pink-100 text-pink-600',
		indigo: 'bg-indigo-100 text-indigo-600',
		teal: 'bg-teal-100 text-teal-600',
	};

	return (
		<div className="bg-gray-50 rounded-xl p-4">
			<div className={`w-12 h-12 ${colorClasses[color]} rounded-lg flex items-center justify-center mb-3`}>
				{icon}
			</div>
			<p className="text-2xl font-bold text-gray-800">{value}</p>
			<p className="text-sm text-gray-500">{label}</p>
		</div>
	);
}
