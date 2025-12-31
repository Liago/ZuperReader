'use client';

import { useState } from 'react';
import { Friend } from '@/lib/supabase';
import { useFriends } from '@/contexts/FriendsContext';

interface FriendsListProps {
	friends: Friend[];
	onSelectFriend?: (friend: Friend) => void;
	selectable?: boolean;
	selectedIds?: string[];
}

export default function FriendsList({ friends, onSelectFriend, selectable = false, selectedIds = [] }: FriendsListProps) {
	const { deleteFriend, loading } = useFriends();
	const [deletingId, setDeletingId] = useState<string | null>(null);
	const [showConfirmDelete, setShowConfirmDelete] = useState<string | null>(null);

	const handleDelete = async (friendshipId: string) => {
		setDeletingId(friendshipId);
		try {
			await deleteFriend(friendshipId);
		} catch (err) {
			console.error('Error removing friend:', err);
		} finally {
			setDeletingId(null);
			setShowConfirmDelete(null);
		}
	};

	const formatDate = (dateString: string) => {
		const date = new Date(dateString);
		return date.toLocaleDateString('it-IT', {
			day: 'numeric',
			month: 'short',
			year: 'numeric'
		});
	};

	if (loading) {
		return (
			<div className="flex items-center justify-center py-12">
				<div className="w-10 h-10 border-4 border-purple-200 dark:border-purple-800 border-t-purple-600 dark:border-t-purple-400 rounded-full animate-spin"></div>
			</div>
		);
	}

	if (friends.length === 0) {
		return (
			<div className="text-center py-12">
				<svg
					className="w-16 h-16 mx-auto mb-4 text-gray-300 dark:text-gray-600"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
				>
					<path
						strokeLinecap="round"
						strokeLinejoin="round"
						strokeWidth={1.5}
						d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
					/>
				</svg>
				<h3 className="text-lg font-medium text-gray-700 dark:text-gray-300 mb-2">Nessun amico</h3>
				<p className="text-gray-500 dark:text-gray-400">Cerca nuovi utenti per aggiungere amici!</p>
			</div>
		);
	}

	return (
		<ul className="divide-y divide-gray-100 dark:divide-slate-700">
			{friends.map((friend) => {
				const isSelected = selectedIds.includes(friend.user.id);

				return (
					<li
						key={friend.friendship_id}
						className={`p-4 transition-colors ${
							selectable
								? 'cursor-pointer hover:bg-purple-50 dark:hover:bg-purple-900/30'
								: 'hover:bg-gray-50 dark:hover:bg-slate-700'
						} ${isSelected ? 'bg-purple-100 dark:bg-purple-900/40' : ''}`}
						onClick={() => selectable && onSelectFriend && onSelectFriend(friend)}
					>
						<div className="flex items-center justify-between">
							<div className="flex items-center gap-4">
								{selectable && (
									<div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
										isSelected
											? 'border-purple-600 bg-purple-600'
											: 'border-gray-300 dark:border-gray-600'
									}`}>
										{isSelected && (
											<svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
												<path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
											</svg>
										)}
									</div>
								)}
								<div className="w-12 h-12 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center text-white font-bold text-lg shadow-md">
									{friend.user.display_name?.charAt(0).toUpperCase() || '?'}
								</div>
								<div>
									<p className="font-semibold text-gray-800 dark:text-gray-100">
										{friend.user.display_name || 'Utente'}
									</p>
									<p className="text-sm text-gray-500 dark:text-gray-400">
										Amici dal {formatDate(friend.created_at)}
									</p>
								</div>
							</div>

							{!selectable && (
								<div className="flex items-center gap-2">
									{showConfirmDelete === friend.friendship_id ? (
										<div className="flex items-center gap-2">
											<span className="text-sm text-gray-600 dark:text-gray-400">Confermi?</span>
											<button
												onClick={(e) => {
													e.stopPropagation();
													handleDelete(friend.friendship_id);
												}}
												disabled={deletingId === friend.friendship_id}
												className="px-3 py-1 bg-red-500 text-white text-sm rounded-lg hover:bg-red-600 transition-colors disabled:opacity-50"
											>
												{deletingId === friend.friendship_id ? 'Rimozione...' : 'Sì'}
											</button>
											<button
												onClick={(e) => {
													e.stopPropagation();
													setShowConfirmDelete(null);
												}}
												className="px-3 py-1 bg-gray-200 dark:bg-slate-600 text-gray-700 dark:text-gray-200 text-sm rounded-lg hover:bg-gray-300 dark:hover:bg-slate-500 transition-colors"
											>
												No
											</button>
										</div>
									) : (
										<button
											onClick={(e) => {
												e.stopPropagation();
												setShowConfirmDelete(friend.friendship_id);
											}}
											className="p-2 text-gray-400 dark:text-gray-500 hover:text-red-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/30 rounded-lg transition-colors"
											title="Rimuovi amico"
										>
											<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
											</svg>
										</button>
									)}
								</div>
							)}
						</div>
					</li>
				);
			})}
		</ul>
	);
}
