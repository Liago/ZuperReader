'use client';

import { useEffect, useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '../../../lib/supabase';
import { EmailOtpType } from '@supabase/supabase-js';

function ConfirmContent() {
	const router = useRouter();
	const searchParams = useSearchParams();
	const [error, setError] = useState('');
	const [verifying, setVerifying] = useState(true);

	useEffect(() => {
		const verifyUser = async () => {
			const token_hash = searchParams.get('token_hash');
			const type = searchParams.get('type') as EmailOtpType | null;

			if (!token_hash || !type) {
				setError('Invalid verification link');
				setVerifying(false);
				return;
			}

			try {
				const { error } = await supabase.auth.verifyOtp({
					token_hash,
					type,
				});

				if (error) {
					throw error;
				}

				// Verification successful, redirect to home
				router.push('/');
			} catch (err: any) {
				setError(err.message || 'Verification failed');
				setVerifying(false);
			}
		};

		verifyUser();
	}, [searchParams, router]);

	return (
		<div className="max-w-md w-full bg-white rounded-lg shadow-md p-8 text-center">
			{verifying ? (
				<div>
					<h2 className="text-2xl font-bold mb-4">Verifying your login...</h2>
					<div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
				</div>
			) : error ? (
				<div>
					<h2 className="text-2xl font-bold text-red-600 mb-4">Verification Failed</h2>
					<p className="text-gray-600 mb-6">{error}</p>
					<button
						onClick={() => router.push('/login')}
						className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
					>
						Back to Login
					</button>
				</div>
			) : null}
		</div>
	);
}

export default function ConfirmPage() {
	return (
		<div className="min-h-screen flex items-center justify-center bg-gray-100 px-4">
			<Suspense fallback={<div>Loading...</div>}>
				<ConfirmContent />
			</Suspense>
		</div>
	);
}
