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
export default function AppShell({
	children,
	hideSidebar = false,
	documentScroll = false,
}: {
	children: ReactNode;
	/** Reader Focus mode hides the sidebar; the content area then fills the frame. */
	hideSidebar?: boolean;
	/**
	 * When true the document (window) scrolls instead of the content area, and the
	 * sidebar becomes sticky. The Reader uses this so its window-based scroll
	 * progress tracking keeps working.
	 */
	documentScroll?: boolean;
}) {
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
			<div
				className={
					documentScroll
						? 'flex min-h-screen bg-app-page text-ink'
						: 'flex h-screen overflow-hidden bg-app-page text-ink'
				}
			>
				{!hideSidebar &&
					(documentScroll ? (
						<div className="sticky top-0 h-screen self-start">
							<Sidebar onSaveLink={() => setShowSaveLink(true)} />
						</div>
					) : (
						<Sidebar onSaveLink={() => setShowSaveLink(true)} />
					))}
				<main className={documentScroll ? 'min-w-0 flex-1' : 'flex-1 overflow-y-auto'}>{children}</main>
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
