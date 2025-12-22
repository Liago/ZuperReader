'use client';

import { useState, useEffect, useRef, useCallback } from 'react';

interface ImageGalleryModalProps {
	images: string[];
	initialIndex: number;
	onClose: () => void;
}

export default function ImageGalleryModal({ images, initialIndex, onClose }: ImageGalleryModalProps) {
	const [currentIndex, setCurrentIndex] = useState(initialIndex);
	const [scale, setScale] = useState(1);
	const [position, setPosition] = useState({ x: 0, y: 0 });
	const [isDragging, setIsDragging] = useState(false);
	const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
	const [isLoading, setIsLoading] = useState(true);
	const imageRef = useRef<HTMLImageElement>(null);
	const containerRef = useRef<HTMLDivElement>(null);

	const currentImage = images[currentIndex];

	// Reset zoom and position when changing images
	useEffect(() => {
		setScale(1);
		setPosition({ x: 0, y: 0 });
		setIsLoading(true);
	}, [currentIndex]);

	// Handle keyboard navigation
	useEffect(() => {
		const handleKeyDown = (e: KeyboardEvent) => {
			if (e.key === 'Escape') {
				onClose();
			} else if (e.key === 'ArrowLeft') {
				handlePrevious();
			} else if (e.key === 'ArrowRight') {
				handleNext();
			} else if (e.key === '+' || e.key === '=') {
				handleZoomIn();
			} else if (e.key === '-' || e.key === '_') {
				handleZoomOut();
			} else if (e.key === '0') {
				resetZoom();
			}
		};

		window.addEventListener('keydown', handleKeyDown);
		return () => window.removeEventListener('keydown', handleKeyDown);
	}, [currentIndex, scale]);

	// Handle mouse wheel zoom
	const handleWheel = useCallback((e: WheelEvent) => {
		if (e.ctrlKey || e.metaKey) {
			e.preventDefault();
			const delta = e.deltaY > 0 ? -0.1 : 0.1;
			setScale(prev => Math.max(0.5, Math.min(5, prev + delta)));
		}
	}, []);

	useEffect(() => {
		const container = containerRef.current;
		if (container) {
			container.addEventListener('wheel', handleWheel, { passive: false });
			return () => container.removeEventListener('wheel', handleWheel);
		}
	}, [handleWheel]);

	const handleNext = () => {
		if (currentIndex < images.length - 1) {
			setCurrentIndex(prev => prev + 1);
		}
	};

	const handlePrevious = () => {
		if (currentIndex > 0) {
			setCurrentIndex(prev => prev - 1);
		}
	};

	const handleZoomIn = () => {
		setScale(prev => Math.min(5, prev + 0.25));
	};

	const handleZoomOut = () => {
		setScale(prev => Math.max(0.5, prev - 0.25));
	};

	const resetZoom = () => {
		setScale(1);
		setPosition({ x: 0, y: 0 });
	};

	// Mouse drag handlers
	const handleMouseDown = (e: React.MouseEvent) => {
		if (scale > 1) {
			setIsDragging(true);
			setDragStart({
				x: e.clientX - position.x,
				y: e.clientY - position.y
			});
		}
	};

	const handleMouseMove = (e: React.MouseEvent) => {
		if (isDragging && scale > 1) {
			setPosition({
				x: e.clientX - dragStart.x,
				y: e.clientY - dragStart.y
			});
		}
	};

	const handleMouseUp = () => {
		setIsDragging(false);
	};

	// Touch handlers for mobile
	const touchStartRef = useRef<{ x: number; y: number; distance: number } | null>(null);

	const handleTouchStart = (e: React.TouchEvent) => {
		if (e.touches.length === 1 && scale > 1) {
			// Single touch for dragging
			setIsDragging(true);
			setDragStart({
				x: e.touches[0].clientX - position.x,
				y: e.touches[0].clientY - position.y
			});
		} else if (e.touches.length === 2) {
			// Two finger pinch for zoom
			const distance = Math.hypot(
				e.touches[0].clientX - e.touches[1].clientX,
				e.touches[0].clientY - e.touches[1].clientY
			);
			touchStartRef.current = {
				x: (e.touches[0].clientX + e.touches[1].clientX) / 2,
				y: (e.touches[0].clientY + e.touches[1].clientY) / 2,
				distance
			};
		}
	};

	const handleTouchMove = (e: React.TouchEvent) => {
		if (e.touches.length === 1 && isDragging && scale > 1) {
			// Single touch drag
			setPosition({
				x: e.touches[0].clientX - dragStart.x,
				y: e.touches[0].clientY - dragStart.y
			});
		} else if (e.touches.length === 2 && touchStartRef.current) {
			// Pinch zoom
			const distance = Math.hypot(
				e.touches[0].clientX - e.touches[1].clientX,
				e.touches[0].clientY - e.touches[1].clientY
			);
			const scaleChange = distance / touchStartRef.current.distance;
			setScale(prev => Math.max(0.5, Math.min(5, prev * scaleChange)));
			touchStartRef.current.distance = distance;
		}
	};

	const handleTouchEnd = () => {
		setIsDragging(false);
		touchStartRef.current = null;
	};

	const handleImageLoad = () => {
		setIsLoading(false);
	};

	return (
		<div className="fixed inset-0 z-50 bg-black/95 backdrop-blur-sm">
			{/* Header */}
			<div className="absolute top-0 left-0 right-0 z-10 bg-gradient-to-b from-black/80 to-transparent p-4">
				<div className="flex items-center justify-between max-w-7xl mx-auto">
					<div className="flex items-center gap-3 text-white">
						<span className="text-sm font-medium bg-white/10 px-3 py-1.5 rounded-full backdrop-blur-sm">
							{currentIndex + 1} / {images.length}
						</span>
					</div>
					<button
						onClick={onClose}
						className="p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition-all hover:scale-110"
						title="Close (Esc)"
					>
						<svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>
			</div>

			{/* Main Image Container */}
			<div
				ref={containerRef}
				className="absolute inset-0 flex items-center justify-center"
				onMouseDown={handleMouseDown}
				onMouseMove={handleMouseMove}
				onMouseUp={handleMouseUp}
				onMouseLeave={handleMouseUp}
				onTouchStart={handleTouchStart}
				onTouchMove={handleTouchMove}
				onTouchEnd={handleTouchEnd}
			>
				{isLoading && (
					<div className="absolute inset-0 flex items-center justify-center">
						<div className="w-12 h-12 border-4 border-white/20 border-t-white rounded-full animate-spin"></div>
					</div>
				)}
				<img
					ref={imageRef}
					src={currentImage}
					alt={`Image ${currentIndex + 1}`}
					className={`max-w-full max-h-full object-contain transition-opacity duration-300 ${
						isLoading ? 'opacity-0' : 'opacity-100'
					} ${isDragging ? 'cursor-grabbing' : scale > 1 ? 'cursor-grab' : 'cursor-default'}`}
					style={{
						transform: `scale(${scale}) translate(${position.x / scale}px, ${position.y / scale}px)`,
						transition: isDragging ? 'none' : 'transform 0.3s ease-out'
					}}
					onLoad={handleImageLoad}
					draggable={false}
				/>
			</div>

			{/* Navigation Arrows */}
			{currentIndex > 0 && (
				<button
					onClick={handlePrevious}
					className="absolute left-4 top-1/2 -translate-y-1/2 p-3 rounded-full bg-white/10 hover:bg-white/20 text-white transition-all hover:scale-110 backdrop-blur-sm"
					title="Previous (←)"
				>
					<svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
					</svg>
				</button>
			)}

			{currentIndex < images.length - 1 && (
				<button
					onClick={handleNext}
					className="absolute right-4 top-1/2 -translate-y-1/2 p-3 rounded-full bg-white/10 hover:bg-white/20 text-white transition-all hover:scale-110 backdrop-blur-sm"
					title="Next (→)"
				>
					<svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
					</svg>
				</button>
			)}

			{/* Bottom Controls */}
			<div className="absolute bottom-0 left-0 right-0 z-10 bg-gradient-to-t from-black/80 to-transparent p-4">
				<div className="flex items-center justify-center gap-3 max-w-7xl mx-auto">
					{/* Zoom Controls */}
					<div className="flex items-center gap-2 bg-white/10 rounded-full px-4 py-2 backdrop-blur-sm">
						<button
							onClick={handleZoomOut}
							disabled={scale <= 0.5}
							className="p-2 text-white hover:bg-white/20 rounded-full transition-all disabled:opacity-30 disabled:cursor-not-allowed"
							title="Zoom out (-)"
						>
							<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10H7" />
							</svg>
						</button>
						<span className="text-white text-sm font-medium min-w-[4rem] text-center">
							{Math.round(scale * 100)}%
						</span>
						<button
							onClick={handleZoomIn}
							disabled={scale >= 5}
							className="p-2 text-white hover:bg-white/20 rounded-full transition-all disabled:opacity-30 disabled:cursor-not-allowed"
							title="Zoom in (+)"
						>
							<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v6m3-3H7" />
							</svg>
						</button>
						{scale !== 1 && (
							<button
								onClick={resetZoom}
								className="ml-2 p-2 text-white hover:bg-white/20 rounded-full transition-all"
								title="Reset zoom (0)"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
								</svg>
							</button>
						)}
					</div>

					{/* Hint Text */}
					<div className="hidden md:block text-white/60 text-xs bg-white/5 px-3 py-1.5 rounded-full backdrop-blur-sm">
						Ctrl + Scroll to zoom • Arrow keys to navigate
					</div>
				</div>
			</div>

			{/* Thumbnail strip (optional, for many images) */}
			{images.length > 1 && images.length <= 10 && (
				<div className="absolute bottom-20 left-0 right-0 z-10">
					<div className="flex items-center justify-center gap-2 px-4 overflow-x-auto">
						{images.map((img, idx) => (
							<button
								key={idx}
								onClick={() => setCurrentIndex(idx)}
								className={`flex-shrink-0 w-16 h-16 rounded-lg overflow-hidden border-2 transition-all ${
									idx === currentIndex
										? 'border-white scale-110 shadow-lg'
										: 'border-white/30 hover:border-white/60 opacity-60 hover:opacity-100'
								}`}
							>
								<img
									src={img}
									alt={`Thumbnail ${idx + 1}`}
									className="w-full h-full object-cover"
								/>
							</button>
						))}
					</div>
				</div>
			)}
		</div>
	);
}
