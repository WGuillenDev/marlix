# Changelog

Notable changes to marlix, one entry per sprint. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Sprint 3 — Chat app: talking to marlix from the phone.

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
