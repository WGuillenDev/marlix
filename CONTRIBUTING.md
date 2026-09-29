# Contributing to marlix

## Non-negotiable rules

1. **The Flutter app never calls the LLM.** Only the backend holds the API key.
2. **Every table has RLS enabled** with its policy.
3. **Chat content never goes to logs.**
4. **The crisis filter runs before the model.** A message with a clear risk signal never leaves the backend; an ambiguous one only goes to an isolated classification (no history, no memory), never to the conversation. When in doubt, trigger the crisis protocol.

The repository is public: no secrets or real user data in it, ever.

## Workflow

1. Every change starts from an issue. The issue title begins with the card ID (e.g. `S1-5 POST /chat endpoint`).
2. Create a branch from `main`: `<type>/<short-description>`, lowercase with hyphens.
3. Make small, frequent commits.
4. Open a pull request with `Closes #N` in the description.
5. Review your own PR against the Definition of Done before merging.
6. Merge into `main` and delete the branch.

`main` must always build and run. It only receives changes through pull requests.

## Branches

| Type | Use | Example |
|---|---|---|
| `feature/` | New functionality | `feature/chat-endpoint` |
| `fix/` | Bug fix | `fix/llm-timeout` |
| `docs/` | Documentation only (also spikes) | `docs/api-contract` |
| `chore/` | Configuration, dependencies | `chore/setup-typescript` |
| `test/` | Automated tests only | `test/crisis-filter` |

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), in English, present tense, no trailing period:

~~~
feat: add POST /chat endpoint
fix: handle LLM timeout
docs: document the API contract
chore: install express and typescript
~~~

The commit type describes that specific change, not the whole task. If a commit message needs the word "and", it is probably two commits.

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
- [ ] The branch was deleted after merging

## Never commit

`.env` files, API keys, `node_modules/`, database volumes, or real user data (including screenshots of real conversations).
