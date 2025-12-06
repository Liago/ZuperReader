'use client';

import { useState, useEffect, useCallback } from 'react';
import { Article } from '../lib/supabase';
import { suggestTagsForArticle, getAllPredefinedTags, searchTags, getTagColor } from '../lib/tagSuggestionService';
import TagBadge from './TagBadge';

interface TagManagementModalProps {
	isOpen: boolean;
	onClose: () => void;
	article: Article;
	onSave: (tags: string[]) => Promise<void>;
}

export default function TagManagementModal({
	isOpen,
	onClose,
	article,
	onSave,
}: TagManagementModalProps) {
	const [selectedTags, setSelectedTags] = useState<string[]>([]);
	const [suggestedTags, setSuggestedTags] = useState<string[]>([]);
	const [searchQuery, setSearchQuery] = useState('');
	const [searchResults, setSearchResults] = useState<string[]>([]);
	const [customTag, setCustomTag] = useState('');
	const [isSaving, setIsSaving] = useState(false);
	const [showAllPredefined, setShowAllPredefined] = useState(false);
	const [isAnalyzing, setIsAnalyzing] = useState(false);

	// Initialize with existing tags and generate suggestions
	useEffect(() => {
		if (isOpen && article) {
			setSelectedTags(article.tags || []);
			setIsAnalyzing(true);

			// Simulate async analysis (in real scenario could be more complex)
			setTimeout(() => {
				const suggestions = suggestTagsForArticle(article);
				// Filter out already selected tags
				setSuggestedTags(suggestions.filter(tag => !(article.tags || []).includes(tag)));
				setIsAnalyzing(false);
			}, 500);
		}
	}, [isOpen, article]);

	// Handle search
	useEffect(() => {
		if (searchQuery.length >= 2) {
			const results = searchTags(searchQuery).filter(tag => !selectedTags.includes(tag));
			setSearchResults(results);
		} else {
			setSearchResults([]);
		}
	}, [searchQuery, selectedTags]);

	const handleAddTag = useCallback((tag: string) => {
		const normalizedTag = tag.toLowerCase().trim();
		if (normalizedTag && !selectedTags.includes(normalizedTag)) {
			setSelectedTags(prev => [...prev, normalizedTag]);
			// Remove from suggested if present
			setSuggestedTags(prev => prev.filter(t => t !== normalizedTag));
		}
		setSearchQuery('');
		setCustomTag('');
	}, [selectedTags]);

	const handleRemoveTag = useCallback((tag: string) => {
		setSelectedTags(prev => prev.filter(t => t !== tag));
		// Add back to suggestions if it was originally suggested
		const originalSuggestions = suggestTagsForArticle(article);
		if (originalSuggestions.includes(tag)) {
			setSuggestedTags(prev => [...prev, tag]);
		}
	}, [article]);

	const handleAddCustomTag = () => {
		const normalizedTag = customTag.toLowerCase().trim().replace(/[^a-z0-9-]/g, '-');
		if (normalizedTag && normalizedTag.length >= 2) {
			handleAddTag(normalizedTag);
		}
	};

	const handleSave = async () => {
		setIsSaving(true);
		try {
			await onSave(selectedTags);
			onClose();
		} catch (error) {
			console.error('Failed to save tags:', error);
		} finally {
			setIsSaving(false);
		}
	};

	const handleKeyPress = (e: React.KeyboardEvent<HTMLInputElement>) => {
		if (e.key === 'Enter') {
			e.preventDefault();
			if (searchQuery.length >= 2) {
				handleAddTag(searchQuery);
			} else if (customTag.length >= 2) {
				handleAddCustomTag();
			}
		}
	};

	if (!isOpen) return null;

	const allPredefinedTags = getAllPredefinedTags().filter(tag => !selectedTags.includes(tag));
	const displayedPredefinedTags = showAllPredefined ? allPredefinedTags : allPredefinedTags.slice(0, 12);

	return (
		<>
			{/* Backdrop */}
			<div
				className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
				onClick={onClose}
			/>

			{/* Modal */}
			<div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
				<div
					className="bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden pointer-events-auto"
					onClick={(e) => e.stopPropagation()}
				>
					{/* Header */}
					<div className="bg-gradient-to-r from-purple-600 to-pink-600 text-white p-6">
						<div className="flex justify-between items-start">
							<div>
								<h2 className="text-xl font-bold mb-1">Manage Tags</h2>
								<p className="text-white/80 text-sm line-clamp-1">{article.title}</p>
							</div>
							<button
								onClick={onClose}
								className="p-2 hover:bg-white/20 rounded-lg transition-colors"
								aria-label="Close modal"
							>
								<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
								</svg>
							</button>
						</div>
					</div>

					{/* Content */}
					<div className="p-6 overflow-y-auto max-h-[calc(90vh-180px)]">
						{/* Current Tags */}
						<div className="mb-6">
							<h3 className="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2">
								<svg className="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
								</svg>
								Current Tags ({selectedTags.length})
							</h3>
							{selectedTags.length > 0 ? (
								<div className="flex flex-wrap gap-2">
									{selectedTags.map(tag => (
										<TagBadge
											key={tag}
											tag={tag}
											size="md"
											removable
											onRemove={() => handleRemoveTag(tag)}
										/>
									))}
								</div>
							) : (
								<p className="text-gray-500 text-sm italic">No tags added yet</p>
							)}
						</div>

						{/* AI Suggested Tags */}
						<div className="mb-6">
							<h3 className="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2">
								<svg className="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
								</svg>
								AI Suggested Tags
								{isAnalyzing && (
									<span className="text-xs text-purple-500 font-normal ml-2 flex items-center gap-1">
										<svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
											<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
											<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
										</svg>
										Analyzing article...
									</span>
								)}
							</h3>
							{isAnalyzing ? (
								<div className="flex gap-2">
									{[1, 2, 3, 4].map(i => (
										<div
											key={i}
											className="h-7 w-20 bg-gray-200 rounded-full animate-pulse"
										/>
									))}
								</div>
							) : suggestedTags.length > 0 ? (
								<div className="flex flex-wrap gap-2">
									{suggestedTags.map(tag => (
										<button
											key={tag}
											onClick={() => handleAddTag(tag)}
											className="group relative"
										>
											<TagBadge tag={tag} size="md" />
											<span className="absolute -top-1 -right-1 w-4 h-4 bg-green-500 text-white rounded-full flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity">
												+
											</span>
										</button>
									))}
								</div>
							) : (
								<p className="text-gray-500 text-sm italic">All suggested tags have been added</p>
							)}
						</div>

						{/* Search & Add Tags */}
						<div className="mb-6">
							<h3 className="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2">
								<svg className="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
								</svg>
								Search or Add Tag
							</h3>
							<div className="flex gap-2">
								<div className="relative flex-1">
									<input
										type="text"
										value={searchQuery || customTag}
										onChange={(e) => {
											const value = e.target.value;
											setSearchQuery(value);
											setCustomTag(value);
										}}
										onKeyPress={handleKeyPress}
										placeholder="Search existing or type new tag..."
										className="w-full px-4 py-2.5 border border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent outline-none transition-all"
									/>
									{searchResults.length > 0 && (
										<div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl shadow-lg border border-gray-100 z-10 max-h-48 overflow-y-auto">
											{searchResults.map(tag => (
												<button
													key={tag}
													onClick={() => handleAddTag(tag)}
													className="w-full px-4 py-2 text-left hover:bg-purple-50 flex items-center gap-2 transition-colors"
												>
													<TagBadge tag={tag} size="sm" />
												</button>
											))}
										</div>
									)}
								</div>
								<button
									onClick={handleAddCustomTag}
									disabled={customTag.length < 2}
									className="px-4 py-2.5 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 disabled:hover:shadow-none"
								>
									Add
								</button>
							</div>
						</div>

						{/* Predefined Tags */}
						<div>
							<h3 className="text-sm font-semibold text-gray-700 mb-3 flex items-center justify-between">
								<span className="flex items-center gap-2">
									<svg className="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
									</svg>
									Available Tags
								</span>
								<button
									onClick={() => setShowAllPredefined(!showAllPredefined)}
									className="text-purple-600 hover:text-pink-600 text-xs font-medium transition-colors"
								>
									{showAllPredefined ? 'Show Less' : `Show All (${allPredefinedTags.length})`}
								</button>
							</h3>
							<div className="flex flex-wrap gap-2">
								{displayedPredefinedTags.map(tag => (
									<button
										key={tag}
										onClick={() => handleAddTag(tag)}
										className="group relative"
									>
										<TagBadge tag={tag} size="sm" />
										<span className="absolute -top-1 -right-1 w-3 h-3 bg-green-500 text-white rounded-full flex items-center justify-center text-[10px] opacity-0 group-hover:opacity-100 transition-opacity">
											+
										</span>
									</button>
								))}
							</div>
						</div>
					</div>

					{/* Footer */}
					<div className="border-t border-gray-200 p-4 flex justify-between items-center bg-gray-50/50">
						<p className="text-sm text-gray-500">
							{selectedTags.length} tag{selectedTags.length !== 1 ? 's' : ''} selected
						</p>
						<div className="flex gap-3">
							<button
								onClick={onClose}
								disabled={isSaving}
								className="px-4 py-2 bg-gray-100 text-gray-700 font-medium rounded-xl hover:bg-gray-200 transition-colors disabled:opacity-50"
							>
								Cancel
							</button>
							<button
								onClick={handleSave}
								disabled={isSaving}
								className="px-6 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-medium rounded-xl hover:shadow-lg hover:scale-105 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 flex items-center gap-2"
							>
								{isSaving ? (
									<>
										<svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
											<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
											<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
										</svg>
										Saving...
									</>
								) : (
									<>
										<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
										</svg>
										Save Tags
									</>
								)}
							</button>
						</div>
					</div>
				</div>
			</div>
		</>
	);
}
