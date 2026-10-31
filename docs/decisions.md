# Technical decisions

Every time the project picks between two technical options, the decision is recorded here: what was chosen, what was discarded and why. Newest first.

---

## 2026-10-30 — The help screen offers two lines, and the chat reads aloud through the speaker (S7-13)

**Decision:** the help screen and the crisis reply list only **9-1-1** and the **Línea Aquí Estoy** (800-273-7869), each with its name, **service** and **hours** (a new `service` field in `api/config/crisis.json` and in `GET /v1/help-resources`). The two Emergencias CCSS lines are removed. The 9-1-1 text does not say it is free, and neither does the fixed crisis reply; Aquí Estoy's service says it is free, confidential care from the Colegio de Psicólogos de Costa Rica. The layout follows wireframe 06: the red card with the big 9-1-1 button first, then "Otros recursos en Costa Rica". The Aquí Estoy card is laid out like the 9-1-1 one (a big red "Llamar a Línea Aquí Estoy" button, then the details) with a quiet border, so only the button is red. Each line of text has a bold label (Servicio, Horario, Teléfono).

**Why:** a short list is easier to use in a hard moment, and the CCSS lines had no clear service or hours ("Consultar"). The app reads `service` as optional, so a new app still works against a backend that does not send it yet and the built-in 9-1-1 works offline with the same text.

**The same words everywhere:** the system prompt, US-05 and the crisis protocol describe both lines with the same service and hours as the screen (Spanish in the app, the prompt and `crisis.json`; English in these docs), and 9-1-1 is never called free (neither is it in the crisis reply). A test checks that the prompt carries the service and hours of every configured line, so the prompt and `crisis.json` cannot drift apart.

**Reading aloud in the chat:** the voice was played with the call route (`voiceCommunication`, communication mode) in every case. That route exists so the phone's echo canceller can remove marlix's voice from the microphone, but in the chat no microphone is open, and on the Galaxy S24 Ultra the voice came out through the earpiece at the top of the phone, very quiet, while the voice mode (whose capture forces the speakerphone) was fine. Now `CallAudioPlayer` plays as a call only while the voice mode listens (`CallRoute`, set by `ConversationController`) and as plain media otherwise. Measured on the S24: the audio focus request went from `USAGE_VOICE_COMMUNICATION` to `USAGE_MEDIA`. The volume of the chat reading is the media volume.

| Option | Verdict |
| --- | --- |
| Keep the call route and force the speakerphone in the chat | Discarded: it needs communication mode and a route that Android 12+ ignores on some phones (it was already ignored here), and it leaves the phone in call mode if the reading is cut. |
| **Media route when no microphone is open, call route while the voice mode listens** | **Chosen.** Plain media always uses the main speaker, needs no mode changes and keeps the echo cancellation where it matters. |

---

## 2026-10-29 — Natural pauses in the voice: each piece said whole, its edges cut (S6-14)

**Decision:** Supertonic says each piece of a reply in one pass and the model sets the tone and the pauses of its commas. The silence the model leaves at both edges is cut (`trimSilence`: 10 ms windows under an RMS of 0.01, 30 ms kept on each side), and the pause of the final punctuation is added: **180 ms** after a comma, **280 ms** after a semicolon or a colon, **350 ms** after a full stop, a question or an exclamation (`pauseAfter` in `sentences.dart`). The first sentence is still cut at its commas so the first sound comes sooner (S6-9); those pieces get the comma pause.

**Why:** measured on the S24, every piece Supertonic makes starts with 270 to 430 ms of silence and ends with 420 to 590 ms. Before, each sentence was cut at its commas and 200 ms were added between pieces, so a comma sounded as about one second of silence: "Claro, mae, te cuento, fue un buen día, la verdad, aunque estuve algo cansado, pero bien." took 11.2 s, and 5 to 5.6 s once the edges were cut. Between sentences the same edges left a gap of almost a second.

| Option | Verdict |
| --- | --- |
| A. Cut at commas and add 200 / 300 ms (before) | Discarded: two silences added up and the voice sounded broken. |
| B. Cut at commas, cut the edges, add 180 / 280 ms | Good in the listening test, but every piece is a separate utterance and loses the tone of the sentence. Kept only for the first sentence. |
| C. As B with 90 / 180 ms | Not chosen in the listening test. |
| **D. The piece said whole, edges cut, the pause of its final punctuation** | **Chosen.** It is how the voice assistants of the big companies and the call apps such as WhatsApp sound: the whole sentence comes out of the model with its own rhythm, the pauses follow the punctuation (a comma shorter than a full stop) and there is no dead gap at the edges. |

**How it was chosen:** a blind listening test on the S24 with the same phrases in each version (one with many commas, a song and a short one), played by the app itself through the call route. The user chose B over A and C, and then asked for the version closest to the voice assistants of the big companies: D. Changing the voice or the model was out of scope.

## 2026-10-29 — The app says marlix and its voice are an AI (S6-13)

**Decision:** two notices, both short and without drama. The onboarding welcome (the first screen, before the consent) says "Soy una inteligencia artificial, no una persona. Mi voz también la genera una máquina." The voice mode shows "Voz generada por IA" under its title, always visible while the mode is open.

- **Why:** the Supertonic 3 license (OpenRAIL-M) asks to say that generated content is produced by a machine. Until now only the system prompt made marlix say it when asked; no screen did (finding of S6-1).
- **Welcome, not the consent step.** It is the first thing read, and the consent screen is already full of data rules. A card with the sentence stands out from the greeting without a second screen.
- **Under the title, not in the hint line.** The hint under the buttons changes with every phase and can be replaced by an error; the title bar never changes, so the notice is always there.
- **The wording avoids any claim of being a person**, in line with the rule that marlix never presents itself as therapy or as a human. The system prompt is not touched.

## 2026-10-17 — Usage in the database: an atomic function, and a cap read every minute (S4-13)

