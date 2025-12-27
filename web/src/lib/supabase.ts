import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Article = {
	id: string;
	user_id: string;
	url: string;
	title: string;
	content: string | null;
	excerpt: string | null;
	image_url: string | null;
	favicon_url: string | null;
	author: string | null;
	published_date: string | null;
	domain: string | null;
	tags: string[];
	is_favorite: boolean;
	like_count: number;
	comment_count: number;
	reading_status: 'unread' | 'reading' | 'completed';
	reading_progress: number; // 0-100 percentage of article read
	estimated_read_time: number | null;
	is_public: boolean;
	scraped_at: string;
	created_at: string;
	updated_at: string;
};

export type Like = {
	id: string;
	article_id: string;
	user_id: string;
	created_at: string;
};

export type Comment = {
	id: string;
	article_id: string;
	user_id: string;
	content: string;
	created_at: string;
	updated_at: string;
	// Author information from user_profiles
	author_display_name?: string | null;
	author_avatar_url?: string | null;
};

export type Share = {
	id: string;
	article_id: string;
	user_id: string;
	created_at: string;
};

// User Profile type
export type UserProfile = {
	id: string;
	display_name: string | null;
	avatar_url: string | null;
	bio: string | null;
	email?: string; // From joined auth.users
	created_at: string;
	updated_at: string;
};

// Friendship status type
export type FriendshipStatus = 'pending' | 'accepted' | 'rejected' | 'blocked';

// Friendship type
export type Friendship = {
	id: string;
	requester_id: string;
	addressee_id: string;
	status: FriendshipStatus;
	created_at: string;
	updated_at: string;
	// Populated fields from joins
	requester?: UserProfile;
	addressee?: UserProfile;
};

// Article Share type (internal sharing between users)
export type ArticleShare = {
	id: string;
	article_id: string;
	shared_by: string;
	shared_with: string;
	message: string | null;
	is_read: boolean;
	created_at: string;
	// Populated fields from joins
	article?: Article;
	sharer?: UserProfile;
};

// Friend with profile info
export type Friend = {
	friendship_id: string;
	user: UserProfile;
	status: FriendshipStatus;
	created_at: string;
	is_requester: boolean; // true if current user sent the request
};

// User Preferences type (for reading preferences synchronization)
export type UserPreferences = {
	id: string; // User ID
	font_family: 'sans' | 'serif' | 'mono' | 'roboto' | 'lato' | 'openSans' | 'ubuntu';
	font_size: number; // 12-50
	color_theme: 'light' | 'dark' | 'ocean' | 'forest' | 'sunset';
	line_height: 'compact' | 'normal' | 'relaxed' | 'loose';
	content_width: 'narrow' | 'normal' | 'wide';
	view_mode: 'grid' | 'list';
	created_at: string;
	updated_at: string;
};

// RSS Folder type
export type RSSFolder = {
	id: string;
	user_id: string;
	name: string;
	created_at: string;
	updated_at: string;
};

// RSS Feed type
export type RSSFeed = {
	id: string;
	user_id: string;
	folder_id: string | null;
	title: string | null;
	url: string;
	site_url: string | null;
	icon_url: string | null;
	created_at: string;
	updated_at: string;
	unread_count?: number; // Populated from join or query
};

// RSS Article type (for tracking read status of RSS feed items)
export type RSSArticle = {
	id: string;
	feed_id: string;
	user_id: string;
	guid: string;
	title: string;
	link: string;
	pub_date: string | null;
	author: string | null;
	content: string | null;
	content_snippet: string | null;
	is_read: boolean;
	read_at: string | null;
	created_at: string;
	updated_at: string;
};
