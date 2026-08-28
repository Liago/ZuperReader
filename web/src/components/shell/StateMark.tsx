import { Bookmark } from 'lucide-react';

export type StateMarkVariant = 'unread' | 'reading' | 'completed' | 'everything' | 'favourites';

interface StateMarkProps {
	variant: StateMarkVariant;
	className?: string;
}

/**
 * The quiet reading-state marks used across the sidebar, cards and rows
 * (README §State marks). Replaces the old uppercase gradient badges.
 */
export default function StateMark({ variant, className = '' }: StateMarkProps) {
	if (variant === 'favourites') {
		return (
			<Bookmark
				size={13}
				strokeWidth={2.75}
				className={`text-accent ${className}`}
				fill="currentColor"
				aria-hidden
			/>
		);
	}

	const base = 'inline-block flex-none rounded-full';

	switch (variant) {
		case 'unread':
			return <span className={`${base} h-[7px] w-[7px] bg-accent ${className}`} aria-hidden />;
		case 'reading':
			return (
				<span
					className={`${base} h-[7px] w-[7px] border-2 border-accent bg-transparent ${className}`}
					aria-hidden
				/>
			);
		case 'completed':
			return <span className={`${base} h-[7px] w-[7px] bg-sage ${className}`} aria-hidden />;
		case 'everything':
		default:
			return (
				<span
					className={`${base} h-2 w-2 bg-current opacity-30 ${className}`}
					aria-hidden
				/>
			);
	}
}
