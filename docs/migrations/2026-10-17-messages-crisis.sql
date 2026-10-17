-- Migration for S4-5: mark the messages of a crisis.
--
-- For a database created from docs/schema.sql before S4-5 (the Supabase
-- project of S4-1). A new database already gets this from docs/schema.sql.
-- Run it once in the Supabase SQL Editor, BEFORE deploying the backend that
-- writes the column. It runs in a transaction: if anything fails, nothing changes.
--
-- Crisis messages saved before this migration stay with crisis = false: they
-- can only be test accounts' messages, because the history started in S4-4.

begin;

alter table public.messages
  add column crisis boolean not null default false;

comment on column public.messages.crisis is
  'True for a message that the crisis filter caught and for its fixed reply (S4-5). They stay in the history but are never sent to the model.';

commit;
