# Wireframes and visual style (S0-5)

Wireframes, navigation flow and visual style for marlix v1, exported from Figma (file *marlix – S0-5 Wireframes*). Screens are Android, 360×800. UI copy is in Spanish because the app is for users in Costa Rica.

## Contents

| File | What it shows |
|---|---|
| [`navigation-flow.png`](navigation-flow.png) | All screens and the navigation between them |
| [`screens/`](screens/) | One image per screen or state |
| [`style-guide/colors.png`](style-guide/colors.png) | Color palette with usage and contrast |
| [`style-guide/typography.png`](style-guide/typography.png) | Type scale |
| [`style-guide/avatar.png`](style-guide/avatar.png) | Avatar prototype in its five states |
| [`style-guide/moodboard.png`](style-guide/moodboard.png) | Style references for the avatar |

## Screens

| Screen | File | User stories |
|---|---|---|
| Login | `01-login.png` | US-01 |
| Onboarding: welcome | `02a-onboarding-welcome.png` | US-02 |
| Onboarding: not therapy + data consent | `02b-onboarding-consent.png` | US-02 |
| Onboarding: microphone and reminders | `02c-onboarding-permissions.png` | US-02, US-11, US-14 |
| Onboarding: where help is | `02d-onboarding-help.png` | US-02, US-05 |
| Chat | `03a-chat.png` | US-03, US-06, US-10 |
| Chat: waking up, failed message, offline | `03b-chat-states.png` | US-15 |
| Chat: crisis response | `03c-chat-crisis.png` | US-04 |
| Chat: daily limit reached | `03d-chat-limit.png` | US-10 |
| Voice mode: listening | `04a-voice-listening.png` | US-11, US-13 |
| Voice mode: speaking | `04b-voice-speaking.png` | US-11, US-12, US-13 |
| What marlix knows about me | `05a-memory.png` | US-08 |
| Edit a memory | `05b-memory-edit.png` | US-08 |
| Help | `06-help.png` | US-05 |
| Settings | `07a-settings.png` | US-01, US-08, US-09, US-14 |
| Delete account (confirmation) | `07b-delete-account.png` | US-09 |

US-07 (memory extraction) runs in the background and has no screen; its result is visible in 05a.

## Flow decisions

- **App start.** With a saved session the app opens straight into the chat; without one it opens the login.
- **Onboarding** (02a–02d) runs once per account, right after sign-up.
- **One conversation.** v1 has a single, continuous chat with no "new chat" action. Recent messages load when the chat opens, grouped by date (older dates, *Ayer*, *Reciente*).
- **Help** is one tap away from the chat and voice mode (lifebuoy button), and from the crisis response. The login does not link to it.
- **Settings** (07a–07b) is not one of the six screens in the card; it was added so memory, reminders, sign-out and account deletion are reachable.

## Visual style

- **Colors:** tan, cream and charcoal from Marley's coat, plus one blue for voice mode. Red is only for 9-1-1, crisis and irreversible actions. Text pairs meet WCAG AA; plain tan is never used behind text.
- **Type:** Baloo 2 for titles, Nunito for UI and chat. Both are free Google Fonts (OFL).
- **Avatar:** a flat, round tricolor beagle in a sleeveless coat that reads "marlix", inspired by Marley. Each animatable part (ears, eyes, mouth, tail, arms, cheeks) is its own layer so it can be animated with `flutter_svg`. The five states are idle, listening, thinking, speaking and happy (US-13). Validated as the prototype on 2026-09-28; final artwork is S5-1.
- **Moodboard:** four openly licensed references, linked with credit. No third-party images are stored in this repository.

## Moodboard credits

| Reference | Author | License |
|---|---|---|
| [Sobo](https://rive.app/marketplace/28761-54484-sobo/) | Patgrivet | CC BY |
| [OpenMoji dog face](https://openmoji.org/library/emoji-1F436/) | Sofie Ascherl, OpenMoji | CC BY-SA 4.0 |
| [Noto Emoji](https://github.com/googlefonts/noto-emoji) | Google | Apache 2.0 |
| [Twemoji](https://github.com/jdecked/twemoji) | Twitter, Inc. and contributors | CC BY 4.0 |

## Placeholders

These wireframes show layout and flow, not final content:

- The crisis response text is provisional; the fixed text is defined by the crisis protocol.
- The Costa Rican resources on the help screen are placeholders; the real list is loaded from configuration (US-05).
- Chat messages are sample copy. marlix's tone and voice are defined in the personality system prompt (S0-10).
