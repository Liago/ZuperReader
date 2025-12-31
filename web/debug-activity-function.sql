-- 1. Get the definition of create_activity
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'create_activity';

-- 2. Get triggers on the comments table
SELECT trigger_name, event_manipulation, action_statement, action_orientation
FROM information_schema.triggers
WHERE event_object_table = 'comments';
