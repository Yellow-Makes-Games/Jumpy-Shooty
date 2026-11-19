-- Jumpy Shooty: one row per signed-in player holding their cloud save (see
-- game/online/cloud_save.gd for what is in `data`). Row-level security keeps every
-- player to their own row: the game only ever has the public anon key and the
-- player's own session.

create table if not exists public.player_data (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.player_data enable row level security;

drop policy if exists "read own player data" on public.player_data;
create policy "read own player data" on public.player_data
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "insert own player data" on public.player_data;
create policy "insert own player data" on public.player_data
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "update own player data" on public.player_data;
create policy "update own player data" on public.player_data
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- No delete policy: deleting the account (auth.users) removes the row (on delete cascade).

-- Keep updated_at current on every write.
create or replace function public.player_data_touch() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists player_data_touch on public.player_data;
create trigger player_data_touch before insert or update on public.player_data
  for each row execute function public.player_data_touch();

-- A save is small (a few KB); refuse anything absurd.
alter table public.player_data drop constraint if exists player_data_size;
alter table public.player_data add constraint player_data_size check (pg_column_size(data) < 262144);
