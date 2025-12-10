'use client';

import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
	const [email, setEmail] = useState('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState('');
	const [success, setSuccess] = useState(false);
	// Manual Link Verification
	const [manualLink, setManualLink] = useState('');
	const [verifyingLink, setVerifyingLink] = useState(false);
	const [linkError, setLinkError] = useState('');
	const { signInWithOtp, verifyTokenHash } = useAuth();

	const router = useRouter();

	// Handle manually pasted Magic Link
	const handleManualLinkSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		if (!manualLink.trim()) return;

		setVerifyingLink(true);
		setLinkError('');

		try {
			// Extract token_hash and type from the URL
			// Expected format: azreader://auth/confirm?token_hash=...&type=...
			let urlObj;
			try {
				urlObj = new URL(manualLink);
			} catch (err) {
				// If it's not a valid URL, try to prepend a protocol if missing, though azreader:// should be there
				throw new Error('Invalid URL format');
			}

			const token_hash = urlObj.searchParams.get('token_hash');
			const type = urlObj.searchParams.get('type');

			if (!token_hash || !type) {
				throw new Error('Invalid Magic Link: missing token or type');
			}

			const { error } = await verifyTokenHash(token_hash, type);

			if (error) {
				throw error;
			}

			// Success - redirect to home
			router.push('/');

		} catch (err: any) {
			setLinkError(err.message || 'Failed to verify link');
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

	// Resend Magic Link
	const handleResendLink = async () => {
		setLoading(true);

		const { error } = await signInWithOtp(email);

		setLoading(false);
		if (error) {
			setError(error.message);
		} else {
			// Optional: Show a toast or small message that link was resent
			// For now, staying on the success screen is enough
		}
	};

	if (success) {
		return (
			<div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 py-12 px-4 relative overflow-hidden">
				{/* Animated background elements */}
				<div className="absolute inset-0 overflow-hidden">
					<div className="absolute -top-1/2 -left-1/2 w-full h-full bg-white/10 rounded-full blur-3xl animate-pulse"></div>
					<div className="absolute -bottom-1/2 -right-1/2 w-full h-full bg-white/10 rounded-full blur-3xl animate-pulse delay-1000"></div>
				</div>

				<div className="max-w-md w-full relative">
					<div className="bg-white/95 backdrop-blur-xl rounded-3xl shadow-2xl p-8 md:p-10 text-center border border-white/20 animate-fade-in-up">
						{/* Email Icon */}
						<div className="w-20 h-20 mx-auto mb-6 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-full flex items-center justify-center shadow-lg animate-scale-in">
							<svg className="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
							</svg>
						</div>

						<h1 className="text-3xl font-bold text-gray-900 mb-4">
							Check your email
						</h1>
						<p className="text-gray-600 mb-2 text-lg">
							We&apos;ve sent a magic link to
						</p>
						<p className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-600 to-purple-600 font-bold text-xl mb-6">
							{email}
						</p>
						<p className="text-gray-500 text-sm mb-6">
							Click the link in the email to sign in. You can close this tab.
						</p>

						{/* Manual Link Entry */}
						<div className="mb-8">
							<div className="relative">
								<div className="absolute inset-0 flex items-center">
									<div className="w-full border-t border-gray-200"></div>
								</div>
								<div className="relative flex justify-center text-sm">
									<span className="px-2 bg-white text-gray-400">or paste the link here</span>
								</div>
							</div>

							<form onSubmit={handleManualLinkSubmit} className="mt-4 space-y-3">
								<div className="relative">
									<input
										type="text"
										value={manualLink}
										onChange={(e) => setManualLink(e.target.value)}
										placeholder="azreader://auth/confirm?..."
										className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all text-gray-900"
										disabled={verifyingLink}
									/>
								</div>

								{linkError && (
									<p className="text-red-500 text-xs text-left ml-1">{linkError}</p>
								)}

								<button
									type="submit"
									disabled={verifyingLink || !manualLink}
									className="w-full py-2.5 bg-gray-900 text-white rounded-xl hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all font-medium text-sm shadow-sm"
								>
									{verifyingLink ? 'Verifying...' : 'Verify Link'}
								</button>
							</form>
						</div>

						<div className="space-y-4">
							<button
								onClick={handleResendLink}
								disabled={loading}
								className="text-indigo-600 hover:text-indigo-700 font-medium text-sm transition-all hover:underline underline-offset-4 disabled:opacity-50 disabled:cursor-not-allowed"
							>
								{loading ? 'Sending...' : "Didn't receive the email? Resend"}
							</button>

							<div className="block">
								<button
									onClick={() => setSuccess(false)}
									className="text-gray-500 hover:text-gray-700 font-medium text-sm transition-all hover:underline underline-offset-4"
								>
									← Try a different email
								</button>
							</div>
						</div>
					</div>
				</div>
			</div>
		);
	}

	return (
		<div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 py-12 px-4 relative overflow-hidden">
			{/* Animated background elements */}
			<div className="absolute inset-0 overflow-hidden">
				<div className="absolute top-1/4 left-1/4 w-96 h-96 bg-white/10 rounded-full blur-3xl animate-float"></div>
				<div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-white/10 rounded-full blur-3xl animate-float-delay"></div>
			</div>

			<div className="max-w-md w-full relative">
				<div className="bg-white/95 backdrop-blur-xl rounded-3xl shadow-2xl p-8 md:p-10 border border-white/20 animate-fade-in-up">
					{/* Logo/Brand */}
					<div className="text-center mb-8">
						<div className="w-16 h-16 mx-auto mb-4 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-2xl flex items-center justify-center shadow-lg transform hover:scale-105 transition-transform">
							<svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
							</svg>
						</div>
						<h1 className="text-3xl font-bold text-gray-900 mb-2">
							Welcome to ZuperReader
						</h1>
						<p className="text-gray-600">
							Sign in with a magic link – no password needed
						</p>
					</div>

					<form onSubmit={handleSubmit} className="space-y-6">
						<div className="space-y-2">
							<label htmlFor="email" className="block text-sm font-semibold text-gray-700">
								Email Address
							</label>
							<div className="relative">
								<div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
									<svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
									</svg>
								</div>
								<input
									id="email"
									type="email"
									value={email}
									onChange={(e) => setEmail(e.target.value)}
									required
									placeholder="you@example.com"
									className="w-full pl-12 pr-4 py-3.5 border-2 border-gray-200 rounded-xl focus:ring-4 focus:ring-indigo-500/20 focus:border-indigo-500 transition-all text-gray-900 placeholder:text-gray-400"
								/>
							</div>
						</div>

						{error && (
							<div className="flex items-start space-x-2 p-3 bg-red-50 border border-red-200 rounded-xl animate-shake">
								<svg className="w-5 h-5 text-red-500 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
									<path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
								</svg>
								<p className="text-red-700 text-sm font-medium">{error}</p>
							</div>
						)}

						<button
							type="submit"
							disabled={loading}
							className="w-full py-4 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all font-semibold shadow-lg hover:shadow-xl transform hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center space-x-2"
						>
							{loading ? (
								<>
									<svg className="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
										<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
										<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
									</svg>
									<span>Sending...</span>
								</>
							) : (
								<>
									<span>Send Magic Link</span>
									<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
									</svg>
								</>
							)}
						</button>
					</form>

					<div className="mt-6 text-center">
						<p className="text-xs text-gray-500">
							By signing in, you agree to our Terms of Service and Privacy Policy
						</p>
					</div>
				</div>
			</div>

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

				@keyframes shake {
					0%, 100% { transform: translateX(0); }
					25% { transform: translateX(-5px); }
					75% { transform: translateX(5px); }
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

				.animate-shake {
					animation: shake 0.3s ease-in-out;
				}
			`}</style>
		</div>
	);
}
