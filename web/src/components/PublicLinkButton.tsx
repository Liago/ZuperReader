'use client';

import { useState } from 'react';
import { Globe, Link2, Check, Loader2 } from 'lucide-react';
import { enablePublicLink, disablePublicLink, buildPublicArticleUrl } from '@/lib/api';

interface PublicLinkButtonProps {
	articleId: string;
	publicShareToken: string | null;
	onChange: (token: string | null) => void;
}

export default function PublicLinkButton({ articleId, publicShareToken, onChange }: PublicLinkButtonProps) {
	const [open, setOpen] = useState(false);
	const [busy, setBusy] = useState(false);
	const [copied, setCopied] = useState(false);
	const [error, setError] = useState<string | null>(null);

	const isPublic = Boolean(publicShareToken);
	const publicUrl = publicShareToken ? buildPublicArticleUrl(publicShareToken) : '';

	const copy = async (url: string) => {
		try {
			await navigator.clipboard.writeText(url);
			setCopied(true);
			setTimeout(() => setCopied(false), 2000);
		} catch {
			setError('Could not copy the link');
		}
	};

	const handleToggle = async () => {
		setBusy(true);
		setError(null);
		try {
			if (isPublic) {
				await disablePublicLink(articleId);
				onChange(null);
			} else {
				const token = await enablePublicLink(articleId);
				onChange(token);
				await copy(buildPublicArticleUrl(token));
			}
		} catch (err) {
			console.error('Error updating public link:', err);
			setError(isPublic ? 'Could not disable the public link' : 'Could not create the public link');
		} finally {
			setBusy(false);
		}
	};

	return (
		<div className="relative">
			<button
				type="button"
				onClick={() => setOpen((v) => !v)}
				title={isPublic ? 'Public link active' : 'Public link'}
				className={`flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full border border-app-line transition-colors hover:bg-app-hover hover:text-ink ${
					isPublic ? 'text-accent' : 'text-app-muted'
				}`}
			>
				<Globe size={16} strokeWidth={2.75} />
			</button>

			{open && (
				<>
					<div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
					<div className="absolute right-0 z-50 mt-2 w-[300px] rounded-2xl border border-app-line bg-app-card p-4 [box-shadow:var(--shadow-modal)]">
						<div className="flex items-start justify-between gap-3">
							<div>
								<div className="text-[14px] font-semibold text-ink">Public link</div>
								<p className="mt-1 text-[12.5px] leading-[1.45] text-app-muted">
									Anyone with the link can read the clean version of this article, without an account.
								</p>
							</div>
							<button
								type="button"
								role="switch"
								aria-checked={isPublic}
								aria-label="Toggle public link"
								onClick={handleToggle}
								disabled={busy}
								className={`relative mt-0.5 h-6 w-11 flex-none rounded-full transition-colors disabled:opacity-60 ${
									isPublic ? 'bg-accent' : 'bg-app-line'
								}`}
							>
								<span
									className={`absolute top-0.5 h-5 w-5 rounded-full bg-app-card shadow transition-transform ${
										isPublic ? 'translate-x-[22px]' : 'translate-x-0.5'
									}`}
								/>
							</button>
						</div>

						{busy && (
							<div className="mt-3 flex items-center gap-2 text-[12.5px] text-app-muted">
								<Loader2 size={14} className="animate-spin" />
								Updating…
							</div>
						)}

						{isPublic && !busy && (
							<div className="mt-3 flex items-center gap-2">
								<input
									readOnly
									value={publicUrl}
									onFocus={(e) => e.currentTarget.select()}
									className="min-w-0 flex-1 rounded-full border border-app-line bg-app-page px-3 py-1.5 text-[12.5px] text-ink outline-none"
								/>
								<button
									type="button"
									onClick={() => copy(publicUrl)}
									title="Copy link"
									className="flex h-[30px] flex-none items-center gap-1.5 rounded-full bg-accent px-3 text-[12.5px] font-semibold text-app-page transition-colors hover:bg-accent-600"
								>
									{copied ? <Check size={14} strokeWidth={2.75} /> : <Link2 size={14} strokeWidth={2.75} />}
									{copied ? 'Copied' : 'Copy'}
								</button>
							</div>
						)}

						{isPublic && !busy && (
							<p className="mt-2 text-[11.5px] text-app-muted">
								Turning it off revokes the link immediately. Turning it on again creates a new one.
							</p>
						)}

						{error && <p className="mt-2 text-[12.5px] text-accent">{error}</p>}
					</div>
				</>
			)}
		</div>
	);
}
