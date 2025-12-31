'use server';

import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { fetchFeed, parseOPML, OpmlOutline, FeedData } from '@/lib/rssService';
import { syncRSSArticles } from '@/lib/api';
import * as cheerio from 'cheerio';

/**
 * Creates a new folder for RSS feeds
 */
export async function createFolder(name: string) {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { error: 'Unauthorized' };
	}

	const { data, error } = await supabase
		.from('rss_folders')
		.insert([{ user_id: user.id, name }])
		.select()
		.single();

	if (error) {
		return { error: error.message };
	}

	revalidatePath('/rss');
	return { data };
}

/**
 * Deletes a folder and all its feeds (cascade handled by database if configured, or needs explicit handling)
 */
export async function deleteFolder(folderId: string) {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { error: 'Unauthorized' };
	}

	const { error } = await supabase
		.from('rss_folders')
		.delete()
		.eq('id', folderId)
		.eq('user_id', user.id);

	if (error) {
		return { error: error.message };
	}

	revalidatePath('/rss');
	return { success: true };
}

/**
 * Adds a new RSS feed
 */
export async function addFeed(url: string, folderId: string | null = null) {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { error: 'Unauthorized' };
	}

	// validating feed
	try {
		const feedData = await fetchFeed(url);

		const { data, error } = await supabase
			.from('rss_feeds')
			.insert([{
				user_id: user.id,
				folder_id: folderId,
				url: url,
				title: feedData.title || url,
				site_url: feedData.link,
			}])
			.select()
			.single();

		if (error) {
			if (error.code === '23505') { // Unique violation
				return { error: 'You are already subscribed to this feed.' };
			}
			return { error: error.message };
		}

		revalidatePath('/rss');
		return { data };
	} catch (err) {
		return { error: `Failed to fetch feed: ${(err as Error).message}` };
	}
}

/**
 * Deletes a feed
 */
export async function deleteFeed(feedId: string) {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { error: 'Unauthorized' };
	}

	const { error } = await supabase
		.from('rss_feeds')
		.delete()
		.eq('id', feedId)
		.eq('user_id', user.id);

	if (error) {
		return { error: error.message };
	}

	revalidatePath('/rss');
	return { success: true };
}

/**
 * Updates the folder of a feed
 */
export async function updateFeedFolder(feedId: string, folderId: string | null) {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { error: 'Unauthorized' };
	}

	const { error } = await supabase
		.from('rss_feeds')
		.update({ folder_id: folderId })
		.eq('id', feedId)
		.eq('user_id', user.id);

	if (error) {
		return { error: error.message };
	}

	revalidatePath('/rss');
	return { success: true };
}

/**
 * Helper to recursively import OPML outlines
 */
async function importOutlines(supabase: any, userId: string, outlines: OpmlOutline[], parentFolderId: string | null = null) {
	let successCount = 0;
	let failCount = 0;

	for (const outline of outlines) {
		if (outline.type === 'rss' && outline.xmlUrl) {
			// It's a feed
			const { error } = await supabase
				.from('rss_feeds')
				.insert({
					user_id: userId,
					folder_id: parentFolderId,
					title: outline.title || outline.text,
					url: outline.xmlUrl,
					site_url: outline.htmlUrl
				});

			if (!error) successCount++;
			else failCount++;

		} else if (outline.outlines && outline.outlines.length > 0) {
			// It's a folder
			const { data: folder, error } = await supabase
				.from('rss_folders')
				.insert({
					user_id: userId,
					name: outline.title || outline.text
				})
				.select()
				.single();

			if (!error && folder) {
				const result = await importOutlines(supabase, userId, outline.outlines, folder.id);
				successCount += result.imported;
				failCount += result.failed;
			}
		}
	}
	return { imported: successCount, failed: failCount };
}

/**
 * Imports feeds from OPML content
 */
