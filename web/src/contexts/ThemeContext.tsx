'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
// import { useAuth } from './AuthContext';

export type AppTheme = 'auto' | 'light' | 'dark' | 'ocean' | 'forest' | 'sunset';

interface ThemeContextType {
	theme: AppTheme;
	resolvedTheme: Exclude<AppTheme, 'auto'>;
	setTheme: (theme: AppTheme) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const THEME_STORAGE_KEY = 'app-theme';

function getSystemTheme(): 'light' | 'dark' {
	if (typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches) {
		return 'dark';
	}
	return 'light';
}

export function ThemeProvider({ children }: { children: ReactNode }) {
	const [theme, setThemeState] = useState<AppTheme>('auto');
	const [systemTheme, setSystemTheme] = useState<'light' | 'dark'>('light');
	const [isLoaded, setIsLoaded] = useState(false);

	const resolvedTheme: Exclude<AppTheme, 'auto'> = theme === 'auto' ? systemTheme : theme;

	// Listen to system color scheme changes
	useEffect(() => {
		setSystemTheme(getSystemTheme());

		const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
		const handler = (e: MediaQueryListEvent) => {
			setSystemTheme(e.matches ? 'dark' : 'light');
		};
		mediaQuery.addEventListener('change', handler);
		return () => mediaQuery.removeEventListener('change', handler);
	}, []);

	// Load theme on mount
	useEffect(() => {
		const loadTheme = async () => {
			try {
				const stored = localStorage.getItem(THEME_STORAGE_KEY);
				if (stored && isValidTheme(stored)) {
					setThemeState(stored as AppTheme);
				}
			} catch (error) {
				console.error('Failed to load theme:', error);
			} finally {
				setIsLoaded(true);
			}
		};

		loadTheme();
	}, []);

	// Apply theme to document
	useEffect(() => {
		if (isLoaded) {
			document.documentElement.setAttribute('data-theme', resolvedTheme);
			if (resolvedTheme === 'dark') {
				document.documentElement.classList.add('dark');
			} else {
				document.documentElement.classList.remove('dark');
			}
			try {
				localStorage.setItem(THEME_STORAGE_KEY, theme);
			} catch (error) {
				console.error('Failed to save theme:', error);
			}
		}
	}, [theme, resolvedTheme, isLoaded]);

	const setTheme = (newTheme: AppTheme) => {
		setThemeState(newTheme);
	};

	return (
		<ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
			{children}
		</ThemeContext.Provider>
	);
}

export function useTheme() {
	const context = useContext(ThemeContext);
	if (context === undefined) {
		throw new Error('useTheme must be used within a ThemeProvider');
	}
	return context;
}

function isValidTheme(value: string): boolean {
	return ['auto', 'light', 'dark', 'ocean', 'forest', 'sunset'].includes(value);
}
