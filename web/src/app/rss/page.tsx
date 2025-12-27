import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import RSSLayout from '@/components/RSS/RSSLayout';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

export default async function RSSPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login');
  }

  // Fetch Folders
  const { data: folders, error: foldersError } = await supabase
    .from('rss_folders')
    .select('*')
    .eq('user_id', user.id)
    .order('name');

  // Fetch Feeds
  const { data: feeds, error: feedsError } = await supabase
    .from('rss_feeds')
    .select('*')
    .eq('user_id', user.id)
    .order('title');

  if (foldersError || feedsError) {
      console.error('Error fetching RSS data:', foldersError || feedsError);
      return <div>Error loading RSS feeds. Please try again.</div>;
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
                     <h1 className="text-xl font-bold text-gray-900">Reader</h1>
                 </div>
                 {/* Could add user menu here if needed */}
            </div>
       </header>

       <RSSLayout 
          initialFolders={folders || []} 
          initialFeeds={feeds || []} 
          userId={user.id} 
       />
    </div>
  );
}
