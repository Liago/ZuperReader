'use client';

import { useState, useEffect } from 'react';
import { parseArticle, saveArticle } from '@/lib/api';

interface ReaderModalProps {
  isOpen: boolean;
  onClose: () => void;
  url: string | null;
  userId: string;
}

export default function ReaderModal({ isOpen, onClose, url, userId }: ReaderModalProps) {
  const [loading, setLoading] = useState(false);
  const [parsedContent, setParsedContent] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

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
    <div className="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <div className="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true" onClick={onClose}></div>

        <span className="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full h-[85vh] flex flex-col">
            
            {/* Header / Actions */}
            <div className="bg-gray-50 px-4 py-3 sm:px-6 flex justify-between items-center border-b border-gray-200">
                <div className="flex items-center gap-2 overflow-hidden">
                    <button 
                        onClick={onClose}
                        className="text-gray-400 hover:text-gray-500"
                    >
                        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </button>
                    {url && <a href={url} target="_blank" rel="noopener noreferrer" className="text-xs text-gray-500 truncate hover:underline max-w-xs sm:max-w-md">{url}</a>}
                </div>
                
                <div className="flex items-center gap-2">
                    {saveSuccess ? (
                         <span className="flex items-center gap-1 text-green-600 font-medium px-4 py-2">
                             <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                             </svg>
                             Saved!
                         </span>
                    ) : (
                        <button
                            type="button"
                            onClick={handleSave}
                            disabled={loading || !parsedContent}
                            className="inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:text-sm disabled:opacity-50"
                        >
                            {saving ? 'Saving...' : 'Save to Library'}
                        </button>
                    )}
                </div>
            </div>

            {/* Content Area */}
            <div className="flex-1 overflow-y-auto p-6 sm:p-10">
                {loading && (
                     <div className="flex flex-col items-center justify-center h-full">
                        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mb-4"></div>
                        <p className="text-gray-500">Parsing article...</p>
                    </div>
                )}
                
                {error && (
                    <div className="flex flex-col items-center justify-center h-full text-center">
                        <div className="text-red-500 text-xl mb-2">Failed to load content</div>
                        <p className="text-gray-500 mb-4">{error}</p>
                        <a href={url!} target="_blank" rel="noopener noreferrer" className="text-indigo-600 hover:underline">
                            Open in original site
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
    </div>
  );
}
