-- ============================================
-- DATA API GRANTS (Supabase change 2026-10-30)
-- ============================================
-- Idempotent: safe to re-run. Run once on the existing project before
-- 2026-10-30, and on any newly provisioned project after creating tables.
--
-- Background: starting 2026-05-30 for new projects and 2026-10-30 for
-- existing ones, Supabase will stop auto-granting public.* to the Data
-- API roles (anon, authenticated). Without explicit GRANTs, PostgREST,
-- supabase-js, and GraphQL return 42501 errors.
--
-- RLS remains the actual row-level access control; GRANTs control whether
-- the table/function is *reachable* via the Data API at all.
--
-- This script uses blanket "ALL TABLES IN SCHEMA public" so it adapts to
-- the live schema instead of hard-coding table names that may drift from
-- the repo's migration files. Tables that don't exist are simply skipped.

-- ============================================
-- TABLES
-- ============================================

-- ---- authenticated: full CRUD on every table in public (RLS enforces ownership) ----
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ---- service_role: bypass for future server-side jobs (edge functions, backfills) ----
grant all on all tables in schema public to service_role;

-- ---- anon: minimal read on publicly shareable surface ----
-- The /shared/[token] page (api.ts: shareArticle/getSharesCount) reads `shares`
-- without an auth session. Guarded with to_regclass because the table may not
-- exist yet on every project.
do $$
begin
    if to_regclass('public.shares') is not null then
        execute 'grant select on public.shares to anon';
    end if;
end $$;

-- ============================================
-- SEQUENCES
-- ============================================
-- Needed when INSERTs use serial PKs. Current tables use UUIDs with
-- gen_random_uuid(), but granting now future-proofs the schema.
grant usage, select on all sequences in schema public to authenticated, service_role;

-- ============================================
-- RPC FUNCTIONS
-- ============================================
-- Blanket grant on all functions in public. PostgREST automatically ignores
-- trigger functions (returning `trigger` type) so handle_new_user,
-- update_updated_at_column, etc. won't become callable via the Data API.
grant execute on all functions in schema public to authenticated, service_role;

-- ============================================
-- DEFAULT PRIVILEGES FOR FUTURE OBJECTS
-- ============================================
-- Ensures any new table/sequence/function created in public auto-inherits
-- the right grants, so the post-2026-10-30 default change is neutralized
-- even if a future migration forgets explicit GRANTs.
alter default privileges in schema public
    grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
    grant all on tables to service_role;
alter default privileges in schema public
    grant usage, select on sequences to authenticated, service_role;
alter default privileges in schema public
    grant execute on functions to authenticated, service_role;

-- ============================================
-- VERIFICATION (run separately, not part of the grant statements above)
-- ============================================
-- select table_name, grantee, privilege_type
-- from information_schema.role_table_grants
-- where table_schema = 'public'
--   and grantee in ('anon', 'authenticated', 'service_role')
-- order by table_name, grantee;
--
-- select * from pg_default_acl where defaclnamespace = 'public'::regnamespace;
