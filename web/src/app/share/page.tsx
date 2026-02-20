'use client';

import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useAuth } from '../../contexts/AuthContext';
import { parseArticle, saveArticle } from '../../lib/api';

function ShareContent() {
	const searchParams = useSearchParams();
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const [status, setStatus] = useState<'initializing' | 'authenticating' | 'parsing' | 'saving' | 'success' | 'error'>('initializing');
	const [errorMessage, setErrorMessage] = useState<string>('');

	useEffect(() => {
		if (authLoading) {
			setStatus('authenticating');
			return;
		}

		if (!user) {
			// If not logged in, redirect to login, passing the current share URL so we can return here?
			// For simplicity and security, it's better to just go to login.
			// The URL parameters might be lost if we don't pass them in the redirect query.
			const currentUrl = encodeURIComponent(`/share?${searchParams.toString()}`);
			router.push(`/login?redirect=${currentUrl}`);
			return;
		}

		const processShare = async () => {
			try {
				// The URL could be passed in the 'url', 'text', or 'title' param depending on the OS/app sharing it.
				const urlParam = searchParams.get('url');
				const textParam = searchParams.get('text');
				const titleParam = searchParams.get('title');

				// Heuristic to find the actual URL:
				let targetUrl = urlParam;

				if (!targetUrl && textParam) {
					// Sometimes the URL is sent in the text field (e.g., from some native Android apps)
					// Try to extract a URL from the text
					const urlRegex = /(https?:\/\/[^\s]+)/g;
					const matches = textParam.match(urlRegex);
					if (matches && matches.length > 0) {
						targetUrl = matches[0];
					}
				}

				if (!targetUrl) {
					console.error("Share target parameters:", { urlParam, textParam, titleParam });
					throw new Error('No valid URL found to share.');
				}

				// Basic URL validation
				if (!targetUrl.startsWith('http')) {
					throw new Error(`Invalid URL format: ${targetUrl}`);
				}

				setStatus('parsing');
				const parsedData = await parseArticle(targetUrl);

				setStatus('saving');
				await saveArticle(parsedData, user.id);

				setStatus('success');
				// Automatically redirect to home after a brief delay
				setTimeout(() => {
					router.push('/');
				}, 1500);

			} catch (error) {
				console.error("Error processing shared article:", error);
				setStatus('error');
				setErrorMessage(error instanceof Error ? error.message : 'An unknown error occurred.');
			}
		};

		processShare();
	}, [user, authLoading, searchParams, router]);

	return (
		<div className="min-h-screen app-bg-gradient flex flex-col justify-center items-center p-4">
			<div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8 max-w-sm w-full text-center">
				<div className="mb-6">
					<div className="w-16 h-16 bg-gradient-to-br from-purple-500 to-pink-500 rounded-2xl mx-auto flex items-center justify-center shadow-lg">
						<svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
						</svg>
					</div>
				</div>

				<h1 className="text-2xl font-bold bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent mb-2">
					Saving Article
				</h1>

				<div className="py-4">
					{status === 'initializing' || status === 'authenticating' ? (
						<div className="flex flex-col items-center gap-3">
							<div className="w-6 h-6 border-2 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
							<p className="text-gray-500 dark:text-gray-400 text-sm">Please wait...</p>
						</div>
					) : status === 'parsing' ? (
						<div className="flex flex-col items-center gap-3">
							<div className="w-6 h-6 border-2 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
							<p className="text-gray-500 dark:text-gray-400 text-sm">Reading the article...</p>
						</div>
					) : status === 'saving' ? (
						<div className="flex flex-col items-center gap-3">
							<div className="w-6 h-6 border-2 border-pink-200 border-t-pink-600 rounded-full animate-spin"></div>
							<p className="text-gray-500 dark:text-gray-400 text-sm">Saving to your list...</p>
						</div>
					) : status === 'success' ? (
						<div className="flex flex-col items-center gap-3 animate-fade-in">
							<div className="w-12 h-12 bg-green-100 dark:bg-green-900/40 rounded-full flex items-center justify-center text-green-600 dark:text-green-400">
								<svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
								</svg>
							</div>
							<p className="text-green-600 dark:text-green-400 font-medium">Successfully saved!</p>
							<p className="text-sm text-gray-500 dark:text-gray-400">Redirecting to your library...</p>
						</div>
					) : (
						<div className="flex flex-col items-center gap-4">
							<div className="bg-red-50 dark:bg-red-900/30 p-3 rounded-xl border border-red-200 dark:border-red-800 w-full text-left">
								<p className="text-red-800 dark:text-red-200 text-sm font-medium break-words">
									{errorMessage}
								</p>
							</div>
							<button
								onClick={() => router.push('/')}
								className="mt-2 px-6 py-2 bg-gray-100 dark:bg-slate-700 text-gray-700 dark:text-gray-200 font-medium rounded-xl hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors"
							>
								Back to Home
							</button>
						</div>
					)}
				</div>
			</div>
		</div>
	);
}

export default function SharePage() {
	return (
		<Suspense fallback={
			<div className="min-h-screen flex items-center justify-center app-bg-gradient">
				<div className="w-12 h-12 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
			</div>
		}>
			<ShareContent />
		</Suspense>
	);
}
