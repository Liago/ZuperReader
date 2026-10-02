'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Globe, Link2, Check, ExternalLink, RotateCcw, X, BookOpen, Clock, Infinity as InfinityIcon } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { getPublicLinks, enablePublicLink, disablePublicLink, buildPublicArticleUrl } from '@/lib/api';
import type { PublicLinkArticle, PublicLinkValidity } from '@/lib/supabase';
import {
	PUBLIC_LINK_VALIDITY_OPTIONS,
	isPublicLinkActive,
	formatPublicLinkValidity,
	formatRelative,
	formatDateTime,
	validityFromExpiry,
} from '@/lib/publicLink';
import AppShell from '@/components/shell/AppShell';

type Row = PublicLinkArticle & { busy?: boolean };

export default function PublicLinksPage() {
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const [rows, setRows] = useState<Row[]>([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);
	const [copiedId, setCopiedId] = useState<string | null>(null);
	const [confirmRevoke, setConfirmRevoke] = useState<Row | null>(null);

	useEffect(() => {
		if (!authLoading && !user) router.push('/login');
	}, [user, authLoading, router]);

	useEffect(() => {
		if (!user) return;
		getPublicLinks(user.id)
			.then(setRows)
			.catch((e) => {
				console.error('Failed to load public links:', e);
				setError('Could not load your public links');
			})
			.finally(() => setLoading(false));
	}, [user]);

	const { active, expired } = useMemo(() => {
		const activeRows: Row[] = [];
		const expiredRows: Row[] = [];
		rows.forEach((row) =>
			(isPublicLinkActive(row.public_share_token, row.public_link_expires_at) ? activeRows : expiredRows).push(row)
		);
		return { active: activeRows, expired: expiredRows };
	}, [rows]);

	const patchRow = (id: string, patch: Partial<Row>) =>
		setRows((prev) => prev.map((row) => (row.id === id ? { ...row, ...patch } : row)));

	const copy = async (row: Row) => {
		if (!row.public_share_token) return;
		try {
			await navigator.clipboard.writeText(buildPublicArticleUrl(row.public_share_token));
			setCopiedId(row.id);
			setTimeout(() => setCopiedId((current) => (current === row.id ? null : current)), 2000);
		} catch {
			setError('Could not copy the link');
		}
	};

	// Change validity (active link, same token) or renew (expired link, new token)
	const setValidity = async (row: Row, validity: PublicLinkValidity) => {
		patchRow(row.id, { busy: true });
		setError(null);
		try {
			const { token, expiresAt } = await enablePublicLink(row.id, validity);
			patchRow(row.id, {
				busy: false,
				public_share_token: token,
				public_link_expires_at: expiresAt,
				public_link_validity_days: validity,
				public_shared_at: isPublicLinkActive(row.public_share_token, row.public_link_expires_at)
					? row.public_shared_at
					: new Date().toISOString(),
			});
		} catch (e) {
			console.error('Failed to update public link:', e);
			patchRow(row.id, { busy: false });
			setError('Could not update the public link');
		}
	};

	const revoke = async (row: Row) => {
		setConfirmRevoke(null);
		patchRow(row.id, { busy: true });
		setError(null);
		try {
			await disablePublicLink(row.id);
			setRows((prev) => prev.filter((r) => r.id !== row.id));
		} catch (e) {
			console.error('Failed to revoke public link:', e);
			patchRow(row.id, { busy: false });
			setError('Could not revoke the public link');
		}
	};

	if (authLoading) {
		return (
			<div className="flex min-h-screen items-center justify-center bg-app-page">
				<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
			</div>
		);
	}

	if (!user) return null;

	const renderRow = (row: Row) => {
		const isActive = isPublicLinkActive(row.public_share_token, row.public_link_expires_at);
		const url = row.public_share_token ? buildPublicArticleUrl(row.public_share_token) : '';
		const selected = validityFromExpiry(row.public_link_expires_at, row.public_link_validity_days);

		return (
			<div key={row.id} className={`border-b border-app-line px-4 py-4 last:border-b-0 sm:px-5 ${row.busy ? 'opacity-60' : ''}`}>
				<div className="flex items-start gap-3.5">
					{/* Thumb */}
					<Link
						href={`/articles/${row.id}`}
						className="relative h-[56px] w-[56px] flex-none overflow-hidden rounded-2xl bg-app-surface"
					>
						{row.image_url ? (
							// eslint-disable-next-line @next/next/no-img-element
							<img src={row.image_url} alt="" className="washed h-full w-full object-cover" />
						) : (
							<span className="flex h-full w-full items-center justify-center">
								<BookOpen size={20} className="text-accent opacity-50" strokeWidth={1.75} />
							</span>
						)}
					</Link>

					<div className="min-w-0 flex-1">
						{row.domain && <div className="text-[12px] font-semibold text-app-muted">{row.domain}</div>}
						<Link
							href={`/articles/${row.id}`}
							className="line-clamp-2 text-[15.5px] font-bold leading-[1.3] text-ink hover:text-accent"
						>
							{row.title}
						</Link>

						{/* Status */}
						<div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1.5 text-[12.5px]">
							<span
								className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 font-bold ${
									isActive ? 'bg-sage-200 text-sage-800' : 'bg-app-surface text-app-muted'
								}`}
							>
								{isActive ? 'Active' : 'Expired'}
							</span>
							<span className="inline-flex items-center gap-1 text-ink">
								{row.public_link_expires_at ? <Clock size={13} strokeWidth={2.5} /> : <InfinityIcon size={14} strokeWidth={2.5} />}
								{formatPublicLinkValidity(row.public_link_validity_days, row.public_link_expires_at)}
							</span>
							{row.public_link_expires_at && (
								<span className="text-app-muted" title={formatDateTime(row.public_link_expires_at)}>
									{isActive ? 'Expires' : 'Expired'} {formatRelative(row.public_link_expires_at)} ·{' '}
									{formatDateTime(row.public_link_expires_at)}
								</span>
							)}
							{row.public_shared_at && (
								<span className="text-app-muted">Shared {formatRelative(row.public_shared_at)}</span>
							)}
						</div>
					</div>
				</div>

				{/* Actions */}
				<div className="mt-3 flex flex-wrap items-center gap-2 sm:pl-[70px]">
					{isActive ? (
						<>
							<button
								type="button"
								onClick={() => copy(row)}
								disabled={row.busy}
								className="flex h-[32px] items-center gap-1.5 rounded-full bg-accent px-3 text-[12.5px] font-semibold text-app-page transition-colors hover:bg-accent-600"
							>
								{copiedId === row.id ? <Check size={14} strokeWidth={2.75} /> : <Link2 size={14} strokeWidth={2.75} />}
								{copiedId === row.id ? 'Copied' : 'Copy link'}
							</button>
							<a
								href={url}
								target="_blank"
								rel="noopener noreferrer"
								className="flex h-[32px] items-center gap-1.5 rounded-full border border-app-line px-3 text-[12.5px] font-semibold text-ink transition-colors hover:bg-app-hover"
							>
								<ExternalLink size={14} strokeWidth={2.75} />
								Open
							</a>
						</>
					) : (
						<button
							type="button"
							onClick={() => setValidity(row, selected)}
							disabled={row.busy}
							className="flex h-[32px] items-center gap-1.5 rounded-full bg-accent px-3 text-[12.5px] font-semibold text-app-page transition-colors hover:bg-accent-600"
						>
							<RotateCcw size={14} strokeWidth={2.75} />
							Renew (new link)
						</button>
					)}

					{/* Validity */}
					<div className="flex rounded-full border border-app-line p-0.5" role="radiogroup" aria-label="Link validity">
						{PUBLIC_LINK_VALIDITY_OPTIONS.map((option) => {
							const isSelected = isActive && option.value === selected;
							return (
								<button
									key={option.label}
									type="button"
									role="radio"
									aria-checked={isSelected}
									disabled={row.busy}
									onClick={() => setValidity(row, option.value)}
									title={isActive ? 'Change validity (same link)' : 'Renew with this validity (new link)'}
									className={`rounded-full px-2.5 py-1 text-[12px] font-semibold transition-colors ${
										isSelected ? 'bg-ink text-app-page' : 'text-ink hover:bg-app-hover'
									}`}
								>
									{option.label}
								</button>
							);
						})}
					</div>

					<button
						type="button"
						onClick={() => setConfirmRevoke(row)}
						disabled={row.busy}
						className="ml-auto flex h-[32px] items-center gap-1 rounded-full px-2.5 text-[12.5px] font-semibold text-app-muted transition-colors hover:bg-app-hover hover:text-accent"
					>
						<X size={14} strokeWidth={2.75} />
						{isActive ? 'Revoke' : 'Remove'}
					</button>
				</div>
			</div>
		);
	};

	return (
		<AppShell>
			<div className="mx-auto max-w-[820px] px-4 py-6 sm:px-9 sm:py-8">
				<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
					{active.length} active{expired.length > 0 && ` · ${expired.length} expired`}
				</div>
				<h1 className="mt-1 font-heading text-[30px] leading-none text-ink sm:text-[34px]">Public links</h1>
				<p className="mt-3 max-w-[560px] text-[13.5px] leading-[1.6] text-app-muted">
					Articles anyone can read through a link, without an account. Changing the validity keeps the same link;
					revoking it stops the link immediately.
				</p>

				{error && <p className="mt-4 text-[13px] font-semibold text-accent">{error}</p>}

				{loading ? (
					<div className="mt-6 h-64 animate-pulse rounded-[28px] border border-app-line bg-app-card" />
				) : rows.length === 0 ? (
					<div className="mt-6 rounded-[28px] border border-app-line bg-app-card px-6 py-20 text-center">
						<div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-app-surface">
							<Globe size={28} className="text-accent opacity-60" strokeWidth={1.75} />
						</div>
						<p className="font-heading text-[21px] text-ink">No public links</p>
						<p className="mt-1.5 text-[13.5px] text-app-muted">
							Open an article and use the globe button to share it with anyone.
						</p>
					</div>
				) : (
					<>
						{active.length > 0 && (
							<div className="mt-6 overflow-hidden rounded-[28px] border border-app-line bg-app-card">{active.map(renderRow)}</div>
						)}
						{expired.length > 0 && (
							<>
								<div className="mt-8 px-1 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">Expired</div>
								<div className="mt-2 overflow-hidden rounded-[28px] border border-app-line bg-app-card">{expired.map(renderRow)}</div>
							</>
						)}
					</>
				)}
			</div>

			{/* Revoke confirmation */}
			{confirmRevoke && (
				<div
					className="fixed inset-0 z-50 grid place-items-center p-4"
					style={{ background: 'rgba(32,30,29,.42)' }}
					onClick={() => setConfirmRevoke(null)}
				>
					<div
						className="w-full max-w-[440px] rounded-[28px] border border-app-line bg-app-card p-6 [box-shadow:var(--shadow-modal)]"
						onClick={(e) => e.stopPropagation()}
					>
						<h2 className="font-heading text-[24px] text-ink">Revoke public link</h2>
						<p className="mt-2 text-[13.5px] text-app-muted">
							&quot;{confirmRevoke.title}&quot; will no longer be readable by people who have the link.
						</p>
						<div className="mt-6 flex justify-end gap-2.5">
							<button
								type="button"
								onClick={() => setConfirmRevoke(null)}
								className="rounded-full border border-app-line px-4 py-2 text-[13.5px] font-semibold text-ink transition-colors hover:bg-app-hover"
							>
								Cancel
							</button>
							<button
								type="button"
								onClick={() => revoke(confirmRevoke)}
								className="rounded-full bg-accent px-4 py-2 text-[13.5px] font-semibold text-app-page transition-colors hover:bg-accent-600"
							>
								Revoke
							</button>
						</div>
					</div>
				</div>
			)}
		</AppShell>
	);
}
