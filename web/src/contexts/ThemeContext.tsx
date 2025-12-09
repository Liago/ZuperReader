'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
// import { useAuth } from './AuthContext';

export type AppTheme = 'light' | 'dark' | 'ocean' | 'forest' | 'sunset';

interface ThemeContextType {
	theme: AppTheme;
	setTheme: (theme: AppTheme) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const THEME_STORAGE_KEY = 'app-theme';

export function ThemeProvider({ children }: { children: ReactNode }) {
	// user is not used
	const [theme, setThemeState] = useState<AppTheme>('light');
	const [isLoaded, setIsLoaded] = useState(false);

	// Load theme on mount
	useEffect(() => {
		const loadTheme = async () => {
			try {
				// For now, just use localStorage
				// Later we'll add database sync
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
			document.documentElement.setAttribute('data-theme', theme);
			// Also save to localStorage
			try {
				localStorage.setItem(THEME_STORAGE_KEY, theme);
			} catch (error) {
				console.error('Failed to save theme:', error);
			}
		}
	}, [theme, isLoaded]);

	const setTheme = (newTheme: AppTheme) => {
		setThemeState(newTheme);
	};

	return (
		<ThemeContext.Provider value={{ theme, setTheme }}>
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
	return ['light', 'dark', 'ocean', 'forest', 'sunset'].includes(value);
}
