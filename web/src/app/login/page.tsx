'use client';

import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';

export default function LoginPage() {
	const [email, setEmail] = useState('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState('');
	const [success, setSuccess] = useState(false);
	const { signInWithOtp } = useAuth();

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
		}
	};

	if (success) {
		return (
			<div className="min-h-screen flex items-center justify-center bg-gray-100 py-12 px-4">
				<div className="max-w-md w-full bg-white rounded-lg shadow-md p-8 text-center">
					<h1 className="text-2xl font-bold text-gray-900 mb-4">Check your email</h1>
					<p className="text-gray-600 mb-6">
						We've sent a magic link to <span className="font-semibold">{email}</span>. Click the link to sign in.
					</p>
					<button
						onClick={() => setSuccess(false)}
						className="text-blue-600 hover:underline"
					>
						Try different email
					</button>
				</div>
			</div>
		);
	}

	return (
		<div className="min-h-screen flex items-center justify-center bg-gray-100 py-12 px-4">
			<div className="max-w-md w-full bg-white rounded-lg shadow-md p-8">
				<h1 className="text-2xl font-bold text-center text-gray-900 mb-2">Welcome</h1>
				<p className="text-center text-gray-600 mb-8">Sign in with Magic Link</p>

				<form onSubmit={handleSubmit} className="space-y-6">
					<div>
						<label htmlFor="email" className="block text-sm font-medium text-gray-700">
							Email
						</label>
						<input
							id="email"
							type="email"
							value={email}
							onChange={(e) => setEmail(e.target.value)}
							required
							placeholder="you@example.com"
							className="mt-1 w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900"
						/>
					</div>

					{error && <p className="text-red-500 text-sm">{error}</p>}

					<button
						type="submit"
						disabled={loading}
						className="w-full py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors font-medium"
					>
						{loading ? 'Sending Magic Link...' : 'Send Magic Link'}
					</button>
				</form>
			</div>
		</div>
	);
}
