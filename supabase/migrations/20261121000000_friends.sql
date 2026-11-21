-- Jumpy Shooty: friends (see game/online/friends.gd and docs/ACCOUNTS.md).
--
--   player_profiles  one row per player who has claimed a username: the username
--                    (unique, any case), and their presence: what they are doing
--                    (online / lobby / match) and when the game last said so.
--   friendships      a request (accepted = false) or a friendship (true), one row per
--                    pair of players whichever of them asked.
--   lobby_invites    a host asking a friend into their lobby, with the lobby code.
--
-- The game only ever has the public key and the player's own session. It reads and
-- writes all of this through the functions below (security definer), which check who
-- is asking; row-level security keeps direct reads to your own rows, and the profiles
-- of your friends. Nothing can be written to the tables directly.

-- ---------------------------------------------------------------------------
-- Tables

create table if not exists public.player_profiles (
  user_id   uuid primary key references auth.users (id) on delete cascade,
  username  text not null,
  status    text not null default 'online',
  last_seen timestamptz not null default now(),
  constraint player_profiles_username_format check (username ~ '^[A-Za-z0-9_]{3,16}$'),
  constraint player_profiles_status check (status in ('online', 'lobby', 'match'))
);
create unique index if not exists player_profiles_username_key on public.player_profiles (lower(username));

create table if not exists public.friendships (
  requester  uuid not null references auth.users (id) on delete cascade,
  addressee  uuid not null references auth.users (id) on delete cascade,
  accepted   boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  constraint friendships_not_self check (requester <> addressee)
);
-- One row per pair, whichever of the two asked.
create unique index if not exists friendships_pair on public.friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee on public.friendships (addressee);

create table if not exists public.lobby_invites (
  from_user  uuid not null references auth.users (id) on delete cascade,
  to_user    uuid not null references auth.users (id) on delete cascade,
  code       text not null,
  created_at timestamptz not null default now(),
  primary key (from_user, to_user),
  constraint lobby_invites_code check (code ~ '^[A-Za-z0-9.:-]{1,40}$')
);
create index if not exists lobby_invites_to on public.lobby_invites (to_user);

alter table public.player_profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.lobby_invites enable row level security;

-- Reads: your own rows; a profile also to your friends.
drop policy if exists "read own or friends' profiles" on public.player_profiles;
create policy "read own or friends' profiles" on public.player_profiles
  for select to authenticated using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.friendships f
      where f.accepted
        and ((f.requester = (select auth.uid()) and f.addressee = player_profiles.user_id)
          or (f.addressee = (select auth.uid()) and f.requester = player_profiles.user_id))));

drop policy if exists "read own friendships" on public.friendships;
create policy "read own friendships" on public.friendships
  for select to authenticated using ((select auth.uid()) in (requester, addressee));

drop policy if exists "read own invites" on public.lobby_invites;
create policy "read own invites" on public.lobby_invites
  for select to authenticated using ((select auth.uid()) in (from_user, to_user));

-- No insert, update or delete policies: every write goes through a function below.
revoke insert, update, delete on public.player_profiles, public.friendships, public.lobby_invites from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Functions (POST /rest/v1/rpc/<name>). Each change returns friends_state(), so the
-- game is up to date after one request.

-- Everything the game shows: your username, your friends and what they are doing
-- (seen_ago: seconds since the game last said; the game counts a friend as offline
-- after a while), requests to you and from you, and invites to you (10 minutes old
-- at most, from friends only).
create or replace function public.friends_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  return jsonb_build_object(
    'username', (select p.username from public.player_profiles p where p.user_id = me),
    'friends', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.user_id, 'username', p.username, 'status', p.status,
          'seen_ago', round(extract(epoch from now() - p.last_seen)::numeric, 1)) order by lower(p.username))
      from public.friendships f
      join public.player_profiles p on p.user_id = case when f.requester = me then f.addressee else f.requester end
      where f.accepted and me in (f.requester, f.addressee)), '[]'::jsonb),
    'incoming', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.user_id, 'username', p.username) order by f.created_at)
      from public.friendships f join public.player_profiles p on p.user_id = f.requester
      where not f.accepted and f.addressee = me), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.user_id, 'username', p.username) order by f.created_at)
      from public.friendships f join public.player_profiles p on p.user_id = f.addressee
      where not f.accepted and f.requester = me), '[]'::jsonb),
    'invites', coalesce((
      select jsonb_agg(jsonb_build_object('from', i.from_user, 'username', p.username, 'code', i.code,
          'age', round(extract(epoch from now() - i.created_at)::numeric, 1)) order by i.created_at desc)
      from public.lobby_invites i join public.player_profiles p on p.user_id = i.from_user
      where i.to_user = me and i.created_at > now() - interval '10 minutes'
        and exists (select 1 from public.friendships f where f.accepted
          and least(f.requester, f.addressee) = least(i.from_user, me)
          and greatest(f.requester, f.addressee) = greatest(i.from_user, me))), '[]'::jsonb));
