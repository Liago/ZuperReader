'use client';

import { useState, useEffect, useCallback } from 'react';
import { ArticleFilters, ArticleSortOptions, ArticleSortField, ArticleSortOrder } from '../lib/api';

interface SearchAndFiltersProps {
	onFiltersChange: (filters: ArticleFilters, sort: ArticleSortOptions) => void;
	availableTags: string[];
	availableDomains: string[];
}

export default function SearchAndFilters({
	onFiltersChange,
	availableTags,
	availableDomains
}: SearchAndFiltersProps) {
	const [searchQuery, setSearchQuery] = useState('');
	const [selectedTags, setSelectedTags] = useState<string[]>([]);
	const [readingStatus, setReadingStatus] = useState<'all' | 'unread' | 'reading' | 'completed'>('all');
	const [isFavorite, setIsFavorite] = useState<boolean | undefined>(undefined);
	const [selectedDomain, setSelectedDomain] = useState('');
	const [sortField, setSortField] = useState<ArticleSortField>('created_at');
	const [sortOrder, setSortOrder] = useState<ArticleSortOrder>('desc');
	const [showFilters, setShowFilters] = useState(false);

	// Applica i filtri
	const applyFilters = useCallback(() => {
		const filters: ArticleFilters = {
			searchQuery: searchQuery || undefined,
			tags: selectedTags.length > 0 ? selectedTags : undefined,
			readingStatus,
			isFavorite,
			domain: selectedDomain || undefined,
		};

		const sort: ArticleSortOptions = {
			field: sortField,
			order: sortOrder,
		};

		onFiltersChange(filters, sort);
	}, [searchQuery, selectedTags, readingStatus, isFavorite, selectedDomain, sortField, sortOrder, onFiltersChange]);

	// Debounce search query e filtri
	useEffect(() => {
		const timer = setTimeout(() => {
			applyFilters();
		}, 300);

		return () => clearTimeout(timer);
	}, [applyFilters]);

	const toggleTag = (tag: string) => {
		if (selectedTags.includes(tag)) {
			setSelectedTags(selectedTags.filter(t => t !== tag));
		} else {
			setSelectedTags([...selectedTags, tag]);
		}
	};

	const clearFilters = () => {
		setSearchQuery('');
		setSelectedTags([]);
		setReadingStatus('all');
		setIsFavorite(undefined);
		setSelectedDomain('');
		setSortField('created_at');
		setSortOrder('desc');
	};

	const hasActiveFilters = searchQuery || selectedTags.length > 0 || readingStatus !== 'all' ||
		isFavorite !== undefined || selectedDomain || sortField !== 'created_at' || sortOrder !== 'desc';

	return (
		<div className="bg-white/60 backdrop-blur-sm rounded-2xl shadow-sm border border-gray-100 overflow-hidden mb-6">
			{/* Search Bar */}
			<div className="p-4">
				<div className="relative">
					<div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
						<svg className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
					</div>
					<input
						type="text"
						value={searchQuery}
						onChange={(e) => setSearchQuery(e.target.value)}
						placeholder="Cerca negli articoli..."
						className="block w-full pl-10 pr-12 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900 placeholder-gray-400"
					/>
					{searchQuery && (
						<button
							onClick={() => setSearchQuery('')}
							className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
						>
							<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					)}
				</div>

				{/* Filters Toggle Button */}
				<div className="flex items-center justify-between mt-3">
					<button
						onClick={() => setShowFilters(!showFilters)}
						className="flex items-center gap-2 text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors"
					>
						<svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
						</svg>
						Filtri e Ordinamento
						{hasActiveFilters && (
							<span className="inline-flex items-center justify-center w-5 h-5 text-xs font-bold text-white bg-blue-600 rounded-full">
								!
							</span>
						)}
					</button>

					{hasActiveFilters && (
						<button
							onClick={clearFilters}
							className="text-sm text-blue-600 hover:text-blue-800 font-medium"
						>
							Cancella tutto
						</button>
					)}
				</div>
			</div>

			{/* Filters Panel */}
			{showFilters && (
				<div className="border-t border-gray-100 p-4 space-y-4 bg-gray-50/50">
					{/* Sort Options */}
					<div>
						<label className="block text-sm font-medium text-gray-700 mb-2">Ordinamento</label>
						<div className="grid grid-cols-2 gap-3">
							<select
								value={sortField}
								onChange={(e) => setSortField(e.target.value as ArticleSortField)}
								className="block w-full px-3 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
							>
								<option value="created_at">Data creazione</option>
								<option value="published_date">Data pubblicazione</option>
								<option value="like_count">Più apprezzati</option>
								<option value="title">Titolo</option>
							</select>
							<select
								value={sortOrder}
								onChange={(e) => setSortOrder(e.target.value as ArticleSortOrder)}
								className="block w-full px-3 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
							>
								<option value="desc">Decrescente</option>
								<option value="asc">Crescente</option>
							</select>
						</div>
					</div>

					{/* Reading Status Filter */}
					<div>
						<label className="block text-sm font-medium text-gray-700 mb-2">Stato lettura</label>
						<div className="flex flex-wrap gap-2">
							{(['all', 'unread', 'reading', 'completed'] as const).map((status) => (
								<button
									key={status}
									onClick={() => setReadingStatus(status)}
									className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
										readingStatus === status
											? 'bg-blue-600 text-white'
											: 'bg-white text-gray-700 hover:bg-gray-100 border border-gray-200'
									}`}
								>
									{status === 'all' && 'Tutti'}
									{status === 'unread' && 'Da leggere'}
									{status === 'reading' && 'In lettura'}
									{status === 'completed' && 'Completati'}
								</button>
							))}
						</div>
					</div>

					{/* Favorite Filter */}
					<div>
						<label className="block text-sm font-medium text-gray-700 mb-2">Preferiti</label>
						<div className="flex gap-2">
							<button
								onClick={() => setIsFavorite(undefined)}
								className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
									isFavorite === undefined
										? 'bg-blue-600 text-white'
										: 'bg-white text-gray-700 hover:bg-gray-100 border border-gray-200'
								}`}
							>
								Tutti
							</button>
							<button
								onClick={() => setIsFavorite(true)}
								className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
									isFavorite === true
										? 'bg-blue-600 text-white'
										: 'bg-white text-gray-700 hover:bg-gray-100 border border-gray-200'
								}`}
							>
								Solo preferiti
							</button>
							<button
								onClick={() => setIsFavorite(false)}
								className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
									isFavorite === false
										? 'bg-blue-600 text-white'
										: 'bg-white text-gray-700 hover:bg-gray-100 border border-gray-200'
								}`}
							>
								Non preferiti
							</button>
						</div>
					</div>

					{/* Tags Filter */}
					{availableTags.length > 0 && (
						<div>
							<label className="block text-sm font-medium text-gray-700 mb-2">Tag</label>
							<div className="flex flex-wrap gap-2">
								{availableTags.map((tag) => (
									<button
										key={tag}
										onClick={() => toggleTag(tag)}
										className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
											selectedTags.includes(tag)
												? 'bg-purple-600 text-white'
												: 'bg-white text-gray-700 hover:bg-gray-100 border border-gray-200'
										}`}
									>
										{tag}
									</button>
								))}
							</div>
						</div>
					)}

					{/* Domain Filter */}
					{availableDomains.length > 0 && (
						<div>
							<label className="block text-sm font-medium text-gray-700 mb-2">Dominio</label>
							<select
								value={selectedDomain}
								onChange={(e) => setSelectedDomain(e.target.value)}
								className="block w-full px-3 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
							>
								<option value="">Tutti i domini</option>
								{availableDomains.map((domain) => (
									<option key={domain} value={domain}>
										{domain}
									</option>
								))}
							</select>
						</div>
					)}
				</div>
			)}
		</div>
	);
}
