-- Realtor OS: inbox for the public Seller Net Sheet page.
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.
--
-- Anyone visiting the net sheet page can ADD a row here (that's the "send me a real number" form).
-- Nobody visiting can read, change or delete rows. Only you, signed in to Realtor OS, can read them;
-- the app turns each row into a seller lead and then clears it from the inbox.

create table if not exists public.ros_inbox (
  id         uuid        primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  source     text        not null default 'net-sheet' check (char_length(source) <= 40),
  name       text        not null check (char_length(name) between 1 and 80),
  email      text        check (email is null or (char_length(email) <= 120 and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  phone      text        check (phone is null or char_length(phone) <= 30),
  address    text        check (address is null or char_length(address) <= 160),
  area       text        check (area is null or char_length(area) <= 60),
  timeline   text        check (timeline is null or char_length(timeline) <= 30),
  estimate   jsonb       check (estimate is null or pg_column_size(estimate) <= 1500),
  constraint ros_inbox_has_contact check (email is not null or phone is not null)
);

alter table public.ros_inbox enable row level security;

-- Visitors (anon) may only insert these columns. Signed in (authenticated = you; sign-ups are off) may read and clear.
revoke all on public.ros_inbox from anon, authenticated;
grant insert (source, name, email, phone, address, area, timeline, estimate) on public.ros_inbox to anon;
grant select, delete on public.ros_inbox to authenticated;

drop policy if exists "visitors can send" on public.ros_inbox;
create policy "visitors can send" on public.ros_inbox
  for insert to anon with check (true);

drop policy if exists "owner reads" on public.ros_inbox;
create policy "owner reads" on public.ros_inbox
  for select to authenticated using (true);

drop policy if exists "owner clears" on public.ros_inbox;
create policy "owner clears" on public.ros_inbox
  for delete to authenticated using (true);

-- Spam brake: at most 30 requests an hour across the whole page.
create or replace function public.ros_inbox_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.ros_inbox where created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Too many requests. Try again later.';
  end if;
  return new;
end;
$$;

drop trigger if exists ros_inbox_limit on public.ros_inbox;
create trigger ros_inbox_limit
  before insert on public.ros_inbox
  for each row execute function public.ros_inbox_limit();
