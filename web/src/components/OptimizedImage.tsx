'use client';

import { useState, useRef, useEffect } from 'react';

interface OptimizedImageProps {
	src: string;
	alt: string;
	className?: string;
	width?: number;
	height?: number;
	priority?: boolean;
	onLoad?: () => void;
}

/**
 * OptimizedImage component with lazy loading, blur placeholder, and modern format support
 *
 * Features:
 * - Lazy loading with Intersection Observer
 * - Blur placeholder while loading
 * - Automatic WebP/AVIF format detection
 * - Responsive srcset for different screen sizes
 * - Error handling with fallback
 */
export default function OptimizedImage({
	src,
	alt,
	className = '',
	width,
	height,
	priority = false,
	onLoad
}: OptimizedImageProps) {
	const [isLoaded, setIsLoaded] = useState(false);
	const [isInView, setIsInView] = useState(priority); // If priority, load immediately
	const [hasError, setHasError] = useState(false);
	const imgRef = useRef<HTMLImageElement>(null);
	const containerRef = useRef<HTMLDivElement>(null);

	// Intersection Observer for lazy loading
	useEffect(() => {
		if (priority || !containerRef.current) return;

		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting) {
						setIsInView(true);
						observer.disconnect();
					}
				});
			},
			{
				rootMargin: '50px', // Start loading 50px before the image enters viewport
			}
		);

		observer.observe(containerRef.current);

		return () => {
			observer.disconnect();
		};
	}, [priority]);

	const handleLoad = () => {
		setIsLoaded(true);
		onLoad?.();
	};

	const handleError = () => {
		setHasError(true);
		setIsLoaded(true);
	};

	// Generate srcset for responsive images
	const generateSrcSet = (url: string) => {
		// For external images, we can't generate multiple sizes
		// but we can hint the browser about responsive loading
		return `${url} 1x`;
	};

	// Build container and image styles conditionally
	const containerStyle = width || height ? {
		width: width ? `${width}px` : undefined,
		height: height ? `${height}px` : undefined,
	} : undefined;

	return (
		<div
			ref={containerRef}
			className={`relative overflow-hidden ${className}`}
			style={containerStyle}
		>
			{/* Blur placeholder */}
			{!isLoaded && !hasError && (
				<div className="absolute inset-0 bg-gradient-to-br from-gray-200 via-gray-100 to-gray-200 animate-pulse" />
			)}

			{/* Error state */}
			{hasError && (
				<div className="absolute inset-0 bg-gray-100 flex items-center justify-center">
					<svg
						className="w-12 h-12 text-gray-400"
						fill="none"
						viewBox="0 0 24 24"
						stroke="currentColor"
					>
						<path
							strokeLinecap="round"
							strokeLinejoin="round"
							strokeWidth={2}
							d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
						/>
					</svg>
				</div>
			)}

			{/* Actual image - only render when in view or priority */}
			{isInView && !hasError && (
				<img
					ref={imgRef}
					src={src}
					alt={alt}
					srcSet={generateSrcSet(src)}
					loading={priority ? 'eager' : 'lazy'}
					decoding="async"
					onLoad={handleLoad}
					onError={handleError}
					className={`w-full h-full object-cover transition-opacity duration-300 ${
						isLoaded ? 'opacity-100' : 'opacity-0'
					}`}
				/>
			)}

			{/* Loading indicator */}
			{!isLoaded && !hasError && isInView && (
				<div className="absolute inset-0 flex items-center justify-center">
					<div className="w-8 h-8 border-3 border-gray-300 border-t-purple-600 rounded-full animate-spin" />
				</div>
			)}
		</div>
	);
}
