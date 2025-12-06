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
};

export type Share = {
	id: string;
	article_id: string;
	user_id: string;
	created_at: string;
};
