'use client'

import { useState, useEffect } from 'react'
import { parseArticle, saveArticle } from '@/lib/api'
import { useAuth } from '@/contexts/AuthContext'

interface LinkPreviewModalProps {
	url: string
	onClose: () => void
	onArticleSaved?: () => void
}

interface ParsedArticle {
	content: string
	title: string
	excerpt: string | null
	lead_image_url: string | null
	author: string | null
	date_published: string | null
	domain: string | null
	word_count: number
	url: string
}

export default function LinkPreviewModal({ url, onClose, onArticleSaved }: LinkPreviewModalProps) {
	const { user } = useAuth()
	const [parsedArticle, setParsedArticle] = useState<ParsedArticle | null>(null)
	const [isLoading, setIsLoading] = useState(true)
	const [isSaving, setIsSaving] = useState(false)
	const [error, setError] = useState<string | null>(null)
	const [saveSuccess, setSaveSuccess] = useState(false)

	useEffect(() => {
		const fetchArticlePreview = async () => {
			if (!user) return

			try {
				setIsLoading(true)
				setError(null)
				const data = await parseArticle(url)
				setParsedArticle(data)
			} catch (err) {
				console.error('Error parsing article:', err)
				setError('Impossibile caricare l\'anteprima dell\'articolo')
			} finally {
				setIsLoading(false)
			}
		}

		fetchArticlePreview()
	}, [url, user])

	const handleSaveArticle = async () => {
		if (!user || !parsedArticle || isSaving) return

		try {
			setIsSaving(true)
			setError(null)
			await saveArticle(parsedArticle, user.id)
			setSaveSuccess(true)

			// Show success message and close after 1 second
			setTimeout(() => {
				onArticleSaved?.()
				onClose()
			}, 1000)
		} catch (err) {
			console.error('Error saving article:', err)
			setError('Errore durante il salvataggio dell\'articolo')
			setIsSaving(false)
		}
	}

	const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
		if (e.target === e.currentTarget && !isSaving) {
			onClose()
		}
	}

	return (
		<>
			{/* Backdrop */}
			<div
				className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 animate-in fade-in duration-200"
				onClick={handleBackdropClick}
			/>

			{/* Modal */}
			<div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none animate-in zoom-in-95 duration-200">
				<div className="bg-white dark:bg-gray-900 rounded-3xl shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col pointer-events-auto overflow-hidden border border-gray-200/50 dark:border-gray-700/50">

					{/* Header */}
					<div className="bg-gradient-to-br from-indigo-600 via-purple-600 to-pink-500 px-8 py-6 flex items-center justify-between relative overflow-hidden">
						<div className="absolute inset-0 bg-grid-white/10 [mask-image:linear-gradient(0deg,transparent,black)]"></div>
						<h2 className="text-2xl font-bold text-white relative z-10 font-[family-name:var(--font-montserrat)]">
							Anteprima Articolo
						</h2>
						<button
							onClick={onClose}
							disabled={isSaving}
							className="relative z-10 text-white/80 hover:text-white transition-all hover:rotate-90 duration-300 disabled:opacity-50 p-2 rounded-full hover:bg-white/10"
							aria-label="Chiudi"
						>
							<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					</div>

					{/* Content */}
					<div className="flex-1 overflow-y-auto p-8 font-[family-name:var(--font-montserrat)]">
						{isLoading && (
							<div className="flex flex-col items-center justify-center py-16">
								<div className="relative">
									<div className="w-16 h-16 border-4 border-indigo-100 dark:border-indigo-900 border-t-indigo-600 rounded-full animate-spin"></div>
									<div className="absolute inset-0 w-16 h-16 border-4 border-transparent border-t-purple-500 rounded-full animate-spin animation-delay-150"></div>
								</div>
								<p className="text-gray-600 dark:text-gray-400 mt-6 text-lg font-medium">Caricamento anteprima...</p>
							</div>
						)}

						{error && (
							<div className="bg-red-50 dark:bg-red-900/20 border-2 border-red-200 dark:border-red-800 rounded-xl p-5 text-red-700 dark:text-red-400 flex items-start gap-3">
								<svg className="w-6 h-6 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
								<span className="font-medium">{error}</span>
							</div>
						)}

						{saveSuccess && (
							<div className="bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 border-2 border-green-200 dark:border-green-800 rounded-xl p-5 text-green-700 dark:text-green-400 mb-6 flex items-center gap-3">
								<svg className="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
								<span className="font-semibold">Articolo salvato con successo!</span>
							</div>
						)}

						{!isLoading && !error && parsedArticle && (
							<div className="space-y-6">
								{/* Image */}
								{parsedArticle.lead_image_url && (
									<div className="mb-8 -mx-8 -mt-8 relative group">
										<div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent z-10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
										<img
											src={parsedArticle.lead_image_url}
											alt={parsedArticle.title}
											className="w-full h-72 object-cover"
										/>
									</div>
								)}

								{/* Metadata */}
								<div className="flex flex-wrap gap-3 mb-6">
									{parsedArticle.domain && (
										<span className="inline-flex items-center gap-2 bg-gradient-to-r from-indigo-50 to-purple-50 dark:from-indigo-900/30 dark:to-purple-900/30 border border-indigo-200 dark:border-indigo-800 px-4 py-2 rounded-full text-sm font-medium text-indigo-700 dark:text-indigo-300">
											<svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
											</svg>
											{parsedArticle.domain}
										</span>
									)}
									{parsedArticle.author && (
										<span className="inline-flex items-center gap-2 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/30 dark:to-pink-900/30 border border-purple-200 dark:border-purple-800 px-4 py-2 rounded-full text-sm font-medium text-purple-700 dark:text-purple-300">
											<svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
											</svg>
											{parsedArticle.author}
										</span>
									)}
									{parsedArticle.word_count && (
										<span className="inline-flex items-center gap-2 bg-gradient-to-r from-pink-50 to-rose-50 dark:from-pink-900/30 dark:to-rose-900/30 border border-pink-200 dark:border-pink-800 px-4 py-2 rounded-full text-sm font-medium text-pink-700 dark:text-pink-300">
											<svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
											</svg>
											{Math.ceil(parsedArticle.word_count / 200)} min lettura
										</span>
									)}
								</div>

								{/* Title */}
								<h3 className="text-3xl font-bold text-gray-900 dark:text-white mb-6 leading-tight">
									{parsedArticle.title}
								</h3>

								{/* Excerpt */}
								{parsedArticle.excerpt && (
									<div className="bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-800/50 dark:to-gray-700/50 border border-gray-200 dark:border-gray-700 rounded-2xl p-6 mb-6">
										<p className="text-gray-700 dark:text-gray-300 text-lg leading-relaxed italic">
											{parsedArticle.excerpt}
										</p>
									</div>
								)}

								{/* Content Preview */}
								<div className="border-t-2 border-gray-200 dark:border-gray-700 pt-6">
									<div className="flex items-center gap-2 mb-4">
										<svg className="w-5 h-5 text-indigo-600 dark:text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
											<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
										</svg>
										<h4 className="text-sm font-bold text-gray-700 dark:text-gray-300 uppercase tracking-wider">Anteprima Contenuto</h4>
									</div>
									<div
										className="prose prose-lg dark:prose-invert max-w-none text-gray-700 dark:text-gray-300 leading-relaxed"
										dangerouslySetInnerHTML={{
											__html: parsedArticle.content.substring(0, 500) + '...'
										}}
									/>
								</div>
							</div>
						)}
					</div>

					{/* Footer */}
					{!isLoading && !error && parsedArticle && (
						<div className="border-t-2 border-gray-200 dark:border-gray-700 px-8 py-5 flex justify-between items-center bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-900">
							<a
								href={url}
								target="_blank"
								rel="noopener noreferrer"
								className="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 text-sm font-semibold transition-all hover:gap-3 group"
							>
								<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
								</svg>
								Apri originale
							</a>
							<div className="flex gap-4">
								<button
									onClick={onClose}
									disabled={isSaving}
									className="px-6 py-2.5 text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white font-semibold transition-all hover:bg-gray-200 dark:hover:bg-gray-700 rounded-xl disabled:opacity-50"
								>
									Annulla
								</button>
								<button
									onClick={handleSaveArticle}
									disabled={isSaving || saveSuccess}
									className="px-8 py-2.5 bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-500 text-white rounded-xl font-semibold hover:from-indigo-700 hover:via-purple-700 hover:to-pink-600 transition-all shadow-lg hover:shadow-xl hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 flex items-center gap-2"
								>
									{isSaving ? (
										<>
											<div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
											Salvataggio...
										</>
									) : saveSuccess ? (
										<>
											<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
											</svg>
											Salvato
										</>
									) : (
										<>
											<svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
											</svg>
											Salva Articolo
										</>
									)}
								</button>
							</div>
						</div>
					)}
				</div>
			</div>
		</>
	)
}
