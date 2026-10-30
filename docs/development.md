# Development guide

How to run, test and deploy marlix: the app, the backend, the Supabase project and the local database. The overview is in the [README](../README.md).

## App

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
| `flutter test` | Runs the automated tests. The [CI](../.github/workflows/ci.yml) also runs them, with the format check and `flutter analyze`, on every pull request. |
| `flutter test integration_test --dart-define-from-file=config/local.json` | Calls every backend endpoint from the app on the emulator. It signs up its own throwaway account (`it-…@marlix.test`) and deletes it with `DELETE /v1/account` at the end, even if a test fails, so it leaves no data in the database. It sends two chat messages; one uses the Groq quota. |
| `flutter build apk --release --dart-define-from-file=config/production.json` | Builds the release APK against production. Test voice mode on a release build too: R8 shrinks it and the debug build does not. |
| `dart format lib test integration_test` | Formats the code (100 columns). |

## Backend

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
   The response follows the [API contract](api-contract.md#post-v1chat).

The server validates its variables when it starts: if a required one is missing or invalid, it does not start and prints the name of the variable (never its value). These four are required:

| Variable | What it is |
|---|---|
| `GROQ_API_KEY` | Groq API key, from [console.groq.com/keys](https://console.groq.com/keys). Only the backend holds it. |
| `GROQ_MODEL` | Model for the conversation (`openai/gpt-oss-120b`). Groq retires models: change it here, not in code. |
| `SUPABASE_URL` | The project URL, `https://<project-ref>.supabase.co`, without `/rest/v1`. |
| `SUPABASE_SECRET_KEY` | Secret key starting with `sb_secret_`. It bypasses RLS: only the backend holds it, never share it. |

The rest are optional and have safe defaults: timeouts, the crisis classifier and memory models, the chat context, the message retention and the transcription model. Each one is explained in [`api/.env.example`](../api/.env.example).

| Command | What it does |
|---|---|
| `npm run dev` | Starts the server and restarts it on every change. |
| `npm run typecheck` | Checks the types in strict mode without emitting files. |
| `npm test` | Runs the automated tests. The [CI](../.github/workflows/ci.yml) also runs them, with the type check and the build, on every pull request. |
| `npm run llm:smoke` | Sends one real message to the configured LLM and prints the reply. `-- --burst 6` sends several at once to check that a quota error (429) is handled. Spends real quota. |
| `npm run crisis:eval` | Runs the crisis test cases through the real filter, classifier included, and reports false negatives and false positives. Spends real quota. |
| `npm run build` | Compiles TypeScript to `dist/`. |
| `npm start` | Runs the compiled server from `dist/`. |

## Deployment

The backend runs on [Render](https://render.com) (free plan), defined in [`render.yaml`](../render.yaml). Every push to `main` that changes `api/` deploys automatically, once the [CI](../.github/workflows/ci.yml) checks of that commit pass; a commit with a failed check is never deployed.

Usage limits: 100 replies a day per person, resetting at midnight Costa Rica time, and 5 messages per minute. The daily count and cap live in the database (`daily_usage` and `plan_limits`), so a restart does not reset them and the cap changes without a deploy; the per-minute limit is in [`api/config/plans.json`](../api/config/plans.json). Reaching one answers `429`, as described in the [API contract](api-contract.md#errors).

**Production URL:** https://marlix-api.onrender.com

| Endpoint | Access |
|---|---|
| `GET /health` | Public. Used by the uptime monitor; says `degraded` if the usage counter fails. |
| `GET /v1/help-resources` | Public. The help resources the app shows, from `api/config/crisis.json`. |
| Rest of `/v1/*` | Only with a Supabase session, `Authorization: Bearer <access token>`; anything else gets `401`. Each account has its own daily limit. |

The free plan sleeps the service after about 15 minutes without traffic, so the first request after a pause can take up to a minute.

To create the service the first time: in the Render dashboard, **New → Blueprint**, pick this repository and confirm. Render asks for `GROQ_API_KEY` (use a production key, not your local one), `SUPABASE_URL` and `SUPABASE_SECRET_KEY`.

## Supabase project

Production data and accounts live in the Supabase project. Changes to the schema after it was created are in [`docs/migrations/`](migrations/): run each file once, in order, in the **SQL Editor**. [`docs/schema.sql`](schema.sql) already includes them for a new database.

Sign-up uses email and password, with these settings in **Authentication → Sign In / Providers → Email** ([decision](decisions.md)):

| Setting | Value | Why |
|---|---|---|
| Confirm email | Off | The free email service sends about 2 emails an hour; confirmation comes with its own card (S7-9). |
| Minimum password length | 8 | The same minimum the app checks. |

The minimum age is enforced in the database: the sign-up trigger in the schema refuses anyone under 18, whatever client calls Supabase Auth.

## Local database

The database runs locally in Docker with the same Postgres image Supabase uses in production, so [`docs/schema.sql`](schema.sql) behaves the same as in the cloud. Production runs on Supabase cloud; Docker is only for development.

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
