'use client';

import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useRouter } from 'next/navigation';

function Brand() {
	return (
		<div className="flex items-center gap-2.5">
			<span className="flex h-11 w-11 items-center justify-center rounded-full bg-accent font-heading text-[22px] text-app-page">
				Z
			</span>
			<span className="font-heading text-[28px] text-ink">Zuper Reader</span>
		</div>
	);
}

export default function LoginPage() {
	const [email, setEmail] = useState('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState('');
	const [success, setSuccess] = useState(false);
	// Manual link verification
	const [manualLink, setManualLink] = useState('');
	const [showManual, setShowManual] = useState(false);
	const [verifyingLink, setVerifyingLink] = useState(false);
	const [linkError, setLinkError] = useState('');
	const { signInWithOtp, verifyTokenHash } = useAuth();

	const router = useRouter();

	const handleManualLinkSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		if (!manualLink.trim()) return;

		setVerifyingLink(true);
		setLinkError('');

		try {
			let urlObj: URL;
			try {
				urlObj = new URL(manualLink);
			} catch {
				throw new Error('Invalid URL format');
			}

			const token_hash = urlObj.searchParams.get('token_hash');
			const type = urlObj.searchParams.get('type');

			if (!token_hash || !type) {
				throw new Error('Invalid magic link: missing token or type');
			}

			const { error } = await verifyTokenHash(token_hash, type);
			if (error) throw error;

			router.push('/');
		} catch (err) {
			setLinkError(err instanceof Error ? err.message : 'Failed to verify link');
			setVerifyingLink(false);
		}
	};

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');

		const { error } = await signInWithOtp(email);

		if (error) {
			setError(error.message);
			setLoading(false);
		} else {
			setSuccess(true);
			setLoading(false);
		}
	};

	const handleResendLink = async () => {
		setLoading(true);
		const { error } = await signInWithOtp(email);
		setLoading(false);
		if (error) setError(error.message);
	};

	const manualLinkField = (
		<form onSubmit={handleManualLinkSubmit} className="mt-4 space-y-2.5 text-left">
			<input
				type="text"
				value={manualLink}
				onChange={(e) => setManualLink(e.target.value)}
				placeholder="azreader://auth/confirm?..."
				disabled={verifyingLink}
				className="w-full rounded-full border border-app-line bg-app-surface px-[18px] py-[13px] text-[13px] text-ink placeholder:text-app-muted focus:border-accent focus:outline-none disabled:opacity-50"
			/>
			{linkError && <p className="px-1 text-[12.5px] text-accent">{linkError}</p>}
			<button
				type="submit"
				disabled={verifyingLink || !manualLink}
				className="w-full rounded-full bg-accent px-4 py-3 font-heading text-[15px] text-app-page transition-colors hover:bg-accent-600 disabled:opacity-50"
			>
				{verifyingLink ? 'Verifying…' : 'Verify link'}
			</button>
		</form>
	);

	if (success) {
		return (
			<div className="grid min-h-screen place-items-center bg-app-page px-4">
				<div className="w-full max-w-[420px] text-center">
					<div className="flex justify-center">
						<Brand />
					</div>
					<h1 className="text-pretty mt-8 font-heading text-[38px] leading-[1.05] text-ink">
						Check your email.
					</h1>
					<p className="mt-3 text-[14px] text-app-muted">
						We sent a magic link to <span className="font-semibold text-ink">{email}</span>. Click it to
						sign in — you can close this tab.
					</p>

					{manualLinkField}

					<div className="mt-6 flex flex-col gap-2 text-[12.5px] text-app-muted">
						<button onClick={handleResendLink} disabled={loading} className="text-accent hover:underline disabled:opacity-50">
							{loading ? 'Sending…' : "Didn't get it? Resend"}
						</button>
						<button onClick={() => setSuccess(false)} className="hover:text-ink">
							← Try a different email
						</button>
					</div>
				</div>
			</div>
		);
	}

	return (
		<div className="grid min-h-screen place-items-center bg-app-page px-4">
			<div className="w-full max-w-[420px]">
				<Brand />
				<h1 className="text-pretty mt-8 font-heading text-[38px] leading-[1.05] text-ink">
					Read what you saved.
				</h1>
				<p className="mt-3 text-[14px] text-app-muted">
					Sign in with a magic link — no password needed.
				</p>

				<form onSubmit={handleSubmit} className="mt-7">
					<label htmlFor="email" className="mb-1.5 block text-[12px] font-medium text-app-muted">
						Email
					</label>
					<input
						id="email"
						type="email"
						value={email}
						onChange={(e) => setEmail(e.target.value)}
						required
						placeholder="you@example.com"
						className="w-full rounded-full border border-app-line bg-app-surface px-[18px] py-[13px] text-[14px] text-ink placeholder:text-app-muted focus:border-accent focus:outline-none"
					/>

					{error && <p className="mt-2 px-1 text-[12.5px] text-accent">{error}</p>}

					<button
						type="submit"
						disabled={loading}
						className="mt-4 w-full rounded-full bg-accent px-4 py-3.5 font-heading text-[15px] text-app-page transition-colors hover:bg-accent-600 disabled:opacity-50"
					>
						{loading ? 'Sending…' : 'Send magic link'}
					</button>
				</form>

				<p className="mt-5 text-center text-[12.5px] text-app-muted">
					Already have a link?{' '}
					<button onClick={() => setShowManual((v) => !v)} className="text-accent hover:underline">
						Paste it here
					</button>
				</p>

				{showManual && manualLinkField}
			</div>
		</div>
	);
}
