-- ============================================
-- VERIFICATION AND CLEANUP SCRIPT
-- ============================================
-- Run this first to check the current state

-- 1. Check if table exists and its structure
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_preferences'
ORDER BY ordinal_position;

-- 2. If table exists with wrong structure, drop it first
-- UNCOMMENT THE LINE BELOW ONLY IF YOU WANT TO RECREATE THE TABLE
-- DROP TABLE IF EXISTS user_preferences CASCADE;
