# Technical decisions

Every time the project picks between two technical options, the decision is recorded here: what was chosen, what was discarded and why. Newest first.

---

## 2026-10-17 — Chat history: saved by the backend through the Supabase API, paged with an opaque cursor (S4-4)

**Decision:** the backend saves every turn (the message and marlix's reply) in `messages` through `@supabase/supabase-js` with the secret key, and `GET /v1/history` returns it newest page first.

| Option | Verdict |
|---|---|
| `@supabase/supabase-js` with the secret key | **Chosen.** No connection string or pool to manage, nothing new to configure in Render (the secret key is already there), and it works from a free instance that sleeps. Because that key bypasses RLS, every query filters by `user_id` itself, and the tests check it. |
| `pg` with the database connection string | Discarded for now. It would need another secret and a connection pool; Supabase's pooler adds its own rules. |
| The app writes its own messages (RLS) | Discarded. The backend must be the only writer so the crisis filter and the daily cap cannot be skipped ([schema](schema.sql)). |

- **One insert per turn.** Both messages go in the same statement, so a turn is saved whole or not at all. The reply gets a later `created_at` than the message, so they never tie.
- **Cursor, not offset.** Pages are ordered by `(created_at, id)` descending and the cursor holds the position of the page's oldest message. A new message cannot shift a page that is being read, and the cursor is checked (timestamp and UUID format) before it goes into the query filter. It is opaque for the app.
- **A reply that cannot be saved is not delivered.** The history would miss a message the person has seen, and the daily count would not match. The answer is `500` and the app offers the retry it already has. **A crisis is the exception:** the 9-1-1 reply never waits on the database, so it is returned even if saving fails ([S0-8](#2026-09-30--chat-flow-crisis-filter-before-the-daily-cap-crisis-messages-kept-in-history-s0-8)).
- **Nothing of the content in logs.** The database's error text and details can quote the row being written, so the store logs only the error code and throws an error without a message.
- **Conversations.** A message belongs to the user's open conversation (`ended_at is null`), created on the first message. Closing it after inactivity belongs to S4-6, which needs it for the memory extraction. Two simultaneous first messages could open two conversations; that is harmless because the history is read by user, not by conversation, and the rate limit makes it very unlikely.
- **Usage counters** stay in memory until S4-13, a card created for this because the contract assigned it to S4-4 but its criteria did not include it.

---

## 2026-10-15 — Accounts: 18 or older, no email confirmation yet, sessions checked with the project's public keys (S4-3)

**Decision:** people sign up in the app with email, password and birth date, against Supabase Auth. The backend checks the Supabase session on every `/v1` request, and the development token of S1-7 (`DEV_ACCESS_TOKEN`) is gone from the backend, the app and Render.

**Minimum age: 18** (decided by the user on 2026-10-15). marlix accompanies people through emotional topics and has a crisis protocol, and in Costa Rica the data of minors needs the consent of a responsible adult (Ley 8968), a flow v1 does not have.

| Option | Result |
|---|---|
| 18 or older, checked in the app and in the database | **Chosen.** The app explains it under the field; the sign-up trigger (`handle_new_auth_user`) refuses a missing, malformed or too recent birth date, so no client can skip it. Ages are counted on the Costa Rica calendar, like the daily limit. |
| 13 or older | Discarded. It needs parental consent and a system prompt reviewed for minors. |
| Store the date, decide later | Discarded. Minors could sign up meanwhile. |

The birth date is stored, not the age, so the policy can change later with one constant in the trigger and one in the app (`minimumAge`). The app sends it as user metadata (`birth_date`, `YYYY-MM-DD`) and the trigger copies it to `users.birth_date`, which the app cannot change afterwards (no column grant).

**No email confirmation for now** (decided by the user on 2026-10-15). "Confirm email" is off in Supabase, so a new account is signed in at once.

| Option | Result |
|---|---|
| No confirmation until S7-9 | **Chosen.** Supabase's free email service sends about 2 emails an hour, and its default link opens a browser. S7-9 adds a 6-digit code typed in the app, a real SMTP and password recovery. |
| 6-digit code now | Postponed to S7-9. It needs an SMTP service and email templates, beyond this card. |
| Confirmation link | Discarded. It needs deep links and is still limited to about 2 emails an hour. |

Until then, someone could sign up with an email that is not theirs; the account only reaches its own data. Signing up with an email that has an account says so, a small leak accepted because sign-up without confirmation cannot hide it; signing in never tells a wrong password from an unknown email (US-01).

**Session check in the backend:**

| Option | Result |
|---|---|
| Verify the token with the project's public keys (JWKS), with [`jose`](https://github.com/panva/jose) | **Chosen.** The project signs tokens with ES256 keys; their public half is at `/auth/v1/.well-known/jwks.json`. The keys are kept in memory, so a message does not wait for a call to Supabase. Checked: signature (ES256 or RS256 only, never HS256 or `none`), expiry, issuer, audience and `role: authenticated`, so the anon key is not a session. |
| Ask Supabase for the user on every request (`auth.getUser`) | Discarded. One more network call per message, and the chat depends on Supabase being reachable. |
| Shared JWT secret (HS256) | Discarded. Supabase's legacy method; the secret would be one more key to protect in Render. |

A token stays valid until it expires (one hour) even after signing out on the phone; the app forgets it at once. If the keys cannot be fetched the answer is `500`, not `401`, so the app does not sign anyone out because of a Supabase outage.

**The session on the phone:** Supabase keeps it in SharedPreferences by default, in plain text. The app stores it with `flutter_secure_storage` instead, encrypted with a key from the Android Keystore; backups already exclude it (S4-11). The app reads the current token on every request, because Supabase refreshes it in the background. If the backend still answers `401`, the session really ended: the app signs out and the sign-in screen says why.

---

## 2026-10-15 — The app's data never leaves the phone in a backup (S4-11)

**Decision:** the app opts out of every Android backup and transfer: `android:allowBackup="false"`, plus rules that exclude every data domain for Android 12 and later (`dataExtractionRules`, in both `<cloud-backup>` and `<device-transfer>`) and for Android 11 and earlier (`fullBackupContent`).

| Option | Result |
|---|---|
| No backup at all | **Chosen.** From S4-3 the phone keeps the person's session. A copy in a Google backup or on another phone would outlive a sign-out or a password change, and `adb backup` could extract it. Losing it is cheap: the person signs in again and the conversation is on the server. |
| Android's default (back up everything) | Discarded (it was the state until S4-11). |
| `allowBackup="false"` only | Discarded. [Android's docs](https://developer.android.com/identity/data/autobackup) say that on Android 12+ some manufacturers still run device-to-device transfers with it, so explicit rules are needed. |

Checked in the release APK with `aapt2 dump xmltree`: the manifest has the three attributes and the packaged rules exclude every domain. Done before S4-3 on purpose, so no session ever reaches a backup.

---

## 2026-10-15 — Docker images pinned by tag and digest (S3-7)

**Decision:** the two `docker-compose.yml` images are written as `tag@sha256:digest`: `supabase/postgres:17.11.0.003@sha256:7374d1…` and `dpage/pgadmin4:9.18.0@sha256:c332c5…`.

| Option | Result |
|---|---|
| Tag and digest | **Chosen.** The digest guarantees the exact image: a tag can be republished with other content, a digest cannot. The tag keeps the line readable and lets Dependabot know the version, so it proposes new versions and updates both parts in the same PR. |
| Tag only | Discarded (it was the state until S3-7). The CI and the local database would run whatever the tag points to that day. |
| Digest only | Discarded. Nobody can tell the version from the line, and Dependabot cannot compare versions. |

Each digest is the **multi-platform index** (amd64 and arm64), checked with `docker buildx imagetools inspect`, so the same line works on any developer's machine and on the CI. The CI's Database job reads the image from this file (S2-11), so it runs the pinned digest too.

---

## 2026-10-15 — Help screen: dialer, offline list and 9-1-1 always present (S3-5)

**Dialing:** every help button opens the phone's dialer with the number loaded (`tel:` with `url_launcher`). The app never places the call itself and does not ask for the call permission: the person confirms on the dialer. If the device cannot dial, the app says which number to dial.

**Offline (US-15):** the help screen must work without internet.

| Option | Result |
|---|---|
| Last `GET /v1/help-resources` list in `shared_preferences`, plus 9-1-1 in the app | **Chosen.** The numbers still come from configuration (`api/config/crisis.json`), so a change needs no new build; the phone keeps the last list it saw, refreshed every time the chat opens. 9-1-1 is in the code as the one exception, so the screen is never empty, even on a first launch without connection. |
| Whole list in the app | Discarded. A changed number would need a new APK on every family phone, and the contract says the list lives in configuration. |
| Only what the backend answers | Discarded. Without internet the screen would be empty, exactly when it may matter most. |

**Always one tap away:** a help button (lifebuoy) in the chat header opens the screen, and so do the crisis card ("Ver más ayuda") and the daily limit card ("La ayuda sigue disponible"). The crisis card dials the primary line directly.

---

## 2026-10-15 — Chat states: a failed message stays in place with a retry (S3-4)

**Decision:** when sending fails, the message stays in the chat with a red border, the reason and a **Reintentar** button (wireframe 03b), and the retry sends it again in the same place.

| Option | Result |
|---|---|
| Failed message in place, with retry | **Chosen.** The text is never lost, the user sees which message failed and why, and one tap sends it again. It is how most messaging apps behave. |
| Put the text back in the field | Discarded (it was the temporary behavior of S3-3). The message disappears from the conversation, and a second failed message would overwrite the first. |

- **Each typed error has its own copy:** no connection, timeout, model unavailable, too many messages (with the seconds from `Retry-After`), daily limit and unexpected error. A message that hit the daily limit cannot be retried until the reset.
- **Daily limit (wireframe 03d):** a card says the messages renew at midnight, the help is still available and the composer is locked. It also appears when a reply uses the last message or the chat opens with none left, and it lifts by itself once `resetsAt` passes.
- **Crisis (wireframe 03c):** a card with a red accent, the backend's fixed text and the help lines, the primary one first. The dial buttons are S3-5.
- **Waking up (wireframe 03b):** if a reply takes more than 5 seconds, a banner explains that marlix is waking up; the free Render plan sleeps after 15 minutes.
- The wireframe's offline banner promises that messages "will be sent when the connection is back". That needs an offline queue, which is out of scope, so the failed message and its retry cover the offline case.

---

## 2026-10-15 — Chat screen: fonts bundled with the app, prototype avatar, scope against the wireframe (S3-3)

**Fonts bundled, not fetched.** Nunito (UI and chat) and Baloo 2 (titles), the style guide's fonts, are in `app/assets/fonts/` with their OFL licenses.

| Option | Result |
|---|---|
| Bundled TTF files | **Chosen.** The app shows the right type from the first frame, offline too, and sends no request to Google when it opens. About 1.3 MB for six weights. |
| `google_fonts` fetching at runtime | Discarded. Every first launch would contact Google's servers, and the chat would show a fallback font without connection. |

**Header avatar:** a crop of the S0-5 prototype (`app/assets/avatar/marlix.png`) until the final artwork and the animated widget (S5-1).

**Against the wireframe (03a):** bubbles, header, remaining messages chip, typing indicator and composer follow it. Left out on purpose, each for the card that makes it work: date groups (there is no history until S4-4), the help button (S3-5), the settings button (its own card) and the voice button (Sprint 6). A button that does nothing is worse than no button.

The message list is reversed, so it stays anchored to the newest message when the keyboard opens or a reply arrives.

---

## 2026-10-15 — App API service: `package:http`, typed errors, development token from an ignored file (S3-2)

**Decision:** `lib/services/marlix_api.dart` is the only code that talks to the backend, on `package:http`. It covers the endpoints the backend has today (`/health`, `/v1/help-resources`, `/v1/chat`, `/v1/usage`); each endpoint built in Sprint 4 adds its method in its own card (decided by the user on 2026-10-15).

| Option | Result |
|---|---|
| `package:http` | **Chosen.** Maintained by the Dart team, small, and `MockClient` replaces the network in tests without extra packages. Four JSON endpoints do not need more. |
| `dio` | Discarded. Interceptors and cancellation are not needed yet, and it is a larger third-party dependency to keep up to date. |

- **Typed errors:** every failure is an `ApiException` subtype (`NetworkException`, `ApiTimeoutException`, `InvalidResponseException`, or one per contract error code, such as `DailyLimitReachedException` with `resetsAt` and `RateLimitedException` with `Retry-After`). A crisis is a `CrisisReply`, not an error, as in the contract.
- **Timeout of 75 seconds:** the free Render plan takes up to a minute to wake up.
- **Development token:** until S4-3, `/v1/chat` and `/v1/usage` need `DEV_ACCESS_TOKEN`. The app reads it from `config/dev-token.json`, ignored by Git and passed with a second `--dart-define-from-file`, so it never enters the repository (decided by the user on 2026-10-15). It is removed with the real accounts. Since S4-12 a release build never reads the token's value, so it is not compiled into the APK, and it refuses to start if the file was passed.
- A test fails if any file outside `lib/services/` imports `package:http`, or if the app's code or config contains something that looks like an API key.

---

## 2026-10-15 — App foundations: Riverpod, backend URL per environment, emulator (S3-1)

**State management: Riverpod** (`flutter_riverpod`), without code generation.

| Option | Result |
|---|---|
| Riverpod | **Chosen.** Providers are declared once and can be replaced in tests (`overrideWithValue`) without a widget tree around them. It handles the async states the chat needs (loading, error, retry) and catches a missing provider at compile time. |
| Provider | Discarded. Simpler, but its own author recommends Riverpod for new projects, and it depends on the widget tree for everything. |
| Bloc | Discarded. Solid, but every feature needs events, states and a bloc: a lot of ceremony for an app built by one person. |
| `setState` only | Discarded. The chat state (messages, sending, limits) is shared by several widgets. |

Code generation (`riverpod_generator`) is left out for now: it adds `build_runner` to every change. It can be added later without rewriting the providers.

**Backend URL per environment:** it is compiled in with `--dart-define-from-file=config/<environment>.json` and read with `String.fromEnvironment`. `config/production.json` is in Git; `config/local.json` is per developer and ignored. The app validates the URL at startup. Plain `http` is accepted only in debug builds, and Android allows cleartext only to `10.0.2.2` and `localhost` in debug builds (`android/app/src/debug/res/xml/network_security_config.xml`).

**Development device: the Android Studio emulator** (decided 2026-10-15 by the user), so no physical phone is needed. It uses 2 to 4 GB of RAM; a phone over USB works the same way.

**Application id:** `io.github.wguillendev.marlix`. The project has no domain of its own, and the GitHub namespace is unique and owned by the author. It cannot change once the APK is installed on family phones without reinstalling.

---

## 2026-10-14 — HTTP security headers: a small middleware of our own, not helmet (S2-9)

**Decision:** the security headers come from a middleware of a few lines (`api/src/middleware/security-headers.ts`), not from `helmet`.

| Header | Value | Where |
|---|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Every response |
| `X-Content-Type-Options` | `nosniff` | Every response |
| `Referrer-Policy` | `no-referrer` | Every response |
| `Content-Security-Policy` | `default-src 'none'; frame-ancestors 'none'` | Every response |
| `Cache-Control` | `no-store` | Everything under `/v1` |

| Option | Result |
|---|---|
| Own middleware | **Chosen.** The API only returns JSON to a mobile app, so five fixed headers cover it. The values are visible in one file and need no dependency. |
| `helmet` | Discarded. Well maintained and the usual choice for Express, but it sets about a dozen headers meant for web pages (frames, cross-origin isolation, DNS prefetch) that a JSON API does not use, and adds a dependency to keep up to date. |

`Cache-Control: no-store` covers `/v1/help-resources` too: the app keeps its own copy of the resources (US-15), so no HTTP cache is needed. CORS stays off, because the mobile app does not need it.

---

## 2026-10-14 — The development token stays until accounts exist (S2-6)

**Decision:** the development token of S1-7 (`DEV_ACCESS_TOKEN`) stays on `/v1/chat` until the Supabase session check of S4-3 replaces it. The S2-1 card planned to remove it once the crisis filter and the crisis reply were done (S2-1, S2-3).

**Why:** without accounts there is no way to tell people apart, so the per-user limits of S2-6 can only apply to whoever holds the token. A public chat would let anyone who finds the URL use up Groq's shared quota (1,000 requests a day for the whole account) and leave the family without the avatar. The crisis filter being ready made the chat safe to answer; it did not make it safe to open.

The public endpoints are unchanged: `GET /health` and `GET /v1/help-resources`.

---

## 2026-10-14 — Usage limits: configuration file and in-memory counters until Sprint 4 (S2-6)

**Decision:** the caps per plan live in [`api/config/plans.json`](../api/config/plans.json) and the counters in memory. In Sprint 4, when the backend uses the database, they move to the `plan_limits` and `daily_usage` tables of the [schema](schema.sql).

| Limit | `personal` plan | Answer when reached |
|---|---|---|
| Daily | 100 successful replies per day, resetting at midnight Costa Rica time | `429 DAILY_LIMIT_REACHED` with `details.resetsAt` |
| Rate | 5 messages to the model per 60 seconds | `429 RATE_LIMITED` with `Retry-After` |

- **Crisis first:** the crisis filter runs before the limits, so a crisis is always answered, even at the cap, and is not counted (decided in S0-8).
- **Only successful replies count** against the daily cap. Every message that reaches the model takes a slot of the rate window, even if the model then fails, so a loop against a failing model is also stopped.
- **In memory, for now:** a restart or deploy resets the counters. That can only give someone more room, never less, and the Groq quota still caps the account. The free Render service also sleeps after 15 minutes without traffic, which resets them too.
- **No redeploy to change a cap** is only true once the caps are read from the `plan_limits` table (Sprint 4). Until then, a cap changes by editing `plans.json` and deploying.
- An unknown plan gets the `personal` limits, never no limit.

---

## 2026-10-14 — Crisis classifier: `openai/gpt-oss-20b` with a policy prompt (S2-2)

**Decision:** the second layer of the crisis filter classifies ambiguous messages with `openai/gpt-oss-20b` on Groq's free plan and a policy prompt of our own that answers `RISK` or `SAFE`. The model is the `CRISIS_CLASSIFIER_MODEL` environment variable.

| Option | Result |
|---|---|
| `openai/gpt-oss-safeguard-20b` | Discarded. It is built to follow a custom safety policy, as the card suggested, but the free plan allows only **3 requests per minute** (confirmed in the response of a test call on 2026-10-14). Every classification over that limit would fail and count as a crisis. |
| `meta-llama/llama-prompt-guard-2` | Discarded. It detects prompt injection and jailbreaks, not risk of self-harm. |
| `openai/gpt-oss-20b` | **Chosen.** 30 requests per minute and a quota separate from the chat model (`gpt-oss-120b`), so classifying does not slow down conversations. |
| Same model as the chat | Discarded. It would share the conversation's 8,000 tokens per minute. |

**Evaluation (2026-10-14):** 12 ambiguous Spanish messages, half risk and half harmless (figurative expressions, grief for someone else, everyday frustration). With the first version of the policy it got 10/12: it missed hopelessness with a stated reason ("nada tiene sentido desde que perdí el trabajo"). After adding those examples to the policy, **12/12**, in 0.3 to 0.8 seconds. The same set is in `npm run crisis:eval`; the full test set comes in S2-7.

Any answer other than an exact `SAFE`, an error or a timeout counts as a crisis.

**Update (S2-7):** the full test suite later found that the classifier could give different answers to the same message ("nada tiene sentido desde que perdí el trabajo" passed once as safe). It is now called with **temperature 0**. With that, the 61 cases of the suite gave 0 false negatives and 0 false positives in two runs in a row.

---

## 2026-10-13 — Deployment: Render Blueprint, and a development token until the crisis filter exists (S1-7)

**Decision:** the backend is deployed on Render's free plan from a `render.yaml` Blueprint at the repository root, with `rootDir: api`. Until the crisis filter is done (S2-1, S2-3), every `/v1` request needs a development token in `Authorization: Bearer <token>`.

| Option | Result |
|---|---|
| Blueprint (`render.yaml`) | **Chosen.** The service configuration is versioned and reviewed in pull requests like the code. Secrets stay out of it: `GROQ_API_KEY` is entered in the dashboard (`sync: false`) and `DEV_ACCESS_TOKEN` is generated by Render. |
| Service configured by hand in the dashboard | Discarded: the configuration would live only in Render, invisible in the repository. |

**Why the token:** the non-negotiable rule says the crisis filter runs before the model. A public `/v1/chat` without the filter would break it, so the endpoint stays private. The token uses the same header as the real auth will (S4-3), is compared in constant time, and is at least 32 characters. It is never shared. It is removed, or replaced by the Supabase session check, once the filter is ready.

**Region:** Virginia, the closest to Costa Rica. The free plan sleeps the service after about 15 minutes without traffic; the S7-6 monitor will keep it awake.

**Update 2026-10-15 (S3-6):** auto-deploy changed from `commit` to `checksPass`. Render now waits for the GitHub checks of each commit on `main` (the CI's API and Database jobs) and skips the deploy if any fails. The ruleset already blocks merging a PR with a failed check, but two PRs that pass separately can still break `main` together; this keeps such a commit out of production. Deploying from GitHub Actions was not chosen: it would need a Render API key as a repository secret for no extra safety.

---

## 2026-10-14 — The database image comes from Docker Hub, and the CI reads it from docker-compose.yml (S2-11)

**Decision:** `docker-compose.yml` uses `supabase/postgres` from Docker Hub instead of `public.ecr.aws/supabase/postgres`: the same image, published by Supabase with the same tags. The CI's Database job reads the image from `docker-compose.yml` instead of writing its own tag.

ECR Public rejected the anonymous pulls of GitHub's shared runners (`toomanyrequests`), so the CI had moved to Docker Hub with a tag of its own. That left two versions in the repository: when Dependabot bumped `docker-compose.yml`, the CI still tested the old image. With a single line, the version Dependabot proposes is the one the CI tests, and local development keeps using the same image as the CI.

---

## 2026-09-30 — Local database: Docker Compose with Supabase's Postgres image (S0-13)

**Decision:** the local database runs with `docker compose` from [`docker-compose.yml`](../docker-compose.yml): the `supabase/postgres` image (from ECR Public until S2-11, now from Docker Hub) plus pgAdmin. On the first start it applies `docs/schema.sql` automatically.

Supabase's own Postgres image already includes the `auth` schema (`auth.users`, `auth.uid()`) and the `anon`, `authenticated` and `service_role` roles, so the schema runs as it does in production. Production stays on Supabase cloud.

| Option | Result |
|---|---|
| Docker Compose with `supabase/postgres` + pgAdmin | **Chosen.** A short, readable `docker-compose.yml`, the standard Docker workflow, and the same database image as production. |
| Supabase CLI (`supabase start`) | Discarded. It runs the full stack in Docker, but it is configured with `config.toml`, not a compose file, and hides the containers behind the CLI. |
| Supabase self-hosted `docker-compose.yml` | Discarded. About a dozen services and secrets to generate and maintain; meant for self-hosting in production. |
| Plain `postgres` image + pgAdmin | Discarded. It lacks the `auth` schema and roles; they would have to be faked. |

**Known difference:** the image ships the base version of `auth.uid()`, which reads the user from the `request.jwt.claim.sub` setting. On Supabase cloud, the Auth service also reads it from `request.jwt.claims`. Policies behave the same; only the way a manual test impersonates a user changes. The Auth service (sign-up and sign-in) is not part of the local environment yet; it can be added to the compose file when the backend needs it (S4-3).

---

## 2026-09-30 — Chat flow: crisis filter before the daily cap, crisis messages kept in history (S0-8)

**Decision 1: the crisis filter runs even when the daily cap is reached.** The backend reads the usage before the filter, but only applies a reached cap to messages without risk. Crisis replies do not count against the cap.

- *Discarded:* rejecting every message once the cap is reached. A person in crisis would get "limit reached" instead of the 9-1-1 reply.

**Decision 2: crisis messages are saved in the user's own history,** together with the fixed reply. They are protected by RLS and the 90-day retention, and never go to Groq or to the logs. The activation log (S2-5) still has no content.

- *Discarded:* not saving them. It is slightly more private, but the user would come back to a chat without what they wrote or the help they got.

Full flow: [chat sequence diagram](diagrams/chat-sequence.md).

---

## 2026-09-30 — LLM provider: Groq free plan with `openai/gpt-oss-120b` (S0-11)

**Decision:** the conversation runs on Groq's free plan with the model `openai/gpt-oss-120b`, called with low reasoning effort. The model name lives in the `GROQ_MODEL` environment variable, never in code.

### Data policy review

marlix sends emotional conversations and the user's distilled memory to the provider on every call, so its data policy was reviewed before committing. Sources were read on 2026-09-30.

| Question | Finding | Source |
|---|---|---|
| Does it train on our data? | **No.** "Groq is not permitted to use Inputs or Outputs for training or fine-tuning any AI Model Services or other models, unless explicitly granted permission or instructed by Customer." | [Services Agreement §4.2](https://console.groq.com/docs/legal/services-agreement) (last modified 2026-06-22) |
| Can people read it? | Only when needed to run the service, comply with the law, keep the platform reliable or check compliance with the acceptable use policy. With **Zero Data Retention (ZDR)** enabled, Groq does not keep data for reliability or abuse monitoring. | [Services Agreement §4.2](https://console.groq.com/docs/legal/services-agreement), [Your Data in GroqCloud](https://console.groq.com/docs/your-data) |
| How long is it kept? | Inference requests are **not retained by default**. They may be logged temporarily, **up to 30 days**, only to troubleshoot reliability errors or investigate suspected abuse. ZDR turns that off. | [Your Data in GroqCloud](https://console.groq.com/docs/your-data) |
| Where is it processed? | Retained data is stored in Google Cloud Platform buckets **in the United States**. | [Your Data in GroqCloud](https://console.groq.com/docs/your-data) |
| Mental health use | Not forbidden by the [acceptable use policy](https://console.groq.com/docs/legal/ai-policy). The agreement says the models "should not be used for medical, legal, financial, or other professional advice", which matches marlix's rule of never diagnosing or presenting itself as therapy. | [Services Agreement §4.3](https://console.groq.com/docs/legal/services-agreement) |
| Minors | Not forbidden. If an app is likely to be used by minors, the developer is responsible for complying with the laws on minors and their data. | [Services Agreement §6.3](https://console.groq.com/docs/legal/services-agreement) |

**Verdict: acceptable for v1.** Groq does not train on the data and does not keep it by default. To close the remaining gap (abuse logs of up to 30 days), **Global ZDR was enabled on 2026-09-30** in the console under Settings → Data Controls. It also turns off batch processing and fine-tuning, which marlix does not use; the chat API keeps working.

This is a clear difference with the discarded option: Gemini's free plan uses content to improve Google's products and it can be read by human reviewers.

### Free plan limits

Limits apply **per organization and per model**: the whole family shares them. Official table read on 2026-09-30 ([Rate limits](https://console.groq.com/docs/rate-limits)). The account's own limits for `openai/gpt-oss-120b` were confirmed in the response headers of the test call (`x-ratelimit-limit-requests: 1000`, `x-ratelimit-limit-tokens: 8000`).

| Model | Requests/min | Requests/day | Tokens/min | Tokens/day |
|---|---|---|---|---|
| `openai/gpt-oss-120b` | 30 | 1,000 | 8,000 | 200,000 |
| `openai/gpt-oss-20b` | 30 | 1,000 | 8,000 | 200,000 |
| `openai/gpt-oss-safeguard-20b` | 30 | 1,000 | 8,000 | 200,000 |

What this means for marlix:

- **1,000 requests per day** for the whole account. With the per-user cap of 100 interactions (S2-6), about ten active users fit in a day. The cap is what stops one person, or a bug, from using up everyone's quota.
- **8,000 tokens per minute** is the tightest limit. One chat call (system prompt + memory + the last 15 to 20 messages + reply) can use a few thousand tokens, so only a few calls fit in a minute. The prompt must stay compact, and the backend must handle a `429` response with a friendly "try again in a moment" (S1-6).
- Background memory distillation (S4-6) spends the same quota; it should run spread out, not in bursts.
- Quotas are per model, so the isolated crisis classification (S2-2) can use a different model and not compete with the conversation.

### Model choice

| Option | Result |
|---|---|
| `openai/gpt-oss-120b` | **Chosen.** Production model, best quality of the free models and good Spanish. Called with low reasoning effort to save tokens and answer faster. |
| `openai/gpt-oss-20b` | Backup. Production model, faster but less nuanced. Switching is only a change of `GROQ_MODEL`. |
| `qwen/qwen3.8-27b` | Discarded as main model: it is a preview model on Groq and can be removed without notice. |
| Llama 3.3 70B, Llama 3.1 8B | Not chosen: they are not listed in the free plan table on 2026-09-30. |

Groq retires models from time to time. Because the model is an environment variable and the backend talks to the LLM through its own abstraction layer (S1-3), changing model or provider does not require rewriting code.

### Account and test call

The project's Groq account and a development API key were created on 2026-09-30. The key lives only in `api/.env`, which Git ignores; [`api/.env.example`](../api/.env.example) lists the variables without values. Production gets its own key on Render (Sprint 1).

Test call from the terminal (Git Bash), reading the key and model from `api/.env`:

~~~bash
set -a && . api/.env && set +a
curl -s https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$GROQ_MODEL\", \"reasoning_effort\": \"low\",
       \"messages\": [{\"role\": \"user\", \"content\": \"Saludame en una frase corta, en español de Costa Rica.\"}]}"
~~~

Result: `openai/gpt-oss-120b` answered in Spanish, using 113 tokens.

### If the policy or limits stop being acceptable

Alternatives, in order: another Groq model, a paid provider such as DeepSeek, or a local model with Ollama.
