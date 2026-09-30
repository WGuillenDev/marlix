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
--   * `anon` gets no access: no policy is granted to it.

begin;

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
-- Created automatically on sign-up by the trigger below.
-- ---------------------------------------------------------------------------

create table public.users (
  id                      uuid primary key references auth.users (id) on delete cascade,
  plan                    text not null default 'personal' references public.plan_limits (plan),
  avatar_id               uuid not null references public.avatars (id),
  data_consent_at         timestamptz,
  onboarding_completed_at timestamptz,
  reminders_enabled       boolean not null default false,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

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

-- Create the profile when someone signs up, with the default avatar.
-- `security definer` lets the trigger write to public.users on behalf of the
-- auth service; the empty search_path avoids search_path hijacking.
create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, avatar_id)
  values (
    new.id,
    (select id from public.avatars where is_default)
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
  created_at      timestamptz not null default now(),
  foreign key (conversation_id, user_id)
    references public.conversations (id, user_id) on delete cascade,
  check (not interrupted or role = 'assistant')
);

comment on column public.messages.interrupted is
  'True when the user interrupted the avatar while it was speaking (US-12).';

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

-- Column-level guard: the app may only set the onboarding and settings fields.
-- plan and avatar_id are changed by the backend only.
revoke update on public.users from authenticated;
grant update (data_consent_at, onboarding_completed_at, reminders_enabled)
  on public.users to authenticated;

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

-- Column-level guard: when editing a memory, only its text can change.
revoke update on public.memories from authenticated;
grant update (fact) on public.memories to authenticated;

-- daily_usage: read only, to show the interactions left today.
create policy "Users can read their own daily usage"
  on public.daily_usage for select
  to authenticated
  using ((select auth.uid()) = user_id);

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
