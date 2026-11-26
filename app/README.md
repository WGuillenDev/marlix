# marlix app

The Flutter app (Android first). Setup and commands are in the [development guide](../docs/operations/development.md#app).

| Folder | Contents |
|---|---|
| `lib/features/<feature>/domain/` | Models and pure rules, with no dependency on plugins or Riverpod. |
| `lib/features/<feature>/application/` | Use cases and ports for the feature. |
| `lib/features/<feature>/infrastructure/` | Adapters for services and device plugins. |
| `lib/features/<feature>/presentation/` | Widgets and Riverpod controllers. |
| `lib/features/<feature>/composition/` | Provider wiring for feature-specific adapters. |
| `lib/shared/` | The HTTP client, local preferences and theme used across features. |
| `lib/bootstrap/` | Environment configuration and shared provider wiring. |
| `config/` | Environment files for `--dart-define-from-file`. |
| `integration_test/` | Tests that call the real backend from a device or emulator. |
| `assets/` | The header avatar (S0-5 prototype until S5-2), the SVG layers of the final avatar (S5-1), the time and texts of the daily reminders (`config/reminders.json`) and the fonts. |

State is managed with [Riverpod](https://riverpod.dev); see the [decision](../docs/adr/decisions.md).

## Fonts

[Nunito](https://github.com/googlefonts/nunito) and [Baloo 2](https://github.com/EkType/Baloo2) are bundled in `assets/fonts/` under the SIL Open Font License 1.1; each license is next to its files.
