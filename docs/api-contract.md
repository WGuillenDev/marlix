# API contract — v1

Endpoints of the marlix backend for the MVP. The app and the backend are built against this contract, so any change to an endpoint updates this file in the same pull request.

See also the [chat sequence diagram](diagrams/chat-sequence.md), the [architecture](architecture.md) and the [ERD](erd.md).

## Conventions

| Topic | Rule |
|---|---|
| Base URL | `https://<backend-host>`. Every route except `/health` starts with `/v1`. A breaking change ships as `/v2`, so apps installed by APK keep working. |
| Format | JSON in and out (`Content-Type: application/json`), UTF-8. `POST /v1/chat` can also stream (see below). |
| Names | JSON fields in `camelCase`. IDs are UUIDs. Dates are ISO 8601 in UTC (`2026-09-30T18:00:00Z`). |
| Auth | `Authorization: Bearer <access token>`, the Supabase Auth session token the app gets on sign-in. Sign-up and sign-in happen against Supabase Auth, not this API. |
| Ownership | Every authenticated endpoint only reads or changes the caller's own data. Another user's ID returns `404`, never `403`, so the API does not reveal what exists. |
| Privacy | Request and response bodies are never logged. |

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

| HTTP | `code` | When | What the app does |
|---|---|---|---|
| 400 | `VALIDATION_ERROR` | The body or a parameter is invalid. `details.fields` lists each invalid field. | Fix the input. |
| 401 | `UNAUTHORIZED` | Missing, invalid or expired token. | Refresh the session or ask to sign in again. |
| 404 | `NOT_FOUND` | The resource does not exist or belongs to another user. | Refresh the list. |
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

**Public.** Tells whether the service is up. The uptime monitor calls it every 10 minutes (S7-6). It does not touch the database or Groq.

**Response `200`**

~~~json
{ "status": "ok" }
~~~

---

### `GET /v1/help-resources`

**Public**, so the help screen works before sign-in. Returns the Costa Rican help resources from configuration, not from code. The app caches the last response so the help screen also works offline (US-15).

**Response `200`**

~~~json
{
  "updatedAt": "2026-09-30T00:00:00Z",
  "resources": [
    {
      "id": "911",
      "name": "9-1-1, Despacho de Apoyo Psicológico",
      "phone": "911",
      "hours": "24/7, gratuito",
      "primary": true
    },
    {
      "id": "aqui-estoy",
      "name": "Aquí Estoy, Colegio de Psicólogos",
      "phone": "8002737869",
      "hours": "Horario limitado",
      "primary": false
    }
  ]
}
~~~

`phone` holds digits only, ready to dial. Exactly one resource has `primary: true` and the app shows it first. Names and hours are user-facing copy, so they are in Spanish.

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
    "name": "marlix"
  },
  "onboardingCompleted": false,
  "dataConsentAt": null,
  "settings": { "remindersEnabled": false }
}
~~~

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
| `remindersEnabled` | boolean | Optional. Inactivity reminders on or off (US-14). The phone schedules or cancels them locally. |

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
| `mode` | `"text"` \| `"voice"` | Optional, default `"text"`. In `"voice"` the model is asked for short, conversational replies (US-11). |
| `interruptedMessageId` | UUID \| null | Optional. The assistant message the user interrupted by talking (US-12). It stays in the history marked as interrupted. |

**Response `200`, normal reply** (`Accept: application/json`, the default)

~~~json
{
  "type": "reply",
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
    { "id": "911", "name": "9-1-1, Despacho de Apoyo Psicológico", "phone": "911", "hours": "24/7, gratuito", "primary": true }
  ],
  "usage": { "used": 13, "limit": 100, "remaining": 87, "resetsAt": "2026-10-01T06:00:00Z" }
}
~~~

The reply is the fixed crisis text from configuration. `resources` has the same shape as in `GET /v1/help-resources`, so the app can show a button that dials directly. The message never reached the conversation model.

**Streaming** (`Accept: text/event-stream`)

Voice mode asks for the reply as a stream so the avatar can start speaking with the first sentence (US-11). The response is [Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html), and each event's `data` is JSON:

| Event | `data` | When |
|---|---|---|
| `sentence` | `{ "index": 0, "text": "¡Qué dicha!" }` | Each sentence, once it passed the review (S2-4). |
| `done` | Same body as the JSON `200` reply, with the full saved reply. | At the end. The stream closes. |
| `crisis` | Same body as the JSON crisis reply. | Instead of any `sentence`. The stream closes. |
| `error` | Same body as an error response. | If something fails before `done`. The stream closes. |

~~~text
event: sentence
data: {"index":0,"text":"¡Qué dicha!"}

event: sentence
data: {"index":1,"text":"Contame, ¿qué fue lo que salió mejor?"}

event: done
data: {"type":"reply","userMessage":{…},"reply":{…},"usage":{…}}
~~~

Checks that happen before the model (auth, validation, daily limit) still answer with a normal JSON error and HTTP status, not with a stream. If a sentence fails the review, the stream sends an `error` or a safe fallback instead of that sentence; it never sends text that failed the review.

**Errors:** `400 VALIDATION_ERROR`, `401 UNAUTHORIZED`, `404 NOT_FOUND` (unknown `interruptedMessageId`), `429 DAILY_LIMIT_REACHED`, `429 RATE_LIMITED`, `503 LLM_UNAVAILABLE`.

---

### `GET /v1/history`

Returns the user's messages, newest page first, for the single continuous chat (US-06). Messages older than 90 days no longer exist.

**Query parameters**

| Parameter | Rules |
|---|---|
| `limit` | Optional, 1 to 100, default 50. |
| `before` | Optional cursor from `nextCursor` to load older messages. |

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

`messages` within a page are in chronological order (oldest first), ready to render. `nextCursor` is `null` when there are no older messages.

---

### `GET /v1/usage`

Returns today's usage, so the app can show the interactions left (US-10).

**Response `200`**

~~~json
{ "plan": "personal", "used": 13, "limit": 100, "remaining": 87, "resetsAt": "2026-10-01T06:00:00Z" }
~~~

`resetsAt` is the next midnight in Costa Rica time, expressed in UTC.

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

**Errors:** `400 VALIDATION_ERROR`, `404 NOT_FOUND`.

---

### `DELETE /v1/memories/:id`

Deletes one memory. It is no longer used in later conversations.

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
      "voiceConfig": { "voice": "default", "pitch": 1.0, "rate": 1.0 },
      "layersPath": "assets/avatars/marlix/",
      "isDefault": true
    }
  ]
}
~~~

The app reads `voiceConfig` for the on-device voice and `layersPath` for the SVG layers.

---

### `DELETE /v1/account`

Deletes the account and all its data in cascade: profile, sessions, messages, memories and usage (US-09). It runs on the backend because it needs the service key. The app asks for confirmation before calling it and signs out after the response.

**Response `204`**, no body. After it, the user cannot sign in with that account.

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
| UC-17 Send inactivity reminder | Local notification on the phone, no endpoint |
| UC-18 Delete messages older than 90 days | Backend scheduled job, no endpoint |

## Out of scope

Implementing the endpoints (starts in Sprint 1). Sign-up, sign-in and password reset, which are handled by Supabase Auth.
