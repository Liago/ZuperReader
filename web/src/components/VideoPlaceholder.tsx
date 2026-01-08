'use client';

import { useState, useEffect } from 'react';

export interface VideoInfo {
	src: string;
	thumbnailUrl: string;
	title?: string;
	provider: 'youtube' | 'vimeo' | 'reddit' | 'unknown';
	videoId?: string;
	duration?: string;
}

interface VideoPlaceholderProps {
	videoInfo: VideoInfo;
	onClick: () => void;
	colorTheme?: 'light' | 'dark' | 'ocean' | 'forest' | 'sunset';
}

// Extract video ID and thumbnail from various providers
export function extractVideoInfo(src: string): VideoInfo {
	let provider: VideoInfo['provider'] = 'unknown';
	let videoId: string | undefined;
	let thumbnailUrl = '';

	// YouTube
	const youtubeMatch = src.match(/(?:youtube\.com\/embed\/|youtube-nocookie\.com\/embed\/|youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
	if (youtubeMatch) {
		provider = 'youtube';
		videoId = youtubeMatch[1];
		thumbnailUrl = `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`;
	}

	// Vimeo
	const vimeoMatch = src.match(/vimeo\.com\/(?:video\/)?(\d+)/);
	if (vimeoMatch) {
		provider = 'vimeo';
		videoId = vimeoMatch[1];
		// Vimeo thumbnails require API call, use placeholder
		thumbnailUrl = '';
	}

	// Reddit
	if (src.includes('redditmedia.com') || src.includes('reddit.com')) {
		provider = 'reddit';
		thumbnailUrl = '';
	}

	return {
		src,
		thumbnailUrl,
		provider,
		videoId,
	};
}

// Provider icons
const ProviderIcon = ({ provider }: { provider: VideoInfo['provider'] }) => {
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

// Provider colors
const getProviderColor = (provider: VideoInfo['provider']) => {
	switch (provider) {
		case 'youtube':
			return 'from-red-600 to-red-700';
		case 'vimeo':
			return 'from-cyan-500 to-blue-600';
		case 'reddit':
			return 'from-orange-500 to-orange-600';
		default:
			return 'from-purple-500 to-pink-600';
	}
};

const getProviderName = (provider: VideoInfo['provider']) => {
	switch (provider) {
		case 'youtube':
			return 'YouTube';
		case 'vimeo':
			return 'Vimeo';
		case 'reddit':
			return 'Reddit';
		default:
			return 'Video';
	}
};

export default function VideoPlaceholder({ videoInfo, onClick, colorTheme = 'light' }: VideoPlaceholderProps) {
	const [imageLoaded, setImageLoaded] = useState(false);
	const [imageError, setImageError] = useState(false);
	const [vimeoThumbnail, setVimeoThumbnail] = useState<string | null>(null);

	// Fetch Vimeo thumbnail via oEmbed
	useEffect(() => {
		if (videoInfo.provider === 'vimeo' && videoInfo.videoId) {
			fetch(`https://vimeo.com/api/oembed.json?url=https://vimeo.com/${videoInfo.videoId}`)
				.then(res => res.json())
				.then(data => {
					if (data.thumbnail_url) {
						// Get higher resolution thumbnail
						const highResThumbnail = data.thumbnail_url.replace(/_\d+x\d+/, '_1280x720');
						setVimeoThumbnail(highResThumbnail);
					}
				})
				.catch(() => {
					// Silently fail, will use fallback
				});
		}
	}, [videoInfo.provider, videoInfo.videoId]);

	const thumbnailUrl = videoInfo.provider === 'vimeo'
		? vimeoThumbnail
		: videoInfo.thumbnailUrl;

	const isDark = colorTheme === 'dark';

	console.log(`VideoPlaceholder: Rendering for ${videoInfo.provider}`, { videoInfo, imageLoaded, imageError, isDark });

	return (
		<div
			className="video-placeholder-container relative w-full rounded-2xl overflow-hidden cursor-pointer group my-6"
			onClick={onClick}
			role="button"
			tabIndex={0}
			onKeyDown={(e) => e.key === 'Enter' && onClick()}
			aria-label={`Play ${videoInfo.title || 'video'}`}
			style={{ aspectRatio: '16/9' }}
		>
			{/* Background / Thumbnail */}
			<div className={`absolute inset-0 ${isDark ? 'bg-slate-800' : 'bg-gray-100'}`}>
				{thumbnailUrl && !imageError ? (
					<>
						<img
							src={thumbnailUrl}
							alt={videoInfo.title || 'Video thumbnail'}
							className={`absolute inset-0 w-full h-full object-cover transition-all duration-500 ${imageLoaded ? 'opacity-100 scale-100' : 'opacity-0 scale-105'
								} group-hover:scale-105`}
							onLoad={() => setImageLoaded(true)}
							onError={() => setImageError(true)}
						/>
						{/* Loading skeleton */}
						{!imageLoaded && (
							<div className={`absolute inset-0 animate-pulse ${isDark ? 'bg-slate-700' : 'bg-gray-200'}`} />
						)}
					</>
				) : (
					/* Fallback gradient for videos without thumbnails */
					<div className={`absolute inset-0 bg-gradient-to-br ${getProviderColor(videoInfo.provider)} opacity-20`} />
				)}
			</div>

			{/* Gradient Overlay */}
			<div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent opacity-60 group-hover:opacity-80 transition-opacity duration-300" />

			{/* Center Play Button */}
			<div className="absolute inset-0 flex items-center justify-center">
				<div className={`
					relative w-20 h-20 md:w-24 md:h-24 rounded-full
					bg-gradient-to-br ${getProviderColor(videoInfo.provider)}
					flex items-center justify-center
					shadow-2xl shadow-black/30
					transform transition-all duration-300 ease-out
					group-hover:scale-110 group-hover:shadow-3xl
					group-active:scale-95
				`}>
					{/* Pulsing ring effect */}
					<div className={`
						absolute inset-0 rounded-full
						bg-gradient-to-br ${getProviderColor(videoInfo.provider)}
						animate-ping opacity-30
					`} />

					{/* Play icon */}
					<svg
						className="w-8 h-8 md:w-10 md:h-10 text-white ml-1 relative z-10"
						fill="currentColor"
						viewBox="0 0 24 24"
					>
						<path d="M8 5v14l11-7z" />
					</svg>
				</div>
			</div>

			{/* Provider Badge */}
			<div className="absolute top-4 left-4">
				<div className={`
					flex items-center gap-2 px-3 py-1.5 rounded-full
					bg-white/95 dark:bg-slate-900/95 backdrop-blur-md
					shadow-lg border border-white/20
					transform transition-all duration-300
					group-hover:translate-y-0.5
				`}>
					<span className={`text-${videoInfo.provider === 'youtube' ? 'red-600' : videoInfo.provider === 'vimeo' ? 'cyan-600' : 'orange-500'}`}>
						<ProviderIcon provider={videoInfo.provider} />
					</span>
					<span className={`text-sm font-semibold ${isDark ? 'text-slate-200' : 'text-gray-800'}`}>
						{getProviderName(videoInfo.provider)}
					</span>
				</div>
			</div>

			{/* Duration Badge (if available) */}
			{videoInfo.duration && (
				<div className="absolute top-4 right-4">
					<div className="px-2.5 py-1 rounded-md bg-black/70 backdrop-blur-sm text-white text-sm font-medium">
						{videoInfo.duration}
					</div>
				</div>
			)}

			{/* Bottom Info Bar */}
			<div className="absolute bottom-0 left-0 right-0 p-4">
				<div className="flex items-center gap-3">
					{/* Play hint */}
					<div className={`
						flex items-center gap-2 px-4 py-2 rounded-xl
						bg-white/10 backdrop-blur-md
						border border-white/20
						text-white text-sm font-medium
						transform transition-all duration-300
						group-hover:bg-white/20
					`}>
						<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
						</svg>
						<span>Click to play</span>
					</div>

					{/* Title (if available) */}
					{videoInfo.title && (
						<span className="text-white/80 text-sm truncate flex-1">
							{videoInfo.title}
						</span>
					)}
				</div>
			</div>

			{/* Hover glow effect */}
			<div className={`
				absolute inset-0 opacity-0 group-hover:opacity-100
				transition-opacity duration-500 pointer-events-none
				bg-gradient-to-t ${getProviderColor(videoInfo.provider)} mix-blend-overlay
			`} style={{ opacity: 0.1 }} />
		</div>
	);
}
