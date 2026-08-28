'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { BookOpen, ListOrdered, Rss, Share2, Plus } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { useFriends } from '../../contexts/FriendsContext';
import { useArticles } from '../../contexts/ArticlesContext';
import { useArticleFilters, ReadingStatus } from '../../contexts/ArticleFiltersContext';
import { getArticleCounts, getReadingQueueCount, ArticleCounts } from '../../lib/api';
import ThemeSelector from '../ThemeSelector';
import StateMark, { StateMarkVariant } from './StateMark';

interface SidebarProps {
	onSaveLink: () => void;
}

type Destination = {
	href: string;
	label: string;
	icon: typeof BookOpen;
	badge?: number;
	badgeTone?: 'accent' | 'sage';
};

export default function Sidebar({ onSaveLink }: SidebarProps) {
	const pathname = usePathname();
	const router = useRouter();
	const { user, signOut } = useAuth();
	const { unreadSharesCount } = useFriends();
	const { state } = useArticles();
	const {
		filters,
		setReadingStatus,
		setIsFavorite,
		setSelectedTags,
	} = useArticleFilters();

	const [counts, setCounts] = useState<ArticleCounts | null>(null);
	const [queueCount, setQueueCount] = useState<number>(0);

	useEffect(() => {
		if (!user?.id) return;
		let cancelled = false;
		getArticleCounts(user.id)
			.then((c) => {
				if (!cancelled) setCounts(c);
			})
			.catch(() => {
				/* counts are non-essential — omit rather than fake */
			});
		getReadingQueueCount(user.id)
			.then((n) => {
				if (!cancelled) setQueueCount(n);
			})
			.catch(() => {});
		return () => {
			cancelled = true;
		};
		// Re-count when the loaded set changes (add / delete / status change).
	}, [user?.id, state.articles.length, pathname]);

	// Tags surfaced from the loaded articles.
	const availableTags = useMemo(() => {
		const set = new Set<string>();
		state.articles.forEach((a) => a.tags?.forEach((t) => set.add(t)));
		return Array.from(set).sort();
	}, [state.articles]);

	const destinations: Destination[] = [
		{ href: '/', label: 'Library', icon: BookOpen, badge: counts?.all },
		{ href: '/queue', label: 'Up next', icon: ListOrdered, badge: queueCount || undefined, badgeTone: 'sage' },
		{ href: '/rss', label: 'Feeds', icon: Rss, badgeTone: 'sage' },
		{
			href: '/shared',
			label: 'Shared with me',
			icon: Share2,
			badge: unreadSharesCount || undefined,
			badgeTone: 'accent',
		},
	];

	const onLibrary = pathname === '/';

	// A reading sub-item filters the Library — it never changes screen, but if the
	// user triggers it from elsewhere we route them to the Library first.
	const applyStatus = (status: ReadingStatus) => {
		setIsFavorite(undefined);
		setReadingStatus(status);
		if (!onLibrary) router.push('/');
	};

	const applyFavourites = () => {
		setReadingStatus('all');
		setIsFavorite(true);
		if (!onLibrary) router.push('/');
	};

	const toggleTag = (tag: string) => {
		const next = filters.selectedTags.includes(tag)
			? filters.selectedTags.filter((t) => t !== tag)
			: [...filters.selectedTags, tag];
		setSelectedTags(next);
		if (!onLibrary) router.push('/');
	};

	type ReadingItem = {
		key: string;
		label: string;
		mark: StateMarkVariant;
		count?: number;
		active: boolean;
		onClick: () => void;
	};

	const favActive = onLibrary && filters.isFavorite === true;
	const readingItems: ReadingItem[] = [
		{
			key: 'all',
			label: 'Everything',
			mark: 'everything',
			count: counts?.all,
			active: onLibrary && filters.readingStatus === 'all' && filters.isFavorite === undefined,
			onClick: () => applyStatus('all'),
		},
		{
			key: 'unread',
			label: 'Unread',
			mark: 'unread',
			count: counts?.unread,
			active: onLibrary && filters.readingStatus === 'unread' && !favActive,
			onClick: () => applyStatus('unread'),
		},
		{
			key: 'reading',
			label: 'In progress',
			mark: 'reading',
			count: counts?.reading,
			active: onLibrary && filters.readingStatus === 'reading' && !favActive,
			onClick: () => applyStatus('reading'),
		},
		{
			key: 'completed',
			label: 'Finished',
			mark: 'completed',
			count: counts?.completed,
			active: onLibrary && filters.readingStatus === 'completed' && !favActive,
			onClick: () => applyStatus('completed'),
		},
		{
			key: 'favourites',
			label: 'Favourites',
			mark: 'favourites',
			count: counts?.favorites,
			active: favActive,
			onClick: applyFavourites,
		},
	];

	const displayName = user?.email ? user.email.split('@')[0] : 'Reader';

	return (
		<aside className="flex h-full w-[264px] flex-none flex-col border-r border-app-line bg-app-rail px-[14px] pb-[14px] pt-5">
			{/* Brand */}
			<div className="flex items-center gap-2.5 px-1 pb-[18px]">
				<span className="flex h-[34px] w-[34px] items-center justify-center rounded-full bg-accent font-heading text-[17px] text-app-page">
					Z
				</span>
				<span className="font-heading text-[21px] text-ink">Zuper</span>
			</div>

			{/* Save a link */}
			<button
				type="button"
				onClick={onSaveLink}
				className="mb-4 flex w-full items-center justify-center gap-2 rounded-full bg-accent px-3.5 py-[11px] font-heading text-[14px] text-app-page transition-colors hover:bg-accent-600"
			>
				<Plus size={18} strokeWidth={2.75} />
				Save a link
			</button>

			{/* Destinations */}
			<nav className="flex flex-col gap-0.5">
				{destinations.map((d) => {
					const active = pathname === d.href;
					const Icon = d.icon;
					return (
						<Link
							key={d.href}
							href={d.href}
							className={`flex items-center gap-3 rounded-xl px-3 py-[9px] text-[14.5px] font-semibold transition-colors ${
								active
									? 'bg-accent text-app-page hover:bg-accent-600'
									: 'text-ink hover:bg-app-hover'
							}`}
						>
							<Icon size={18} strokeWidth={2.75} className="flex-none" />
							<span className="flex-1 truncate">{d.label}</span>
							{typeof d.badge === 'number' && d.badge > 0 && (
								<span
									className={`rounded-full px-2 py-0.5 text-[11px] font-bold ${
										active
											? 'bg-app-page/25 text-app-page'
											: d.badgeTone === 'sage'
												? 'bg-sage-200 text-sage-800'
												: 'bg-accent-200 text-accent-800'
									}`}
								>
									{d.badge}
								</span>
							)}
						</Link>
					);
				})}
			</nav>

			{/* Reading */}
			<SectionLabel>Reading</SectionLabel>
			<div className="flex flex-col gap-0.5">
				{readingItems.map((item) => (
					<button
						key={item.key}
						type="button"
						onClick={item.onClick}
						style={item.active ? { boxShadow: 'inset 2px 0 0 var(--app-accent)' } : undefined}
						className={`flex items-center gap-3 rounded-xl px-3 py-[9px] text-[14px] transition-colors ${
							item.active
								? 'bg-app-hover font-semibold text-accent-800 dark:text-accent'
								: 'text-ink hover:bg-app-hover'
						}`}
					>
						<span className="flex w-4 flex-none items-center justify-center">
							<StateMark variant={item.mark} />
						</span>
						<span className="flex-1 text-left">{item.label}</span>
						{typeof item.count === 'number' && (
							<span className="text-[12px] text-app-muted">{item.count}</span>
						)}
					</button>
				))}
			</div>

			{/* Tags */}
			{availableTags.length > 0 && (
				<>
					<SectionLabel>Tags</SectionLabel>
					<div className="flex flex-wrap gap-1.5 px-1">
						{availableTags.map((tag) => {
							const selected = filters.selectedTags.includes(tag);
							return (
								<button
									key={tag}
									type="button"
									onClick={() => toggleTag(tag)}
									className={`rounded-full border px-2.5 py-1 text-[12px] transition-colors ${
										selected
											? 'border-accent bg-accent text-app-page'
											: 'border-app-line text-app-muted hover:bg-app-hover hover:text-ink'
									}`}
								>
									{tag}
								</button>
							);
						})}
					</div>
				</>
			)}

			{/* Account */}
			<div className="mt-auto border-t border-app-line pt-3">
				<div className="flex items-center gap-2.5">
					<span className="flex h-[30px] w-[30px] flex-none items-center justify-center rounded-full bg-sage text-[13px] font-semibold text-app-page">
						{displayName.charAt(0).toUpperCase()}
					</span>
					<div className="min-w-0 flex-1">
						<div className="truncate text-[13.5px] font-semibold text-ink">{displayName}</div>
						<div className="truncate text-[11.5px] text-app-muted">{user?.email}</div>
					</div>
					<ThemeSelector />
				</div>
				<button
					type="button"
					onClick={signOut}
					className="mt-2 w-full rounded-full px-3 py-1.5 text-left text-[12.5px] text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
				>
					Sign out
				</button>
			</div>
		</aside>
	);
}

function SectionLabel({ children }: { children: React.ReactNode }) {
	return (
		<div className="px-3 pb-1.5 pt-5 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
			{children}
		</div>
	);
}
