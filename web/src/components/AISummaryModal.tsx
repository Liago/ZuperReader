'use client';

import { useState, useEffect } from 'react';
import { Article } from '../lib/supabase';
import { regenerateArticleSummary } from '../lib/api';

interface AISummaryModalProps {
	isOpen: boolean;
	onClose: () => void;
	article: Article;
	onSummaryUpdated?: (updatedArticle: Article) => void;
}

export default function AISummaryModal({ isOpen, onClose, article, onSummaryUpdated }: AISummaryModalProps) {
	const [isGenerating, setIsGenerating] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [summaryFormat, setSummaryFormat] = useState<'summary' | 'bullet'>('summary');
	const [summaryLength, setSummaryLength] = useState<'short' | 'medium' | 'long'>('medium');
	const [localArticle, setLocalArticle] = useState<Article>(article);

	// Update local article when prop changes
	useEffect(() => {
		setLocalArticle(article);
	}, [article]);

	// Handle keyboard navigation
	useEffect(() => {
		const handleKeyDown = (e: KeyboardEvent) => {
			if (e.key === 'Escape') {
				onClose();
			}
		};

		if (isOpen) {
			window.addEventListener('keydown', handleKeyDown);
			return () => window.removeEventListener('keydown', handleKeyDown);
		}
	}, [isOpen, onClose]);

	const handleGenerateSummary = async () => {
		if (!localArticle.content) {
			setError('Questo articolo non ha contenuto da riassumere');
			return;
		}

		setIsGenerating(true);
		setError(null);

		try {
			const updatedArticle = await regenerateArticleSummary(localArticle.id, summaryLength, summaryFormat);
			setLocalArticle(updatedArticle);
			if (onSummaryUpdated) {
				onSummaryUpdated(updatedArticle);
			}
		} catch (err) {
			setError(err instanceof Error ? err.message : 'Errore durante la generazione del riassunto');
		} finally {
			setIsGenerating(false);
		}
	};

	if (!isOpen) return null;

	return (
		<div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
			<div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
				{/* Header */}
				<div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700 bg-gradient-to-br from-purple-50 to-blue-50 dark:from-gray-800 dark:to-gray-900">
					<div className="flex items-center gap-3">
						<div className="p-2 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg">
							<svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
							</svg>
						</div>
						<div>
							<h3 className="text-xl font-bold bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent">
								Riassunto AI
							</h3>
							{localArticle.ai_summary_generated_at && (
								<p className="text-xs text-gray-500 dark:text-gray-400">
									Generato {new Date(localArticle.ai_summary_generated_at).toLocaleDateString('it-IT')}
								</p>
							)}
						</div>
					</div>

					<button
						onClick={onClose}
						className="p-2 rounded-full hover:bg-white/50 dark:hover:bg-gray-700 transition-all"
						title="Chiudi (Esc)"
					>
						<svg className="w-6 h-6 text-gray-600 dark:text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				{/* Controls */}
				{localArticle.content && (
					<div className="flex items-center justify-between gap-4 p-4 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50">
						<div className="flex items-center gap-4 flex-wrap">
							<div className="flex items-center gap-3">
								<label className="text-sm font-medium text-gray-700 dark:text-gray-300">
									Formato:
								</label>
								<select
									value={summaryFormat}
									onChange={(e) => setSummaryFormat(e.target.value as 'summary' | 'bullet')}
									disabled={isGenerating}
									className="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 disabled:opacity-50 focus:ring-2 focus:ring-purple-500 focus:border-transparent"
								>
									<option value="summary">Riassunto</option>
									<option value="bullet">Punti elenco</option>
								</select>
							</div>

							<div className="flex items-center gap-3">
								<label className="text-sm font-medium text-gray-700 dark:text-gray-300">
									Lunghezza:
								</label>
								<select
									value={summaryLength}
									onChange={(e) => setSummaryLength(e.target.value as 'short' | 'medium' | 'long')}
									disabled={isGenerating}
									className="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 disabled:opacity-50 focus:ring-2 focus:ring-purple-500 focus:border-transparent"
								>
									<option value="short">Breve</option>
									<option value="medium">Medio</option>
									<option value="long">Lungo</option>
								</select>
							</div>
						</div>

						<button
							onClick={handleGenerateSummary}
							disabled={isGenerating}
							className="px-5 py-2 text-sm font-medium bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg hover:from-purple-700 hover:to-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center gap-2 shadow-md hover:shadow-lg"
							title={localArticle.ai_summary ? 'Rigenera riassunto' : 'Genera riassunto'}
						>
							{isGenerating ? (
								<>
									<svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
										<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
										<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
									</svg>
									<span>Generazione...</span>
								</>
							) : (
								<>
									<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
									</svg>
									<span>{localArticle.ai_summary ? 'Rigenera' : 'Genera'}</span>
								</>
							)}
						</button>
					</div>
				)}

				{/* Content */}
				<div className="flex-1 overflow-y-auto p-6">
					{/* Error message */}
					{error && (
						<div className="mb-4 p-4 bg-red-100 dark:bg-red-900/30 border border-red-300 dark:border-red-700 rounded-lg">
							<p className="text-sm text-red-700 dark:text-red-300">{error}</p>
						</div>
					)}

					{/* Summary content */}
					{localArticle.ai_summary ? (
						<div className="prose prose-lg dark:prose-invert max-w-none">
							<p className="text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-line">
								{localArticle.ai_summary}
							</p>
						</div>
					) : (
						<div className="text-center py-12">
							<svg className="w-16 h-16 mx-auto text-gray-400 dark:text-gray-600 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
							</svg>
							<p className="text-gray-600 dark:text-gray-400 text-lg mb-2 font-medium">
								Nessun riassunto AI disponibile
							</p>
							<p className="text-sm text-gray-500 dark:text-gray-500">
								Clicca su &quot;Genera&quot; per creare un riassunto intelligente di questo articolo
							</p>
						</div>
					)}

					{/* AI Badge */}
					<div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700 flex items-center justify-center gap-2 text-xs text-gray-500 dark:text-gray-400">
						<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
						</svg>
						<span>Powered by Cohere AI</span>
					</div>
				</div>
			</div>
		</div>
	);
}
