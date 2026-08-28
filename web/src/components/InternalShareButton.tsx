'use client';

import { useState } from 'react';
import { Users, X, Check, Send } from 'lucide-react';
import { shareArticleWithFriend } from '@/lib/api';
import { useFriends } from '@/contexts/FriendsContext';
import { useAuth } from '@/contexts/AuthContext';

interface InternalShareButtonProps {
	articleId: string;
	articleTitle: string;
}

export default function InternalShareButton({ articleId, articleTitle }: InternalShareButtonProps) {
	const { user } = useAuth();
	const { friends } = useFriends();
	const [showModal, setShowModal] = useState(false);
	const [selectedFriends, setSelectedFriends] = useState<string[]>([]);
	const [message, setMessage] = useState('');
	const [sharing, setSharing] = useState(false);
	const [success, setSuccess] = useState(false);
	const [error, setError] = useState<string | null>(null);

	const toggleFriend = (friendId: string) => {
		setSelectedFriends((prev) =>
			prev.includes(friendId) ? prev.filter((id) => id !== friendId) : [...prev, friendId]
		);
	};

	const handleShare = async () => {
		if (!user || selectedFriends.length === 0) return;

		setSharing(true);
		setError(null);

		try {
			await Promise.all(
				selectedFriends.map((friendId) =>
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
			setError(err instanceof Error ? err.message : 'Failed to share.');
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

	// Don't show the button if the user has no friends
	if (friends.length === 0) return null;

	return (
		<>
			<button
				onClick={() => setShowModal(true)}
				title="Share with friends"
				className="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
			>
				<Users size={16} strokeWidth={2.75} />
			</button>

			{showModal && (
				<div
					className="fixed inset-0 z-50 grid place-items-center p-4"
					style={{ background: 'rgba(32,30,29,.42)' }}
					onClick={handleClose}
				>
					<div
						className="max-h-[80vh] w-full max-w-md overflow-hidden rounded-[28px] border border-app-line bg-app-card [box-shadow:var(--shadow-modal)]"
						onClick={(e) => e.stopPropagation()}
					>
						{/* Header */}
						<div className="border-b border-app-line p-6">
							<div className="flex items-center justify-between gap-4">
								<h2 className="font-heading text-[21px] text-ink">Share with friends</h2>
								<button
									onClick={handleClose}
									className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
								>
									<X size={16} strokeWidth={2.75} />
								</button>
							</div>
							<p className="mt-1 line-clamp-1 text-[13px] text-app-muted">{articleTitle}</p>
						</div>

						{success ? (
							<div className="p-8 text-center">
								<div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-sage">
									<Check size={28} strokeWidth={2.75} className="text-app-page" />
								</div>
								<h3 className="font-heading text-[19px] text-ink">Shared</h3>
								<p className="mt-1 text-[13.5px] text-app-muted">The article was shared with your friends.</p>
							</div>
						) : (
							<>
								{/* Friends list */}
								<div className="max-h-64 overflow-y-auto p-4">
									<ul className="space-y-2">
										{friends.map((friend) => {
											const isSelected = selectedFriends.includes(friend.user.id);
											return (
												<li
													key={friend.friendship_id}
													onClick={() => toggleFriend(friend.user.id)}
													className={`flex cursor-pointer items-center gap-3 rounded-[18px] border p-3 transition-colors ${
														isSelected ? 'border-accent bg-accent-100' : 'border-app-line hover:bg-app-hover'
													}`}
												>
													<span
														className={`flex h-5 w-5 flex-none items-center justify-center rounded-full border transition-colors ${
															isSelected ? 'border-accent bg-accent text-app-page' : 'border-app-line'
														}`}
													>
														{isSelected && <Check size={12} strokeWidth={3} />}
													</span>
													<span className="flex h-9 w-9 flex-none items-center justify-center rounded-full bg-sage text-[13px] font-semibold text-app-page">
														{friend.user.display_name?.charAt(0).toUpperCase() || '?'}
													</span>
													<span className="text-[14px] font-medium text-ink">
														{friend.user.display_name || 'Friend'}
													</span>
												</li>
											);
										})}
									</ul>
								</div>

								{/* Message */}
								<div className="px-4 pb-4">
									<textarea
										value={message}
										onChange={(e) => setMessage(e.target.value)}
										placeholder="Add a message (optional)…"
										rows={2}
										className="w-full resize-none rounded-[18px] border border-app-line bg-app-surface px-4 py-3 text-[14px] text-ink placeholder:text-app-muted focus:border-accent focus:outline-none"
									/>
								</div>

								{error && (
									<div className="px-4 pb-4">
										<p className="rounded-[14px] px-3 py-2 text-[13px] font-medium text-accent-800" style={{ background: 'var(--accent-100)' }}>
											{error}
										</p>
									</div>
								)}

								{/* Footer */}
								<div className="flex items-center justify-between gap-4 border-t border-app-line p-4">
									<span className="text-[13px] text-app-muted">
										{selectedFriends.length} selected
									</span>
									<button
										onClick={handleShare}
										disabled={sharing || selectedFriends.length === 0}
										className="flex items-center gap-2 rounded-full bg-accent px-5 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600 disabled:cursor-not-allowed disabled:opacity-50"
									>
										<Send size={15} strokeWidth={2.75} className={sharing ? 'animate-pulse' : ''} />
										{sharing ? 'Sending…' : 'Send'}
									</button>
								</div>
							</>
						)}
					</div>
				</div>
			)}
		</>
	);
}
