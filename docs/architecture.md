# Architecture

How the pieces of marlix fit together. See the [data model](erd.md) for database access and policies.

## Engineering rules

- Only the backend calls the language model and holds its key.
- Every application table has row-level security and the policies its access requires.
- Chat content stays out of logs. Keep secrets and real user data out of the repository.
- Run the [crisis filter](crisis-protocol.md) before the conversation model, including when the daily limit is reached. Clear risk stays on the backend. For an ambiguous message, send only that message to the isolated classifier. Trigger the crisis protocol if the classifier cannot clear it.

Repository documentation, code and commit messages are in English. User-facing app copy is in Spanish.

## Code organization

Marlix uses Clean Architecture and domain-driven design across the API and mobile app. Code is organized by business capability.

| Backend module | Responsibilities |
| --- | --- |
| Conversation | Chat turns, history, retention and transcription. |
| Safety | Crisis detection and escalation, reply review and help resources. |
| Memory | Distilled facts, extraction policy, prompt selection and personal memory management. |
| Identity | Sessions, account deletion, profiles and onboarding. |
| Usage | Burst limits, daily accounting and reset time. |

Backend modules live under `api/src/modules/`. Their `domain/` contains models and policies. The `application/` layer orchestrates workflows through ports. `presentation/` adapts HTTP and `infrastructure/` adapts Supabase, model providers and configuration. `server.ts` creates production adapters and `app.ts` wires up the HTTP application.

The app follows the same feature-first layout under `app/lib/features/` for account, conversation, safety, memory, settings, avatar and voice. Riverpod and widgets live in presentation and wiring. The conversation, memory and account controllers use feature gateways backed by the shared HTTP adapter. Voice uses ports for speech detection, recognition, playback, model storage and device facts. Shared preferences, the dialer and notifications are device adapters.

Domain and application dependencies point inward. Presentation consumes the typed ports and cases exposed by application, with adapters supplied through the composition code. API and Flutter architecture tests enforce the import boundaries and SDK isolation. The `/v1` HTTP contract continues to connect the two applications.

To follow a chat turn, start at the [HTTP route](../api/src/modules/conversation/presentation/chat.ts) and read the [chat use case](../api/src/modules/conversation/application/chat-service.ts). In Flutter, the [chat controller](../app/lib/features/conversation/presentation/chat_controller.dart) uses the conversation gateway. The [HTTP transport](../app/lib/shared/infrastructure/http/http_transport.dart) handles requests and the [chat event reader](../app/lib/features/conversation/infrastructure/chat_event_stream.dart) handles sentence streaming.

## Components

