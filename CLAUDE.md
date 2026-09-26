# CLAUDE.md

Context for Claude Code. Keep it short: stable facts here, task details in the backlog.

## Project

marlix is an open source mobile app for conversational companionship with an AI avatar (a round, cute dog inspired by Marley). It accompanies users without fostering dependency and never presents itself as therapy.

**v1 scope:** personal and family use, free, a single avatar, zero operating cost, installed via APK. Text chat, persistent history and memory, voice mode with an animated avatar, inactivity reminders. Deferred to v2: more avatars, paid plan, app store release.

## Stack

- `app/`: Flutter (Dart), Android first. Avatar animated with SVG layers (`flutter_svg`).
- `api/`: Node.js + TypeScript + Express, hosted on Render (free tier).
- Database and auth: Supabase (PostgreSQL).
- LLM: Groq (free tier), called only from the backend.
- TTS: Supertonic 3 on device, `flutter_tts` as fallback.
- STT: device recognizer (`speech_to_text`).

## Non-negotiable rules

1. **The Flutter app never calls the LLM.** Only the backend holds the API key.
2. **Every table has RLS enabled** with its policy.
3. **Chat content never goes to logs.**
4. **The crisis filter runs before the model.** A message with a clear risk signal never leaves the backend; an ambiguous one only goes to an isolated classification (no history, no memory), never to the conversation. When in doubt, trigger the crisis protocol.

Also: no secrets or real user data in the repository, ever. It is public.

## Conventions

- Everything in the repository is in English: code, docs, commits, branches, issues.
- The project name is always written `marlix` (lowercase, no accent).
- Branches: `<type>/<short-description>` (`feature/`, `fix/`, `docs/`, `chore/`, `test/`).
- Commits: Conventional Commits, present tense, no trailing period.
- Issue and PR titles start with the card ID (e.g. `S1-5`).
- See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and the Definition of Done.

## Commands

Not available yet. They will be added when `api/` (S1-1) and `app/` (S3-1) are initialized.

## Documentation

Design documents live in `docs/`: user stories, ERD and schema, architecture, API contract, crisis protocol and technical decisions.
