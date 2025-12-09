-- ============================================
-- MIGRATION: Drop user_profiles_with_email view
-- ============================================
-- This view exposed auth.users email data with SECURITY DEFINER
-- which bypassed RLS policies. Since it's not used in the codebase,
-- we're removing it completely for security.

DROP VIEW IF EXISTS public.user_profiles_with_email;