end;
$$;

-- The game's heartbeat (every 15 s or so while signed in, and when what you are doing
-- changes): you are here, doing p_status. Old invites are cleared out on the way.
create or replace function public.friends_heartbeat(p_status text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  update public.player_profiles
    set status = case when p_status in ('online', 'lobby', 'match') then p_status else 'online' end,
        last_seen = now()
    where user_id = me;
  delete from public.lobby_invites
    where (to_user = me or from_user = me) and created_at < now() - interval '10 minutes';
  return public.friends_state();
end;
$$;

-- Take a username (or change yours): 3 to 16 letters, digits or _, not one someone
-- else has in any case.
create or replace function public.claim_username(p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  wanted text := btrim(coalesce(p_name, ''));
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  if wanted !~ '^[A-Za-z0-9_]{3,16}$' then
    raise exception 'Usernames are 3 to 16 letters, digits or _';
  end if;
  if exists (select 1 from public.player_profiles where lower(username) = lower(wanted) and user_id <> me) then
    raise exception 'That username is taken';
  end if;
  begin
    insert into public.player_profiles (user_id, username) values (me, wanted)
      on conflict (user_id) do update set username = excluded.username;
  exception when unique_violation then
    raise exception 'That username is taken';
  end;
  return public.friends_state();
end;
$$;

-- Ask a player to be friends, by username. If they have already asked you, you are
-- friends now.
create or replace function public.send_friend_request(p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  them uuid;
  link public.friendships;
begin
  if not exists (select 1 from public.player_profiles where user_id = me) then
    raise exception 'Pick a username first';
  end if;
  select user_id into them from public.player_profiles where lower(username) = lower(btrim(coalesce(p_name, '')));
  if them is null then
    raise exception 'No player is called %', btrim(coalesce(p_name, ''));
  end if;
  if them = me then
    raise exception 'That''s you';
  end if;
  select * into link from public.friendships f
    where (f.requester = me and f.addressee = them) or (f.requester = them and f.addressee = me);
  if found then
    if link.accepted then
      raise exception 'You are already friends';
    end if;
    if link.requester = them then
      update public.friendships set accepted = true where requester = them and addressee = me;
    end if;
    return public.friends_state();
  end if;
  if (select count(*) from public.friendships where requester = me and not accepted) >= 50 then
    raise exception 'Too many requests waiting for an answer';
  end if;
  if (select count(*) from public.friendships where accepted and me in (requester, addressee)) >= 200 then
    raise exception 'You have the most friends you can have';
  end if;
  insert into public.friendships (requester, addressee) values (me, them);
  return public.friends_state();
end;
$$;

-- Accept or decline a request someone sent you.
create or replace function public.respond_friend_request(p_from uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if p_accept then
    update public.friendships set accepted = true where requester = p_from and addressee = me and not accepted;
  else
    delete from public.friendships where requester = p_from and addressee = me and not accepted;
  end if;
  return public.friends_state();
end;
$$;

-- Remove a friend, or take back a request you sent. Invites between you go too.
create or replace function public.remove_friend(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  delete from public.friendships
    where (requester = me and addressee = p_id) or (requester = p_id and addressee = me);
  delete from public.lobby_invites
    where (from_user = me and to_user = p_id) or (from_user = p_id and to_user = me);
  return public.friends_state();
end;
$$;

-- Invite a friend into your lobby: they see it with Join, which joins with p_code.
-- Inviting them again sends the newest code.
create or replace function public.invite_friend(p_id uuid, p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if not exists (select 1 from public.friendships f where f.accepted
      and ((f.requester = me and f.addressee = p_id) or (f.requester = p_id and f.addressee = me))) then
    raise exception 'You can only invite friends';
  end if;
  if coalesce(p_code, '') !~ '^[A-Za-z0-9.:-]{1,40}$' then
    raise exception 'That is not a lobby code';
  end if;
  insert into public.lobby_invites (from_user, to_user, code) values (me, p_id, p_code)
    on conflict (from_user, to_user) do update set code = excluded.code, created_at = now();
  return public.friends_state();
end;
$$;

-- Done with an invite (joined, or turned down).
create or replace function public.dismiss_invite(p_from uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  delete from public.lobby_invites where from_user = p_from and to_user = me;
  return public.friends_state();
end;
$$;

-- Only signed-in players may call these.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'friends_state()', 'friends_heartbeat(text)', 'claim_username(text)', 'send_friend_request(text)',
    'respond_friend_request(uuid, boolean)', 'remove_friend(uuid)', 'invite_friend(uuid, text)', 'dismiss_invite(uuid)']
  loop
    execute format('revoke all on function public.%s from public, anon', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
end;
$$;
