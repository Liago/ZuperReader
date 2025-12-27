'use server';

import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { fetchFeed, parseOPML, OpmlOutline, FeedData } from '@/lib/rssService';
import { syncRSSArticles } from '@/lib/api';

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
                        contentSnippet: item.contentSnippet
                    }));

                // Sync articles to database
                if (articles.length > 0) {
                    syncStats = await syncRSSArticles(user.id, feedId, articles);
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
 * Normalizes a URL by adding protocol if missing
 */
function normalizeUrl(url: string): string {
    url = url.trim();
    if (!/^https?:\/\//i.test(url)) {
        url = 'https://' + url;
    }
    return url;
}

/**
 * Discovers RSS/Atom feeds from a given URL or domain
 */
export async function discoverFeeds(inputUrl: string): Promise<{ feeds?: DiscoveredFeed[]; error?: string }> {
    try {
        const normalizedUrl = normalizeUrl(inputUrl);
        const discoveredFeeds: DiscoveredFeed[] = [];
        const checkedUrls = new Set<string>();

        // Parse the base URL
        const baseUrl = new URL(normalizedUrl);
        const origin = baseUrl.origin;

        // 1. Fetch the HTML page to find <link> tags
        try {
            const response = await fetch(normalizedUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (compatible; SuperReader/1.0; +https://superreader.app)',
                },
                signal: AbortSignal.timeout(10000), // 10 second timeout
            });

            if (response.ok) {
                const html = await response.text();

                // Parse HTML to find <link rel="alternate"> tags
                const linkRegex = /<link[^>]*rel=["']alternate["'][^>]*>/gi;
                const matches = html.match(linkRegex);

                if (matches) {
                    for (const match of matches) {
                        // Check if it's RSS or Atom
                        const typeMatch = match.match(/type=["']([^"']+)["']/i);
                        const hrefMatch = match.match(/href=["']([^"']+)["']/i);
                        const titleMatch = match.match(/title=["']([^"']+)["']/i);

                        if (typeMatch && hrefMatch) {
                            const type = typeMatch[1].toLowerCase();
                            if (type.includes('rss') || type.includes('atom')) {
                                let feedUrl = hrefMatch[1];

                                // Make absolute URL if relative
                                if (feedUrl.startsWith('/')) {
                                    feedUrl = origin + feedUrl;
                                } else if (!feedUrl.startsWith('http')) {
                                    feedUrl = origin + '/' + feedUrl;
                                }

                                if (!checkedUrls.has(feedUrl)) {
                                    checkedUrls.add(feedUrl);
                                    discoveredFeeds.push({
                                        url: feedUrl,
                                        title: titleMatch ? titleMatch[1] : 'Feed',
                                        type: type.includes('atom') ? 'atom' : 'rss',
                                        siteUrl: normalizedUrl,
                                    });
                                }
                            }
                        }
                    }
                }
            }
        } catch (err) {
            // Continue to check common paths even if HTML fetch fails
            console.error('HTML fetch error:', err);
        }

        // 2. Check common feed URLs
        const commonPaths = [
            '/feed',
            '/rss',
            '/feed.xml',
            '/rss.xml',
            '/atom.xml',
            '/feed/atom',
            '/index.xml',
            '/blog/feed',
            '/blog/rss',
            '/feeds/posts/default',
        ];

        for (const path of commonPaths) {
            const testUrl = origin + path;

            if (!checkedUrls.has(testUrl)) {
                checkedUrls.add(testUrl);

                try {
                    // Try to validate the feed
                    const feedData = await fetchFeed(testUrl);

                    // If successful, add to discovered feeds
                    const existingIndex = discoveredFeeds.findIndex(f => f.url === testUrl);
                    if (existingIndex >= 0) {
                        // Update existing entry with actual data
                        discoveredFeeds[existingIndex] = {
                            url: testUrl,
                            title: feedData.title || discoveredFeeds[existingIndex].title,
                            type: testUrl.includes('atom') ? 'atom' : 'rss',
                            siteUrl: feedData.link || normalizedUrl,
                        };
                    } else {
                        // Add new entry
                        discoveredFeeds.push({
                            url: testUrl,
                            title: feedData.title || 'Feed',
                            type: testUrl.includes('atom') ? 'atom' : 'rss',
                            siteUrl: feedData.link || normalizedUrl,
                        });
                    }
                } catch (err) {
                    // Feed not valid, skip
                    continue;
                }
            }
        }

        // 3. Validate all discovered feeds
        const validatedFeeds: DiscoveredFeed[] = [];

        for (const feed of discoveredFeeds) {
            try {
                const feedData = await fetchFeed(feed.url);
                validatedFeeds.push({
                    ...feed,
                    title: feedData.title || feed.title,
                    siteUrl: feedData.link || feed.siteUrl,
                });
            } catch (err) {
                // Feed not valid, skip
                continue;
            }
        }

        if (validatedFeeds.length === 0) {
            return { error: 'No RSS/Atom feeds found for this URL.' };
        }

        return { feeds: validatedFeeds };

    } catch (err) {
        return { error: `Discovery failed: ${(err as Error).message}` };
    }
}
