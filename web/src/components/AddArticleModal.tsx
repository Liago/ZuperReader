'use client';

import { useState, useEffect } from 'react';
import { parseArticle, saveArticle } from '../lib/api';

interface AddArticleModalProps {
	isOpen: boolean;
	onClose: () => void;
	userId: string;
	onArticleAdded: () => void;
}

export default function AddArticleModal({ isOpen, onClose, userId, onArticleAdded }: AddArticleModalProps) {
	const [url, setUrl] = useState('');
	const [loading, setLoading] = useState(false);
	const [parsingStep, setParsingStep] = useState<'idle' | 'parsing' | 'saving'>('idle');
	const [error, setError] = useState('');
	const [clipboardUrl, setClipboardUrl] = useState<string | null>(null);
	const [showClipboardPrompt, setShowClipboardPrompt] = useState(false);

	// Check clipboard when modal opens
	useEffect(() => {
		if (isOpen) {
			checkClipboard();
		} else {
			setClipboardUrl(null);
			setShowClipboardPrompt(false);
		}
	}, [isOpen]);

	const checkClipboard = async () => {
		try {
			const text = await navigator.clipboard.readText();
			// Check if it's a URL
			if (text && (text.startsWith('http://') || text.startsWith('https://'))) {
				setClipboardUrl(text);
				setShowClipboardPrompt(true);
			}
		} catch (err) {
			// Permission denied or clipboard not available
			console.log('Clipboard access denied:', err);
		}
	};

	const handlePasteFromClipboard = async () => {
		try {
			const text = await navigator.clipboard.readText();
			if (text && (text.startsWith('http://') || text.startsWith('https://'))) {
				setUrl(text);
				setShowClipboardPrompt(false);
			} else {
				setError('No valid URL found in clipboard');
			}
		} catch (err) {
			setError('Unable to read from clipboard. Please allow clipboard access.');
		}
	};

	const handleUseClipboardUrl = () => {
		if (clipboardUrl) {
			setUrl(clipboardUrl);
			setShowClipboardPrompt(false);
		}
	};

	const handleDismissClipboardPrompt = () => {
		setShowClipboardPrompt(false);
		setClipboardUrl(null);
	};

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');
		setParsingStep('parsing');

		try {
			// Step 1: Parse the URL using Netlify Function
			const parsedData = await parseArticle(url);

			// Step 2: Save to Supabase
			setParsingStep('saving');
			await saveArticle(parsedData, userId);

			setUrl('');
			setParsingStep('idle');
			onArticleAdded();
			onClose();
		} catch (err) {
			setError(err instanceof Error ? err.message : 'Failed to add article. Please try again.');
			setParsingStep('idle');
		} finally {
			setLoading(false);
		}
	};

	const handleClose = () => {
		if (!loading) {
			setUrl('');
			setError('');
			setParsingStep('idle');
			onClose();
		}
	};

	if (!isOpen) return null;

	return (
		<div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
			<div
				className="bg-white rounded-2xl shadow-2xl max-w-lg w-full transform transition-all"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header */}
				<div className="flex items-center justify-between p-5 border-b border-gray-100">
					<div className="flex items-center gap-3">
						<div className="w-10 h-10 bg-gradient-to-br from-purple-500 to-pink-500 rounded-xl flex items-center justify-center">
							<svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
							</svg>
						</div>
						<div>
							<h2 className="text-xl font-bold text-gray-900">Add New Article</h2>
							<p className="text-sm text-gray-500">Save an article to your library</p>
						</div>
					</div>
					<button
						onClick={handleClose}
						disabled={loading}
						className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors disabled:opacity-50"
					>
						<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				{/* Content */}
				<form onSubmit={handleSubmit} className="p-5">
					<div className="relative">
						<label htmlFor="article-url" className="flex items-center justify-between text-sm font-medium text-gray-700 mb-2">
							<span>Article URL</span>
							<button
								type="button"
								onClick={handlePasteFromClipboard}
								disabled={loading}
								className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-purple-600 bg-purple-50 rounded-lg hover:bg-purple-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
							>
								<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
								</svg>
								Paste from Clipboard
							</button>
						</label>
						<div className="relative">
							<div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
								<svg className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
								</svg>
							</div>
							<input
								id="article-url"
								type="url"
								value={url}
								onChange={(e) => setUrl(e.target.value)}
								placeholder="https://example.com/article"
								required
								disabled={loading}
								className="w-full pl-10 pr-10 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-200 text-gray-900 placeholder-gray-400 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
							/>
							{url && !loading && (
								<button
									type="button"
									onClick={() => setUrl('')}
									className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
								>
									<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							)}
						</div>
					</div>

					{/* Clipboard prompt */}
					{showClipboardPrompt && clipboardUrl && (
						<div className="mt-4 p-4 bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-xl">
							<div className="flex items-start gap-3">
								<div className="flex-shrink-0 mt-0.5">
									<svg className="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
									</svg>
								</div>
								<div className="flex-1 min-w-0">
									<p className="text-sm font-medium text-blue-900 mb-1">Link found in clipboard</p>
									<p className="text-xs text-blue-700 break-all mb-3">{clipboardUrl}</p>
									<div className="flex gap-2">
										<button
											type="button"
											onClick={handleUseClipboardUrl}
											className="px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors"
										>
											Use this link
										</button>
										<button
											type="button"
											onClick={handleDismissClipboardPrompt}
											className="px-3 py-1.5 text-sm font-medium text-blue-600 bg-white rounded-lg hover:bg-blue-50 transition-colors"
										>
											Dismiss
										</button>
									</div>
								</div>
							</div>
						</div>
					)}

					{/* Loading progress indicator */}
					{loading && (
						<div className="mt-4 p-4 bg-gradient-to-r from-purple-50 to-pink-50 rounded-xl border border-purple-100">
							<div className="flex items-center gap-3">
								<div className="flex-shrink-0">
									<div className="w-8 h-8 border-3 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
								</div>
								<div className="flex-1">
									<p className="text-sm font-medium text-purple-900">
										{parsingStep === 'parsing' && 'Parsing article content...'}
										{parsingStep === 'saving' && 'Saving to your library...'}
									</p>
									<div className="mt-2 h-1.5 bg-purple-200 rounded-full overflow-hidden">
										<div
											className="h-full bg-gradient-to-r from-purple-600 to-pink-600 rounded-full transition-all duration-500"
											style={{ width: parsingStep === 'parsing' ? '40%' : '80%' }}
										></div>
									</div>
								</div>
							</div>
						</div>
					)}

					{/* Error message */}
					{error && (
						<div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3">
							<svg className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							<div className="flex-1">
								<p className="text-sm font-medium text-red-800">{error}</p>
							</div>
							<button
								type="button"
								onClick={() => setError('')}
								className="text-red-400 hover:text-red-600 transition-colors"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
								</svg>
							</button>
						</div>
					)}

					{/* Actions */}
					<div className="mt-6 flex gap-3 justify-end">
						<button
							type="button"
							onClick={handleClose}
							disabled={loading}
							className="px-4 py-2.5 bg-gray-100 text-gray-700 font-medium rounded-xl hover:bg-gray-200 transition-colors disabled:opacity-50"
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={loading || !url}
							className="relative px-6 py-2.5 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 text-white font-medium rounded-xl hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 overflow-hidden group"
						>
							{/* Shimmer effect */}
							<div className="absolute inset-0 -translate-x-full group-hover:translate-x-full transition-transform duration-1000 bg-gradient-to-r from-transparent via-white/20 to-transparent"></div>

							<span className="relative flex items-center justify-center gap-2">
								{loading ? (
									<>
										<svg className="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24">
											<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
											<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
										</svg>
										{parsingStep === 'parsing' ? 'Parsing...' : 'Saving...'}
									</>
								) : (
									<>
										<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
										</svg>
										Add Article
									</>
								)}
							</span>
						</button>
					</div>
				</form>
			</div>
		</div>
	);
}
