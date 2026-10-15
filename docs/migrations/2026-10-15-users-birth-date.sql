-- Migration for S4-3: birth date on the profile and minimum age at sign-up.
--
-- For a database created from docs/schema.sql before S4-3 (the Supabase
-- project of S4-1). A new database already gets this from docs/schema.sql.
-- Run it once in the Supabase SQL Editor. It runs in a transaction: if
-- anything fails, nothing changes.

begin;

-- Profiles created before S4-3 have no birth date to fill the new column with.
-- They can only be test accounts: delete them in Authentication -> Users first.
do $$
begin
  if exists (select 1 from public.users) then
    raise exception 'public.users has rows: delete those test accounts, then run this again';
  end if;
end;
$$;

alter table public.users
  add column birth_date date not null check (birth_date >= date '1900-01-01');

comment on column public.users.birth_date is
  'Given at sign-up (S4-3). Stored instead of the age, so the minimum age policy can change without reworking the model.';

-- Same function as in docs/schema.sql. `create or replace` keeps its
-- privileges: still nobody can execute it directly.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Decided on 2026-10-15 (docs/decisions.md). The app checks the same age.
  minimum_age constant integer := 18;
  birth_date_text text := new.raw_user_meta_data ->> 'birth_date';
  given_birth_date date;
  -- Ages are counted on the Costa Rica calendar, like the daily limit.
  today date := (now() at time zone 'America/Costa_Rica')::date;
begin
  -- The format is checked first: a cast alone would also accept other
  -- formats, read according to the server's DateStyle.
  if birth_date_text is null or birth_date_text !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'A birth date (YYYY-MM-DD) is required to sign up'
      using errcode = 'check_violation';
  end if;
  given_birth_date := birth_date_text::date;

  if given_birth_date > (today - make_interval(years => minimum_age))::date then
    raise exception 'marlix is for people aged % or older', minimum_age
      using errcode = 'check_violation';
  end if;

  insert into public.users (id, avatar_id, birth_date)
  values (
    new.id,
    (select id from public.avatars where is_default),
    given_birth_date
  );
  return new;
end;
$$;

commit;
