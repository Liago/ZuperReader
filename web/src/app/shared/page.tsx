'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useFriends } from '@/contexts/FriendsContext';
import { getSharedWithMe, markShareAsRead, deleteArticleShare } from '@/lib/api';
import { ArticleShare } from '@/lib/supabase';

export default function SharedPage() {
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const { refreshUnreadCount } = useFriends();
	const [shares, setShares] = useState<ArticleShare[]>([]);
	const [loading, setLoading] = useState(true);
	const [deletingId, setDeletingId] = useState<string | null>(null);

	useEffect(() => {
		if (!authLoading && !user) {
			router.push('/login');
		}
	}, [user, authLoading, router]);

	useEffect(() => {
		const loadShares = async () => {
			if (!user) return;
			setLoading(true);
			try {
				const data = await getSharedWithMe(user.id);
				setShares(data);
			} catch (err) {
				console.error('Error loading shared articles:', err);
			} finally {
				setLoading(false);
			}
		};

		loadShares();
	}, [user]);

	const handleMarkAsRead = async (shareId: string) => {
		try {
			await markShareAsRead(shareId);
			setShares(prev => prev.map(s =>
				s.id === shareId ? { ...s, is_read: true } : s
			));
			await refreshUnreadCount();
		} catch (err) {
			console.error('Error marking as read:', err);
		}
	};

	const handleDelete = async (shareId: string) => {
		setDeletingId(shareId);
		try {
			await deleteArticleShare(shareId);
			setShares(prev => prev.filter(s => s.id !== shareId));
			await refreshUnreadCount();
		} catch (err) {
			console.error('Error deleting share:', err);
		} finally {
			setDeletingId(null);
		}
	};

	const formatTimeAgo = (dateString: string) => {
		const date = new Date(dateString);
		const now = new Date();
		const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

		if (diffInSeconds < 60) return 'adesso';
		if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} min fa`;
		if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} ore fa`;
		if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)} giorni fa`;
		return date.toLocaleDateString('it-IT');
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

	const unreadCount = shares.filter(s => !s.is_read).length;

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
							<div>
								<h1 className="text-2xl sm:text-3xl font-bold text-gray-800">Condivisi con me</h1>
								<p className="text-gray-500 text-sm mt-1">
									Articoli che i tuoi amici hanno condiviso con te
								</p>
							</div>
						</div>
						{unreadCount > 0 && (
							<span className="px-3 py-1 bg-purple-100 text-purple-600 rounded-full text-sm font-medium">
								{unreadCount} nuovi
							</span>
						)}
					</div>
				</header>

				{/* Content */}
				<div className="bg-white rounded-2xl shadow-lg overflow-hidden">
					{loading ? (
						<div className="flex items-center justify-center py-16">
							<div className="w-10 h-10 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
						</div>
					) : shares.length === 0 ? (
						<div className="text-center py-16">
							<svg
								className="w-20 h-20 mx-auto mb-4 text-gray-300"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									strokeLinecap="round"
									strokeLinejoin="round"
									strokeWidth={1.5}
									d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
								/>
							</svg>
							<h3 className="text-xl font-medium text-gray-700 mb-2">Nessun articolo condiviso</h3>
							<p className="text-gray-500 max-w-sm mx-auto">
								Quando i tuoi amici condivideranno articoli con te, appariranno qui.
							</p>
							<Link
								href="/friends"
								className="inline-flex items-center gap-2 mt-6 px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors font-medium"
							>
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
								</svg>
								Trova amici
							</Link>
						</div>
					) : (
						<ul className="divide-y divide-gray-100">
							{shares.map((share) => (
								<li
									key={share.id}
									className={`p-6 transition-colors ${
										!share.is_read ? 'bg-purple-50/50' : 'hover:bg-gray-50'
									}`}
								>
									<div className="flex flex-col sm:flex-row gap-4">
										{/* Article Image */}
										{share.article?.image_url && (
											<div className="w-full sm:w-32 h-40 sm:h-24 flex-shrink-0">
												<img
													src={share.article.image_url}
													alt={share.article.title}
													className="w-full h-full object-cover rounded-lg"
												/>
											</div>
										)}

										{/* Content */}
										<div className="flex-1 min-w-0">
											<div className="flex items-start justify-between gap-4">
												<div className="flex-1 min-w-0">
													{/* Sender Info */}
													<div className="flex items-center gap-2 mb-2">
														<div className="w-6 h-6 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center text-white text-xs font-bold">
															{share.sharer?.display_name?.charAt(0).toUpperCase() || '?'}
														</div>
														<span className="text-sm text-gray-600">
															<span className="font-medium">{share.sharer?.display_name || 'Utente'}</span>
															{' '}ha condiviso
														</span>
														<span className="text-xs text-gray-400">
															{formatTimeAgo(share.created_at)}
														</span>
														{!share.is_read && (
															<span className="px-2 py-0.5 bg-purple-100 text-purple-600 text-xs rounded-full font-medium">
																Nuovo
															</span>
														)}
													</div>

													{/* Article Title */}
													<h3 className="font-semibold text-gray-800 mb-1 line-clamp-2">
														{share.article?.title || 'Articolo senza titolo'}
													</h3>

													{/* Article Excerpt */}
													{share.article?.excerpt && (
														<p className="text-sm text-gray-500 line-clamp-2 mb-2">
															{share.article.excerpt}
														</p>
													)}

													{/* Message */}
													{share.message && (
														<div className="bg-gray-100 rounded-lg p-3 mt-2">
															<p className="text-sm text-gray-700 italic">
																"{share.message}"
															</p>
														</div>
													)}

													{/* Domain */}
													{share.article?.domain && (
														<p className="text-xs text-gray-400 mt-2">
															{share.article.domain}
														</p>
													)}
												</div>

												{/* Actions */}
												<div className="flex flex-col gap-2">
													<Link
														href={`/articles/${share.article_id}`}
														onClick={() => !share.is_read && handleMarkAsRead(share.id)}
														className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-sm font-medium whitespace-nowrap"
													>
														Leggi
													</Link>
													<button
														onClick={() => handleDelete(share.id)}
														disabled={deletingId === share.id}
														className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
														title="Rimuovi"
													>
														{deletingId === share.id ? (
															<div className="w-5 h-5 border-2 border-red-200 border-t-red-500 rounded-full animate-spin"></div>
														) : (
															<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
																<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
															</svg>
														)}
													</button>
												</div>
											</div>
										</div>
									</div>
								</li>
							))}
						</ul>
					)}
				</div>
			</div>
		</main>
	);
}
