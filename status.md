# Marlix v0.2

**Release progress** `[░░░░░░░░░░]` **7%** · 2 of 28 launch tasks verified

**Requirements for release** 0 of 11 met · **Sala beta** 0 of 6 tasks verified

- Completed and verified: V2-01, V2-02
- Scope: 28 launch tasks. The Sala, experiments, and V2-04 are tracked separately.

## Milestones

| Milestone | Status | Done when |
| --- | --- | --- |
| Prepare the test environment (M0) | **In progress** | The Google Play path is defined and a backup is restored and tested in staging. |
| Build the technical foundations (M1) | Planned | Email, crisis detection, and spend controls meet launch criteria 3, 4, 5, and 11. |
| Deliver the v0.2 features (M3) | Planned | The features required for launch are verified. |
| Publish v0.2 (M5) | Planned | All 11 release requirements are met and v0.2 is live on Google Play. |

[Full milestone plan, including experiments and the Sala](docs/designs/marlix-v0-2.md#9-sequence-and-milestones)

## Active task

**[Prepare and verify staging (V2-05a)](docs/designs/marlix-v0-2.md#detailed-implementation-plan)**

- **Verified (2026-11-20):**
  - Supabase staging has its own project. Its migration checks returned `ok`.
  - Render `marlix-api-staging` returns `200 {"status":"ok"}` on `/health`. Auto-deploy is off. The first deploy failed only because three variables were empty.
  - CI passed for [PR #229](https://github.com/WGuillenDev/marlix/pull/229) and [PR #230](https://github.com/WGuillenDev/marlix/pull/230), which merged. `main` has the integration runner and the `.gitignore` rules.
  - `app/config/staging.json` is complete and Git ignores it. `node tool/verify-integration.mjs staging --check` passes.
  - The integration suite builds, installs, and starts on the `Pixel_8` emulator.
- **Failing:**
  - Criterion 4: the suite's sign-up fails with `AuthFailureException: unexpected`. Staging `/auth/v1/settings` shows `disable_signup: true`.
  - Criterion 5: [Staging keepalive](https://github.com/WGuillenDev/marlix/actions/runs/44865007387) fails with `Network is unreachable`. `STAGING_DATABASE_URL` is the direct connection, which is IPv6 only. GitHub runners have no IPv6.
- **To finish:**
  1. Owner: in Supabase staging, turn on **Allow new users to sign up** (Authentication → Sign In / Providers). Keep **Confirm email** off until the suite passes.
  2. Owner: replace the `STAGING_DATABASE_URL` secret with the staging [Session pooler connection](docs/backups.md#one-time-setup) on port 5432. Set it from a terminal.
- **Then, the assistant** (`/pstack:poteto-mode`, from this file): rerun **Staging keepalive** from `main` and confirm `select 1` passes. Start the `Pixel_8` emulator and run `node tool/verify-integration.mjs staging` from `app/`. If both pass: record the evidence here, move V2-05a to "Completed and verified", set the bar to **10%** · 3 of 28, tell the owner to turn **Confirm email** back on, and take V2-05b (restore drill against staging).
- **Notes:** If the debug build fails in `record_android` with `Unresolved reference 'PolicyAction'`, delete `app/build/record_android` and rebuild; it was a stale Kotlin cache. The local `app/pubspec.lock` differs only because Flutter 3.47.4 rewrote it (`test_api` and the SDK constraint); do not commit it.

## In review

No open PR for V2-05a. The documentation branch `docs/v0-2-status-layout` waits for a rebase onto `main`.

## Ready to start

After the active task is done, refresh this list before choosing the first task.

1. Show the crisis response when the API is unavailable (V2-37).
2. Update greetings and migrate reminders (V2-14).
3. Improve navigation, theme, first use, and accessibility (V2-15).
4. Add a reduced-motion setting (V2-16).

## Blocked

| Task | Waiting for | How it unblocks | Who | Recorded |
| --- | --- | --- | --- | --- |
| Test a backup restore in staging (V2-05b) | V2-05a | Close V2-05a after verification. | Owner and assistant | 2026-11-20 |
| Move Groq to the paid plan (V2-35) | Developer access and charge timing (C6(f)) | Recheck availability and confirm charge timing before paying. Gates on V2-10 and V2-12b also apply. | Owner and Groq | 2026-11-20 |

## Launch checklist

- [ ] 1. Closed test complete or confirmed unnecessary (C1)
- [ ] 2. Restore drill passed on a real project
- [ ] 3. Spend governor running in production
- [ ] 4. Classifier isolated and crisis evaluation passing
- [ ] 5. Own-domain sender verified
- [ ] 6. Launch features complete
- [ ] 7. Production build excludes the Sala
- [ ] 8. Privacy policy, data safety, and health declaration complete
- [ ] 9. v0.1 APKs still work
- [ ] 10. Checks pass and the release build has been tested
- [ ] 11. Paid Groq with ZDR and a spend limit

## Owner decisions

- **Launch:** C2 (treat 13% VAT as provisional until a Groq charge confirms it), C3, C6, and Q13.
- **Sala beta:** C8, Q15, Q16, Q18, and Q19.
- **Workflow:** C10, adoption of GitHub Issues and Projects.

## Later

- Play closed testing is in progress on `0.1.2+3`. App Signing is active. Play verified developer identity on 2026-11-05. Keep [issue #213](https://github.com/WGuillenDev/marlix/issues/213) open until publication.
- V2-34 checks Gmail SMTP and Groq Free capacity. The owner accepted the available C6 evidence. Usage is per model and in UTC. No export was visible, Free has no invoice history, and global and inference ZDR are on. V2-06a verifies an own-domain sender.
- V2-09 and V2-10 check charges for errors and aborted streams and verify `include_usage`. V2-35 rechecks a second organization and when Groq charges. Mixed billing is documented, and actual charge timing remains unconfirmed. Production health monitoring is active.
- Revisit [PR #221](https://github.com/WGuillenDev/marlix/pull/221) in V2-14 and issues #186–#188 in V2-15. Sign-up still completes in the reproduced #186 case.
- Review transcription alerts in V2-08, API rate limits before publication, and [the documentation layout](docs/designs/marlix-v0-2.md#101-where-each-kind-of-information-lives) separately.

Updated: 2026-11-20 · [Design](docs/designs/marlix-v0-2.md) · [Workflow](docs/workflow.md)
