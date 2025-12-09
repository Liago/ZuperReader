import { useState, useRef, useEffect } from 'react';

interface AvatarMenuProps {
	userEmail: string | undefined;
	onSignOut: () => void;
}

export default function AvatarMenu({ userEmail, onSignOut }: AvatarMenuProps) {
	const [isOpen, setIsOpen] = useState(false);
	const dropdownRef = useRef<HTMLDivElement>(null);

	// Close dropdown when clicking outside
	useEffect(() => {
		function handleClickOutside(event: MouseEvent) {
			if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
				setIsOpen(false);
			}
		}
		document.addEventListener('mousedown', handleClickOutside);
		return () => {
			document.removeEventListener('mousedown', handleClickOutside);
		};
	}, []);

	const initial = userEmail ? userEmail[0].toUpperCase() : '?';

	return (
		<div className="relative" ref={dropdownRef}>
			<button
				onClick={() => setIsOpen(!isOpen)}
				className="flex items-center justify-center w-10 h-10 rounded-full bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
			>
				{initial}
			</button>

			{isOpen && (
				<div className="absolute right-0 mt-2 w-56 bg-white rounded-md shadow-lg py-1 z-10 ring-1 ring-black ring-opacity-5">
					<div className="px-4 py-3 border-b border-gray-100">
						<p className="text-sm text-gray-500">Signed in as</p>
						<p className="text-sm font-medium text-gray-900 truncate">{userEmail}</p>
					</div>

					<div className="py-1">
						<a
							href="/profile"
							className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
							role="menuitem"
						>
							Your Profile
						</a>
						<a
							href="/friends"
							className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
							role="menuitem"
						>
							Friends
						</a>
						<button
							className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex justify-between items-center"
							role="menuitem"
							onClick={() => alert('Theme toggling not implemented yet')}
						>
							<span>Theme</span>
							<span className="text-xs text-gray-400">Light</span>
						</button>
					</div>

					<div className="py-1 border-t border-gray-100">
						<button
							onClick={onSignOut}
							className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50"
							role="menuitem"
						>
							Sign Out
						</button>
					</div>
				</div>
			)}
		</div>
	);
}
