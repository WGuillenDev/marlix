-- marlix database schema (v1)
--
-- Target: Supabase (PostgreSQL 15+). It relies on the `auth` schema that
-- Supabase provides (`auth.users`, `auth.uid()`) and on its `authenticated`
-- role, so it does not run on plain PostgreSQL.
--
-- Run it once on a clean project. See docs/erd.md for the diagram and the
-- reasoning behind each table.
--
-- Access model:
--   * The backend uses the `service_role` key, which bypasses RLS. It is the
--     only writer of conversations, messages, memories and daily usage, so the
--     crisis filter and the daily cap cannot be skipped from the app.
--   * The app, signed in as `authenticated`, can only read its own rows and
--     manage its own memories (US-08) and onboarding fields.
--   * `anon` gets no access: no privilege and no policy.
--   * Least privilege (S1-8): Supabase grants every table privilege to `anon`
--     and `authenticated` by default, and RLS does not cover TRUNCATE. So
--     those defaults are removed and each privilege is granted explicitly in
--     the "Privileges" section. RLS then limits rows; privileges limit what
--     can be done at all. Run docs/schema-test.sql to check both.

begin;

-- Tables, sequences and functions created later in `public` (migrations from
-- the Supabase dashboard run as `postgres`) start with no access for the app
-- roles, instead of inheriting Supabase's broad defaults.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- plan_limits: daily caps per plan (US-10)
-- v1 has a single plan, `personal`. A paid plan in v2 is a new row.
-- ---------------------------------------------------------------------------

