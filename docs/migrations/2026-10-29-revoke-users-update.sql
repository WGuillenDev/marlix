-- Migration for S6-11: the users can no longer write their consent and onboarding.
--
-- For a database created from docs/schema.sql before S6-11. A new database
-- already gets this from docs/schema.sql. Run it once in the Supabase SQL
-- Editor, before merging. It runs in a transaction: if anything fails,
-- nothing changes.
--
-- Since S5-5 only the backend (service_role) writes these columns, so the
-- grant was unused and let a user clear their own consent date.

begin;

revoke update (data_consent_at, onboarding_completed_at, reminders_enabled)
  on public.users from authenticated;

commit;
