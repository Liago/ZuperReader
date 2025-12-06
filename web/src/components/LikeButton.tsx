'use client';

import { useState, useEffect } from 'react';
import { toggleLike, checkIfUserLiked } from '@/lib/api';

interface LikeButtonProps {
	articleId: string;
	userId: string;
	initialLikeCount: number;
}

export default function LikeButton({ articleId, userId, initialLikeCount }: LikeButtonProps) {
	const [liked, setLiked] = useState(false);
	const [likeCount, setLikeCount] = useState(initialLikeCount);
	const [loading, setLoading] = useState(false);

	useEffect(() => {
		const checkLiked = async () => {
			try {
				const isLiked = await checkIfUserLiked(articleId, userId);
				setLiked(isLiked);
			} catch (error) {
				console.error('Error checking if user liked:', error);
			}
		};

		checkLiked();
	}, [articleId, userId]);

	const handleLike = async () => {
		if (loading) return;

		setLoading(true);
		try {
			const result = await toggleLike(articleId, userId);
			setLiked(result.liked);
			setLikeCount(result.likeCount);
		} catch (error) {
			console.error('Error toggling like:', error);
		} finally {
			setLoading(false);
		}
	};

	return (
		<button
			onClick={handleLike}
			disabled={loading}
			className={`flex items-center gap-2 px-4 py-2 rounded-full transition-all duration-200 ${
				liked
					? 'bg-red-500 text-white hover:bg-red-600'
					: 'bg-gray-200 text-gray-700 hover:bg-gray-300'
			} ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
		>
			<svg
				className={`w-5 h-5 transition-transform ${liked ? 'scale-110' : ''}`}
				fill={liked ? 'currentColor' : 'none'}
				stroke="currentColor"
				strokeWidth="2"
				viewBox="0 0 24 24"
			>
				<path
					strokeLinecap="round"
					strokeLinejoin="round"
					d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
				/>
			</svg>
			<span className="font-medium">{likeCount}</span>
		</button>
	);
}
