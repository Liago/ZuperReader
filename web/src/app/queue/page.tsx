'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { GripVertical, X, ListOrdered } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { getReadingQueue, removeFromQueue, reorderQueue, QueueItem } from '@/lib/api';
import AppShell from '@/components/shell/AppShell';

export default function QueuePage() {
	const router = useRouter();
	const { user, loading: authLoading } = useAuth();
	const [queue, setQueue] = useState<QueueItem[]>([]);
	const [loading, setLoading] = useState(true);
	const [dragIndex, setDragIndex] = useState<number | null>(null);
	const [overIndex, setOverIndex] = useState<number | null>(null);

	useEffect(() => {
		if (!authLoading && !user) router.push('/login');
	}, [user, authLoading, router]);

	useEffect(() => {
		if (!user) return;
		getReadingQueue(user.id)
			.then(setQueue)
			.catch((e) => console.error('Failed to load queue:', e))
			.finally(() => setLoading(false));
	}, [user]);

	const handleRemove = async (item: QueueItem) => {
		setQueue((prev) => prev.filter((q) => q.id !== item.id));
		try {
			await removeFromQueue(item.id);
		} catch (e) {
			console.error('Failed to remove from queue:', e);
		}
	};

	const handleDrop = async (dropIndex: number) => {
		if (dragIndex === null || dragIndex === dropIndex) {
			setDragIndex(null);
			setOverIndex(null);
			return;
		}
		const next = [...queue];
		const [moved] = next.splice(dragIndex, 1);
		next.splice(dropIndex, 0, moved);
		setQueue(next);
		setDragIndex(null);
		setOverIndex(null);
		try {
			await reorderQueue(next.map((q) => q.id));
		} catch (e) {
			console.error('Failed to reorder queue:', e);
		}
	};

	if (authLoading) {
		return (
			<div className="flex min-h-screen items-center justify-center bg-app-page">
				<div className="h-10 w-10 animate-spin rounded-full border-2 border-app-line border-t-accent" />
			</div>
		);
	}

	if (!user) return null;

	const totalMinutes = queue.reduce((sum, q) => sum + (q.article.estimated_read_time || 0), 0);

	return (
		<AppShell>
			<div className="mx-auto max-w-[760px] px-9 py-8">
				<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
					{queue.length} {queue.length === 1 ? 'article' : 'articles'}
					{totalMinutes > 0 && ` · ${totalMinutes} minutes`}
				</div>
				<h1 className="mt-1 font-heading text-[34px] leading-none text-ink">Up next</h1>
				<p className="mt-3 max-w-[520px] text-[13.5px] leading-[1.6] text-app-muted">
					An ordered shortlist to read next. Drag to reorder — finishing an article advances the queue.
				</p>

				{loading ? (
					<div className="mt-6 h-64 animate-pulse rounded-[28px] border border-app-line bg-app-card" />
				) : queue.length === 0 ? (
					<div className="mt-6 rounded-[28px] border border-app-line bg-app-card px-6 py-20 text-center">
						<div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-app-surface">
							<ListOrdered size={28} className="text-accent opacity-60" strokeWidth={1.75} />
						</div>
						<p className="font-heading text-[21px] text-ink">Your queue is empty</p>
						<p className="mt-1.5 text-[13.5px] text-app-muted">
							Add articles to Up next from the Library or when you save a link.
						</p>
					</div>
				) : (
					<div className="mt-6 overflow-hidden rounded-[28px] border border-app-line bg-app-card">
						{queue.map((item, index) => {
							const first = index === 0;
							return (
								<div
									key={item.id}
									draggable
									onDragStart={() => setDragIndex(index)}
									onDragOver={(e) => {
										e.preventDefault();
										setOverIndex(index);
									}}
									onDrop={() => handleDrop(index)}
									onDragEnd={() => {
										setDragIndex(null);
										setOverIndex(null);
									}}
									className={`flex items-center gap-4 border-b border-app-line px-5 py-4 last:border-b-0 transition-colors ${
										overIndex === index && dragIndex !== null ? 'bg-app-hover' : ''
									}`}
								>
									{/* Position circle */}
									<span
										className={`flex h-[26px] w-[26px] flex-none items-center justify-center rounded-full text-[12.5px] font-bold ${
											first ? 'bg-accent text-app-page' : 'border border-app-line text-app-muted'
										}`}
									>
										{index + 1}
									</span>

									{/* Body */}
									<button
										type="button"
										onClick={() => router.push(`/articles/${item.article_id}`)}
										className="min-w-0 flex-1 text-left"
									>
										<div className="text-pretty truncate text-[16.5px] font-bold leading-[1.3] text-ink">
											{item.article.title}
										</div>
										<div className="mt-0.5 truncate text-[12.5px] text-app-muted">
											{item.article.domain}
											{item.article.estimated_read_time ? ` · ${item.article.estimated_read_time} min` : ''}
										</div>
									</button>

									{/* Trailing */}
									{first ? (
										<button
											type="button"
											onClick={() => router.push(`/articles/${item.article_id}`)}
											className="flex-none rounded-full bg-accent-200 px-3.5 py-1.5 text-[12.5px] font-bold text-accent-800 transition-colors hover:bg-accent-300"
										>
											Continue
										</button>
									) : (
										<span className="flex-none cursor-grab text-app-muted opacity-40" title="Drag to reorder">
											<GripVertical size={18} strokeWidth={2.75} />
										</span>
									)}

									<button
										type="button"
										onClick={() => handleRemove(item)}
										title="Remove from queue"
										className="flex-none text-app-muted opacity-45 transition-opacity hover:text-accent hover:opacity-100"
									>
										<X size={16} strokeWidth={2.75} />
									</button>
								</div>
							);
						})}
					</div>
				)}
			</div>
		</AppShell>
	);
}
