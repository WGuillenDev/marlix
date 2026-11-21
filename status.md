# marlix status

Updated: 2026-11-20 · Board: none yet (C10 pending); tasks use their V2 ID · Milestone: M0 Unblock

Rules: [docs/workflow.md](docs/workflow.md) · Design: [docs/designs/marlix-v0-2.md](docs/designs/marlix-v0-2.md)

## Progress
v0.2 launch progress [░░░░░░░░░░] 3% (1 of 28 launch tasks complete)
Sala beta: 0 of 6 tasks complete (does not block the launch)
Scope: 28 launch tasks from docs/designs/marlix-v0-2.md (experiments and V2-04 not counted).
Completed and verified: V2-01
Launch criteria met: 0 of 11. Finished tasks are not the same as ready to publish.

## Active task
[V2-02 Verify the external conditions](docs/designs/marlix-v0-2.md#organization-and-verification-m0) · P0 · M0 · owner

- C1: closed testing is required and in progress on `0.1.2+3`. Play App Signing is active. Developer identity verification is pending; v0.2 is the planned first public release.
- C2: Costa Rica's general VAT rate on cross-border digital services is 13%. Keep `tax_multiplier = 1.13` provisional until the actual Groq charge is confirmed.
- C5: V2-34 verifies the current Gmail SMTP setup for the closed test. V2-06a provides a verified domain sender for launch.
- C6: owner accepted criterion 4 with available evidence. Groq Free shows usage per model in UTC; no export was visible and invoice history is unavailable on Free. Global and inference ZDR are enabled.
- C6 follow-up: V2-09/V2-10 test billing of errors and aborted streams and `include_usage`; V2-35 rechecks the second organization and charge timing. Groq documents mixed billing for new Developer accounts; actual timing unconfirmed.
- C11: production health monitoring is active. Criterion 7 met.

## Review
- [PR #224](https://github.com/WGuillenDev/marlix/pull/224): update against `main` and verify CI before the owner's merge.
- [PR #226](https://github.com/WGuillenDev/marlix/pull/226): replacement for [#223](https://github.com/WGuillenDev/marlix/pull/223) with account-deletion tests. Close #223 after #226 merges.

## Next up (Ready, in order)
1. V2-05a Staging environment · P0
2. V2-37 Crisis layer 1 on the phone · P0
3. V2-14 Greeting by local time and reminder migration · P1
4. V2-15 Navigation, theme, first use and accessibility · P1
5. V2-16 Reduced-motion setting · P1

## Blocked
- V2-35 — Cause: Groq Developer upgrade unavailable and charge timing unconfirmed.
  - Depends on: Developer access and C6(f).
  - Action to unblock: recheck upgrade availability and confirm billing timing before paying.
  - Who acts: owner and Groq.
  - Recorded on: 2026-11-20.
- Related gates remain in force for V2-10 and V2-12b. See [task dependencies](docs/designs/marlix-v0-2.md#work-order).

## Launch criteria still pending (11 of 11)
- [ ] 1 Closed test done or not required (C1)
- [ ] 2 Restore drill on a real project
- [ ] 3 Spend governor in production
- [ ] 4 Classifier isolated, crisis:eval green
- [ ] 5 Own-domain sender verified
- [ ] 6 Launch features done
- [ ] 7 Production build without the Sala
- [ ] 8 Privacy policy, data safety, health declaration
- [ ] 9 v0.1 APKs work
- [ ] 10 Checks green, release build tested
- [ ] 11 Groq paid with ZDR and spend limit

## Decisions waiting on the owner
- Launch: C1 (identity), C2 (Groq tax treatment), C3, C6, Q13
- Sala beta: C8, Q15, Q16, Q18, Q19
- Process: C10 (approve adopting GitHub Issues and Projects for the v0.2 backlog)

## Next step
Owner: confirm developer identity verification in Play Console. Record the result for V2-02, then take V2-05a once V2-02 is closed.

## Later
- V2-14: revisit [PR #221](https://github.com/WGuillenDev/marlix/pull/221) for notifications.
- V2-15: review issues #186–#188; #186 was reproduced and sign-up still completes.
- V2-08: review the related security findings. Review API rate limits before public launch.
- Keep issue #213 open until v0.2 is published.
- Review the existing documentation against the layout in [section 10.1](docs/designs/marlix-v0-2.md#101-where-each-kind-of-information-lives).
