'use client';

import { useEffect, useSyncExternalStore } from 'react';

const STORAGE_KEY = 'superreader-public-font-size';
const SIZES = [16, 18, 20, 22, 24, 26, 28];
export const DEFAULT_PUBLIC_FONT_SIZE = 20;

// Tiny external store over localStorage (per visitor, best effort).
const listeners = new Set<() => void>();
// Last value set in this page view (also covers storage being unavailable)
let memorySize: number | null = null;

function readSize(): number {
	try {
		const stored = Number(localStorage.getItem(STORAGE_KEY));
		return SIZES.includes(stored) ? stored : DEFAULT_PUBLIC_FONT_SIZE;
	} catch {
		// storage unavailable (private mode): keep the default
		return DEFAULT_PUBLIC_FONT_SIZE;
	}
}

function writeSize(size: number) {
	try {
		localStorage.setItem(STORAGE_KEY, String(size));
	} catch {
		// ignore: the change still applies for this page view via the listeners
	}
	memorySize = size;
	listeners.forEach((listener) => listener());
}

function subscribe(listener: () => void) {
	listeners.add(listener);
	return () => listeners.delete(listener);
}

const getSnapshot = () => memorySize ?? readSize();
const getServerSnapshot = () => DEFAULT_PUBLIC_FONT_SIZE;

/**
 * A− / A+ buttons for the public article page. Sets the
 * --public-font-size CSS variable used by the article body.
 */
export default function PublicFontSizeControl() {
	const size = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

	useEffect(() => {
		document.documentElement.style.setProperty('--public-font-size', `${size}px`);
	}, [size]);

	const change = (delta: number) => {
		const index = SIZES.indexOf(size);
		writeSize(SIZES[Math.min(SIZES.length - 1, Math.max(0, index + delta))]);
	};

	const btn =
		'flex h-[34px] min-w-[40px] items-center justify-center px-2 font-bold text-ink transition-colors hover:bg-app-hover disabled:opacity-35 disabled:hover:bg-transparent';

	return (
		<div className="flex items-center overflow-hidden rounded-full border border-app-line" role="group" aria-label="Text size">
			<button
				type="button"
				onClick={() => change(-1)}
				disabled={size === SIZES[0]}
				aria-label="Decrease text size"
				className={`${btn} text-[13px]`}
			>
				A−
			</button>
			<span className="h-5 w-px bg-app-line" />
			<button
				type="button"
				onClick={() => change(1)}
				disabled={size === SIZES[SIZES.length - 1]}
				aria-label="Increase text size"
				className={`${btn} text-[17px]`}
			>
				A+
			</button>
		</div>
	);
}
