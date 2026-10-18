# Changelog

Notable changes to marlix, one entry per sprint. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Sprint 5 — Avatars: the avatar comes to life.

## Sprint 4 — Data and memory (2026-10-15 to 2026-10-18)

marlix knows who you are: accounts with Supabase, a saved history, a distilled memory the person can see and edit, and data that is deleted when it should be.

### Added

- Supabase project with the schema applied, and the migrations folder for later changes ([#95](https://github.com/WGuillenDev/marlix/pull/95)).
- Sign up and sign in: the app has an auth screen (18 or older) and a sign-out button, and `/v1` checks the Supabase session instead of the development token ([#103](https://github.com/WGuillenDev/marlix/pull/103)).
- Chat history saved by the backend and `GET /v1/history`, paged with an opaque cursor ([#105](https://github.com/WGuillenDev/marlix/pull/105)).
- The model sees the last 16 messages of the open conversation, never the ones of a crisis ([#108](https://github.com/WGuillenDev/marlix/pull/108)).
- Distilled memory: a background job ends idle conversations and extracts lasting facts with a small model, with two barriers against sensitive data ([#110](https://github.com/WGuillenDev/marlix/pull/110)).
- The saved memories go into the system prompt, the most recently updated first ([#112](https://github.com/WGuillenDev/marlix/pull/112)).
- "Lo que marlix sabe de mí" screen to see, edit and delete memories, with `/v1/memories` ([#114](https://github.com/WGuillenDev/marlix/pull/114)).
- Account deletion in cascade after a recent sign-in, with `DELETE /v1/account` ([#116](https://github.com/WGuillenDev/marlix/pull/116)).
- Raw messages are deleted after 90 days (`MESSAGE_RETENTION_DAYS`) by an hourly job, and the policy is shown in Settings ([#118](https://github.com/WGuillenDev/marlix/pull/118)).

### Changed

- The daily usage count and cap moved from memory to the `daily_usage` and `plan_limits` tables, so a restart does not reset the count and a new cap needs no deploy. The app accepts a chat reply without `usage` ([#119](https://github.com/WGuillenDev/marlix/pull/119)).

### Security

- Row Level Security enabled on every table, with tests that act as two different users and a guard that fails if a table forgets it ([#97](https://github.com/WGuillenDev/marlix/pull/97)).
- The app is not backed up to Android's cloud ([#99](https://github.com/WGuillenDev/marlix/pull/99)).
- A release build rejects the development token ([#101](https://github.com/WGuillenDev/marlix/pull/101)).
- The development token no longer exists in the code: every request needs a Supabase session ([#103](https://github.com/WGuillenDev/marlix/pull/103)).
- Deleting an account requires a sign-in from the last 5 minutes, read from `amr` and not `iat`, so a stolen refresh token cannot delete it ([#116](https://github.com/WGuillenDev/marlix/pull/116)).
- Less data kept: messages expire after 90 days, and memories last only as long as the account or until the person deletes them ([#118](https://github.com/WGuillenDev/marlix/pull/118)).

## Sprint 3 — Chat app (2026-10-15)

Talking to marlix from the phone: the Flutter app chats with the backend, explains every failure without losing a message, and keeps 9-1-1 one tap away, even offline.

### Added

- Flutter app in `app/` (Android first) with Riverpod, the style guide's colors and the backend URL per environment, never in the code ([#74](https://github.com/WGuillenDev/marlix/pull/74)).
- API service, the only code that talks to the backend, with typed errors for every contract code, network failures and timeouts ([#76](https://github.com/WGuillenDev/marlix/pull/76)).
- Chat screen from the wireframe: bubbles, remaining messages, typing indicator, Nunito and Baloo 2 bundled with the app ([#78](https://github.com/WGuillenDev/marlix/pull/78)).
- Chat states: a failed message stays in place with a retry, a "waking up" banner, the daily limit card and a prominent crisis card ([#80](https://github.com/WGuillenDev/marlix/pull/80)).
- Help screen with 9-1-1 and the other lines, one tap away from the chat. Every button opens the dialer with the number loaded, and the list works offline ([#82](https://github.com/WGuillenDev/marlix/pull/82)).

### Security

- Render deploys a commit on `main` only after its CI checks pass ([#84](https://github.com/WGuillenDev/marlix/pull/84)).
- Docker images pinned by tag and digest ([#86](https://github.com/WGuillenDev/marlix/pull/86)).
- Secret protection reviewed and documented in `SECURITY.md`; generic patterns and validity checks are not available on a personal repository ([#88](https://github.com/WGuillenDev/marlix/pull/88)).
- The CI also checks the app (format, analysis and tests), and the `main` ruleset requires it. Dependabot updates the Flutter packages ([#90](https://github.com/WGuillenDev/marlix/pull/90)).
- The app holds no API key: the development token comes from a file ignored by Git, and a test fails if the app's code or config contains something that looks like a key ([#76](https://github.com/WGuillenDev/marlix/pull/76)).

## Sprint 2 — Security (2026-10-14)

Nobody in crisis is left without help: every message goes through the crisis filter before the model, and every reply is reviewed before it reaches the user.

### Added

- Keyword crisis filter, run on every message before the model. A crisis gets a fixed reply with 9-1-1 first, and the model is not called ([#48](https://github.com/WGuillenDev/marlix/pull/48)).
- Second layer that classifies ambiguous messages with `openai/gpt-oss-20b`. If the classifier fails, the message is treated as a crisis ([#50](https://github.com/WGuillenDev/marlix/pull/50)).
- Help resources in `api/config/crisis.json` and the public `GET /v1/help-resources` endpoint ([#52](https://github.com/WGuillenDev/marlix/pull/52)).
- Review of the model's reply, which replaces a reply that encourages harm or dependency with a safe one ([#54](https://github.com/WGuillenDev/marlix/pull/54)).
- Log of crisis filter activations without any of the message: not the text, a hash or its length ([#56](https://github.com/WGuillenDev/marlix/pull/56)).
- Per-person usage limits from `api/config/plans.json` (100 replies a day and 5 messages a minute) and `GET /v1/usage` ([#58](https://github.com/WGuillenDev/marlix/pull/58)).
- Crisis filter test suite with 61 invented messages and a report of false negatives and false positives. `npm run crisis:eval` measures the whole filter with the real classifier ([#60](https://github.com/WGuillenDev/marlix/pull/60)).

### Fixed

- "me kiero matar" passed the filter as normal: *k* and *q* typed for *qu* are now normalized ([#60](https://github.com/WGuillenDev/marlix/pull/60)).
- The classifier answered the same message differently between runs. It now runs at temperature 0 ([#60](https://github.com/WGuillenDev/marlix/pull/60)).

### Security

- Continuous integration on every pull request: type check, tests and build of the backend, and the database privilege and RLS tests. The `main` ruleset requires both checks before a merge ([#62](https://github.com/WGuillenDev/marlix/pull/62), [#70](https://github.com/WGuillenDev/marlix/pull/70)).
- HTTP security headers on every response (HSTS, `nosniff`, `no-referrer` and a CSP that blocks everything) and `Cache-Control: no-store` on `/v1` ([#64](https://github.com/WGuillenDev/marlix/pull/64)).
- Dependabot version updates for npm, Docker Compose and GitHub Actions, tested by the CI before each merge ([#66](https://github.com/WGuillenDev/marlix/pull/66), [#67](https://github.com/WGuillenDev/marlix/pull/67), [#68](https://github.com/WGuillenDev/marlix/pull/68)).

## Sprint 1 — Backend base (2026-10-03 to 2026-10-13)

The avatar answers: the backend runs on Render, private behind a development token until the crisis filter exists.

### Added

- Backend in `api/` with Node, TypeScript and Express, and the public `GET /health` endpoint ([#30](https://github.com/WGuillenDev/marlix/pull/30)).
- Environment variables validated with zod at startup; the server does not start with a missing variable ([#38](https://github.com/WGuillenDev/marlix/pull/38)).
- LLM provider abstraction layer, so Groq can be replaced without rewriting the backend ([#39](https://github.com/WGuillenDev/marlix/pull/39)).
- Groq adapter on the OpenAI SDK, which waits the time Groq asks for after a quota error ([#40](https://github.com/WGuillenDev/marlix/pull/40)).
- `POST /v1/chat` with the personality system prompt ([#41](https://github.com/WGuillenDev/marlix/pull/41)).
- Central error handling, a configurable LLM timeout and one retry for transient errors ([#42](https://github.com/WGuillenDev/marlix/pull/42)).
- Deployment on Render from a Blueprint (`render.yaml`), with automatic deploys from `main` ([#43](https://github.com/WGuillenDev/marlix/pull/43)).
- Automated tests for the backend (`npm test`) and for database privileges and RLS (`docs/schema-test.sql`) ([#38](https://github.com/WGuillenDev/marlix/pull/38) to [#44](https://github.com/WGuillenDev/marlix/pull/44)).

### Security

- `/v1` requires a development token until the crisis filter is ready ([#43](https://github.com/WGuillenDev/marlix/pull/43)).
- Least privilege for the `anon` and `authenticated` database roles, and functions no longer executable by them ([#44](https://github.com/WGuillenDev/marlix/pull/44)).
- Account deletion requires a recent sign-in in the API contract ([#44](https://github.com/WGuillenDev/marlix/pull/44)).
- pgAdmin image pinned to an exact version ([#44](https://github.com/WGuillenDev/marlix/pull/44)).
- Groq API keys rotated, with separate keys for development and production.

## Sprint 0 — Design (2026-09-26 to 2026-09-30)

Design before code: every v1 decision is documented and the repository is ready to build on.

### Added

- Repository, base structure, MIT license, contribution guide and issue template ([#2](https://github.com/WGuillenDev/marlix/pull/2)).
- Pull request template; labels and `main` branch protection configured on GitHub ([#13](https://github.com/WGuillenDev/marlix/pull/13)).
- v1 user stories with acceptance criteria and traceability to the backlog ([#14](https://github.com/WGuillenDev/marlix/pull/14)).
- Use case diagram ([#15](https://github.com/WGuillenDev/marlix/pull/15)).
- Wireframes, navigation flow and visual style, exported from Figma ([#16](https://github.com/WGuillenDev/marlix/pull/16)).
- Security policy, private vulnerability reporting and Dependabot ([#18](https://github.com/WGuillenDev/marlix/pull/18)).
- Entity-relationship diagram and SQL schema with strict RLS ([#19](https://github.com/WGuillenDev/marlix/pull/19)).
- Architecture diagram ([#20](https://github.com/WGuillenDev/marlix/pull/20)).
- Groq data policy review and LLM model decision; Zero Data Retention enabled on the account ([#21](https://github.com/WGuillenDev/marlix/pull/21)).
- Sequence diagram for sending a chat message ([#22](https://github.com/WGuillenDev/marlix/pull/22)).
- v1 API contract ([#23](https://github.com/WGuillenDev/marlix/pull/23)).
- marlix personality system prompt, tested with 10 sample conversations ([#24](https://github.com/WGuillenDev/marlix/pull/24)).
- Local database with Docker Compose and pgAdmin ([#26](https://github.com/WGuillenDev/marlix/pull/26)).
- Documentation index in the README and this changelog.
