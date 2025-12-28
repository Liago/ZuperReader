'use client';

import { useState } from 'react';
import { Article } from '../lib/supabase';
import { regenerateArticleSummary } from '../lib/api';

interface AISummaryBoxProps {
	article: Article;
	onSummaryUpdated?: (updatedArticle: Article) => void;
}

export default function AISummaryBox({ article, onSummaryUpdated }: AISummaryBoxProps) {
	const [isGenerating, setIsGenerating] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [summaryLength, setSummaryLength] = useState<'short' | 'medium' | 'long'>('medium');

	const handleGenerateSummary = async () => {
		if (!article.content) {
			setError('Questo articolo non ha contenuto da riassumere');
			return;
		}

		setIsGenerating(true);
		setError(null);

		try {
			const updatedArticle = await regenerateArticleSummary(article.id, summaryLength);
			if (onSummaryUpdated) {
				onSummaryUpdated(updatedArticle);
			}
		} catch (err) {
			setError(err instanceof Error ? err.message : 'Errore durante la generazione del riassunto');
		} finally {
			setIsGenerating(false);
		}
	};

	// If no summary and no content, don't show anything
	if (!article.ai_summary && !article.content) {
		return null;
	}

	return (
		<div className="bg-gradient-to-br from-purple-50 to-blue-50 dark:from-gray-800 dark:to-gray-900 rounded-2xl p-6 border border-purple-200 dark:border-purple-800 shadow-lg">
			{/* Header */}
			<div className="flex items-center justify-between mb-4">
				<div className="flex items-center gap-3">
					<div className="p-2 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg">
						<svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
						</svg>
					</div>
					<div>
						<h3 className="text-lg font-bold bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent">
							Riassunto AI
						</h3>
						{article.ai_summary_generated_at && (
							<p className="text-xs text-gray-500 dark:text-gray-400">
								Generato {new Date(article.ai_summary_generated_at).toLocaleDateString('it-IT')}
							</p>
						)}
					</div>
				</div>

				{/* Length selector and regenerate button */}
				<div className="flex items-center gap-2">
					{article.content && (
						<>
							<select
								value={summaryLength}
								onChange={(e) => setSummaryLength(e.target.value as 'short' | 'medium' | 'long')}
								disabled={isGenerating}
								className="px-3 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 disabled:opacity-50"
							>
								<option value="short">Breve</option>
								<option value="medium">Medio</option>
								<option value="long">Lungo</option>
							</select>

							<button
								onClick={handleGenerateSummary}
								disabled={isGenerating}
								className="px-4 py-1.5 text-sm font-medium bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg hover:from-purple-700 hover:to-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center gap-2"
								title={article.ai_summary ? 'Rigenera riassunto' : 'Genera riassunto'}
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
										<span>{article.ai_summary ? 'Rigenera' : 'Genera'}</span>
									</>
								)}
							</button>
						</>
					)}
				</div>
			</div>

			{/* Error message */}
			{error && (
				<div className="mb-4 p-3 bg-red-100 dark:bg-red-900/30 border border-red-300 dark:border-red-700 rounded-lg">
					<p className="text-sm text-red-700 dark:text-red-300">{error}</p>
				</div>
			)}

			{/* Summary content */}
			{article.ai_summary ? (
				<div className="prose prose-sm dark:prose-invert max-w-none">
					<p className="text-gray-700 dark:text-gray-300 leading-relaxed">
						{article.ai_summary}
					</p>
				</div>
			) : (
				<div className="text-center py-8">
					<svg className="w-12 h-12 mx-auto text-gray-400 dark:text-gray-600 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
					</svg>
					<p className="text-gray-500 dark:text-gray-400 mb-2">
						Nessun riassunto AI disponibile
					</p>
					<p className="text-sm text-gray-400 dark:text-gray-500">
						Clicca su "Genera" per creare un riassunto intelligente di questo articolo
					</p>
				</div>
			)}

			{/* AI Badge */}
			<div className="mt-4 flex items-center justify-center gap-2 text-xs text-gray-500 dark:text-gray-400">
				<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
				</svg>
				<span>Powered by Cohere AI</span>
			</div>
		</div>
	);
}
