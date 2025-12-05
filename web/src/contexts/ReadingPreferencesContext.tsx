'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';

export type FontFamily = 'sans' | 'serif' | 'mono' | 'roboto' | 'lato' | 'openSans' | 'ubuntu';
export type FontSize = number; // Font size in pixels (12-50)
export type ColorTheme = 'default' | 'sepia' | 'dark' | 'night';
export type LineHeight = 'compact' | 'normal' | 'relaxed' | 'loose';
export type ContentWidth = 'narrow' | 'normal' | 'wide';

export interface ReadingPreferences {
	fontFamily: FontFamily;
	fontSize: FontSize;
	colorTheme: ColorTheme;
	lineHeight: LineHeight;
	contentWidth: ContentWidth;
}

interface ReadingPreferencesContextType {
	preferences: ReadingPreferences;
	updatePreferences: (newPreferences: Partial<ReadingPreferences>) => void;
	resetPreferences: () => void;
}

const defaultPreferences: ReadingPreferences = {
	fontFamily: 'serif',
	fontSize: 16,
	colorTheme: 'default',
	lineHeight: 'relaxed',
	contentWidth: 'normal',
};

const ReadingPreferencesContext = createContext<ReadingPreferencesContextType | undefined>(undefined);

export function ReadingPreferencesProvider({ children }: { children: ReactNode }) {
	const [preferences, setPreferences] = useState<ReadingPreferences>(defaultPreferences);
	const [isLoaded, setIsLoaded] = useState(false);

	// Load preferences from localStorage on mount
	useEffect(() => {
		try {
			const stored = localStorage.getItem('readingPreferences');
			if (stored) {
				const parsed = JSON.parse(stored);
				setPreferences({ ...defaultPreferences, ...parsed });
			}
		} catch (error) {
			console.error('Failed to load reading preferences:', error);
		} finally {
			setIsLoaded(true);
		}
	}, []);

	// Save preferences to localStorage whenever they change
	useEffect(() => {
		if (isLoaded) {
			try {
				localStorage.setItem('readingPreferences', JSON.stringify(preferences));
			} catch (error) {
				console.error('Failed to save reading preferences:', error);
			}
		}
	}, [preferences, isLoaded]);

	const updatePreferences = (newPreferences: Partial<ReadingPreferences>) => {
		setPreferences((prev) => ({ ...prev, ...newPreferences }));
	};

	const resetPreferences = () => {
		setPreferences(defaultPreferences);
	};

	return (
		<ReadingPreferencesContext.Provider
			value={{
				preferences,
				updatePreferences,
				resetPreferences,
			}}
		>
			{children}
		</ReadingPreferencesContext.Provider>
	);
}

export function useReadingPreferences() {
	const context = useContext(ReadingPreferencesContext);
	if (context === undefined) {
		throw new Error('useReadingPreferences must be used within a ReadingPreferencesProvider');
	}
	return context;
}
