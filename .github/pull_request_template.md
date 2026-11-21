<!--
Title: Conventional Commits in English, for example `fix: handle LLM timeout`.
Maintainer pull requests go from `wil` to `main`. Keep the body short.
Add `Closes #N` only if this pull request fully resolves an existing issue.
No AI attribution lines in the body or in the commit messages.
Evidence must be safe to publish: no credentials, connection strings, account or project IDs,
email addresses, private links, console screenshots or raw logs with internal data.
-->

## Work Item & Sprint Goal
- Item: V2-NN or #N, with a link
- Sprint Goal: how this item serves it
- Story points: original estimate, or "not estimated"

## Why
The problem and the expected result.

## What Changed
- Main changes and their scope. What is out of scope.

## Acceptance Criteria
- [ ] 1. Criterion — evidence: test name, command and result, screenshot or log
- [ ] 2. Criterion — still to verify: what and how

## Verification
- Commands run and their results (`npm run typecheck`, `npm test`, `npm run build` in `api/`; `flutter analyze`, `flutter test` in `app/`)
- Device or staging checks, with links to screenshots or logs
- How to reproduce
- CI on the last pushed commit: passed / failed / pending, with a link

## Risks & Follow-ups
- Risks, pending work, and the post-merge checks that apply (CI of `main`, `GET /health` after a backend deploy, `docs/verify-migrations.sql` after a migration). Write "None" if there are none.

<!--
Definition of Done: criteria met with evidence; no console errors; no keys or secrets;
`docs/api-contract.md` updated if an endpoint changed; ERD, schema and migration updated if the database changed;
spend ledger and budget updated if a model call changed; `status.md` written as it will read after the merge;
the README still accurate.
-->
