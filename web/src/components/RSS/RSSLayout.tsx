'use client';

import { useState } from 'react';
import RSSSidebar from './RSSSidebar';
import FeedList from './FeedList';
import ImportModal from './ImportModal';
import DiscoveryModal from './DiscoveryModal';

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
}

export default function RSSLayout({ initialFolders, initialFeeds, userId }: RSSLayoutProps) {
  const [selectedFeed, setSelectedFeed] = useState<Feed | null>(null);
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

  return (
    <>
      <div className="flex h-[calc(100vh-73px)] overflow-hidden">
          {/* Sidebar */}
          <RSSSidebar
              folders={initialFolders}
              feeds={initialFeeds}
              selectedFeedId={selectedFeed?.id}
              onSelectFeed={setSelectedFeed}
              onOpenImportModal={() => setShowImportModal(true)}
              onOpenDiscoveryModal={() => setShowDiscoveryModal(true)}
          />

          {/* Main Content */}
          <div className="flex-1 flex flex-col h-full overflow-hidden">
              <FeedList
                  feedUrl={selectedFeed?.url || null}
                  feedId={selectedFeed?.id || null}
                  userId={userId}
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
