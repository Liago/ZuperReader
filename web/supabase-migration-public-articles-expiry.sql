-- ============================================
-- PUBLIC ARTICLE LINKS — EXPIRY
-- ============================================
-- Run AFTER supabase-migration-public-articles.sql. Idempotent.
--
-- Adds a validity to public links: 1 day, 7 days or never.
-- - `articles.public_link_expires_at` NULL = never expires.
-- - `enable_article_public_link(p_article_id, p_expires_in_days)`:
--     * p_expires_in_days: 1, 7 or NULL (never). Any other value is rejected.
--     * If the link is active, it keeps the SAME token and only updates the
--       expiry (so a link already sent keeps working with the new validity).
--     * If the link is expired or off, a NEW token is generated.
--     * Returns jsonb: { "token": text, "expires_at": timestamptz | null }.
-- - `get_public_article` ignores expired links (the page shows 404).
--
-- Reminder: `articles.user_id` is TEXT in this project (see the first migration).

-- ============================================
-- 1. Column
-- ============================================
alter table public.articles
    add column if not exists public_link_expires_at timestamptz;

-- ============================================
-- 2. Enable with expiry (owner only)
-- ============================================
-- The return type changes (text -> jsonb) and a parameter is added:
-- drop the previous signatures so PostgREST has no ambiguous overloads.
drop function if exists public.enable_article_public_link(uuid);
drop function if exists public.enable_article_public_link(text);

create or replace function public.enable_article_public_link(
    p_article_id text,
    p_expires_in_days integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_token text;
    v_expires_at timestamptz;
begin
    if auth.uid() is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;

    if p_expires_in_days is not null and p_expires_in_days not in (1, 7) then
        raise exception 'Invalid validity: use 1, 7 or null (never)' using errcode = '22023';
    end if;

    update public.articles
    set public_share_token = case
            -- active link: keep the token already shared
            when public_share_token is not null
                 and (public_link_expires_at is null or public_link_expires_at > now())
                then public_share_token
            -- off or expired: new token (2 x UUIDv4 = 244 random bits, hex)
            else replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
        end,
        public_shared_at = case
            when public_share_token is not null
                 and (public_link_expires_at is null or public_link_expires_at > now())
                then coalesce(public_shared_at, now())
            else now()
        end,
        -- whole seconds: keeps the ISO string simple for iOS date parsing
        public_link_expires_at = case
            when p_expires_in_days is null then null
            else date_trunc('second', now()) + make_interval(days => p_expires_in_days)
        end
    where user_id = auth.uid()::text
      and id::text = p_article_id
    returning public_share_token, public_link_expires_at into v_token, v_expires_at;

    if v_token is null then
        raise exception 'Article not found' using errcode = 'P0002';
    end if;

    return jsonb_build_object('token', v_token, 'expires_at', v_expires_at);
end;
$$;

-- ============================================
-- 3. Disable (owner only) — also clears the expiry
-- ============================================
create or replace function public.disable_article_public_link(p_article_id text)
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
        public_shared_at = null,
        public_link_expires_at = null
    where user_id = auth.uid()::text
      and id::text = p_article_id;

    if not found then
        raise exception 'Article not found' using errcode = 'P0002';
    end if;
end;
$$;

-- ============================================
-- 4. Public read — expired links return no rows
-- ============================================
-- Return type changes (adds expires_at): drop first.
drop function if exists public.get_public_article(text);

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
    expires_at timestamptz,
    shared_by_name text
)
language sql
stable
security definer
set search_path = public
as $$
    select
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
        a.public_link_expires_at,
        p.display_name::text as shared_by_name
    from public.articles a
    -- user_profiles.id is uuid, articles.user_id is text
    left join public.user_profiles p on p.id::text = a.user_id
    where p_token is not null
      and length(p_token) >= 32
      and a.public_share_token = p_token
      and (a.public_link_expires_at is null or a.public_link_expires_at > now())
    limit 1;
$$;

-- ============================================
-- 5. Grants
-- ============================================
revoke all on function public.enable_article_public_link(text, integer) from public, anon;
revoke all on function public.disable_article_public_link(text) from public, anon;
revoke all on function public.get_public_article(text) from public;

grant execute on function public.enable_article_public_link(text, integer) to authenticated, service_role;
grant execute on function public.disable_article_public_link(text) to authenticated, service_role;
-- Intentional anon exception (see CLAUDE.md): public share tokens.
grant execute on function public.get_public_article(text) to anon, authenticated, service_role;

-- Refresh the PostgREST schema cache so the new signatures are visible now
notify pgrst, 'reload schema';
