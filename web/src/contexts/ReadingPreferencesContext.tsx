'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { getUserPreferences, saveUserPreferences } from '../lib/api';
import { useAuth } from './AuthContext';
import { useTheme } from './ThemeContext';

export type FontFamily = 'sans' | 'serif' | 'mono' | 'roboto' | 'lato' | 'openSans' | 'ubuntu';
export type FontSize = number; // Font size in pixels (12-50)
export type ColorTheme = 'light' | 'dark' | 'ocean' | 'forest' | 'sunset';
export type LineHeight = 'compact' | 'normal' | 'relaxed' | 'loose';
export type ContentWidth = 'narrow' | 'normal' | 'wide';
export type ViewMode = 'grid' | 'list';

export interface ReadingPreferences {
	fontFamily: FontFamily;
	fontSize: FontSize;
	colorTheme: ColorTheme;
	lineHeight: LineHeight;
	contentWidth: ContentWidth;
	viewMode: ViewMode;
}

interface ReadingPreferencesContextType {
	preferences: ReadingPreferences;
	updatePreferences: (newPreferences: Partial<ReadingPreferences>) => void;
	resetPreferences: () => void;
}

const defaultPreferences: ReadingPreferences = {
	fontFamily: 'serif',
	fontSize: 16,
	colorTheme: 'light',
	lineHeight: 'relaxed',
	contentWidth: 'normal',
	viewMode: 'grid',
};

const ReadingPreferencesContext = createContext<ReadingPreferencesContextType | undefined>(undefined);

export function ReadingPreferencesProvider({ children }: { children: ReactNode }) {
	const { user } = useAuth();
	const { theme: globalTheme } = useTheme();
	const [preferences, setPreferences] = useState<ReadingPreferences>(defaultPreferences);
	const [isLoaded, setIsLoaded] = useState(false);
	const [hasInitiallyLoaded, setHasInitiallyLoaded] = useState(false);

	// Load preferences on mount (database first, then localStorage as fallback)
	useEffect(() => {
		const loadPreferences = async () => {
			try {
				// If user is logged in, try to load from database
				if (user?.id) {
					try {
						const dbPreferences = await getUserPreferences(user.id);

						if (dbPreferences) {
							// Convert database format to app format (snake_case to camelCase)
							const appPreferences: ReadingPreferences = {
								fontFamily: dbPreferences.font_family,
								fontSize: dbPreferences.font_size,
								colorTheme: dbPreferences.color_theme,
								lineHeight: dbPreferences.line_height,
								contentWidth: dbPreferences.content_width,
								viewMode: dbPreferences.view_mode,
							};
							setPreferences(appPreferences);
							// Also save to localStorage for offline access
							localStorage.setItem('readingPreferences', JSON.stringify(appPreferences));
							setIsLoaded(true);
							return;
						}
					} catch (error) {
						console.warn('Failed to load preferences from database, falling back to localStorage:', error);
					}
				}

				// Fallback to localStorage
				const stored = localStorage.getItem('readingPreferences');
				if (stored) {
					const parsed = JSON.parse(stored);
					setPreferences({ ...defaultPreferences, ...parsed });
				}
			} catch (error) {
				console.error('Failed to load reading preferences:', error);
			} finally {
				setIsLoaded(true);
				setHasInitiallyLoaded(true);
			}
		};

		loadPreferences();
	}, [user]);

	// Sync colorTheme with global theme when it changes
	// This ensures the article reader respects the app-wide dark mode setting
	useEffect(() => {
		if (hasInitiallyLoaded && globalTheme) {
			// Only sync if the global theme is a valid color theme
			const validColorThemes: ColorTheme[] = ['light', 'dark', 'ocean', 'forest', 'sunset'];
			if (validColorThemes.includes(globalTheme as ColorTheme)) {
				setPreferences((prev) => ({
					...prev,
					colorTheme: globalTheme as ColorTheme,
				}));
			}
		}
	}, [globalTheme, hasInitiallyLoaded]);

	// Save preferences to both database and localStorage whenever they change
	useEffect(() => {
		if (isLoaded && user?.id) {
			const savePreferences = async () => {
				try {
					// Save to localStorage immediately (for performance)
					localStorage.setItem('readingPreferences', JSON.stringify(preferences));

					// Save to database (for cross-device sync)
					await saveUserPreferences(user.id, {
						font_family: preferences.fontFamily,
						font_size: preferences.fontSize,
						color_theme: preferences.colorTheme,
						line_height: preferences.lineHeight,
						content_width: preferences.contentWidth,
						view_mode: preferences.viewMode,
					});
				} catch (error) {
					console.error('Failed to save reading preferences to database:', error);
					// Even if database save fails, localStorage is already updated
				}
			};

			savePreferences();
		} else if (isLoaded && !user) {
			// If user is not logged in, just save to localStorage
			try {
				localStorage.setItem('readingPreferences', JSON.stringify(preferences));
			} catch (error) {
				console.error('Failed to save reading preferences to localStorage:', error);
			}
		}
	}, [preferences, isLoaded, user]);

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
