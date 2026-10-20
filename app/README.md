# marlix app

The Flutter app (Android first). Setup and commands are in the [main README](../README.md#app).

| Folder | Contents |
|---|---|
| `lib/screens/` | One folder or file per screen, with its Riverpod controller next to it. |
| `lib/widgets/` | Widgets shared by several screens. |
| `lib/models/` | Data classes, such as the API's request and response bodies. |
| `lib/services/` | Communication with the backend (`MarlixApi`, the only code that uses `package:http`), with Supabase Auth (`AuthService`, the only code that uses `supabase_flutter`, for sign-up and sign-in only) and the device. |
| `lib/config/` | Configuration per environment (`AppConfig`). |
| `lib/theme/` | Colors and theme from the [style guide](../docs/diagrams/wireframes/README.md). |
| `config/` | Environment files for `--dart-define-from-file`. |
| `integration_test/` | Tests that call the real backend from a device or emulator. |
| `assets/` | The header avatar (S0-5 prototype until S5-2), the SVG layers of the final avatar (S5-1) and the fonts. |

State is managed with [Riverpod](https://riverpod.dev); see the [decision](../docs/decisions.md).

## Fonts

[Nunito](https://github.com/googlefonts/nunito) and [Baloo 2](https://github.com/EkType/Baloo2) are bundled in `assets/fonts/` under the SIL Open Font License 1.1; each license is next to its files.
