'use client';

import { useEffect, useState } from 'react';

interface ReadingProgressIndicatorProps {
	contentRef: React.RefObject<HTMLDivElement | null>;
}

export default function ReadingProgressIndicator({ contentRef }: ReadingProgressIndicatorProps) {
	const [progress, setProgress] = useState(0);

	useEffect(() => {
		const handleScroll = () => {
			const contentElement = contentRef.current;
			if (!contentElement) return;

			const scrollPosition = window.scrollY + window.innerHeight;
			const contentBottom = contentElement.offsetTop + contentElement.offsetHeight;
			const scrollPercentage = Math.min(
				Math.max((scrollPosition / contentBottom) * 100, 0),
				100
			);

			setProgress(Math.round(scrollPercentage));
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
	const size = 60;
	const strokeWidth = 4;
	const center = size / 2;
	const radius = center - strokeWidth / 2;
	const circumference = 2 * Math.PI * radius;
	const offset = circumference - (progress / 100) * circumference;

	return (
		<div
			className="fixed top-4 left-4 sm:top-6 sm:left-6 z-40 transition-opacity duration-300 hover:opacity-100 opacity-90 group"
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
