'use client';

import { useState, useEffect } from 'react';
import { FeedData, FeedItem } from '@/lib/rssService';
import { parseArticle, saveArticle } from '@/lib/api';
import ReaderModal from './ReaderModal';

interface FeedListProps {
  feedUrl: string | null;
  userId: string;
}

export default function FeedList({ feedUrl, userId }: FeedListProps) {
  const [items, setItems] = useState<FeedItem[]>([]);
  const [feedTitle, setFeedTitle] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  
  // Reader Modal State
  const [readerUrl, setReaderUrl] = useState<string | null>(null);
  const [isReaderOpen, setIsReaderOpen] = useState(false);

  useEffect(() => {
    if (!feedUrl) {
        setItems([]);
        setFeedTitle('Select a feed to read');
        return;
    }

    const loadFeed = async () => {
        setLoading(true);
        setError(null);
        try {
            const { getFeedContent } = await import('@/app/actions/rss');
            const data = await getFeedContent(feedUrl);
            
            if (data.error) throw new Error(data.error);
            if (data.feed) {
                setFeedTitle(data.feed.title || 'Untitled Feed');
                setItems(data.feed.items);
            }
        } catch (err) {
            setError((err as Error).message);
        } finally {
            setLoading(false);
        }
    };

    loadFeed();
  }, [feedUrl]);

  const handleSaveToLibrary = async (item: FeedItem) => {
      if (!item.link) return;
      setSavingId(item.link);
      
      try {
          const parsed = await parseArticle(item.link);
          
          await saveArticle({
              url: item.link,
              title: parsed.title || item.title || 'Untitled',
              content: parsed.content || item.content || '',
              excerpt: parsed.excerpt || item.contentSnippet || null,
              lead_image_url: parsed.lead_image_url || null,
              author: parsed.author || item.author || null,
              date_published: parsed.date_published || item.pubDate || null,
              word_count: parsed.word_count || 0
          }, userId);

      } catch (err) {
          console.error('Failed to save', err);
          alert('Failed to save article to library');
      } finally {
          setSavingId(null);
      }
  };

  const handleRead = (link?: string) => {
      if (!link) return;
      setReaderUrl(link);
      setIsReaderOpen(true);
  };

  if (loading) {
      return <div className="p-8 text-center text-gray-500">Loading feed...</div>;
  }

  if (error) {
      return <div className="p-8 text-center text-red-500">Error: {error}</div>;
  }

  if (!feedUrl) {
      return <div className="p-8 text-center text-gray-500 text-lg">Select a feed to start reading</div>;
  }

  return (
    <div className="flex-1 overflow-y-auto bg-white/50 p-4 sm:p-8">
      <h1 className="text-2xl font-bold mb-6 text-gray-800 border-b pb-4">{feedTitle}</h1>
      <div className="space-y-6 max-w-4xl mx-auto">
          {items.map((item, idx) => (
              <div key={idx} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow border border-gray-100">
                  <div className="flex justify-between items-start gap-4">
                      <div>
                          <div 
                              onClick={() => handleRead(item.link)}
                              className="text-xl font-semibold text-gray-900 hover:text-indigo-600 mb-2 block cursor-pointer"
                          >
                              {item.title}
                          </div>
                          <div className="text-sm text-gray-500 mb-4 flex gap-3">
                              {item.author && <span>{item.author}</span>}
                              {item.pubDate && <span>{new Date(item.pubDate).toLocaleDateString()}</span>}
                              {item.isoDate && <span>{new Date(item.isoDate).toLocaleDateString()}</span>}
                          </div>
                          <div className="text-gray-600 leading-relaxed mb-4 line-clamp-3">
                              {item.contentSnippet || item.content?.replace(/<[^>]*>?/gm, '').substring(0, 300) + '...'}
                          </div>
                      </div>
                  </div>
                  
                  <div className="flex gap-3 mt-4 pt-4 border-t border-gray-50">
                      <button 
                        onClick={() => handleRead(item.link)}
                        className="px-4 py-2 bg-indigo-50 text-indigo-700 rounded-lg hover:bg-indigo-100 text-sm font-medium transition-colors"
                      >
                          Read Now
                      </button>
                      
                      {/* Shortcut to save without reading */}
                      <button 
                        onClick={() => handleSaveToLibrary(item)}
                        disabled={savingId === item.link}
                        className="px-4 py-2 bg-white border border-gray-200 text-gray-700 rounded-lg hover:bg-gray-50 text-sm font-medium transition-colors shadow-sm disabled:opacity-70 flex items-center gap-2"
                      >
                          {savingId === item.link ? (
                              <>
                                <svg className="animate-spin h-4 w-4 text-gray-500" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                                Saving...
                              </>
                          ) : (
                              <>
                                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" /></svg>
                                Save for Later
                              </>
                          )}
                      </button>
                      
                      <a 
                          href={item.link} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="px-4 py-2 text-gray-400 hover:text-gray-600 rounded-lg text-sm font-medium transition-colors ml-auto"
                          title="Open original link"
                      >
                          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                          </svg>
                      </a>
                  </div>
              </div>
          ))}
      </div>
      
      <ReaderModal 
          isOpen={isReaderOpen}
          onClose={() => setIsReaderOpen(false)}
          url={readerUrl}
          userId={userId}
      />
    </div>
  );
}
