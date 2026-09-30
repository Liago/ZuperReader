'use client';

import { useState } from 'react';
import { Globe, Link2, Check, Loader2 } from 'lucide-react';
import { enablePublicLink, disablePublicLink, buildPublicArticleUrl } from '@/lib/api';
import type { PublicLinkValidity } from '@/lib/supabase';
import {
	PUBLIC_LINK_VALIDITY_OPTIONS,
	isPublicLinkActive,
	formatPublicLinkExpiry,
	validityFromExpiry,
} from '@/lib/publicLink';

interface PublicLinkButtonProps {
	articleId: string;
	publicShareToken: string | null;
	publicLinkExpiresAt: string | null;
	onChange: (token: string | null, expiresAt: string | null) => void;
}

export default function PublicLinkButton({ articleId, publicShareToken, publicLinkExpiresAt, onChange }: PublicLinkButtonProps) {
	const [open, setOpen] = useState(false);
	const [busy, setBusy] = useState(false);
	const [copied, setCopied] = useState(false);
	const [error, setError] = useState<string | null>(null);

	const isPublic = isPublicLinkActive(publicShareToken, publicLinkExpiresAt);
	const publicUrl = isPublic && publicShareToken ? buildPublicArticleUrl(publicShareToken) : '';

	// Validity picked before turning the link on (default: 1 week).
	// While the link is active the selection mirrors the saved expiry.
	const [pendingValidity, setPendingValidity] = useState<PublicLinkValidity>(7);
	const selectedValidity: PublicLinkValidity = isPublic ? validityFromExpiry(publicLinkExpiresAt) : pendingValidity;

	const copy = async (url: string) => {
		try {
			await navigator.clipboard.writeText(url);
			setCopied(true);
			setTimeout(() => setCopied(false), 2000);
		} catch {
			setError('Could not copy the link');
		}
	};

	const enable = async (validity: PublicLinkValidity, copyAfter: boolean) => {
		setBusy(true);
		setError(null);
		try {
			const { token, expiresAt } = await enablePublicLink(articleId, validity);
			onChange(token, expiresAt);
			if (copyAfter) await copy(buildPublicArticleUrl(token));
		} catch (err) {
			console.error('Error enabling public link:', err);
			setError('Could not update the public link');
		} finally {
			setBusy(false);
		}
	};

	const handleToggle = async () => {
		if (!isPublic) {
			await enable(pendingValidity, true);
			return;
		}
		setBusy(true);
		setError(null);
		try {
			await disablePublicLink(articleId);
			onChange(null, null);
		} catch (err) {
			console.error('Error disabling public link:', err);
			setError('Could not disable the public link');
		} finally {
			setBusy(false);
		}
	};

	const handleValidityChange = (validity: PublicLinkValidity) => {
		if (isPublic) {
			// Same token, new expiry
			void enable(validity, false);
		} else {
			setPendingValidity(validity);
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
					<div className="absolute right-0 z-50 mt-2 w-[310px] rounded-2xl border border-app-line bg-app-card p-4 [box-shadow:var(--shadow-modal)]">
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

						{/* Validity */}
						<div className="mt-3">
							<div className="mb-1.5 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">Valid for</div>
							<div className="flex rounded-full border border-app-line p-0.5" role="radiogroup" aria-label="Link validity">
								{PUBLIC_LINK_VALIDITY_OPTIONS.map((option) => {
									const selected = option.value === selectedValidity;
									return (
										<button
											key={option.label}
											type="button"
											role="radio"
											aria-checked={selected}
											disabled={busy}
											onClick={() => handleValidityChange(option.value)}
											className={`flex-1 rounded-full px-2 py-1.5 text-[12.5px] font-semibold transition-colors disabled:opacity-60 ${
												selected ? 'bg-ink text-app-page' : 'text-ink hover:bg-app-hover'
											}`}
										>
											{option.label}
										</button>
									);
								})}
							</div>
						</div>

						{busy && (
							<div className="mt-3 flex items-center gap-2 text-[12.5px] text-app-muted">
								<Loader2 size={14} className="animate-spin" />
								Updating…
							</div>
						)}

						{isPublic && !busy && (
							<>
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
								<p className="mt-2 text-[11.5px] font-semibold text-ink">{formatPublicLinkExpiry(publicLinkExpiresAt)}</p>
								<p className="mt-1 text-[11.5px] text-app-muted">
									Changing the validity keeps the same link. Turning it off revokes it immediately.
								</p>
							</>
						)}

						{error && <p className="mt-2 text-[12.5px] text-accent">{error}</p>}
					</div>
				</>
			)}
		</div>
	);
}
