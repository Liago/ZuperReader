'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { addFeed, createFolder } from '@/app/actions/rss';

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

interface RSSSidebarProps {
  folders: Folder[];
  feeds: Feed[];
  selectedFeedId?: string;
  onSelectFeed: (feed: Feed | null) => void;
  onOpenImportModal: () => void;
  onOpenDiscoveryModal: () => void;
}

export default function RSSSidebar({ folders, feeds, selectedFeedId, onSelectFeed, onOpenImportModal, onOpenDiscoveryModal }: RSSSidebarProps) {
  const router = useRouter();
  const [newFolderMode, setNewFolderMode] = useState(false);
  const [newFolderName, setNewFolderName] = useState('');
  const [newFeedMode, setNewFeedMode] = useState(false);
  const [newFeedUrl, setNewFeedUrl] = useState('');
  const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);

  // Group feeds by folder
  const feedsByFolder = feeds.reduce((acc, feed) => {
    const key = feed.folder_id || 'uncategorized';
    if (!acc[key]) acc[key] = [];
    acc[key].push(feed);
    return acc;
  }, {} as Record<string, Feed[]>);

  const handleCreateFolder = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFolderName.trim()) return;
    const result = await createFolder(newFolderName);
    if (result.error) {
      alert(`Failed to create folder: ${result.error}`);
      return;
    }
    setNewFolderName('');
    setNewFolderMode(false);
    router.refresh(); // Refresh to show the new folder
  };

  const handleAddFeed = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFeedUrl.trim()) return;
    const result = await addFeed(newFeedUrl, selectedFolderId);
    if (result.error) {
      alert(`Failed to add feed: ${result.error}`);
      return;
    }
    setNewFeedUrl('');
    setNewFeedMode(false);
    setSelectedFolderId(null);
    router.refresh(); // Refresh to show the new feed
  };

  return (
    <div className="w-full md:w-80 bg-white/60 backdrop-blur-sm border-r border-gray-100 h-full flex flex-col shadow-sm">
      <div className="p-5 border-b border-gray-100">
        <h2 className="text-2xl font-bold flex items-center gap-3 mb-1">
            <div className="w-10 h-10 bg-gradient-to-br from-orange-500 to-pink-500 rounded-xl flex items-center justify-center">
              <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M5 3a1 1 0 000 2c5.523 0 10 4.477 10 10a1 1 0 102 0C17 8.373 11.627 3 5 3z" />
                  <path d="M5 9a1 1 0 000 2 4.002 4.002 0 014 4 1 1 0 102 0 6.002 6.002 0 00-6-6z" />
                  <path d="M5 15a1 1 0 100 2 1 1 0 000-2z" />
              </svg>
            </div>
            <span className="bg-gradient-to-r from-orange-600 via-pink-600 to-purple-600 bg-clip-text text-transparent">
              RSS Reader
            </span>
        </h2>
        <p className="text-sm text-gray-500 ml-13 mb-4">Manage your feeds</p>

        <div className="grid grid-cols-2 gap-2">
            <button
                onClick={() => setNewFeedMode(true)}
                className="flex items-center justify-center gap-1.5 text-xs px-3 py-2 bg-gradient-to-r from-orange-500 to-pink-500 text-white rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-200 font-medium"
            >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                Feed
            </button>
            <button
                onClick={() => setNewFolderMode(true)}
                className="flex items-center justify-center gap-1.5 text-xs px-3 py-2 bg-white/80 text-gray-700 rounded-xl hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200 font-medium"
            >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                </svg>
                Folder
            </button>
            <button
                onClick={onOpenDiscoveryModal}
                className="flex items-center justify-center gap-1.5 text-xs px-3 py-2 bg-gradient-to-r from-purple-100 to-pink-100 text-purple-700 rounded-xl hover:from-purple-200 hover:to-pink-200 hover:shadow-md transition-all duration-200 font-medium"
                title="Discover RSS Feeds"
            >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                Discover
            </button>
             <button
                onClick={onOpenImportModal}
                className="flex items-center justify-center gap-1.5 text-xs px-3 py-2 bg-white/80 text-gray-700 rounded-xl hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200 font-medium"
                title="Import OPML"
            >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
                Import
            </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-3">
        {/* Create Folder Form */}
        {newFolderMode && (
             <form onSubmit={handleCreateFolder} className="mb-3 p-3 bg-gradient-to-br from-purple-50 to-pink-50 rounded-xl border border-purple-100">
                 <input
                    type="text"
                    value={newFolderName}
                    onChange={e => setNewFolderName(e.target.value)}
                    placeholder="Folder Name"
                    className="w-full text-sm border-2 border-purple-200 rounded-lg mb-2 px-3 py-2 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-200"
                    autoFocus
                 />
                 <div className="flex justify-end gap-2">
                     <button type="button" onClick={() => setNewFolderMode(false)} className="text-xs px-3 py-1.5 text-gray-600 hover:text-gray-800 font-medium">Cancel</button>
                     <button type="submit" className="text-xs px-3 py-1.5 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-lg font-medium hover:shadow-md transition-all">Create</button>
                 </div>
             </form>
        )}

        {/* Add Feed Form */}
        {newFeedMode && (
             <form onSubmit={handleAddFeed} className="mb-3 p-3 bg-gradient-to-br from-orange-50 to-pink-50 rounded-xl border border-orange-100">
                 <input
                    type="url"
                    value={newFeedUrl}
                    onChange={e => setNewFeedUrl(e.target.value)}
                    placeholder="Feed URL (https://...)"
                    className="w-full text-sm border-2 border-orange-200 rounded-lg mb-2 px-3 py-2 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-200"
                    autoFocus
                 />
                  <select
                     value={selectedFolderId || ''}
                     onChange={e => setSelectedFolderId(e.target.value || null)}
                     className="w-full text-sm border-2 border-orange-200 rounded-lg mb-2 px-3 py-2 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-200"
                  >
                      <option value="">Uncategorized</option>
                      {folders.map(f => (
                          <option key={f.id} value={f.id}>{f.name}</option>
                      ))}
                  </select>
                 <div className="flex justify-end gap-2">
                     <button type="button" onClick={() => setNewFeedMode(false)} className="text-xs px-3 py-1.5 text-gray-600 hover:text-gray-800 font-medium">Cancel</button>
                     <button type="submit" className="text-xs px-3 py-1.5 bg-gradient-to-r from-orange-500 to-pink-500 text-white rounded-lg font-medium hover:shadow-md transition-all">Add</button>
                 </div>
             </form>
        )}

        {/* All Feeds Link */}
        <div
             onClick={() => onSelectFeed(null)}
             className={`cursor-pointer px-3 py-2.5 rounded-xl text-sm font-semibold mb-3 flex items-center gap-2 transition-all ${!selectedFeedId ? 'bg-gradient-to-r from-orange-500 to-pink-500 text-white shadow-lg' : 'text-gray-700 hover:bg-white/80 border border-transparent hover:border-gray-200'}`}
        >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
               <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            All Articles
        </div>

        {/* Folders */}
        {folders.map(folder => (
            <div key={folder.id} className="mb-3">
                <div className="px-3 py-2 text-xs font-bold text-gray-600 uppercase tracking-wider flex justify-between items-center group rounded-lg hover:bg-purple-50/50">
                    <span className="flex items-center gap-2">
                      <svg className="w-4 h-4 text-purple-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                      </svg>
                      {folder.name}
                    </span>
                    <button
                        onClick={() => { setNewFeedMode(true); setSelectedFolderId(folder.id); }}
                        className="opacity-0 group-hover:opacity-100 text-purple-600 hover:text-purple-800 w-5 h-5 flex items-center justify-center rounded hover:bg-purple-100 transition-all"
                        title="Add feed to folder"
                    >
                        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                        </svg>
                    </button>
                </div>
                <div className="mt-1">
                    {feedsByFolder[folder.id]?.map(feed => (
                        <div
                            key={feed.id}
                            onClick={() => onSelectFeed(feed)}
                            className={`cursor-pointer px-3 py-2 rounded-lg text-sm mb-1 ml-2 flex items-center gap-2 truncate transition-all ${selectedFeedId === feed.id ? 'bg-gradient-to-r from-orange-100 to-pink-100 text-orange-700 font-semibold shadow-sm' : 'text-gray-600 hover:bg-white/80 hover:shadow-sm'}`}
                        >
                            <img src={`https://www.google.com/s2/favicons?domain=${new URL(feed.url).hostname}`} className="w-4 h-4 flex-shrink-0" alt="" />
                            <span className="truncate">{feed.title || feed.url}</span>
                        </div>
                    ))}
                    {(!feedsByFolder[folder.id] || feedsByFolder[folder.id].length === 0) && (
                        <div className="px-3 py-2 text-xs text-gray-400 ml-2 italic">No feeds yet</div>
                    )}
                </div>
            </div>
        ))}

        {/* Uncategorized */}
        {feedsByFolder['uncategorized'] && feedsByFolder['uncategorized'].length > 0 && (
            <div className="mb-3">
                <div className="px-3 py-2 text-xs font-bold text-gray-600 uppercase tracking-wider flex items-center gap-2 rounded-lg">
                    <svg className="w-4 h-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                    </svg>
                    Uncategorized
                </div>
                <div className="mt-1">
                    {feedsByFolder['uncategorized'].map(feed => (
                        <div
                            key={feed.id}
                            onClick={() => onSelectFeed(feed)}
                            className={`cursor-pointer px-3 py-2 rounded-lg text-sm mb-1 ml-2 flex items-center gap-2 truncate transition-all ${selectedFeedId === feed.id ? 'bg-gradient-to-r from-orange-100 to-pink-100 text-orange-700 font-semibold shadow-sm' : 'text-gray-600 hover:bg-white/80 hover:shadow-sm'}`}
                        >
                             <img src={`https://www.google.com/s2/favicons?domain=${new URL(feed.url).hostname}`} className="w-4 h-4 flex-shrink-0" alt="" />
                            <span className="truncate">{feed.title || feed.url}</span>
                        </div>
                    ))}
                </div>
            </div>
        )}
      </div>
    </div>
  );
}
