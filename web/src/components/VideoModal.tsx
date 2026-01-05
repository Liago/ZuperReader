'use client';

import { useEffect, useCallback, useState, useRef } from 'react';
import { VideoInfo } from './VideoPlaceholder';

interface VideoModalProps {
	isOpen: boolean;
	onClose: () => void;
	videoSrc: string;
	videoTitle?: string;
	videoInfo?: VideoInfo;
}

// Provider icons (same as VideoPlaceholder)
const ProviderIcon = ({ provider }: { provider?: VideoInfo['provider'] }) => {
	switch (provider) {
		case 'youtube':
			return (
				<svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
					<path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" />
				</svg>
			);
		case 'vimeo':
			return (
				<svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
					<path d="M23.977 6.416c-.105 2.338-1.739 5.543-4.894 9.609-3.268 4.247-6.026 6.37-8.29 6.37-1.409 0-2.578-1.294-3.553-3.881L5.322 11.4C4.603 8.816 3.834 7.522 3.01 7.522c-.179 0-.806.378-1.881 1.132L0 7.197a315.065 315.065 0 0 0 3.501-3.128C5.08 2.701 6.266 1.984 7.055 1.91c1.867-.18 3.016 1.1 3.447 3.838.465 2.953.789 4.789.971 5.507.539 2.45 1.131 3.674 1.776 3.674.502 0 1.256-.796 2.265-2.385 1.004-1.589 1.54-2.797 1.612-3.628.144-1.371-.395-2.061-1.614-2.061-.574 0-1.167.121-1.777.391 1.186-3.868 3.434-5.757 6.762-5.637 2.473.06 3.628 1.664 3.493 4.797l-.013.01z" />
				</svg>
			);
		case 'reddit':
			return (
				<svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
					<path d="M12 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0zm5.01 4.744c.688 0 1.25.561 1.25 1.249a1.25 1.25 0 0 1-2.498.056l-2.597-.547-.8 3.747c1.824.07 3.48.632 4.674 1.488.308-.309.73-.491 1.207-.491.968 0 1.754.786 1.754 1.754 0 .716-.435 1.333-1.01 1.614a3.111 3.111 0 0 1 .042.52c0 2.694-3.13 4.87-7.004 4.87-3.874 0-7.004-2.176-7.004-4.87 0-.183.015-.366.043-.534A1.748 1.748 0 0 1 4.028 12c0-.968.786-1.754 1.754-1.754.463 0 .898.196 1.207.49 1.207-.883 2.878-1.43 4.744-1.487l.885-4.182a.342.342 0 0 1 .14-.197.35.35 0 0 1 .238-.042l2.906.617a1.214 1.214 0 0 1 1.108-.701zM9.25 12C8.561 12 8 12.562 8 13.25c0 .687.561 1.248 1.25 1.248.687 0 1.248-.561 1.248-1.249 0-.688-.561-1.249-1.249-1.249zm5.5 0c-.687 0-1.248.561-1.248 1.25 0 .687.561 1.248 1.249 1.248.688 0 1.249-.561 1.249-1.249 0-.687-.562-1.249-1.25-1.249zm-5.466 3.99a.327.327 0 0 0-.231.094.33.33 0 0 0 0 .463c.842.842 2.484.913 2.961.913.477 0 2.105-.056 2.961-.913a.361.361 0 0 0 .029-.463.33.33 0 0 0-.464 0c-.547.533-1.684.73-2.512.73-.828 0-1.979-.196-2.512-.73a.326.326 0 0 0-.232-.095z" />
				</svg>
			);
		default:
			return (
				<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
				</svg>
			);
	}
};

const getProviderColor = (provider?: VideoInfo['provider']) => {
	switch (provider) {
		case 'youtube':
			return { gradient: 'from-red-500 via-red-600 to-red-700', text: 'text-red-500', bg: 'bg-red-500' };
		case 'vimeo':
			return { gradient: 'from-cyan-500 via-blue-500 to-blue-600', text: 'text-cyan-500', bg: 'bg-cyan-500' };
		case 'reddit':
			return { gradient: 'from-orange-500 via-orange-600 to-red-600', text: 'text-orange-500', bg: 'bg-orange-500' };
		default:
			return { gradient: 'from-purple-500 via-pink-500 to-rose-500', text: 'text-purple-500', bg: 'bg-purple-500' };
	}
};

