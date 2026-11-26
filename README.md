# marlix

Marlix is an Android companion app with an animated AI mascot. You can talk or write in Spanish, manage what the mascot remembers, and access Costa Rican help resources offline.

> [!IMPORTANT]
> Marlix does not replace professional mental health care. If you are in danger in Costa Rica, call **9-1-1**.

**Next release:** See the [execution plan](docs/plans/next-release-execution-plan.md) for the scope, phase status and verification evidence.

## Run locally

Use Flutter with an Android device or emulator, and Node.js 24 or later for the API. See the [development guide](docs/development.md) for environment configuration, Docker Compose, the local API and staging.

```bash
cd api
npm ci
# Copy .env.example to .env and configure it as described in the development guide.
npm run dev
```

```bash
cd app
flutter pub get
# Copy config/local.example.json to config/local.json and fill in its values.
flutter run --dart-define-from-file=config/local.json
```

## Install on Android

Download the APK from [GitHub Releases](https://github.com/WGuillenDev/marlix/releases/latest). Access requires permission to view the repository while it is private. Install updates over the existing app to keep local settings. Registration is for adults and requires email confirmation.

Verify the APK signer with `apksigner verify --print-certs <file.apk>`. The release signing certificate's SHA-256 fingerprint is `3ee151e5216b23a73e8de40331d72d732710c42280fcde2b099435ebbae86226`.

## Project references

- [Execution plan](docs/plans/next-release-execution-plan.md)
- [Development, staging and deployment](docs/development.md)
- [Architecture](docs/architecture.md), [API contract](docs/api-contract.md) and [data access rules](docs/erd.md)
- [Technical decisions](docs/decisions.md) and [security reporting](SECURITY.md)

## License

Marlix is released under the [MIT License](LICENSE). The [Supertonic 3 voice model](https://huggingface.co/Supertone/supertonic-3), downloaded on first use, has its own [OpenRAIL-M license](https://huggingface.co/Supertone/supertonic-3/blob/main/LICENSE).
