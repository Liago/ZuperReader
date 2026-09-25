-- ============================================
-- PUBLIC ARTICLE LINKS
-- ============================================
-- Lets the owner of an article generate an unguessable public link
-- (https://<web-app>/p/<token>) that anyone can open WITHOUT an account.
-- The public page shows the parsed, sanitized article only (no tags, no
-- reading progress, no comments, no owner email).
--
-- Design:
-- - `articles.public_share_token` NULL = private, NOT NULL = readable by link.
-- - Disabling the link sets the token to NULL: the old URL stops working and
--   re-enabling generates a NEW token (a revoked link can never come back).
-- - anon gets NO table privileges on `articles` (see supabase-anon-hardening.sql).
--   It can only call `get_public_article(token)`, a SECURITY DEFINER function
--   that returns a fixed, safe subset of columns for exactly one token.
-- - The existing `is_public` column is NOT reused: it drives activity feed
--   visibility and comments RLS for authenticated users, which is unrelated.
--
-- Run once in the Supabase SQL Editor. Idempotent.

-- ============================================
-- 1. Columns
-- ============================================
alter table public.articles
    add column if not exists public_share_token text,
    add column if not exists public_shared_at timestamptz;

create unique index if not exists articles_public_share_token_key
    on public.articles (public_share_token)
    where public_share_token is not null;

-- ============================================
-- 2. Enable (owner only) — returns the token
-- ============================================
-- Reuses the current token if the link is already active, so calling it
-- twice never invalidates a link that was already sent to someone.
create or replace function public.enable_article_public_link(p_article_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    v_token text;
begin
    if auth.uid() is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;

    update public.articles
    set public_share_token = coalesce(
            public_share_token,
            -- 2 x UUIDv4 = 244 random bits, URL-safe hex
            replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
        ),
        public_shared_at = coalesce(public_shared_at, now())
    where id = p_article_id
      and user_id = auth.uid()
    returning public_share_token into v_token;

    if v_token is null then
        raise exception 'Article not found' using errcode = 'P0002';
    end if;

    return v_token;
end;
$$;

-- ============================================
-- 3. Disable (owner only)
-- ============================================
create or replace function public.disable_article_public_link(p_article_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;

    update public.articles
    set public_share_token = null,
        public_shared_at = null
    where id = p_article_id
      and user_id = auth.uid();

    if not found then
        raise exception 'Article not found' using errcode = 'P0002';
    end if;
end;
$$;

-- ============================================
-- 4. Public read (anon + authenticated)
-- ============================================
-- Returns zero rows for unknown/revoked tokens. Never exposes article id,
-- user_id, tags, reading state, email or AI summary.
create or replace function public.get_public_article(p_token text)
returns table (
    title text,
    url text,
    content text,
    excerpt text,
    image_url text,
    favicon_url text,
    author text,
    published_date timestamptz,
    domain text,
    estimated_read_time integer,
    public_shared_at timestamptz,
    shared_by_name text
)
language sql
stable
security definer
set search_path = public
as $$
    select
        -- explicit casts: the result must match the declared column types
        -- regardless of varchar/text differences in the table definition
        a.title::text,
        a.url::text,
        a.content::text,
        a.excerpt::text,
        a.image_url::text,
        a.favicon_url::text,
        a.author::text,
        a.published_date::timestamptz,
        a.domain::text,
        a.estimated_read_time::integer,
        a.public_shared_at,
        p.display_name::text as shared_by_name
    from public.articles a
    left join public.user_profiles p on p.id = a.user_id
    where p_token is not null
      and length(p_token) >= 32
      and a.public_share_token = p_token
    limit 1;
$$;

-- ============================================
-- 5. Grants
-- ============================================
revoke all on function public.enable_article_public_link(uuid) from public, anon;
revoke all on function public.disable_article_public_link(uuid) from public, anon;
revoke all on function public.get_public_article(text) from public;

grant execute on function public.enable_article_public_link(uuid) to authenticated, service_role;
grant execute on function public.disable_article_public_link(uuid) to authenticated, service_role;
-- Intentional anon exception (see CLAUDE.md): public share tokens.
grant execute on function public.get_public_article(text) to anon, authenticated, service_role;

-- ============================================
-- VERIFICATION (run separately)
-- ============================================
-- As an authenticated user:
--   select public.enable_article_public_link('<article-uuid>');
-- As anon (e.g. curl with only the anon key):
--   curl -X POST "$SUPABASE_URL/rest/v1/rpc/get_public_article" \
--     -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
--     -d '{"p_token":"<token>"}'
-- anon must still have NO table grants:
--   select table_name, privilege_type from information_schema.role_table_grants
--   where table_schema = 'public' and grantee = 'anon';
