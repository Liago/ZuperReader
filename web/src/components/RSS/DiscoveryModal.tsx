'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { discoverFeeds, addFeed, createFolder, type DiscoveredFeed } from '@/app/actions/rss';
import CustomSelect from './CustomSelect';

interface DiscoveryModalProps {
	isOpen: boolean;
	onClose: () => void;
	folders: Array<{ id: string; name: string }>;
}

export default function DiscoveryModal({ isOpen, onClose, folders: initialFolders }: DiscoveryModalProps) {
	const router = useRouter();
	const [searchUrl, setSearchUrl] = useState('');
	const [isSearching, setIsSearching] = useState(false);
	const [discoveredFeeds, setDiscoveredFeeds] = useState<DiscoveredFeed[]>([]);
	const [errorMessage, setErrorMessage] = useState<string | null>(null);
	const [selectedFolders, setSelectedFolders] = useState<{ [feedUrl: string]: string | null }>({});
	const [addingFeed, setAddingFeed] = useState<{ [feedUrl: string]: boolean }>({});
	const [addedFeeds, setAddedFeeds] = useState<Set<string>>(new Set());
	const [folders, setFolders] = useState(initialFolders);
	const [creatingFolderForFeed, setCreatingFolderForFeed] = useState<string | null>(null);
	const [newFolderName, setNewFolderName] = useState('');

	if (!isOpen) return null;

	const handleSearch = async (e: React.FormEvent) => {
		e.preventDefault();
		if (!searchUrl.trim()) {
			setErrorMessage('Please enter a site name, domain, or URL.');
			return;
		}

		setIsSearching(true);
		setErrorMessage(null);
		setDiscoveredFeeds([]);
		setAddedFeeds(new Set());

		// Small delay to allow UI to update if needed
		await new Promise(r => setTimeout(r, 100));

		const result = await discoverFeeds(searchUrl);

		setIsSearching(false);

		if (result.error) {
			setErrorMessage(result.error);
		} else if (result.feeds) {
			setDiscoveredFeeds(result.feeds);
			// Initialize selected folders to null (uncategorized)
			const initialFolders: { [feedUrl: string]: string | null } = {};
			result.feeds.forEach(feed => {
				initialFolders[feed.url] = null;
			});
			setSelectedFolders(initialFolders);
		}
	};

	const handleAddFeed = async (feed: DiscoveredFeed) => {
		setAddingFeed({ ...addingFeed, [feed.url]: true });
		setErrorMessage(null);

		const folderId = selectedFolders[feed.url] || null;
		const result = await addFeed(feed.url, folderId);

		setAddingFeed({ ...addingFeed, [feed.url]: false });

		if (result.error) {
			setErrorMessage(result.error);
		} else {
			// Mark feed as added
			setAddedFeeds(new Set([...addedFeeds, feed.url]));
			router.refresh(); // Refresh to show the new feed in sidebar
		}
	};

	const handleFolderChange = (feedUrl: string, folderId: string) => {
		if (folderId === '__create_new__') {
			setCreatingFolderForFeed(feedUrl);
			setNewFolderName('');
			return;
		}
		setSelectedFolders({
			...selectedFolders,
			[feedUrl]: folderId === '' ? null : folderId,
		});
	};

	const handleCreateNewFolder = async (feedUrl: string) => {
		if (!newFolderName.trim()) {
			setErrorMessage('Folder name cannot be empty');
			return;
		}

		const result = await createFolder(newFolderName.trim());

		if (result.error) {
			setErrorMessage(result.error);
			return;
		}

		if (result.data) {
			// Add folder to local state
			setFolders([...folders, { id: result.data.id, name: result.data.name }]);
			// Set this folder as selected for the feed
			setSelectedFolders({
				...selectedFolders,
				[feedUrl]: result.data.id,
			});
			// Reset creation state
			setCreatingFolderForFeed(null);
			setNewFolderName('');
			router.refresh(); // Refresh to update sidebar
		}
	};

	const handleCancelCreateFolder = () => {
		setCreatingFolderForFeed(null);
		setNewFolderName('');
	};

	const handleClose = () => {
		setSearchUrl('');
		setDiscoveredFeeds([]);
		setErrorMessage(null);
		setSelectedFolders({});
		setAddingFeed({});
		setAddedFeeds(new Set());
		onClose();
	};

	return (
		<div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
			<div
				className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full transform transition-all"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header */}
				<div className="flex items-center justify-between p-5 border-b border-gray-100">
					<div className="flex items-center gap-3">
						<div className="w-10 h-10 bg-gradient-to-br from-orange-500 to-pink-500 rounded-xl flex items-center justify-center">
							<svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
							</svg>
						</div>
						<div>
							<h2 className="text-xl font-bold text-gray-900">Discover RSS Feeds</h2>
							<p className="text-sm text-gray-500">Find feeds by site name or domain</p>
						</div>
					</div>
					<button
						onClick={handleClose}
						className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
					>
						<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				{/* Content */}
				<form onSubmit={handleSearch} className="p-5">
					<div className="relative">
						<label htmlFor="search-url" className="text-sm font-medium text-gray-700 mb-2 block">
							Site Name, Domain, or URL
						</label>
						<div className="relative">
							<div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
								<svg className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
								</svg>
							</div>
							<input
								id="search-url"
								type="text"
								value={searchUrl}
								onChange={(e) => setSearchUrl(e.target.value)}
								placeholder="e.g., TechCrunch, theverge.com"
								className="w-full pl-10 pr-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-200 text-gray-900 placeholder-gray-400 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
								disabled={isSearching}
							/>
						</div>
					</div>

					{errorMessage && (
						<div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3">
							<svg className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							<div className="flex-1">
								<p className="text-sm font-medium text-red-800">{errorMessage}</p>
							</div>
						</div>
					)}

					{discoveredFeeds.length > 0 && (
						<div className="mt-4 max-h-96 overflow-y-auto border-2 border-gray-200 rounded-xl">
							<div className="divide-y divide-gray-100">
								{discoveredFeeds.map((feed) => {
									const isAdded = addedFeeds.has(feed.url);
									const isAdding = addingFeed[feed.url];

									return (
										<div key={feed.url} className="p-4 hover:bg-gradient-to-r hover:from-orange-50/50 hover:to-pink-50/50 transition-all">
											<div className="flex items-start justify-between gap-4">
												<div className="flex-1 min-w-0">
													<h4 className="text-sm font-semibold text-gray-900 truncate">
														{feed.title}
													</h4>
													<a href={feed.siteUrl || feed.url} target="_blank" rel="noopener noreferrer" className="text-xs text-gray-500 truncate mt-1 hover:underline">
														{feed.url}
													</a>
													<div className="mt-2">
														<span className="inline-flex items-center px-2 py-1 rounded-lg text-xs font-medium bg-gradient-to-r from-orange-100 to-pink-100 text-orange-800">
															{feed.type.toUpperCase()}
														</span>
													</div>
												</div>

												<div className="flex flex-col gap-2 items-end">
													{creatingFolderForFeed === feed.url ? (
														<div className="flex items-center gap-2 w-full">
															<input
																type="text"
																value={newFolderName}
																onChange={(e) => setNewFolderName(e.target.value)}
																placeholder="New folder name..."
																className="flex-1 text-xs border-2 border-purple-300 rounded-lg px-3 py-2 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-200"
																autoFocus
																onKeyDown={(e) => {
																	if (e.key === 'Enter') {
																		e.preventDefault();
																		handleCreateNewFolder(feed.url);
																	} else if (e.key === 'Escape') {
																		handleCancelCreateFolder();
																	}
																}}
															/>
															<button
																type="button"
																onClick={() => handleCreateNewFolder(feed.url)}
																className="px-2 py-2 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-lg hover:shadow-md transition-all"
																title="Create folder"
															>
																<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
																	<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
																</svg>
															</button>
															<button
																type="button"
																onClick={handleCancelCreateFolder}
																className="px-2 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-all"
																title="Cancel"
															>
																<svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
																	<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
																</svg>
															</button>
														</div>
													) : (
														<div className="flex items-center gap-2">
															<CustomSelect
																value={selectedFolders[feed.url] || ''}
																onChange={(value) => handleFolderChange(feed.url, value)}
																options={[
																	{ value: '', label: 'Uncategorized' },
																	...folders.map((folder) => ({
																		value: folder.id,
																		label: folder.name
																	})),
																	{ value: '__create_new__', label: '+ Create new folder...' }
																]}
																disabled={isAdded || isAdding}
															/>

															<button
																type="button"
																onClick={() => handleAddFeed(feed)}
																disabled={isAdded || isAdding}
																className={`inline-flex items-center px-3 py-2 border border-transparent text-xs font-semibold rounded-xl shadow-sm text-white transition-all ${isAdded
																		? 'bg-gradient-to-r from-green-500 to-emerald-500 cursor-not-allowed'
																		: 'bg-gradient-to-r from-orange-500 to-pink-500 hover:shadow-lg hover:scale-105'
																	} disabled:opacity-50`}
															>
																{isAdding ? (
																	<>
																		<svg className="animate-spin -ml-0.5 mr-1.5 h-3 w-3 text-white" fill="none" viewBox="0 0 24 24">
																			<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
																			<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
																		</svg>
																		Adding...
																	</>
																) : isAdded ? (
																	<>
																		<svg className="-ml-0.5 mr-1.5 h-3 w-3" fill="currentColor" viewBox="0 0 20 20">
																			<path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
																		</svg>
																		Added
																	</>
																) : (
																	'Add'
																)}
															</button>
														</div>
													)}
												</div>
											</div>
										</div>
									);
								})}
							</div>
						</div>
					)}

					{/* Actions */}
					<div className="mt-6 flex gap-3 justify-end">
						<button
							type="button"
							onClick={handleClose}
							className="px-4 py-2.5 bg-gray-100 text-gray-700 font-medium rounded-xl hover:bg-gray-200 transition-colors"
						>
							Close
						</button>
						<button
							type="submit"
							disabled={isSearching || !searchUrl.trim()}
							className="relative px-6 py-2.5 bg-gradient-to-r from-orange-500 to-pink-500 text-white font-medium rounded-xl hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 overflow-hidden group"
						>
							{/* Shimmer effect */}
							<div className="absolute inset-0 -translate-x-full group-hover:translate-x-full transition-transform duration-1000 bg-gradient-to-r from-transparent via-white/20 to-transparent"></div>

							<span className="relative flex items-center justify-center gap-2">
								{isSearching ? (
									<>
										<svg className="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24">
											<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
											<path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
										</svg>
										Searching...
									</>
								) : (
									<>
										<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
										</svg>
										Search
									</>
								)}
							</span>
						</button>
					</div>
				</form>
			</div>
		</div>
	);
}
