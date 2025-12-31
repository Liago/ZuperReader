-- FIX COMMENTS FOREIGN KEY (Complete Version with Policy Handling)

-- 1. Drop the blocking policy
DROP POLICY IF EXISTS "Users can insert comments on accessible articles" ON comments;

-- 2. Drop the incorrect constraint
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_user_id_fkey;

-- 3. Convert user_id from TEXT to UUID
ALTER TABLE comments 
  ALTER COLUMN user_id TYPE UUID USING user_id::uuid;

-- 4. Add the correct foreign key pointing to user_profiles
ALTER TABLE comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_profiles(id)
  ON DELETE CASCADE;

-- 5. Recreate the policy (updated to handle UUID user_id)
-- We removed the ::text cast for the direct user_id comparison
-- We kept the ::text cast for the articles.user_id comparison to preserve existing behavior for that table
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

-- 6. Reload schema cache
NOTIFY pgrst, 'reload schema';