create table public.plan_limits (
  plan               text primary key,
  daily_interactions integer not null check (daily_interactions > 0),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.plan_limits is
  'Daily interaction cap per plan. One text or voice turn counts as one interaction.';

create trigger plan_limits_set_updated_at
  before update on public.plan_limits
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- avatars: catalog of avatars (US-13)
-- v1 has a single avatar. More avatars in v2 are new rows.
-- ---------------------------------------------------------------------------

create table public.avatars (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name         text not null,
  voice_config jsonb not null check (
    jsonb_typeof(voice_config) = 'object'
    and voice_config ? 'voice'
    and voice_config ? 'pitch'
    and voice_config ? 'rate'
  ),
  layers_path  text not null,
  is_default   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on column public.avatars.voice_config is
  'On-device TTS settings read by the app: {"voice", "pitch", "rate"}.';
comment on column public.avatars.layers_path is
  'Folder in the app assets that holds the avatar SVG layers.';
comment on column public.avatars.is_default is
  'Avatar assigned to new users. At most one row can be the default.';

-- Only one avatar can be the default one.
create unique index avatars_single_default_idx
  on public.avatars (is_default)
  where is_default;

create trigger avatars_set_updated_at
  before update on public.avatars
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- users: app profile, one row per auth user (US-01, US-02, US-14)
-- Created automatically on sign-up by the trigger below, which also enforces
-- the minimum age (S4-3).
-- ---------------------------------------------------------------------------

create table public.users (
  id                      uuid primary key references auth.users (id) on delete cascade,
  plan                    text not null default 'personal' references public.plan_limits (plan),
  avatar_id               uuid not null references public.avatars (id),
  birth_date              date not null check (birth_date >= date '1900-01-01'),
  data_consent_at         timestamptz,
  onboarding_completed_at timestamptz,
  reminders_enabled       boolean not null default false,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

comment on column public.users.birth_date is
  'Given at sign-up (S4-3). Stored instead of the age, so the minimum age policy can change without reworking the model.';
comment on column public.users.data_consent_at is
  'When the user gave explicit data consent during onboarding (US-02).';
comment on column public.users.onboarding_completed_at is
  'When onboarding finished. Null means onboarding must be shown (US-02).';
comment on column public.users.reminders_enabled is
  'Inactivity reminders opt-in (US-14). Off until the user accepts them.';

create index users_avatar_id_idx on public.users (avatar_id);
create index users_plan_idx on public.users (plan);

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- Create the profile when someone signs up, with the default avatar and the
-- birth date the app sends as user metadata (`birth_date`, YYYY-MM-DD).
-- Raising an error here cancels the sign-up, so nobody under the minimum age
-- gets an account, whatever client calls Supabase Auth (S4-3).
-- `security definer` lets the trigger write to public.users on behalf of the
-- auth service; the empty search_path avoids search_path hijacking.
create function public.handle_new_auth_user()
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ---------------------------------------------------------------------------
-- conversations: internal sessions (US-06, US-07)
-- The user sees one continuous chat. A session ends after a period of
-- inactivity, and that is when memory extraction runs.
-- ---------------------------------------------------------------------------

create table public.conversations (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  avatar_id           uuid not null references public.avatars (id),
  started_at          timestamptz not null default now(),
  ended_at            timestamptz,
  memory_extracted_at timestamptz,
  -- Lets messages check that they belong to a conversation of the same user.
  unique (id, user_id),
  check (ended_at is null or ended_at >= started_at),
  check (memory_extracted_at is null or ended_at is not null)
);

comment on table public.conversations is
  'Internal chat sessions, not separate chats. ended_at is set after inactivity; memory_extracted_at when memory distillation finished.';

create index conversations_user_id_started_at_idx
  on public.conversations (user_id, started_at desc);
create index conversations_avatar_id_idx on public.conversations (avatar_id);
-- Finds ended sessions still waiting for memory extraction.
create index conversations_pending_memory_idx
  on public.conversations (ended_at)
  where ended_at is not null and memory_extracted_at is null;

-- ---------------------------------------------------------------------------
-- messages: raw chat history (US-03, US-06, US-12)
-- Kept for 90 days, then deleted (S4-10).
-- ---------------------------------------------------------------------------

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid not null,
  role            text not null check (role in ('user', 'assistant')),
  content         text not null check (length(content) > 0),
  interrupted     boolean not null default false,
  crisis          boolean not null default false,
  created_at      timestamptz not null default now(),
  foreign key (conversation_id, user_id)
    references public.conversations (id, user_id) on delete cascade,
  check (not interrupted or role = 'assistant')
);

comment on column public.messages.interrupted is
  'True when the user interrupted the avatar while it was speaking (US-12).';
comment on column public.messages.crisis is
  'True for a message that the crisis filter caught and for its fixed reply (S4-5). They stay in the history but are never sent to the model.';

create index messages_conversation_id_created_at_idx
  on public.messages (conversation_id, created_at);
create index messages_user_id_created_at_idx
  on public.messages (user_id, created_at desc);
-- Supports the 90-day retention job.
create index messages_created_at_idx on public.messages (created_at);

-- ---------------------------------------------------------------------------
-- memories: distilled memory (US-07, US-08)
-- Key facts added to the system prompt. Never sensitive data.
-- ---------------------------------------------------------------------------

create table public.memories (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references auth.users (id) on delete cascade,
  fact                   text not null check (length(fact) between 1 and 500),
  category               text,
  source_conversation_id uuid references public.conversations (id) on delete set null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

comment on column public.memories.source_conversation_id is
  'Conversation the fact was extracted from. Null for facts the user edited or whose session was deleted.';

create index memories_user_id_idx on public.memories (user_id);
create index memories_source_conversation_id_idx
  on public.memories (source_conversation_id);

create trigger memories_set_updated_at
  before update on public.memories
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- daily_usage: interactions per user per day (US-10)
-- The day follows Costa Rica time, so the cap resets at local midnight.
-- ---------------------------------------------------------------------------

create table public.daily_usage (
  user_id      uuid not null references auth.users (id) on delete cascade,
  usage_date   date not null default (now() at time zone 'America/Costa_Rica')::date,
  interactions integer not null default 0 check (interactions >= 0),
  updated_at   timestamptz not null default now(),
  primary key (user_id, usage_date)
);

comment on column public.daily_usage.usage_date is
  'Calendar day in Costa Rica time (America/Costa_Rica).';

create trigger daily_usage_set_updated_at
  before update on public.daily_usage
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- Every table has RLS enabled. Policies use (select auth.uid()) so the value
-- is computed once per query instead of once per row.
-- ---------------------------------------------------------------------------

alter table public.plan_limits   enable row level security;
alter table public.avatars       enable row level security;
alter table public.users         enable row level security;
alter table public.conversations enable row level security;
alter table public.messages      enable row level security;
alter table public.memories      enable row level security;
alter table public.daily_usage   enable row level security;

-- Catalogs: any signed-in user can read them. Only the backend changes them.
create policy "Signed-in users can read plan limits"
  on public.plan_limits for select
  to authenticated
  using (true);

create policy "Signed-in users can read avatars"
  on public.avatars for select
  to authenticated
  using (true);

-- users: read and update your own profile.
create policy "Users can read their own profile"
  on public.users for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.users for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- conversations and messages: read only. The backend writes them after the
-- crisis filter and the daily cap.
create policy "Users can read their own conversations"
  on public.conversations for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their own messages"
  on public.messages for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- memories: read, edit and delete your own (US-08). The backend creates them.
create policy "Users can read their own memories"
  on public.memories for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can update their own memories"
  on public.memories for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own memories"
  on public.memories for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- daily_usage: read only, to show the interactions left today.
create policy "Users can read their own daily usage"
  on public.daily_usage for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Privileges (S1-8)
-- Least privilege for the app roles. `service_role` (the backend) keeps its
-- privileges and bypasses RLS. Policies above decide which rows; these grants
-- decide which operations exist at all.
-- ---------------------------------------------------------------------------

-- Start from nothing: remove Supabase's default grants.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- Functions run only as triggers; nobody calls them directly. A trigger does
-- not need EXECUTE on its function to fire.
revoke execute on all functions in schema public from public, anon, authenticated;

-- authenticated: read what the policies allow.
grant select on
  public.plan_limits,
  public.avatars,
  public.users,
  public.conversations,
  public.messages,
  public.memories,
  public.daily_usage
to authenticated;

-- Column-level guard: the app may only set the onboarding and settings fields.
-- plan and avatar_id are changed by the backend only.
grant update (data_consent_at, onboarding_completed_at, reminders_enabled)
  on public.users to authenticated;

-- Column-level guard: when editing a memory, only its text can change.
grant update (fact) on public.memories to authenticated;
grant delete on public.memories to authenticated;

-- anon: nothing.

-- ---------------------------------------------------------------------------
-- Seed data
-- Values are configuration and can be tuned with real usage data.
-- ---------------------------------------------------------------------------

insert into public.plan_limits (plan, daily_interactions)
values ('personal', 100);

-- The final voice is chosen in S6-1; these are neutral starting values.
insert into public.avatars (slug, name, voice_config, layers_path, is_default)
values (
  'marlix',
  'marlix',
  '{"voice": "default", "pitch": 1.0, "rate": 1.0}',
  'assets/avatars/marlix/',
  true
);

commit;
