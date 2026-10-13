-- marlix database tests: privileges and Row Level Security (S0-6, S1-8).
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
-- Fixtures: two users, Ana and Beto, with data written as the backend would
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'ana@example.com'),
  ('00000000-0000-4000-8000-00000000000b', 'beto@example.com');

-- The sign-up trigger still works without EXECUTE granted to anyone.
select pg_temp.expect('the sign-up trigger created both profiles with the default avatar',
  (select count(*) from public.users u join public.avatars a on a.id = u.avatar_id and a.is_default
   where u.id in ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b')) = 2);

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

delete from auth.users where id = '00000000-0000-4000-8000-00000000000b';
select pg_temp.expect('deleting Beto removes all his data',
  not exists (select 1 from public.users where id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.conversations where user_id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.messages where user_id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.memories where user_id = '00000000-0000-4000-8000-00000000000b')
  and not exists (select 1 from public.daily_usage where user_id = '00000000-0000-4000-8000-00000000000b'));

\echo 'All database tests passed.'

rollback;
