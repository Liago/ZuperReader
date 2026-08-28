import { Bookmark, BookOpen, Trash2 } from 'lucide-react';
import { Article } from '../lib/supabase';
import OptimizedImage from './OptimizedImage';
import { TagList } from './TagBadge';
import StateMark, { StateMarkVariant } from './shell/StateMark';

interface ArticleCardProps {
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

function metaLabel(article: Article): string {
	if (article.reading_status === 'completed') return 'finished';
	if (article.reading_status === 'reading' && article.reading_progress > 0) {
		return `${article.reading_progress}% read`;
	}
	if (article.estimated_read_time) return `${article.estimated_read_time} min`;
	return '';
}

export default function ArticleCard({
	article,
	onClick,
	onToggleFavorite,
	onDelete,
	onEditTags,
}: ArticleCardProps) {
	const meta = metaLabel(article);
	const inProgress = article.reading_status === 'reading' && article.reading_progress > 0;

	return (
		<article
			onClick={() => onClick(article.id)}
			className="group flex cursor-pointer flex-col overflow-hidden rounded-[28px] border border-app-line bg-app-card transition-[transform,box-shadow] duration-180 ease-out hover:-translate-y-0.5 hover:[box-shadow:var(--shadow-card-hover)]"
		>
			{/* Cover */}
			<div className="relative aspect-16/10 overflow-hidden bg-app-surface">
				{article.image_url ? (
					<OptimizedImage
						src={article.image_url}
						alt={article.title}
						className="washed h-full w-full object-cover"
					/>
				) : (
					<div className="flex h-full w-full items-center justify-center">
						<BookOpen size={42} className="text-accent opacity-50" strokeWidth={1.75} />
					</div>
				)}

				{/* In-progress bar pinned to the cover's bottom edge */}
				{inProgress && (
					<div className="absolute inset-x-0 bottom-0 h-1 bg-app-line">
						<div
							className="h-full bg-accent"
							style={{ width: `${Math.min(100, Math.max(0, article.reading_progress))}%` }}
						/>
					</div>
				)}
			</div>

			{/* Body */}
			<div className="flex flex-1 flex-col px-5 pb-4 pt-[18px]">
				{/* Meta row */}
				<div className="mb-2 flex items-center gap-2 text-[12px] text-app-muted">
					<StateMark variant={markFor(article.reading_status)} />
					{article.domain && <span className="font-semibold text-ink">{article.domain}</span>}
					{article.domain && meta && <span>·</span>}
					{meta && <span>{meta}</span>}
				</div>

				{/* Title */}
				<h3 className="text-pretty text-[19px] font-bold leading-[1.3] text-ink">
					{article.title}
				</h3>

				{/* Excerpt */}
				{article.excerpt && (
					<p className="mt-1.5 line-clamp-2 text-[13.5px] leading-[1.6] text-app-muted">
						{article.excerpt}
					</p>
				)}

				{/* Bottom row */}
				<div className="mt-auto flex items-center justify-between gap-3 pt-4">
					<div className="min-w-0 flex-1" onClick={(e) => e.stopPropagation()}>
						{article.tags && article.tags.length > 0 ? (
							<TagList tags={article.tags} maxVisible={2} size="sm" />
						) : (
							<button
								type="button"
								onClick={(e) => onEditTags(e, article)}
								className="text-[12px] text-app-muted transition-colors hover:text-accent"
							>
								+ Tag
							</button>
						)}
					</div>

					<div className="flex shrink-0 items-center gap-2.5">
						<button
							type="button"
							onClick={(e) => onDelete(e, article)}
							title="Delete article"
							className="text-app-muted opacity-45 transition-opacity hover:text-accent hover:opacity-100"
						>
							<Trash2 size={17} strokeWidth={2.75} />
						</button>
						<button
							type="button"
							onClick={(e) => onToggleFavorite(e, article)}
							title={article.is_favorite ? 'Remove from favourites' : 'Add to favourites'}
							className={`transition-colors ${
								article.is_favorite ? 'text-accent' : 'text-ink opacity-45 hover:opacity-100'
							}`}
						>
							<Bookmark
								size={18}
								strokeWidth={2.75}
								fill={article.is_favorite ? 'currentColor' : 'none'}
							/>
						</button>
					</div>
				</div>
			</div>
		</article>
	);
}
