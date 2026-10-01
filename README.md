# marlix 🐾

Open source mobile app for conversational companionship with an AI avatar.

marlix is designed for people facing social isolation who need accessible emotional support. It keeps them company without fostering dependency: it encourages users to connect with the people in their lives.

> **marlix is not therapy and does not replace professional mental health care.**
> In Costa Rica, call **9-1-1** (free, 24/7) for psychological support.

## Status

🚧 Early development (Sprint 0 — Design). Nothing runs yet.

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

Setup instructions for the backend (`api/`) and the app (`app/`) will be added when they are initialized.

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
