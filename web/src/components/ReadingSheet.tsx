'use client';

import { useEffect } from 'react';
import { X } from 'lucide-react';
import { useReadingPreferences, LineHeight } from '../contexts/ReadingPreferencesContext';
import { useTheme } from '../contexts/ThemeContext';

interface ReadingSheetProps {
	isOpen: boolean;
	onClose: () => void;
}

// The revamp offers three line-height steps mapped onto the stored enum.
const LINE_HEIGHTS: { value: LineHeight; label: string; css: number }[] = [
	{ value: 'compact', label: 'Tight', css: 1.4 },
	{ value: 'relaxed', label: 'Comfortable', css: 1.8 },
	{ value: 'loose', label: 'Loose', css: 2.0 },
];

/**
 * Reading side sheet (README §10) — replaces the full-screen reading-preferences
 * modal so the article stays visible and reflows live as values change.
 */
export default function ReadingSheet({ isOpen, onClose }: ReadingSheetProps) {
	const { preferences, updatePreferences } = useReadingPreferences();
	const { setTheme } = useTheme();

	useEffect(() => {
		if (!isOpen) return;
		const onKey = (e: KeyboardEvent) => {
			if (e.key === 'Escape') onClose();
		};
		document.addEventListener('keydown', onKey);
		return () => document.removeEventListener('keydown', onKey);
	}, [isOpen, onClose]);

	if (!isOpen) return null;

	const isSerif = preferences.fontFamily === 'serif';
	const isDark = preferences.colorTheme === 'dark';
	const activeLineHeight = LINE_HEIGHTS.find((l) => l.value === preferences.lineHeight) ?? LINE_HEIGHTS[1];

	const setSurface = (surface: 'light' | 'dark') => {
		updatePreferences({ colorTheme: surface });
		setTheme(surface);
	};

	return (
		<div className="fixed inset-0 z-50" onClick={onClose} style={{ background: 'rgba(32,30,29,.42)' }}>
			<div
				className="absolute right-10 top-[70px] w-[360px] rounded-[28px] border border-app-line bg-app-card p-[22px] [box-shadow:var(--shadow-modal)]"
				onClick={(e) => e.stopPropagation()}
			>
				<div className="flex items-center justify-between">
					<h2 className="font-heading text-[21px] text-ink">Reading</h2>
					<button
						type="button"
						onClick={onClose}
						className="flex h-8 w-8 items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
					>
						<X size={16} strokeWidth={2.75} />
					</button>
				</div>

				{/* Typeface */}
				<SectionLabel>Typeface</SectionLabel>
				<div className="grid grid-cols-2 gap-2.5">
					<OptionCard active={!isSerif} onClick={() => updatePreferences({ fontFamily: 'sans' })}>
						<span style={{ fontFamily: 'var(--font-body)' }}>Figtree</span>
					</OptionCard>
					<OptionCard active={isSerif} onClick={() => updatePreferences({ fontFamily: 'serif' })}>
						<span style={{ fontFamily: 'Georgia, serif' }}>Serif</span>
					</OptionCard>
				</div>

				{/* Size */}
				<div className="mt-5 flex items-center justify-between">
					<SectionLabel inline>Size</SectionLabel>
					<span className="text-[12.5px] font-bold text-accent-700">{preferences.fontSize}px</span>
				</div>
				<input
					type="range"
					min={12}
					max={50}
					step={0.5}
					value={preferences.fontSize}
					onChange={(e) => updatePreferences({ fontSize: parseFloat(e.target.value) })}
					className="reading-range mt-2 w-full"
					style={{
						background: `linear-gradient(to right, var(--app-accent) 0%, var(--app-accent) ${((preferences.fontSize - 12) / 38) * 100}%, var(--app-line) ${((preferences.fontSize - 12) / 38) * 100}%, var(--app-line) 100%)`,
					}}
				/>

				{/* Line height */}
				<SectionLabel>Line height</SectionLabel>
				<div className="flex overflow-hidden rounded-full border border-app-line">
					{LINE_HEIGHTS.map((opt, i) => (
						<button
							key={opt.value}
							type="button"
							onClick={() => updatePreferences({ lineHeight: opt.value })}
							className={`flex-1 py-2 text-[13px] font-semibold transition-colors ${i > 0 ? 'border-l border-app-line' : ''} ${
								preferences.lineHeight === opt.value ? 'bg-accent text-app-page' : 'text-ink hover:bg-app-hover'
							}`}
						>
							{opt.label}
						</button>
					))}
				</div>

				{/* Surface */}
				<SectionLabel>Surface</SectionLabel>
				<div className="grid grid-cols-2 gap-2.5">
					<OptionCard active={!isDark} onClick={() => setSurface('light')}>
						Cream
					</OptionCard>
					<OptionCard active={isDark} onClick={() => setSurface('dark')}>
						Dark
					</OptionCard>
				</div>

				{/* Preview */}
				<SectionLabel>Preview</SectionLabel>
				<div
					className="rounded-[20px] bg-app-surface p-4 text-ink"
					style={{
						fontSize: `${preferences.fontSize}px`,
						lineHeight: activeLineHeight.css,
						fontFamily: isSerif ? 'Georgia, serif' : 'var(--font-body)',
					}}
				>
					The quick brown fox jumps over the lazy dog.
				</div>
			</div>

			<style jsx>{`
				.reading-range {
					-webkit-appearance: none;
					appearance: none;
					height: 6px;
					border-radius: 999px;
					cursor: pointer;
				}
				.reading-range::-webkit-slider-thumb {
					-webkit-appearance: none;
					appearance: none;
					width: 18px;
					height: 18px;
					border-radius: 50%;
					background: var(--app-accent);
					box-shadow: 0 0 0 3px var(--app-card);
					cursor: pointer;
				}
				.reading-range::-moz-range-thumb {
					width: 18px;
					height: 18px;
					border: none;
					border-radius: 50%;
					background: var(--app-accent);
					box-shadow: 0 0 0 3px var(--app-card);
					cursor: pointer;
				}
			`}</style>
		</div>
	);
}

function SectionLabel({ children, inline }: { children: React.ReactNode; inline?: boolean }) {
	return (
		<div className={`text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted ${inline ? '' : 'mb-2 mt-5'}`}>
			{children}
		</div>
	);
}

function OptionCard({
	active,
	onClick,
	children,
}: {
	active: boolean;
	onClick: () => void;
	children: React.ReactNode;
}) {
	return (
		<button
			type="button"
			onClick={onClick}
			className={`rounded-[18px] border p-3 text-[14px] font-semibold transition-colors ${
				active ? 'border-accent bg-accent-100 text-accent-800' : 'border-app-line text-ink hover:bg-app-hover'
			}`}
		>
			{children}
		</button>
	);
}
