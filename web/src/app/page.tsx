'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../contexts/AuthContext';
import ArticleList from '../components/ArticleList';
import AppShell from '../components/shell/AppShell';

export default function Home() {
	const { user, loading } = useAuth();
	const router = useRouter();

	useEffect(() => {
		if (!loading && !user) {
			router.push('/login');
		}
	}, [user, loading, router]);

	if (loading) {
		return (
			<div className="flex min-h-screen items-center justify-center bg-app-page">
				<div className="flex flex-col items-center gap-4">
					<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
					<p className="text-[13.5px] font-medium text-app-muted">Loading…</p>
				</div>
			</div>
		);
	}

	if (!user) {
		return null; // Will redirect to login
	}

	return (
		<AppShell>
			<ArticleList userId={user.id} />
		</AppShell>
	);
}
