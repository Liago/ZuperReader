'use client';

import { Moon, Sun } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';

/**
 * The revamp reduces the old five-theme dropdown to a single moon/sun toggle
 * that flips Light <-> Dark. It lives in the sidebar's account block.
 */
export default function ThemeSelector() {
	const { resolvedTheme, setTheme } = useTheme();
	const isDark = resolvedTheme === 'dark';

	return (
		<button
			type="button"
			onClick={() => setTheme(isDark ? 'light' : 'dark')}
			aria-label={isDark ? 'Switch to light theme' : 'Switch to dark theme'}
			title={isDark ? 'Switch to light theme' : 'Switch to dark theme'}
			className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
		>
			{isDark ? (
				<Sun size={16} strokeWidth={2.75} />
			) : (
				<Moon size={16} strokeWidth={2.75} />
			)}
		</button>
	);
}
