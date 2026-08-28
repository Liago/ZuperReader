'use client';

import { createContext, useContext, useState, ReactNode } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useArticles } from '../../contexts/ArticlesContext';
import AddArticleModal from '../AddArticleModal';
import ArticleSummaryModal from '../ArticleSummaryModal';
import Sidebar from './Sidebar';

interface ShellContextValue {
	openSaveLink: () => void;
	openSummary: () => void;
}

const ShellContext = createContext<ShellContextValue | undefined>(undefined);

export function useShell() {
	const ctx = useContext(ShellContext);
	if (!ctx) throw new Error('useShell must be used within an AppShell');
	return ctx;
}

/**
 * The persistent app frame: a fixed 264px sidebar plus an independently
 * scrolling content area. Owns the Save-a-link and weekly-summary modals so
 * any screen inside the shell (and the sidebar) can open them.
 */
export default function AppShell({ children }: { children: ReactNode }) {
	const { user } = useAuth();
	const { refreshArticles } = useArticles();
	const [showSaveLink, setShowSaveLink] = useState(false);
	const [showSummary, setShowSummary] = useState(false);

	const handleArticleAdded = () => {
		if (user) refreshArticles(user.id);
	};

	return (
		<ShellContext.Provider
			value={{
				openSaveLink: () => setShowSaveLink(true),
				openSummary: () => setShowSummary(true),
			}}
		>
			<div className="flex h-screen overflow-hidden bg-app-page text-ink">
				<Sidebar onSaveLink={() => setShowSaveLink(true)} />
				<main className="flex-1 overflow-y-auto">{children}</main>
			</div>

			{user && (
				<>
					<AddArticleModal
						isOpen={showSaveLink}
						onClose={() => setShowSaveLink(false)}
						userId={user.id}
						onArticleAdded={handleArticleAdded}
					/>
					<ArticleSummaryModal
						isOpen={showSummary}
						onClose={() => setShowSummary(false)}
						userId={user.id}
					/>
				</>
			)}
		</ShellContext.Provider>
	);
}
