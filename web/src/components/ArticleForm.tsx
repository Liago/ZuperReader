'use client';

import { useState } from 'react';
import { parseArticle, saveArticle } from '../lib/api';

interface ArticleFormProps {
	userId: string;
	onArticleAdded: () => void;
}

export default function ArticleForm({ userId, onArticleAdded }: ArticleFormProps) {
	const [url, setUrl] = useState('');
	const [loading, setLoading] = useState(false);
	const [parsingStep, setParsingStep] = useState<'idle' | 'parsing' | 'saving'>('idle');
	const [error, setError] = useState('');

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');
		setParsingStep('parsing');

		try {
			// Step 1: Parse the URL using Netlify Function
			const parsedData = await parseArticle(url, userId);

			// Step 2: Save to Supabase
			setParsingStep('saving');
			await saveArticle(parsedData, userId);

			setUrl('');
			onArticleAdded();
			setParsingStep('idle');
		} catch (err: any) {
			setError(err.message || 'Failed to add article. Please try again.');
			setParsingStep('idle');
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className="mb-8">
			<form onSubmit={handleSubmit} className="relative overflow-hidden bg-white/80 backdrop-blur-sm rounded-2xl shadow-lg border border-gray-200 p-5 sm:p-6">
				{/* Progress bar animato */}
				{loading && (
					<div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-purple-500 via-pink-500 to-blue-500 animate-pulse">
						<div className="h-full bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 animate-shimmer"></div>
					</div>
				)}

				<h2 className="text-xl sm:text-2xl font-bold mb-4 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent">
					Add New Article
				</h2>

				<div className="flex flex-col sm:flex-row gap-3 sm:gap-4">
					<div className="flex-1 relative">
						<input
							type="url"
							value={url}
							onChange={(e) => setUrl(e.target.value)}
							placeholder="Enter article URL (e.g., https://example.com/article)"
							required
							disabled={loading}
							className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-200 text-gray-900 placeholder-gray-400 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
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

					<button
						type="submit"
						disabled={loading}
						className="relative px-6 py-3 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 disabled:opacity-50 disabled:hover:scale-100 disabled:cursor-not-allowed transition-all duration-200 overflow-hidden group"
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
									<span className="hidden sm:inline">
										{parsingStep === 'parsing' ? 'Parsing...' : 'Saving...'}
									</span>
									<span className="sm:hidden">
										{parsingStep === 'parsing' ? 'Parsing' : 'Saving'}
									</span>
								</>
							) : (
								<>
									<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
									</svg>
									<span className="hidden sm:inline">Add Article</span>
									<span className="sm:hidden">Add</span>
								</>
							)}
						</span>
					</button>
				</div>

				{/* Loading progress indicator */}
				{loading && (
					<div className="mt-4 p-4 bg-gradient-to-r from-purple-50 to-pink-50 rounded-xl border border-purple-100">
						<div className="flex items-center gap-3">
							<div className="flex-shrink-0">
								<div className="w-8 h-8 border-3 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
							</div>
							<div className="flex-1">
								<p className="text-sm font-medium text-purple-900">
									{parsingStep === 'parsing' && '🔍 Parsing article content...'}
									{parsingStep === 'saving' && '💾 Saving to your library...'}
								</p>
								<div className="mt-2 h-1.5 bg-purple-200 rounded-full overflow-hidden">
									<div className="h-full bg-gradient-to-r from-purple-600 to-pink-600 rounded-full animate-progress"></div>
								</div>
							</div>
						</div>
					</div>
				)}

				{/* Error message */}
				{error && (
					<div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3 animate-shake">
						<svg className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
						<div className="flex-1">
							<p className="text-sm font-medium text-red-800">{error}</p>
						</div>
						<button
							onClick={() => setError('')}
							className="text-red-400 hover:text-red-600 transition-colors"
						>
							<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					</div>
				)}
			</form>

			{/* CSS Animations */}
			<style jsx>{`
				@keyframes shimmer {
					0% {
						background-position: -100% 0;
					}
					100% {
						background-position: 200% 0;
					}
				}
				@keyframes progress {
					0% {
						transform: translateX(-100%);
					}
					100% {
						transform: translateX(100%);
					}
				}
				@keyframes shake {
					0%, 100% {
						transform: translateX(0);
					}
					10%, 30%, 50%, 70%, 90% {
						transform: translateX(-5px);
					}
					20%, 40%, 60%, 80% {
						transform: translateX(5px);
					}
				}
				.animate-shimmer {
					background-size: 200% 100%;
					animation: shimmer 2s infinite;
				}
				.animate-progress {
					animation: progress 1.5s ease-in-out infinite;
				}
				.animate-shake {
					animation: shake 0.5s ease-in-out;
				}
			`}</style>
		</div>
	);
}
