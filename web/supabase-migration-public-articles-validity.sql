-- ============================================
-- PUBLIC ARTICLE LINKS — STORED VALIDITY (for the "Public links" view)
-- ============================================
-- Run AFTER supabase-migration-public-articles-expiry.sql. Idempotent.
--
-- The expiry date alone does not tell which validity the owner picked
-- (it moves every time the validity is changed), so it is stored:
-- - `articles.public_link_validity_days`: 1, 7 or NULL (never expires).
--   For links created before this migration it stays NULL while an expiry
--   may exist: clients show "custom" in that case.
-- - `enable_article_public_link` is the same as in the expiry migration and
--   additionally saves the validity; `disable_article_public_link` clears it.
-- - Partial index to list the owner's public links quickly.
--
-- Reminder: `articles.user_id` is TEXT in this project.

-- ============================================
-- 1. Column + index
-- ============================================
alter table public.articles
    add column if not exists public_link_validity_days integer;

create index if not exists articles_user_public_links_idx
    on public.articles (user_id, public_shared_at desc)
    where public_share_token is not null;

-- ============================================
-- 2. Enable with expiry (owner only) — now also stores the validity
-- ============================================
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
        end,
        public_link_validity_days = p_expires_in_days
    where user_id = auth.uid()::text
      and id::text = p_article_id
    returning public_share_token, public_link_expires_at into v_token, v_expires_at;

    if v_token is null then
        raise exception 'Article not found' using errcode = 'P0002';
    end if;

    return jsonb_build_object(
        'token', v_token,
        'expires_at', v_expires_at,
        'validity_days', p_expires_in_days
    );
end;
$$;

-- ============================================
-- 3. Disable (owner only) — also clears expiry and validity
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
        public_link_expires_at = null,
        public_link_validity_days = null
    where user_id = auth.uid()::text
      and id::text = p_article_id;

    if not found then
        raise exception 'Article not found' using errcode = 'P0002';
    end if;
end;
$$;

-- ============================================
-- 4. Grants (unchanged signatures, re-applied for safety)
-- ============================================
revoke all on function public.enable_article_public_link(text, integer) from public, anon;
revoke all on function public.disable_article_public_link(text) from public, anon;

grant execute on function public.enable_article_public_link(text, integer) to authenticated, service_role;
grant execute on function public.disable_article_public_link(text) to authenticated, service_role;

notify pgrst, 'reload schema';
