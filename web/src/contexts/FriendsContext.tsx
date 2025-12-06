'use client';

import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { Friend, UserProfile } from '../lib/supabase';
import {
	getFriends,
	getPendingFriendRequests,
	getSentFriendRequests,
	sendFriendRequest,
	respondToFriendRequest,
	removeFriend,
	getUnreadSharesCount,
	getUserProfile,
	createUserProfile
} from '../lib/api';
import { useAuth } from './AuthContext';

interface FriendsContextType {
	friends: Friend[];
	pendingRequests: Friend[];
	sentRequests: Friend[];
	unreadSharesCount: number;
	userProfile: UserProfile | null;
	loading: boolean;
	error: string | null;
	refreshFriends: () => Promise<void>;
	refreshPendingRequests: () => Promise<void>;
	refreshUnreadCount: () => Promise<void>;
	sendRequest: (addresseeId: string) => Promise<void>;
	acceptRequest: (friendshipId: string) => Promise<void>;
	rejectRequest: (friendshipId: string) => Promise<void>;
	deleteFriend: (friendshipId: string) => Promise<void>;
}

const FriendsContext = createContext<FriendsContextType | undefined>(undefined);

export function FriendsProvider({ children }: { children: ReactNode }) {
	const { user } = useAuth();
	const [friends, setFriends] = useState<Friend[]>([]);
	const [pendingRequests, setPendingRequests] = useState<Friend[]>([]);
	const [sentRequests, setSentRequests] = useState<Friend[]>([]);
	const [unreadSharesCount, setUnreadSharesCount] = useState(0);
	const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);

	const refreshFriends = useCallback(async () => {
		if (!user) return;
		try {
			const data = await getFriends(user.id);
			setFriends(data);
		} catch (err) {
			console.error('Error loading friends:', err);
		}
	}, [user]);

	const refreshPendingRequests = useCallback(async () => {
		if (!user) return;
		try {
			const [pending, sent] = await Promise.all([
				getPendingFriendRequests(user.id),
				getSentFriendRequests(user.id)
			]);
			setPendingRequests(pending);
			setSentRequests(sent);
		} catch (err) {
			console.error('Error loading friend requests:', err);
		}
	}, [user]);

	const refreshUnreadCount = useCallback(async () => {
		if (!user) return;
		try {
			const count = await getUnreadSharesCount(user.id);
			setUnreadSharesCount(count);
		} catch (err) {
			console.error('Error loading unread count:', err);
		}
	}, [user]);

	const loadUserProfile = useCallback(async () => {
		if (!user) return;
		try {
			let profile = await getUserProfile(user.id);
			if (!profile) {
				// Create profile if it doesn't exist
				const displayName = user.email?.split('@')[0] || 'User';
				profile = await createUserProfile(user.id, displayName);
			}
			setUserProfile(profile);
		} catch (err) {
			console.error('Error loading user profile:', err);
		}
	}, [user]);

	const loadAllData = useCallback(async () => {
		if (!user) {
			setLoading(false);
			return;
		}

		setLoading(true);
		setError(null);

		try {
			await Promise.all([
				loadUserProfile(),
				refreshFriends(),
				refreshPendingRequests(),
				refreshUnreadCount()
			]);
		} catch (err) {
			setError('Failed to load data');
			console.error('Error loading friends data:', err);
		} finally {
			setLoading(false);
		}
	}, [user, loadUserProfile, refreshFriends, refreshPendingRequests, refreshUnreadCount]);

	useEffect(() => {
		loadAllData();
	}, [loadAllData]);

	const sendRequest = async (addresseeId: string) => {
		if (!user) throw new Error('User not authenticated');
		try {
			await sendFriendRequest(user.id, addresseeId);
			await refreshPendingRequests();
		} catch (err) {
			throw err;
		}
	};

	const acceptRequest = async (friendshipId: string) => {
		try {
			await respondToFriendRequest(friendshipId, 'accepted');
			await Promise.all([refreshFriends(), refreshPendingRequests()]);
		} catch (err) {
			throw err;
		}
	};

	const rejectRequest = async (friendshipId: string) => {
		try {
			await respondToFriendRequest(friendshipId, 'rejected');
			await refreshPendingRequests();
		} catch (err) {
			throw err;
		}
	};

	const deleteFriend = async (friendshipId: string) => {
		try {
			await removeFriend(friendshipId);
			await refreshFriends();
		} catch (err) {
			throw err;
		}
	};

	return (
		<FriendsContext.Provider
			value={{
				friends,
				pendingRequests,
				sentRequests,
				unreadSharesCount,
				userProfile,
				loading,
				error,
				refreshFriends,
				refreshPendingRequests,
				refreshUnreadCount,
				sendRequest,
				acceptRequest,
				rejectRequest,
				deleteFriend
			}}
		>
			{children}
		</FriendsContext.Provider>
	);
}

export function useFriends() {
	const context = useContext(FriendsContext);
	if (context === undefined) {
		throw new Error('useFriends must be used within a FriendsProvider');
	}
	return context;
}
