'use client';

import { useEffect, useCallback } from 'react';

interface ConfirmationModalProps {
	isOpen: boolean;
	onClose: () => void;
	onConfirm: () => void;
	title: string;
	message: string;
	confirmText?: string;
	cancelText?: string;
	isDestructive?: boolean;
}

export default function ConfirmationModal({
	isOpen,
	onClose,
	onConfirm,
	title,
	message,
	confirmText = 'Confirm',
	cancelText = 'Cancel',
	isDestructive = false
}: ConfirmationModalProps) {
	// Close on ESC key
	const handleEscKey = useCallback((e: KeyboardEvent) => {
		if (e.key === 'Escape') {
			onClose();
		}
	}, [onClose]);

	useEffect(() => {
		if (isOpen) {
			document.addEventListener('keydown', handleEscKey);
			// Prevent body scroll when modal is open
			document.body.style.overflow = 'hidden';
		}

		return () => {
			document.removeEventListener('keydown', handleEscKey);
			document.body.style.overflow = 'unset';
		};
	}, [isOpen, handleEscKey]);

	if (!isOpen) return null;

	return (
		<div
			className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn"
			onClick={onClose}
		>
			<div
				className="relative w-full max-w-md bg-white dark:bg-gray-800 rounded-2xl shadow-2xl overflow-hidden transform transition-all animate-scaleIn border border-gray-100 dark:border-gray-700"
				onClick={(e) => e.stopPropagation()}
			>
				{/* Header */}
				<div className="p-6 pb-0">
					<h3 className="text-xl font-bold text-gray-900 dark:text-gray-100">
						{title}
					</h3>
				</div>

				{/* Content */}
				<div className="p-6">
					<p className="text-gray-600 dark:text-gray-300">
						{message}
					</p>
				</div>

				{/* Footer / Actions */}
				<div className="px-6 py-4 bg-gray-50 dark:bg-gray-800/50 flex justify-end gap-3 border-t border-gray-100 dark:border-gray-700">
					<button
						onClick={onClose}
						className="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-purple-500 transition-colors"
					>
						{cancelText}
					</button>
					<button
						onClick={() => {
							onConfirm();
							onClose();
						}}
						className={`px-4 py-2 text-sm font-medium text-white rounded-lg focus:outline-none focus:ring-2 focus:ring-offset-2 transition-colors ${
							isDestructive
								? 'bg-red-600 hover:bg-red-700 focus:ring-red-500'
								: 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-500'
						}`}
					>
						{confirmText}
					</button>
				</div>
			</div>

			<style jsx>{`
				@keyframes fadeIn {
					from { opacity: 0; }
					to { opacity: 1; }
				}
				@keyframes scaleIn {
					from { 
						opacity: 0; 
						transform: scale(0.95); 
					}
					to { 
						opacity: 1; 
						transform: scale(1); 
					}
				}
				.animate-fadeIn {
					animation: fadeIn 0.2s ease-out;
				}
				.animate-scaleIn {
					animation: scaleIn 0.3s ease-out;
				}
			`}</style>
		</div>
	);
}
