import { Article } from '../lib/supabase';
import OptimizedImage from './OptimizedImage';
import { TagList } from './TagBadge';

interface ArticleRowProps {
	article: Article;
	onClick: (articleId: string) => void;
	onToggleFavorite: (e: React.MouseEvent, article: Article) => void;
	onDelete: (e: React.MouseEvent, article: Article) => void;
	onEditTags: (e: React.MouseEvent, article: Article) => void;
	index?: number;
}

export default function ArticleRow({
	article,
	onClick,
	onToggleFavorite,
	onDelete,
	onEditTags,
	index = 0
}: ArticleRowProps) {
	// Prevenire propagazione click link
	const handleExternalLinkClick = (e: React.MouseEvent) => {
		e.stopPropagation();
	};

	return (
		<article
			onClick={() => onClick(article.id)}
			className="group relative flex items-stretch bg-white dark:bg-slate-800 rounded-2xl overflow-hidden shadow-sm hover:shadow-lg transition-all duration-300 ease-out border border-gray-100 dark:border-slate-700 hover:border-purple-200 dark:hover:border-purple-700 cursor-pointer p-4 gap-5"
			style={{
				animation: `fadeInUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) ${index * 0.05}s both`,
			}}
		>
			{/* Image Section */}
			<div className="relative w-32 sm:w-48 flex-shrink-0 rounded-xl overflow-hidden shadow-inner">
				{article.image_url ? (
					<>
						<div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 z-10" />
						<OptimizedImage
							src={article.image_url}
							alt={article.title}
							className="w-full h-full object-cover transform group-hover:scale-105 transition-transform duration-500"
							priority={index < 3}
						/>
					</>
				) : (
					<div className="w-full h-full bg-gradient-to-br from-purple-50 to-indigo-50 dark:from-slate-800 dark:to-slate-700 flex items-center justify-center">
						<svg className="w-8 h-8 text-purple-200 dark:text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
						</svg>
					</div>
				)}

				{/* Status Icon Overlay */}
				<div className="absolute top-2 left-2 z-20">
					{article.reading_status === 'unread' && (
						<div className="w-2.5 h-2.5 bg-blue-500 rounded-full shadow-md shadow-blue-500/50" title="Unread" />
					)}
					{article.reading_status === 'reading' && (
						<div className="w-2.5 h-2.5 bg-amber-500 rounded-full shadow-md shadow-amber-500/50 animate-pulse" title="Reading" />
					)}
					{article.reading_status === 'completed' && (
						<div className="flex items-center justify-center w-4 h-4 bg-emerald-500 rounded-full shadow-md shadow-emerald-500/50" title="Completed">
							<svg className="w-2.5 h-2.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
							</svg>
						</div>
					)}
				</div>
			</div>

			{/* Content Section */}
			<div className="flex-1 min-w-0 flex flex-col py-1">
				<div className="flex items-start justify-between gap-4 mb-2">
					<div className="flex items-center gap-2 text-xs font-medium text-indigo-600 dark:text-indigo-400">
						{article.domain && (
							<span className="bg-indigo-50 dark:bg-indigo-900/20 px-2 py-0.5 rounded-md">
								{article.domain}
							</span>
						)}
						<span className="text-gray-300 dark:text-gray-600">•</span>
						<span className="text-gray-500 dark:text-gray-400">
							{new Date(article.created_at || '').toLocaleDateString('it-IT', { day: 'numeric', month: 'short' })}
						</span>
					</div>

					{/* Actions (Visible on Hover or Touch) */}
					<div className="flex items-center gap-1 opacity-100 sm:opacity-0 group-hover:opacity-100 transition-opacity duration-200">
						<button
							onClick={(e) => onToggleFavorite(e, article)}
							className={`p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-slate-700 transition-colors ${article.is_favorite ? 'text-red-500' : 'text-gray-400 dark:text-gray-500 hover:text-red-500'
								}`}
							title="Toggle favorite"
						>
							<svg className={`w-4 h-4 ${article.is_favorite ? 'fill-current' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
							</svg>
						</button>
						<button
							onClick={(e) => onDelete(e, article)}
							className="p-1.5 rounded-full text-gray-400 dark:text-gray-500 hover:text-red-500 hover:bg-gray-100 dark:hover:bg-slate-700 transition-colors"
							title="Delete"
						>
							<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
							</svg>
						</button>
					</div>
				</div>

				<h3 className="text-lg font-bold text-gray-800 dark:text-gray-100 leading-snug mb-1 group-hover:text-purple-600 dark:group-hover:text-purple-400 transition-colors duration-200">
					{article.title}
				</h3>

				<p className="text-sm text-gray-500 dark:text-gray-400 line-clamp-2 mb-4 hidden sm:block">
					{article.excerpt}
				</p>

				<div className="mt-auto flex items-center justify-between">
					<div className="flex items-center gap-3">
						{article.tags && article.tags.length > 0 ? (
							<div onClick={(e) => e.stopPropagation()}>
								<TagList tags={article.tags} maxVisible={3} size="sm" />
							</div>
						) : (
							<button
								onClick={(e) => onEditTags(e, article)}
								className="text-xs text-gray-400 hover:text-purple-600 dark:hover:text-purple-400 flex items-center gap-1 transition-colors"
							>
								<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
								</svg>
								Add tags
							</button>
						)}
					</div>

					<div className="flex items-center gap-3 text-gray-400 dark:text-gray-500 text-xs">
						{article.estimated_read_time && (
							<span className="flex items-center gap-1">
								<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
								{article.estimated_read_time} min
							</span>
						)}
						<a
							href={article.url}
							target="_blank"
							rel="noopener noreferrer"
							onClick={handleExternalLinkClick}
							className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors"
						>
							<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
							</svg>
						</a>
					</div>
				</div>
			</div>
		</article>
	);
}
