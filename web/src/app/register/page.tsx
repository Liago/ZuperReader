'use client';

import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

export default function RegisterPage() {
	const [email, setEmail] = useState('');
	const [password, setPassword] = useState('');
	const [confirmPassword, setConfirmPassword] = useState('');
	const [error, setError] = useState('');
	const [loading, setLoading] = useState(false);
	const [success, setSuccess] = useState(false);
	const { signUp } = useAuth();
	const router = useRouter();

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setLoading(true);
		setError('');

		if (password !== confirmPassword) {
			setError('Passwords do not match');
			setLoading(false);
			return;
		}

		if (password.length < 6) {
			setError('Password must be at least 6 characters');
			setLoading(false);
			return;
		}

		const { error } = await signUp(email, password);

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
						We've sent you a confirmation link. Please check your email to verify your account.
					</p>
					<Link href="/login" className="text-blue-600 hover:underline">
						Go to login
					</Link>
				</div>
			</div>
		);
	}

	return (
		<div className="min-h-screen flex items-center justify-center bg-gray-100 py-12 px-4">
			<div className="max-w-md w-full bg-white rounded-lg shadow-md p-8">
				<h1 className="text-2xl font-bold text-center text-gray-900 mb-8">Create Account</h1>

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

					<div>
						<label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700">
							Confirm Password
						</label>
						<input
							id="confirmPassword"
							type="password"
							value={confirmPassword}
							onChange={(e) => setConfirmPassword(e.target.value)}
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
						{loading ? 'Creating account...' : 'Sign Up'}
					</button>
				</form>

				<p className="mt-6 text-center text-gray-600">
					Already have an account?{' '}
					<Link href="/login" className="text-blue-600 hover:underline">
						Sign in
					</Link>
				</p>
			</div>
		</div>
	);
}