const getProviderName = (provider?: VideoInfo['provider']) => {
	switch (provider) {
		case 'youtube': return 'YouTube';
		case 'vimeo': return 'Vimeo';
		case 'reddit': return 'Reddit';
		default: return 'Video';
	}
};

export default function VideoModal({ isOpen, onClose, videoSrc, videoTitle, videoInfo }: VideoModalProps) {
	const [isLoading, setIsLoading] = useState(true);
	const [showControls, setShowControls] = useState(true);
	const iframeRef = useRef<HTMLIFrameElement>(null);
	const controlsTimeoutRef = useRef<NodeJS.Timeout | null>(null);

	const providerColors = getProviderColor(videoInfo?.provider);

	// Close on ESC key
	const handleEscKey = useCallback((e: KeyboardEvent) => {
		if (e.key === 'Escape') {
			onClose();
		}
	}, [onClose]);

	// Handle fullscreen toggle
	const toggleFullscreen = useCallback(() => {
		const container = document.querySelector('.video-modal-container');
		if (!container) return;

		if (!document.fullscreenElement) {
			container.requestFullscreen?.();
		} else {
			document.exitFullscreen?.();
		}
	}, []);

	// Auto-hide controls
	const resetControlsTimeout = useCallback(() => {
		setShowControls(true);
		if (controlsTimeoutRef.current) {
			clearTimeout(controlsTimeoutRef.current);
		}
		controlsTimeoutRef.current = setTimeout(() => {
			setShowControls(false);
		}, 3000);
	}, []);

	useEffect(() => {
		if (isOpen) {
			document.addEventListener('keydown', handleEscKey);
			document.body.style.overflow = 'hidden';
			setIsLoading(true);
			resetControlsTimeout();
		}

		return () => {
			document.removeEventListener('keydown', handleEscKey);
			document.body.style.overflow = 'unset';
			if (controlsTimeoutRef.current) {
				clearTimeout(controlsTimeoutRef.current);
			}
		};
	}, [isOpen, handleEscKey, resetControlsTimeout]);

	if (!isOpen) return null;

	// Ensure autoplay for embedded videos
	const getAutoplaySrc = (src: string) => {
		const url = new URL(src, window.location.origin);
		url.searchParams.set('autoplay', '1');
		if (src.includes('youtube')) {
			url.searchParams.set('rel', '0'); // Don't show related videos
		}
		return url.toString();
	};

	return (
		<div
			className="fixed inset-0 z-50"
			onClick={onClose}
			onMouseMove={resetControlsTimeout}
		>
			{/* Backdrop with blur */}
			<div className="absolute inset-0 bg-black/95 backdrop-blur-xl animate-fadeIn" />

			{/* Video Container */}
			<div
				className="video-modal-container relative w-full h-full flex flex-col animate-scaleIn"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header - Hidden on mouse idle */}
				<div className={`
					absolute top-0 left-0 right-0 z-20 p-4 md:p-6
					bg-gradient-to-b from-black/80 via-black/40 to-transparent
					transition-all duration-500
					${showControls ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-4'}
				`}>
					<div className="flex items-center justify-between max-w-7xl mx-auto">
						{/* Left - Provider & Title */}
						<div className="flex items-center gap-4">
							{/* Provider Badge */}
							<div className={`
								flex items-center gap-2.5 px-4 py-2 rounded-xl
								bg-white/10 backdrop-blur-md border border-white/10
								shadow-lg
							`}>
								<div className={`p-1.5 rounded-lg bg-gradient-to-br ${providerColors.gradient}`}>
									<span className="text-white">
										<ProviderIcon provider={videoInfo?.provider} />
									</span>
								</div>
								<span className="text-white font-semibold text-sm md:text-base">
									{getProviderName(videoInfo?.provider)}
								</span>
							</div>

							{/* Title */}
							{(videoTitle || videoInfo?.title) && (
								<h2 className="text-white font-bold text-lg md:text-xl drop-shadow-lg truncate max-w-md">
									{videoTitle || videoInfo?.title}
								</h2>
							)}
						</div>

						{/* Right - Controls */}
						<div className="flex items-center gap-2">
							{/* Fullscreen Button */}
							<button
								onClick={toggleFullscreen}
								className="p-3 text-white/80 hover:text-white hover:bg-white/10 rounded-xl transition-all duration-200 backdrop-blur-sm"
								aria-label="Toggle fullscreen"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
								</svg>
							</button>

							{/* Close Button */}
							<button
								onClick={onClose}
								className="p-3 text-white/80 hover:text-white hover:bg-white/10 rounded-xl transition-all duration-200 backdrop-blur-sm"
								aria-label="Close video"
							>
								<svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
								</svg>
							</button>
						</div>
					</div>
				</div>

				{/* Video Player Area */}
				<div className="flex-1 flex items-center justify-center p-4 md:p-8">
					<div className="relative w-full max-w-7xl mx-auto rounded-2xl overflow-hidden shadow-2xl bg-black">
						{/* Aspect ratio container */}
						<div className="relative w-full" style={{ paddingBottom: '56.25%' }}>
							{/* Loading State */}
							{isLoading && (
								<div className="absolute inset-0 flex items-center justify-center bg-black z-10">
									<div className="flex flex-col items-center gap-4">
										{/* Animated loader */}
										<div className="relative">
											<div className={`w-16 h-16 rounded-full border-4 border-white/20 border-t-transparent animate-spin`}
												style={{ borderTopColor: providerColors.bg.replace('bg-', '') }} />
											<div className="absolute inset-0 flex items-center justify-center">
												<svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 24 24">
													<path d="M8 5v14l11-7z" />
												</svg>
											</div>
										</div>
										<p className="text-white/60 text-sm font-medium">Loading video...</p>
									</div>
								</div>
							)}

							{/* Video iframe */}
							<iframe
								ref={iframeRef}
								src={getAutoplaySrc(videoSrc)}
								className="absolute inset-0 w-full h-full"
								allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
								allowFullScreen
								style={{ border: 'none' }}
								onLoad={() => setIsLoading(false)}
							/>
						</div>

						{/* Decorative glow effect */}
						<div className={`absolute -inset-1 bg-gradient-to-r ${providerColors.gradient} opacity-20 blur-2xl -z-10`} />
					</div>
				</div>

				{/* Footer - Hidden on mouse idle */}
				<div className={`
					absolute bottom-0 left-0 right-0 z-20 p-4 md:p-6
					bg-gradient-to-t from-black/80 via-black/40 to-transparent
					transition-all duration-500
					${showControls ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}
				`}>
					<div className="max-w-7xl mx-auto flex items-center justify-center gap-8">
						{/* Keyboard hints */}
						<div className="flex items-center gap-4 text-white/50 text-sm">
							<div className="flex items-center gap-2">
								<kbd className="px-2.5 py-1 bg-white/10 rounded-lg text-white/80 font-mono text-xs border border-white/10">
									ESC
								</kbd>
								<span>Close</span>
							</div>
							<div className="flex items-center gap-2">
								<kbd className="px-2.5 py-1 bg-white/10 rounded-lg text-white/80 font-mono text-xs border border-white/10">
									F
								</kbd>
								<span>Fullscreen</span>
							</div>
						</div>
					</div>
				</div>
			</div>

			<style jsx>{`
				@keyframes fadeIn {
					from {
						opacity: 0;
					}
					to {
						opacity: 1;
					}
				}

				@keyframes scaleIn {
					from {
						opacity: 0;
						transform: scale(0.95);
					}
					to {
						opacity: 1;
						transform: scale(1);
					}
				}

				.animate-fadeIn {
					animation: fadeIn 0.3s ease-out;
				}

				.animate-scaleIn {
					animation: scaleIn 0.4s cubic-bezier(0.16, 1, 0.3, 1);
				}
			`}</style>
		</div>
	);
}
