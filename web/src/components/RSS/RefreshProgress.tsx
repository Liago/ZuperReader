'use client';

import { Check } from 'lucide-react';

interface RefreshProgressProps {
	current: number;
	total: number;
	isVisible: boolean;
}

export default function RefreshProgress({ current, total, isVisible }: RefreshProgressProps) {
	if (!isVisible || total === 0) return null;

	const percentage = Math.round((current / total) * 100);
	const isComplete = current === total;

	return (
		<div className="fixed left-1/2 top-20 z-50 -translate-x-1/2 animate-in fade-in slide-in-from-top-4 duration-300">
			<div className="min-w-[320px] max-w-md rounded-[28px] border border-app-line bg-app-card p-6 [box-shadow:var(--shadow-modal)]">
				{/* Header */}
				<div className="mb-4 flex items-center justify-between gap-4">
					<div className="flex items-center gap-3">
						<div className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-accent">
							{isComplete ? (
								<Check size={20} strokeWidth={2.75} className="text-app-page" />
							) : (
								<div className="h-5 w-5 animate-spin rounded-full border-2 border-app-page/30 border-t-app-page" />
							)}
						</div>
						<div>
							<h3 className="font-heading text-[17px] text-ink">
								{isComplete ? 'Feeds updated' : 'Refreshing feeds'}
							</h3>
							<p className="text-[13px] text-app-muted">
								{current} of {total} feeds processed
							</p>
						</div>
					</div>
					<div className="font-heading text-[24px] text-accent">{percentage}%</div>
				</div>

				{/* Progress Bar */}
				<div className="h-2 overflow-hidden rounded-full bg-app-line">
					<div
						className="h-full rounded-full bg-accent transition-all duration-500 ease-out"
						style={{ width: `${percentage}%` }}
					/>
				</div>

				{/* Status message */}
				{!isComplete && (
					<div className="mt-3 text-center">
						<p className="text-[12px] text-app-muted">Fetching the latest articles…</p>
						<p className="mt-1 text-[12px] font-medium text-sage">You can keep reading while we update.</p>
					</div>
				)}
			</div>
		</div>
	);
}