export async function importOPML(formData: FormData) {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { error: 'Unauthorized' };
	}

	const file = formData.get('file') as File;
	if (!file) {
		return { error: 'No file provided' };
	}

	const text = await file.text();

	try {
		const outlines = parseOPML(text);
		const result = await importOutlines(supabase, user.id, outlines);

		revalidatePath('/rss');
		return {
			success: true,
			message: `Imported ${result.imported} feeds. ${result.failed > 0 ? `(${result.failed} skipped/failed)` : ''}`
		};
	} catch (e) {
		return { error: 'Failed to parse OPML file.' };
	}
}

/**
 * PROXY ACTION: Fetch feed content server-side to avoid CORS
 * Also syncs articles to database for read tracking
 */
export async function getFeedContent(url: string, feedId?: string): Promise<{ feed?: FeedData; error?: string; syncStats?: { added: number; existing: number } }> {
	try {
		const feed = await fetchFeed(url);

		// If feedId is provided, sync articles to database for read tracking
		let syncStats = undefined;
		if (feedId) {
			const supabase = await createClient();
			const { data: { user } } = await supabase.auth.getUser();

			if (user && feed.items && feed.items.length > 0) {
				// Prepare articles for syncing - filter out items without guid/link/title
				const articles = feed.items
					.filter(item => item.guid || item.link || item.title)
					.map(item => ({
						guid: (item.guid || item.link || item.title)!,
						title: item.title || 'Untitled',
						link: item.link || '',
						pubDate: item.pubDate,
						author: item.creator || item.author,
						content: item.content,
						contentSnippet: item.contentSnippet,
					imageUrl: item.imageUrl
					}));

				// Sync articles to database
				if (articles.length > 0) {
					syncStats = await syncRSSArticles(user.id, feedId, articles, supabase);
				}
			}
		}

		return { feed, syncStats };
	} catch (err) {
		return { error: (err as Error).message };
	}
}

/**
 * Discovered feed result interface
 */
export interface DiscoveredFeed {
	url: string;
	title: string;
	type: 'rss' | 'atom';
	siteUrl?: string;
}

/**
 * Fetches HTML from a DuckDuckGo search for "query rss" or just "query"
 * Returns the first likely URL found in results.
 * 
 * NOTE: This is a lightweight scraper. It's fragile but avoids API keys.
 */
async function searchForUrl(query: string): Promise<string | null> {
	// 1. Web Scraping Search (DuckDuckGo)
	try {
		const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query + ' rss feed')}`;
		console.log(`🔍 Searching: ${searchUrl}`);
		const response = await fetch(searchUrl, {
			headers: {
				'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
			},
			signal: AbortSignal.timeout(5000)
		});

		if (response.ok) {
			const html = await response.text();
			const $ = cheerio.load(html);
			const firstResult = $('.result__a').first().attr('href');

			if (firstResult) {
				console.log(`✅ Search found: ${firstResult}`);
				return firstResult;
			}
		}
	} catch (e) {
		console.error('Search failed:', e);
	}

	// 2. Fallback: Heuristic Domain Guessing
	// e.g. "The Verge" -> "theverge.com"
	try {
		const cleanName = query.toLowerCase().replace(/[^a-z0-9]/g, '');
		if (cleanName.length > 2) {
			const guessUrl = `https://${cleanName}.com`;
			console.log(`🤔 Guessing URL: ${guessUrl}`);

			// Quick check if this domain exists
			const response = await fetch(guessUrl, {
				method: 'HEAD',
				headers: { 'User-Agent': 'Mozilla/5.0 (compatible; SuperReader/1.0)' },
				signal: AbortSignal.timeout(3000)
			});

			if (response.ok || response.status === 405) { // 405 Method Not Allowed often means server exists but hates HEAD
				console.log(`✅ Guess validated: ${guessUrl}`);
				return guessUrl;
			}
		}
	} catch (e) {
		console.log('Guessing failed:', e);
	}

	return null;
}


/**
 * Discovers RSS/Atom feeds from a given URL or domain or query
 */
