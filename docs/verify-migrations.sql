-- Verifies that a database has everything the files in docs/migrations/ create (S6-16).
--
-- Run it in the Supabase SQL Editor after a migration and before the backend
-- that needs it is deployed. It only reads the catalog and changes nothing.
-- Any row with status MISSING is a migration (or part of one) not applied yet;
-- when none is MISSING, the database is up to date.
--
-- Every new migration adds its checks here, in the same pull request.

with checks (migration, what, ok) as (
  values
    -- 2026-10-15-users-birth-date.sql
    ('2026-10-15-users-birth-date', 'column users.birth_date (not null)',
      exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'users'
          and column_name = 'birth_date' and is_nullable = 'NO'
      )),
    ('2026-10-15-users-birth-date', 'handle_new_auth_user() reads the birth date',
      coalesce(
        pg_get_functiondef(to_regprocedure('public.handle_new_auth_user()')) like '%birth_date%',
        false
      )),

    -- 2026-10-17-messages-crisis.sql
    ('2026-10-17-messages-crisis', 'column messages.crisis (boolean, not null, default false)',
      exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'messages'
          and column_name = 'crisis' and data_type = 'boolean'
          and is_nullable = 'NO' and column_default = 'false'
      )),

    -- 2026-10-17-close-idle-conversations.sql
    ('2026-10-17-close-idle-conversations', 'function close_idle_conversations(integer, uuid)',
      to_regprocedure('public.close_idle_conversations(integer, uuid)') is not null),
    ('2026-10-17-close-idle-conversations', 'close_idle_conversations: only service_role can execute it',
      coalesce(
        has_function_privilege('service_role', to_regprocedure('public.close_idle_conversations(integer, uuid)'), 'execute')
        and not has_function_privilege('anon', to_regprocedure('public.close_idle_conversations(integer, uuid)'), 'execute')
        and not has_function_privilege('authenticated', to_regprocedure('public.close_idle_conversations(integer, uuid)'), 'execute'),
        false
      )),

    -- 2026-10-17-record-interaction.sql
    ('2026-10-17-record-interaction', 'function record_interaction(uuid, date)',
      to_regprocedure('public.record_interaction(uuid, date)') is not null),
    ('2026-10-17-record-interaction', 'record_interaction: only service_role can execute it',
      coalesce(
        has_function_privilege('service_role', to_regprocedure('public.record_interaction(uuid, date)'), 'execute')
        and not has_function_privilege('anon', to_regprocedure('public.record_interaction(uuid, date)'), 'execute')
        and not has_function_privilege('authenticated', to_regprocedure('public.record_interaction(uuid, date)'), 'execute'),
        false
      )),

    -- 2026-10-21-voice-config.sql
    ('2026-10-21-voice-config', 'constraint avatars_voice_config_check accepts the engine',
      coalesce(
        (
          select pg_get_constraintdef(oid) like '%supertonic-3%'
          from pg_constraint
          where conrelid = 'public.avatars'::regclass and conname = 'avatars_voice_config_check'
        ),
        false
      )),
    ('2026-10-21-voice-config', 'the default avatar has the new voice_config',
      exists (
        select 1 from public.avatars
        where slug = 'marlix' and voice_config ->> 'engine' in ('supertonic-3', 'native')
      )),

    -- 2026-10-29-revoke-users-update.sql
    ('2026-10-29-revoke-users-update', 'authenticated cannot update users.data_consent_at',
      not has_column_privilege('authenticated', 'public.users', 'data_consent_at', 'update')),
    ('2026-10-29-revoke-users-update', 'authenticated cannot update users.onboarding_completed_at',
      not has_column_privilege('authenticated', 'public.users', 'onboarding_completed_at', 'update')),
    ('2026-10-29-revoke-users-update', 'authenticated cannot update users.reminders_enabled',
      not has_column_privilege('authenticated', 'public.users', 'reminders_enabled', 'update'))
),
-- Not created by a migration, but a table without RLS is never acceptable
-- (CONTRIBUTING.md, rule 2), and a migration that adds a table can forget it.
rls as (
  select
    'row level security' as migration,
    'RLS enabled on public.' || c.relname as what,
    c.relrowsecurity as ok
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
)
select
  case when ok then 'ok' else 'MISSING' end as status,
  migration,
  what
from (
  select * from checks
  union all
  select * from rls
) all_checks
order by ok, migration, what;
