-- Verify if the constraint exists
SELECT constraint_name, table_name 
FROM information_schema.table_constraints 
WHERE constraint_name = 'comments_user_id_fkey' 
AND table_name = 'comments';

-- Reload the PostgREST schema cache
NOTIFY pgrst, 'reload schema';
