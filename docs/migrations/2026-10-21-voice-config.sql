-- Migration for S6-2: the avatar's voice settings.
--
-- For a database created from docs/schema.sql before S6-2. A new database
-- already gets this from docs/schema.sql. Run it once in the Supabase SQL
-- Editor, BEFORE deploying the backend that reads the new shape. It runs in a
-- transaction: if anything fails, nothing changes.
--
-- The old shape was {"voice", "pitch", "rate"}, only for the phone's native
-- voice. The new one adds the engine and the Supertonic settings chosen in
-- S6-1, and keeps the native voice as the fallback.

begin;

alter table public.avatars drop constraint avatars_voice_config_check;

-- Before the new check, so the existing row does not break it.
update public.avatars
set voice_config = '{"engine": "supertonic-3", "voice": "F4", "language": "es", "steps": 5, "rate": 1.05,
    "fallback": {"voice": "default", "pitch": 1.0, "rate": 1.0}}'
where slug = 'marlix';

alter table public.avatars
  add constraint avatars_voice_config_check check (
    jsonb_typeof(voice_config) = 'object'
    -- coalesce: a missing key gives null, and a check accepts null.
    and coalesce(voice_config->>'engine' in ('supertonic-3', 'native'), false)
    and coalesce(jsonb_typeof(voice_config->'voice') = 'string', false)
    and coalesce(jsonb_typeof(voice_config->'language') = 'string', false)
    and coalesce(jsonb_typeof(voice_config->'steps') = 'number', false)
    and coalesce(jsonb_typeof(voice_config->'rate') = 'number', false)
    and coalesce(jsonb_typeof(voice_config->'fallback') = 'object', false)
  );

comment on column public.avatars.voice_config is
  'On-device voice settings read by the app (S6-2): {"engine", "voice", "language", "steps", "rate", "fallback": {"voice", "pitch", "rate"}}. The fallback is for the phone''s native voice.';

commit;
