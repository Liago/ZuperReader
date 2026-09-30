'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { Menu, Plus, X } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { useArticles } from '../../contexts/ArticlesContext';
import AddArticleModal from '../AddArticleModal';
import ArticleSummaryModal from '../ArticleSummaryModal';
import Sidebar from './Sidebar';

interface ShellContextValue {
	openSaveLink: () => void;
	openSummary: () => void;
	openNavigation: () => void;
}

const ShellContext = createContext<ShellContextValue | undefined>(undefined);

export function useShell() {
	const ctx = useContext(ShellContext);
	if (!ctx) throw new Error('useShell must be used within an AppShell');
	return ctx;
}

/**
 * The persistent app frame, mobile first:
 * - below `md` the sidebar is an off-canvas drawer opened from a sticky top bar
 *   (menu · brand · save a link);
 * - from `md` up it is the fixed 264px column next to an independently
 *   scrolling content area.
 * Owns the Save-a-link and weekly-summary modals so any screen inside the shell
 * (and the sidebar) can open them.
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
	 * progress tracking keeps working. The Reader has its own top bar, so the
	 * mobile shell bar is not rendered in this mode.
	 */
	documentScroll?: boolean;
}) {
	const { user } = useAuth();
	const { refreshArticles } = useArticles();
	const [showSaveLink, setShowSaveLink] = useState(false);
	const [showSummary, setShowSummary] = useState(false);
	const [drawerOpen, setDrawerOpen] = useState(false);

	const handleArticleAdded = () => {
		if (user) refreshArticles(user.id);
	};

	// Drawer: close with Escape and lock the page scroll behind it
	useEffect(() => {
		if (!drawerOpen) return;
		const onKeyDown = (e: KeyboardEvent) => {
			if (e.key === 'Escape') setDrawerOpen(false);
		};
		const previousOverflow = document.body.style.overflow;
		document.body.style.overflow = 'hidden';
		window.addEventListener('keydown', onKeyDown);
		return () => {
			document.body.style.overflow = previousOverflow;
			window.removeEventListener('keydown', onKeyDown);
		};
	}, [drawerOpen]);

	const openSaveLink = () => {
		setDrawerOpen(false);
		setShowSaveLink(true);
	};

	const mobileBar = (
		<div className="sticky top-0 z-30 flex items-center gap-3 border-b border-app-line bg-app-page/95 px-4 py-2.5 backdrop-blur md:hidden">
			<button
				type="button"
				onClick={() => setDrawerOpen(true)}
				aria-label="Open navigation"
				className="flex h-10 w-10 flex-none items-center justify-center rounded-full border border-app-line text-ink transition-colors hover:bg-app-hover"
			>
				<Menu size={18} strokeWidth={2.75} />
			</button>
			<div className="flex min-w-0 flex-1 items-center gap-2">
				<span className="flex h-[28px] w-[28px] flex-none items-center justify-center rounded-full bg-accent font-heading text-[14px] text-app-page">
					Z
				</span>
				<span className="truncate font-heading text-[19px] text-ink">Zuper</span>
			</div>
			<button
				type="button"
				onClick={openSaveLink}
				aria-label="Save a link"
				className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-accent text-app-page transition-colors hover:bg-accent-600"
			>
				<Plus size={19} strokeWidth={2.75} />
			</button>
		</div>
	);

	return (
		<ShellContext.Provider
			value={{
				openSaveLink,
				openSummary: () => setShowSummary(true),
				openNavigation: () => setDrawerOpen(true),
			}}
		>
			<div
				className={
					documentScroll
						? 'flex min-h-dvh bg-app-page text-ink'
						: 'flex h-dvh overflow-hidden bg-app-page text-ink'
				}
			>
				{/* Desktop / tablet sidebar */}
				{!hideSidebar &&
					(documentScroll ? (
						<div className="sticky top-0 hidden h-dvh self-start md:block">
							<Sidebar onSaveLink={openSaveLink} />
						</div>
					) : (
						<div className="hidden h-full md:block">
							<Sidebar onSaveLink={openSaveLink} />
						</div>
					))}

				<main className={documentScroll ? 'min-w-0 flex-1' : 'min-w-0 flex-1 overflow-y-auto'}>
					{!documentScroll && mobileBar}
					{children}
				</main>
			</div>

			{/* Mobile navigation drawer */}
			{/* Note: globals.css forces `.opacity-0` to opacity 1, so visibility + inline opacity are used here */}
			<div
				className={`fixed inset-0 z-50 transition-[visibility] duration-200 md:hidden ${drawerOpen ? 'visible' : 'invisible'}`}
				aria-hidden={!drawerOpen}
			>
				<div
					className="absolute inset-0 bg-[rgba(32,30,29,.42)] transition-opacity duration-200"
					style={{ opacity: drawerOpen ? 1 : 0 }}
					onClick={() => setDrawerOpen(false)}
				/>
				<div
					role="dialog"
					aria-modal="true"
					aria-label="Navigation"
					className={`absolute inset-y-0 left-0 flex max-w-[86vw] transition-transform duration-200 ease-out [box-shadow:var(--shadow-modal)] ${
						drawerOpen ? 'translate-x-0' : '-translate-x-full'
					}`}
				>
					{drawerOpen && (
						<>
							<Sidebar onSaveLink={openSaveLink} onNavigate={() => setDrawerOpen(false)} />
							<button
								type="button"
								onClick={() => setDrawerOpen(false)}
								aria-label="Close navigation"
								className="absolute right-3 top-4 flex h-9 w-9 items-center justify-center rounded-full text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
							>
								<X size={18} strokeWidth={2.75} />
							</button>
						</>
					)}
				</div>
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
