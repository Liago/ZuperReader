'use client';

import { useEffect, useState } from 'react';

interface ReadingProgressIndicatorProps {
	contentRef: React.RefObject<HTMLDivElement | null>;
	hidden?: boolean;
	variant?: 'fixed' | 'inline';
	onProgressChange?: (progress: number) => void;
}

export default function ReadingProgressIndicator({
	contentRef,
	hidden = false,
	variant = 'fixed',
	onProgressChange
}: ReadingProgressIndicatorProps) {
	const [progress, setProgress] = useState(0);

	useEffect(() => {
		const handleScroll = () => {
			const contentElement = contentRef.current;
			if (!contentElement) return;

			const contentTop = contentElement.offsetTop;
			const contentBottom = contentTop + contentElement.offsetHeight;
			const viewportTop = window.scrollY;
			const viewportBottom = window.scrollY + window.innerHeight;
			const windowHeight = window.innerHeight;

			// Calculate progress: 0% when starting to read, 100% when finished
			// Start: when top of viewport reaches top of content
			// End: when bottom of viewport reaches bottom of content

			const scrollStart = contentTop;
			const scrollEnd = contentBottom - windowHeight;
			const scrollRange = scrollEnd - scrollStart;

			let scrollPercentage = 0;

			if (scrollRange <= 0) {
				// Content is smaller than viewport
				scrollPercentage = viewportTop >= contentTop ? 100 : 0;
			} else {
				const scrollProgress = viewportTop - scrollStart;
				scrollPercentage = Math.max(0, Math.min(100, (scrollProgress / scrollRange) * 100));
			}

			const roundedProgress = Math.round(scrollPercentage);
			setProgress(roundedProgress);
			if (onProgressChange) {
				onProgressChange(roundedProgress);
			}
		};

		// Initial calculation
		handleScroll();

		window.addEventListener('scroll', handleScroll);
		window.addEventListener('resize', handleScroll);

		return () => {
			window.removeEventListener('scroll', handleScroll);
			window.removeEventListener('resize', handleScroll);
		};
	}, [contentRef]);

	// SVG circle properties - responsive size
	const size = variant === 'inline' ? 40 : 60;
	const strokeWidth = variant === 'inline' ? 3 : 4;
	const center = size / 2;
	const radius = center - strokeWidth / 2;
	const circumference = 2 * Math.PI * radius;
	const offset = circumference - (progress / 100) * circumference;

	if (variant === 'inline') {
		return (
			<div className="relative inline-flex items-center justify-center" title="Reading Progress">
				<svg width={size} height={size} className="transform -rotate-90">
					{/* Background track */}
					<circle
						cx={center}
						cy={center}
						r={radius}
						fill="none"
						stroke="currentColor"
						strokeWidth={strokeWidth}
						className="text-gray-200"
					/>
					{/* Progress circle */}
					<circle
						cx={center}
						cy={center}
						r={radius}
						fill="none"
						stroke="url(#gradient-inline)"
						strokeWidth={strokeWidth}
						strokeDasharray={circumference}
						strokeDashoffset={offset}
						strokeLinecap="round"
						className="transition-all duration-300 ease-out"
					/>
					{/* Gradient definition */}
					<defs>
						<linearGradient id="gradient-inline" x1="0%" y1="0%" x2="100%" y2="100%">
							<stop offset="0%" stopColor="#9333ea" />
							<stop offset="50%" stopColor="#db2777" />
							<stop offset="100%" stopColor="#ec4899" />
						</linearGradient>
					</defs>
				</svg>
				{/* Percentage text */}
				<div className="absolute inset-0 flex items-center justify-center">
					<span className="text-[10px] font-bold text-gray-700 tabular-nums">
						{progress}%
					</span>
				</div>
			</div>
		);
	}

	return (
		<div
			className={`fixed top-4 left-4 sm:top-6 sm:left-6 z-40 transition-all duration-300 hover:opacity-100 group ${
				hidden ? 'opacity-0 pointer-events-none' : 'opacity-90'
			}`}
			title="Reading Progress"
		>
			<div className="relative bg-white rounded-full shadow-lg p-1 scale-90 sm:scale-100">
				{/* Background circle */}
				<svg width={size} height={size} className="transform -rotate-90">
					{/* Background track */}
					<circle
						cx={center}
						cy={center}
						r={radius}
						fill="none"
						stroke="currentColor"
						strokeWidth={strokeWidth}
						className="text-gray-200"
					/>
					{/* Progress circle */}
					<circle
						cx={center}
						cy={center}
						r={radius}
						fill="none"
						stroke="url(#gradient)"
						strokeWidth={strokeWidth}
						strokeDasharray={circumference}
						strokeDashoffset={offset}
						strokeLinecap="round"
						className="transition-all duration-300 ease-out"
					/>
					{/* Gradient definition */}
					<defs>
						<linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="100%">
							<stop offset="0%" stopColor="#9333ea" />
							<stop offset="50%" stopColor="#db2777" />
							<stop offset="100%" stopColor="#ec4899" />
						</linearGradient>
					</defs>
				</svg>

				{/* Percentage text */}
				<div className="absolute inset-0 flex items-center justify-center">
					<span className="text-xs font-bold text-gray-700 tabular-nums">
						{progress}%
					</span>
				</div>
			</div>
		</div>
	);
}