export async function discoverFeeds(input: string): Promise<{ feeds?: DiscoveredFeed[]; error?: string }> {
	try {
		let normalizedUrl = input.trim();
		const discoveredFeeds: DiscoveredFeed[] = [];
		const checkedUrls = new Set<string>();

		// 1. Heuristic: Is it a URL?
		const hasProtocol = /^https?:\/\//i.test(normalizedUrl);
		const hasDomain = /\.[a-z]{2,}(\/|$)/i.test(normalizedUrl); // simplistic domain check

		if (!hasProtocol && !hasDomain) {
			// Case 1: Search Query (e.g. "The Verge")
			// Try to search for it
			const searchResult = await searchForUrl(normalizedUrl);
			if (searchResult) {
				normalizedUrl = searchResult;
			} else {
				return { error: `Could not find a website for "${input}". Please try a full URL.` };
			}
		} else if (!hasProtocol && hasDomain) {
			// Case 2: Domain without protocol (e.g. "theverge.com")
			normalizedUrl = 'https://' + normalizedUrl;
		}

		// At this point normalizedUrl should be a valid-ish URL

		// Parse the base URL
		let baseUrl: URL;
		try {
			baseUrl = new URL(normalizedUrl);
		} catch (e) {
			return { error: 'Invalid URL constructed.' };
		}

		const origin = baseUrl.origin;

		// 1. Fetch the HTML page to find <link> tags
		try {
			const response = await fetch(normalizedUrl, {
				headers: {
					'User-Agent': 'Mozilla/5.0 (compatible; SuperReader/1.0; +https://superreader.app)',
				},
				signal: AbortSignal.timeout(10000),
			});

			if (response.ok) {
				const contentType = response.headers.get('content-type') || '';

				// If the URL itself IS the feed (XML/RSS/Atom)
				if (contentType.includes('xml') || contentType.includes('rss') || contentType.includes('atom')) {
					// Verify it works
					try {
						const feedData = await fetchFeed(normalizedUrl);
						return {
							feeds: [{
								url: normalizedUrl,
								title: feedData.title || 'Feed',
								type: 'rss', // simplified
								siteUrl: feedData.link || origin
							}]
						};
					} catch (e) {
						// not a valid feed
					}
				}

				const html = await response.text();
				const $ = cheerio.load(html);

				// Parse HTML to find <link rel="alternate"> tags
				$('link[rel="alternate"]').each((_, el) => {
					const $el = $(el);
					const type = $el.attr('type')?.toLowerCase() || '';
					const href = $el.attr('href');
					const title = $el.attr('title');

					if (href && (type.includes('rss') || type.includes('atom'))) {
						let feedUrl = href;
						// Make absolute URL if relative
						if (feedUrl.startsWith('/')) {
							feedUrl = origin + feedUrl;
						} else if (!feedUrl.startsWith('http')) {
							// Handle protocol-relative //example.com/feed or path-relative
							if (feedUrl.startsWith('//')) {
								feedUrl = baseUrl.protocol + feedUrl;
							} else {
								feedUrl = new URL(feedUrl, normalizedUrl).href;
							}
						}

						if (!checkedUrls.has(feedUrl)) {
							checkedUrls.add(feedUrl);
							discoveredFeeds.push({
								url: feedUrl,
								title: title || 'Feed',
								type: type.includes('atom') ? 'atom' : 'rss',
								siteUrl: normalizedUrl,
							});
						}
					}
				});
			}
		} catch (err) {
			console.error('HTML fetch error:', err);
		}

		// 2. Check common feed URLs
		const commonPaths = [
			'/feed',
			'/rss',
			'/rss.xml',
			'/feed.xml',
			'/atom.xml',
			'/index.xml',
			'/blog/feed',
			'/blog/rss',
		];

		const promises = commonPaths.map(async path => {
			const testUrl = new URL(path, origin).href;
			// Prevent duplicates
			if (checkedUrls.has(testUrl)) return;

			checkedUrls.add(testUrl);

			try {
				const feedData = await fetchFeed(testUrl);
				// Check if this feed is already in our list (by URL)
				const existing = discoveredFeeds.find(f => f.url === testUrl);
				if (!existing) {
					discoveredFeeds.push({
						url: testUrl,
						title: feedData.title || 'Feed',
						type: 'rss',
						siteUrl: feedData.link || origin
					});
				}
			} catch (e) {
				// ignore invalid
			}
		});

		await Promise.allSettled(promises);

		// 3. Final Validation check (optional, but ensures we don't return 404s from scraped <links>)
		// We actually trust scraped links usually, but let's do a quick head check? 
		// No, let's blindly trust explicit link tags for speed, but validated common paths were already checked.
		// Actually, let's try to fetch title for scraped links if we can, concurrently.

		const finalFeeds: DiscoveredFeed[] = [];

		await Promise.all(discoveredFeeds.map(async (feed) => {
			// If we already have a nice title (and we know it works from common paths check), keep it.
			// If it came from a link tag, we might want to verify it works.
			try {
				// If it was scraped from link tag, title might be "RSS", "Atom", or "Feed". 
				// Let's try to get a better title if it's generic.
				if (feed.title === 'RSS' || feed.title === 'Atom' || feed.title === 'Feed' || !feed.title) {
					const data = await fetchFeed(feed.url);
					feed.title = data.title || feed.title;
					feed.siteUrl = data.link || feed.siteUrl;
				}
				finalFeeds.push(feed);
			} catch (e) {
				// scraped link was broken?
				console.log(`Failed to verify feed: ${feed.url}`);
			}
		}));

		if (finalFeeds.length === 0) {
			return { error: 'No RSS/Atom feeds found.' };
		}

		// Remove duplicates again just in case
		const uniqueFeeds = finalFeeds.filter((feed, index, self) =>
			index === self.findIndex((t) => (
				t.url === feed.url
			))
		);

		return { feeds: uniqueFeeds };

	} catch (err) {
		return { error: `Discovery failed: ${(err as Error).message}` };
	}
}

