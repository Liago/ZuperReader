'use client';

import { getTagColor } from '../lib/tagSuggestionService';

interface TagBadgeProps {
	tag: string;
	onRemove?: () => void;
	onClick?: () => void;
	size?: 'sm' | 'md';
	removable?: boolean;
}

export default function TagBadge({
	tag,
	onRemove,
	onClick,
	size = 'sm',
	removable = false,
}: TagBadgeProps) {
	const colors = getTagColor(tag);

	const sizeClasses = size === 'sm'
		? 'px-2 py-0.5 text-xs'
		: 'px-3 py-1 text-sm';

	const handleRemoveClick = (e: React.MouseEvent) => {
		e.stopPropagation();
		onRemove?.();
	};

	return (
		<span
			onClick={onClick}
			className={`
				inline-flex items-center gap-1 rounded-full font-medium border
				${colors.bg} ${colors.text} ${colors.border}
				${sizeClasses}
				${onClick ? 'cursor-pointer hover:opacity-80 transition-opacity' : ''}
				${removable ? 'pr-1' : ''}
			`}
		>
			<span className="truncate max-w-[120px]">{tag}</span>
			{removable && onRemove && (
				<button
					onClick={handleRemoveClick}
					className={`
						flex-shrink-0 rounded-full p-0.5
						hover:bg-black/10 transition-colors
						${size === 'sm' ? 'ml-0.5' : 'ml-1'}
					`}
					aria-label={`Remove ${tag} tag`}
				>
					<svg
						className={size === 'sm' ? 'w-3 h-3' : 'w-4 h-4'}
						fill="none"
						viewBox="0 0 24 24"
						stroke="currentColor"
					>
						<path
							strokeLinecap="round"
							strokeLinejoin="round"
							strokeWidth={2}
							d="M6 18L18 6M6 6l12 12"
						/>
					</svg>
				</button>
			)}
		</span>
	);
}

// Component for displaying multiple tags
interface TagListProps {
	tags: string[];
	onTagClick?: (tag: string) => void;
	onTagRemove?: (tag: string) => void;
	maxVisible?: number;
	size?: 'sm' | 'md';
	removable?: boolean;
}

export function TagList({
	tags,
	onTagClick,
	onTagRemove,
	maxVisible = 5,
	size = 'sm',
	removable = false,
}: TagListProps) {
	if (!tags || tags.length === 0) return null;

	const visibleTags = tags.slice(0, maxVisible);
	const hiddenCount = tags.length - maxVisible;

	return (
		<div className="flex flex-wrap gap-1.5">
			{visibleTags.map((tag) => (
				<TagBadge
					key={tag}
					tag={tag}
					size={size}
					onClick={onTagClick ? () => onTagClick(tag) : undefined}
					onRemove={onTagRemove ? () => onTagRemove(tag) : undefined}
					removable={removable}
				/>
			))}
			{hiddenCount > 0 && (
				<span className={`
					inline-flex items-center rounded-full font-medium
					bg-gray-100 text-gray-600 border border-gray-200
					${size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-3 py-1 text-sm'}
				`}>
					+{hiddenCount} more
				</span>
			)}
		</div>
	);
}
