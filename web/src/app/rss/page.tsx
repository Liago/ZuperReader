'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import RSSLayout from '@/components/RSS/RSSLayout';

interface Feed {
  id: string;
  title: string | null;
  url: string;
  folder_id: string | null;
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
      try {
        setIsLoadingData(true);

        // Fetch Folders
        const { data: foldersData, error: foldersError } = await supabase
          .from('rss_folders')
          .select('*')
          .eq('user_id', user.id)
          .order('name');

        // Fetch Feeds
        const { data: feedsData, error: feedsError } = await supabase
          .from('rss_feeds')
          .select('*')
          .eq('user_id', user.id)
          .order('title');

        if (foldersError || feedsError) {
          console.error('Error fetching RSS data:', foldersError || feedsError);
          setError('Error loading RSS feeds. Please try again.');
          return;
        }

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
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
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
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <p className="text-red-600 mb-4">{error}</p>
          <Link href="/" className="text-purple-600 hover:text-purple-700 underline">
            Go back to home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col">
       {/* Simple Header for RSS Page to match app style or just a back link */}
       <header className="bg-white shadow-sm z-10 sticky top-0 md:relative">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
                 <div className="flex items-center gap-4">
                     <Link href="/" className="text-gray-500 hover:text-gray-700">
                        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                        </svg>
                     </Link>
                     <h1 className="text-xl font-bold text-gray-900">RSS Reader</h1>
                 </div>
                 {/* Could add user menu here if needed */}
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
