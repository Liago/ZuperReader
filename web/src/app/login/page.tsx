'use client';

import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

export default function LoginPage() {
	const [email, setEmail] = useState('');
	const [password, setPassword] = useState('');
	const [error, setError] = useState('');
	const [loading, setLoading] = useState(false);
	const { signIn } = useAuth();
	const router = useRouter();

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');

		const { error } = await signIn(email, password);

		if (error) {
			setError(error.message);
			setLoading(false);
		} else {
			router.push('/');
		}
	};

	return (
		<div className="min-h-screen flex items-center justify-center bg-gray-100 py-12 px-4">
			<div className="max-w-md w-full bg-white rounded-lg shadow-md p-8">
				<h1 className="text-2xl font-bold text-center text-gray-900 mb-8">Sign In</h1>

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
							className="mt-1 w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900"
						/>
					</div>

					<div>
						<label htmlFor="password" className="block text-sm font-medium text-gray-700">
							Password
						</label>
						<input
							id="password"
							type="password"
							value={password}
							onChange={(e) => setPassword(e.target.value)}
							required
							className="mt-1 w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900"
						/>
					</div>

					{error && <p className="text-red-500 text-sm">{error}</p>}

					<button
						type="submit"
						disabled={loading}
						className="w-full py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors font-medium"
					>
						{loading ? 'Signing in...' : 'Sign In'}
					</button>
				</form>

				<p className="mt-6 text-center text-gray-600">
					Don't have an account?{' '}
					<Link href="/register" className="text-blue-600 hover:underline">
						Sign up
					</Link>
				</p>
			</div>
		</div>
	);
}
