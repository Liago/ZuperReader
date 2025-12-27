'use client';

import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { importOPML } from '@/app/actions/rss';

interface ImportModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function ImportModal({ isOpen, onClose }: ImportModalProps) {
  const router = useRouter();
  const [isImporting, setIsImporting] = useState(false);
  const [resultMessage, setResultMessage] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  const handleImport = async (e: React.FormEvent) => {
    e.preventDefault();
    const file = fileInputRef.current?.files?.[0];
    if (!file) {
        setResultMessage('Please select a file.');
        return;
    }

    setIsImporting(true);
    setResultMessage(null);

    const formData = new FormData();
    formData.append('file', file);

    const result = await importOPML(formData);

    setIsImporting(false);
    if (result.error) {
        setResultMessage(`Error: ${result.error}`);
    } else {
        setResultMessage(result.message || 'Import successful!');
        router.refresh(); // Refresh to show imported feeds and folders
        setTimeout(() => {
            onClose();
            setResultMessage(null); // Reset for next time
        }, 2000);
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true" onClick={onClose}></div>

        <span className="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div className="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-sm sm:w-full sm:p-6">
          <div>
            <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100">
              <svg className="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
              </svg>
            </div>
            <div className="mt-3 text-center sm:mt-5">
              <h3 className="text-lg leading-6 font-medium text-gray-900" id="modal-title">Import OPML</h3>
              <div className="mt-2 text-sm text-gray-500">
                <p>Upload an OPML file exported from another feed reader (like Feedly) to import your subscriptions.</p>
              </div>
            </div>
          </div>
          
          <form onSubmit={handleImport} className="mt-5 sm:mt-6">
             <div className="mb-4">
                 <input 
                    type="file" 
                    accept=".opml,.xml"
                    ref={fileInputRef}
                    className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
                 />
             </div>

             {resultMessage && (
                 <div className={`mb-4 text-sm ${resultMessage.startsWith('Error') ? 'text-red-600' : 'text-green-600'}`}>
                     {resultMessage}
                 </div>
             )}

            <div className="flex gap-3">
                <button
                    type="button"
                    onClick={onClose}
                    className="w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:text-sm"
                >
                    Cancel
                </button>
                <button
                    type="submit"
                    disabled={isImporting}
                    className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:text-sm disabled:opacity-50"
                >
                    {isImporting ? 'Importing...' : 'Import'}
                </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