| Component | Runs on | Responsibility |
|---|---|---|
| Flutter app | Phone | Chat and voice screens, animated avatar, help screen, onboarding and settings. Talks only to the backend and to Supabase Auth. |
| Microphone | Phone | Records each turn with echo cancellation and cuts it where the person stops speaking (`record` plus Silero VAD, which scores the voice of every 32 ms frame, and `TurnDetector`), so the person can talk without buttons and interrupt marlix ([decision](decisions.md#2026-10-28--talking-without-buttons-whisper-in-groq-and-a-detector-of-turns-s6-9)). |
| Speech recognition | Backend | `POST /v1/transcribe` turns the turn's audio into text with Whisper in Groq, which understands Costa Rican words. The audio is never saved. |
| Avatar voice | Phone | Turns marlix's reply into speech with Supertonic 3; the native voice (`flutter_tts`) is the fallback. Free and private. The model (398 MB) is downloaded once from Hugging Face at a pinned revision; after that it works offline ([decision](decisions.md#2026-10-21--voice-supertonic-3-on-the-phone-voice-f4-s6-1)). |
| Local reminders | Phone | Daily reminders scheduled on the phone (`flutter_local_notifications`). No server, no push. |
| Backend | Render (free plan) | The only component that talks to the LLM and writes to the database. Checks the session, the daily limit and the crisis filter, builds the prompt with memory, calls Groq and reviews the reply before returning it. |
| Supabase Auth | Supabase | Sign-up, sign-in and sessions. |
| PostgreSQL | Supabase | Profiles, conversations, messages, memories and usage, with RLS on every table. |
| Groq | Groq cloud (free plan) | Generates chat replies, classifies ambiguous messages, extracts memories when a conversation ends and transcribes voice turns with Whisper, with Zero Data Retention. |
| Uptime monitor | UptimeRobot (free plan) | Calls `GET /health` every 5 minutes, looks for `"status":"ok"` in the body and keeps the free Render service awake ([monitoring](monitoring.md), S7-6). |
| Backup | GitHub Actions | Dumps the database every day, encrypts it with age and keeps it as a private artifact ([backups](backups.md), S7-5). A quarterly workflow also opens an issue to verify the help lines (S7-7). |

## Where the keys live

| Key | Where | Why |
|---|---|---|
| `GROQ_API_KEY` | Backend environment variables on Render (`.env` locally, never committed) | Anyone who extracts it from an app could use up or bill the account. |
| `SUPABASE_SECRET_KEY` | Backend environment variables on Render | It has `service_role` rights: it bypasses RLS and gives access to all data. |
| Supabase publishable key | Flutter app (`app/config/`) | Public by design: it only allows sign-in and what RLS permits. |
| The person's session | Phone, encrypted with a key from the Android Keystore (S4-3), outside backups (S4-11) | It keeps the person signed in; the backend checks it on every request against the project's public keys. |

The app never holds a secret. That is why **the Flutter app never calls the LLM directly**: every request goes through the backend.

## Voice runs on the phone

Voice mode reuses the same backend path as text chat. The phone records each turn, sends the audio to [`POST /v1/transcribe`](api-contract.md#post-v1transcribe) (Whisper in Groq, never saved), sends the text it gets to [`POST /v1/chat`](api-contract.md#post-v1chat) like any message, and speaks the reply with the on-device voice. The crisis filter applies exactly as in text chat because the text goes through the same endpoint. Transcribing does not count as an interaction, but it does use Groq's shared audio quota, so it has its own rate limit.

## The crisis filter comes first

The crisis filter runs inside the backend, after session verification and before sending anything to the conversation model:

- **Clear risk:** the message never leaves the backend. The reply is a fixed text that points to 9-1-1.
- **Ambiguous:** only that message is sent to Groq for an isolated classification, with no history or memory. If it says risk, fails or times out, the crisis protocol is triggered.
- **Normal:** the message continues to the conversation with the model.

The backend always runs the filter before enforcing an exhausted daily limit. See the [chat endpoint](api-contract.md#post-v1chat) for request behavior and the [crisis protocol](crisis-protocol.md) for classification.

## The reply is reviewed before it is shown

The personality prompt forbids clinical advice, diagnoses and the rest of marlix's limits, but a model can still break them. So every reply goes through a review in code (S2-4, `api/src/modules/safety/domain/`) before it reaches the person:

- The reply is split into sentences and **each sentence is reviewed on its own**. The voice mode sends the reply sentence by sentence while the model writes it (S6-10) and reuses the same check on each one.
- Rules, checked most serious first: harmful information (lethal doses, methods), clinical advice (medication, doses), diagnoses, claiming to be a professional, discouraging professional help and encouraging dependence. The phrases are in [`rules.ts`](../api/src/modules/safety/domain/rules.ts) and are normalized like the crisis signals; a phrase right after "no" does not count, so "no soy tu terapeuta" passes.
- If a sentence fails, **the reply is replaced** by a safe text that gives no advice and invites the person to keep talking. In the text chat the whole reply is replaced; in the voice stream the sentences already approved stay and the safe text follows them. The log only says which rule fired, never the reply.
- It is a few regular expressions per sentence: no second model call and no noticeable delay (well under 5 ms per reply).

## Ready to change providers

The backend talks to the LLM through its own abstraction layer (S1-3), and voice is behind an on-device abstraction. Groq, the voice engine or the hosting can be replaced without changing the app.

### The LLM layer

The model port and its errors live in `api/src/shared/application/ai/`. Provider implementations and their factory live in `api/src/shared/infrastructure/ai/`. The [architecture test](../api/test/llm-boundary.test.ts) confines provider SDKs to that adapter directory.

| File | What it holds |
|---|---|
| `types.ts` | The `LlmProvider` interface: `complete(request)` takes the conversation (system prompt first) and returns the reply text, and `stream(request)` returns the same reply in pieces for the voice mode (S6-10). |
| `errors.ts` | `LlmError` and its kinds: `rate_limited`, `timeout`, `unavailable`, `authentication`, `invalid_request` and `empty_response`. Adapters translate every provider failure into one of them, so the backend decides what to do without knowing which provider failed. |
| `index.ts` | The public entry point and `createLlmProvider`, the factory that builds the provider chosen by `LLM_PROVIDER`. |
| `retry.ts` | Wraps any provider so transient failures (timeout, network, 5xx) are tried once more. Quota and key errors are not retried. The timeout of each call is `LLM_TIMEOUT_MS` (S1-6). |
| `groq-provider.ts` | The Groq adapter (S1-4), on the OpenAI SDK with Groq's base URL. After a `429` it does not call Groq again until the wait time Groq asked for has passed. |
| `groq-transcriber.ts` | Whisper in Groq for `POST /v1/transcribe` (S6-9). |
| `quota-monitor.ts` | Reads the daily request quota from Groq's response headers, for `/health` (S7-6). |

The provider is chosen with the `LLM_PROVIDER` environment variable, and each provider reads its own key and model from variables named after it (`GROQ_API_KEY`, `GROQ_MODEL`). Changing the model is a change of variable, not of code.

### Adding an LLM provider

1. Add the provider name to `LLM_PROVIDER` and its variables (key, model) to the schema in `api/src/shared/infrastructure/config/env.ts`, to `api/.env.example` and to the README table.
2. Create `api/src/shared/infrastructure/ai/<provider>-provider.ts` with a class that implements `LlmProvider`. Its SDK is imported only there. Translate every error into an `LlmError` of the right kind; a quota error must carry the wait time the provider asks for.
3. Register it in the provider factory in `api/src/shared/infrastructure/ai/index.ts`, under its `LLM_PROVIDER` name.
4. Review the provider's data policy before sending it real conversations, and record the decision in [decisions.md](decisions.md), as was done for Groq.

Providers compatible with the OpenAI API (Groq, DeepSeek and others) can reuse the OpenAI SDK with a different base URL.
