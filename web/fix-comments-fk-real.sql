-- FIX COMMENTS FOREIGN KEY AND TYPE MISMATCH

-- 1. Drop the incorrect constraint (which points to 'users' instead of 'user_profiles')
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_user_id_fkey;

-- 2. Convert user_id from TEXT to UUID (required to match user_profiles.id)
-- Note: This assumes all current user_id values are valid UUIDs.
ALTER TABLE comments 
  ALTER COLUMN user_id TYPE UUID USING user_id::uuid;

-- 3. Add the correct foreign key pointing to user_profiles
ALTER TABLE comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_profiles(id)
  ON DELETE CASCADE;

-- 4. Reload schema cache
NOTIFY pgrst, 'reload schema';
