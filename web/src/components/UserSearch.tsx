'use client';

import { useState, useEffect, useCallback } from 'react';
import { UserProfile, Friendship } from '@/lib/supabase';
import { searchUsers, getFriendshipStatus } from '@/lib/api';
import { useFriends } from '@/contexts/FriendsContext';
import { useAuth } from '@/contexts/AuthContext';

interface UserSearchProps {
	onClose?: () => void;
}

interface UserWithStatus extends UserProfile {
	friendshipStatus: Friendship | null;
}

export default function UserSearch({ onClose }: UserSearchProps) {
	const { user } = useAuth();
	const { sendRequest, friends, pendingRequests, sentRequests } = useFriends();
	const [query, setQuery] = useState('');
	const [results, setResults] = useState<UserWithStatus[]>([]);
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [sendingRequest, setSendingRequest] = useState<string | null>(null);

	const search = useCallback(async () => {
		if (!user || query.trim().length < 2) {
			setResults([]);
			return;
		}

		setLoading(true);
		setError(null);

		try {
			const users = await searchUsers(query.trim(), user.id);

			// Get friendship status for each user
			const usersWithStatus = await Promise.all(
				users.map(async (u) => {
					const status = await getFriendshipStatus(user.id, u.id);
					return { ...u, friendshipStatus: status };
				})
			);

			setResults(usersWithStatus);
		} catch (err) {
			setError('Errore nella ricerca');
			console.error('Search error:', err);
		} finally {
			setLoading(false);
		}
	}, [user, query]);

	useEffect(() => {
		const debounce = setTimeout(() => {
			if (query.trim().length >= 2) {
				search();
			} else {
				setResults([]);
			}
		}, 300);

		return () => clearTimeout(debounce);
	}, [query, search]);

	const handleSendRequest = async (addresseeId: string) => {
		setSendingRequest(addresseeId);
		try {
			await sendRequest(addresseeId);
			// Refresh search results
			await search();
		} catch (err: any) {
			setError(err.message || 'Errore nell\'invio della richiesta');
		} finally {
			setSendingRequest(null);
		}
	};

	const getStatusLabel = (userWithStatus: UserWithStatus) => {
		if (!userWithStatus.friendshipStatus) return null;

		const status = userWithStatus.friendshipStatus.status;
		const isRequester = userWithStatus.friendshipStatus.requester_id === user?.id;

		switch (status) {
			case 'accepted':
				return (
					<span className="px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-medium">
						Amici
					</span>
				);
			case 'pending':
				if (isRequester) {
					return (
						<span className="px-3 py-1 bg-yellow-100 text-yellow-700 rounded-full text-sm font-medium">
							Richiesta inviata
						</span>
					);
				} else {
					return (
						<span className="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm font-medium">
							Richiesta ricevuta
						</span>
					);
				}
			case 'rejected':
				return null;
			case 'blocked':
				return (
					<span className="px-3 py-1 bg-red-100 text-red-700 rounded-full text-sm font-medium">
						Bloccato
					</span>
				);
			default:
				return null;
		}
	};

	const canSendRequest = (userWithStatus: UserWithStatus) => {
		if (!userWithStatus.friendshipStatus) return true;
		const status = userWithStatus.friendshipStatus.status;
		return status === 'rejected';
	};

	return (
		<div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
			<div className="p-4 border-b border-gray-100">
				<div className="flex items-center justify-between mb-4">
					<h3 className="text-lg font-semibold text-gray-800">Cerca Utenti</h3>
					{onClose && (
						<button
							onClick={onClose}
							className="p-2 hover:bg-gray-100 rounded-full transition-colors"
						>
							<svg className="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					)}
				</div>
				<div className="relative">
					<input
						type="text"
						value={query}
						onChange={(e) => setQuery(e.target.value)}
						placeholder="Cerca per nome utente..."
						className="w-full px-4 py-3 pl-11 bg-gray-50 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all"
					/>
					<svg
						className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</div>
			</div>

			<div className="max-h-96 overflow-y-auto">
				{loading && (
					<div className="flex items-center justify-center py-8">
						<div className="w-8 h-8 border-3 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
					</div>
				)}

				{error && (
					<div className="p-4 text-center text-red-600">
						{error}
					</div>
				)}

				{!loading && !error && results.length === 0 && query.length >= 2 && (
					<div className="p-8 text-center text-gray-500">
						<svg className="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
						</svg>
						<p>Nessun utente trovato</p>
					</div>
				)}

				{!loading && !error && query.length < 2 && (
					<div className="p-8 text-center text-gray-500">
						<svg className="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
						<p>Inserisci almeno 2 caratteri per cercare</p>
					</div>
				)}

				{!loading && results.length > 0 && (
					<ul className="divide-y divide-gray-100">
						{results.map((userResult) => (
							<li key={userResult.id} className="p-4 hover:bg-gray-50 transition-colors">
								<div className="flex items-center justify-between">
									<div className="flex items-center gap-3">
										<div className="w-12 h-12 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center text-white font-bold text-lg">
											{userResult.display_name?.charAt(0).toUpperCase() || '?'}
										</div>
										<div>
											<p className="font-medium text-gray-800">
												{userResult.display_name || 'Utente'}
											</p>
											{userResult.bio && (
												<p className="text-sm text-gray-500 line-clamp-1">
													{userResult.bio}
												</p>
											)}
										</div>
									</div>
									<div className="flex items-center gap-2">
										{getStatusLabel(userResult)}
										{canSendRequest(userResult) && (
											<button
												onClick={() => handleSendRequest(userResult.id)}
												disabled={sendingRequest === userResult.id}
												className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
											>
												{sendingRequest === userResult.id ? (
													<>
														<div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
														<span>Invio...</span>
													</>
												) : (
													<>
														<svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
															<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
														</svg>
														<span>Aggiungi</span>
													</>
												)}
											</button>
										)}
									</div>
								</div>
							</li>
						))}
					</ul>
				)}
			</div>
		</div>
	);
}
