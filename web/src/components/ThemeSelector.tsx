'use client';

import { useState } from 'react';
import { useTheme, AppTheme } from '../contexts/ThemeContext';

export default function ThemeSelector() {
	const { theme, setTheme } = useTheme();
	const [isOpen, setIsOpen] = useState(false);

	const themes: { value: AppTheme; label: string; icon: string; colors: string }[] = [
		{ value: 'light', label: 'Light', icon: '☀️', colors: 'from-purple-100 to-pink-100' },
		{ value: 'dark', label: 'Dark', icon: '🌙', colors: 'from-slate-700 to-slate-900' },
		{ value: 'ocean', label: 'Ocean', icon: '🌊', colors: 'from-cyan-100 to-sky-200' },
		{ value: 'forest', label: 'Forest', icon: '🌲', colors: 'from-emerald-100 to-green-200' },
		{ value: 'sunset', label: 'Sunset', icon: '🌅', colors: 'from-violet-100 to-fuchsia-200' },
	];

	const currentTheme = themes.find(t => t.value === theme) || themes[0];

	return (
		<div className="relative">
			<button
				onClick={() => setIsOpen(!isOpen)}
				className="flex items-center gap-2 px-3 py-2 bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm text-gray-700 dark:text-gray-200 rounded-lg hover:bg-white hover:shadow-md transition-all duration-200 border border-gray-200 dark:border-slate-700"
				title="Change theme"
			>
				<span className="text-lg">{currentTheme.icon}</span>
				<span className="hidden sm:inline text-sm font-medium">{currentTheme.label}</span>
				<svg
					className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`}
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
				>
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
				</svg>
			</button>

			{isOpen && (
				<>
					{/* Backdrop */}
					<div
						className="fixed inset-0 z-40"
						onClick={() => setIsOpen(false)}
					></div>

					{/* Dropdown */}
					<div className="absolute right-0 mt-2 w-56 bg-white/95 dark:bg-slate-800/95 backdrop-blur-md rounded-xl shadow-2xl border border-gray-200 dark:border-slate-700 z-50 overflow-hidden">
						<div className="p-2">
							{themes.map((t) => (
								<button
									key={t.value}
									onClick={() => {
										setTheme(t.value);
										setIsOpen(false);
									}}
									className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 ${
										theme === t.value
											? 'bg-gradient-to-r ' + t.colors + ' font-semibold scale-105'
											: 'hover:bg-gray-100 dark:hover:bg-slate-700'
									}`}
								>
									<span className="text-xl">{t.icon}</span>
									<div className="flex-1 text-left">
										<div className="text-sm font-medium text-gray-900 dark:text-gray-100">
											{t.label}
										</div>
									</div>
									{theme === t.value && (
										<svg className="w-5 h-5 text-purple-600 dark:text-purple-400" fill="currentColor" viewBox="0 0 20 20">
											<path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
										</svg>
									)}
								</button>
							))}
						</div>
						<div className="border-t border-gray-200 dark:border-slate-700 p-2 bg-gray-50 dark:bg-slate-900/50">
							<p className="text-xs text-gray-500 dark:text-gray-400 text-center">
								Theme applies to entire app
							</p>
						</div>
					</div>
				</>
			)}
		</div>
	);
}
