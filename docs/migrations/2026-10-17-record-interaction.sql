-- Migration for S4-13: the daily usage counter moves to the database.
--
-- For a database created from docs/schema.sql before S4-13 (the Supabase
-- project of S4-1). A new database already gets this from docs/schema.sql.
-- Run it once in the Supabase SQL Editor, BEFORE deploying the backend that
-- calls it. It runs in a transaction: if anything fails, nothing changes.

begin;

-- Counts one interaction for a user on a day and returns the new total, in a
-- single statement: two messages at the same time cannot count as one. Called
-- only by the backend (S4-13), with the day on the Costa Rica calendar.
create function public.record_interaction(p_user_id uuid, p_day date)
returns integer
language sql
set search_path = ''
as $$
  insert into public.daily_usage (user_id, usage_date, interactions)
  values (p_user_id, p_day, 1)
  on conflict (user_id, usage_date)
  do update set interactions = public.daily_usage.interactions + 1
  returning interactions;
$$;

-- Nobody but the backend can call it (S1-8).
revoke execute on function public.record_interaction(uuid, date)
  from public, anon, authenticated;
grant execute on function public.record_interaction(uuid, date) to service_role;

commit;
