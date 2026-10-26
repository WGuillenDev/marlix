# Avatar

The avatar is drawn as SVG layers and animated in Flutter code (`app/lib/widgets/avatar_marlix.dart`). No paid tool is needed to change it.

## Layer template

An avatar is a folder of SVG files with these fixed names. Every file uses the same `0 0 512 512` canvas and origin, so stacking them in this order, back to front, assembles the character. The marlix avatar follows the validated prototype (`docs/diagrams/wireframes/style-guide/avatar.png`): a round tricolor beagle in a sleeveless coat that reads "marlix".

| Layer | What it is |
| --- | --- |
| `cola` | Tail with a white tip. Wags around where it joins the body. |
| `pies` | White feet. |
| `cuerpo` | Orange torso, the rim that shows around the coat. |
| `panza` | The coat with the "marlix" lettering (outlined from Baloo 2, so the SVG needs no font). |
| `brazo_izq`, `brazo_der` | Arms with their white hands. |
| `cabeza` | Head, white blaze that flares into the nose bridge, and muzzle. The head reaches below the muzzle so an orange rim frames the chin. |
| `oreja_izq`, `oreja_der` | Floppy ears, over the head. They rotate around the top of the ear. |
| `mejillas` | Cheeks. |
| `ojos_abiertos` | The white rings of the open eyes. |
| `pupilas` | Iris, pupil and highlight. They move inside the rings. |
| `ojos_felices` | Eyes closed with joy: two arcs, without the rings. |
| `nariz` | Nose. |
| `boca_0` | Closed smile, the resting mouth. |
| `boca_1` | Almost closed: a small opening. |
| `boca_2` | Half open, with the tongue. |
| `boca_3` | Open, with the tongue. |
| `boca_pensando` | The doubtful squiggle of the thinking state. |

The art is drawn in a design space and shrunk to 92% around its middle when exported, so the bobbing never clips. The marlix avatar is in `app/assets/avatars/marlix/`. A new avatar is a new folder with the same names; the folder is registered in `pubspec.yaml` and its path goes in `avatars.layers_path`.

## States

`AvatarMarlix(state:, volume:, folder:)` takes one of five states and eases between them in 350 ms.

| State | Movement | Mouth |
| --- | --- | --- |
| `idle` | Floats, wags the tail and blinks every 4 s. | `boca_0` |
| `listening` | Raises the ears, blue ring around the head. | `boca_0` |
| `thinking` | Pupils look up, three thought bubbles growing away from the head. | `boca_pensando` |
| `speaking` | Floats less and opens the mouth. | From the volume (below). |
| `happy` | Eyes closed with joy, bounces, wags the tail fast, hearts rise. | `boca_3` |

Mouth for the volume (0.0 to 1.0) while speaking: under 0.05 (silence) `boca_0`, under 0.2 `boca_1`, under 0.6 `boca_2`, otherwise `boca_3`.

In the chat, `AvatarController` sets `speaking` when the first sound of a reply plays and `avatarVolumeProvider` carries the volume from the voice layer; the avatar goes back to rest when the sound ends, is paused, is stopped or fails.

The ring, thought bubbles and hearts are painted by code, so they need no layer.

## How it runs

- One 12 s clock drives every periodic movement. All periods divide 12 s, so the loop has no jump.
- The layers that never move (`pies`, `cuerpo`, `panza`, `brazo_izq`, `brazo_der`, `cabeza`) are built once and cached as one picture, so each frame only redraws the tail, ears, eyes, mouth and effects.
- A missing layer leaves a gap instead of an error screen.

## In the chat

The avatar lives in the header of the chat screen, 64 px (48 px while the keyboard is open, to leave room for the messages). `AvatarController` (`app/lib/screens/chat/avatar_controller.dart`) is the only place that decides its state; screens just watch `avatarStateProvider`.

| Moment | State |
| --- | --- |
| Nothing is happening | `idle` |
| A message was sent and marlix has not answered | `thinking` |
| The reply arrived, and the user's message was positive (`tone: "positive"`) | `happy` for 3 s, then `idle` |
| The reply arrived otherwise, the send failed, or it was a crisis | `idle` |

`tone` comes from the backend (`POST /v1/chat`, [contract](api-contract.md#post-v1chat)). It is never `positive` for a crisis, and the history loaded at the start never makes the avatar celebrate. The folder of the layers comes from `avatarFolderProvider`, which reads `avatar.layersPath` from `GET /v1/me` (S5-7) and uses `assets/avatars/marlix` if the profile has not loaded, failed or sent a path that is not under `assets/avatars/`. With "remove animations" on in the phone, the avatar keeps its pose and only eases between states.

## Trying it

In a debug build, Settings has a "Probar el avatar" row with a button per state and a volume slider. It is not in release builds.
