import { Article } from '../lib/supabase';
import OptimizedImage from './OptimizedImage';
import { TagList } from './TagBadge';

interface ArticleCardProps {
	article: Article;
	onClick: (articleId: string) => void;
	onToggleFavorite: (e: React.MouseEvent, article: Article) => void;
	onDelete: (e: React.MouseEvent, article: Article) => void;
	onEditTags: (e: React.MouseEvent, article: Article) => void;
	index?: number;
}

export default function ArticleCard({
	article,
	onClick,
	onToggleFavorite,
	onDelete,
	onEditTags,
	index = 0
}: ArticleCardProps) {
	// Prevenire propagazione click link
	const handleExternalLinkClick = (e: React.MouseEvent) => {
		e.stopPropagation();
	};

	return (
		<article
			onClick={() => onClick(article.id)}
			className="group relative flex flex-col h-full bg-white dark:bg-slate-800 rounded-3xl overflow-hidden shadow-sm hover:shadow-2xl transition-all duration-500 ease-out hover:-translate-y-2 cursor-pointer border border-gray-100 dark:border-slate-700 hover:border-transparent dark:hover:border-transparent ring-0 hover:ring-2 hover:ring-purple-500/20 dark:hover:ring-purple-400/20"
			style={{
				animation: `fadeInUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) ${index * 0.05}s both`,
			}}
		>
			{/* Image Section with Dynamic Gradient Overlay */}
			<div className="relative aspect-[16/10] overflow-hidden">
				{article.image_url ? (
					<>
						<div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-60 group-hover:opacity-40 transition-opacity duration-500 z-10" />
						<OptimizedImage
							src={article.image_url}
							alt={article.title}
							className="w-full h-full object-cover transform group-hover:scale-110 transition-transform duration-700 ease-in-out"
							priority={index < 3}
						/>
					</>
				) : (
					<div className="w-full h-full bg-gradient-to-br from-purple-50 to-indigo-50 dark:from-slate-800 dark:to-slate-700 flex items-center justify-center p-8">
						<div className="w-16 h-16 rounded-2xl bg-white/50 dark:bg-slate-600/50 flex items-center justify-center backdrop-blur-sm shadow-inner text-purple-600 dark:text-purple-400">
							<svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
							</svg>
						</div>
					</div>
				)}

				{/* Floating Status Badge */}
				<div className="absolute top-4 left-4 z-20 flex flex-col gap-2">
					{article.reading_status === 'unread' && (
						<span className="inline-flex items-center gap-1.5 px-3 py-1 bg-blue-500/90 backdrop-blur-md text-white text-[11px] font-bold uppercase tracking-wider rounded-full shadow-lg shadow-blue-500/20 transform transition-transform group-hover:scale-105">
							<span className="w-1.5 h-1.5 rounded-full bg-white animate-pulse" />
							Unread
						</span>
					)}
					{article.reading_status === 'reading' && (
						<span className="inline-flex items-center gap-1.5 px-3 py-1 bg-amber-500/90 backdrop-blur-md text-white text-[11px] font-bold uppercase tracking-wider rounded-full shadow-lg shadow-amber-500/20 transform transition-transform group-hover:scale-105">
							<svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							Reading
						</span>
					)}
					{article.reading_status === 'completed' && (
						<span className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-500/90 backdrop-blur-md text-white text-[11px] font-bold uppercase tracking-wider rounded-full shadow-lg shadow-emerald-500/20 transform transition-transform group-hover:scale-105">
							<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
							</svg>
							Done
						</span>
					)}
				</div>

				{/* Action Buttons (Reveal on Hover) */}
				<div className="absolute top-4 right-4 z-20 flex gap-2 translate-x-4 opacity-0 group-hover:translate-x-0 group-hover:opacity-100 transition-all duration-300">
					<button
						onClick={(e) => onToggleFavorite(e, article)}
						className={`p-2.5 rounded-full backdrop-blur-md shadow-lg transition-all duration-200 hover:scale-110 active:scale-95 ${article.is_favorite
							? 'bg-red-500 text-white shadow-red-500/30'
							: 'bg-white/90 dark:bg-slate-800/90 text-gray-500 dark:text-gray-300 hover:text-red-500 dark:hover:text-red-400'
							}`}
						title={article.is_favorite ? "Remove from favorites" : "Add to favorites"}
					>
						<svg className={`w-4 h-4 ${article.is_favorite ? 'fill-current' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
						</svg>
					</button>
					<button
						onClick={(e) => onDelete(e, article)}
						className="p-2.5 bg-white/90 dark:bg-slate-800/90 hover:bg-red-500 text-gray-500 dark:text-gray-300 hover:text-white rounded-full backdrop-blur-md shadow-lg transition-all duration-200 hover:scale-110 active:scale-95 hover:shadow-red-500/30"
						title="Delete article"
					>
						<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
						</svg>
					</button>
				</div>
			</div>

			{/* Content Section */}
			<div className="flex-1 p-5 flex flex-col relative">
				{/* Domain & Read Time */}
				<div className="flex items-center justify-between mb-3 text-xs font-medium">
					<div className="flex items-center gap-2">
						{article.domain && (
							<span className="flex items-center gap-1.5 text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/20 px-2 py-1 rounded-md">
								<div className="w-1.5 h-1.5 rounded-full bg-indigo-500 dark:bg-indigo-400" />
								{article.domain}
							</span>
						)}
					</div>
					{article.estimated_read_time && (
						<span className="text-gray-500 dark:text-gray-400 flex items-center gap-1">
							<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							{article.estimated_read_time} min
						</span>
					)}
				</div>

				{/* Title */}
				<h3 className="text-lg font-bold text-gray-800 dark:text-gray-100 leading-snug mb-2 line-clamp-2 group-hover:text-purple-600 dark:group-hover:text-purple-400 transition-colors duration-200">
					{article.title}
				</h3>

				{/* Excerpt */}
				<p className="text-sm text-gray-600 dark:text-gray-400 line-clamp-2 mb-4 leading-relaxed h-[2.5rem] overflow-hidden">
					{article.excerpt}
				</p>

				<div className="mt-auto pt-4 border-t border-gray-100 dark:border-slate-700/50 flex items-center justify-between">
					{/* Tags (Scrollable if many) */}
					<div className="flex-1 min-w-0 mr-3">
						<div className="flex items-center gap-1">
							{article.tags && article.tags.length > 0 ? (
								<div onClick={(e) => e.stopPropagation()} className="flex">
									<TagList tags={article.tags} maxVisible={2} size="sm" />
								</div>
							) : (
								<button
									onClick={(e) => onEditTags(e, article)}
									className="text-xs text-gray-400 hover:text-purple-600 dark:hover:text-purple-400 flex items-center gap-1 transition-colors"
								>
									<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
									</svg>
									Tag
								</button>
							)}
						</div>
					</div>

					{/* View Original Link */}
					<a
						href={article.url}
						target="_blank"
						rel="noopener noreferrer"
						onClick={handleExternalLinkClick}
						className="flex-shrink-0 inline-flex items-center justify-center w-8 h-8 rounded-full bg-gray-50 dark:bg-slate-700 text-gray-400 dark:text-gray-300 hover:bg-purple-100 dark:hover:bg-purple-900/30 hover:text-purple-600 dark:hover:text-purple-400 transition-all duration-200"
						title="Open original link"
					>
						<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
						</svg>
					</a>
				</div>
			</div>
		</article>
	);
}
