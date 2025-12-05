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
        const data = await parseArticle(url, user.id)
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
        className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
        onClick={handleBackdropClick}
      />

      {/* Modal */}
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
        <div className="bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl w-full max-w-3xl max-h-[85vh] flex flex-col pointer-events-auto overflow-hidden">

          {/* Header */}
          <div className="bg-gradient-to-r from-indigo-500 to-purple-600 px-6 py-4 flex items-center justify-between">
            <h2 className="text-xl font-bold text-white">
              Anteprima Articolo
            </h2>
            <button
              onClick={onClose}
              disabled={isSaving}
              className="text-white/90 hover:text-white transition-colors disabled:opacity-50"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          {/* Content */}
          <div className="flex-1 overflow-y-auto p-6">
            {isLoading && (
              <div className="flex flex-col items-center justify-center py-12">
                <div className="w-12 h-12 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin mb-4"></div>
                <p className="text-gray-600">Caricamento anteprima...</p>
              </div>
            )}

            {error && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
                {error}
              </div>
            )}

            {saveSuccess && (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4 text-green-700 mb-4">
                ✓ Articolo salvato con successo!
              </div>
            )}

            {!isLoading && !error && parsedArticle && (
              <div>
                {/* Image */}
                {parsedArticle.lead_image_url && (
                  <div className="mb-6 -mx-6 -mt-6">
                    <img
                      src={parsedArticle.lead_image_url}
                      alt={parsedArticle.title}
                      className="w-full h-64 object-cover"
                    />
                  </div>
                )}

                {/* Metadata */}
                <div className="flex flex-wrap gap-2 mb-4 text-sm text-gray-600">
                  {parsedArticle.domain && (
                    <span className="bg-gray-100 px-2 py-1 rounded">
                      🌐 {parsedArticle.domain}
                    </span>
                  )}
                  {parsedArticle.author && (
                    <span className="bg-gray-100 px-2 py-1 rounded">
                      ✍️ {parsedArticle.author}
                    </span>
                  )}
                  {parsedArticle.word_count && (
                    <span className="bg-gray-100 px-2 py-1 rounded">
                      📖 {Math.ceil(parsedArticle.word_count / 200)} min lettura
                    </span>
                  )}
                </div>

                {/* Title */}
                <h3 className="text-2xl font-bold text-gray-900 mb-4">
                  {parsedArticle.title}
                </h3>

                {/* Excerpt */}
                {parsedArticle.excerpt && (
                  <p className="text-gray-700 mb-4 leading-relaxed">
                    {parsedArticle.excerpt}
                  </p>
                )}

                {/* Content Preview (first 500 characters) */}
                <div className="border-t border-gray-200 pt-4">
                  <h4 className="text-sm font-semibold text-gray-700 mb-2">ANTEPRIMA CONTENUTO</h4>
                  <div
                    className="prose prose-sm max-w-none text-gray-600"
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
            <div className="border-t border-gray-200 px-6 py-4 flex justify-between items-center bg-gray-50">
              <a
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-indigo-600 hover:text-indigo-700 text-sm font-medium"
              >
                Apri originale ↗
              </a>
              <div className="flex gap-3">
                <button
                  onClick={onClose}
                  disabled={isSaving}
                  className="px-4 py-2 text-gray-700 hover:text-gray-900 font-medium transition-colors disabled:opacity-50"
                >
                  Annulla
                </button>
                <button
                  onClick={handleSaveArticle}
                  disabled={isSaving || saveSuccess}
                  className="px-6 py-2 bg-gradient-to-r from-indigo-500 to-purple-600 text-white rounded-lg font-medium hover:from-indigo-600 hover:to-purple-700 transition-all shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  {isSaving ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      Salvataggio...
                    </>
                  ) : saveSuccess ? (
                    <>✓ Salvato</>
                  ) : (
                    <>💾 Salva Articolo</>
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
