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
			} catch (err) {
				setError(err instanceof Error ? err.message : 'Verification failed');
				setVerifying(false);
			}
		};

		verifyUser();
	}, [searchParams, router]);

	return (
		<div className="max-w-md w-full relative">
			<div className="bg-white/95 backdrop-blur-xl rounded-3xl shadow-2xl p-8 md:p-10 text-center border border-white/20 animate-fade-in-up">
				{verifying ? (
					<div>
						{/* Loading Icon */}
						<div className="w-24 h-24 mx-auto mb-6 relative">
							<div className="absolute inset-0 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full animate-pulse"></div>
							<div className="absolute inset-2 bg-white rounded-full flex items-center justify-center">
								<svg className="w-12 h-12 text-indigo-600 animate-spin-slow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
								</svg>
							</div>
						</div>

						<h2 className="text-3xl font-bold text-gray-900 mb-3">
							Verifying your login
						</h2>
						<p className="text-gray-600 mb-6">
							Please wait while we securely verify your identity...
						</p>

						{/* Loading dots */}
						<div className="flex justify-center space-x-2">
							<div className="w-2 h-2 bg-indigo-600 rounded-full animate-bounce"></div>
							<div className="w-2 h-2 bg-purple-600 rounded-full animate-bounce delay-100"></div>
							<div className="w-2 h-2 bg-pink-600 rounded-full animate-bounce delay-200"></div>
						</div>
					</div>
				) : error ? (
					<div>
						{/* Error Icon */}
						<div className="w-20 h-20 mx-auto mb-6 bg-gradient-to-br from-red-400 to-rose-500 rounded-full flex items-center justify-center shadow-lg animate-scale-in">
							<svg className="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
							</svg>
						</div>

						<h2 className="text-3xl font-bold text-gray-900 mb-3">
							Verification Failed
						</h2>
						<div className="bg-red-50 border border-red-200 rounded-xl p-4 mb-6">
							<p className="text-red-700 font-medium">{error}</p>
						</div>
						<p className="text-gray-600 mb-6 text-sm">
							This link may have expired or is invalid. Please try logging in again.
						</p>
						<button
							onClick={() => router.push('/login')}
							className="px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all font-semibold shadow-lg hover:shadow-xl transform hover:scale-[1.02] active:scale-[0.98] inline-flex items-center space-x-2"
						>
							<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
							</svg>
							<span>Back to Login</span>
						</button>
					</div>
				) : null}
			</div>
		</div>
	);
}

export default function ConfirmPage() {
	return (
		<div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 py-12 px-4 relative overflow-hidden">
			{/* Animated background elements */}
			<div className="absolute inset-0 overflow-hidden">
				<div className="absolute top-1/3 left-1/3 w-96 h-96 bg-white/10 rounded-full blur-3xl animate-float"></div>
				<div className="absolute bottom-1/3 right-1/3 w-96 h-96 bg-white/10 rounded-full blur-3xl animate-float-delay"></div>
			</div>

			<Suspense
				fallback={
					<div className="max-w-md w-full relative">
						<div className="bg-white/95 backdrop-blur-xl rounded-3xl shadow-2xl p-8 md:p-10 text-center border border-white/20">
							<div className="animate-spin rounded-full h-12 w-12 border-4 border-indigo-600 border-t-transparent mx-auto"></div>
							<p className="mt-4 text-gray-600">Loading...</p>
						</div>
					</div>
				}
			>
				<ConfirmContent />
			</Suspense>

			<style jsx>{`
				@keyframes fade-in-up {
					from {
						opacity: 0;
						transform: translateY(20px);
					}
					to {
						opacity: 1;
						transform: translateY(0);
					}
				}

				@keyframes float {
					0%, 100% {
						transform: translateY(0) translateX(0);
					}
					50% {
						transform: translateY(-20px) translateX(10px);
					}
				}

				@keyframes float-delay {
					0%, 100% {
						transform: translateY(0) translateX(0);
					}
					50% {
						transform: translateY(20px) translateX(-10px);
					}
				}

				@keyframes scale-in {
					from {
						transform: scale(0);
					}
					to {
						transform: scale(1);
					}
				}

				@keyframes spin-slow {
					from {
						transform: rotate(0deg);
					}
					to {
						transform: rotate(360deg);
					}
				}

				.animate-fade-in-up {
					animation: fade-in-up 0.6s ease-out;
				}

				.animate-float {
					animation: float 8s ease-in-out infinite;
				}

				.animate-float-delay {
					animation: float-delay 8s ease-in-out infinite;
				}

				.animate-scale-in {
					animation: scale-in 0.5s ease-out;
				}

				.animate-spin-slow {
					animation: spin-slow 2s linear infinite;
				}

				.delay-100 {
					animation-delay: 0.1s;
				}

				.delay-200 {
					animation-delay: 0.2s;
				}
			`}</style>
		</div>
	);
}
