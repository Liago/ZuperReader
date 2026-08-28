'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { UserPlus, X, Check, Share2 } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useFriends } from '@/contexts/FriendsContext';
import { getSharedWithMe, markShareAsRead, deleteArticleShare } from '@/lib/api';
import { ArticleShare } from '@/lib/supabase';
import AppShell from '@/components/shell/AppShell';
import UserSearch from '@/components/UserSearch';

function timeAgo(dateString: string) {
	const date = new Date(dateString);
	const diff = Math.floor((Date.now() - date.getTime()) / 1000);
	if (diff < 60) return 'just now';
	if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
	if (diff < 86400) return `${Math.floor(diff / 3600)} hours ago`;
	if (diff < 604800) return `${Math.floor(diff / 86400)} days ago`;
	return date.toLocaleDateString('en-US', { day: 'numeric', month: 'short' });
}

export default function SharedPage() {
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const {
		friends,
		pendingRequests,
		sentRequests,
		refreshUnreadCount,
		acceptRequest,
		rejectRequest,
		deleteFriend,
	} = useFriends();

	const [shares, setShares] = useState<ArticleShare[]>([]);
	const [loading, setLoading] = useState(true);
	const [showFindFriends, setShowFindFriends] = useState(false);

	useEffect(() => {
		if (!authLoading && !user) router.push('/login');
	}, [user, authLoading, router]);

	useEffect(() => {
		const loadShares = async () => {
			if (!user) return;
			setLoading(true);
			try {
				setShares(await getSharedWithMe(user.id));
			} catch (err) {
				console.error('Error loading shared articles:', err);
			} finally {
				setLoading(false);
			}
		};
		loadShares();
	}, [user]);

	const handleRead = async (share: ArticleShare) => {
		if (!share.is_read) {
			try {
				await markShareAsRead(share.id);
				setShares((prev) => prev.map((s) => (s.id === share.id ? { ...s, is_read: true } : s)));
				await refreshUnreadCount();
			} catch (err) {
				console.error('Error marking as read:', err);
			}
		}
	};

	const handleDeleteShare = async (shareId: string) => {
		try {
			await deleteArticleShare(shareId);
			setShares((prev) => prev.filter((s) => s.id !== shareId));
			await refreshUnreadCount();
		} catch (err) {
			console.error('Error deleting share:', err);
		}
	};

	if (authLoading) {
		return (
			<div className="flex min-h-screen items-center justify-center bg-app-page">
				<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
			</div>
		);
	}

	if (!user) return null;

	const unreadCount = shares.filter((s) => !s.is_read).length;

	return (
		<AppShell>
			<div className="mx-auto max-w-[780px] px-9 py-8">
				{/* Header */}
				<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
					{unreadCount} new · {friends.length} friends
				</div>
				<h1 className="mt-1 font-heading text-[34px] leading-none text-ink">Shared with me</h1>

				{/* Shares */}
				<div className="mt-6 flex flex-col gap-3.5">
					{loading ? (
						[...Array(3)].map((_, i) => (
							<div key={i} className="h-28 animate-pulse rounded-3xl border border-app-line bg-app-card" />
						))
					) : shares.length === 0 ? (
						<div className="rounded-3xl border border-app-line bg-app-card px-6 py-16 text-center">
							<div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-app-surface">
								<Share2 size={26} className="text-accent opacity-60" strokeWidth={1.75} />
							</div>
							<p className="font-heading text-[21px] text-ink">Nothing shared yet</p>
							<p className="mt-1.5 text-[13.5px] text-app-muted">
								When friends share articles with you, they land here.
							</p>
						</div>
					) : (
						shares.map((share) => (
							<article
								key={share.id}
								className={`flex gap-4 rounded-3xl border bg-app-card p-5 ${
									share.is_read ? 'border-app-line' : 'border-accent'
								}`}
							>
								{share.article?.image_url && (
									<div className="hidden h-[88px] w-[120px] flex-none overflow-hidden rounded-2xl bg-app-surface sm:block">
										{/* eslint-disable-next-line @next/next/no-img-element */}
										<img
											src={share.article.image_url}
											alt={share.article.title}
											className="washed h-full w-full object-cover"
										/>
									</div>
								)}

								<div className="min-w-0 flex-1">
									<div className="flex items-center gap-2 text-[13px] text-app-muted">
										<span className="flex h-6 w-6 flex-none items-center justify-center rounded-full bg-sage text-[11px] font-semibold text-app-page">
											{share.sharer?.display_name?.charAt(0).toUpperCase() || '?'}
										</span>
										<span>
											<span className="font-semibold text-ink">
												{share.sharer?.display_name || 'Someone'}
											</span>{' '}
											shared this · {timeAgo(share.created_at)}
										</span>
									</div>

									<h3 className="text-pretty mt-2 text-[17px] font-bold leading-[1.3] text-ink">
										{share.article?.title || 'Untitled article'}
									</h3>

									{share.message && (
										<blockquote className="mt-2 border-l-[3px] border-sage pl-3 text-[13.5px] italic text-app-muted">
											{share.message}
										</blockquote>
									)}
								</div>

								<div className="flex flex-none flex-col items-stretch gap-2">
									<Link
										href={`/articles/${share.article_id}`}
										onClick={() => handleRead(share)}
										className="rounded-full bg-accent px-4 py-2 text-center text-[13px] font-semibold text-app-page transition-colors hover:bg-accent-600"
									>
										Read
									</Link>
									<button
										type="button"
										title="Add to Up next"
										className="rounded-full border border-app-line px-4 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
									>
										Queue
									</button>
									<button
										type="button"
										onClick={() => handleDeleteShare(share.id)}
										className="text-[12px] text-app-muted transition-colors hover:text-accent"
									>
										Remove
									</button>
								</div>
							</article>
						))
					)}
				</div>

				{/* Friends */}
				<div className="mt-8 border-t border-app-line pt-6">
					<div className="mb-3 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
						Friends
					</div>
					<div className="flex flex-wrap items-center gap-2">
						{friends.map((f) => (
							<span
								key={f.friendship_id}
								className="group flex items-center gap-2 rounded-full border border-app-line py-1.5 pl-2 pr-3.5 text-[13px] text-ink"
							>
								<span className="flex h-6 w-6 flex-none items-center justify-center rounded-full bg-sage text-[11px] font-semibold text-app-page">
									{f.user.display_name?.charAt(0).toUpperCase() || '?'}
								</span>
								{f.user.display_name || 'Friend'}
								<button
									type="button"
									onClick={() => deleteFriend(f.friendship_id)}
									title="Remove friend"
									className="text-app-muted opacity-0 transition-opacity hover:text-accent group-hover:opacity-100"
								>
									<X size={13} strokeWidth={2.75} />
								</button>
							</span>
						))}

						<button
							type="button"
							onClick={() => setShowFindFriends(true)}
							className="flex items-center gap-2 rounded-full bg-app-surface px-4 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							<UserPlus size={15} strokeWidth={2.75} />
							Find friends
							{pendingRequests.length > 0 && (
								<span className="rounded-full bg-accent px-1.5 py-0.5 text-[11px] font-bold text-app-page">
									{pendingRequests.length}
								</span>
							)}
						</button>
					</div>
				</div>
			</div>

			{/* Find friends modal */}
			{showFindFriends && (
				<div
					className="fixed inset-0 z-50 grid place-items-center p-4"
					style={{ background: 'rgba(32,30,29,.42)' }}
					onClick={() => setShowFindFriends(false)}
				>
					<div
						className="max-h-[85vh] w-full max-w-[520px] overflow-y-auto rounded-[28px] border border-app-line bg-app-card p-6 [box-shadow:var(--shadow-modal)]"
						onClick={(e) => e.stopPropagation()}
					>
						<div className="flex items-start justify-between gap-4">
							<h2 className="font-heading text-[24px] text-ink">Find friends</h2>
							<button
								type="button"
								onClick={() => setShowFindFriends(false)}
								className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
							>
								<X size={16} strokeWidth={2.75} />
							</button>
						</div>

						{/* Pending requests */}
						{pendingRequests.length > 0 && (
							<div className="mt-5">
								<div className="mb-2 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
									Requests
								</div>
								<div className="flex flex-col gap-2">
									{pendingRequests.map((r) => (
										<div
											key={r.friendship_id}
											className="flex items-center gap-3 rounded-[18px] border border-app-line px-3 py-2.5"
										>
											<span className="flex h-8 w-8 flex-none items-center justify-center rounded-full bg-sage text-[13px] font-semibold text-app-page">
												{r.user.display_name?.charAt(0).toUpperCase() || '?'}
											</span>
											<span className="min-w-0 flex-1 truncate text-[14px] text-ink">
												{r.user.display_name || 'User'}
											</span>
											<button
												type="button"
												onClick={() => acceptRequest(r.friendship_id)}
												title="Accept"
												className="flex h-8 w-8 items-center justify-center rounded-full bg-accent text-app-page transition-colors hover:bg-accent-600"
											>
												<Check size={16} strokeWidth={2.75} />
											</button>
											<button
												type="button"
												onClick={() => rejectRequest(r.friendship_id)}
												title="Decline"
												className="flex h-8 w-8 items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
											>
												<X size={16} strokeWidth={2.75} />
											</button>
										</div>
									))}
								</div>
							</div>
						)}

						{sentRequests.length > 0 && (
							<p className="mt-3 text-[12.5px] text-app-muted">
								{sentRequests.length} pending sent request{sentRequests.length > 1 ? 's' : ''}.
							</p>
						)}

						{/* User search */}
						<div className="mt-5">
							<UserSearch onClose={() => setShowFindFriends(false)} />
						</div>
					</div>
				</div>
			)}
		</AppShell>
	);
}
