'use client';

import { useState, useEffect } from 'react';
import { Sparkles, X, RefreshCw, Zap } from 'lucide-react';
import { Article } from '../lib/supabase';
import { regenerateArticleSummary } from '../lib/api';
import Dropdown from './Dropdown';

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

	useEffect(() => {
		setLocalArticle(article);
	}, [article]);

	useEffect(() => {
		const handleKeyDown = (e: KeyboardEvent) => {
			if (e.key === 'Escape') onClose();
		};
		if (isOpen) {
			window.addEventListener('keydown', handleKeyDown);
			return () => window.removeEventListener('keydown', handleKeyDown);
		}
	}, [isOpen, onClose]);

	const handleGenerateSummary = async () => {
		if (!localArticle.content) {
			setError('This article has no content to summarise.');
			return;
		}

		setIsGenerating(true);
		setError(null);

		try {
			const updatedArticle = await regenerateArticleSummary(localArticle.id, summaryLength, summaryFormat);
			setLocalArticle(updatedArticle);
			if (onSummaryUpdated) onSummaryUpdated(updatedArticle);
		} catch (err) {
			setError(err instanceof Error ? err.message : 'Failed to generate the summary.');
		} finally {
			setIsGenerating(false);
		}
	};

	if (!isOpen) return null;

	return (
		<div
			className="fixed inset-0 z-50 grid place-items-center p-4"
			style={{ background: 'rgba(32,30,29,.42)' }}
			onClick={onClose}
		>
			<div
				className="flex max-h-[90vh] w-full max-w-3xl flex-col overflow-hidden rounded-[28px] border border-app-line bg-app-card [box-shadow:var(--shadow-modal)]"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header */}
				<div className="flex items-center justify-between gap-4 border-b border-app-line p-6">
					<div className="flex items-center gap-3">
						<div className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-accent">
							<Sparkles size={18} strokeWidth={2.75} className="text-app-page" />
						</div>
						<div>
							<h2 className="font-heading text-[24px] leading-none text-ink">AI summary</h2>
							{localArticle.ai_summary_generated_at && (
								<p className="mt-1 text-[12px] text-app-muted">
									Generated {new Date(localArticle.ai_summary_generated_at).toLocaleDateString('en-US')}
								</p>
							)}
						</div>
					</div>

					<button
						onClick={onClose}
						title="Close (Esc)"
						className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
					>
						<X size={16} strokeWidth={2.75} />
					</button>
				</div>

				{/* Controls */}
				{localArticle.content && (
					<div className="flex flex-wrap items-center justify-between gap-4 border-b border-app-line p-4">
						<div className="flex flex-wrap items-center gap-4">
							<div className="flex items-center gap-2.5">
								<label className="text-[13px] font-medium text-app-muted">Format:</label>
								<Dropdown
									value={summaryFormat}
									onChange={(value) => setSummaryFormat(value as 'summary' | 'bullet')}
									options={[
										{ label: 'Summary', value: 'summary' },
										{ label: 'Bullet points', value: 'bullet' },
									]}
									disabled={isGenerating}
									className="w-40"
								/>
							</div>

							<div className="flex items-center gap-2.5">
								<label className="text-[13px] font-medium text-app-muted">Length:</label>
								<Dropdown
									value={summaryLength}
									onChange={(value) => setSummaryLength(value as 'short' | 'medium' | 'long')}
									options={[
										{ label: 'Short', value: 'short' },
										{ label: 'Medium', value: 'medium' },
										{ label: 'Long', value: 'long' },
									]}
									disabled={isGenerating}
									className="w-32"
								/>
							</div>
						</div>

						<button
							onClick={handleGenerateSummary}
							disabled={isGenerating}
							className="flex items-center gap-2 rounded-full bg-accent px-5 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600 disabled:cursor-not-allowed disabled:opacity-50"
							title={localArticle.ai_summary ? 'Regenerate summary' : 'Generate summary'}
						>
							<RefreshCw size={15} strokeWidth={2.75} className={isGenerating ? 'animate-spin' : ''} />
							{isGenerating ? 'Generating…' : localArticle.ai_summary ? 'Regenerate' : 'Generate'}
						</button>
					</div>
				)}

				{/* Content */}
				<div className="flex-1 overflow-y-auto p-6">
					{error && (
						<div className="mb-4 rounded-[18px] border border-app-line p-4" style={{ background: 'var(--accent-100)' }}>
							<p className="text-[13px] font-medium text-accent-800">{error}</p>
						</div>
					)}

					{isGenerating ? (
						<div className="animate-pulse space-y-3">
							{['w-full', 'w-11/12', 'w-10/12', 'w-full', 'w-9/12', 'w-10/12', 'w-full', 'w-8/12'].map((w, i) => (
								<div key={i} className={`h-4 rounded bg-app-surface ${w}`} />
							))}
							<div className="mt-8 flex items-center justify-center gap-3 border-t border-app-line pt-8">
								<div className="h-5 w-5 animate-spin rounded-full border-2 border-app-line border-t-accent" />
								<span className="text-[13px] font-medium text-app-muted">Generating the summary…</span>
							</div>
						</div>
					) : localArticle.ai_summary ? (
						<div
							className="whitespace-pre-line text-[15px] leading-[1.7] text-ink"
							style={{ fontFamily: 'var(--font-body)' }}
						>
							{localArticle.ai_summary}
						</div>
					) : (
						<div className="py-12 text-center">
							<Sparkles size={40} strokeWidth={1.75} className="mx-auto mb-4 text-accent opacity-50" />
							<p className="font-heading text-[21px] text-ink">No AI summary yet</p>
							<p className="mt-1.5 text-[13.5px] text-app-muted">
								Click &quot;Generate&quot; to create a smart summary of this article.
							</p>
						</div>
					)}

					{/* AI Badge */}
					<div className="mt-6 flex items-center justify-center gap-2 border-t border-app-line pt-6 text-[12px] text-app-muted">
						<Zap size={14} strokeWidth={2.75} />
						<span>Powered by Cohere AI</span>
					</div>
				</div>
			</div>
		</div>
	);
}
