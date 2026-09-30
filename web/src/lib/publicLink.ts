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

/** Infer the currently selected validity from the expiry (closest option). */
export function validityFromExpiry(expiresAt: string | null | undefined): PublicLinkValidity {
	if (!expiresAt) return null;
	const hoursLeft = (new Date(expiresAt).getTime() - Date.now()) / 36e5;
	return hoursLeft > 24 ? 7 : 1;
}
