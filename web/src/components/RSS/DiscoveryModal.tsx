'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { discoverFeeds, addFeed, type DiscoveredFeed } from '@/app/actions/rss';

interface DiscoveryModalProps {
  isOpen: boolean;
  onClose: () => void;
  folders: Array<{ id: string; name: string }>;
}

export default function DiscoveryModal({ isOpen, onClose, folders }: DiscoveryModalProps) {
  const router = useRouter();
  const [searchUrl, setSearchUrl] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [discoveredFeeds, setDiscoveredFeeds] = useState<DiscoveredFeed[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedFolders, setSelectedFolders] = useState<{ [feedUrl: string]: string | null }>({});
  const [addingFeed, setAddingFeed] = useState<{ [feedUrl: string]: boolean }>({});
  const [addedFeeds, setAddedFeeds] = useState<Set<string>>(new Set());

  if (!isOpen) return null;

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchUrl.trim()) {
      setErrorMessage('Please enter a URL or domain.');
      return;
    }

    setIsSearching(true);
    setErrorMessage(null);
    setDiscoveredFeeds([]);
    setAddedFeeds(new Set());

    const result = await discoverFeeds(searchUrl);

    setIsSearching(false);

    if (result.error) {
      setErrorMessage(result.error);
    } else if (result.feeds) {
      setDiscoveredFeeds(result.feeds);
      // Initialize selected folders to null (uncategorized)
      const initialFolders: { [feedUrl: string]: string | null } = {};
      result.feeds.forEach(feed => {
        initialFolders[feed.url] = null;
      });
      setSelectedFolders(initialFolders);
    }
  };

  const handleAddFeed = async (feed: DiscoveredFeed) => {
    setAddingFeed({ ...addingFeed, [feed.url]: true });
    setErrorMessage(null);

    const folderId = selectedFolders[feed.url] || null;
    const result = await addFeed(feed.url, folderId);

    setAddingFeed({ ...addingFeed, [feed.url]: false });

    if (result.error) {
      setErrorMessage(result.error);
    } else {
      // Mark feed as added
      setAddedFeeds(new Set([...addedFeeds, feed.url]));
      router.refresh(); // Refresh to show the new feed in sidebar
    }
  };

  const handleFolderChange = (feedUrl: string, folderId: string) => {
    setSelectedFolders({
      ...selectedFolders,
      [feedUrl]: folderId === '' ? null : folderId,
    });
  };

  const handleClose = () => {
    setSearchUrl('');
    setDiscoveredFeeds([]);
    setErrorMessage(null);
    setSelectedFolders({});
    setAddingFeed({});
    setAddedFeeds(new Set());
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true" onClick={handleClose}></div>

        <span className="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div className="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full sm:p-6">
          <div>
            <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100">
              <svg className="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <div className="mt-3 text-center sm:mt-5">
              <h3 className="text-lg leading-6 font-medium text-gray-900" id="modal-title">Discover RSS Feeds</h3>
              <div className="mt-2 text-sm text-gray-500">
                <p>Enter a website URL or domain to discover available RSS/Atom feeds.</p>
              </div>
            </div>
          </div>

          <form onSubmit={handleSearch} className="mt-5 sm:mt-6">
            <div className="mb-4">
              <input
                type="text"
                value={searchUrl}
                onChange={(e) => setSearchUrl(e.target.value)}
                placeholder="e.g., example.com or https://example.com"
                className="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm px-4 py-2 border"
                disabled={isSearching}
              />
            </div>

            {errorMessage && (
              <div className="mb-4 text-sm text-red-600 bg-red-50 p-3 rounded-md">
                {errorMessage}
              </div>
            )}

            {discoveredFeeds.length > 0 && (
              <div className="mb-4 max-h-96 overflow-y-auto border border-gray-200 rounded-md">
                <div className="divide-y divide-gray-200">
                  {discoveredFeeds.map((feed) => {
                    const isAdded = addedFeeds.has(feed.url);
                    const isAdding = addingFeed[feed.url];

                    return (
                      <div key={feed.url} className="p-4 hover:bg-gray-50">
                        <div className="flex items-start justify-between gap-4">
                          <div className="flex-1 min-w-0">
                            <h4 className="text-sm font-medium text-gray-900 truncate">
                              {feed.title}
                            </h4>
                            <p className="text-xs text-gray-500 truncate mt-1">
                              {feed.url}
                            </p>
                            <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800 mt-2">
                              {feed.type.toUpperCase()}
                            </span>
                          </div>

                          <div className="flex items-center gap-2">
                            <select
                              value={selectedFolders[feed.url] || ''}
                              onChange={(e) => handleFolderChange(feed.url, e.target.value)}
                              className="text-xs border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                              disabled={isAdded || isAdding}
                            >
                              <option value="">Uncategorized</option>
                              {folders.map((folder) => (
                                <option key={folder.id} value={folder.id}>
                                  {folder.name}
                                </option>
                              ))}
                            </select>

                            <button
                              type="button"
                              onClick={() => handleAddFeed(feed)}
                              disabled={isAdded || isAdding}
                              className={`inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md shadow-sm text-white ${
                                isAdded
                                  ? 'bg-green-600 cursor-not-allowed'
                                  : 'bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
                              } disabled:opacity-50`}
                            >
                              {isAdding ? (
                                <>
                                  <svg className="animate-spin -ml-0.5 mr-1.5 h-3 w-3 text-white" fill="none" viewBox="0 0 24 24">
                                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                  </svg>
                                  Adding...
                                </>
                              ) : isAdded ? (
                                <>
                                  <svg className="-ml-0.5 mr-1.5 h-3 w-3" fill="currentColor" viewBox="0 0 20 20">
                                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                                  </svg>
                                  Added
                                </>
                              ) : (
                                'Add Feed'
                              )}
                            </button>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            <div className="flex gap-3">
              <button
                type="button"
                onClick={handleClose}
                className="w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:text-sm"
              >
                Close
              </button>
              <button
                type="submit"
                disabled={isSearching}
                className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:text-sm disabled:opacity-50"
              >
                {isSearching ? (
                  <>
                    <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Searching...
                  </>
                ) : (
                  'Discover Feeds'
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
