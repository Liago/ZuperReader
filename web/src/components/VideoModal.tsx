'use client';

import { useEffect, useCallback } from 'react';

interface VideoModalProps {
	isOpen: boolean;
	onClose: () => void;
	videoSrc: string;
	videoTitle?: string;
}

export default function VideoModal({ isOpen, onClose, videoSrc, videoTitle }: VideoModalProps) {
	// Close on ESC key
	const handleEscKey = useCallback((e: KeyboardEvent) => {
		if (e.key === 'Escape') {
			onClose();
		}
	}, [onClose]);

	useEffect(() => {
		if (isOpen) {
			document.addEventListener('keydown', handleEscKey);
			// Prevent body scroll when modal is open
			document.body.style.overflow = 'hidden';
		}

		return () => {
			document.removeEventListener('keydown', handleEscKey);
			document.body.style.overflow = 'unset';
		};
	}, [isOpen, handleEscKey]);

	if (!isOpen) return null;

	return (
		<div
			className="fixed inset-0 bg-black/90 backdrop-blur-md flex items-center justify-center p-4 z-50 animate-fadeIn"
			onClick={onClose}
		>
			<div
				className="relative w-full max-w-6xl mx-auto transform transition-all animate-scaleIn"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header */}
				<div className="flex items-center justify-between mb-4 px-2">
					<div className="flex items-center gap-3">
						<div className="w-10 h-10 bg-gradient-to-br from-red-500 via-purple-500 to-pink-500 rounded-xl flex items-center justify-center shadow-lg">
							<svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
								<path d="M8 5v14l11-7z" />
							</svg>
						</div>
						{videoTitle && (
							<h2 className="text-xl font-bold text-white drop-shadow-lg">{videoTitle}</h2>
						)}
					</div>
					<button
						onClick={onClose}
						className="p-2.5 text-white/80 hover:text-white hover:bg-white/10 rounded-xl transition-all duration-200 backdrop-blur-sm"
						aria-label="Close video"
					>
						<svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				{/* Video Container */}
				<div className="relative w-full bg-black rounded-2xl shadow-2xl overflow-hidden" style={{ paddingBottom: '56.25%' }}>
					<iframe
						src={videoSrc}
						className="absolute inset-0 w-full h-full"
						allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
						allowFullScreen
						style={{ border: 'none' }}
					/>
				</div>

				{/* Instructions hint */}
				<div className="mt-4 text-center">
					<p className="text-sm text-white/60">
						Press <kbd className="px-2 py-1 bg-white/10 rounded text-white/80 font-mono text-xs">ESC</kbd> or click outside to close
					</p>
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
					animation: fadeIn 0.2s ease-out;
				}

				.animate-scaleIn {
					animation: scaleIn 0.3s ease-out;
				}
			`}</style>
		</div>
	);
}
