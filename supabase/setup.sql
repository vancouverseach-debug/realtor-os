-- Realtor OS: cloud storage for the app's data.
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.

-- One row per data bucket (leads, past clients, notes, showings, market, focus).
create table if not exists public.ros_store (
  user_id    uuid        not null references auth.users on delete cascade,
  key        text        not null,
  value      jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.ros_store enable row level security;

-- You can only ever see and change your own rows.
drop policy if exists "own rows" on public.ros_store;
create policy "own rows" on public.ros_store
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Safety net: an hourly snapshot of each bucket, kept 30 days,
-- so a bad save can always be rolled back.
create table if not exists public.ros_history (
  id       bigint generated always as identity primary key,
  user_id  uuid        not null,
  key      text        not null,
  value    jsonb,
  saved_at timestamptz not null default now()
);

create index if not exists ros_history_lookup on public.ros_history (user_id, key, saved_at desc);

alter table public.ros_history enable row level security;

drop policy if exists "read own history" on public.ros_history;
create policy "read own history" on public.ros_history
  for select to authenticated
  using (user_id = auth.uid());

create or replace function public.ros_keep_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.ros_history
    where user_id = old.user_id and key = old.key
      and saved_at > now() - interval '1 hour'
  ) then
    insert into public.ros_history (user_id, key, value)
    values (old.user_id, old.key, old.value);
  end if;

  delete from public.ros_history
  where user_id = old.user_id and key = old.key
    and saved_at < now() - interval '30 days';

  return new;
end;
$$;

drop trigger if exists ros_store_history on public.ros_store;
create trigger ros_store_history
  before update on public.ros_store
  for each row execute function public.ros_keep_history();
