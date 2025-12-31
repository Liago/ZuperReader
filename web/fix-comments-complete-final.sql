-- FIX COMMENTS FOREIGN KEY & POLICIES (Final Comprehensive Version)

-- 1. Drop ALL policies on the comments table to unlock the column
DROP POLICY IF EXISTS "Users can delete own comments" ON comments;
DROP POLICY IF EXISTS "Users can insert comments on accessible articles" ON comments;
DROP POLICY IF EXISTS "Users can update own comments" ON comments;
DROP POLICY IF EXISTS "Users can view comments on accessible articles" ON comments;

-- 2. Drop the incorrect constraint if it exists
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_user_id_fkey;

-- 3. Convert user_id from TEXT to UUID
-- This matches the type of user_profiles.id
ALTER TABLE comments 
  ALTER COLUMN user_id TYPE UUID USING user_id::uuid;

-- 4. Add the correct foreign key pointing to user_profiles
ALTER TABLE comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_profiles(id)
  ON DELETE CASCADE;

-- 5. Recreate "Users can delete own comments"
-- Updated: Removed ::text cast for user_id comparison
CREATE POLICY "Users can delete own comments"
ON comments
FOR DELETE
USING (auth.uid() = user_id);

-- 6. Recreate "Users can update own comments"
-- Updated: Removed ::text cast for user_id comparison
CREATE POLICY "Users can update own comments"
ON comments
FOR UPDATE
USING (auth.uid() = user_id);

-- 7. Recreate "Users can insert comments on accessible articles"
-- Updated: Removed ::text cast for comments.user_id check
-- Kept ::text cast for articles.user_id check (assuming articles table hasn't changed)
CREATE POLICY "Users can insert comments on accessible articles"
ON comments
FOR INSERT
WITH CHECK (
  (auth.uid() = user_id) AND 
  (EXISTS ( 
    SELECT 1
    FROM articles
    WHERE (articles.id = comments.article_id) 
    AND (
      (articles.user_id = (auth.uid())::text) OR 
      (articles.is_public = true)
    )
  ))
);

-- 8. Recreate "Users can view comments on accessible articles"
-- No changes needed to logic, but re-adding it to be safe
CREATE POLICY "Users can view comments on accessible articles"
ON comments
FOR SELECT
USING (
  EXISTS ( 
    SELECT 1
    FROM articles
    WHERE (articles.id = comments.article_id) 
    AND (
      (articles.user_id = (auth.uid())::text) OR 
      (articles.is_public = true)
    )
  )
);

-- 9. Reload schema cache
NOTIFY pgrst, 'reload schema';
