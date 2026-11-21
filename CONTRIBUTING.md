# Contributing to marlix

## Non-negotiable rules

1. **The Flutter app never calls the LLM.** Only the backend holds the API key.
2. **Every table has RLS enabled** with its policy.
3. **Chat content never goes to logs.**
4. **The crisis filter runs before the model.** A message with a clear risk signal never leaves the backend; an ambiguous one only goes to an isolated classification (no history, no memory), never to the conversation. When in doubt, trigger the crisis protocol.

The repository is public: no secrets or real user data in it, ever.

## Workflow

1. Start at [`status.md`](status.md) and follow the [current workflow](docs/workflow.md). Before C10, v0.2 tasks are the V2-NN entries of the [approved design](docs/designs/marlix-v0-2.md#work-order), and each pull request states the acceptance criteria it closes with evidence. Use existing GitHub issues to track their fixes.
2. Create a branch from `main`: `<type>/<short-description>`, lowercase with hyphens. The maintainer's own work goes through the permanent `wil` branch instead ([Branches](docs/workflow.md#branches-main-and-wil)).
3. Make small commits, one coherent change each.
4. Open a pull request into `main` using the [template](.github/pull_request_template.md): work item and Sprint Goal, why, what changed, acceptance criteria with evidence, verification, risks and follow-ups. Include `Closes #N` only when the change fully resolves a GitHub issue.
5. Wait for the CI checks to pass and review your own PR against the Definition of Done before merging.
6. Squash merge into `main`. Delete topic branches after merging; `wil` is kept and prepared for the next item.

`main` must always build and run. It only receives changes through pull requests, and GitHub blocks the merge until the [CI](.github/workflows/ci.yml) passes: the backend's type check, tests and build, the app's format check, analysis and tests, and the database privilege and RLS tests.

## Database migrations

A change to the database is a file in [`docs/migrations/`](docs/migrations/) named `YYYY-MM-DD-what-it-does.sql`, written to run once, in a transaction, and mirrored in [`docs/schema.sql`](docs/schema.sql). Production does not apply it by itself: Render deploys the backend, but nothing runs the SQL. A backend that needs a function or column the database lacks keeps answering and fails quietly (that is how the daily cap went unenforced until S6-16).

1. Add the checks of the new migration to [`docs/verify-migrations.sql`](docs/verify-migrations.sql), in the same pull request. The CI runs it against `schema.sql` and fails if anything is `MISSING`.
2. **Before merging** a pull request with a migration, open the Supabase project's [SQL Editor](https://supabase.com/dashboard/project/_/sql/new) and run the migration file. If the backend needs it, this must happen before the deploy.
3. In the same editor, run `docs/verify-migrations.sql`. Every row must say `ok`; a `MISSING` row names the migration that was not applied.
4. Merge. After the deploy, `GET /health` must answer `{"status": "ok"}`; `"degraded"` with `usage_counter` means the backend cannot count replies, which is what a missing `record_interaction` looks like.

## Branches

| Type | Use | Example |
|---|---|---|
| `feature/` | New functionality | `feature/chat-endpoint` |
| `fix/` | Bug fix | `fix/llm-timeout` |
| `docs/` | Documentation only (also spikes) | `docs/api-contract` |
| `chore/` | Configuration, dependencies | `chore/setup-typescript` |
| `test/` | Automated tests only | `test/crisis-filter` |

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), in English, imperative mood, no trailing period. Use `type(scope): subject` when a scope adds clarity (`api`, `app`, `db`, `site`, `infra`, `ci`) and `type: subject` otherwise:

~~~
feat: add POST /chat endpoint
fix: handle LLM timeout
docs: document the API contract
chore: install express and typescript
~~~

The commit type describes that specific change, not the whole task. If a commit message needs the word "and", it is probably two commits. Commit messages and pull request descriptions carry no automatic AI attribution lines ([No AI attribution](docs/workflow.md#no-ai-attribution)); human co-authors are credited as usual.

## Language and naming

- Everything in the repository is in English: code, docs, commits, branches, issues. Only in-app copy is in Spanish.
- The project name is always written `marlix` (lowercase, no accent).

## Definition of Done

- [ ] Acceptance criteria are met
- [ ] Code runs without console errors
- [ ] Manually tested following the issue steps
- [ ] No keys or secrets in the code
- [ ] Variable and function names are self-explanatory
- [ ] If the API contract changed, the contract file is updated
- [ ] If the database changed, the ERD and migration are updated
- [ ] The README is still accurate
- [ ] A topic branch was deleted after merging (`wil` is kept)

## Never commit

`.env` files, API keys, `node_modules/`, database volumes, or real user data (including screenshots of real conversations).
