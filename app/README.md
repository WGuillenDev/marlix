# marlix app

The Flutter app (Android first). Setup and commands are in the [main README](../README.md#app).

| Folder | Contents |
|---|---|
| `lib/screens/` | One file per screen. |
| `lib/widgets/` | Widgets shared by several screens. |
| `lib/models/` | Data classes, such as the API's request and response bodies. |
| `lib/services/` | Communication with the backend (`MarlixApi`, the only code that uses `package:http`) and the device. |
| `lib/config/` | Configuration per environment (`AppConfig`). |
| `lib/theme/` | Colors and theme from the [style guide](../docs/diagrams/wireframes/README.md). |
| `config/` | Environment files for `--dart-define-from-file`. |
| `integration_test/` | Tests that call the real backend from a device or emulator. |

State is managed with [Riverpod](https://riverpod.dev); see the [decision](../docs/decisions.md).
