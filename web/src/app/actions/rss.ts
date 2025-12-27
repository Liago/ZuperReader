'use server';

import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { fetchFeed, parseOPML, OpmlOutline, FeedData } from '@/lib/rssService';

// ... existing imports ...

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
 */
export async function getFeedContent(url: string): Promise<{ feed?: FeedData; error?: string }> {
    try {
        const feed = await fetchFeed(url);
        return { feed };
    } catch (err) {
        return { error: (err as Error).message };
    }
}
