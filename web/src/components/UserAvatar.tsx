'use client';

import { useState } from 'react';

interface UserAvatarProps {
	avatarUrl?: string | null;
	displayName?: string | null;
	size?: 'xs' | 'sm' | 'md' | 'lg';
	className?: string;
}

export default function UserAvatar({
	avatarUrl,
	displayName,
	size = 'sm',
	className = ''
}: UserAvatarProps) {
	const [imageError, setImageError] = useState(false);

	const sizeClasses = {
		xs: 'w-6 h-6 text-xs',
		sm: 'w-8 h-8 text-sm',
		md: 'w-12 h-12 text-base',
		lg: 'w-16 h-16 text-xl'
	};

	const getInitial = () => {
		if (displayName && displayName.length > 0) {
			return displayName.charAt(0).toUpperCase();
		}
		return '?';
	};

	// Show image if URL exists and hasn't errored
	if (avatarUrl && !imageError) {
		return (
			<img
				src={avatarUrl}
				alt={displayName || 'User'}
				className={`${sizeClasses[size]} rounded-full object-cover ${className}`}
				onError={() => setImageError(true)}
			/>
		);
	}

	// Fallback to initial
	return (
		<div
			className={`${sizeClasses[size]} rounded-full bg-gradient-to-br from-purple-400 to-pink-400 flex items-center justify-center text-white font-semibold ${className}`}
		>
			{getInitial()}
		</div>
	);
}
