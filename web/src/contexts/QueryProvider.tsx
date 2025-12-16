'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';

/**
 * QueryProvider wraps the app with React Query's QueryClientProvider
 *
 * Configuration:
 * - Stale time: 5 minutes (data is considered fresh for 5 minutes)
 * - Cache time: 10 minutes (data is kept in cache for 10 minutes)
 * - Retry: 2 times on failure
 * - Refetch on window focus: enabled (refetch data when user returns to tab)
 */
export function QueryProvider({ children }: { children: React.ReactNode }) {
	const [queryClient] = useState(
		() =>
			new QueryClient({
				defaultOptions: {
					queries: {
						staleTime: 5 * 60 * 1000, // 5 minutes
						gcTime: 10 * 60 * 1000, // 10 minutes (formerly cacheTime)
						retry: 2,
						refetchOnWindowFocus: true,
						refetchOnReconnect: true,
					},
					mutations: {
						retry: 1,
					},
				},
			})
	);

	return (
		<QueryClientProvider client={queryClient}>
			{children}
		</QueryClientProvider>
	);
}
