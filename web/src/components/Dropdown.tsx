'use client';

import { useState, useRef, useEffect } from 'react';

interface DropdownOption {
	label: string;
	value: string;
}

interface DropdownProps {
	value: string;
	onChange: (value: string) => void;
	options: DropdownOption[];
	disabled?: boolean;
	className?: string;
}

export default function Dropdown({ value, onChange, options, disabled = false, className = '' }: DropdownProps) {
	const [isOpen, setIsOpen] = useState(false);
	const dropdownRef = useRef<HTMLDivElement>(null);

	const selectedOption = options.find((opt) => opt.value === value);

	useEffect(() => {
		const handleClickOutside = (event: MouseEvent) => {
			if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
				setIsOpen(false);
			}
		};

		document.addEventListener('mousedown', handleClickOutside);
		return () => document.removeEventListener('mousedown', handleClickOutside);
	}, []);

	const handleSelect = (optionValue: string) => {
		onChange(optionValue);
		setIsOpen(false);
	};

	return (
		<div className={`relative ${className}`} ref={dropdownRef}>
			<button
				type="button"
				onClick={() => !disabled && setIsOpen(!isOpen)}
				disabled={disabled}
				className={`
					flex items-center justify-between w-full px-3 py-2 text-sm bg-white dark:bg-gray-700 
					border border-gray-300 dark:border-gray-600 rounded-lg shadow-sm 
					text-gray-700 dark:text-gray-200 
					focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500
					disabled:opacity-50 disabled:cursor-not-allowed
					transition-all duration-200
				`}
			>
				<span className="truncate">{selectedOption?.label || value}</span>
				<svg
					className={`w-4 h-4 ml-2 text-gray-400 transition-transform duration-200 ${isOpen ? 'transform rotate-180' : ''}`}
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
				>
					<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
				</svg>
			</button>

			{isOpen && (
				<div className="absolute z-50 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg max-h-60 overflow-auto origin-top-right animate-in fade-in zoom-in-95 duration-100">
					<div className="py-1">
						{options.map((option) => (
							<button
								key={option.value}
								onClick={() => handleSelect(option.value)}
								className={`
									flex items-center w-full px-3 py-2 text-sm text-left
									${value === option.value
										? 'bg-purple-50 dark:bg-purple-900/20 text-purple-700 dark:text-purple-300 font-medium'
										: 'text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700/50'
									}
								`}
							>
								{value === option.value && (
									<svg className="w-4 h-4 mr-2 text-purple-600 dark:text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
									</svg>
								)}
								<span className={value === option.value ? '' : 'ml-6'}>{option.label}</span>
							</button>
						))}
					</div>
				</div>
			)}
		</div>
	);
}
