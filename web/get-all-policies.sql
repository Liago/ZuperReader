-- Get ALL policy definitions for the comments table
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'comments';
