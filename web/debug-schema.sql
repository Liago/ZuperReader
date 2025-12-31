-- Comprehensive DB Debug Script

-- 1. Check Tables and Schemas
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name IN ('comments', 'user_profiles');

-- 2. Check Columns
SELECT table_schema, table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('comments', 'user_profiles')
ORDER BY table_name, column_name;

-- 3. Check All Constraints/Foreign Keys on comments
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.table_name = 'comments';

-- 4. Check RLS Status
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname IN ('comments', 'user_profiles');
