# API contract — v1

Endpoints of the marlix backend for the MVP. The app and the backend are built against this contract, so any change to an endpoint updates this file in the same pull request.

See also the [chat sequence diagram](diagrams/chat-sequence.md), the [architecture](architecture.md) and the [ERD](erd.md).

## Conventions

| Topic | Rule |
|---|---|
| Base URL | `https://<backend-host>`. Every route except `/health` starts with `/v1`. A breaking change ships as `/v2`, so apps installed by APK keep working. |
| Format | JSON in and out (`Content-Type: application/json`), UTF-8. `POST /v1/chat` can also stream (see below). |
| Names | JSON fields in `camelCase`. IDs are UUIDs. Dates are ISO 8601 in UTC (`2026-09-30T18:00:00Z`). |
| Auth | `Authorization: Bearer <access token>`, the Supabase Auth session token the app gets on sign-in. The backend checks it on every request against the project's public signing keys: signature, expiry, issuer, audience `authenticated` and role `authenticated`. Sign-up and sign-in happen against Supabase Auth, not this API; sign-up must send the birth date as user metadata (`data.birth_date`, `YYYY-MM-DD`), and the database refuses it when it is missing or the person is under 18. |
| Ownership | Every authenticated endpoint only reads or changes the caller's own data. Another user's ID returns `404`, never `403`, so the API does not reveal what exists. |
| Privacy | Request and response bodies are never logged. Responses under `/v1` carry `Cache-Control: no-store`, so no cache keeps them. |
| Security headers | Every response carries HSTS, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` and a CSP that blocks everything ([decision](decisions.md)). |

Endpoints marked **Public** do not need a token.

## Errors

Every error uses the same body:

~~~json
{
  "error": {
    "code": "DAILY_LIMIT_REACHED",
    "message": "Daily interaction limit reached.",
    "details": { "resetsAt": "2026-10-01T06:00:00Z" }
  }
}
~~~

`code` is stable and the app decides what to show from it. `message` is for developers, not for the user. `details` is optional.

For `VALIDATION_ERROR`, `details.fields` lists every invalid field. `field` is the field's path, or `body` when the problem is the body as a whole (not an object, unknown field):

~~~json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request body is invalid.",
    "details": { "fields": [{ "field": "message", "message": "Must be at most 2000 characters" }] }
  }
}
~~~

| HTTP | `code` | When | What the app does |
|---|---|---|---|
| 400 | `VALIDATION_ERROR` | The body or a parameter is invalid. `details.fields` lists each invalid field. Malformed JSON or a body over 16 KB answers the same code without `details`. | Fix the input. |
| 401 | `UNAUTHORIZED` | Missing, invalid or expired token. | Refresh the session or ask to sign in again. |
| 401 | `REAUTHENTICATION_REQUIRED` | `DELETE /v1/account` with a token issued more than 5 minutes ago. | Ask for the password again, then retry. |
| 404 | `NOT_FOUND` | The resource or route does not exist, or belongs to another user. | Refresh the list. |
| 409 | `ONBOARDING_ALREADY_COMPLETED` | `POST /v1/onboarding` was already called. | Go to the chat. |
| 429 | `DAILY_LIMIT_REACHED` | The user used today's interactions. `details.resetsAt` is the next midnight in Costa Rica. | Friendly message with the reset time; the help screen stays available. |
| 429 | `RATE_LIMITED` | Too many requests in a short time. Sent with a `Retry-After` header in seconds. | Wait and retry. |
| 503 | `LLM_UNAVAILABLE` | The model failed, timed out or Groq's shared quota is exhausted. Nothing was saved or counted. | Clear error with retry, keeping the text. |
| 500 | `INTERNAL_ERROR` | Unexpected error. | Clear error with retry. |

### Crisis is a reply, not an error

When the crisis filter detects risk, `POST /v1/chat` answers **`200`** with `"type": "crisis"`. It is not an error code because the app must show it right away, never hide it or offer a retry. A crisis reply is returned even when the daily limit is reached, and it does not count against it.

## Endpoints

| Method | Path | Auth | Story |
|---|---|---|---|
| `GET` | [`/health`](#get-health) | Public | — |
| `GET` | [`/v1/help-resources`](#get-v1help-resources) | Public | US-05 |
| `GET` | [`/v1/me`](#get-v1me) | Token | US-01, US-02 |
| `POST` | [`/v1/onboarding`](#post-v1onboarding) | Token | US-02 |
| `PATCH` | [`/v1/settings`](#patch-v1settings) | Token | US-14 |
| `POST` | [`/v1/chat`](#post-v1chat) | Token | US-03, US-04, US-10, US-11, US-12 |
| `POST` | [`/v1/transcribe`](#post-v1transcribe) | Token | US-03 |
| `GET` | [`/v1/history`](#get-v1history) | Token | US-06 |
| `GET` | [`/v1/usage`](#get-v1usage) | Token | US-10 |
| `GET` | [`/v1/memories`](#get-v1memories) | Token | US-08 |
| `PATCH` | [`/v1/memories/:id`](#patch-v1memoriesid) | Token | US-08 |
| `DELETE` | [`/v1/memories/:id`](#delete-v1memoriesid) | Token | US-08 |
| `DELETE` | [`/v1/memories`](#delete-v1memories) | Token | US-08 |
| `GET` | [`/v1/avatars`](#get-v1avatars) | Token | US-13 |
| `DELETE` | [`/v1/account`](#delete-v1account) | Token | US-09 |

---

### `GET /health`

**Public.** Tells whether the service is up. The uptime monitor calls it every 10 minutes (S7-6). It does not touch the database or Groq: it reports what the last real requests found.

**Response `200`**

~~~json
{ "status": "ok" }
~~~

When the last attempt to count a reply failed (S6-16), it still answers `200`, so Render does not restart a service that a restart cannot fix, but says what is wrong. The next count that works clears it. The monitor must look for `"status":"ok"` in the body, not only for the status code.

~~~json
{ "status": "degraded", "problems": ["usage_counter"] }
~~~

---

### `GET /v1/help-resources`

**Public**, so the help screen works before sign-in. Returns the Costa Rican help resources from configuration ([`api/config/crisis.json`](../api/config/crisis.json)), not from code, so changing a number never requires a new app build. The crisis reply of `POST /v1/chat` returns the same list. The app caches the last response so the help screen also works offline (US-15); `updatedAt` changes whenever the list does.

**Response `200`**

~~~json
{
  "updatedAt": "2026-10-30T00:00:00Z",
  "resources": [
    {
      "id": "911",
      "name": "9-1-1",
      "phone": "911",
      "service": "Atención inmediata ante emergencias o situaciones de riesgo",
      "hours": "24 horas, 7 días de la semana",
      "primary": true
    },
    {
      "id": "aqui-estoy",
      "name": "Línea Aquí Estoy",
      "phone": "8002737869",
      "service": "Atención psicológica gratuita y confidencial del Colegio de Psicólogos de Costa Rica",
      "hours": "Lunes a viernes de 2:00 p. m. a 10:00 p. m. y sábados de 9:00 a. m. a 4:00 p. m.",
      "primary": false
    }
  ]
}
~~~

`phone` holds digits only, ready to dial. `service` says what the line offers and `hours` when it answers. Exactly one resource has `primary: true` and the app shows it first. Names, services and hours are user-facing copy, so they are in Spanish. The app treats `service` as optional, so a newer app still works against a backend that does not send it yet.

---

### `GET /v1/me`

Returns the signed-in user's profile. The app calls it after sign-in to decide whether to show onboarding.

**Response `200`**

~~~json
{
  "id": "6a1f0c1e-2b7d-4c55-9a3e-1f2d3c4b5a69",
  "plan": "personal",
  "avatar": {
    "id": "0b8e5d2a-7c41-4f0e-8d2b-3a9c1e7f6b54",
    "slug": "marlix",
    "name": "marlix",
    "layersPath": "assets/avatars/marlix/",
    "voiceConfig": {
      "engine": "supertonic-3",
      "voice": "F4",
      "language": "es",
      "steps": 5,
      "rate": 1.05,
      "fallback": { "voice": "default", "pitch": 1.0, "rate": 1.0 }
    }
  },
  "onboardingCompleted": false,
  "dataConsentAt": null,
  "settings": { "remindersEnabled": false }
}
~~~

`avatar.layersPath` is the folder with the avatar's SVG layers inside the app's assets (`avatars.layers_path`). The app passes it to the avatar widget (S5-7); it ignores a path that does not start with `assets/avatars/` and uses marlix's, and it tolerates the trailing slash.

`avatar.voiceConfig` says how the avatar speaks (S6-2). `engine` is `supertonic-3` (the neural voice that runs on the phone) or `native` (the phone's own voice); `voice` is the Supertonic voice, `language` its language, `steps` its denoising steps and `rate` its speed. `fallback` is for the phone's native voice, which the app uses when the phone cannot run Supertonic. The app ignores a `voiceConfig` it does not understand and falls back to its built-in defaults, so an older app keeps working and a newer one does not break against an older backend. The choice of engine on each phone is made by the app ([decision](decisions.md#2026-10-21--voice-supertonic-3-on-the-phone-voice-f4-s6-1)).

---

### `POST /v1/onboarding`

Records the explicit data consent and marks onboarding as done (US-02). Called once, at the end of onboarding.

**Request**

~~~json
{ "dataConsent": true, "remindersEnabled": true }
~~~

| Field | Type | Rules |
|---|---|---|
| `dataConsent` | boolean | Required, must be `true`. Onboarding cannot finish without consent. |
| `remindersEnabled` | boolean | Required. The user's answer to the reminders offer; `false` has no consequences. |

**Response `200`**: the updated profile, same shape as `GET /v1/me`, with `onboardingCompleted: true`.

**Errors:** `400 VALIDATION_ERROR` if `dataConsent` is not `true`; `409 ONBOARDING_ALREADY_COMPLETED`.

---

### `PATCH /v1/settings`

Changes the user's settings. Only the fields sent are changed.

**Request**

~~~json
{ "remindersEnabled": false }
~~~

| Field | Type | Rules |
|---|---|---|
| `remindersEnabled` | boolean | Optional. Daily reminders on or off (US-14). The phone schedules or cancels them locally. |

**Response `200`**

~~~json
{ "remindersEnabled": false }
~~~

---

### `POST /v1/chat`

Sends a message to marlix and returns the reply. It runs the full flow of the [sequence diagram](diagrams/chat-sequence.md): auth, daily limit, crisis filter, prompt with memory, model, reply review and save.

**Request**

~~~json
{
  "message": "Hoy me fue mejor en el trabajo",
  "mode": "text",
  "interruptedMessageId": null
}
~~~

| Field | Type | Rules |
|---|---|---|
| `message` | string | Required. 1 to 2,000 characters after trimming spaces. In voice mode it is the text from the phone's speech recognizer. |
| `mode` | `"text"` \| `"voice"` | Optional, default `"text"`. In `"voice"` the model is asked for one to three short sentences, as people talk, and the reply is cleaned of emojis, markdown and symbols before it is reviewed, saved and returned, because the phone reads it aloud (US-11, S6-3). `"text"` changes nothing. |
| `interruptedMessageId` | UUID \| null | Optional. The assistant message the user interrupted by talking (US-12). It stays in the history marked as interrupted. |

**Response `200`, normal reply** (`Accept: application/json`, the default)

~~~json
{
  "type": "reply",
  "tone": "positive",
  "userMessage": {
    "id": "c2a7e9b0-4f3d-4a1e-9b8c-7d6e5f4a3b21",
    "role": "user",
    "content": "Hoy me fue mejor en el trabajo",
    "createdAt": "2026-09-30T18:00:00Z"
  },
  "reply": {
    "id": "f1e2d3c4-b5a6-4978-8a9b-0c1d2e3f4a5b",
    "role": "assistant",
    "content": "¡Qué dicha! Contame, ¿qué fue lo que salió mejor?",
    "createdAt": "2026-09-30T18:00:02Z",
    "interrupted": false
  },
  "usage": { "used": 13, "limit": 100, "remaining": 87, "resetsAt": "2026-10-01T06:00:00Z" }
}
~~~

**Response `200`, crisis**

~~~json
{
  "type": "crisis",
  "tone": "neutral",
  "userMessage": {
    "id": "a9b8c7d6-e5f4-4321-8a7b-6c5d4e3f2a1b",
    "role": "user",
    "content": "…",
    "createdAt": "2026-09-30T18:05:00Z"
  },
  "reply": {
    "id": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
    "role": "assistant",
    "content": "Lo que me contás suena muy duro, y me importa de verdad. …",
    "createdAt": "2026-09-30T18:05:00Z",
    "interrupted": false
  },
  "resources": [
    { "id": "911", "name": "9-1-1", "phone": "911", "service": "Atención inmediata ante emergencias o situaciones de riesgo", "hours": "24 horas, 7 días de la semana", "primary": true }
  ],
  "usage": { "used": 13, "limit": 100, "remaining": 87, "resetsAt": "2026-10-01T06:00:00Z" }
}
~~~

`tone` is the tone of the user's message, `positive` or `neutral`, so the app can make the avatar celebrate (S5-4). It is computed with simple rules over words and emojis, never by the model, so it adds no latency or Groq quota. It is `positive` only for a short message with a clear happy phrase and no negation or doubt ("no me siento bien" and "estoy bien, pero cansado" are `neutral`); anything uncertain is `neutral`, because celebrating next to someone who is struggling is worse than staying calm. A crisis is always `neutral`.

`usage` is missing from a response when the database cannot be read right after the reply or the crisis was produced: the person still gets it, and the app keeps the last usage it knew.

The reply is the fixed crisis text from configuration. `resources` has the same shape as in `GET /v1/help-resources`, so the app can show a button that dials directly. The message never reached the conversation model.

**Streaming** (`Accept: text/event-stream`, voice mode only)

Voice mode asks for the reply as a stream so the avatar can start speaking with the first sentence while the model keeps writing (US-11, S6-10). `"text"` mode ignores the header and answers JSON, because a text reply keeps its paragraphs. The response is [Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html), and each event's `data` is JSON:

| Event | `data` | When |
|---|---|---|
| `sentence` | `{ "index": 0, "text": "¡Qué dicha!" }` | Each sentence, once it is complete, cleaned like a voice reply (S6-3) and passed the review (S2-4). |
| `done` | Same body as the JSON `200` reply, with the full saved reply. | At the end. The stream closes. |
| `crisis` | Same body as the JSON crisis reply. | Instead of any `sentence`. The stream closes. |
| `error` | Same body as an error response. | If the model fails after the first `sentence`. The stream closes. |

~~~text
event: sentence
data: {"index":0,"text":"¡Qué dicha!"}

event: sentence
data: {"index":1,"text":"Contame, ¿qué fue lo que salió mejor?"}

event: done
data: {"type":"reply","userMessage":{…},"reply":{…},"usage":{…}}
~~~

Everything that can fail before the first event still answers with a normal JSON error and HTTP status, not with a stream: validation, auth, the daily limit and a model that fails before saying anything (`503`, with `Retry-After` when Groq asks for it). The stream only opens with its first event.

A sentence that fails the review is never sent. The safe reply is sent as the next `sentence` instead, the rest of the model's reply is dropped, and the stream ends with `done`. The sentences already sent passed the review, so `reply.content` of `done` is those sentences followed by the safe reply, exactly what the person heard. If the model fails after sending sentences, the stream ends with `error` and the turn is neither saved nor counted. If the app disconnects, the model call is cancelled and nothing is saved. A model failure is retried only while nothing was sent.

Both messages of a turn are saved before the reply is returned, and `userMessage.id` and `reply.id` are the ids the history gives them. A reply that cannot be saved is not returned: the answer is `500 INTERNAL_ERROR`, and nothing is counted. The one exception is a crisis, which is always answered with its fixed reply even if saving fails; in that case it is missing from the history. `interruptedMessageId` must be the id of one of the caller's own assistant messages, otherwise `404 NOT_FOUND`; that message is then marked `interrupted` in the history. A crisis ignores it.

**What the model sees.** The system prompt, then the last messages of the user's open conversation (16 by default, `CHAT_CONTEXT_MESSAGES`), then the new message. The rest of the history is only for the app to show. The messages of a crisis, the user's and the fixed reply, are never part of it ([decision](decisions.md)). If the context cannot be read, the answer is `500 INTERNAL_ERROR` before the model is called.

**Errors:** `400 VALIDATION_ERROR`, `401 UNAUTHORIZED`, `404 NOT_FOUND` (unknown `interruptedMessageId`), `500 INTERNAL_ERROR`, `429 DAILY_LIMIT_REACHED`, `429 RATE_LIMITED`, `503 LLM_UNAVAILABLE`. A `503` caused by Groq's quota comes with a `Retry-After` header in seconds.

---

### `POST /v1/transcribe`

Turns what the person said in the voice mode into text (S6-9). The app records each turn on the phone, with echo cancellation, and sends it here; the text then goes through `POST /v1/chat` like typed text, so the crisis filter applies equally. The model is Whisper in Groq (`GROQ_TRANSCRIPTION_MODEL`), in Spanish, with a prompt that spells Costa Rican words such as "mae" and "tuanis". The stretches that Whisper itself doubts are speech (a fan, the street) are dropped, so `text` can come back empty ([decision](decisions.md#2026-10-28--talking-without-buttons-whisper-in-groq-and-a-detector-of-turns-s6-9)).

**Request.** The body is the audio itself, not JSON: `Content-Type: audio/wav`, WAV 16 kHz, mono, 16-bit PCM, between 0.25 and 32 seconds (the app sends 30 s at most). A body that is not that format, is empty, is too short or is over the size of 32 s answers `400 VALIDATION_ERROR`.

**Response `200`**

~~~json
{ "text": "mae, tuanis, cuéntame más" }
~~~

`text` is empty when nothing was said. The phrases Whisper invents on silence ("Gracias por ver el video") are dropped, so the app treats an empty `text` as a turn without words and sends nothing to the chat.

**Errors.** `401 UNAUTHORIZED`; `429 DAILY_LIMIT_REACHED` once the day's interactions are used, because the chat would refuse the answer anyway; `429 RATE_LIMITED` above 20 requests per minute per user, apart from the chat's own limit; `503 LLM_UNAVAILABLE` when Groq fails, times out (`TRANSCRIPTION_TIMEOUT_MS`) or its shared quota runs out (with `Retry-After` when Groq says how long).

A transcription does **not** count as an interaction: only the chat message that follows does. But it does use Groq's shared quota, 2,000 requests and 28,800 seconds of audio per day for the whole project, so it is limited apart from the chat.

**Privacy.** The audio and the text are never saved or logged, here or by Groq (zero data retention). The audio only lives in memory while the request lasts.

---

### `GET /v1/history`

Returns the user's messages, newest page first, for the single continuous chat (US-06). Messages older than 90 days no longer exist: a job deletes them every hour ([policy](memory.md#how-long-messages-are-kept)), so one can still show for up to an hour after its deadline.

**Query parameters**

| Parameter | Rules |
|---|---|
| `limit` | Optional, 1 to 100, default 50. |
| `before` | Optional cursor from `nextCursor` to load older messages. It is opaque: send it back as received. A value the API did not issue answers `400 VALIDATION_ERROR`. |

Any other parameter answers `400 VALIDATION_ERROR` too.

**Response `200`**

~~~json
{
  "messages": [
    {
      "id": "c2a7e9b0-4f3d-4a1e-9b8c-7d6e5f4a3b21",
      "role": "user",
      "content": "Hoy me fue mejor en el trabajo",
      "createdAt": "2026-09-30T18:00:00Z",
      "interrupted": false
    },
    {
      "id": "f1e2d3c4-b5a6-4978-8a9b-0c1d2e3f4a5b",
      "role": "assistant",
      "content": "¡Qué dicha! Contame, ¿qué fue lo que salió mejor?",
      "createdAt": "2026-09-30T18:00:02Z",
      "interrupted": false
    }
  ],
  "nextCursor": "MjAyNi0wOS0yOVQxMjowMDowMFo"
}
~~~

`messages` within a page are in chronological order (oldest first), ready to render. `nextCursor` is `null` when there are no older messages. The first page (no `before`) holds the newest messages, so opening the chat loads that one and scrolling up loads the rest. Crisis messages and their fixed reply are part of the history. Nothing of the content is logged.

---

### `GET /v1/usage`

Returns today's usage, so the app can show the interactions left (US-10).

**Response `200`**

~~~json
{ "plan": "personal", "used": 13, "limit": 100, "remaining": 87, "resetsAt": "2026-10-01T06:00:00Z" }
~~~

`resetsAt` is the next midnight in Costa Rica time, expressed in UTC.

The count is the `daily_usage` row of the user for the Costa Rica day and the cap is the `daily_interactions` of their plan in `plan_limits` ([decision](decisions.md#2026-10-17--usage-in-the-database-an-atomic-function-and-a-cap-read-every-minute-s4-13)). A restart or a deploy does not reset it, and a cap changed in `plan_limits` applies within a minute, with no deploy. If the database cannot be read the answer is `500 INTERNAL_ERROR`.

---

### `GET /v1/memories`

Lists everything marlix remembers about the user, for the "What marlix knows about me" screen (US-08).

**Response `200`**

~~~json
{
  "memories": [
    {
      "id": "d4c3b2a1-0f9e-4d8c-b7a6-958473625140",
      "fact": "Tiene un perro llamado Coco",
      "category": "pets",
      "createdAt": "2026-09-28T20:00:00Z",
      "updatedAt": "2026-09-28T20:00:00Z"
    }
  ]
}
~~~

Ordered newest first. `category` can be `null`.

---

### `PATCH /v1/memories/:id`

Edits the text of one memory. The change is used from the next message on.

**Request**

~~~json
{ "fact": "Tiene una perrita llamada Coco" }
~~~

| Field | Type | Rules |
|---|---|---|
| `fact` | string | Required. 1 to 500 characters after trimming spaces. |

**Response `200`**: the updated memory, same shape as in `GET /v1/memories`.

**Errors:** `400 VALIDATION_ERROR`, `404 NOT_FOUND`. The `404` is also the answer for an id that is not a UUID or belongs to another user.

---

### `DELETE /v1/memories/:id`

Deletes one memory for good. It is no longer sent to the model from the next message on.

**Response `204`**, no body. **Errors:** `404 NOT_FOUND`.

---

### `DELETE /v1/memories`

Deletes all of the user's memories. The app asks for confirmation before calling it.

**Response `204`**, no body.

---

### `GET /v1/avatars`

Lists the available avatars. In v1 there is one; the endpoint is ready for more in v2 without changes.

**Response `200`**

~~~json
{
  "avatars": [
    {
      "id": "0b8e5d2a-7c41-4f0e-8d2b-3a9c1e7f6b54",
      "slug": "marlix",
      "name": "marlix",
      "voiceConfig": {
        "engine": "supertonic-3",
        "voice": "F4",
        "language": "es",
        "steps": 5,
        "rate": 1.05,
        "fallback": { "voice": "default", "pitch": 1.0, "rate": 1.0 }
      },
      "layersPath": "assets/avatars/marlix/",
      "isDefault": true
    }
  ]
}
~~~

The app reads `voiceConfig` for the on-device voice (same shape as in [`GET /v1/me`](#get-v1me)) and `layersPath` for the SVG layers.

---

### `DELETE /v1/account`

Deletes the account and all its data in cascade: profile, sessions, messages, memories and usage (US-09). It runs on the backend because it needs the service key. The app asks for confirmation before calling it and signs out after the response.

**Requires a recent sign-in.** Deleting everything cannot be undone, so a stolen or forgotten-open session must not be enough. The backend checks when the person last entered their credentials: the newest `timestamp` of the access token's `amr` claim. If it is more than **5 minutes** old, or the token has none, it answers `401 REAUTHENTICATION_REQUIRED` and deletes nothing. The app then asks for the password again (a new Supabase sign-in, which puts a fresh time in the token) and retries the call. The `iat` claim is not used: Supabase renews it with every token refresh, so a refresh token would be enough to look like a recent sign-in ([decision](decisions.md)).

**Response `204`**, no body. After it, the user cannot sign in with that account. Calling it again with a token that is still valid also answers `204`. Such a token keeps passing the session check until it expires (up to an hour), but there is nothing left to read, and anything it tries to write is refused by the database because the user no longer exists.

**Errors:** `401 UNAUTHORIZED` (missing or invalid token), `401 REAUTHENTICATION_REQUIRED` (the last sign-in is older than 5 minutes).

## Use cases covered

Every use case from the [use case diagram](use-cases.md) runs with these endpoints, with Supabase Auth, or entirely on the phone or the backend:

| Use case | How |
|---|---|
| UC-01 Sign up / sign in | Supabase Auth from the app, then `GET /v1/me` |
| UC-02 Complete onboarding | `GET /v1/me` (is it pending?), then `POST /v1/onboarding` |
| UC-03 Chat by text | `POST /v1/chat` with `mode: "text"` |
| UC-04 Talk by voice | `POST /v1/chat` with `mode: "voice"` and streaming |
| UC-05 Open help / call 9-1-1 | `GET /v1/help-resources` (cached); the call is made by the phone |
| UC-06 View conversation history | `GET /v1/history` |
| UC-07 View remaining interactions | `GET /v1/usage`, also returned by every `POST /v1/chat` |
| UC-08 Manage memories | `GET`, `PATCH` and `DELETE` on `/v1/memories` |
| UC-09 Configure reminders | `PATCH /v1/settings`; the phone schedules them |
| UC-10 Delete account | `DELETE /v1/account` |
| UC-11 Give data consent | `POST /v1/onboarding` with `dataConsent: true` |
| UC-12 Interrupt the avatar | The phone stops the voice; the next `POST /v1/chat` sends `interruptedMessageId` |
| UC-13 Enforce daily limit | Inside `POST /v1/chat` (`429 DAILY_LIMIT_REACHED`) |
| UC-14 Check crisis signals | Inside `POST /v1/chat`, before the model |
| UC-15 Show crisis response | `POST /v1/chat` answers `200` with `type: "crisis"` |
| UC-16 Distill memory | Backend background job, no endpoint |
| UC-17 Send daily reminder | Local notification on the phone, no endpoint |
| UC-18 Delete messages older than 90 days | Backend scheduled job, no endpoint |

## Out of scope

Implementing the endpoints (starts in Sprint 1). Sign-up, sign-in and password reset, which are handled by Supabase Auth.
