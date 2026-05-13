-- ============================================
-- ANON HARDENING (defense-in-depth)
-- ============================================
-- Run ONCE on the existing project, AFTER supabase-grants.sql. Idempotent.
--
-- Why: Supabase historically grants ALL privileges (SELECT/INSERT/UPDATE/
-- DELETE/TRUNCATE/REFERENCES/TRIGGER) to anon on public.* via default ACLs.
-- The information_schema audit shows every table in this project currently
-- has full mutation privileges for anon. RLS is the only line of defense.
--
-- SuperReader has NO public anonymous flow that reads or writes any table:
-- - /shared/[id]/page.tsx requires authentication (redirects to /login)
-- - Login uses auth.signInWithOtp() which doesn't touch public schema
-- - All other pages live behind AuthContext
--
-- Therefore anon can be stripped of every privilege on public schema with
-- no functional impact. If a future flow needs anon SELECT (e.g. a public
-- /share/[token] page), grant it explicitly on the specific table at that
-- time. See the template in CLAUDE.md.

-- ============================================
-- REVOKE existing privileges from anon
-- ============================================
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;

-- ============================================
-- REVOKE default privileges going forward
-- ============================================
-- pg_default_acl shows legacy entries were created by both `postgres` and
-- `supabase_admin`. The SQL Editor runs as `postgres`, which can revoke its
-- own defaults but NOT supabase_admin's (would need role membership).
--
-- The block below tries the supabase_admin revoke and silently skips it on
-- insufficient_privilege. The legacy supabase_admin defaults will be
-- neutralized by Supabase itself on 2026-10-30 when the platform-wide
-- default flips. Until then, tables created via the Dashboard "Table
-- Editor" will still get anon defaults; new tables created by SQL
-- migrations running as `postgres` will inherit our `postgres` defaults
-- (no anon grants), which is the common path.

alter default privileges for role postgres in schema public
    revoke all on tables from anon;
alter default privileges for role postgres in schema public
    revoke all on sequences from anon;
alter default privileges for role postgres in schema public
    revoke all on functions from anon;

do $$
begin
    begin
        alter default privileges for role supabase_admin in schema public
            revoke all on tables from anon;
        alter default privileges for role supabase_admin in schema public
            revoke all on sequences from anon;
        alter default privileges for role supabase_admin in schema public
            revoke all on functions from anon;
    exception
        when insufficient_privilege then
            raise notice 'Skipped FOR ROLE supabase_admin defaults: current user lacks role membership. Supabase will neutralize these on 2026-10-30.';
    end;
end $$;

-- ============================================
-- VERIFICATION (run separately)
-- ============================================
-- Expected: empty result set (no rows for anon on public schema)
-- select table_name, privilege_type
-- from information_schema.role_table_grants
-- where table_schema = 'public' and grantee = 'anon';
--
-- Expected: no `anon=` entries for postgres-owned defaults (supabase_admin-
-- owned defaults may still appear until 2026-10-30).
-- select defaclrole::regrole, defaclobjtype, defaclacl
-- from pg_default_acl
-- where defaclnamespace = 'public'::regnamespace;
