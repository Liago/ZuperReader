'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

interface AuthContextType {
	user: User | null;
	session: Session | null;
	loading: boolean;
	signInWithOtp: (email: string) => Promise<{ error: Error | null }>;
	verifyOtpCode: (email: string, token: string) => Promise<{ error: Error | null }>;
	signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
	const [user, setUser] = useState<User | null>(null);
	const [session, setSession] = useState<Session | null>(null);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		// Get initial session and validate it
		supabase.auth.getSession().then(async ({ data: { session } }) => {
			// Check if session exists and is not expired
			if (session) {
				const now = Math.floor(Date.now() / 1000); // Current time in seconds
				const expiresAt = session.expires_at ?? 0;

				// If token is expired, sign out automatically
				if (expiresAt < now) {
					console.log('Token expired, signing out...');
					await supabase.auth.signOut();
					setSession(null);
					setUser(null);
					setLoading(false);
					return;
				}
			}

			setSession(session);
			setUser(session?.user ?? null);
			setLoading(false);
		});

		// Listen for auth changes
		const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
			setSession(session);
			setUser(session?.user ?? null);
			setLoading(false);
		});

		return () => subscription.unsubscribe();
	}, []);

	const signInWithOtp = async (email: string) => {
		const { error } = await supabase.auth.signInWithOtp({
			email,
			options: {
				emailRedirectTo: typeof window !== 'undefined' ? `${window.location.origin}/auth/confirm` : undefined,
			},
		});
		return { error: error as Error | null };
	};

	const verifyOtpCode = async (email: string, token: string) => {
		const { error } = await supabase.auth.verifyOtp({
			email,
			token,
			type: 'email',
		});
		return { error: error as Error | null };
	};

	const signOut = async () => {
		await supabase.auth.signOut();
	};

	return (
		<AuthContext.Provider value={{ user, session, loading, signInWithOtp, verifyOtpCode, signOut }}>
			{children}
		</AuthContext.Provider>
	);
}

export function useAuth() {
	const context = useContext(AuthContext);
	if (context === undefined) {
		throw new Error('useAuth must be used within an AuthProvider');
	}
	return context;
}
