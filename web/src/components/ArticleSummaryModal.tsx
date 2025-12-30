'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Article } from '../lib/supabase';
import { getArticlesForSummary, generateArticleSummary, generateAISummary } from '../lib/api';

interface ArticleSummaryModalProps {
	isOpen: boolean;
	onClose: () => void;
	userId: string;
}

export default function ArticleSummaryModal({ isOpen, onClose, userId }: ArticleSummaryModalProps) {
	const [period, setPeriod] = useState<7 | 30>(7);
	const [articles, setArticles] = useState<Article[]>([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);
	const [narrativeSummary, setNarrativeSummary] = useState<string | null>(null);
	const [isGeneratingNarrative, setIsGeneratingNarrative] = useState(false);

	useEffect(() => {
		if (isOpen) {
			loadArticles();
		}
	}, [isOpen, period, userId]);

	const loadArticles = async () => {
		try {
			setLoading(true);
			setError(null);
			const data = await getArticlesForSummary(userId, period);
			setArticles(data);
			setNarrativeSummary(null); // Reset when period changes
		} catch (err) {
			setError(err instanceof Error ? err.message : 'Errore nel caricamento degli articoli');
		} finally {
			setLoading(false);
		}
	};

	const handleGenerateNarrative = async () => {
		if (articles.length === 0) return;

		try {
			setIsGeneratingNarrative(true);
			
			// Prepare content for the AI - List of titles and excerpts
			const articlesContent = articles
				.slice(0, 15) // Limit to top 15 to avoid context limits
				.map(a => `TITOLO: ${a.title}\nESTRATTO: ${a.excerpt || 'Nessun estratto'}`)
				.join('\n\n');
				
			const summary = await generateAISummary(articlesContent, 'long', 'periodical');
			setNarrativeSummary(summary);
		} catch (err) {
			console.error('Error generating narrative summary:', err);
			// Silent error or show toast
		} finally {
			setIsGeneratingNarrative(false);
		}
	};

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

	if (!isOpen) return null;

	const { summary, stats } = articles.length > 0
		? generateArticleSummary(articles, period)
		: { summary: '', stats: { total: 0, read: 0, reading: 0, unread: 0, favorites: 0, totalReadTime: 0, topDomains: [], topTags: [] } };

	// Render markdown-like text
	const renderSummary = (text: string) => {
		return text.split('\n').map((line, idx) => {
			// Headers
			if (line.startsWith('### ')) {
				return (
					<h3 key={idx} className="text-xl font-bold mt-6 mb-3 bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
						{line.replace('### ', '')}
					</h3>
				);
			}
			// Bold text
			const parts = line.split(/(\*\*[^*]+\*\*)/g);
			return (
				<p key={idx} className="mb-2">
					{parts.map((part, i) => {
						if (part.startsWith('**') && part.endsWith('**')) {
							return <strong key={i} className="font-semibold text-purple-700 dark:text-purple-300">{part.slice(2, -2)}</strong>;
						}
						return <span key={i}>{part}</span>;
					})}
				</p>
			);
		});
	};

	return (
		<div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
			<div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
				{/* Header */}
				<div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-gray-800 dark:to-gray-800">
					<div>
						<h2 className="text-2xl font-bold bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent">
							Riassunto Articoli
						</h2>
						<p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
							Analisi della tua attività di lettura
						</p>
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

				{/* Period Selector */}
				<div className="flex gap-3 p-4 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50">
					<button
						onClick={() => setPeriod(7)}
						className={`flex-1 px-4 py-2 rounded-lg font-medium transition-all ${
							period === 7
								? 'bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-md'
								: 'bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-600'
						}`}
					>
						Ultimi 7 giorni
					</button>
					<button
						onClick={() => setPeriod(30)}
						className={`flex-1 px-4 py-2 rounded-lg font-medium transition-all ${
							period === 30
								? 'bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-md'
								: 'bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-600'
						}`}
					>
						Ultimi 30 giorni
					</button>
				</div>

				{/* Content */}
				<div className="flex-1 overflow-y-auto p-6">
					{loading ? (
						<div className="flex flex-col items-center justify-center py-12">
							<div className="w-12 h-12 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
							<p className="text-gray-600 dark:text-gray-400 mt-4">Caricamento...</p>
						</div>
					) : error ? (
						<div className="text-center py-12">
							<p className="text-red-600 dark:text-red-400">{error}</p>
						</div>
					) : articles.length === 0 ? (
						<div className="text-center py-12">
							<svg className="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
							</svg>
							<p className="text-gray-600 dark:text-gray-400 text-lg">
								Nessun articolo salvato negli ultimi {period} giorni
							</p>
						</div>
					) : (
						<div className="space-y-8">
							{/* Summary Section */}
							<div className="bg-gradient-to-br from-purple-50 to-pink-50 dark:from-gray-800 dark:to-gray-800 rounded-xl p-6 border border-purple-200 dark:border-gray-700">
								<div className="flex items-center gap-2 mb-4">
									<svg className="w-6 h-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
									</svg>
									<h3 className="text-xl font-bold text-gray-900 dark:text-white">Riepilogo</h3>
								</div>
								<div className="text-gray-700 dark:text-gray-300 leading-relaxed">
									{renderSummary(summary)}
								</div>

								{/* Narrative Summary Section */}
								<div className="mt-8 pt-6 border-t border-purple-200 dark:border-gray-700">
									<div className="flex items-center justify-between mb-4">
										<div className="flex items-center gap-2">
											<svg className="w-6 h-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
											</svg>
											<h3 className="text-lg font-bold text-gray-900 dark:text-white">Racconto del periodo</h3>
										</div>
										{!narrativeSummary && !isGeneratingNarrative && (
											<button
												onClick={handleGenerateNarrative}
												className="px-4 py-2 text-sm font-medium bg-white dark:bg-gray-700 text-purple-600 dark:text-purple-300 rounded-lg border border-purple-200 dark:border-gray-600 hover:bg-purple-50 dark:hover:bg-gray-600 transition-all flex items-center gap-2"
											>
												<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
													<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
												</svg>
												Genera racconto AI
											</button>
										)}
									</div>

									{isGeneratingNarrative ? (
										<div className="animate-pulse space-y-3">
											<div className="h-4 bg-purple-100 dark:bg-gray-700 rounded w-full"></div>
											<div className="h-4 bg-purple-100 dark:bg-gray-700 rounded w-11/12"></div>
											<div className="h-4 bg-purple-100 dark:bg-gray-700 rounded w-full"></div>
											<div className="flex items-center gap-2 text-sm text-purple-600 mt-2">
												<svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
													<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
													<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
												</svg>
												Scrivendo il racconto delle tue letture...
											</div>
										</div>
									) : narrativeSummary ? (
										<div className="prose prose-purple dark:prose-invert max-w-none">
											<div className="p-4 bg-white/50 dark:bg-gray-900/30 rounded-lg italic text-gray-700 dark:text-gray-300 leading-relaxed border border-purple-100 dark:border-gray-700">
												{narrativeSummary.split('\n\n').map((para, idx) => (
													<p key={idx} className="mb-4 last:mb-0">{para}</p>
												))}
											</div>
										</div>
									) : (
										<p className="text-sm text-gray-500 italic">
											Genera un riassunto discorsivo che collega gli argomenti dei tuoi articoli recenti in una narrazione fluida.
										</p>
									)}
								</div>

							</div>

							{/* Articles Grid */}
							<div>
								<div className="flex items-center gap-2 mb-4">
									<svg className="w-6 h-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
									</svg>
									<h3 className="text-xl font-bold text-gray-900 dark:text-white">
										I tuoi articoli ({articles.length})
									</h3>
								</div>

								<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
									{articles.map((article) => (
										<Link
											key={article.id}
											href={`/articles/${article.id}`}
											className="group bg-white dark:bg-gray-800 rounded-xl overflow-hidden border border-gray-200 dark:border-gray-700 hover:shadow-lg hover:scale-[1.02] transition-all duration-200"
										>
											{/* Image */}
											{article.image_url ? (
												<div className="aspect-video bg-gray-200 dark:bg-gray-700 overflow-hidden">
													<img
														src={article.image_url}
														alt={article.title}
														className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
													/>
												</div>
											) : (
												<div className="aspect-video bg-gradient-to-br from-purple-100 to-pink-100 dark:from-gray-700 dark:to-gray-600 flex items-center justify-center">
													<svg className="w-12 h-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
														<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
													</svg>
												</div>
											)}

											{/* Content */}
											<div className="p-4">
												<h4 className="font-semibold text-gray-900 dark:text-white line-clamp-2 mb-2 group-hover:text-purple-600 dark:group-hover:text-purple-400 transition-colors">
													{article.title}
												</h4>

												{article.excerpt && (
													<p className="text-sm text-gray-600 dark:text-gray-400 line-clamp-2 mb-3">
														{article.excerpt}
													</p>
												)}

												{/* Meta Info */}
												<div className="flex items-center justify-between text-xs text-gray-500 dark:text-gray-500">
													<div className="flex items-center gap-2">
														{article.domain && (
															<span className="flex items-center gap-1">
																<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
																	<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
																</svg>
																{article.domain}
															</span>
														)}
													</div>
													<div className="flex items-center gap-2">
														{article.estimated_read_time && (
															<span className="flex items-center gap-1">
																<svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
																	<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
																</svg>
																{article.estimated_read_time}min
															</span>
														)}
													</div>
												</div>

												{/* Status Badge */}
												<div className="mt-3 flex items-center gap-2">
													<span className={`text-xs px-2 py-1 rounded-full ${
														article.reading_status === 'completed'
															? 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300'
															: article.reading_status === 'reading'
															? 'bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300'
															: 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300'
													}`}>
														{article.reading_status === 'completed' ? 'Completato' :
														 article.reading_status === 'reading' ? 'In lettura' : 'Da leggere'}
													</span>
													{article.is_favorite && (
														<svg className="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 24 24">
															<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
														</svg>
													)}
												</div>

												{/* Tags */}
												{article.tags && article.tags.length > 0 && (
													<div className="mt-3 flex flex-wrap gap-1">
														{article.tags.slice(0, 3).map((tag, idx) => (
															<span
																key={idx}
																className="text-xs px-2 py-0.5 bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 rounded"
															>
																#{tag}
															</span>
														))}
														{article.tags.length > 3 && (
															<span className="text-xs text-gray-500">+{article.tags.length - 3}</span>
														)}
													</div>
												)}
											</div>
										</Link>
									))}
								</div>
							</div>
						</div>
					)}
				</div>
			</div>
		</div>
	);
}
