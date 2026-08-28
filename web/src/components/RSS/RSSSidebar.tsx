'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, Search, Check, Trash2, FolderInput, ChevronDown, Upload } from 'lucide-react';
import { addFeed, createFolder, deleteFeed, updateFeedFolder } from '@/app/actions/rss';
import ConfirmationModal from '../ConfirmationModal';

interface Feed {
	id: string;
	title: string | null;
	url: string;
	folder_id: string | null;
	unread_count?: number;
}

interface Folder {
	id: string;
	name: string;
}

interface RSSSidebarProps {
	folders: Folder[];
	feeds: Feed[];
	selectedFeedId?: string;
	onSelectFeed: (feed: Feed | null) => void;
	onOpenImportModal: () => void;
	onOpenDiscoveryModal: () => void;
	onMarkFeedAsRead?: (feedId: string) => void;
}

export default function RSSSidebar({
	folders,
	feeds,
	selectedFeedId,
	onSelectFeed,
	onOpenImportModal,
	onOpenDiscoveryModal,
	onMarkFeedAsRead,
}: RSSSidebarProps) {
	const router = useRouter();
	const [newFolderMode, setNewFolderMode] = useState(false);
	const [newFolderName, setNewFolderName] = useState('');
	const [newFeedMode, setNewFeedMode] = useState(false);
	const [newFeedUrl, setNewFeedUrl] = useState('');
	const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);
	const [movingFeedId, setMovingFeedId] = useState<string | null>(null);
	const [deleteModalOpen, setDeleteModalOpen] = useState(false);
	const [feedToDelete, setFeedToDelete] = useState<{ id: string; title: string | null } | null>(null);

	const feedsByFolder = feeds.reduce((acc, feed) => {
		const key = feed.folder_id || 'uncategorized';
		if (!acc[key]) acc[key] = [];
		acc[key].push(feed);
		return acc;
	}, {} as Record<string, Feed[]>);

	const handleCreateFolder = async (e: React.FormEvent) => {
		e.preventDefault();
		if (!newFolderName.trim()) return;
		const result = await createFolder(newFolderName);
		if (result.error) {
			alert(`Failed to create folder: ${result.error}`);
			return;
		}
		setNewFolderName('');
		setNewFolderMode(false);
		router.refresh();
	};

	const handleAddFeed = async (e: React.FormEvent) => {
		e.preventDefault();
		if (!newFeedUrl.trim()) return;
		const result = await addFeed(newFeedUrl, selectedFolderId);
		if (result.error) {
			alert(`Failed to add feed: ${result.error}`);
			return;
		}
		setNewFeedUrl('');
		setNewFeedMode(false);
		setSelectedFolderId(null);
		router.refresh();
	};

	const handleDeleteFeed = (feedId: string, feedTitle: string | null, e: React.MouseEvent) => {
		e.stopPropagation();
		setFeedToDelete({ id: feedId, title: feedTitle });
		setDeleteModalOpen(true);
	};

	const confirmDeleteFeed = async () => {
		if (!feedToDelete) return;
		const result = await deleteFeed(feedToDelete.id);
		if (result.error) alert(`Failed to delete feed: ${result.error}`);
		else router.refresh();
		setDeleteModalOpen(false);
		setFeedToDelete(null);
	};

	const handleMoveFeed = async (feedId: string, newFolderId: string | null, e: React.MouseEvent) => {
		e.stopPropagation();
		const result = await updateFeedFolder(feedId, newFolderId);
		if (result.error) {
			alert(`Failed to move feed: ${result.error}`);
			return;
		}
		setMovingFeedId(null);
		router.refresh();
	};

	const toggleMoveDropdown = (feedId: string, e: React.MouseEvent) => {
		e.stopPropagation();
		setMovingFeedId(movingFeedId === feedId ? null : feedId);
	};

	const faviconFor = (url: string) => {
		try {
			return `https://www.google.com/s2/favicons?domain=${new URL(url).hostname}&sz=32`;
		} catch {
			return '';
		}
	};

	const renderFeedRow = (feed: Feed) => {
		const active = selectedFeedId === feed.id;
		return (
			<div
				key={feed.id}
				onClick={() => onSelectFeed(feed)}
				className={`group flex cursor-pointer items-center gap-2.5 rounded-xl px-3 py-2 text-[13.5px] transition-colors ${
					active ? 'bg-accent text-app-page' : 'text-ink hover:bg-app-hover'
				}`}
			>
				{/* eslint-disable-next-line @next/next/no-img-element */}
				<img src={faviconFor(feed.url)} className="h-4 w-4 flex-none rounded" alt="" />
				<span className="flex-1 truncate">{feed.title || feed.url}</span>

				{feed.unread_count !== undefined && feed.unread_count > 0 && (
					<span
						className={`flex-none rounded-full px-1.5 py-0.5 text-[11px] font-bold ${
							active ? 'bg-app-page/25 text-app-page' : 'bg-accent-200 text-accent-800'
						}`}
					>
						{feed.unread_count > 99 ? '99+' : feed.unread_count}
					</span>
				)}

				{/* Move to folder */}
				<div className="relative flex-none">
					<button
						onClick={(e) => toggleMoveDropdown(feed.id, e)}
						className={`flex h-5 w-5 items-center justify-center rounded opacity-0 transition-opacity group-hover:opacity-100 ${active ? 'text-app-page' : 'text-app-muted hover:text-ink'}`}
						title="Move to folder"
					>
						<FolderInput size={14} strokeWidth={2.75} />
					</button>
					{movingFeedId === feed.id && (
						<div className="absolute right-0 top-6 z-50 min-w-40 overflow-hidden rounded-xl border border-app-line bg-app-card py-1 [box-shadow:var(--shadow-modal)]">
							<button
								onClick={(e) => handleMoveFeed(feed.id, null, e)}
								className={`block w-full px-3 py-2 text-left text-[12.5px] text-ink transition-colors hover:bg-app-hover ${!feed.folder_id ? 'font-semibold text-accent' : ''}`}
							>
								Uncategorized
							</button>
							{folders.map((f) => (
								<button
									key={f.id}
									onClick={(e) => handleMoveFeed(feed.id, f.id, e)}
									className={`block w-full px-3 py-2 text-left text-[12.5px] text-ink transition-colors hover:bg-app-hover ${feed.folder_id === f.id ? 'font-semibold text-accent' : ''}`}
								>
									{f.name}
								</button>
							))}
						</div>
					)}
				</div>

				{onMarkFeedAsRead && feed.unread_count !== undefined && feed.unread_count > 0 && (
					<button
						onClick={(e) => {
							e.stopPropagation();
							onMarkFeedAsRead(feed.id);
						}}
						className={`flex h-5 w-5 flex-none items-center justify-center rounded opacity-0 transition-opacity group-hover:opacity-100 ${active ? 'text-app-page' : 'text-app-muted hover:text-ink'}`}
						title="Mark all as read"
					>
						<Check size={14} strokeWidth={2.75} />
					</button>
				)}

				<button
					onClick={(e) => handleDeleteFeed(feed.id, feed.title, e)}
					className={`flex h-5 w-5 flex-none items-center justify-center rounded opacity-0 transition-opacity group-hover:opacity-100 ${active ? 'text-app-page' : 'text-app-muted hover:text-accent'}`}
					title="Delete feed"
				>
					<Trash2 size={14} strokeWidth={2.75} />
				</button>
			</div>
		);
	};

	const uncategorized = feedsByFolder['uncategorized'] || [];

	return (
		<div className="flex h-full w-full flex-col border-r border-app-line bg-app-page md:w-[250px]">
			<div className="flex-1 overflow-y-auto px-4 py-6">
				{/* Actions */}
				<div className="mb-5 grid grid-cols-2 gap-2">
					<button
						onClick={() => setNewFeedMode((v) => !v)}
						className="flex items-center justify-center gap-1.5 rounded-full border border-app-line px-3 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
					>
						<Plus size={15} strokeWidth={2.75} />
						Add feed
					</button>
					<button
						onClick={onOpenDiscoveryModal}
						className="flex items-center justify-center gap-1.5 rounded-full border border-app-line px-3 py-2 text-[13px] font-semibold text-ink transition-colors hover:bg-app-hover"
					>
						<Search size={15} strokeWidth={2.75} />
						Discover
					</button>
				</div>

				{/* Add Feed form */}
				{newFeedMode && (
					<form onSubmit={handleAddFeed} className="mb-4 rounded-[18px] border border-app-line bg-app-card p-3">
						<input
							type="url"
							value={newFeedUrl}
							onChange={(e) => setNewFeedUrl(e.target.value)}
							placeholder="Feed URL (https://…)"
							autoFocus
							className="mb-2 w-full rounded-full border border-app-line bg-app-surface px-3 py-2 text-[13px] text-ink placeholder:text-app-muted focus:border-accent focus:outline-none"
						/>
						<select
							value={selectedFolderId || ''}
							onChange={(e) => setSelectedFolderId(e.target.value || null)}
							className="mb-2 w-full rounded-full border border-app-line bg-app-surface px-3 py-2 text-[13px] text-ink focus:border-accent focus:outline-none"
						>
							<option value="">Uncategorized</option>
							{folders.map((f) => (
								<option key={f.id} value={f.id}>
									{f.name}
								</option>
							))}
						</select>
						<div className="flex justify-end gap-2">
							<button type="button" onClick={() => setNewFeedMode(false)} className="rounded-full px-3 py-1.5 text-[12.5px] text-app-muted hover:text-ink">
								Cancel
							</button>
							<button type="submit" className="rounded-full bg-accent px-3 py-1.5 text-[12.5px] font-semibold text-app-page hover:bg-accent-600">
								Add
							</button>
						</div>
					</form>
				)}

				{/* New folder form */}
				{newFolderMode && (
					<form onSubmit={handleCreateFolder} className="mb-4 rounded-[18px] border border-app-line bg-app-card p-3">
						<input
							type="text"
							value={newFolderName}
							onChange={(e) => setNewFolderName(e.target.value)}
							placeholder="Folder name"
							autoFocus
							className="mb-2 w-full rounded-full border border-app-line bg-app-surface px-3 py-2 text-[13px] text-ink placeholder:text-app-muted focus:border-accent focus:outline-none"
						/>
						<div className="flex justify-end gap-2">
							<button type="button" onClick={() => setNewFolderMode(false)} className="rounded-full px-3 py-1.5 text-[12.5px] text-app-muted hover:text-ink">
								Cancel
							</button>
							<button type="submit" className="rounded-full bg-accent px-3 py-1.5 text-[12.5px] font-semibold text-app-page hover:bg-accent-600">
								Create
							</button>
						</div>
					</form>
				)}

				{/* All Articles */}
				<button
					type="button"
					onClick={() => onSelectFeed(null)}
					className={`mb-4 flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-[13.5px] font-semibold transition-colors ${
						!selectedFeedId ? 'bg-accent text-app-page' : 'text-ink hover:bg-app-hover'
					}`}
				>
					All articles
				</button>

				{/* Folders */}
				{folders.map((folder) => (
					<div key={folder.id} className="mb-4">
						<div className="flex items-center justify-between px-3 pb-1.5">
							<span className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">{folder.name}</span>
							<button
								onClick={() => {
									setNewFeedMode(true);
									setSelectedFolderId(folder.id);
								}}
								className="text-app-muted transition-colors hover:text-ink"
								title="Add feed to folder"
							>
								<Plus size={14} strokeWidth={2.75} />
							</button>
						</div>
						<div className="flex flex-col gap-0.5">
							{feedsByFolder[folder.id]?.map(renderFeedRow)}
							{(!feedsByFolder[folder.id] || feedsByFolder[folder.id].length === 0) && (
								<div className="px-3 py-1.5 text-[12px] italic text-app-muted">No feeds yet</div>
							)}
						</div>
					</div>
				))}

				{/* Uncategorized */}
				{uncategorized.length > 0 && (
					<div className="mb-4">
						<div className="px-3 pb-1.5 text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">Feeds</div>
						<div className="flex flex-col gap-0.5">{uncategorized.map(renderFeedRow)}</div>
					</div>
				)}
			</div>

			{/* Secondary actions */}
			<div className="flex items-center justify-between gap-2 border-t border-app-line px-4 py-3">
				<button onClick={() => setNewFolderMode((v) => !v)} className="flex items-center gap-1.5 text-[12.5px] text-app-muted transition-colors hover:text-ink">
					<ChevronDown size={14} strokeWidth={2.75} className="rotate-0" />
					New folder
				</button>
				<button onClick={onOpenImportModal} className="flex items-center gap-1.5 text-[12.5px] text-app-muted transition-colors hover:text-ink" title="Import OPML">
					<Upload size={14} strokeWidth={2.75} />
					Import
				</button>
			</div>

			<ConfirmationModal
				isOpen={deleteModalOpen}
				onClose={() => {
					setDeleteModalOpen(false);
					setFeedToDelete(null);
				}}
				onConfirm={confirmDeleteFeed}
				title="Delete Feed"
				message={`Are you sure you want to delete "${feedToDelete?.title || 'this feed'}"? This will also delete all articles from this feed.`}
				confirmText="Delete"
				cancelText="Cancel"
				isDestructive={true}
			/>
		</div>
	);
}
