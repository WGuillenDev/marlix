# Changelog

Notable changes to marlix, one entry per sprint. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Sprint 2 — Security: nobody in crisis is left without help.

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
