'use client';

import { useReadingPreferences, FontFamily, ColorTheme, LineHeight, ContentWidth } from '../contexts/ReadingPreferencesContext';

interface ReadingPreferencesModalProps {
	isOpen: boolean;
	onClose: () => void;
}

export default function ReadingPreferencesModal({ isOpen, onClose }: ReadingPreferencesModalProps) {
	const { preferences, updatePreferences, resetPreferences } = useReadingPreferences();

	if (!isOpen) return null;

	const fontFamilyOptions: { value: FontFamily; label: string; preview: string }[] = [
		{ value: 'sans', label: 'Sans Serif', preview: 'font-sans' },
		{ value: 'serif', label: 'Serif', preview: 'font-serif' },
		{ value: 'mono', label: 'Monospace', preview: 'font-mono' },
		{ value: 'roboto', label: 'Roboto', preview: 'font-roboto' },
		{ value: 'lato', label: 'Lato', preview: 'font-lato' },
		{ value: 'openSans', label: 'Open Sans', preview: 'font-open-sans' },
		{ value: 'ubuntu', label: 'Ubuntu', preview: 'font-ubuntu' },
	];


	const colorThemeOptions: { value: ColorTheme; label: string; bg: string; text: string; border: string }[] = [
		{ value: 'light', label: 'Light', bg: 'bg-white', text: 'text-gray-900', border: 'border-gray-200' },
		{ value: 'dark', label: 'Dark', bg: 'bg-slate-800', text: 'text-slate-100', border: 'border-slate-700' },
		{ value: 'ocean', label: 'Ocean', bg: 'bg-sky-50', text: 'text-cyan-950', border: 'border-sky-200' },
		{ value: 'forest', label: 'Forest', bg: 'bg-emerald-50', text: 'text-emerald-950', border: 'border-emerald-200' },
		{ value: 'sunset', label: 'Sunset', bg: 'bg-violet-50', text: 'text-violet-950', border: 'border-violet-200' },
	];

	const lineHeightOptions: { value: LineHeight; label: string; height: string }[] = [
		{ value: 'compact', label: 'Compact', height: '1.4' },
		{ value: 'normal', label: 'Normal', height: '1.6' },
		{ value: 'relaxed', label: 'Relaxed', height: '1.8' },
		{ value: 'loose', label: 'Loose', height: '2.0' },
	];

	const contentWidthOptions: { value: ContentWidth; label: string; width: string }[] = [
		{ value: 'narrow', label: 'Narrow', width: 'max-w-2xl' },
		{ value: 'normal', label: 'Normal', width: 'max-w-4xl' },
		{ value: 'wide', label: 'Wide', width: 'max-w-6xl' },
	];

	return (
		<>
			{/* Backdrop */}
			<div
				className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40 animate-fadeIn"
				onClick={onClose}
			></div>

			{/* Modal */}
			<div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
				<div
					className="bg-white/95 dark:bg-slate-800/95 backdrop-blur-md rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto pointer-events-auto border border-gray-200 dark:border-slate-700"
					onClick={(e) => e.stopPropagation()}
				>
					{/* Header */}
					<div className="sticky top-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 text-white p-6 rounded-t-2xl">
						<div className="flex items-center justify-between">
							<div>
								<h2 className="text-2xl font-bold mb-1">Reading Preferences</h2>
								<p className="text-purple-100 text-sm">Customize your reading experience</p>
							</div>
							<button
								onClick={onClose}
								className="p-2 hover:bg-white/20 rounded-lg transition-colors"
								aria-label="Close"
							>
								<svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
								</svg>
							</button>
						</div>
					</div>

					{/* Content */}
					<div className="p-6 space-y-8">
						{/* Font Family */}
						<div>
							<label className="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
								Font Family
							</label>
							<div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
								{fontFamilyOptions.map((option) => (
									<button
										key={option.value}
										onClick={() => updatePreferences({ fontFamily: option.value })}
										className={`p-4 rounded-xl border-2 transition-all duration-200 ${preferences.fontFamily === option.value
												? 'border-purple-500 bg-purple-50 dark:bg-purple-900/30 shadow-md text-purple-900 dark:text-purple-200'
												: 'border-gray-200 dark:border-slate-600 hover:border-purple-300 dark:hover:border-purple-600 hover:bg-purple-50/50 dark:hover:bg-purple-900/20 text-gray-900 dark:text-gray-100'
											}`}
									>
										<span className={`block text-base font-medium ${option.preview}`}>
											{option.label}
										</span>
									</button>
								))}
							</div>
						</div>

						{/* Font Size */}
						<div>
							<label className="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
								Font Size: {preferences.fontSize}px
							</label>
							<div className="space-y-4">
								<input
									type="range"
									min="12"
									max="50"
									value={preferences.fontSize}
									onChange={(e) => updatePreferences({ fontSize: parseInt(e.target.value) })}
									className="w-full h-2 bg-gradient-to-r from-pink-200 to-pink-500 rounded-lg appearance-none cursor-pointer slider"
									style={{
										background: `linear-gradient(to right, #fbcfe8 0%, #ec4899 ${((preferences.fontSize - 12) / (50 - 12)) * 100}%, #fce7f3 ${((preferences.fontSize - 12) / (50 - 12)) * 100}%, #fce7f3 100%)`
									}}
								/>
								<div className="flex justify-between text-xs text-gray-500 dark:text-gray-400">
									<span>12px</span>
									<span>50px</span>
								</div>
								<div className="p-4 bg-pink-50 dark:bg-pink-900/30 rounded-xl border-2 border-pink-200 dark:border-pink-800">
									<p style={{ fontSize: `${preferences.fontSize}px` }} className="text-gray-900 dark:text-gray-100 text-center">
										Sample text preview
									</p>
								</div>
							</div>
						</div>

						{/* Color Theme */}
						<div>
							<label className="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
								Color Theme
							</label>
							<div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
								{colorThemeOptions.map((option) => (
									<button
										key={option.value}
										onClick={() => updatePreferences({ colorTheme: option.value })}
										className={`p-4 rounded-xl border-2 transition-all duration-200 ${preferences.colorTheme === option.value
												? 'border-blue-500 shadow-md scale-105'
												: 'border-gray-300 dark:border-slate-600 hover:border-blue-300 dark:hover:border-blue-600 hover:scale-102'
											}`}
									>
										<div className={`${option.bg} ${option.text} ${option.border} border rounded-lg p-3 mb-2`}>
											<span className="text-xs font-medium">Aa</span>
										</div>
										<span className="block text-sm font-medium text-gray-700 dark:text-gray-300">
											{option.label}
										</span>
									</button>
								))}
							</div>
						</div>

						{/* Line Height */}
						<div>
							<label className="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
								Line Height
							</label>
							<div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
								{lineHeightOptions.map((option) => (
									<button
										key={option.value}
										onClick={() => updatePreferences({ lineHeight: option.value })}
										className={`p-4 rounded-xl border-2 transition-all duration-200 ${preferences.lineHeight === option.value
												? 'border-green-500 bg-green-50 dark:bg-green-900/30 shadow-md'
												: 'border-gray-200 dark:border-slate-600 hover:border-green-300 dark:hover:border-green-600 hover:bg-green-50/50 dark:hover:bg-green-900/20'
											}`}
									>
										<span className={`block text-sm font-medium ${preferences.lineHeight === option.value ? 'text-green-900 dark:text-green-200' : 'text-gray-900 dark:text-gray-100'
											}`}>
											{option.label}
										</span>
										<span className={`block text-xs mt-1 ${preferences.lineHeight === option.value ? 'text-green-700 dark:text-green-400' : 'text-gray-600 dark:text-gray-400'
											}`}>
											{option.height}
										</span>
									</button>
								))}
							</div>
						</div>

						{/* Content Width */}
						<div>
							<label className="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
								Content Width
							</label>
							<div className="grid grid-cols-3 gap-3">
								{contentWidthOptions.map((option) => (
									<button
										key={option.value}
										onClick={() => updatePreferences({ contentWidth: option.value })}
										className={`p-4 rounded-xl border-2 transition-all duration-200 ${preferences.contentWidth === option.value
												? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-900/30 shadow-md text-indigo-900 dark:text-indigo-200'
												: 'border-gray-200 dark:border-slate-600 hover:border-indigo-300 dark:hover:border-indigo-600 hover:bg-indigo-50/50 dark:hover:bg-indigo-900/20 text-gray-900 dark:text-gray-100'
											}`}
									>
										<span className="block text-sm font-medium">
											{option.label}
										</span>
									</button>
								))}
							</div>
						</div>
					</div>

					{/* Footer */}
					<div className="sticky bottom-0 bg-gray-50/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-gray-200 dark:border-slate-700 p-6 rounded-b-2xl flex gap-3">
						<button
							onClick={resetPreferences}
							className="flex-1 px-6 py-3 bg-white dark:bg-slate-800 border-2 border-gray-300 dark:border-slate-600 text-gray-700 dark:text-gray-200 font-medium rounded-xl hover:bg-gray-50 dark:hover:bg-slate-700 hover:border-gray-400 dark:hover:border-slate-500 transition-all duration-200"
						>
							Reset to Default
						</button>
						<button
							onClick={onClose}
							className="flex-1 px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-200"
						>
							Done
						</button>
					</div>
				</div>
			</div>

			{/* CSS for animations */}
			<style jsx>{`
				@keyframes fadeIn {
					from {
						opacity: 0;
					}
					to {
						opacity: 1;
					}
				}
				.animate-fadeIn {
					animation: fadeIn 0.2s ease-out;
				}
			`}</style>
		</>
	);
}
