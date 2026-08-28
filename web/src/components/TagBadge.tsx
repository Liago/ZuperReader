'use client';

interface TagBadgeProps {
	tag: string;
	onRemove?: () => void;
	onClick?: () => void;
	size?: 'sm' | 'md';
	removable?: boolean;
}

// Two-voice tag palette (Organic): a stable hash picks terracotta or sage so a
// given tag always reads the same colour across the app.
function tagTone(tag: string): 'accent' | 'sage' {
	let hash = 0;
	for (let i = 0; i < tag.length; i++) hash = (hash * 31 + tag.charCodeAt(i)) | 0;
	return Math.abs(hash) % 2 === 0 ? 'accent' : 'sage';
}

function toneClasses(tone: 'accent' | 'sage') {
	return tone === 'accent'
		? 'bg-accent-200 text-accent-800'
		: 'bg-sage-200 text-sage-800';
}

export default function TagBadge({
	tag,
	onRemove,
	onClick,
	size = 'sm',
	removable = false,
}: TagBadgeProps) {
	const sizeClasses = size === 'sm'
		? 'px-2.5 py-[3px] text-[11px]'
		: 'px-3 py-1 text-[12.5px]';

	const handleRemoveClick = (e: React.MouseEvent) => {
		e.stopPropagation();
		onRemove?.();
	};

	return (
		<span
			onClick={onClick}
			className={`
				inline-flex items-center gap-1 rounded-full font-medium tracking-[0.02em]
				${toneClasses(tagTone(tag))}
				${sizeClasses}
				${onClick ? 'cursor-pointer transition-opacity hover:opacity-80' : ''}
				${removable ? 'pr-1' : ''}
			`}
		>
			<span className="max-w-[120px] truncate">{tag}</span>
			{removable && onRemove && (
				<button
					onClick={handleRemoveClick}
					className={`
						shrink-0 rounded-full p-0.5 transition-colors hover:bg-black/10
						${size === 'sm' ? 'ml-0.5' : 'ml-1'}
					`}
					aria-label={`Remove ${tag} tag`}
				>
					<svg
						className={size === 'sm' ? 'h-3 w-3' : 'h-4 w-4'}
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
					inline-flex items-center rounded-full font-medium text-app-muted
					${size === 'sm' ? 'px-2.5 py-[3px] text-[11px]' : 'px-3 py-1 text-[12.5px]'}
				`}>
					+{hiddenCount} more
				</span>
			)}
		</div>
	);
}
