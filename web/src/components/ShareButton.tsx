'use client';

import { useState, useEffect } from 'react';
import { Share2, Link2, Check } from 'lucide-react';
import { shareArticle, getSharesCount } from '@/lib/api';

interface ShareButtonProps {
	articleId: string;
	userId: string;
	articleUrl: string;
	articleTitle: string;
}

export default function ShareButton({ articleId, userId, articleUrl, articleTitle }: ShareButtonProps) {
	const [, setSharesCount] = useState(0);
	const [showShareMenu, setShowShareMenu] = useState(false);
	const [copied, setCopied] = useState(false);

	useEffect(() => {
		getSharesCount(articleId)
			.then(setSharesCount)
			.catch((error) => console.error('Error loading shares count:', error));
	}, [articleId]);

	const handleShare = async (platform?: string) => {
		try {
			await shareArticle(articleId, userId);
			setSharesCount((prev) => prev + 1);

			if (platform === 'twitter') {
				window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(articleTitle)}&url=${encodeURIComponent(articleUrl)}`, '_blank', 'noopener,noreferrer');
			} else if (platform === 'facebook') {
				window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(articleUrl)}`, '_blank', 'noopener,noreferrer');
			} else if (platform === 'linkedin') {
				window.open(`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(articleUrl)}`, '_blank', 'noopener,noreferrer');
			} else if (platform === 'whatsapp') {
				window.open(`https://wa.me/?text=${encodeURIComponent(articleTitle + ' ' + articleUrl)}`, '_blank', 'noopener,noreferrer');
			}

			setShowShareMenu(false);
		} catch (error) {
			console.error('Error sharing article:', error);
			alert('Failed to share article');
		}
	};

	const handleCopyLink = async () => {
		try {
			await navigator.clipboard.writeText(articleUrl);
			await shareArticle(articleId, userId);
			setSharesCount((prev) => prev + 1);
			setCopied(true);
			setTimeout(() => {
				setCopied(false);
				setShowShareMenu(false);
			}, 2000);
		} catch (error) {
			console.error('Error copying link:', error);
			alert('Failed to copy link');
		}
	};

	const menuItem = 'flex w-full items-center gap-3 px-4 py-2 text-left text-[13.5px] text-ink transition-colors hover:bg-app-hover';

	return (
		<div className="relative">
			<button
				onClick={() => setShowShareMenu(!showShareMenu)}
				title="Share"
				className="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full border border-app-line text-app-muted transition-colors hover:bg-app-hover hover:text-ink"
			>
				<Share2 size={16} strokeWidth={2.75} />
			</button>

			{showShareMenu && (
				<>
					<div className="fixed inset-0 z-40" onClick={() => setShowShareMenu(false)} />
					<div className="absolute right-0 z-50 mt-2 w-56 overflow-hidden rounded-2xl border border-app-line bg-app-card py-1.5 [box-shadow:var(--shadow-modal)]">
						<button onClick={() => handleShare('twitter')} className={menuItem}>Share on Twitter</button>
						<button onClick={() => handleShare('facebook')} className={menuItem}>Share on Facebook</button>
						<button onClick={() => handleShare('linkedin')} className={menuItem}>Share on LinkedIn</button>
						<button onClick={() => handleShare('whatsapp')} className={menuItem}>Share on WhatsApp</button>
						<div className="my-1.5 h-px bg-app-line" />
						<button onClick={handleCopyLink} className={menuItem}>
							{copied ? <Check size={16} strokeWidth={2.75} className="text-sage" /> : <Link2 size={16} strokeWidth={2.75} className="text-app-muted" />}
							<span>{copied ? 'Copied!' : 'Copy link'}</span>
						</button>
					</div>
				</>
			)}
		</div>
	);
}
