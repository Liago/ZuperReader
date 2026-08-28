'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { createClient } from '@/lib/supabase/client';
import { getRSSFeedsWithUnreadCounts } from '@/lib/api';
import AppShell from '@/components/shell/AppShell';
import RSSLayout from '@/components/RSS/RSSLayout';
import RefreshProgress from '@/components/RSS/RefreshProgress';
import { refreshFeedsParallel } from '@/app/actions/rss';

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

export default function RSSPage() {
	const { user, loading } = useAuth();
	const router = useRouter();
	const [folders, setFolders] = useState<Folder[]>([]);
	const [feeds, setFeeds] = useState<Feed[]>([]);
	const [isLoadingData, setIsLoadingData] = useState(true);
	const [error, setError] = useState<string | null>(null);
	const [isRefreshing, setIsRefreshing] = useState(false);
	const [refreshProgress, setRefreshProgress] = useState({ current: 0, total: 0 });

	useEffect(() => {
		if (!loading && !user) {
			router.push('/login');
		}
	}, [user, loading, router]);

	// Define fetch function
	const fetchRSSData = useCallback(async () => {
		if (!user) return;

		try {
			// Don't show full loading spinner for background updates if we already have data
			if (feeds.length === 0) setIsLoadingData(true);

			const supabase = createClient();

			// Fetch Folders
			const { data: foldersData, error: foldersError } = await supabase
				.from('rss_folders')
				.select('*')
				.eq('user_id', user.id)
				.order('name');

			if (foldersError) {
				console.error('Error fetching RSS folders:', foldersError);
				// Only set error if we don't have data yet
				if (feeds.length === 0) setError('Error loading RSS feeds. Please try again.');
				return;
			}

			// Fetch Feeds with unread counts
			const feedsData = await getRSSFeedsWithUnreadCounts(user.id);

			setFolders(foldersData || []);
			setFeeds(feedsData || []);
		} catch (err) {
			console.error('Error fetching RSS data:', err);
			if (feeds.length === 0) setError('Error loading RSS feeds. Please try again.');
		} finally {
			setIsLoadingData(false);
		}
	}, [user, feeds.length]);

	useEffect(() => {
		if (!loading && !user) {
			router.push('/login');
		}
	}, [user, loading, router]);

	useEffect(() => {
		if (!user) return;
		fetchRSSData();
	}, [user, fetchRSSData]);

	// Track if we've already started refreshing to prevent double refresh
	const hasStartedRefresh = useRef(false);

	// Optimized parallel feed refresh on mount
	// Uses stale-while-revalidate pattern: show cached data immediately, refresh in background
	useEffect(() => {
		if (!user) return;
		if (hasStartedRefresh.current) return; // Prevent double refresh on StrictMode
		hasStartedRefresh.current = true;

		const refreshFeeds = async () => {
			setIsRefreshing(true);

			try {
				// Get all user feeds
				const supabase = createClient();
				const { data: userFeeds, error: feedsError } = await supabase
					.from('rss_feeds')
					.select('id, url, title')
					.eq('user_id', user.id);

				if (feedsError || !userFeeds || userFeeds.length === 0) {
					console.warn('No feeds to refresh');
					setIsRefreshing(false);
					return;
				}

				const totalFeeds = userFeeds.length;
				setRefreshProgress({ current: 0, total: totalFeeds });

				// Use optimized parallel refresh with concurrency of 5
				// This is much faster than sequential refresh
				const CONCURRENCY = 5;
				let completed = 0;

				// Process feeds in parallel batches for better performance
				for (let i = 0; i < userFeeds.length; i += CONCURRENCY) {
					const batch = userFeeds.slice(i, i + CONCURRENCY);

					// Refresh this batch in parallel
					const batchResult = await refreshFeedsParallel(batch, CONCURRENCY);

					// Update progress after each batch completes
					completed += batch.length;
					setRefreshProgress({ current: completed, total: totalFeeds });

					// Log batch results
					if (batchResult.totalAdded > 0) {
						console.log(`Batch ${Math.floor(i / CONCURRENCY) + 1}: Added ${batchResult.totalAdded} new articles`);
					}
					if (batchResult.errorCount > 0) {
						const errors = batchResult.results
							.filter(r => !r.success)
							.map(r => `${r.feedTitle}: ${r.error}`);
						console.warn('Batch errors:', errors);
					}

					// Incrementally update unread counts after each batch
					// This provides immediate feedback to the user
					await fetchRSSData();
				}

				console.log(`Refresh complete: ${totalFeeds} feeds processed`);

				// Brief completion display
				await new Promise(resolve => setTimeout(resolve, 800));

			} catch (err) {
				console.error('Error refreshing feeds:', err);
			} finally {
				setIsRefreshing(false);
				setRefreshProgress({ current: 0, total: 0 });
			}
		};

		// Start refresh in background - don't block initial render
		// The cached data is already displayed, refresh happens asynchronously
		refreshFeeds();
	}, [user, fetchRSSData]);

	if (loading || (isLoadingData && feeds.length === 0)) {
		return (
			<div className="flex min-h-screen items-center justify-center bg-app-page">
				<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
			</div>
		);
	}

	if (!user) {
		return null; // Will redirect to login
	}

	return (
		<AppShell>
			{/* Progress Indicator */}
			<RefreshProgress
				current={refreshProgress.current}
				total={refreshProgress.total}
				isVisible={isRefreshing}
			/>

			{error && feeds.length === 0 ? (
				<div className="flex h-full items-center justify-center px-4 text-center">
					<p className="font-semibold text-accent">{error}</p>
				</div>
			) : (
				<RSSLayout
					initialFolders={folders}
					initialFeeds={feeds}
					userId={user.id}
					onFeedUpdated={fetchRSSData}
				/>
			)}
		</AppShell>
	);
}
