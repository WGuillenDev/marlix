# marlix 🐾

[![CI](https://github.com/WGuillenDev/marlix/actions/workflows/ci.yml/badge.svg)](https://github.com/WGuillenDev/marlix/actions/workflows/ci.yml)

Open source mobile app for conversational companionship with an AI avatar.

marlix is designed for people facing social isolation who need accessible emotional support. It keeps them company without fostering dependency: it encourages users to connect with the people in their lives.

> **marlix is not therapy and does not replace professional mental health care.**
> In Costa Rica, call **9-1-1** (free, 24/7) for psychological support.

## Status

🚧 Early development. Design (Sprint 0), the backend base (Sprint 1), security (Sprint 2) and the chat app (Sprint 3) are finished; see the [changelog](CHANGELOG.md). The [app](#app) chats with the [backend](#backend), which is [deployed](#deployment) with the [crisis filter](docs/crisis-protocol.md), the reply review and the usage limits; the app has the help screen with 9-1-1, also offline. The [CI](.github/workflows/ci.yml) tests the backend, the app and the database on every pull request. `/v1` stays behind a development token until accounts exist (S4-3; see the [decision](docs/decisions.md)), so the app is not shared yet. There are no accounts, history or memory yet: that is Sprint 4. The [local database](#local-database) runs.

## Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android first) |
| Backend | Node.js + TypeScript + Express |
| Database and auth | Supabase (PostgreSQL) |
| LLM | Groq |
| Avatar voice (TTS) | Supertonic 3, on device |
| Speech recognition | Device recognizer |

## Repository structure

~~~
marlix/
├── app/                 # Flutter app
├── api/                 # Node + TypeScript backend
├── docs/                # Project documentation
├── infra/               # Local development config (pgAdmin)
└── docker-compose.yml   # Local database
~~~

## Getting started

### App

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) stable (3.47 or later) and [Android Studio](https://developer.android.com/studio) with an Android emulator, or an Android phone over USB with developer mode on.

1. Install the dependencies:
   ~~~bash
   cd app
   flutter pub get
   ~~~
2. Start an emulator from Android Studio (**Device Manager → ▶**) and run the app against the production backend:
   ~~~bash
   flutter run --dart-define-from-file=config/production.json
   ~~~

The backend URL and the Supabase project are not in the code: they come from a file in `app/config/`, and the app refuses to start without valid ones. The app uses Supabase only to sign up and sign in, with the project's publishable key, which is public by design; the secret key never goes in the app.

| File | Backend | In Git |
|---|---|---|
| `config/production.json` | https://marlix-api.onrender.com | Yes |
| `config/local.json` | Your own backend (`npm run dev`), copied from `config/local.example.json`. From the emulator, your computer is `10.0.2.2`. Use the same `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as `config/production.json`. | No |

Plain `http` is only accepted in debug builds, for a backend on your computer; a release build always uses HTTPS.

The app opens on the sign-in screen. Create an account there (you must be 18 or older); the session is kept, encrypted, until you sign out in **Ajustes**. There you can also delete the account and all its data for good; it asks for your password again if you signed in more than 5 minutes ago.

| Command (in `app/`) | What it does |
|---|---|
| `flutter analyze` | Checks the code with the project's lint rules. |
| `flutter test` | Runs the automated tests. The [CI](.github/workflows/ci.yml) also runs them, with the format check and `flutter analyze`, on every pull request. |
| `flutter test integration_test --dart-define-from-file=config/local.json --dart-define-from-file=config/test-account.json` | Signs in with a test account and calls every backend endpoint from the app on the emulator. Create the account in the app first, then copy `config/test-account.example.json` to `config/test-account.json` (ignored by Git) and fill it in. It sends two chat messages; one uses the Groq quota. |
| `dart format lib test integration_test` | Formats the code (100 columns). |

### Backend

Requirements: [Node.js](https://nodejs.org/) 24 or later.

1. Install the dependencies and copy the example environment file:
   ~~~bash
   cd api
   npm install
   cp .env.example .env
   ~~~
   Then fill in `GROQ_API_KEY` and the Supabase variables.
2. Start the server with automatic reload:
   ~~~bash
   npm run dev
   ~~~
3. Check that it answers:
   ~~~bash
   curl http://localhost:3000/health
   # {"status":"ok"}
   ~~~
4. Every `/v1` request except the help resources needs a session. Sign in to Supabase Auth with an account created in the app; `access_token` in the answer is the token, valid for one hour:
   ~~~bash
   curl -X POST "https://<project-ref>.supabase.co/auth/v1/token?grant_type=password" \
     -H "apikey: <SUPABASE_PUBLISHABLE_KEY>" \
     -H "Content-Type: application/json" \
     -d '{"email": "<your email>", "password": "<your password>"}'
   ~~~
5. Send a message to marlix with that token:
   ~~~bash
   curl -X POST http://localhost:3000/v1/chat \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <access_token>" \
     -d '{"message": "Hola, hoy tuve un buen día"}'
   ~~~
   The response follows the [API contract](docs/api-contract.md#post-v1chat).

The server validates these variables when it starts. If a required one is missing or invalid, it does not start and prints the name of the variable (never its value).

| Variable | Required | Default | What it is |
|---|---|---|---|
| `PORT` | No | `3000` | Port the API listens on. |
| `LLM_PROVIDER` | No | `groq` | LLM provider that answers the chat. Only `groq` exists for now; see [how to add one](docs/architecture.md#adding-an-llm-provider). |
| `LLM_TIMEOUT_MS` | No | `15000` | Milliseconds to wait for one LLM call. Timeouts, network errors and 5xx are retried once; quota and key errors are not. |
| `GROQ_API_KEY` | Yes | — | Groq API key, from [console.groq.com/keys](https://console.groq.com/keys). Only the backend holds it. |
| `GROQ_MODEL` | Yes | `openai/gpt-oss-120b` | Model used for the conversation. Groq retires models: change it here, not in code. |
| `GROQ_BASE_URL` | No | `https://api.groq.com/openai/v1` | Groq's OpenAI-compatible endpoint. Only changed for tests. |
| `GROQ_REASONING_EFFORT` | No | `low` | Reasoning effort for gpt-oss models (`low`, `medium`, `high`), or `none` for models that do not reason. |
| `CRISIS_CLASSIFIER_MODEL` | No | `openai/gpt-oss-20b` | Model that classifies ambiguous messages for the [crisis protocol](docs/crisis-protocol.md#the-second-layer). Different from the chat model, so it has its own quota. |
| `CRISIS_CLASSIFIER_TIMEOUT_MS` | No | `5000` | Longest wait for that classification. A timeout counts as a crisis. |
| `CHAT_CONTEXT_MESSAGES` | No | `16` | How many of the last messages of the conversation the model sees with each new one (2 to 40). Each one costs tokens of Groq's free quota: lower it if the limit is reached. |
| `CHAT_MEMORY_FACTS` | No | `30` | How many of the person's saved [memories](docs/memory.md#what-goes-into-the-prompt) go into the prompt with each message (1 to 50); if there are more, the most recently updated ones. |
| `CONVERSATION_IDLE_MINUTES` | No | `30` | A conversation without messages for this long has ended, and that starts the extraction of its [memory](docs/memory.md) (1 to 1440). |
| `MEMORY_EXTRACTOR_MODEL` | No | `openai/gpt-oss-20b` | Model that extracts the facts of a finished conversation. Smaller than the chat model, so the extractions do not use the chat's quota. |
| `MEMORY_EXTRACTOR_TIMEOUT_MS` | No | `30000` | Longest wait for one extraction. A failed one stays pending and is tried again. |
| `MESSAGE_RETENTION_DAYS` | No | `90` | Raw messages older than this are deleted by a job that runs every hour (1 to 3650). The distilled memory is kept as long as the account; see the [policy](docs/memory.md#how-long-messages-are-kept). |
| `SUPABASE_URL` | Yes | — | The Supabase project URL, `https://<project-ref>.supabase.co`, without the `/rest/v1` that Project Settings → Data API shows. Session tokens are checked against this project's public signing keys. |
| `SUPABASE_SECRET_KEY` | Yes | — | Supabase secret key, starting with `sb_secret_` (Project Settings → API Keys). It has `service_role` rights and bypasses RLS: only the backend holds it. Never share it. |

| Command | What it does |
|---|---|
| `npm run dev` | Starts the server and restarts it on every change. |
| `npm run typecheck` | Checks the types in strict mode without emitting files. |
| `npm test` | Runs the automated tests. The [CI](.github/workflows/ci.yml) also runs them, with the type check and the build, on every pull request. |
| `npm run llm:smoke` | Sends one real message to the configured LLM and prints the reply. `-- --burst 6` sends several at once to check that a quota error (429) is handled. Spends real quota. |
| `npm run crisis:eval` | Runs the crisis test cases through the real filter, classifier included, and reports false negatives and false positives. Spends real quota. |
| `npm run build` | Compiles TypeScript to `dist/`. |
| `npm start` | Runs the compiled server from `dist/`. |

### Deployment

The backend runs on [Render](https://render.com) (free plan), defined in [`render.yaml`](render.yaml). Every push to `main` that changes `api/` deploys automatically, once the [CI](.github/workflows/ci.yml) checks of that commit pass; a commit with a failed check is never deployed.

Usage limits per plan are in [`api/config/plans.json`](api/config/plans.json): 100 replies a day per person, resetting at midnight Costa Rica time, and 5 messages per minute. Reaching one answers `429`, as described in the [API contract](docs/api-contract.md#errors).

**Production URL:** https://marlix-api.onrender.com

| Endpoint | Access |
|---|---|
| `GET /health` | Public. Used by the uptime monitor. |
| `GET /v1/help-resources` | Public. The help resources the app shows, from `api/config/crisis.json`. |
| Rest of `/v1/*` | Only with a Supabase session, `Authorization: Bearer <access token>`; anything else gets `401`. Each account has its own daily limit. |

The free plan sleeps the service after about 15 minutes without traffic, so the first request after a pause can take up to a minute.

To create the service the first time: in the Render dashboard, **New → Blueprint**, pick this repository and confirm. Render asks for `GROQ_API_KEY` (use a production key, not your local one), `SUPABASE_URL` and `SUPABASE_SECRET_KEY`.

### Supabase project

Production data and accounts live in the Supabase project. Changes to the schema after it was created are in [`docs/migrations/`](docs/migrations/): run each file once, in order, in the **SQL Editor**. [`docs/schema.sql`](docs/schema.sql) already includes them for a new database.

Sign-up uses email and password, with these settings in **Authentication → Sign In / Providers → Email** ([decision](docs/decisions.md)):

| Setting | Value | Why |
|---|---|---|
| Confirm email | Off | The free email service sends about 2 emails an hour; confirmation comes with its own card (S7-9). |
| Minimum password length | 8 | The same minimum the app checks. |

The minimum age is enforced in the database: the sign-up trigger in the schema refuses anyone under 18, whatever client calls Supabase Auth.

### Local database

The database runs locally in Docker with the same Postgres image Supabase uses in production, so [`docs/schema.sql`](docs/schema.sql) behaves the same as in the cloud. Production runs on Supabase cloud; Docker is only for development.

Requirements: [Docker Desktop](https://www.docker.com/products/docker-desktop/) running.

1. Copy the example environment file and set your own passwords:
   ~~~bash
   cp .env.example .env
   ~~~
2. Start the database and pgAdmin:
   ~~~bash
   docker compose up -d --wait
   ~~~
   On the first start, with an empty volume, the schema in `docs/schema.sql` is applied automatically.

| Service | Address | User | Password |
|---|---|---|---|
| PostgreSQL | `localhost:54322`, database `postgres` | `postgres` | `POSTGRES_PASSWORD` in `.env` |
| pgAdmin | http://localhost:5050 | `PGADMIN_EMAIL` in `.env` | `PGADMIN_PASSWORD` in `.env` |

In pgAdmin the server **marlix (local)** is already registered; it asks for `POSTGRES_PASSWORD` the first time you open it. The tables are under *Databases → postgres → Schemas → public → Tables*.

| Command | What it does |
|---|---|
| `docker compose down` | Stops everything. The data is kept. |
| `docker compose down -v` | Stops everything and deletes the data. The next start applies the schema again from scratch. |
| `docker compose logs db` | Shows the database logs. |
| `docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - < docs/schema-test.sql` | Runs the privilege and RLS tests. Prints `All database tests passed.` and changes nothing. |

Both services only listen on `127.0.0.1`, and the data lives in Docker volumes outside the repository.

## Documentation

Design documents for v1, in the order they are usually read:

| Document | What it contains |
|---|---|
| [User stories](docs/user-stories.md) | What v1 does, as user stories with acceptance criteria and their backlog cards. |
| [Use cases](docs/use-cases.md) | UML use case diagram: actors, use cases and how they relate. |
| [Wireframes and visual style](docs/diagrams/wireframes/README.md) | Screens, navigation flow, color palette, typography and the avatar. |
| [Architecture](docs/architecture.md) | How the app, backend, Supabase, Groq and on-device voice fit together, and where the keys live. |
| [Entity-relationship diagram](docs/erd.md) | Data model, relationships, access rules and RLS. The SQL is in [`schema.sql`](docs/schema.sql). |
| [Chat sequence](docs/diagrams/chat-sequence.md) | Every step of sending a message, including the crisis filter and the daily limit. |
| [API contract](docs/api-contract.md) | Every v1 endpoint with its request, response, errors and examples. |
| [System prompt](docs/system-prompt.md) | marlix's personality, how memory is injected and the test conversations. |
| [Distilled memory](docs/memory.md) | How a finished conversation becomes lasting facts about the person, what is never saved and the limits. |
| [Crisis protocol](docs/crisis-protocol.md) | How the crisis filter classifies each message before the model, and what the crisis reply contains. |
| [Technical decisions](docs/decisions.md) | Each choice between technical options, what was discarded and why. |

Rules every change must follow are in [CONTRIBUTING.md](CONTRIBUTING.md); security reporting is in [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
