import { Bookmark, BookOpen, Trash2 } from 'lucide-react';
import { Article } from '../lib/supabase';
import OptimizedImage from './OptimizedImage';
import { TagList } from './TagBadge';
import StateMark, { StateMarkVariant } from './shell/StateMark';

interface ArticleRowProps {
	article: Article;
	onClick: (articleId: string) => void;
	onToggleFavorite: (e: React.MouseEvent, article: Article) => void;
	onDelete: (e: React.MouseEvent, article: Article) => void;
	onEditTags: (e: React.MouseEvent, article: Article) => void;
	index?: number;
}

function markFor(status: Article['reading_status']): StateMarkVariant {
	if (status === 'unread') return 'unread';
	if (status === 'reading') return 'reading';
	return 'completed';
}

export default function ArticleRow({
	article,
	onClick,
	onToggleFavorite,
	onDelete,
	onEditTags,
	index = 0,
}: ArticleRowProps) {
	const finished = article.reading_status === 'completed';
	const date = article.created_at
		? new Date(article.created_at).toLocaleDateString('en-US', { day: 'numeric', month: 'short' })
		: '';

	return (
		<article
			onClick={() => onClick(article.id)}
			className="flex cursor-pointer items-center gap-5 px-[22px] py-[18px] transition-colors hover:bg-app-hover"
		>
			{/* Cover thumb */}
			<div className="relative h-[76px] w-28 flex-none overflow-hidden rounded-2xl bg-app-surface">
				{article.image_url ? (
					<OptimizedImage
						src={article.image_url}
						alt={article.title}
						className="washed h-full w-full object-cover"
						priority={index < 4}
					/>
				) : (
					<div className="flex h-full w-full items-center justify-center">
						<BookOpen size={24} className="text-accent opacity-50" strokeWidth={1.75} />
					</div>
				)}
			</div>

			{/* Content */}
			<div className="min-w-0 flex-1">
				<div className="mb-1 flex items-center gap-2 text-[12px] text-app-muted">
					<StateMark variant={markFor(article.reading_status)} />
					{article.domain && <span className="font-semibold text-ink">{article.domain}</span>}
					{date && <span>·</span>}
					{date && <span>{date}</span>}
					{article.estimated_read_time && (
						<>
							<span>·</span>
							<span>{article.estimated_read_time} min</span>
						</>
					)}
				</div>

				<h3
					className={`text-pretty text-[18px] font-bold leading-[1.3] ${
						finished ? 'text-app-muted' : 'text-ink'
					}`}
				>
					{article.title}
				</h3>

				{article.excerpt && (
					<p className="mt-1 line-clamp-1 text-[13.5px] text-app-muted">{article.excerpt}</p>
				)}

				{article.tags && article.tags.length > 0 && (
					<div className="mt-2" onClick={(e) => e.stopPropagation()}>
						<TagList tags={article.tags} maxVisible={4} size="sm" />
					</div>
				)}
			</div>

			{/* Trailing actions */}
			<div className="flex flex-none items-center gap-3 text-app-muted">
				<button
					type="button"
					onClick={(e) => onEditTags(e, article)}
					title="Edit tags"
					className="opacity-45 transition-opacity hover:text-accent hover:opacity-100"
				>
					<svg className="h-[18px] w-[18px]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.75}>
						<path strokeLinecap="round" strokeLinejoin="round" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
					</svg>
				</button>
				<button
					type="button"
					onClick={(e) => onDelete(e, article)}
					title="Delete article"
					className="opacity-45 transition-opacity hover:text-accent hover:opacity-100"
				>
					<Trash2 size={18} strokeWidth={2.75} />
				</button>
				<button
					type="button"
					onClick={(e) => onToggleFavorite(e, article)}
					title={article.is_favorite ? 'Remove from favourites' : 'Add to favourites'}
					className={`transition-colors ${
						article.is_favorite ? 'text-accent' : 'opacity-45 hover:opacity-100'
					}`}
				>
					<Bookmark size={18} strokeWidth={2.75} fill={article.is_favorite ? 'currentColor' : 'none'} />
				</button>
			</div>
		</article>
	);
}
