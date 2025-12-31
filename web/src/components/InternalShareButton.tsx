'use client';

import { useState } from 'react';
// import { Friend } from '@/lib/supabase';
import { shareArticleWithFriend } from '@/lib/api';
import { useFriends } from '@/contexts/FriendsContext';
import { useAuth } from '@/contexts/AuthContext';
import { useReadingPreferences } from '@/contexts/ReadingPreferencesContext';

interface InternalShareButtonProps {
	articleId: string;
	articleTitle: string;
}

export default function InternalShareButton({ articleId, articleTitle }: InternalShareButtonProps) {
	const { user } = useAuth();
	const { friends } = useFriends();
	const { preferences } = useReadingPreferences();
	const [showModal, setShowModal] = useState(false);
	const [selectedFriends, setSelectedFriends] = useState<string[]>([]);
	const [message, setMessage] = useState('');
	const [sharing, setSharing] = useState(false);
	const [success, setSuccess] = useState(false);
	const [error, setError] = useState<string | null>(null);

	const toggleFriend = (friendId: string) => {
		setSelectedFriends(prev =>
			prev.includes(friendId)
				? prev.filter(id => id !== friendId)
				: [...prev, friendId]
		);
	};

	const handleShare = async () => {
		if (!user || selectedFriends.length === 0) return;

		setSharing(true);
		setError(null);

		try {
			// Share with all selected friends
			await Promise.all(
				selectedFriends.map(friendId =>
					shareArticleWithFriend(articleId, user.id, friendId, message || undefined)
				)
			);
			setSuccess(true);
			setTimeout(() => {
				setShowModal(false);
				setSuccess(false);
				setSelectedFriends([]);
				setMessage('');
			}, 1500);
		} catch (err) {
			setError(err instanceof Error ? err.message : 'Errore durante la condivisione');
		} finally {
			setSharing(false);
		}
	};

	const handleClose = () => {
		setShowModal(false);
		setSelectedFriends([]);
		setMessage('');
		setError(null);
		setSuccess(false);
	};

	// Don't show the button if user has no friends
	if (friends.length === 0) {
		return null;
	}

	return (
		<>
			<button
				onClick={() => setShowModal(true)}
				className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-full hover:from-purple-600 hover:to-pink-600 transition-all shadow-md hover:shadow-lg"
				title="Condividi con amici"
			>
				<svg
					className="w-5 h-5"
					fill="none"
					stroke="currentColor"
					strokeWidth="2"
					viewBox="0 0 24 24"
				>
					<path
						strokeLinecap="round"
						strokeLinejoin="round"
						d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
					/>
				</svg>
				<span className="font-medium">Condividi</span>
			</button>

			{/* Modal */}
			{showModal && (
				<div className="fixed inset-0 z-50 flex items-center justify-center p-4">
					{/* Backdrop */}
					<div
						className="absolute inset-0 bg-black/50 backdrop-blur-sm"
						onClick={handleClose}
					/>

					{/* Modal Content */}
					<div className={`relative rounded-2xl shadow-2xl max-w-md w-full max-h-[80vh] overflow-hidden ${
						preferences.colorTheme === 'dark' ? 'bg-slate-800' : 'bg-white'
					}`}>
						{/* Header */}
						<div className={`p-6 border-b ${
							preferences.colorTheme === 'dark' ? 'border-slate-700' : 'border-gray-100'
						}`}>
							<div className="flex items-center justify-between">
								<h3 className={`text-xl font-bold ${
									preferences.colorTheme === 'dark' ? 'text-slate-100' : 'text-gray-800'
								}`}>
									Condividi con amici
								</h3>
								<button
									onClick={handleClose}
									className={`p-2 rounded-full transition-colors ${
										preferences.colorTheme === 'dark'
											? 'hover:bg-slate-700'
											: 'hover:bg-gray-100'
									}`}
								>
									<svg className={`w-5 h-5 ${
										preferences.colorTheme === 'dark' ? 'text-slate-400' : 'text-gray-500'
									}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							</div>
							<p className={`text-sm mt-1 line-clamp-1 ${
								preferences.colorTheme === 'dark' ? 'text-slate-400' : 'text-gray-500'
							}`}>
								{articleTitle}
							</p>
						</div>

						{/* Success State */}
						{success ? (
							<div className="p-8 text-center">
								<div className="w-16 h-16 mx-auto mb-4 bg-green-100 rounded-full flex items-center justify-center">
									<svg className="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
									</svg>
								</div>
								<h4 className={`text-lg font-semibold ${
									preferences.colorTheme === 'dark' ? 'text-slate-100' : 'text-gray-800'
								}`}>Condivisione completata!</h4>
								<p className={`mt-1 ${
									preferences.colorTheme === 'dark' ? 'text-slate-400' : 'text-gray-500'
								}`}>L&apos;articolo è stato condiviso con i tuoi amici.</p>
							</div>
						) : (
							<>
								{/* Friends List */}
								<div className="max-h-64 overflow-y-auto p-4">
									{friends.length === 0 ? (
										<p className={`text-center py-4 ${
											preferences.colorTheme === 'dark' ? 'text-slate-400' : 'text-gray-500'
										}`}>
											Non hai ancora amici. Aggiungine alcuni per condividere!
										</p>
									) : (
										<ul className="space-y-2">
											{friends.map((friend) => {
												const isSelected = selectedFriends.includes(friend.user.id);
												return (
													<li
														key={friend.friendship_id}
														onClick={() => toggleFriend(friend.user.id)}
														className={`p-3 rounded-xl cursor-pointer transition-all ${
															isSelected
																? 'bg-purple-100 border-2 border-purple-400'
																: preferences.colorTheme === 'dark'
																	? 'bg-slate-700 border-2 border-transparent hover:bg-slate-600'
																	: 'bg-gray-50 border-2 border-transparent hover:bg-gray-100'
															}`}
													>
														<div className="flex items-center gap-3">
															<div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
																isSelected
																	? 'border-purple-600 bg-purple-600'
																	: preferences.colorTheme === 'dark'
																		? 'border-slate-500'
																		: 'border-gray-300'
																}`}>
																{isSelected && (
																	<svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
																		<path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
																	</svg>
																)}
															</div>
															<div className="w-10 h-10 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center text-white font-bold">
																{friend.user.display_name?.charAt(0).toUpperCase() || '?'}
															</div>
															<span className={`font-medium ${
																preferences.colorTheme === 'dark' ? 'text-slate-200' : 'text-gray-800'
															}`}>
																{friend.user.display_name || 'Utente'}
															</span>
														</div>
													</li>
												);
											})}
										</ul>
									)}
								</div>

								{/* Message Input */}
								<div className="px-4 pb-4">
									<textarea
										value={message}
										onChange={(e) => setMessage(e.target.value)}
										placeholder="Aggiungi un messaggio (opzionale)..."
										className={`w-full px-4 py-3 border rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all resize-none ${
											preferences.colorTheme === 'dark'
												? 'bg-slate-700 border-slate-600 text-slate-200 placeholder-slate-400'
												: 'bg-gray-50 border-gray-200'
										}`}
										rows={2}
									/>
								</div>

								{/* Error */}
								{error && (
									<div className="px-4 pb-4">
										<p className="text-sm text-red-500 bg-red-50 px-3 py-2 rounded-lg">
											{error}
										</p>
									</div>
								)}

								{/* Footer */}
								<div className={`p-4 border-t ${
									preferences.colorTheme === 'dark'
										? 'border-slate-700 bg-slate-900/50'
										: 'border-gray-100 bg-gray-50'
								}`}>
									<div className="flex items-center justify-between">
										<span className={`text-sm ${
											preferences.colorTheme === 'dark' ? 'text-slate-400' : 'text-gray-500'
										}`}>
											{selectedFriends.length} {selectedFriends.length === 1 ? 'amico selezionato' : 'amici selezionati'}
										</span>
										<button
											onClick={handleShare}
											disabled={sharing || selectedFriends.length === 0}
											className="px-6 py-2 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-lg hover:from-purple-600 hover:to-pink-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed font-medium flex items-center gap-2"
										>
											{sharing ? (
												<>
													<div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
													<span>Condivisione...</span>
												</>
											) : (
												<>
													<svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
													</svg>
													<span>Invia</span>
												</>
											)}
										</button>
									</div>
								</div>
							</>
						)}
					</div>
				</div>
			)}
		</>
	);
}