/**
 * Refreshes all RSS feeds for the current user
 * Fetches latest articles from all feeds and syncs them to the database
 */
export async function refreshAllFeeds(): Promise<{
	success: boolean;
	totalAdded: number;
	totalExisting: number;
	feedsRefreshed: number;
	errors: string[];
}> {
	const supabase = await createClient();
	const { data: { user } } = await supabase.auth.getUser();

	if (!user) {
		return { success: false, totalAdded: 0, totalExisting: 0, feedsRefreshed: 0, errors: ['Unauthorized'] };
	}

	// Get all feeds for the user
	const { data: feeds, error: feedsError } = await supabase
		.from('rss_feeds')
		.select('id, url')
		.eq('user_id', user.id);

	if (feedsError) {
		return {
			success: false,
			totalAdded: 0,
			totalExisting: 0,
			feedsRefreshed: 0,
			errors: [`Failed to fetch feeds: ${feedsError.message}`]
		};
	}

	if (!feeds || feeds.length === 0) {
		return { success: true, totalAdded: 0, totalExisting: 0, feedsRefreshed: 0, errors: [] };
	}

	let totalAdded = 0;
	let totalExisting = 0;
	let feedsRefreshed = 0;
	const errors: string[] = [];

	// Refresh each feed
	for (const feed of feeds) {
		try {
			const result = await getFeedContent(feed.url, feed.id);

			if (result.error) {
				errors.push(`${feed.url}: ${result.error}`);
			} else if (result.syncStats) {
				totalAdded += result.syncStats.added;
				totalExisting += result.syncStats.existing;
				feedsRefreshed++;
			}
		} catch (err) {
			errors.push(`${feed.url}: ${(err as Error).message}`);
		}
	}

	return {
		success: true,
		totalAdded,
		totalExisting,
		feedsRefreshed,
		errors
	};
}
