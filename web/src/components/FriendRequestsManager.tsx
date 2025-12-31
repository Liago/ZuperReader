'use client';

import { useState } from 'react';
import { Friend } from '@/lib/supabase';
import { useFriends } from '@/contexts/FriendsContext';

interface FriendRequestsManagerProps {
	pendingRequests: Friend[];
	sentRequests: Friend[];
}

export default function FriendRequestsManager({ pendingRequests, sentRequests }: FriendRequestsManagerProps) {
	const { acceptRequest, rejectRequest, deleteFriend } = useFriends();
	const [processingId, setProcessingId] = useState<string | null>(null);
	const [activeTab, setActiveTab] = useState<'received' | 'sent'>('received');

	const handleAccept = async (friendshipId: string) => {
		setProcessingId(friendshipId);
		try {
			await acceptRequest(friendshipId);
		} catch (err) {
			console.error('Error accepting request:', err);
		} finally {
			setProcessingId(null);
		}
	};

	const handleReject = async (friendshipId: string) => {
		setProcessingId(friendshipId);
		try {
			await rejectRequest(friendshipId);
		} catch (err) {
			console.error('Error rejecting request:', err);
		} finally {
			setProcessingId(null);
		}
	};

	const handleCancel = async (friendshipId: string) => {
		setProcessingId(friendshipId);
		try {
			await deleteFriend(friendshipId);
		} catch (err) {
			console.error('Error canceling request:', err);
		} finally {
			setProcessingId(null);
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

	const totalPending = pendingRequests.length + sentRequests.length;

	if (totalPending === 0) {
		return (
			<div className="text-center py-8">
				<svg
					className="w-12 h-12 mx-auto mb-3 text-gray-300 dark:text-gray-600"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
				>
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
				</svg>
				<p className="text-gray-500 dark:text-gray-400">Nessuna richiesta in sospeso</p>
			</div>
		);
	}

	return (
		<div>
			{/* Tabs */}
			<div className="flex border-b border-gray-200 dark:border-slate-700 mb-4">
				<button
					onClick={() => setActiveTab('received')}
					className={`flex-1 py-3 px-4 text-sm font-medium border-b-2 transition-colors ${
						activeTab === 'received'
							? 'border-purple-600 dark:border-purple-400 text-purple-600 dark:text-purple-400'
							: 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
					}`}
				>
					Ricevute
					{pendingRequests.length > 0 && (
						<span className="ml-2 px-2 py-0.5 bg-purple-100 dark:bg-purple-900/50 text-purple-600 dark:text-purple-300 rounded-full text-xs">
							{pendingRequests.length}
						</span>
					)}
				</button>
				<button
					onClick={() => setActiveTab('sent')}
					className={`flex-1 py-3 px-4 text-sm font-medium border-b-2 transition-colors ${
						activeTab === 'sent'
							? 'border-purple-600 dark:border-purple-400 text-purple-600 dark:text-purple-400'
							: 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
					}`}
				>
					Inviate
					{sentRequests.length > 0 && (
						<span className="ml-2 px-2 py-0.5 bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 rounded-full text-xs">
							{sentRequests.length}
						</span>
					)}
				</button>
			</div>

			{/* Received Requests */}
			{activeTab === 'received' && (
				<div>
					{pendingRequests.length === 0 ? (
						<p className="text-center text-gray-500 dark:text-gray-400 py-6">Nessuna richiesta ricevuta</p>
					) : (
						<ul className="space-y-3">
							{pendingRequests.map((request) => (
								<li
									key={request.friendship_id}
									className="p-4 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-xl border border-purple-100 dark:border-purple-800/50"
								>
									<div className="flex items-center justify-between">
										<div className="flex items-center gap-3">
											<div className="w-12 h-12 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center text-white font-bold text-lg">
												{request.user.display_name?.charAt(0).toUpperCase() || '?'}
											</div>
											<div>
												<p className="font-semibold text-gray-800 dark:text-gray-100">
													{request.user.display_name || 'Utente'}
												</p>
												<p className="text-sm text-gray-500 dark:text-gray-400">
													{formatTimeAgo(request.created_at)}
												</p>
											</div>
										</div>
										<div className="flex items-center gap-2">
											<button
												onClick={() => handleAccept(request.friendship_id)}
												disabled={processingId === request.friendship_id}
												className="px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors disabled:opacity-50 text-sm font-medium"
											>
												{processingId === request.friendship_id ? '...' : 'Accetta'}
											</button>
											<button
												onClick={() => handleReject(request.friendship_id)}
												disabled={processingId === request.friendship_id}
												className="px-4 py-2 bg-gray-200 dark:bg-slate-600 text-gray-700 dark:text-gray-200 rounded-lg hover:bg-gray-300 dark:hover:bg-slate-500 transition-colors disabled:opacity-50 text-sm font-medium"
											>
												Rifiuta
											</button>
										</div>
									</div>
								</li>
							))}
						</ul>
					)}
				</div>
			)}

			{/* Sent Requests */}
			{activeTab === 'sent' && (
				<div>
					{sentRequests.length === 0 ? (
						<p className="text-center text-gray-500 dark:text-gray-400 py-6">Nessuna richiesta inviata</p>
					) : (
						<ul className="space-y-3">
							{sentRequests.map((request) => (
								<li
									key={request.friendship_id}
									className="p-4 bg-gray-50 dark:bg-slate-700/50 rounded-xl border border-gray-200 dark:border-slate-600"
								>
									<div className="flex items-center justify-between">
										<div className="flex items-center gap-3">
											<div className="w-12 h-12 bg-gradient-to-br from-gray-300 to-gray-400 dark:from-gray-600 dark:to-gray-700 rounded-full flex items-center justify-center text-white font-bold text-lg">
												{request.user.display_name?.charAt(0).toUpperCase() || '?'}
											</div>
											<div>
												<p className="font-semibold text-gray-800 dark:text-gray-100">
													{request.user.display_name || 'Utente'}
												</p>
												<p className="text-sm text-gray-500 dark:text-gray-400">
													Inviata {formatTimeAgo(request.created_at)}
												</p>
											</div>
										</div>
										<div className="flex items-center gap-3">
											<span className="px-3 py-1 bg-yellow-100 dark:bg-yellow-900/50 text-yellow-700 dark:text-yellow-300 rounded-full text-sm font-medium">
												In attesa
											</span>
											<button
												onClick={() => handleCancel(request.friendship_id)}
												disabled={processingId === request.friendship_id}
												className="p-2 text-gray-400 dark:text-gray-500 hover:text-red-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/30 rounded-lg transition-colors disabled:opacity-50"
												title="Annulla richiesta"
											>
												<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
												</svg>
											</button>
										</div>
									</div>
								</li>
							))}
						</ul>
					)}
				</div>
			)}
		</div>
	);
}
