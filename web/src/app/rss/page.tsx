'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { createClient } from '@/lib/supabase/client';
import { getRSSFeedsWithUnreadCounts } from '@/lib/api';
import RSSLayout from '@/components/RSS/RSSLayout';

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

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login');
    }
  }, [user, loading, router]);

  useEffect(() => {
    if (!user) return;

    async function fetchRSSData() {
      if (!user) return; // Guard against null user

      try {
        setIsLoadingData(true);
        const supabase = createClient();

        // Fetch Folders
        const { data: foldersData, error: foldersError } = await supabase
          .from('rss_folders')
          .select('*')
          .eq('user_id', user.id)
          .order('name');

        if (foldersError) {
          console.error('Error fetching RSS folders:', foldersError);
          setError('Error loading RSS feeds. Please try again.');
          return;
        }

        // Fetch Feeds with unread counts
        const feedsData = await getRSSFeedsWithUnreadCounts(user.id);

        setFolders(foldersData || []);
        setFeeds(feedsData || []);
      } catch (err) {
        console.error('Error fetching RSS data:', err);
        setError('Error loading RSS feeds. Please try again.');
      } finally {
        setIsLoadingData(false);
      }
    }

    fetchRSSData();
  }, [user]);

  if (loading || isLoadingData) {
    return (
      <div className="min-h-screen flex items-center justify-center app-bg-gradient">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full animate-spin"></div>
          <p className="text-orange-600 font-medium">Loading RSS Feeds...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return null; // Will redirect to login
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center app-bg-gradient">
        <div className="text-center bg-white/60 backdrop-blur-sm p-8 rounded-2xl shadow-lg">
          <p className="text-red-600 mb-4 font-semibold">{error}</p>
          <Link href="/" className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-medium rounded-xl hover:shadow-lg transition-all">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Go back to home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col app-bg-gradient">
       {/* Header */}
       <header className="bg-white/60 backdrop-blur-sm shadow-sm z-10 sticky top-0 border-b border-gray-100">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
                 <div className="flex items-center gap-4">
                     <Link href="/" className="flex items-center gap-2 px-3 py-2 bg-white/80 text-gray-700 hover:text-gray-900 font-medium rounded-xl hover:shadow-md transition-all border border-gray-200">
                        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                        </svg>
                        <span className="hidden sm:inline">SuperReader</span>
                     </Link>
                     <h1 className="text-2xl font-bold bg-gradient-to-r from-orange-600 via-pink-600 to-purple-600 bg-clip-text text-transparent">RSS Reader</h1>
                 </div>
            </div>
       </header>

       <RSSLayout
          initialFolders={folders}
          initialFeeds={feeds}
          userId={user.id}
       />
    </div>
  );
}
