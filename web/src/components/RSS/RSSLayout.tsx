'use client';

import { useState, useCallback } from 'react';
import RSSSidebar from './RSSSidebar';
import FeedList from './FeedList';
import ImportModal from './ImportModal';
import DiscoveryModal from './DiscoveryModal';
import { markAllFeedArticlesAsRead } from '@/lib/api';

interface Feed {
	id: string;
	title: string | null;
	url: string;
	folder_id: string | null;
	unread_count?: number;
}

interface Folder {
	id: string;
	name: string;
}

interface RSSLayoutProps {
	initialFolders: Folder[];
	initialFeeds: Feed[];
	userId: string;
	onFeedUpdated?: () => void;
}

export default function RSSLayout({ initialFolders, initialFeeds, userId, onFeedUpdated }: RSSLayoutProps) {
	const [selectedFeed, setSelectedFeed] = useState<Feed | null>(null);
	// Phones show one pane at a time: the feed list or the articles of a feed.
	const [showListOnMobile, setShowListOnMobile] = useState(true);
	const [showImportModal, setShowImportModal] = useState(false);
	const [showDiscoveryModal, setShowDiscoveryModal] = useState(false);

	// We could also synchronize with URL params here if desired

	// Since Sidebar can add feeds/folders, we might want to re-fetch or optimistically update.
	// The server actions call revalidatePath('/rss'), so if this was a Server Component it would refresh.
	// But since this is a Client Component with initial data passed from Server Component,
	// the initial data won't update automatically unless the parent Server Component re-renders.
	// Next.js App Router: router.refresh() will re-execute Server Components and update the tree.
	// We don't have router.refresh() in the Sidebar actions (we used revalidatePath).
	// But revalidatePath only invalidates the cache; the client needs to refetch.
	// The actions in `rss.ts` just return data.
	// Ideally we should use `useRouter` and `router.refresh()` after mutations in Sidebar.

	// Actually the Sidebar is managing the mutations.
	// I should probably pass a refresh callback or let Sidebar handle router refresh?
	// I didn't add router.refresh() in Sidebar. I should probably add it there.

	// Handle marking all articles in a feed as read
	const handleMarkFeedAsRead = useCallback(async (feedId: string) => {
		try {
			await markAllFeedArticlesAsRead(feedId, userId);
			if (onFeedUpdated) onFeedUpdated();
		} catch (err) {
			console.error('Failed to mark feed as read:', err);
		}
	}, [userId, onFeedUpdated]);

	const handleSelectFeed = (feed: Feed | null) => {
		setSelectedFeed(feed);
		// "All articles" (null) has no article pane of its own: stay on the list
		setShowListOnMobile(feed === null);
	};

	// Handle back to feeds on mobile
	const handleBackToFeeds = () => {
		setShowListOnMobile(true);
	};

	return (
		<>
			{/* 61px = AppShell mobile top bar (hidden from md up) */}
			<div className="flex h-[calc(100%-61px)] overflow-hidden md:h-full">
				{/* Sidebar - Hidden on mobile if feed is selected */}
				<div
					className={`
						h-full
						${showListOnMobile ? 'w-full md:w-auto' : 'hidden md:block'}
						md:flex-shrink-0
					`}
				>
					<RSSSidebar
						folders={initialFolders}
						feeds={initialFeeds}
						selectedFeedId={selectedFeed?.id}
						onSelectFeed={handleSelectFeed}
						onOpenImportModal={() => setShowImportModal(true)}
						onOpenDiscoveryModal={() => setShowDiscoveryModal(true)}
						onMarkFeedAsRead={handleMarkFeedAsRead}
					/>
				</div>

				{/* Main Content - Full width on mobile if feed selected, hidden if not (unless on desktop where it's always visible) */}
				<div 
					className={`
						flex-1 flex flex-col h-full overflow-hidden
						${showListOnMobile ? 'hidden md:flex' : 'w-full'}
					`}
				>
					<FeedList
						feedUrl={selectedFeed?.url || null}
						feedId={selectedFeed?.id || null}
						userId={userId}
						onFeedUpdated={onFeedUpdated}
						onBack={handleBackToFeeds}
					/>
				</div>
			</div>

			{/* Modals rendered at layout level to properly overlay entire screen */}
			<ImportModal isOpen={showImportModal} onClose={() => setShowImportModal(false)} />
			<DiscoveryModal
				isOpen={showDiscoveryModal}
				onClose={() => setShowDiscoveryModal(false)}
				folders={initialFolders}
			/>
		</>
	);
}
