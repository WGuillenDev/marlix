-- marlix database tests: privileges, Row Level Security and sign-up (S0-6, S1-8, S4-2, S4-3, S4-5, S4-6).
--
-- Runs against the local database after docs/schema.sql was applied:
--
--   docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - < docs/schema-test.sql
--
-- Everything runs inside a transaction that is rolled back, so the database
-- is left as it was. Any failed check stops the script with an error that
-- says which check failed; "All database tests passed." means success.

-- Only failures and the final line are printed.
\o /dev/null

begin;

-- ---------------------------------------------------------------------------
-- Helpers (temporary, gone after the rollback)
-- ---------------------------------------------------------------------------

-- Runs a statement that must be refused for lack of privilege.
create function pg_temp.expect_denied(description text, statement text)
returns void
language plpgsql
as $$
begin
  execute statement;
  raise exception 'FAILED: % (the statement was allowed)', description;
exception
  when insufficient_privilege then null;
end;
$$;

-- Fails with a message unless the condition is true.
create function pg_temp.expect(description text, condition boolean)
returns void
language plpgsql
as $$
begin
  if condition is not true then
    raise exception 'FAILED: %', description;
  end if;
end;
$$;

-- Acts as a signed-in user, the way Supabase does for requests with a token.
create function pg_temp.sign_in_as(user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

grant execute on function pg_temp.expect_denied(text, text) to anon, authenticated;
grant execute on function pg_temp.expect(text, boolean) to anon, authenticated;
grant execute on function pg_temp.sign_in_as(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Privileges (S1-8): checked in the catalog, independent of any data
-- ---------------------------------------------------------------------------

do $$
declare
  table_name text;
  privilege text;
  allowed boolean;
begin
  foreach table_name in array array[
    'plan_limits', 'avatars', 'users', 'conversations', 'messages', 'memories', 'daily_usage'
  ] loop
    foreach privilege in array array[
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
    ] loop
      perform pg_temp.expect(
        format('anon has no %s on %s', privilege, table_name),
        not has_table_privilege('anon', 'public.' || table_name, privilege)
      );

      -- Table-level UPDATE is never granted; users and memories get it per column.
      allowed := privilege = 'SELECT' or (privilege = 'DELETE' and table_name = 'memories');
      perform pg_temp.expect(
        format('authenticated %s %s on %s', case when allowed then 'has' else 'has no' end, privilege, table_name),
        has_table_privilege('authenticated', 'public.' || table_name, privilege) = allowed
      );
    end loop;
  end loop;
end;
$$;

-- Column-level UPDATE: only the onboarding and settings fields, and a memory's text.
select pg_temp.expect('authenticated can update users.data_consent_at',
  has_column_privilege('authenticated', 'public.users', 'data_consent_at', 'UPDATE'));
select pg_temp.expect('authenticated can update users.onboarding_completed_at',
  has_column_privilege('authenticated', 'public.users', 'onboarding_completed_at', 'UPDATE'));
select pg_temp.expect('authenticated can update users.reminders_enabled',
  has_column_privilege('authenticated', 'public.users', 'reminders_enabled', 'UPDATE'));
select pg_temp.expect('authenticated cannot update users.plan',
  not has_column_privilege('authenticated', 'public.users', 'plan', 'UPDATE'));
select pg_temp.expect('authenticated cannot update users.avatar_id',
  not has_column_privilege('authenticated', 'public.users', 'avatar_id', 'UPDATE'));
select pg_temp.expect('authenticated cannot update users.birth_date',
  not has_column_privilege('authenticated', 'public.users', 'birth_date', 'UPDATE'));
select pg_temp.expect('authenticated can update memories.fact',
  has_column_privilege('authenticated', 'public.memories', 'fact', 'UPDATE'));
select pg_temp.expect('authenticated cannot update memories.user_id',
  not has_column_privilege('authenticated', 'public.memories', 'user_id', 'UPDATE'));

-- Functions in public: nobody but the owner and the backend can execute them.
select pg_temp.expect(format('%s is not executable by anon or authenticated', p.oid::regprocedure),
  not has_function_privilege('anon', p.oid, 'EXECUTE')
  and not has_function_privilege('authenticated', p.oid, 'EXECUTE'))
from pg_proc p
where p.pronamespace = 'public'::regnamespace;

select pg_temp.expect(format('%s is not executable by PUBLIC', p.oid::regprocedure),
  p.proacl is not null
  and not exists (select 1 from aclexplode(p.proacl) acl where acl.grantee = 0))
from pg_proc p
where p.pronamespace = 'public'::regnamespace;

-- Future tables do not inherit broad privileges.
create table public.privilege_probe (id integer);
select pg_temp.expect('a new table gives nothing to anon',
  not has_table_privilege('anon', 'public.privilege_probe', 'SELECT'));
select pg_temp.expect('a new table gives nothing to authenticated',
  not has_table_privilege('authenticated', 'public.privilege_probe', 'SELECT'));
drop table public.privilege_probe;

-- ---------------------------------------------------------------------------
-- Row Level Security (S4-2): checked in the catalog, so a table added later
-- without RLS, or with a policy that does not depend on the user, fails here
-- ---------------------------------------------------------------------------

-- Every table in public has RLS enabled.
select pg_temp.expect(format('%s has RLS enabled', c.oid::regclass), c.relrowsecurity)
from pg_class c
where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p');

-- Every table with user data (a user_id column, or the profiles table itself)
-- has at least one policy, and every one of its policies depends on auth.uid().
select pg_temp.expect(format('%s has at least one policy', t.oid::regclass),
  exists (select 1 from pg_policies p
          where p.schemaname = 'public' and p.tablename = t.relname))
from pg_class t
where t.relnamespace = 'public'::regnamespace and t.relkind in ('r', 'p')
  and (t.relname = 'users'
       or exists (select 1 from pg_attribute a
                  where a.attrelid = t.oid and a.attname = 'user_id' and not a.attisdropped));

select pg_temp.expect(format('policy "%s" on %s depends on auth.uid()', p.policyname, p.tablename),
  coalesce(p.qual, '') || coalesce(p.with_check, '') like '%auth.uid()%')
from pg_policies p
join pg_class t on t.relname = p.tablename and t.relnamespace = 'public'::regnamespace
where p.schemaname = 'public'
  and (t.relname = 'users'
       or exists (select 1 from pg_attribute a
                  where a.attrelid = t.oid and a.attname = 'user_id' and not a.attisdropped));

-- No policy opens a table to anon or to every role.
select pg_temp.expect(
  format('policy "%s" on %s is only for signed-in users', policyname, tablename),
  roles = array['authenticated']::name[])
from pg_policies
where schemaname = 'public';

-- The guard itself works: with a table created without RLS, the same query
-- that checks every table finds it.
create table public.rls_probe (id integer, user_id uuid);
select pg_temp.expect('the RLS guard detects a table created without RLS',
  exists (select 1 from pg_class c
          where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
            and not c.relrowsecurity));
drop table public.rls_probe;

-- ---------------------------------------------------------------------------
-- Sign-up (S4-3): a birth date is required, and nobody under 18 gets an account
-- ---------------------------------------------------------------------------

-- Runs a sign-up that the trigger must cancel.
create function pg_temp.expect_sign_up_refused(description text, metadata jsonb)
returns void
language plpgsql
as $$
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values (gen_random_uuid(), 'refused@example.com', metadata);
  raise exception 'FAILED: % (the sign-up was allowed)', description;
exception
  when check_violation or invalid_datetime_format or datetime_field_overflow then null;
end;
$$;

select pg_temp.expect_sign_up_refused('a sign-up without metadata is refused', null);
select pg_temp.expect_sign_up_refused('a sign-up without a birth date is refused', '{}');
select pg_temp.expect_sign_up_refused('a birth date in another format is refused',
  '{"birth_date": "20/05/1990"}');
select pg_temp.expect_sign_up_refused('a birth date that does not exist is refused',
  '{"birth_date": "1990-02-30"}');
select pg_temp.expect_sign_up_refused('someone who turns 18 tomorrow is refused',
  jsonb_build_object('birth_date',
    to_char((now() at time zone 'America/Costa_Rica')::date - interval '18 years' + interval '1 day',
            'YYYY-MM-DD')));
select pg_temp.expect('no refused sign-up left an account or a profile',
  not exists (select 1 from auth.users where email = 'refused@example.com'));

insert into auth.users (id, email, raw_user_meta_data)
values ('00000000-0000-4000-8000-0000000000d1', 'cumple@example.com',
  jsonb_build_object('birth_date',
    to_char((now() at time zone 'America/Costa_Rica')::date - interval '18 years', 'YYYY-MM-DD')));
select pg_temp.expect('someone who turns 18 today can sign up',
  exists (select 1 from public.users where id = '00000000-0000-4000-8000-0000000000d1'));
delete from auth.users where id = '00000000-0000-4000-8000-0000000000d1';

-- ---------------------------------------------------------------------------
-- Fixtures: two users, Ana and Beto, with data written as the backend would
-- ---------------------------------------------------------------------------

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000000a', 'ana@example.com', '{"birth_date": "1990-05-20"}'),
  ('00000000-0000-4000-8000-00000000000b', 'beto@example.com', '{"birth_date": "1985-11-02"}');

-- The sign-up trigger still works without EXECUTE granted to anyone.
select pg_temp.expect('the sign-up trigger created both profiles with the default avatar',
  (select count(*) from public.users u join public.avatars a on a.id = u.avatar_id and a.is_default
   where u.id in ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b')) = 2);
select pg_temp.expect('the sign-up trigger stored the birth date',
  (select birth_date from public.users where id = '00000000-0000-4000-8000-00000000000a')
  = date '1990-05-20');

insert into public.conversations (id, user_id, avatar_id)
select c.id, c.user_id, (select id from public.avatars where is_default)
from (values
  ('00000000-0000-4000-8000-0000000000c1'::uuid, '00000000-0000-4000-8000-00000000000a'::uuid),
  ('00000000-0000-4000-8000-0000000000c2'::uuid, '00000000-0000-4000-8000-00000000000b'::uuid)
) as c (id, user_id);

insert into public.messages (user_id, conversation_id, role, content) values
  ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c1', 'user', 'Mensaje de Ana'),
  ('00000000-0000-4000-8000-00000000000b', '00000000-0000-4000-8000-0000000000c2', 'user', 'Mensaje de Beto');

insert into public.memories (id, user_id, fact) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-00000000000a', 'Ana tiene un perro'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-00000000000b', 'Beto toca guitarra');

insert into public.daily_usage (user_id, interactions) values
  ('00000000-0000-4000-8000-00000000000a', 3),
  ('00000000-0000-4000-8000-00000000000b', 5);

select pg_temp.expect('messages are not marked as crisis unless the backend says so',
  (select bool_and(not crisis) from public.messages));

-- A message can never point to another user's session.
do $$
begin
  insert into public.messages (user_id, conversation_id, role, content)
  values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c2', 'user', 'x');
  raise exception 'FAILED: a message was attached to another user''s conversation';
exception
  when foreign_key_violation then null;
end;
$$;

-- ---------------------------------------------------------------------------
-- anon: no access at all
-- ---------------------------------------------------------------------------

set local role anon;

select pg_temp.expect_denied('anon cannot read users', 'select * from public.users');
select pg_temp.expect_denied('anon cannot read messages', 'select * from public.messages');
select pg_temp.expect_denied('anon cannot read avatars', 'select * from public.avatars');
select pg_temp.expect_denied('anon cannot insert messages',
  $sql$insert into public.messages (user_id, conversation_id, role, content)
       values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c1', 'user', 'x')$sql$);
select pg_temp.expect_denied('anon cannot truncate memories', 'truncate public.memories');

reset role;

-- ---------------------------------------------------------------------------
-- authenticated: Ana only sees and changes her own rows
-- ---------------------------------------------------------------------------

select pg_temp.sign_in_as('00000000-0000-4000-8000-00000000000a');

select pg_temp.expect('Ana sees only her profile',
  (select array_agg(id) from public.users) = array['00000000-0000-4000-8000-00000000000a'::uuid]);
select pg_temp.expect('Ana sees only her conversation',
  (select array_agg(id) from public.conversations) = array['00000000-0000-4000-8000-0000000000c1'::uuid]);
select pg_temp.expect('Ana sees only her messages',
  (select array_agg(content) from public.messages) = array['Mensaje de Ana']);
select pg_temp.expect('Ana sees only her memories',
  (select array_agg(fact) from public.memories) = array['Ana tiene un perro']);
select pg_temp.expect('Ana sees only her daily usage',
  (select array_agg(interactions) from public.daily_usage) = array[3]);
select pg_temp.expect('Ana can read the catalogs',
  (select count(*) from public.avatars) >= 1 and (select count(*) from public.plan_limits) >= 1);

-- Allowed changes on her own rows.
update public.users set reminders_enabled = true;
update public.memories set fact = 'Ana tiene una perrita';
select pg_temp.expect('Ana updated her settings and her memory',
  (select reminders_enabled from public.users) and (select fact from public.memories) = 'Ana tiene una perrita');

-- Changes on Beto's rows silently affect nothing (RLS).
update public.memories set fact = 'cambiado' where id = '00000000-0000-4000-8000-0000000000e2';
delete from public.memories where id = '00000000-0000-4000-8000-0000000000e2';

-- Operations without privilege are refused.
select pg_temp.expect_denied('authenticated cannot change their plan',
  $sql$update public.users set plan = 'personal'$sql$);
select pg_temp.expect_denied('authenticated cannot change their avatar',
  'update public.users set avatar_id = avatar_id');
select pg_temp.expect_denied('authenticated cannot insert messages',
  $sql$insert into public.messages (user_id, conversation_id, role, content)
       values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c1', 'user', 'x')$sql$);
select pg_temp.expect_denied('authenticated cannot insert memories',
  $sql$insert into public.memories (user_id, fact) values ('00000000-0000-4000-8000-00000000000a', 'x')$sql$);
select pg_temp.expect_denied('authenticated cannot change daily usage',
  'update public.daily_usage set interactions = 0');
select pg_temp.expect_denied('authenticated cannot delete messages', 'delete from public.messages');
select pg_temp.expect_denied('authenticated cannot change avatars', $sql$update public.avatars set name = 'x'$sql$);
-- TRUNCATE skips RLS, so only the missing privilege stops it.
select pg_temp.expect_denied('authenticated cannot truncate memories', 'truncate public.memories');
select pg_temp.expect_denied('authenticated cannot truncate messages', 'truncate public.messages');
select pg_temp.expect_denied('authenticated cannot mark a message as crisis',
  'update public.messages set crisis = true');
select pg_temp.expect_denied('authenticated cannot end conversations',
  $sql$select public.close_idle_conversations(1800)$sql$);
select pg_temp.expect_denied('authenticated cannot call the sign-up function',
  'select public.handle_new_auth_user()');

-- Ana deletes her own memory.
delete from public.memories where id = '00000000-0000-4000-8000-0000000000e1';
select pg_temp.expect('Ana deleted her memory', (select count(*) from public.memories) = 0);

reset role;

-- Beto's memory is untouched.
select pg_temp.expect('Beto''s memory was not changed or deleted by Ana',
  (select fact from public.memories where id = '00000000-0000-4000-8000-0000000000e2') = 'Beto toca guitarra');

-- ---------------------------------------------------------------------------
-- Account deletion in cascade (US-09)
-- ---------------------------------------------------------------------------

-- close_idle_conversations (S4-6): activity counts, not the start of the conversation.
insert into public.conversations (id, user_id, avatar_id, started_at)
select c.id, c.user_id, (select id from public.avatars where is_default), c.started_at
from (values
  ('00000000-0000-4000-8000-0000000000c3'::uuid, '00000000-0000-4000-8000-00000000000a'::uuid, now() - interval '3 hours'),
  ('00000000-0000-4000-8000-0000000000c4'::uuid, '00000000-0000-4000-8000-00000000000a'::uuid, now() - interval '2 hours'),
  ('00000000-0000-4000-8000-0000000000c5'::uuid, '00000000-0000-4000-8000-00000000000b'::uuid, now() - interval '4 hours')
) as c(id, user_id, started_at);

insert into public.messages (user_id, conversation_id, role, content, created_at) values
  ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c3', 'user', 'viejo', now() - interval '170 minutes'),
  ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c3', 'assistant', 'viejo', now() - interval '169 minutes'),
  ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000000c4', 'user', 'reciente', now() - interval '5 minutes');

select pg_temp.expect('close_idle_conversations ends only the idle conversation of the user asked for',
  (select count(*) from public.close_idle_conversations(1800, '00000000-0000-4000-8000-00000000000a')) = 1);
select pg_temp.expect('it ends the conversation at its last message',
  (select ended_at from public.conversations where id = '00000000-0000-4000-8000-0000000000c3')
  = (select max(created_at) from public.messages
     where conversation_id = '00000000-0000-4000-8000-0000000000c3'));
select pg_temp.expect('a conversation with recent messages stays open, however old it started',
  (select ended_at is null from public.conversations where id = '00000000-0000-4000-8000-0000000000c4'));
select pg_temp.expect('another user''s idle conversation was not touched',
  (select ended_at is null from public.conversations where id = '00000000-0000-4000-8000-0000000000c5'));
select pg_temp.expect('without a user it ends everybody''s idle conversations',
  (select count(*) from public.close_idle_conversations(1800)) = 1);
select pg_temp.expect('an idle conversation without messages ends at its start',
  (select ended_at = started_at from public.conversations
   where id = '00000000-0000-4000-8000-0000000000c5'));
select pg_temp.expect('a conversation already ended is not ended again',
  (select count(*) from public.close_idle_conversations(1800)) = 0);
select pg_temp.expect('the backend can execute close_idle_conversations',
  has_function_privilege('service_role', 'public.close_idle_conversations(integer, uuid)', 'EXECUTE'));

delete from auth.users where id = '00000000-0000-4000-8000-00000000000b';
select pg_temp.expect('deleting Beto removes all his data',
  not exists (select 1 from public.users where id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.conversations where user_id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.messages where user_id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.memories where user_id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.daily_usage where user_id = '00000000-0000-4000-8000-00000000000b'));

\echo 'All database tests passed.'

rollback;
