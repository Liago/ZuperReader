-- ============================================
-- FIX: Friendships Foreign Keys
-- ============================================
-- This migration fixes the foreign keys in the friendships table
-- to reference user_profiles instead of auth.users, which allows
-- the Supabase queries to work correctly with joins.
-- ============================================

-- Drop existing foreign key constraints
ALTER TABLE friendships
DROP CONSTRAINT IF EXISTS friendships_requester_id_fkey;

ALTER TABLE friendships
DROP CONSTRAINT IF EXISTS friendships_addressee_id_fkey;

-- Add new foreign keys pointing to user_profiles
ALTER TABLE friendships
ADD CONSTRAINT friendships_requester_id_fkey
FOREIGN KEY (requester_id) REFERENCES user_profiles(id) ON DELETE CASCADE;

ALTER TABLE friendships
ADD CONSTRAINT friendships_addressee_id_fkey
FOREIGN KEY (addressee_id) REFERENCES user_profiles(id) ON DELETE CASCADE;
