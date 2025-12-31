-- 1. Get definition of the generic trigger function
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'trigger_create_activity';

-- 2. Check activity_feed table schema (specifically actor_id type)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'activity_feed'
AND column_name = 'actor_id';
