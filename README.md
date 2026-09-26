# marlix 🐾

Open source mobile app for conversational companionship with an AI avatar.

Marlîx is designed for people facing social isolation who need accessible emotional support. It keeps them company without fostering dependency: it encourages users to connect with the people in their lives.

> **Marlîx is not therapy and does not replace professional mental health care.**
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

marlix/
├── app/   # Flutter app
├── api/   # Node + TypeScript backend
└── docs/  # Project documentation

## Getting started

Setup instructions will be added when the backend (`api/`) and the app (`app/`) are initialized.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
