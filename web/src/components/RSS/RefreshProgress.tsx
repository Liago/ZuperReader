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
		<div className="fixed top-20 left-1/2 -translate-x-1/2 z-50 animate-in fade-in slide-in-from-top-4 duration-300">
			<div className="bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl border border-orange-100 p-6 min-w-[320px] max-w-md">
				{/* Header */}
				<div className="flex items-center justify-between mb-4">
					<div className="flex items-center gap-3">
						<div className={`w-10 h-10 rounded-full flex items-center justify-center ${
							isComplete
								? 'bg-gradient-to-br from-green-400 to-emerald-500'
								: 'bg-gradient-to-br from-orange-400 to-pink-500'
						}`}>
							{isComplete ? (
								<svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
								</svg>
							) : (
								<div className="w-5 h-5 border-3 border-white/30 border-t-white rounded-full animate-spin"></div>
							)}
						</div>
						<div>
							<h3 className="font-semibold text-gray-900">
								{isComplete ? 'Aggiornamento completato!' : 'Aggiornamento feed RSS'}
							</h3>
							<p className="text-sm text-gray-500">
								{current} di {total} feed processati
							</p>
						</div>
					</div>
					<div className="text-2xl font-bold bg-gradient-to-r from-orange-600 to-pink-600 bg-clip-text text-transparent">
						{percentage}%
					</div>
				</div>

				{/* Progress Bar */}
				<div className="relative h-3 bg-gray-100 rounded-full overflow-hidden">
					{/* Progress fill */}
					<div
						className={`h-full rounded-full transition-all duration-500 ease-out ${
							isComplete
								? 'bg-gradient-to-r from-green-400 to-emerald-500'
								: 'bg-gradient-to-r from-orange-500 via-pink-500 to-purple-500'
						}`}
						style={{ width: `${percentage}%` }}
					>
						{/* Glow effect */}
						<div className="h-full w-full bg-gradient-to-r from-white/0 via-white/30 to-white/0 animate-pulse"></div>
					</div>
				</div>

				{/* Status message */}
				{!isComplete && (
					<p className="text-xs text-gray-400 mt-3 text-center">
						Recupero degli ultimi articoli in corso...
					</p>
				)}
			</div>
		</div>
	);
}
