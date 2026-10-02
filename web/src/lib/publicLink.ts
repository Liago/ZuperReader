import type { PublicLinkValidity } from './supabase';

export const PUBLIC_LINK_VALIDITY_OPTIONS: { value: PublicLinkValidity; label: string }[] = [
	{ value: 1, label: '1 day' },
	{ value: 7, label: '1 week' },
	{ value: null, label: 'Never' },
];

/** True when there is a token and it has not expired yet. */
export function isPublicLinkActive(token: string | null | undefined, expiresAt: string | null | undefined): boolean {
	if (!token) return false;
	return !expiresAt || new Date(expiresAt).getTime() > Date.now();
}

/** Human readable expiry, e.g. "Expires Oct 1, 3:26 PM" or "Never expires". */
export function formatPublicLinkExpiry(expiresAt: string | null | undefined): string {
	if (!expiresAt) return 'Never expires';
	const date = new Date(expiresAt);
	return `Expires ${date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}, ${date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`;
}

/**
 * Currently selected validity: the stored one when available, otherwise
 * inferred from the expiry (links created before the validity was stored).
 */
export function validityFromExpiry(expiresAt: string | null | undefined, storedDays?: number | null): PublicLinkValidity {
	if (storedDays === 1 || storedDays === 7) return storedDays;
	if (!expiresAt) return null;
	const hoursLeft = (new Date(expiresAt).getTime() - Date.now()) / 36e5;
	return hoursLeft > 24 ? 7 : 1;
}

/** Label of the validity picked by the owner. */
export function formatPublicLinkValidity(storedDays: number | null | undefined, expiresAt: string | null | undefined): string {
	if (storedDays === 1) return '1 day';
	if (storedDays === 7) return '1 week';
	return expiresAt ? 'Custom' : 'Never expires';
}

/** "in 5 hours", "2 days ago"… */
export function formatRelative(date: string | Date): string {
	const target = typeof date === 'string' ? new Date(date) : date;
	const seconds = Math.round((target.getTime() - Date.now()) / 1000);
	const units: [Intl.RelativeTimeFormatUnit, number][] = [
		['day', 86400],
		['hour', 3600],
		['minute', 60],
	];
	const rtf = new Intl.RelativeTimeFormat('en-US', { numeric: 'auto' });
	for (const [unit, size] of units) {
		if (Math.abs(seconds) >= size) return rtf.format(Math.round(seconds / size), unit);
	}
	return rtf.format(seconds, 'second');
}

/** Absolute date + time, e.g. "Oct 3, 4:12 PM". */
export function formatDateTime(date: string): string {
	const d = new Date(date);
	return `${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}, ${d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`;
}
