'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { useFriends } from '@/contexts/FriendsContext';
import { useTheme } from '@/contexts/ThemeContext';
import { useReadingPreferences } from '@/contexts/ReadingPreferencesContext';
import { getUserStatistics, getMonthlySavedCounts, updateUserProfile, MonthlyActivity } from '@/lib/api';
import AppShell from '@/components/shell/AppShell';

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
	const { userProfile, refreshFriends } = useFriends();
	const { theme } = useTheme();
	const { preferences } = useReadingPreferences();

	const [statistics, setStatistics] = useState<Statistics | null>(null);
	const [activity, setActivity] = useState<MonthlyActivity[]>([]);

	const [isEditing, setIsEditing] = useState(false);
	const [displayName, setDisplayName] = useState('');
	const [bio, setBio] = useState('');
	const [saving, setSaving] = useState(false);

	useEffect(() => {
		if (!authLoading && !user) router.push('/login');
	}, [user, authLoading, router]);

	useEffect(() => {
		if (userProfile) {
			setDisplayName(userProfile.display_name || '');
			setBio(userProfile.bio || '');
		}
	}, [userProfile]);

	useEffect(() => {
		if (!user) return;
		getUserStatistics(user.id).then(setStatistics).catch((e) => console.error(e));
		getMonthlySavedCounts(user.id).then(setActivity).catch((e) => console.error(e));
	}, [user]);

	const handleSaveProfile = async () => {
		if (!user) return;
		setSaving(true);
		try {
			await updateUserProfile(user.id, { display_name: displayName, bio });
			setIsEditing(false);
			await refreshFriends();
		} catch (err) {
			console.error('Error saving profile:', err);
		} finally {
			setSaving(false);
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

	const name = userProfile?.display_name || user.email?.split('@')[0] || 'Reader';
	const memberSince = user.created_at
		? new Date(user.created_at).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
		: null;

	const readingDefault = `${preferences.fontFamily === 'serif' ? 'Serif' : 'Figtree'} · ${preferences.fontSize}px`;
	const appearance = theme === 'auto' ? 'Auto (system)' : theme === 'dark' ? 'Dark' : 'Cream';

	const maxCount = Math.max(1, ...activity.map((a) => a.count));
	const peakIdx = activity.reduce((best, a, i, arr) => (a.count > arr[best].count ? i : best), 0);

	return (
		<AppShell>
			<div className="mx-auto max-w-[840px] px-9 py-8">
				{/* Header */}
				<div className="flex flex-wrap items-center gap-5">
					<span className="flex h-[76px] w-[76px] flex-none items-center justify-center rounded-full bg-accent font-heading text-[32px] text-app-page">
						{name.charAt(0).toUpperCase()}
					</span>
					<div className="min-w-0 flex-1">
						<h1 className="font-heading text-[34px] leading-none text-ink">{name}</h1>
						<p className="mt-1.5 text-[13px] text-app-muted">
							{user.email}
							{memberSince && <> · member since {memberSince}</>}
						</p>
					</div>
					<div className="flex gap-2.5">
						<button
							type="button"
							onClick={() => setIsEditing((v) => !v)}
							className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							Edit profile
						</button>
						<button
							type="button"
							onClick={signOut}
							className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							Sign out
						</button>
					</div>
				</div>

				{/* Inline edit */}
				{isEditing && (
					<div className="mt-5 rounded-3xl border border-app-line bg-app-card p-5">
						<label className="mb-1.5 block text-[12px] font-medium text-app-muted">Display name</label>
						<input
							type="text"
							value={displayName}
							onChange={(e) => setDisplayName(e.target.value)}
							className="w-full rounded-full border border-app-line bg-app-surface px-4 py-2.5 text-[14px] text-ink focus:border-accent focus:outline-none"
						/>
						<label className="mb-1.5 mt-3 block text-[12px] font-medium text-app-muted">Bio</label>
						<textarea
							value={bio}
							onChange={(e) => setBio(e.target.value)}
							rows={2}
							className="w-full resize-none rounded-[18px] border border-app-line bg-app-surface px-4 py-2.5 text-[14px] text-ink focus:border-accent focus:outline-none"
						/>
						<div className="mt-3 flex justify-end gap-2.5">
							<button
								type="button"
								onClick={() => {
									setIsEditing(false);
									setDisplayName(userProfile?.display_name || '');
									setBio(userProfile?.bio || '');
								}}
								className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover"
							>
								Cancel
							</button>
							<button
								type="button"
								onClick={handleSaveProfile}
								disabled={saving}
								className="rounded-full bg-accent px-5 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600 disabled:opacity-50"
							>
								{saving ? 'Saving…' : 'Save'}
							</button>
						</div>
					</div>
				)}

				{/* Stats */}
				<div className="mt-7 grid grid-cols-2 gap-3.5 sm:grid-cols-4">
					<StatCard label="Saved" value={statistics?.totalArticles} />
					<StatCard label="Finished" value={statistics?.readArticles} tone="sage" />
					<StatCard label="Favourites" value={statistics?.favoriteArticles} tone="accent" />
					<StatCard label="Shared out" value={statistics?.sharedArticlesCount} />
				</div>
				{statistics && (
					<p className="mt-3 text-[12.5px] text-app-muted">
						{statistics.totalLikesReceived} likes · {statistics.totalCommentsReceived} comments ·{' '}
						{statistics.friendsCount} friends · {statistics.receivedArticlesCount} received
					</p>
				)}

				{/* Activity */}
				<div className="mt-6 rounded-3xl border border-app-line bg-app-card p-6">
					<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
						Saved over the last 12 months
					</div>
					<div className="mt-4 flex h-24 items-end gap-[7px]">
						{activity.map((m, i) => {
							const h = Math.round((m.count / maxCount) * 100);
							const color = m.isCurrent
								? 'var(--app-accent)'
								: i === peakIdx
									? 'var(--app-sage)'
									: 'var(--accent-300)';
							return (
								<div
									key={i}
									className="flex-1 rounded-t-lg"
									style={{ height: `${Math.max(4, h)}%`, background: color }}
									title={`${m.label}: ${m.count}`}
								/>
							);
						})}
					</div>
					<p className="mt-3 text-[12.5px] text-app-muted">
						{activity.reduce((s, m) => s + m.count, 0)} articles saved in the last year.
					</p>
				</div>

				{/* Settings */}
				<div className="mt-6 overflow-hidden rounded-3xl border border-app-line bg-app-card">
					<SettingRow label="Reading defaults" value={readingDefault} />
					<SettingRow label="Appearance" value={appearance} />
					<SettingRow label="Feed refresh" value="Manage in Feeds" href="/rss" />
				</div>
			</div>
		</AppShell>
	);
}

function StatCard({ label, value, tone }: { label: string; value?: number; tone?: 'accent' | 'sage' }) {
	const figureColor = tone === 'sage' ? 'text-sage-700' : tone === 'accent' ? 'text-accent-700' : 'text-ink';
	return (
		<div className="rounded-[22px] border border-app-line bg-app-card p-5">
			<div className={`font-heading text-[34px] leading-none ${figureColor}`}>{value ?? '—'}</div>
			<div className="mt-1.5 text-[12.5px] text-app-muted">{label}</div>
		</div>
	);
}

function SettingRow({ label, value, href }: { label: string; value: string; href?: string }) {
	const content = (
		<div className="flex items-center justify-between px-5 py-4">
			<span className="text-[14.5px] font-semibold text-ink">{label}</span>
			<span className="text-[13px] text-app-muted">{value}</span>
		</div>
	);
	if (href) {
		return (
			<a href={href} className="block border-b border-app-line transition-colors last:border-b-0 hover:bg-app-hover">
				{content}
			</a>
		);
	}
	return <div className="border-b border-app-line last:border-b-0">{content}</div>;
}
