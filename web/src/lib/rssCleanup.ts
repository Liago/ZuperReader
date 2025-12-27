/**
 * RSS Articles Cleanup Utilities
 *
 * Manages automatic cleanup of old RSS articles to prevent database bloat.
 * This follows best practices from commercial feed readers like Feedly, Inoreader, etc.
 */

import { deleteOldRSSArticles } from './api';
import { createClient } from './supabase/client';

/**
 * Cleanup configuration
 */
export const CLEANUP_CONFIG = {
    // Keep read articles for 30 days (Feedly: 30 days, Inoreader: 90 days)
    READ_RETENTION_DAYS: 30,

    // Keep unread articles for 90 days (most readers: unlimited, but we set a limit)
    UNREAD_RETENTION_DAYS: 90,

    // Maximum articles per feed to keep in database
    MAX_ARTICLES_PER_FEED: 200,
} as const;

/**
 * Delete old read RSS articles beyond retention period
 * This should be called periodically (daily recommended)
 */
export async function cleanupOldReadArticles(userId: string): Promise<{
    deletedCount: number;
    error?: string;
}> {
    try {
        const deletedCount = await deleteOldRSSArticles(userId, CLEANUP_CONFIG.READ_RETENTION_DAYS);
        return { deletedCount };
    } catch (err) {
        return {
            deletedCount: 0,
            error: (err as Error).message
        };
    }
}

/**
 * Delete old unread articles that are very stale (beyond 90 days)
 * This prevents accumulation of articles user will never read
 */
export async function cleanupVeryOldUnreadArticles(userId: string): Promise<{
    deletedCount: number;
    error?: string;
}> {
    try {
        const supabase = createClient();
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - CLEANUP_CONFIG.UNREAD_RETENTION_DAYS);

        const { data, error } = await supabase
            .from('rss_articles')
            .delete()
            .eq('user_id', userId)
            .eq('is_read', false)
            .lt('pub_date', cutoffDate.toISOString())
            .select('id');

        if (error) throw new Error(error.message);
        return { deletedCount: data?.length || 0 };
    } catch (err) {
        return {
            deletedCount: 0,
            error: (err as Error).message
        };
    }
}

/**
 * Trim articles per feed to keep only the most recent N articles
 * This prevents individual feeds from bloating the database
 */
export async function trimArticlesPerFeed(
    userId: string,
    maxPerFeed: number = CLEANUP_CONFIG.MAX_ARTICLES_PER_FEED
): Promise<{
    deletedCount: number;
    error?: string;
}> {
    try {
        const supabase = createClient();

        // Get all feeds for user
        const { data: feeds, error: feedsError } = await supabase
            .from('rss_feeds')
            .select('id')
            .eq('user_id', userId);

        if (feedsError) throw new Error(feedsError.message);
        if (!feeds || feeds.length === 0) return { deletedCount: 0 };

        let totalDeleted = 0;

        // For each feed, keep only the most recent N articles
        for (const feed of feeds) {
            // Get articles beyond the limit (oldest first)
            const { data: articlesToDelete, error: articlesError } = await supabase
                .from('rss_articles')
                .select('id')
                .eq('user_id', userId)
                .eq('feed_id', feed.id)
                .order('pub_date', { ascending: false })
                .range(maxPerFeed, 999999); // Get everything beyond the limit

            if (articlesError) continue; // Skip this feed on error
            if (!articlesToDelete || articlesToDelete.length === 0) continue;

            // Delete the excess articles
            const articleIds = articlesToDelete.map(a => a.id);
            const { error: deleteError } = await supabase
                .from('rss_articles')
                .delete()
                .in('id', articleIds);

            if (!deleteError) {
                totalDeleted += articleIds.length;
            }
        }

        return { deletedCount: totalDeleted };
    } catch (err) {
        return {
            deletedCount: 0,
            error: (err as Error).message
        };
    }
}

/**
 * Run all cleanup operations
 * This is the main function to call periodically (e.g., daily via cron job)
 */
export async function runFullCleanup(userId: string): Promise<{
    totalDeleted: number;
    details: {
        oldRead: number;
        oldUnread: number;
        trimmed: number;
    };
    errors: string[];
}> {
    const errors: string[] = [];
    const details = {
        oldRead: 0,
        oldUnread: 0,
        trimmed: 0
    };

    // Cleanup old read articles
    const readResult = await cleanupOldReadArticles(userId);
    if (readResult.error) errors.push(`Old read: ${readResult.error}`);
    else details.oldRead = readResult.deletedCount;

    // Cleanup very old unread articles
    const unreadResult = await cleanupVeryOldUnreadArticles(userId);
    if (unreadResult.error) errors.push(`Old unread: ${unreadResult.error}`);
    else details.oldUnread = unreadResult.deletedCount;

    // Trim articles per feed
    const trimResult = await trimArticlesPerFeed(userId);
    if (trimResult.error) errors.push(`Trim: ${trimResult.error}`);
    else details.trimmed = trimResult.deletedCount;

    return {
        totalDeleted: details.oldRead + details.oldUnread + details.trimmed,
        details,
        errors
    };
}

/**
 * Get cleanup statistics without actually deleting
 * Useful for showing users how much will be cleaned up
 */
export async function getCleanupStats(userId: string): Promise<{
    oldReadCount: number;
    oldUnreadCount: number;
    totalArticles: number;
    error?: string;
}> {
    try {
        const supabase = createClient();

        // Count old read articles
        const readCutoff = new Date();
        readCutoff.setDate(readCutoff.getDate() - CLEANUP_CONFIG.READ_RETENTION_DAYS);

        const { count: oldReadCount } = await supabase
            .from('rss_articles')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', userId)
            .eq('is_read', true)
            .lt('pub_date', readCutoff.toISOString());

        // Count very old unread articles
        const unreadCutoff = new Date();
        unreadCutoff.setDate(unreadCutoff.getDate() - CLEANUP_CONFIG.UNREAD_RETENTION_DAYS);

        const { count: oldUnreadCount } = await supabase
            .from('rss_articles')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', userId)
            .eq('is_read', false)
            .lt('pub_date', unreadCutoff.toISOString());

        // Count total articles
        const { count: totalArticles } = await supabase
            .from('rss_articles')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', userId);

        return {
            oldReadCount: oldReadCount || 0,
            oldUnreadCount: oldUnreadCount || 0,
            totalArticles: totalArticles || 0
        };
    } catch (err) {
        return {
            oldReadCount: 0,
            oldUnreadCount: 0,
            totalArticles: 0,
            error: (err as Error).message
        };
    }
}
