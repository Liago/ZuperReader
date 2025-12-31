-- Add foreign key from comments.user_id to user_profiles.id
-- This allows PostgREST to join comments with user_profiles using the hint !comments_user_id_fkey

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'comments_user_id_fkey'
        AND table_name = 'comments'
    ) THEN
        ALTER TABLE comments
        ADD CONSTRAINT comments_user_id_fkey
        FOREIGN KEY (user_id)
        REFERENCES user_profiles(id)
        ON DELETE CASCADE;
    END IF;
END $$;