**Decision:** the daily count is the `daily_usage` row of the person for the Costa Rica day, and the cap is `plan_limits.daily_interactions` of their plan. `plans.json` keeps only the per-minute limit. This replaces the in-memory counters of [S2-6](#2026-10-14--usage-limits-configuration-file-and-in-memory-counters-until-sprint-4-s2-6).

| Option for counting | Verdict |
|---|---|
| A database function `record_interaction(user, day)` that inserts or adds 1 in one statement (`insert ... on conflict do update`) and returns the new total | **Chosen.** Two messages at the same time cannot count as one, because the row is locked during the update. The `schema-test.sql` checks that it counts up and keeps users and days apart. |
| Read the count, add 1 in the backend and write it back | Discarded. Two simultaneous replies read the same number and one is lost. |
| `upsert` through the REST API | Discarded. It can only replace the value, not add to it. |

- **The cap is cached for a minute.** It is read on every message and changes rarely, so each backend process keeps it for 60 seconds. A new cap applies within that minute with no deploy. If the database fails and the cap is already known, the chat keeps using it.
- **A count that cannot be read stops the message** (`500`, before the model): letting it through would give the cap away. **A count that cannot be saved does not stop the reply**: the person already has it, and failing would only make them resend it. The cost is one uncounted reply, logged by its error code.
- **A crisis ignores the database.** It is answered even if the count cannot be read; its response just has no `usage`.
- **The per-minute limit stays in memory.** It is a window of seconds: a restart only gives more room.
- **Order of deploy.** The function is created by [a migration](migrations/2026-10-17-record-interaction.sql) that runs in the SQL Editor **before** the backend that calls it is deployed.
- **The cascade already covers it.** `daily_usage` references `auth.users` with `on delete cascade`, so deleting an account (S4-9) removes its counters.

---

## 2026-10-17 — Message retention: an hourly delete inside the backend, 90 days by default (S4-10)

**Decision:** a job inside the backend deletes every message older than `MESSAGE_RETENTION_DAYS` (90 by default) when the server starts and then every hour. It deletes only rows of `messages`: conversations and memories stay, so the distilled memory lasts as long as the account. The policy is in [docs/memory.md](memory.md#how-long-messages-are-kept) and, for the person, at the bottom of the Settings screen.

| Option | Verdict |
|---|---|
| A timer in the backend process, one `DELETE ... WHERE created_at < cutoff` through the Supabase API | **Chosen.** Same pattern as the memory sweep (S4-6), no migration and nothing new to deploy. The delete is idempotent, so a missed run is made up by the next one, and `messages_created_at_idx` serves it. |
| `pg_cron` in Supabase | Discarded. One more place where the period lives, outside the environment variables and the tests. |
| Filter old messages out when reading and never delete | Discarded. The goal is to hold less data, not to hide it. |
| A database function called by RPC | Discarded. It needs a migration for a single statement. |

- **Hourly, not at midnight.** Render's free plan sleeps, so a fixed hour could be missed every day. A sweep at start and every hour deletes within an hour of the deadline whenever the server is awake.
- **The period is not in the app.** The text in Settings says 90 days; if `MESSAGE_RETENTION_DAYS` is changed in production, update that text with it.
- **Logs.** Only how many messages were deleted, never their content.

---

## 2026-10-17 — Account deletion: the database cascades, and a recent sign-in is read from `amr`, not `iat` (S4-9)

**Decision:** `DELETE /v1/account` deletes the user in Supabase Auth with the secret key (a hard delete), and `on delete cascade` removes the profile, conversations, messages, memories and usage. Before that it requires a sign-in from the last 5 minutes. The contract is [here](api-contract.md#delete-v1account).

| Option for deleting the data | Verdict |
|---|---|
| Delete the Auth user and let the foreign keys cascade | **Chosen.** One call, one transaction in the database: nothing can be left half deleted, and a table added later is covered if it follows the same rule. |
| The backend deletes table by table, then the user | Discarded. It repeats what the schema already says, and the next table someone adds would be forgotten. |
| Soft delete (Supabase's `should_soft_delete`) | Discarded. The rows would stay, and the card asks for a real deletion. |

- **Verified table by table, from the catalog.** `docs/schema-test.sql` fails if any foreign key to `auth.users` does not cascade, if a table in `public` (except the two catalogs) has no such key, or if any row is left pointing to a deleted user. A table that forgets the rule breaks the CI instead of surviving the account. Both guards were checked by creating a bad table.
- **`amr`, not `iat`, proves a recent sign-in.** The contract first said `iat`. Checked on 2026-10-17 with a real token: a token refresh issues a new `iat` but keeps the original time in `amr[].timestamp`. With `iat`, anyone holding a stolen refresh token could get a fresh token and delete the account without the password. `amr` only moves when credentials are entered. A token without a usable `amr` is treated as an old session (it fails closed). This changes the contract's wording, not its behavior for the person: the app asks for the password and retries.
- **Usage counters.** They are in `daily_usage` since S4-13, so the cascade removes them with the account.
- **Known limit.** The access token of a deleted account still passes the session check until it expires (at most an hour). It can read nothing, since the rows are gone, and the database refuses what it tries to write because the user no longer exists. If a memory extraction was running for that user, its insert is refused for the same reason.

---

## 2026-10-17 — Managing memories: through the backend, deleting for real, and editing only the text (S4-8)

**Decision:** the app lists, edits and deletes memories with `GET`, `PATCH` and `DELETE` on `/v1/memories` ([contract](api-contract.md#get-v1memories)), and the backend does it with the secret key, always filtering by the signed-in user. Deleting removes the row; editing changes only `fact`.

| Option | Verdict |
|---|---|
| Through the backend, as the contract says | **Chosen.** One place checks the session, validates the text and decides the order and the 404s, and the app keeps a single client for everything. |
| The app straight to Supabase, relying on the RLS policies and the `update (fact)` grant that already exist | Discarded for now. It works, but the rules (500 characters, trimmed text) would live in the app and in the database, and it would be the only data the app reads without the backend. The policies stay as a second barrier. |
| Mark the memory as deleted and hide it | Discarded. The person asked for it to be gone, and a hidden copy still counts as data kept (Law 8968). |

- **Immediate effect.** The prompt is built from the database on every message ([S4-7](#2026-10-17--memory-in-the-prompt-the-most-recently-updated-in-a-stable-order-one-line-each-s4-7)), so a deleted memory is not sent from the very next message, and an edited one goes with its new text. A test checks it end to end.
- **Editing keeps the category and the source conversation.** The person fixes the wording, not the classification; the extractor may later rewrite the fact if the person says something new. An edit also counts as the most recent update, so it is favored when there are more than 30 memories.
- **The edit is not run through the extractor's sensitive-data filter.** It is the person writing about themselves, on a screen that shows them exactly what is stored. They are limited to 500 characters and one line when it reaches the prompt ([S4-7](#2026-10-17--memory-in-the-prompt-the-most-recently-updated-in-a-stable-order-one-line-each-s4-7)).
- **An id that is not a UUID is a `404`,** like one that does not exist or belongs to someone else: no one can tell the three apart, and the database never sees a malformed value.

---

## 2026-10-17 — Memory in the prompt: the most recently updated, in a stable order, one line each (S4-7)

**Decision:** on every message, the backend adds the person's memories at the end of the system prompt. At most 30 (`CHAT_MEMORY_FACTS`); if there are more, the most recently updated ones. How it works: [docs/memory.md](memory.md#what-goes-into-the-prompt).

| Option for "the most relevant ones" | Verdict |
|---|---|
| The most recently updated | **Chosen.** A fact that was just told, corrected or edited is the most likely to still matter. It needs no extra model call and no embeddings, which the card leaves out of scope. |
| By similarity with the current message | Discarded: it is the semantic selection the card leaves for later, and it would change the prompt on every message. |
| The oldest first | Discarded: the first things told are not the most current. |
| By category | Discarded: nothing says that family matters more than work. |

- **Stable order for the cache.** The chosen ones are always written oldest first, whatever order the database answers in, so the text of the memory is identical from one message to the next until it changes. If the order followed the ranking, a fact moving up or down would change the prompt and spend the cache for nothing. The fixed part still comes first and never changes.
- **One line each.** The facts come from what the person said, and from S4-8 on they can edit them. Flattening each one to a single line stops it from adding a heading or a paragraph that would read as an instruction; the prompt also says they are data, not orders.
- **If the memory cannot be read, the answer is `500`** before the model is called, like the recent context ([S4-5](#2026-10-17--recent-context-the-last-16-messages-of-the-open-conversation-never-a-crisis-s4-5)): answering as if marlix did not know the person would be wrong, without saying so.
- **Cost.** 30 facts are about 450 tokens on top of the 1,600 of the fixed prompt, and the fixed part is cached. If Groq's per-minute limit is reached, lower `CHAT_MEMORY_FACTS` or `CHAT_CONTEXT_MESSAGES`.

---

## 2026-10-17 — Memory extraction: a job inside the backend that ends idle conversations, with two barriers against sensitive data (S4-6)

**Decision:** when a conversation has no messages for 30 minutes (`CONVERSATION_IDLE_MINUTES`) it ends, and a background job inside the backend extracts its facts with a small model (`MEMORY_EXTRACTOR_MODEL`, `openai/gpt-oss-20b` by default). How it works, its limits and what is never saved: [docs/memory.md](memory.md).

| Option | Verdict |
|---|---|
| A queue and a sweep in the backend process, with the idle conversations ended by a database function | **Chosen.** Nothing new to deploy or pay for. The queue runs one extraction at a time, a few seconds apart, so the extractions do not burst on Groq's quota ([S0-11](#2026-09-30--llm-provider-groq-free-plan-with-openaigpt-oss-120b-s0-11)). |
| `pg_cron` in Supabase calling a function | Discarded. Extraction needs the model, so it would also need an Edge Function with its own copy of the Groq key. |
| A separate worker service | Discarded. Another paid or sleeping service for one job. |
| Extract at the moment the conversation ends, before answering | Discarded. The card requires that it does not delay the reply. |

- **When it ends.** Idle time counts from the last message, not from when the session started. The conversation is ended when the person's next message arrives (before it is answered, so it opens a new one) and by a sweep every 5 minutes. The chat only waits for the single database call that ends it, and a failure of the memory never fails a message, not even a crisis.
- **Known limit.** Render's free plan sleeps after 15 minutes without traffic and a sleeping server runs no timer. A session that ended while it slept is extracted just after the person's first message back, so that first reply can miss its facts. The uptime monitor of S7-6 keeps the server awake and removes the gap.
- **Two barriers for sensitive data.** The prompt forbids ID numbers, cards, passwords and diagnoses (and phone numbers, emails, addresses and anything about self-harm), and tells the model the conversation is data, not instructions. Then a filter in code drops any fact with eight or more digits, an email, a word about secrets or documents, or a health stem, whatever the model answered. The card names four kinds of data; **health is read widely** (illnesses, medications, treatments too), because everything saved travels to Groq on every call and a lost fact costs less than a saved one.
- **Update, do not duplicate.** The extractor sees the saved facts with their ids and returns the same id to correct one. An id that is not one of the person's facts counts as a new fact, and a fact that differs only in case or accents is not a change. The answer is untrusted input: validated with a schema, at most 10 changes per session, and at most 50 facts per person (past it, only updates).
- **Never the messages of a crisis.** The extractor reads the conversation without them, like the chat window ([S4-5](#2026-10-17--recent-context-the-last-16-messages-of-the-open-conversation-never-a-crisis-s4-5)).
- **Failures leave the session pending.** After three attempts per process it waits for a restart instead of looping on the quota. The logs only say that an extraction ran or failed, never the messages, the facts or the database's text.

---

## 2026-10-17 — Recent context: the last 16 messages of the open conversation, never a crisis (S4-5)

**Decision:** with each message, the model gets the system prompt, the last 16 messages of the user's open conversation and the new message. The size is `CHAT_CONTEXT_MESSAGES` (2 to 40, 16 by default), so it changes in Render without a deploy of new code.

- **Why 16.** The card asks for 15 to 20. Messages travel in pairs (message and reply), so an even number keeps whole turns, and the system prompt already takes about 1,600 tokens of Groq's free quota (8,000 a minute). 16 is 8 turns: enough to hold the thread without using the quota in two or three messages. If the limit is reached, lower it.
- **Within one conversation.** The window reads the open conversation (`ended_at is null`). Nothing closes a conversation yet; S4-6 does, when it extracts the memory, and from then on a new conversation starts with an empty window and the distilled memory instead.
- **Crisis messages are left out.** [S0-8](#2026-09-30--chat-flow-crisis-filter-before-the-daily-cap-crisis-messages-kept-in-history-s0-8) says they stay in the history but never go to Groq. The history could not tell them apart, so `messages` has a `crisis` column, set by the backend for both messages of a crisis turn (migration `docs/migrations/2026-10-17-messages-crisis.sql`). The app does not read it. Crisis messages saved before the migration (only test accounts, since the history began in S4-4) keep `false`.

| Option | Verdict |
|---|---|
| A `crisis` column | **Chosen.** One boolean that the database keeps, so it does not depend on text. |
| Recognize the fixed crisis reply by its text and drop it with the message before it | Discarded. If the text in `crisis.json` changes, the old replies would no longer match and would go to the model. |
| Do not save crisis messages | Discarded in S0-8: the person would return to a chat without what they wrote or the help they got. |

- **Read before saving.** The context is read before the turn is saved, so the new message is not in the window and the model never gets it twice.
- **If the context cannot be read,** the answer is `500` before calling the model, like a reply that cannot be saved (S4-4): answering without context would make marlix forget the thread without saying so.

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
- **Usage counters** moved to the database in S4-13, a card created for this because the contract assigned it to S4-4 but its criteria did not include it.

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

> **Replaced by [S4-13](#2026-10-17--usage-in-the-database-an-atomic-function-and-a-cap-read-every-minute-s4-13):** the daily count and cap are now in the database. What follows is the original decision.

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


## 2026-10-19 — Final avatar artwork: vector layers and palette (S5-1)

**Decision:** the avatar is a round beagle drawn as 12 independent SVG layers in `app/assets/avatars/marlix/` (`oreja_izq`, `oreja_der`, `cuerpo`, `panza`, `mejillas`, `ojos_abiertos`, `ojos_felices`, `nariz`, `boca_0` to `boca_3`). Every layer uses the same `0 0 512 512` canvas, so stacking them in order assembles the character with no offsets. The widget of S5-2 animates them by swapping eyes and mouths.

**Palette:** orange body, brown ears, white muzzle and blaze, cream belly, pink cheeks: the validated S0-5 prototype. The mint palette first written on the card was dropped so the chat keeps the same character it already shows.

**Origin:** the character is original, inspired by the author's own dog; it copies no existing character. The art is public and editable with any SVG editor.

**Test:** `app/test/avatar/marlix_layers_test.dart` checks the layer files and the shared canvas, and stacks them with `flutter_svg`, the dependency S5-2 needs anyway.


## 2026-10-19 — Avatar widget: English names, folder as parameter, drawn effects (S5-2)

**English names in the code.** `AvatarMarlix(state, volume, folder)`, `AvatarState { idle, listening, thinking, speaking, happy }` and `mouthForVolume`, instead of the Spanish names first written on the card. The layer file names stay as the template fixes them (`oreja_izq`, `boca_0`...), because they are the public contract of every avatar (`docs/avatar.md`).

**The folder is a parameter.** The widget works with any folder that follows the template. Reading `avatars.layers_path` needs a backend endpoint, since the app never queries the database directly (`docs/architecture.md`); it is the new card S5-7.

**Animation in code, no Rive.** Rive's free plan cannot export for the app, and an open source project cannot require a paid tool to edit the avatar. A single `AnimationController` of 12 s drives the periodic movements and a `TweenAnimationBuilder` eases between poses.

| Alternative | Why not |
| --- | --- |
| One `AnimationController` per movement | More objects and more ticks for the same result on old phones. |
| Animating with `AnimatedSwitcher` between states | A state change would cut instead of ease: the card asks for no jumps. |
| Baking effects (waves, hearts, cloud) as SVG layers | They would break the fixed layer template and every new avatar would have to redraw them. |

**Artwork redrawn against the prototype (found in S5-2).** The first layers of S5-1 were drawn from the card alone and did not look like the validated prototype (`docs/diagrams/wireframes/style-guide/avatar.png`): they lacked the white eye rings, the "marlix" coat, arms, tail and feet. The layers were redrawn measuring over the prototype and the template grew to 19 layers (`cola`, `pies`, `brazo_izq`, `brazo_der`, `cabeza`, `pupilas` and `boca_pensando` are new; `panza` is the coat). The open mouths have the flat top of the prototype, so Speaking visibly opens the mouth even at low volume, and the doubtful mouth of Thinking is its own layer instead of sharing `boca_1`. `pupilas` is apart from `ojos_abiertos` so the pupils can look up inside their rings. The lettering is outlined from the bundled Baloo 2 because `flutter_svg` does not draw text. Lesson: check the artwork against the validated reference before delivering, not only against the card.

**Debug-only test screen.** "Probar el avatar" is shown in Settings only when `kDebugMode`, so release builds do not carry a developer row.


## 2026-10-19 — Daily reminders: local, weekly-repeating, no streaks (S5-3)

**Change of scope (user decision, 2026-10-19).** The card first asked for reminders after 2, 5 and 10 days without opening the app, then silence. The product owner changed it to a daily greeting, like Duolingo, so the user talks with marlix a little every day. What does not change: no streaks, no day counters, no guilt and no user data in the texts, because in an emotional-support app losing a streak creates guilt and pressure, and the text shows on the lock screen.

**Decision:** the reminders are local notifications with `flutter_local_notifications`: no server, no Firebase and no Groq quota. When they are on, the app schedules seven notifications, one per weekday at the time the user picks (19:00 by default), each repeating every week (`DateTimeComponents.dayOfWeekAndTime`). They keep going even if the app is never opened again, and each weekday has its own text, so they rotate through the week. A single daily repeating notification would always show the same text.

**Configuration:** the default time and the bank of at least seven texts live in `app/assets/config/reminders.json`, validated at startup (`ReminderConfig`). A test checks that no shipped text has digits, guilt, a sad avatar, streaks, "it has been a while" or user data.

**Opt-in on the phone.** The switch and the time (`RemindersController`, keys `reminders_enabled` and `reminders_time` in `SharedPreferences`) are off by default; they turn on only after the system permission (`POST_NOTIFICATIONS` on Android 13+), and `enable()` is the function onboarding (S5-5) calls. If the user revokes the permission in the phone's settings, the next opening turns the switch off instead of pretending they are active. Signing out cancels them and signing in schedules them again. `docs/api-contract.md` and `docs/erd.md` already describe `remindersEnabled` / `users.reminders_enabled` on the server, but no endpoint stores it yet; syncing it is left to the onboarding and settings work.

| Alternative | Why not |
| --- | --- |
| Push notifications (Firebase) | They need a server, an account and keys; the card asks for zero cost and no server. |
| One daily repeating notification (`DateTimeComponents.time`) | The text cannot change from one day to the next. |
| Scheduling the next 30 one-shot days on each opening | They would stop if the app is not opened for a month, and the user asked for no end. |
| A streak counter like Duolingo's | Discarded by the user too: it creates guilt and dependence. |
| Exact alarms (`SCHEDULE_EXACT_ALARM`) | A greeting does not need the exact minute, and the permission adds a prompt and store scrutiny. |

**Details:** the time zone is read from the phone (`flutter_timezone`) so the hour follows the local clock, daylight saving time included; the app reschedules on every opening, which also follows a time zone change. Reboots are covered by the plugin's boot receiver (`RECEIVE_BOOT_COMPLETED`), and the plugin needs core library desugaring in `build.gradle.kts`. The time picker uses the 24-hour clock because the app has no Spanish localizations and the 12-hour one would show AM/PM in English.


## 2026-10-19 — The avatar follows the conversation: one controller and a tone from the backend (S5-4)

**One controller.** `AvatarController` listens to the chat state and is the only code that sets the avatar's state: `thinking` while marlix replies, a 3 s `happy` after a reply to a positive message, `idle` otherwise. Screens only watch it, so voice mode (Sprint 6) adds `listening` and `speaking` there without touching the widget. The avatar sits in the chat header (64 px, 48 px with the keyboard open, because at 64 px a 320x568 phone with the keyboard open overflowed by 20 px), as in wireframe 03a but bigger and animated.

**`tone` in `POST /v1/chat`.** The backend returns `tone` (`positive` or `neutral`), computed in `api/src/services/tone/message-tone.ts` with rules over words and emojis, without calling the model. It is conservative on purpose: `positive` only for a short message (at most 200 characters) with a clear happy phrase and no negation or doubt ("no me siento bien", "estoy bien pero cansado" are `neutral`), because celebrating next to someone who is struggling is worse than staying calm. A crisis is always `neutral`. The app reads anything but an explicit `"positive"` as neutral, so it still works against a backend that does not send the field.

| Alternative | Why not |
| --- | --- |
| The model decides the tone | It changes the system prompt (about 1,600 tokens, and the Groq per-minute limit is tight), complicates parsing and forces repeating the prompt tests. |
| Detecting the tone in the app | The card asks the backend for the signal; the rules would be duplicated for the future voice mode and cannot be tested with the backend suite. |
| A sentiment library | A dependency and a model for a decoration; false positives are worse than none. |

**Avatar by `avatar_id` moves to S5-7.** `/v1/me` and `/v1/avatars` do not exist yet, so the folder comes from `avatarFolderProvider`, which returns marlix's folder; S5-7 overrides it. Decided with the product owner on 2026-10-19.

**Reduce motion.** `AvatarMarlix` stops its 12 s clock when the phone asks to remove animations (`MediaQuery.disableAnimationsOf`): it keeps its pose and still eases between states. It is the right behavior for people who need it, and it lets `pumpAndSettle` finish in the chat tests, since the avatar otherwise floats for ever (tests turn the feature on in `openChat`).


## 2026-10-19 — Onboarding: the consent is stored on the server, and the chat waits for it (S5-5)

**Decision:** after signing in, the app reads `GET /v1/me` and only opens the chat if `onboardingCompleted` is true; otherwise it shows the onboarding (`ProfileGate`). Finishing it calls `POST /v1/onboarding`, which records `data_consent_at` and `onboarding_completed_at` and the answer to the reminders offer, in one atomic update (`where onboarding_completed_at is null`), so two phones cannot both win; the second gets `409 ONBOARDING_ALREADY_COMPLETED`, which the app treats as "already done". Both endpoints were already in the contract and the columns in the schema, so there is no migration. This was outside the card ("App" area) and was added with the product owner on 2026-10-19: "once per account" and "explicit consent" cannot live only on the phone, because a reinstall or a second phone would skip the consent or repeat the onboarding.

| Alternative | Why not |
| --- | --- |
| The flag in `SharedPreferences` | The consent would not be on record in the database, and the onboarding would repeat after a reinstall. It contradicts US-02 and the ERD. |
| Letting the app write the columns through Supabase | The app never reads or writes the database directly (docs/architecture.md); the backend does it with its own key. |

**The chat stays closed while the profile loads or fails.** Without the consent the app must not be used, so a failed `GET /v1/me` shows a retry (plus sign-out and help), never the chat, and there are no automatic retries. The profile is not read without a session: a request at sign-out would come back 401 and make a voluntary sign-out look like an expired session. Accounts created before this card (their `onboarding_completed_at` is null) see the onboarding the next time they sign in.

**Steps (wireframes 02a to 02d).** Welcome with the avatar bouncing with joy (`happy`); the notice that marlix is not therapy, what is stored and the consent; the microphone and the daily reminders; and where help is. The pages do not swipe, so the consent cannot be skipped. The checkbox is pinned next to its button: inside the scroll it fell below the fold on an 800 px screen, with the button visible but disabled. Whoever does not accept can sign out ("No acepto, cerrar sesión"); the wireframe has no exit. Errors are said on the step itself, not in a snackbar, because the snackbar covered the button to try again.

**Microphone.** `permission_handler` asks for `RECORD_AUDIO` when the person taps "Permitir"; "Ahora no" asks nothing and voice mode (Sprint 6) asks again. `permission_handler` 13 requires compiling against Android 37 and our Android Gradle plugin recommends 36, so the project uses 12.x until the toolchain moves. The screen says speech recognition may depend on the phone's service, as the card asks.

**Reminders.** The switch uses the same code as settings (`toggleReminders`) and the answer goes to the server with the consent. The local preference stays the one that schedules the notifications (S5-3); the server copy is informational.


## 2026-10-20 — Integration tests create and delete their own account (S5-6)

**Decision:** `app/integration_test/api_test.dart` signs up a throwaway account (`it-<time>-<random>@marlix.test`, random password) in `setUpAll` and deletes it with `DELETE /v1/account` at the end. The last test does it and checks the account can no longer sign in; `tearDownAll` repeats the deletion if a test failed halfway, so a run never leaves data in production. `config/test-account.json` and its example are gone: nothing needs a permanent test account. The sign-up works because "Confirm email" is off ([S4-3](#2026-10-15--accounts-18-or-older-no-email-confirmation-yet-sessions-checked-with-the-projects-public-keys-s4-3)).

| Alternative | Why not |
| --- | --- |
| A permanent test account | It is what left `prueba-s43@marlix.test` and its messages in production. |
| A local database for the tests | The point of these tests is the deployed backend and its real Supabase rules. A second Supabase project is out of scope for the card. |

**Only the app deletes.** The run needs a recent sign-in for the deletion, so it signs in again right before deleting instead of trusting the sign-up token. The account's cascade (S4-9) removes profile, messages, memories and usage; the backend suite uses fakes and never touches production.

**Production cleanup.** The old accounts (`@marlix.test`) are removed by the owner in the Supabase SQL Editor with `delete from auth.users where email like '%@marlix.test'`, which the same foreign keys cascade.


## 2026-10-20 — The avatar folder travels in `GET /v1/me` (S5-7)

**Decision:** `GET /v1/me` (and `POST /v1/onboarding`, which returns the same profile) adds `avatar.layersPath`, read from `avatars.layers_path` in the same query that already joined the avatar. The app reads it with the profile, before the chat opens, and `avatarFolderProvider` turns it into the widget's folder. No new endpoint and no migration.

| Alternative | Why not |
| --- | --- |
| `GET /v1/avatars` | It lists every avatar (v2) and the app would need a second request and a second loading state; the user's avatar is already part of the profile it must read before showing anything. It stays in the contract for the v2 selection screen. |
| Hard-coding the folder in the app | It is what S5-2 did; the card asks for the folder in the database to be the source. |

**Fallback.** The chat never waits for or breaks on the avatar: if the profile is loading, failed, or the backend (an older one) sends no `layersPath`, the folder is marlix's. A path that does not start with `assets/avatars/` or has `..` is ignored too: the app only loads bundled files, and an unknown folder would draw an empty avatar (the widget hides a missing layer).

**Trap: the seed's trailing slash.** `schema.sql` stores `assets/avatars/marlix/`, and the widget builds `$folder/cola.svg`, which would become `marlix//cola.svg` and silently draw nothing. The app trims trailing slashes instead of editing the seed, so databases that already exist need no migration.


## 2026-10-21 — Voice: Supertonic 3 on the phone, voice F4 (S6-1)

**Decision:** marlix speaks with [Supertonic 3](https://huggingface.co/Supertone/supertonic-3), a neural text-to-speech model that runs on the phone with ONNX Runtime, in Spanish (`es`) and with the **F4** voice, using the package's default settings (5 denoising steps, speed 1.05). The phone's native voice (`flutter_tts`) stays behind the voice layer of S6-2 only for when Supertonic cannot run: no space for the model, a failed download or a model that does not load. It is not a fallback for slow phones, because the point of the decision is a voice that sounds human. The Costa Rican flavor comes from the text, which the [system prompt](system-prompt.md) defines: no free voice has a Costa Rican accent.

| Alternative | Why not |
| --- | --- |
| The phone's native voice (`flutter_tts`) | The listeners preferred Supertonic in every vote but one (and that one was corrected). It starts in 56 to 137 ms and weighs nothing, so it is the fallback when Supertonic cannot run. |
| Paid cloud voices | Out of scope: they cost money and send the reply to a third party. |

**How it was tested.** A throwaway app (not in the repository) played the same 5 phrases, written in marlix's voseo tone, with both engines on two real phones, a Samsung Galaxy S24 Ultra (SM-S928B, Android 16, arm64, 11 GB of RAM) and a HONOR 90 (REA-NX9, Android 15, arm64, 11 GB of RAM), and on the emulator. Three people voted blind, on the S24 Ultra: the app drew which engine was A and which was B in every phrase. A second round played one phrase (the empathic one) with the 10 Supertonic voices, anonymous and in random order, and each person picked a favorite.

| Result | Native voice | Supertonic 3 (F1) |
| --- | --- | --- |
| Blind vote, engine | 0 | **14 of 14** (3 people, 5 phrases; one person did not vote phrase 1; one wrong vote on phrase 1 was replaced by its correction) |
| Time to start speaking, S24 Ultra | 56 to 82 ms (238 ms the first time) | 1.05 to 1.72 s, about 3 times faster than the audio lasts |
| Time to start speaking, HONOR 90 | 92 to 137 ms (396 ms the first time) | 1.82 to 2.70 s, about 2 times faster than the audio lasts |
| Loading the model | none | 0.8 to 0.9 s on the S24 Ultra, 1.7 s on the HONOR 90 (12 s on the emulator) |
| First-use download | none | 398 MB (4 ONNX files): 32 s over wifi on the S24 Ultra, 49 s on the HONOR 90 |
| Added to the APK (arm64) | none | about 28.6 MB (`libonnxruntime.so`) |

The voice vote gave **F4** two votes and F1 one (a fourth vote without a name, also F4, was not counted). Three voters is a small sample: enough to choose, not to measure preference.

**What it costs.**
- **A first-use download of 398 MB.** The app has to ask for wifi, show progress and work in text mode meanwhile. S6-2 and S6-4 must plan it.
- **A wait before the first word.** The package synthesizes the whole phrase before playing it, so the wait grows with the phrase length. The voice mode prompt already asks for one to three short sentences.
- **Unofficial port.** `supertonic_flutter` 2.0.0 depends on `flutter_onnxruntime`; the model files come from Hugging Face. The app pins the version, adds `-keep class ai.onnxruntime.** { *; }` to the ProGuard rules, and uses the native voice if loading fails.

**Shortening the wait without changing the voice.** Measured on the HONOR 90, the slower phone, with the F4 voice:

| How it is synthesized | Time to the first word (phrases 1, 2, 3 and 5, which have more than one sentence) |
| --- | --- |
| The whole phrase, 5 denoising steps (what was voted) | 1.60 to 2.92 s |
| **Only the first sentence, 5 steps** | **1.17 to 1.43 s** |
| The whole phrase, 3 steps | 1.05 to 1.70 s |
| Only the first sentence, 3 steps | 0.76 to 0.97 s |

The voice keeps the **5 steps** that the listeners voted for: 3 steps is faster but nobody has listened to it, and fewer steps can sound less natural. The wait is shortened by speaking **sentence by sentence**: marlix starts with the first sentence while the next ones are synthesized (the voice layer of S6-2 does it; S6-10 also starts the voice before the whole reply has been written), which keeps the voted voice and brings the first word to about 1.2 to 1.4 s on the HONOR 90. A phrase of a single sentence still waits for the whole of it: phrase 4 took 2.03 s with 5 steps.

**Not verified: a low-end phone.** The card asked for two real phones; two were tested and both are high end (11 GB of RAM). Neither is a modest or old phone, and the wait grew from one to the other. S6-12 measures one. If the first sentence still takes more than 3 s there, the next step is 3 denoising steps, checked first with a blind listening test; the native voice is the last option.

**Scaling to any phone.** The app decides by measuring the phone, never by its model name, so the same code serves a flagship, a modest phone or an iPhone (the package supports iOS 16 or newer). S6-2 builds these rules behind the voice interface:

1. **marlix owns the model download.** If the files are missing, the package's `initialize()` downloads them by itself from the `main` branch, unverified and even over mobile data. The app therefore downloads the files itself, from the pinned revision `3cadd1ee6394adea1bd021217a0e650ede09a323` of `Supertone/supertonic-3`, checks each file against a SHA-256 manifest shipped in the app, resumes broken downloads, uses wifi unless the person allows mobile data, and only then calls `initialize()`. A model update is a new revision and a new manifest in a release, never a silent change.
2. **Space before downloading.** The download needs at least 1 GB free (398 MB of files plus room to write them). Otherwise the phone uses the native voice and the app says why.
3. **Memory without guessing.** With the model loaded the app used 637 MB (PSS) on the HONOR 90. A phone that Android marks as low-RAM (`ActivityManager.isLowRamDevice`, as Android Go phones are) skips Supertonic. On any other phone the app tries: it saves a "loading" flag before loading the model and clears it after; if the next start finds the flag, the last load killed the app, and that phone uses the native voice.
4. **Speed measured once per phone.** After loading, the app synthesizes one fixed sentence and computes how many seconds of audio it makes per second of work. Speaking by sentences only works if the next sentence is ready before the current one ends, so the threshold is **1.3** (30 % of margin). The phones measured gave 3.0 to 3.7 (S24 Ultra) and 1.8 to 2.3 (HONOR 90). Below 1.3 the phone tries 3 steps, once the blind listening test approves them; below 1.3 with 3 steps it uses the native voice. The result is saved per phone (its system fingerprint), model revision, steps and voice, and measured again when any of them changes. The 1.3 starts as a reasoned value and S6-12 calibrates it.
5. **Never a broken conversation.** If Supertonic fails in the middle of a reply, that reply continues with the native voice, and the text is always on screen.

| Phone | Voice |
| --- | --- |
| Enough space, loads the model, 1.3 or more with 5 steps | Supertonic F4, 5 steps (the voted voice) |
| Loads the model, below 1.3 with 5 steps and 1.3 or more with 3 | Supertonic F4, 3 steps, only after the listening test approves them |
| No space, low-RAM, a failed load, or below 1.3 even with 3 steps | Native voice |

**The voice settings live in the database.** `avatars.voice_config` only accepts `voice`, `pitch` and `rate` today, which fit the native voice and not Supertonic. S6-2 changes it with a migration to `{"engine": "supertonic-3", "voice": "F4", "language": "es", "steps": 5, "rate": 1.05, "fallback": {"voice": "default", "pitch": 1.0, "rate": 1.0}}`, updates the seed and sends it in `GET /v1/me` next to `layersPath`. A new avatar in v2 brings its own voice with no code change.

**License.** The code is MIT; the model weights use the [OpenRAIL-M License](https://huggingface.co/Supertone/supertonic-3/blob/main/LICENSE) (Copyright (c) 2026 Supertone Inc.), which allows commercial use and asks to keep the notices, to give recipients a copy of the license and to pass on its use restrictions. The app downloads the model from Hugging Face and the repository does not contain it. Those restrictions that touch marlix: no medical advice (marlix never diagnoses), generated content must say that it is machine generated, and no exploiting a person's vulnerabilities (marlix does not encourage dependence). **The disclosure is still missing:** the system prompt makes marlix say it is an AI when it talks, but no screen of the app says so. S6-13 adds it before the voice ships. The credit is in the README.

## 2026-10-21 — The voice layer: one interface, the phone decides, the app owns the download (S6-2)

**Decision:** the app speaks through `VoiceController` (`lib/screens/voice/`), which wraps `VoiceService` (`lib/services/voice/`). The service chooses between two engines that implement the same `VoiceEngine` interface (`speak`, `stop`, and the events started, progress and finished): `SupertonicVoiceEngine` and `NativeVoiceEngine` (`flutter_tts`). It applies the rules of [the S6-1 decision](#2026-10-21--voice-supertonic-3-on-the-phone-voice-f4-s6-1), and the avatar's `voice_config` in the database says which voice, so a new avatar brings its own without a release. No screen names an engine: `architecture_test.dart` fails if one imports an engine, the model store or a voice package.

**One common signal.** Supertonic makes audio, so it knows how long it lasts; the native voice reports the word it is on. Both are turned into the same progress, a fraction from 0 to 1, so the avatar's mouth (S6-5) does not care which engine speaks.

| Alternative | Why not |
| --- | --- |
| Let `supertonic_flutter` download the model with `preDownloadModels` or on its own | It downloads from the `main` branch, with no check of the files, and it does it again by itself, even over mobile data, if a load fails. The app downloads instead, from the pinned revision, with the SHA-256 of every file in `assets/config/voice-model.json`. |
| Put the model in the APK | It would add 401 MB to every download of the app. |
| Fork or copy the package to change its download | Then the app maintains a port of someone else's code. Closing the network inside the engine is enough. |
| Decide the engine by the phone's model name | The list is never complete. The app measures the phone. |

**The download is the app's.** `VoiceModelStore` fetches each file of the manifest to `<name>.part`, hashes it while it arrives, and renames it only if the size and the SHA-256 match; a cut download resumes from the bytes it has (`Range`), and a server that ignores the range sends the file again. The `.verified` mark is written after the last file, and `isReady` checks it and the sizes, not the hashes, so opening the app never reads 401 MB. The person decides when to download (wifi, or mobile data only if they allow it, and at least 1 GB free). While the model is missing, replies are spoken with the native voice.

**The engine cannot go online.** `SupertonicVoiceEngine.prepare` runs the package's `initialize` inside `HttpOverrides` that refuse every connection. If a file were missing or a load failed, the package would delete the model and try to download it from `main`: now that attempt fails at once, and the service treats it as a failed load. The files sit in the folder the package reads (`supertonic_models_v3` inside the app's support folder), which is why `supertonic_flutter` stays pinned at 2.0.0.

**What the service does when something fails.**
- The model does not load: that revision is marked as failed for the phone, the files are deleted, and the native voice is used. A new model revision gets a new chance.
- The app dies while loading: a flag is set before the load and cleared after it. If the next start finds it, that load killed the app (a phone short of memory does this) and the phone is marked as failed.
- The phone is too slow: below 1.3 seconds of audio per second of work the model is deleted and the native voice is used. The measure is kept, so the download is not offered again until the system fingerprint changes. The 3-step mode of S6-1 is not part of this card: it needs its own listening test and is decided in S6-12.
- Supertonic fails in the middle of a reply: the reply is spoken sentence by sentence, so the sentence that failed is repeated with the native voice and the reply goes on, once per reply. Three failures in a row drop Supertonic until the app restarts.
- The phone says it has Spanish but cannot speak it (the emulator's Google voice reported `es-US` as available and failed with status -7 because its voice data was never downloaded): to the person it is the same as having no voice, so the status is `VoiceUnavailable`, the screens say so and the text chat keeps working.

**Sentence by sentence, with the next one ready in advance.** The service splits the reply into sentences and speaks each one in turn, so the engine can change between two of them without repeating what was said. The first version said one sentence, waited for it to end and only then made the next one, which left a silence as long as the synthesis (1 to 1.7 s) after every full stop; the person heard it at once. Now, when a sentence starts to play, the engine starts making the next one (`PrefetchingVoiceEngine.warm`), as the speed threshold of S6-1 assumes. Measured on the S24 Ultra, the longest gap between two sentences went from the synthesis time to about 240 ms. S6-10 is a different thing: the backend sends the reply to the app sentence by sentence, so the voice starts before the model has written all of it.

**Commas get a pause of their own.** Supertonic reads through commas without stopping (the package only cuts text at the end of a sentence, and leaves the commas to the model, which at speed 1.05 hardly pauses). The engine splits each sentence at its commas, semicolons and colons, makes each clause and joins them with 200 ms of silence after a comma and 300 ms after a semicolon or colon. The punctuation stays in the text so the voice still raises its tone for a sentence that goes on. It costs little: the first sentence of a phrase with commas started in 1.1 s instead of 0.8 s on the S24 Ultra. A comma inside a number does not split.

**The shape of `voice_config`.** `{"engine", "voice", "language", "steps", "rate", "fallback": {"voice", "pitch", "rate"}}`, with the database refusing any other shape ([migration](migrations/2026-10-21-voice-config.sql), run in the SQL Editor before the backend that sends it is deployed). The app does not trust it: a `voiceConfig` it does not understand, or none from an older backend, gives the S6-1 voice, so neither an old app nor an old backend breaks.

**Traps found.**
- A test caught that the speed measure was never read back: it was saved with `|` as separator and its own key contains `|`. It is saved as JSON now.
- Google's voice can say a language is available and still fail to speak it, so availability is not checked once but at the moment of speaking.
- `device_info_plus` already gives `isLowRamDevice`; the only native code is five lines in `MainActivity` for the free space, which Dart cannot read.
- The model, voice styles included, is 401 MB: S6-1 measured 398 MB for the four ONNX files alone.


## 2026-10-21 — Voice replies: ask for short sentences, and clean what the model still writes (S6-3)

**Decision:** in voice mode (`mode: "voice"` in `POST /v1/chat`) the system prompt asks for **one to three** short sentences, as people talk, and the backend cleans the reply with `toSpokenText` before the reply review, the history and the memory see it. In text mode nothing changes. The voice is made on the phone, so the backend only returns text prepared to be read aloud, and there is no synthesis endpoint.

| Alternative | Why not |
| --- | --- |
| Two to four sentences, as the card said | The code and the docs already had one to three. A shorter reply starts speaking sooner and spends less of Groq's quota; the same message got 127 characters in voice mode and 182 in text, and 221 against 376 in another. The card was changed to say one to three. |
| Only ask the model (no cleaning) | A prompt is a request, not a guarantee. One list or one emoji is read as "asterisco" or skipped with a strange pause. |
| Clean in the app, just before the voice | Then the screen shows the dirty text and the voice says another one, and every future client repeats the cleaning. In the backend, one place. |
| Save the original and clean only for the voice | Two versions of every reply, and a chat that could show words that were not said. The history keeps what was said. |

**Where it runs.** After the model answers and before `reviewReply`, so the review checks the final text. A reply that is empty once cleaned (only emojis) is replaced by the review's safe reply and logged as "nothing to say" without its content. The crisis reply never goes through the model or through this.

**What was already there.** `mode` was accepted since S1-5 and the voice token limit (512 against 1,024 in text) too; this card covers them with tests and adds the cleaning and the prompt wording ("as people talk and not as they write: no lists, headings or bold").

**Checked against the real model.** Three messages in both modes: the voice replies had two or three sentences and were 30 to 40 % shorter, and the cleaner found nothing to change, because the prompt already works. The cleaner is the net for the day the model slips.

**Out of scope.** Streaming the reply sentence by sentence so the voice starts before the whole reply exists is S6-10, and the audio is S6-4.


## 2026-10-25 — Reading replies aloud: a switch in Settings, pause with the screen, stop on leaving (S6-4)

**Decision:** the chat reads each reply aloud when the person turns on **Leer las respuestas en voz alta** in Settings (saved on the phone, off by default). While it is on, the app sends `mode: "voice"` so the reply comes short and clean (S6-3). The chat shows a bar with **pause / resume / stop** while marlix talks. The reply is always on screen as text first: a voice that fails only ends the reading and never touches the chat.

| Question | Decision |
| --- | --- |
| How is it turned on, if the voice button is S6-7? | A minimal switch in Settings, which S6-7 replaces with the button and the full-screen mode. The alternatives were a speaker button on every bubble (does not read by itself) and moving the whole thing to S6-7 (S6-4 would have no way to be tried). |
| Screen locked or app in the background | The voice **pauses** and **continues when the person comes back**; a pause made by the person stays until they resume. No foreground service, no notification and no extra permission. Playing on with the screen off needs a persistent notification in Android, and that fits better in the voice mode (S6-7). |
| Leaving the chat | Opening Settings or Help stops the reading, and so does signing out or turning the switch off. Help is where someone in a bad moment goes: nothing should keep talking over it. |
| Pause in the native voice | Android's engine cannot pause, so it stops and **says the sentence again from its start** on resume. Supertonic pauses the audio exactly where it is. Both keep the stream open, so the sentence loop of `VoiceService` waits for the resume instead of treating the pause as a failure. |
| Crisis replies | They are not read: they stay on screen with their numbers and the call buttons. Reading them is a decision for the voice mode. |

**Not in this card.** The 401 MB download of the Supertonic model has no screen yet, so until the model is on the phone the replies are read with the native voice. The prompt to download it belongs to the voice mode (S6-7); the avatar moving its mouth with the audio is S6-5.


## 2026-10-25 — The avatar's mouth follows the loudness of the voice (S6-5)

**Decision:** the voice layer (S6-2) gets a second signal next to the progress, `VoiceLevel`: how loud the sound is right now, from 0 to 1. `ReplyReader` passes it to the avatar, which opens the mouth by that volume. It is not phonetic lip-sync (out of scope in the card).

| Question | Decision |
| --- | --- |
| Where does the level come from in Supertonic? | From the audio the engine already has: the loudness (RMS) of every 50 ms step, divided by the loudest step of that sentence, so a quiet voice and a loud one move the mouth the same. It is calculated once per sentence, before it plays, and read by the same clock that gives the progress. |
| And in the native voice? | Android gives no audio, so each word marks the level (longer words open wider) and the mouth closes 160 ms later to wait for the next word. |
| Why 50 ms and not the 100 ms of the progress? | A syllable lasts about 150 ms: at 100 ms the mouth would move once per syllable and look slow. The progress went to 50 ms too, so both come from the same tick. |
| When does the avatar speak? | When the first sound plays (`VoiceStarted`), not when the reply arrives: with Supertonic the first word takes 1 to 2.7 s and the mouth should not move in the silence. Until then it keeps the state the chat gave it. A positive reply's `happy` gives way to `speaking`. |
| Silence | Under 0.05 the mouth is the closed smile (`boca_0`), so commas and gaps between sentences close it. Before, `boca_0` never came from the volume. |
| Pause, stop, failure | Pausing closes the mouth and resuming opens it again; stopping, ending or any failure sends the avatar back to rest. It only rests if it was speaking: if the person already sent another message the avatar is thinking, and the old sound ending must not interrupt that. |

**Alternatives.** Reading the player's real position would be more exact, but `audioplayers` behind the package does not expose it; the clock starts when `play` returns. Measuring the level on the native audio is not possible without capturing the output.

**Not checked.** The delay between sound and mouth was not measured on a phone from code: it depends on the output latency of each phone and has to be seen on a screen recording.


## 2026-10-25 — Warning before the daily interactions run out (S6-6)

**Decision:** when 10 % or less of the plan's daily cap is left, the counter chip in the chat turns into a warning (amber background and border) and says when they renew: "Te quedan 10 mensajes hoy. Se renuevan a medianoche." Before that it only shows the count, and at zero the limit card (S4-13) takes over. There is no pop-up and nothing is added to the conversation.

| Question | Decision |
| --- | --- |
| What was already there? | The counter (S3-3), the limit card that explains the renewal and the help button in the header, which never depends on the quota. S6-6 covers them with tests and adds the early warning, the only criterion that was missing. |
| Where is the line? | `remaining <= ceil(limit * 0.1)`, 10 of 100 today. It is calculated from the `limit` the backend sends, so a cap changed in `plan_limits` moves it without a release. Fixed numbers (10, 20) would have been wrong for a plan with another cap. |
| Why 10 % and not 20 %? | A warning that is on for a fifth of a long day stops being noticed. At 10 % it shows for the last ten messages, which is enough to finish a thought. |
| Message in the chat instead? | Rejected: it adds text to the history and the conversation that the person did not write nor marlix said, and the model would see it. |
| Screen readers | The warning is a live region, so it is announced when the chip turns into it and not on every message. |
| Voice | The counter is shared by text and voice, as the card says. The full-screen voice mode (S6-7) has to show this same chip. |

**Checked on the phone (S24 Ultra):** with the cap lowered to 3 for a test account, the chip showed "Te queda 1 mensaje hoy. Se renuevan a medianoche." on an amber background at one left, and the limit card with the locked composer and the help button at zero; the help screen opened from the header. The normal, low, last-one and exhausted states are also covered with widget tests.


## 2026-10-25 — The full-screen voice mode: the voice is what stands out (S6-7)

**Decision:** a voice button next to the message field opens the voice mode, a full-screen route that follows wireframes 04a and 04b: close button, "Modo voz" and the help button on top; the avatar large and centered on a pale circle; what marlix is doing ("Aquí estoy", "Pensando…", "Preparando la voz…", "marlix está hablando", "En pausa") and its last reply; and at the bottom a **big central voice button** with **Chat** and **Terminar** small at its sides. The counter of the day (S6-6) is shown under the top bar. Writing is the small option, as in the wireframe.

| Question | Decision |
| --- | --- |
| What does the big button do before S6-8? | It pauses and resumes what marlix says. When nothing is being said it is the microphone, off, with the line "Pronto podrás hablarle con tu voz": the place of the wireframe is kept and S6-8 only turns it on. A working microphone button that does nothing was worse than a clearly off one. |
| How does the person write meanwhile? | The small **Chat** button swaps the buttons for a field; sending closes it and the voice buttons come back. A field that stays open hides the pause button and the avatar. In S6-8 and S6-9 it stays as the way to type instead of speaking. |
| How is the avatar kept large? | With the keyboard open the last reply and the labels are dropped so the avatar keeps room; the keyboard closes after sending. Seen on the S24: with a permanent field the avatar was about 50 dp. |
| Replies in the voice mode | `voiceModeProvider` asks for short, clean replies and reading aloud while the screen is open, like the Settings switch does (`repliesAreSpokenProvider`). Leaving by any way (the X, Terminar, back button or gesture) ends the mode and cuts what is being said. |
| The transition | A route of 380 ms with fade and a slight growth, and the avatar flies from the header to the center with a `Hero`. It is opaque so the chat is not drawn under it. |
| The voice button in the chat | Left of the field, only while the field is empty (the text gets all the width while writing; with it, a 320 px screen wrapped one line and overflowed). Off when the daily limit is reached. |
| The model download | The card appears only when there is something to decide: "Dale a marlix su voz" (401 MB) with **Descargar con wifi**; over mobile data it says what it costs and asks for **Descargar con datos móviles**; with no connection it says so and offers nothing; downloading shows the progress and says replies go on with the phone's voice; if it stops it says why and **Continuar la descarga** resumes it; a phone with no Spanish voice says the text chat keeps working. When the voice works nothing is shown. The download runs in `VoiceService`, so leaving the screen does not stop it. |

**Not in this card.** Listening with the microphone (S6-8) and the turns with interruption (S6-9), which will add the "Te escucho…" state of 04a. The "Preparando la voz…" of the chat bar is S6-15.

**Checked on the S24 Ultra:** the opening transition, the large avatar, a message written with **Chat** (Pensando → Preparando la voz → hablando with the mouth moving), the keyboard layout, and the whole model download (the model was moved aside, the card offered it, showed 92 of 401 MB and disappeared when it ended).

## 2026-10-27 — Speech recognition: the phone's recognizer behind one interface (S6-8)

**Decision:** the person speaks to marlix with the recognizer of the phone (`speech_to_text`), in Spanish, behind `SpeechRecognizer` (`lib/services/voice/speech_recognizer.dart`: `listen`, `stop`, `cancel`, with partial and final results). Screens go through `SpeechController`; no screen imports the package (a rule in `architecture_test.dart`). What is understood goes through `ChatController.send`, the same path as typed text, so `POST /chat` and its crisis filter apply equally. No endpoint changes.

| Question | Decision |
| --- | --- |
| Which locale? | The first the phone offers of `es_CR`, `es_419`, `es_MX`, `es_US`, `es_ES` (same order as the native voice). Android writes `es_CR` and iOS `es-CR`; the id the phone gave is the one passed back. No Spanish at all: the phone "cannot recognize the voice" and writing keeps working. |
| On the device or in Google's service? | `onDevice: true`. On Android it maps to `EXTRA_PREFER_OFFLINE`, a preference: when the language is not downloaded the phone uses its service instead of failing. The onboarding (S5-5) already tells the person that. |
| What does the big button do? | Idle: the microphone ("Toca el micrófono y háblale."). Listening: a filled stop button ("Terminé de hablar"), the state "Te escucho…" and the words heard so far where the last reply goes. While marlix speaks it still pauses and resumes; interrupting by talking is S6-9. Off while a reply is pending or the daily limit is reached. |
| Does marlix hear itself? | Starting to listen stops the reading first. Opening the **Chat** field, leaving the mode by any way, or leaving the screen closes the microphone. |
| The permission | `MicrophonePermission.ask()` now answers `granted`, `denied` or `blocked`. Pressing the microphone asks again if the person said "Ahora no" in onboarding. If the system will not ask again (`blocked`), the same button opens the phone's settings. In both cases the line says to use **Chat**. |
| Failures | `noSpeech` ("No te escuché"), `unavailable` (no recognizer or language) and `other` each show a line under the buttons; none blocks the text chat. A final result with no words is `noSpeech`: nothing is sent. |
| Length of a turn | 30 s at most (`listenFor`), so an open microphone ends. Detecting the end of speech and interruptions are S6-9. |

**Not in this card.** End-of-speech detection and interruption (S6-9). Whisper in Groq (shares the quota and the audio leaves the phone) or in the phone (heavier) stay as alternatives behind `SpeechRecognizer`, a candidate for v2.

## 2026-10-28 — Talking without buttons: Whisper in Groq and a detector of turns (S6-9)

**Decision:** the person talks to marlix without buttons: the microphone opens by itself, the turn ends when they stop speaking, and talking over marlix cuts it. The audio of each turn is recorded on the phone with echo cancellation, a voice detector (`SileroVoiceActivity`) scores every 32 ms frame and a detector of turns (`TurnDetector`) decides where the turn starts and ends, and the WAV goes to the new `POST /v1/transcribe` ([contract](api-contract.md#post-v1transcribe)), which uses Whisper (`whisper-large-v3-turbo`) in Groq. The text then goes through `ChatController.send`, so the crisis filter of `POST /v1/chat` applies equally. `ServerSpeechRecognizer` implements the same `SpeechRecognizer` interface as S6-8, so screens did not change their imports.

| Question | Decision |
| --- | --- |
| Why not keep the phone's recognizer (S6-8)? | On the S24 it did not cancel marlix's own voice (marlix cut itself), cut the person at pauses because it decides the end of speech on its own, and does not write "mae" or "tuanis". Whisper accepts a `prompt` that spells Costa Rican words, which also covers most of S6-17. |
| Why Groq and not Whisper on the phone? | A model on the phone is heavy (download, RAM, battery) and S6-1 already spent that budget on the voice. Groq is already our provider and the key never leaves the backend. The price is that the audio leaves the phone; the onboarding text says so, and the audio is never saved or logged (zero data retention in Groq). |
| How is the end of the turn found? | Silero VAD on the phone (`vad_plus`, MIT, a 2.3 MB model) gives the probability of voice of every 32 ms frame, and `TurnDetector` decides on it: it starts above 0.75 and 0.035 of loudness (RMS) for 300 ms, so a television or people in the street, which are voices but far away, do not open a turn; it goes on above 0.45; it keeps a pre-roll of 400 ms so the first syllable is not lost; a click is dropped; a turn that was voice less than half of the time (a fan that now and then looks like a voice) is dropped as `noSpeech` and never reaches the backend; and a turn lasts 30 s at most. An energy threshold was tried first and discarded: after the phone's noise suppression the voice reached it at 0.02 to 0.03 and the detector missed it unless the person shouted. |
| Silence that closes a turn | 0.8 s. The sentences that sound unfinished are held back (next row), so a pause to think is not lost. |
| Can the person pause to think? | A sentence that ends in "y", "pero", "eh", a comma or an ellipsis is held back, up to twice, waiting 4 s for the rest; both parts go to the chat as one message. A closed sentence ("." or "?") is answered at once. |
| Interrupting | The microphone stays open while marlix speaks (`audioInterruption: none`; by default `record` pauses it when another sound takes the audio focus, so there was no way to interrupt). While marlix speaks the detector is `guarded`: more than 0.85 of probability, 0.06 of loudness and 390 ms. A voice that passes the guard **pauses** marlix at once and the words decide: what looks like marlix's last reply (`isEchoOf`), or a turn that came to nothing, lets it go on where it was; anything else cuts the reading and is answered. The phone's echo cancellation is not enough alone, so this does not depend on it. |
| Marlix hearing itself | Its voice came back into the microphone as loud as a person (0.2 to 0.3 of loudness, probability 1.0): it cut itself, transcribed its own sentences and answered them. The phone cancels the echo of what goes through the call route only, so marlix's voice is played with `CallAudioPlayer` (`USAGE_VOICE_COMMUNICATION`, speaker on) and the microphone records in call mode. The volume of marlix is then the call volume. A global `AudioContext` did not reach the player inside `supertonic_flutter`, which is why the package's player is replaced. |
| Noise that Whisper writes down | Whisper writes sentences on a fan or the street. The backend asks for `verbose_json` and drops the segments it doubts (`no_speech_prob` above 0.85, or above 0.6 with `avg_logprob` below -1, or `compression_ratio` above 2.4). |
| How soon does marlix start? | The first sound waits for the first piece of the reply to be made, and a long first sentence took up to 9 s. The first sentence is spoken clause by clause (`splitForSpeech`), so the first piece is short; the rest is made while it speaks. The first sound now comes 1 to 2.6 s after the reply. |
| When does it listen again? | After the reply ends plus `reopenDelay` (250 ms), so the tail of marlix's voice is not heard as the person. Three turns without words pause the conversation; five attempts when the service is busy. |
| What does the central button do? | It pauses and resumes the conversation (it used to start and stop one turn). Going to the background pauses it too, so the microphone never stays open. |
| Quota | Groq's free quota is shared by the whole project: 2,000 requests and 28,800 s of audio per day, in addition to the chat. `/v1/transcribe` is limited to 20 per minute per user and refuses when the daily interactions are used, because the chat would refuse the answer. When the quota runs out it answers `503`, which the app shows as a problem with the voice while writing keeps working. |

**Reference.** The design follows how the voice assistants of the big companies and the call apps such as WhatsApp solve the same problems: a voice detector that scores the voice instead of measuring volume, a pre-roll and a silence to close each turn, noise that does not open a turn, the echo of the speaker cancelled through the call route, and an interruption that stops the assistant at once and then checks what was heard. The numbers (thresholds, silences, durations) were measured on the S24 with the app's own logs.

**Removed.** `SpeechToTextRecognizer` (S6-8) and the `speech_to_text` package: nothing used them, and without them the app no longer asks Android for its recognition service.

## 2026-10-29 — The reply reaches the voice sentence by sentence (S6-10)

**Decision:** in voice mode `POST /v1/chat` can answer as a stream of Server-Sent Events (`Accept: text/event-stream`). The backend cuts the model's reply into sentences while it is written, cleans (S6-3) and reviews (S2-4) each one, and sends it; the app speaks each sentence as it arrives instead of waiting for the whole reply. The contract is in [`api-contract.md`](api-contract.md#post-v1chat).

| Question | Decision |
| --- | --- |
| Who cuts the sentences? | The backend (`SentenceStream`), not the app. The review must run on a sentence before anyone hears it, so the cut has to happen where the review is. The card said the app cuts the text; the contract already had the backend sending `sentence` events, and that is what was built. The app only takes the first sentence and cuts it at its commas (S6-9) so the first sound comes sooner. |
| When is a sentence complete? | When the whitespace after its full stop has arrived: "Hola." could still become "Hola.com". A lone "1." is kept with its list item. Decimals and addresses are not cut. |
| What if a sentence fails the review? | It is never sent. The safe reply goes out as the next `sentence`, the rest of the model's reply is dropped, and the saved reply is the approved sentences followed by the safe reply: exactly what the person heard. In the text chat the whole reply is still replaced, because nothing was heard yet. Sentences already spoken cannot be taken back, so the alternative of replacing everything would put in the history something different from what was said. |
| What if the model fails midway? | The stream ends with an `error` event and the turn is neither saved nor counted. Before the first sentence nothing is open yet, so the normal JSON error with its status (and `Retry-After`) is sent instead. `withRetry` retries a stream only while nothing was delivered, so a sentence is never said twice. |
| Why the first event opens the stream | Validation, the daily limit and a model that fails before saying anything keep answering JSON with their HTTP status. The headers go out with the first event. |
| Text mode | It ignores the header: a text reply keeps its paragraphs, and the card leaves streaming the text chat out of scope. |
| The app | `MarlixApi.sendVoiceMessage` reads the events; `ChatController` publishes the sentences in `liveReplyProvider`; `ReplyReader` starts a reading with the first one and `VoiceService.speakSentences` says each as it arrives, waiting for the next if it gets ahead. The complete reply is not read again when it arrives, and the avatar keeps its mouth moving after it. While the voice speaks the conversation is not "thinking" any more, even if the reply is still being written. A backend that answers plain JSON works as before. |
| Trap | `await for` over the events with a `return` inside waited for the cancellation of the subscription of a stream that had already ended, and the chat stayed on "thinking" for ever with the reply complete. The events are read with a plain subscription and its `cancel()` is not awaited. |

**Measured** against Groq from the PC, voice mode, the same stream: the first sentence arrives 0.5 to 0.7 s before the reply is complete (1.36 s vs 2.06 s, 1.17 s vs 1.70 s, 1.89 s vs 2.38 s). The gain is modest because voice replies are short and most of the wait is the model's first token; it grows with longer replies. The time until the voice makes its first sound still depends on the phone (S6-1).

## 2026-10-29 — Only the backend writes the consent and the onboarding (S6-11)

**Decision:** `authenticated` has no `UPDATE` on any column of `users`. Migration `docs/migrations/2026-10-29-revoke-users-update.sql` revokes the column grant on `data_consent_at`, `onboarding_completed_at` and `reminders_enabled`, and `schema.sql`, `schema-test.sql` and `erd.md` follow.

**Why:** the Sprint 5 audit found that, since S5-5, only `POST /v1/onboarding` writes those columns, with the service key. The grant was unused, and with the public key and their own token a user could clear their consent date or repeat the onboarding through the Supabase API. The record of the consent must be written only by the server.

**Checked:** the backend writes with `SUPABASE_SECRET_KEY` (`server.ts`), which does not depend on the grant; the app never reads or writes `users` directly, and there is no `PATCH /v1/settings` route yet, so when US-14 adds it, it has to write through the backend like the rest. `schema-test.sql` now proves the three columns cannot be updated, and that an `update` of each fails with "permission denied".

---

## 2026-10-29 — Migrations are checked by a query, and a failed counter shows in /health (S6-16)

**Decision:** [`docs/verify-migrations.sql`](verify-migrations.sql) lists, for every file in `docs/migrations/`, what it creates (columns, functions, execute grants, constraints, column privileges) and shows `ok` or `MISSING`. It also checks that every table in `public` has RLS. It is run in the SQL Editor after a migration, and by the CI against `schema.sql`, so the query itself cannot drift from the schema. The steps are in [CONTRIBUTING.md](../CONTRIBUTING.md#database-migrations). `GET /health` answers `"status": "degraded"` with `"problems": ["usage_counter"]` after a failed count, until one succeeds.

**Why:** `record_interaction` (S4-13) was missing in production. Every count failed with `PGRST202`, the backend logged only the error code and kept answering, so the daily cap was not enforced and nobody noticed.

| Option for the limit when it cannot count | Verdict |
|---|---|
| Keep failing open after the reply (as in S4-13) and make the failure visible | **Chosen.** The person already has the reply, and refusing the next ones would lock everyone out for a deploy mistake. The cost is the uncounted replies while the counter is down, which `/health` now reports. |
| Fail closed: refuse to answer if the last count failed | Discarded. A database hiccup would stop the whole chat, and the cap protects the free Groq quota, not safety. Reading the count already fails closed (`500` before the model), so a database that is really down does stop messages. |

| Option for showing it | Verdict |
|---|---|
| `200` with `"degraded"` in the body | **Chosen.** `render.yaml` sets `healthCheckPath: /health`: a `503` would make Render restart a healthy process for a problem a restart does not fix. The external monitor (S7-6) looks for `"status":"ok"` in the body. |
| `503` when the counter fails | Discarded for the restart loop above. |
| Only the log line | Discarded. It already existed and nobody read it. |

**Limits.** The flag lives in memory and is set by real traffic: after a deploy it says `ok` until the first reply is counted, and it cannot see a problem while nobody chats. That is why the query, not `/health`, is the check to run before merging. Applying a migration stays manual (an automatic migration tool is out of scope).
