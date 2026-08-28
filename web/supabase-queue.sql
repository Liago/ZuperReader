-- ============================================================================
-- Zuper Reader — "Up next" reading queue
-- ----------------------------------------------------------------------------
-- Ordered, per-user reading queue backing the revamp's "Up next" screen.
--
-- STATUS: DRAFT — NOT YET APPLIED.
-- Run this manually in the Supabase SQL editor before wiring the Up next screen
-- (a later revamp pass). No application code depends on it yet.
--
-- Follows the new-table template in CLAUDE.md: RLS on, policies scoped to
-- auth.uid(), grants to authenticated + service_role, nothing to anon.
-- ============================================================================

create table if not exists public.reading_queue (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references auth.users (id) on delete cascade,
	article_id uuid not null references public.articles (id) on delete cascade,
	position integer not null default 0,
	created_at timestamptz not null default now(),
	-- an article appears at most once in a given user's queue
	unique (user_id, article_id)
);

-- Fast ordered reads of a user's queue.
create index if not exists reading_queue_user_position_idx
	on public.reading_queue (user_id, position);

alter table public.reading_queue enable row level security;

create policy "Users can read their own queue"
	on public.reading_queue for select
	to authenticated
	using (auth.uid() = user_id);

create policy "Users can add to their own queue"
	on public.reading_queue for insert
	to authenticated
	with check (auth.uid() = user_id);

create policy "Users can reorder their own queue"
	on public.reading_queue for update
	to authenticated
	using (auth.uid() = user_id)
	with check (auth.uid() = user_id);

create policy "Users can remove from their own queue"
	on public.reading_queue for delete
	to authenticated
	using (auth.uid() = user_id);

grant select, insert, update, delete on public.reading_queue to authenticated;
grant all on public.reading_queue to service_role;
-- Intentionally NOT granted to anon (no anonymous flow; see supabase-anon-hardening.sql).
