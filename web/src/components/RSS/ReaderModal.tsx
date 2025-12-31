'use client';

import { useState, useEffect, useCallback } from 'react';
import { parseArticle, saveArticle } from '@/lib/api';

interface ReaderModalProps {
  isOpen: boolean;
  onClose: () => void;
  url: string | null;
  userId: string;
  onNext?: () => void;
  onPrevious?: () => void;
  hasNext?: boolean;
  hasPrevious?: boolean;
}

export default function ReaderModal({ 
    isOpen, 
    onClose, 
    url, 
    userId,
    onNext,
    onPrevious,
    hasNext = false,
    hasPrevious = false
}: ReaderModalProps) {
  const [loading, setLoading] = useState(false);
  const [parsedContent, setParsedContent] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Handle keyboard navigation
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (!isOpen) return;
    
    // Only navigate if not typing in an input
    if (document.activeElement?.tagName === 'INPUT' || document.activeElement?.tagName === 'TEXTAREA') return;

    if (e.key === 'ArrowRight' && hasNext && onNext) {
        onNext();
    } else if (e.key === 'ArrowLeft' && hasPrevious && onPrevious) {
        onPrevious();
    }
  }, [isOpen, hasNext, hasPrevious, onNext, onPrevious]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  useEffect(() => {
    if (!isOpen || !url) {
        setParsedContent(null);
        setError(null);
        setSaveSuccess(false);
        return;
    }

    const loadContent = async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await parseArticle(url);
            setParsedContent(data);
        } catch (err) {
            setError((err as Error).message);
        } finally {
            setLoading(false);
        }
    };

    loadContent();
  }, [isOpen, url]);

  const handleSave = async () => {
    if (!parsedContent) return;

    setSaving(true);
    try {
        await saveArticle({
            url: parsedContent.url,
            title: parsedContent.title,
            content: parsedContent.content,
            excerpt: parsedContent.excerpt,
            lead_image_url: parsedContent.lead_image_url,
            author: parsedContent.author,
            date_published: parsedContent.date_published,
            word_count: parsedContent.word_count
        }, userId);
        setSaveSuccess(true);
        setTimeout(() => {
            onClose();
        }, 1500);
    } catch (err) {
        console.error(err);
        alert('Failed to save article.');
    } finally {
        setSaving(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      {/* Overlay */}
      <div className="absolute inset-0 bg-gray-900/75 backdrop-blur-sm transition-opacity" aria-hidden="true" onClick={onClose}></div>

      {/* Modal Content */}
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-4xl h-[85vh] flex flex-col z-10 transition-all">
            
            {/* Header / Actions */}
            <div className="bg-gradient-to-r from-orange-50 to-pink-50 px-4 py-3 sm:px-6 flex justify-between items-center border-b border-gray-200">
                <div className="flex items-center gap-3 overflow-hidden flex-1">
                    <button
                        onClick={onClose}
                        className="flex-shrink-0 p-1 rounded-full text-gray-500 hover:bg-white/60 hover:text-gray-900 transition-all"
                        title="Close"
                    >
                        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </button>
                    
                    {/* Navigation Buttons */}
                    <div className="flex items-center gap-1 border-l border-gray-300 pl-3 ml-1">
                        <button 
                            onClick={onPrevious}
                            disabled={!hasPrevious}
                            className="p-1.5 rounded-lg text-gray-500 hover:text-gray-900 hover:bg-white/60 disabled:opacity-30 disabled:cursor-not-allowed transition-all"
                            title="Previous Article (Left Arrow)"
                        >
                            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                            </svg>
                        </button>
                        <button 
                            onClick={onNext}
                            disabled={!hasNext}
                            className="p-1.5 rounded-lg text-gray-500 hover:text-gray-900 hover:bg-white/60 disabled:opacity-30 disabled:cursor-not-allowed transition-all"
                            title="Next Article (Right Arrow)"
                        >
                            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                            </svg>
                        </button>
                    </div>

                    {url && (
                        <a
                            href={url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="hidden sm:flex text-sm text-gray-600 truncate hover:text-orange-600 transition-colors items-center gap-1 ml-2 border-l border-gray-300 pl-3"
                            title={url}
                        >
                            <svg className="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                            </svg>
                            <span className="truncate max-w-[200px]">{url.replace(/^https?:\/\/(www\.)?/, '')}</span>
                        </a>
                    )}
                </div>

                <div className="flex items-center gap-2 flex-shrink-0">
                    {saveSuccess ? (
                         <span className="flex items-center gap-2 text-green-600 font-semibold px-4 py-2 bg-green-50 rounded-xl animate-scaleIn">
                             <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                             </svg>
                             Saved!
                         </span>
                    ) : (
                        <button
                            type="button"
                            onClick={handleSave}
                            disabled={loading || !parsedContent || saving}
                            className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-orange-500 to-pink-500 text-white font-semibold rounded-xl hover:shadow-lg hover:scale-105 transition-all disabled:opacity-50 disabled:hover:scale-100"
                        >
                            {saving ? (
                                <>
                                    <svg className="animate-spin h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                    </svg>
                                    Saving...
                                </>
                            ) : (
                                <>
                                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
                                    </svg>
                                    Save to Library
                                </>
                            )}
                        </button>
                    )}
                </div>
            </div>

            {/* Content Area */}
            <div className="flex-1 overflow-y-auto p-6 sm:p-10 bg-gradient-to-br from-orange-50/30 via-white to-pink-50/30">
                {loading && (
                     <div className="flex flex-col items-center justify-center h-full gap-4">
                        <div className="w-16 h-16 border-4 border-orange-200 border-t-orange-600 rounded-full animate-spin"></div>
                        <p className="text-orange-600 font-medium text-lg">Parsing article...</p>
                        <div className="flex gap-1">
                            <div className="w-2 h-2 bg-orange-600 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
                            <div className="w-2 h-2 bg-pink-600 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
                            <div className="w-2 h-2 bg-purple-600 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
                        </div>
                    </div>
                )}

                {error && (
                    <div className="flex flex-col items-center justify-center h-full text-center">
                        <div className="w-20 h-20 bg-red-100 rounded-2xl flex items-center justify-center mb-4">
                            <svg className="w-10 h-10 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                        </div>
                        <h3 className="text-2xl font-bold text-gray-900 mb-2">Failed to load content</h3>
                        <p className="text-gray-600 mb-6 max-w-md">{error}</p>
                        <a
                            href={url!}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-orange-500 to-pink-500 text-white font-semibold rounded-xl hover:shadow-lg hover:scale-105 transition-all"
                        >
                            Open in original site
                            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                            </svg>
                        </a>
                    </div>
                )}

                {!loading && parsedContent && (
                    <article className="prose lg:prose-xl mx-auto">
                        {parsedContent.lead_image_url && (
                            <img 
                                src={parsedContent.lead_image_url} 
                                alt={parsedContent.title}
                                className="w-full h-auto rounded-lg shadow-md mb-8 object-cover max-h-[500px]" 
                            />
                        )}
                        <h1 className="mb-4">{parsedContent.title}</h1>
                        <div className="flex gap-4 text-sm text-gray-500 mb-8 not-prose border-b pb-4">
                            {parsedContent.author && <span>By {parsedContent.author}</span>}
                            {parsedContent.date_published && <span>{new Date(parsedContent.date_published).toLocaleDateString()}</span>}
                            {parsedContent.domain && <span>{parsedContent.domain}</span>}
                            {parsedContent.word_count && <span>{parsedContent.word_count} words</span>}
                        </div>
                        
                        <div dangerouslySetInnerHTML={{ __html: parsedContent.content }} />
                    </article>
                )}
            </div>
        </div>
      </div>
  );
}
