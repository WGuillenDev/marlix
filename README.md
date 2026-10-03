# marlix 🐾

Open source mobile app for conversational companionship with an AI avatar.

marlix is designed for people facing social isolation who need accessible emotional support. It keeps them company without fostering dependency: it encourages users to connect with the people in their lives.

> **marlix is not therapy and does not replace professional mental health care.**
> In Costa Rica, call **9-1-1** (free, 24/7) for psychological support.

## Status

🚧 Early development. Design is finished (Sprint 0, see the [changelog](CHANGELOG.md)); Sprint 1, the backend, is in progress. The [backend](#backend) starts and answers its health check, and the [local database](#local-database) runs; the app does not run yet.

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

Setup instructions for the app (`app/`) will be added when it is initialized.

### Backend

Requirements: [Node.js](https://nodejs.org/) 24 or later.

1. Install the dependencies and copy the example environment file:
   ~~~bash
   cd api
   npm install
   cp .env.example .env
   ~~~
2. Start the server with automatic reload:
   ~~~bash
   npm run dev
   ~~~
3. Check that it answers:
   ~~~bash
   curl http://localhost:3000/health
   # {"status":"ok"}
   ~~~

| Variable | Required | Default | What it is |
|---|---|---|---|
| `PORT` | No | `3000` | Port the API listens on. |
| `GROQ_API_KEY` | Yes | — | Groq API key, from [console.groq.com/keys](https://console.groq.com/keys). Only the backend holds it. |
| `GROQ_MODEL` | Yes | `openai/gpt-oss-120b` | Model used for the conversation. Groq retires models: change it here, not in code. |

| Command | What it does |
|---|---|
| `npm run dev` | Starts the server and restarts it on every change. |
| `npm run typecheck` | Checks the types in strict mode without emitting files. |
| `npm run build` | Compiles TypeScript to `dist/`. |
| `npm start` | Runs the compiled server from `dist/`. |

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
| [Technical decisions](docs/decisions.md) | Each choice between technical options, what was discarded and why. |

Rules every change must follow are in [CONTRIBUTING.md](CONTRIBUTING.md); security reporting is in [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
