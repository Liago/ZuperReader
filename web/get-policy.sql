-- Get policy definition
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'comments' 
AND policyname = 'Users can insert comments on accessible articles';
