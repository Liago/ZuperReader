'use client';

import { useState, useEffect, useRef } from 'react';
import { Link2, ClipboardCheck, X } from 'lucide-react';
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
	const [addToQueue, setAddToQueue] = useState(false);
	const inputRef = useRef<HTMLInputElement>(null);

	// Check clipboard when modal opens
	useEffect(() => {
		if (isOpen) {
			checkClipboard();
		} else {
			setClipboardUrl(null);
			setShowClipboardPrompt(false);
		}
	}, [isOpen]);

	// Close on Escape
	useEffect(() => {
		if (!isOpen) return;
		const onKey = (e: KeyboardEvent) => {
			if (e.key === 'Escape' && !loading) handleClose();
		};
		document.addEventListener('keydown', onKey);
		return () => document.removeEventListener('keydown', onKey);
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [isOpen, loading]);

	const checkClipboard = async () => {
		try {
			const text = await navigator.clipboard.readText();
			if (text && (text.startsWith('http://') || text.startsWith('https://'))) {
				setClipboardUrl(text);
				setShowClipboardPrompt(true);
			} else {
				setTimeout(() => inputRef.current?.focus(), 100);
			}
		} catch (err) {
			console.log('Clipboard access denied:', err);
			setTimeout(() => inputRef.current?.focus(), 100);
		}
	};

	const handleUseClipboardUrl = () => {
		if (clipboardUrl) {
			setUrl(clipboardUrl);
			setShowClipboardPrompt(false);
		}
	};

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');
		setParsingStep('parsing');

		try {
			const parsedData = await parseArticle(url);
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
		<div
			className="fixed inset-0 z-50 grid place-items-center p-4"
			style={{ background: 'rgba(32,30,29,.42)' }}
			onClick={handleClose}
		>
			<div
				className="w-full max-w-[520px] rounded-[28px] border border-app-line bg-app-card p-7 [box-shadow:var(--shadow-modal)]"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header */}
				<div className="flex items-start justify-between gap-4">
					<div>
						<h2 className="font-heading text-[24px] leading-[1.1] text-ink">Save a link</h2>
						<p className="mt-1 text-[13px] text-app-muted">
							We&apos;ll fetch the title, cover and reading time.
						</p>
					</div>
					<button
						type="button"
						onClick={handleClose}
						disabled={loading}
						className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink disabled:opacity-50"
					>
						<X size={16} strokeWidth={2.75} />
					</button>
				</div>

				<form onSubmit={handleSubmit} className="mt-5">
					{/* URL input */}
					<div className="flex items-center gap-2.5 rounded-full border border-app-line bg-app-surface px-4 py-3">
						<Link2 size={18} strokeWidth={2.75} className="flex-none text-app-muted" />
						<input
							ref={inputRef}
							id="article-url"
							type="url"
							value={url}
							onChange={(e) => setUrl(e.target.value)}
							placeholder="https://"
							required
							disabled={loading}
							className="w-full bg-transparent text-[14px] text-ink placeholder:text-app-muted focus:outline-none disabled:opacity-50"
						/>
						{url && !loading && (
							<button type="button" onClick={() => setUrl('')} className="flex-none text-app-muted hover:text-ink">
								<X size={15} strokeWidth={2.75} />
							</button>
						)}
					</div>

					{/* Clipboard suggestion */}
					{showClipboardPrompt && clipboardUrl && (
						<div
							className="mt-3 flex items-center gap-3 rounded-[20px] border p-3"
							style={{ background: 'var(--accent-100)', borderColor: 'var(--accent-300)' }}
						>
							<ClipboardCheck size={18} strokeWidth={2.75} className="flex-none text-accent" />
							<div className="min-w-0 flex-1">
								<div className="text-[12px] font-bold text-accent-800">In your clipboard</div>
								<div className="truncate text-[12.5px] text-accent-800/80">{clipboardUrl}</div>
							</div>
							<button
								type="button"
								onClick={handleUseClipboardUrl}
								className="flex-none rounded-full bg-accent px-3.5 py-1.5 text-[12.5px] font-semibold text-app-page transition-colors hover:bg-accent-600"
							>
								Use
							</button>
						</div>
					)}

					{/* Loading progress */}
					{loading && (
						<div className="mt-4 rounded-[18px] border border-app-line bg-app-surface p-4">
							<p className="text-[13px] font-medium text-ink">
								{parsingStep === 'parsing' && 'Fetching article…'}
								{parsingStep === 'saving' && 'Saving to your library…'}
							</p>
							<div className="mt-2 h-1 overflow-hidden rounded-full bg-app-line">
								<div
									className="h-full rounded-full bg-accent transition-all duration-500"
									style={{ width: parsingStep === 'parsing' ? '40%' : '80%' }}
								/>
							</div>
						</div>
					)}

					{/* Error */}
					{error && (
						<div className="mt-4 flex items-start justify-between gap-3 rounded-[18px] border border-app-line p-4" style={{ background: 'var(--accent-100)' }}>
							<p className="text-[13px] font-medium text-accent-800">{error}</p>
							<button type="button" onClick={() => setError('')} className="flex-none text-accent-800/70 hover:text-accent-800">
								<X size={16} strokeWidth={2.75} />
							</button>
						</div>
					)}

					{/* Footer */}
					<div className="mt-6 flex items-center justify-between gap-4 border-t border-app-line pt-5">
						<label className="flex cursor-pointer select-none items-center gap-2.5">
							<button
								type="button"
								role="switch"
								aria-checked={addToQueue}
								onClick={() => setAddToQueue((v) => !v)}
								className={`relative h-5 w-[34px] flex-none rounded-full transition-colors ${
									addToQueue ? 'bg-accent' : 'bg-app-line'
								}`}
							>
								<span
									className={`absolute top-0.5 h-4 w-4 rounded-full bg-app-card transition-transform ${
										addToQueue ? 'translate-x-[15px]' : 'translate-x-0.5'
									}`}
								/>
							</button>
							<span className="text-[13px] text-app-muted">Add to Up next</span>
						</label>

						<div className="flex gap-2.5">
							<button
								type="button"
								onClick={handleClose}
								disabled={loading}
								className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover disabled:opacity-50"
							>
								Cancel
							</button>
							<button
								type="submit"
								disabled={loading || !url}
								className="rounded-full bg-accent px-5 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600 disabled:cursor-not-allowed disabled:opacity-50"
							>
								{loading ? (parsingStep === 'parsing' ? 'Fetching…' : 'Saving…') : 'Save'}
							</button>
						</div>
					</div>
				</form>
			</div>
		</div>
	);
}
