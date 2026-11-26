# A0 evidence: Clean Architecture and DDD move

Local checks run on 2026-11-25. Result: **the candidate passes them. A0 is open**: the new API has not run in staging, and the candidate is not on `main` ([decision D12](../plans/next-release-execution-plan.md#decisions-that-need-the-owner)).

## Candidate

| Commit | Content |
| --- | --- |
| `c3099a3` | `refactor(api)`: the backend grouped by capability, with a dependency-direction test |
| `9390079` | `refactor(app)`: the app grouped by feature, with a dependency-direction test |
| The commit that adds this file | Documentation: new code paths, retired documents and the execution plan |

The base is `65a0594` (`origin/main`). The commits are on the local branch `release/next-release`.

## Checks

Node 24.21.0 and Flutter 3.47.4, the version CI uses.

| Check | Command | Result |
| --- | --- | --- |
| API types | `npm run typecheck` | Pass |
| API tests | `npm test` | 581 passed, 0 failed |
| API build | `npm run build` | Pass |
| App format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 146 files, 0 changed |
| App analysis | `flutter analyze` | No issues |
| App tests | `flutter test` | 437 passed |
| Release build | `flutter build apk --release --dart-define-from-file=config/staging.json` | Built |

## Behavior

- **API, old and new side by side.** A script booted the `65a0594` build and the candidate build with placeholder credentials and sent the same 19 requests to both (health, help resources, missing and forged tokens, invalid and oversized bodies, unknown routes, and the protected routes). Status, headers (without `date`, `etag` and connection headers) and bodies matched in all 19. Authenticated flows are not covered by this check.
- **Code comparison.** A script compared the code lines of the base and the candidate, ignoring imports and comments. The differences are in wiring and in logic that moved into use cases and domain files: session verification, account deletion, memory listing, extraction policy and transcription.
- **App against staging.** `node tool/verify-integration.mjs staging` on the `Pixel_8` emulator: 12 of 12 passed. The suite calls the API client and does not draw screens. The staging backend runs an earlier commit, so this checks the new app and not the new backend.
- **Release APK on the emulator.** It starts on the sign-in screen and opens the help screen. The log showed no Flutter error and no crash.

![Release build, sign-in screen](a0/release-sign-in.png)

![Release build, help screen](a0/release-help.png)

## Independent review

A reviewer that did not write the code compared both refactor commits with the base: session checks, the crisis path and its order, usage limits, deletion, data sent to providers, routes, startup wiring and app providers. It found **no blocking behavior change**. It ran the API type check and tests, not the Flutter tests.

Follow-ups it raised, none blocking:

- The app test that limits `package:http` now also allows `composition/` folders and `lib/bootstrap/`.
- The API dependency-direction test has no test of its own, and it checks neither `infrastructure/` layers nor imports between modules.

## Limits and pending

- The new backend has not run against a real database or model provider. That needs a deploy to staging or production.
- Voice mode, chat screens and signed-in screens were not driven by hand.
- `app/pubspec.lock` is not part of the candidate. With Flutter 3.47.4, resolving packages rewrites `test_api` from 0.7.14 to 0.7.12. The change comes from the toolchain, not from the move, and stays uncommitted.
- Seen on the two screens while checking, for Phase 1a to record: the copy mixes voseo with «quieras» and «necesitas» ([#187](https://github.com/WGuillenDev/marlix/issues/187)).
- CI has not run on these commits. It runs on pushes to `main` and on pull requests.

## Staging verification

Pending. The plan:

1. Deploy the exact candidate commit to `marlix-api-staging` and confirm the deployed SHA.
2. `GET /health` answers `ok`, and the unauthenticated requests of the side-by-side check answer as expected.
3. `node tool/verify-integration.mjs staging` passes on `Pixel_8`.
4. A staging-only script covers what the suite does not: onboarding, a streamed chat reply and transcription, with a throwaway account that it deletes.
5. The service logs show no error from the startup jobs (memory and retention).
