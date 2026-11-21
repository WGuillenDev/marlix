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

The backend URL and the Supabase project are not in the code: they come from a file in `app/config/`, and the app refuses to start without valid ones. The app uses Supabase Auth for accounts, email verification, password recovery and sessions, with the project's publishable key, which is public by design; the secret key never goes in the app.

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
| `node tool/verify-integration.mjs local` or `node tool/verify-integration.mjs staging` | Runs the emulator integration suite against an isolated environment. See [Integration tests](#integration-tests). |
| `flutter build apk --release --dart-define-from-file=config/production.json` | Builds the release APK against production. Test voice mode on a release build too: R8 shrinks it and the debug build does not. |
| `dart format lib test integration_test` | Formats the code (100 columns). |

### Integration tests

With Node.js 24 available, run `flutter pub get` in `app/` and start the Android emulator. Configure the app and backend to use the same isolated Supabase project with email autoconfirm enabled. The suite creates and deletes its own test account and uses one Groq chat request. Verify the real email-code flow separately using a controlled mailbox.

- **Local API:** Copy `config/local.example.json` to `config/integration.local.json`. Use the local API URL from the emulator and the isolated project's Supabase URL and publishable key. Run `node tool/verify-integration.mjs local` from `app/`.
- **Staging API:** Copy `config/staging.example.json` to `config/staging.json` and use with the staging HTTPS API URL and that project's Supabase URL and publishable key. Run `node tool/verify-integration.mjs staging` from `app/`.

Add `--check` to either command to validate the configuration before contacting a service or starting Flutter. The runner rejects the production API host, Supabase host and publishable key from `config/production.json`. The integration suite checks autoconfirm before creating its test account. Record the command and result in the pull request; keep environment files and test credentials local.

### Signing the release

Without `app/android/key.properties` the release build uses the debug key: fine for `flutter run --release`, never for an APK you hand to someone. To sign it with your own key:

1. Create the key outside the repository and keep at least two copies of it. If it is lost, no update of the app can be installed over the old one.
   ~~~powershell
   keytool -genkeypair -v -keystore "$env:USERPROFILE\marlix-keys\marlix-release.jks" -alias marlix -keyalg RSA -keysize 2048 -validity 10000
   ~~~
2. Copy `app/android/key.properties.example` to `app/android/key.properties` and fill in the path and the passwords. Git ignores it and every `.jks`.
3. Build with `flutter build apk --release --dart-define-from-file=config/production.json`.
4. Check the signer: `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk` (in the Android SDK `build-tools`). It must show your certificate, not `Android Debug`.

To publish an update, raise the number after `+` in `app/pubspec.yaml`, build, and attach the APK to a new GitHub Release.

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

## Staging

Staging is a second Render service, `marlix-api-staging` in [`render.yaml`](../render.yaml), backed by its own Supabase project. It shares no key with production. Use it for the email acceptance test, the restore drill, migration rehearsals and the Sala rehearsal.

- **No automatic deploys.** `autoDeployTrigger` is `off`: deploy a branch or commit by hand (**marlix-api-staging → Manual Deploy → Deploy a specific commit**) before merging it. Production keeps deploying from `main`.
- **It sleeps.** The free plan allows 750 instance hours a month per workspace, so only production stays awake. The first request after a pause can take up to a minute.
- **Create it once.** (1) Create a second Supabase project. In its SQL Editor run [`schema.sql`](schema.sql), then [`verify-migrations.sql`](verify-migrations.sql): every row must say `ok`. Apply the Auth settings of the [production table](#supabase-project), plus `Confirm email` off while the integration suite runs. (2) In Render, create the service from the Blueprint and set `SUPABASE_URL`, `SUPABASE_SECRET_KEY` and `GROQ_API_KEY` to staging values. (3) Add the repository secret `STAGING_DATABASE_URL`, the project's connection string.
- **Keepalive.** [`staging-keepalive.yml`](../.github/workflows/staging-keepalive.yml) runs `select 1` on Mondays and Thursdays so the free project does not pause. Run it once by hand from the Actions tab to check the secret.
- **App.** `config/staging.json` (not committed) points the app at staging; see [Integration tests](#integration-tests).

### Low-end AVD

Every performance check uses this Android Virtual Device. Define it here and nowhere else.

| Setting | Value |
|---|---|
| System image | API 31 (Android 12), Google APIs, x86_64 |
| RAM | 2 GB |
| CPU cores | 2 |
| Graphics | Software (SwiftShader) |

Create it with Android Studio's Device Manager, or with `avdmanager create avd -n marlix-lowend -k "system-images;android-31;google_apis;x86_64"` and then set `hw.ramSize=2048`, `hw.cpu.ncore=2` and `hw.gpu.mode=swiftshader_indirect` in its `config.ini`.

## Supabase project

Production data and accounts live in the Supabase project. Changes to the schema after it was created are in [`docs/migrations/`](migrations/): run each file once, in order, in the **SQL Editor**. [`docs/schema.sql`](schema.sql) already includes them for a new database.

Sign-up uses email and password, with these settings in **Authentication → Sign In / Providers → Email** ([decision](decisions.md)):

| Setting | Value | Why |
|---|---|---|
| Confirm email | On | New accounts confirm their email with a code entered in the app (S7-9). |
| Minimum password length | 8 | The same minimum the app checks. |
| Email OTP length | 6 | The confirmation and recovery forms accept six digits. |
| Email OTP expiration | 3600 seconds | Supabase expires confirmation and recovery codes after one hour. |

The minimum age is enforced in the database: the sign-up trigger in the schema refuses anyone under 18, whatever client calls Supabase Auth.

S7-9 enables confirmation and recovery with codes typed in the app. Production uses custom SMTP, `Confirm email` on, six-digit email OTPs, and the confirmation and recovery templates in `infra/auth/`, which use `{{ .Token }}` without links. On 2026-11-04, real-mailbox tests in the Pixel_8 emulator verified sign-up confirmation, recovery, a new password and subsequent sign-in. Existing users remain confirmed. Older app versions cannot handle a sign-up without a session; new installations need the updated app. The app requests a fresh code after expiry and waits 60 seconds before resend; Supabase enforces the actual rate limits. Recovery sessions exist only in memory, outside the normal persisted session, and finish with password sign-in. See the [S7-9 decision](decisions.md#2026-11-04--email-confirmation-and-password-recovery-use-codes-inside-the-app-s7-9).

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
