'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { FeedData, FeedItem } from '@/lib/rssService';
import { parseArticle, saveArticle, getRSSArticles, markRSSArticleAsRead } from '@/lib/api';
import type { RSSArticle } from '@/lib/supabase';
import ReaderModal from './ReaderModal';

interface FeedListProps {
  feedUrl: string | null;
  feedId: string | null;
  userId: string;
}

export default function FeedList({ feedUrl, feedId, userId }: FeedListProps) {
  const [items, setItems] = useState<FeedItem[]>([]);
  const [feedTitle, setFeedTitle] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [rssArticles, setRssArticles] = useState<RSSArticle[]>([]);

  // Reader Modal State
  const [readerUrl, setReaderUrl] = useState<string | null>(null);
  const [isReaderOpen, setIsReaderOpen] = useState(false);

  useEffect(() => {
    if (!feedUrl) {
        setItems([]);
        setFeedTitle('Select a feed to read');
        setRssArticles([]);
        return;
    }

    const loadFeed = async () => {
        setLoading(true);
        setError(null);
        try {
            const { getFeedContent } = await import('@/app/actions/rss');
            // Pass feedId to sync articles to database
            const data = await getFeedContent(feedUrl, feedId || undefined);

            if (data.error) throw new Error(data.error);
            if (data.feed) {
                setFeedTitle(data.feed.title || 'Untitled Feed');
                setItems(data.feed.items);
            }

            // Load tracked articles from database
            if (feedId) {
                const trackedArticles = await getRSSArticles(userId, feedId);
                setRssArticles(trackedArticles);
            }
        } catch (err) {
            setError((err as Error).message);
        } finally {
            setLoading(false);
        }
    };

    loadFeed();
  }, [feedUrl, feedId, userId]);

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

  // Mark an article as read (extracted to reusable function)
  const markArticleAsRead = useCallback(async (item: FeedItem) => {
      if (!feedId) return;

      const articleGuid = item.guid || item.link || item.title;
      const trackedArticle = rssArticles.find(a => a.guid === articleGuid);

      if (trackedArticle && !trackedArticle.is_read) {
          try {
              await markRSSArticleAsRead(trackedArticle.id, userId);
              // Update local state
              setRssArticles(prev => prev.map(a =>
                  a.id === trackedArticle.id ? { ...a, is_read: true, read_at: new Date().toISOString() } : a
              ));
          } catch (err) {
              console.error('Failed to mark article as read:', err);
          }
      }
  }, [feedId, rssArticles, userId]);

  const handleRead = async (item: FeedItem) => {
      if (!item.link) return;
      setReaderUrl(item.link);
      setIsReaderOpen(true);

      // Also mark as read when opening in modal
      await markArticleAsRead(item);
  };

  // Helper function to check if an article is read
  const isArticleRead = (item: FeedItem): boolean => {
      if (!feedId || rssArticles.length === 0) return false;
      const articleGuid = item.guid || item.link || item.title;
      const trackedArticle = rssArticles.find(a => a.guid === articleGuid);
      return trackedArticle?.is_read || false;
  };

  // Intersection Observer to mark articles as read when scrolled past
  useEffect(() => {
      if (!feedId || items.length === 0) return;

      const observerCallback: IntersectionObserverCallback = (entries) => {
          entries.forEach((entry) => {
              // Mark as read when article exits viewport from top (scrolling down)
              if (!entry.isIntersecting && entry.boundingClientRect.top < 0) {
                  const articleIndex = parseInt(entry.target.getAttribute('data-article-index') || '-1');
                  if (articleIndex >= 0 && articleIndex < items.length) {
                      const item = items[articleIndex];
                      // Debounce: only mark if article has been scrolled past completely
                      markArticleAsRead(item);
                  }
              }
          });
      };

      const observer = new IntersectionObserver(observerCallback, {
          root: null, // viewport
          rootMargin: '-80px 0px 0px 0px', // Trigger when article is 80px past top (after header)
          threshold: 0
      });

      // Observe all article elements
      const articleElements = document.querySelectorAll('[data-article-index]');
      articleElements.forEach(el => observer.observe(el));

      return () => {
          observer.disconnect();
      };
  }, [items, feedId, markArticleAsRead]);

  if (loading) {
      return (
        <div className="flex-1 p-8 flex items-center justify-center">
          <div className="flex flex-col items-center gap-4">
            <div className="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full animate-spin"></div>
            <p className="text-orange-600 font-medium">Loading feed...</p>
          </div>
        </div>
      );
  }

  if (error) {
      return (
        <div className="flex-1 p-8 flex items-center justify-center">
          <div className="bg-white/60 backdrop-blur-sm p-8 rounded-2xl shadow-lg text-center">
            <p className="text-red-600 font-semibold">Error: {error}</p>
          </div>
        </div>
      );
  }

  if (!feedUrl) {
      return (
        <div className="flex-1 p-8 flex items-center justify-center">
          <div className="text-center">
            <div className="w-20 h-20 mx-auto mb-4 bg-gradient-to-br from-orange-500 to-pink-500 rounded-2xl flex items-center justify-center">
              <svg className="w-12 h-12 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path d="M5 3a1 1 0 000 2c5.523 0 10 4.477 10 10a1 1 0 102 0C17 8.373 11.627 3 5 3z" />
                <path d="M5 9a1 1 0 000 2 4.002 4.002 0 014 4 1 1 0 102 0 6.002 6.002 0 00-6-6z" />
                <path d="M5 15a1 1 0 100 2 1 1 0 000-2z" />
              </svg>
            </div>
            <p className="text-2xl font-bold bg-gradient-to-r from-orange-600 via-pink-600 to-purple-600 bg-clip-text text-transparent">Select a feed to start reading</p>
          </div>
        </div>
      );
  }

  return (
    <div className="flex-1 overflow-y-auto p-4 sm:p-8">
      <h1 className="text-3xl font-bold mb-6 bg-gradient-to-r from-orange-600 via-pink-600 to-purple-600 bg-clip-text text-transparent border-b border-gray-200 pb-4">{feedTitle}</h1>
      <div className="space-y-4 max-w-4xl mx-auto">
          {items.map((item, idx) => {
              const isRead = isArticleRead(item);
              return (
              <div
                  key={idx}
                  data-article-index={idx}
                  className={`bg-white/60 backdrop-blur-sm p-6 rounded-2xl shadow-sm hover:shadow-lg transition-all border border-gray-100 hover:border-orange-200 ${isRead ? 'opacity-60' : ''}`}
              >
                  <div className="flex justify-between items-start gap-4">
                      <div className="flex-1">
                          <div className="flex items-start gap-2 mb-2">
                              <div
                                  onClick={() => handleRead(item)}
                                  className={`text-xl font-bold flex-1 hover:bg-gradient-to-r hover:from-orange-600 hover:to-pink-600 hover:bg-clip-text hover:text-transparent cursor-pointer transition-all ${isRead ? 'text-gray-500' : 'text-gray-900'}`}
                              >
                                  {item.title}
                              </div>
                              {isRead && (
                                  <span className="flex-shrink-0 text-xs bg-gray-100 text-gray-500 px-2 py-1 rounded-full font-medium">
                                      Read
                                  </span>
                              )}
                          </div>
                          <div className="text-sm text-gray-500 mb-4 flex gap-3 items-center">
                              {item.author && (
                                <span className="flex items-center gap-1">
                                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                                  </svg>
                                  {item.author}
                                </span>
                              )}
                              {(item.pubDate || item.isoDate) && (
                                <span className="flex items-center gap-1">
                                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                  {new Date(item.pubDate || item.isoDate!).toLocaleDateString()}
                                </span>
                              )}
                          </div>
                          <div className="text-gray-600 leading-relaxed mb-4 line-clamp-3">
                              {item.contentSnippet || item.content?.replace(/<[^>]*>?/gm, '').substring(0, 300) + '...'}
                          </div>
                      </div>
                  </div>

                  <div className="flex flex-wrap gap-2 mt-4 pt-4 border-t border-gray-100">
                      <button
                        onClick={() => handleRead(item)}
                        className="px-4 py-2 bg-gradient-to-r from-orange-500 to-pink-500 text-white rounded-xl hover:shadow-lg hover:scale-105 text-sm font-semibold transition-all"
                      >
                          Read Now
                      </button>

                      {/* Shortcut to save without reading */}
                      <button
                        onClick={() => handleSaveToLibrary(item)}
                        disabled={savingId === item.link}
                        className="px-4 py-2 bg-white/80 border border-gray-200 text-gray-700 rounded-xl hover:bg-white hover:shadow-md text-sm font-medium transition-all disabled:opacity-70 flex items-center gap-2"
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
                          className="px-4 py-2 text-gray-400 hover:text-gray-600 rounded-xl text-sm font-medium transition-colors ml-auto flex items-center gap-1"
                          title="Open original link"
                      >
                          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                          </svg>
                      </a>
                  </div>
              </div>
          );
          })}
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
