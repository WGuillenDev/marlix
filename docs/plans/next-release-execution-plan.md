# Next release execution plan

This file is the only active source for the next Marlix release. It records which phase is next, what is done, where the evidence is, and where to resume. The [phase tracking table](#6-phase-tracking) holds the current state. The A0 candidate passed its local checks and waits for verification in staging. Phase 1a is authorized and has not started.

Lasting decisions go to [`docs/decisions.md`](../decisions.md). Phase evidence goes to `docs/qa/phase-<n>-evidence.md`, one file per phase, with real commands and results. The approved [v0.2 design](../designs/marlix-v0-2.md) stays as the reference for its acceptance criteria. This plan replaces its release sequence, milestones and earlier development flow.

Sources were read on 2026-11-25 unless a row says otherwise. A row marked **unverified** names the check that settles it.

## 1. What is new for users

Each item states what a person sees and what must be true for the item to count as done. App copy stays in Spanish.

1. **A cleaner app that works without surprises (Phase 1).** Sign-up, chat, voice mode, settings and help are audited end to end, and the bugs found are fixed. Done when every audited step has a pass result with a screenshot, and the open bugs [#186](https://github.com/WGuillenDev/marlix/issues/186), [#187](https://github.com/WGuillenDev/marlix/issues/187) and [#188](https://github.com/WGuillenDev/marlix/issues/188) are closed or re-triaged with a reason.
2. **My own mascot.** The person takes or picks a photo, and Marlix proposes a 2D animal mascot whose colors and markings come from that photo. Two preset skins (a feminine style and a masculine style) are available without a photo. A gallery of animated backgrounds, like the backgrounds of a video call, sits behind the mascot. The same mascot, with the same look, appears in chat, voice mode, the mood screen and the game. Done when one saved mascot definition renders identically on all four screens and the photo never leaves the phone unless the owner approves otherwise ([decision D4](#decisions-that-need-the-owner)).
3. **More natural voices.** The ten Supertonic voice styles are replaced by more natural Spanish voices from an engine that VoiceStudio offers on Android. The person hears a sample of each voice, picks one, and the choice is kept after a restart. People who already downloaded the Supertonic model get a guided switch that frees its space. Done when the new engine passes the listening, latency and interruption tests of [Phase 3](#phase-3-android-voice-spike) and the switch is tested from a phone with the old model installed.
4. **Mood screen.** The person records how they feel, and the mascot shows that state. A timeline groups the records by hour. Done when a record appears in the timeline at its local hour, the mascot animation matches the recorded state, and the data follows the same deletion and privacy rules as chat. A view for health professionals ("mi paciente") is not built until the owner decides scope, consent and permissions ([decision D6](#decisions-that-need-the-owner)).
5. **A small world to bring back to color.** A 2D game where the mascot walks a round world that starts gray. Each challenge restores the color of one zone, and progress survives closing the app. Done when every zone can be colored, progress persists across restarts and reinstalls of the same account (or only on the phone, per [decision D7](#decisions-that-need-the-owner)), and the game respects reduced motion.
6. **Sala Marlix beta.** A text-only community to practice social skills, opened first as a moderated beta by invitation. It has reporting, blocking and opening criteria. Sala content never enters the private chat or Marlix's memory. Done when the beta start conditions A to F of the [v0.2 design](../designs/marlix-v0-2.md#sala-de-marlix-scope) pass. Opening to everyone keeps its own criteria.
7. **DeepSeek as the conversation model.** Marlix's replies come from DeepSeek once a synthetic evaluation shows equal or better quality at an acceptable latency and cost, and once the owner accepts the privacy change ([decision D1](#decisions-that-need-the-owner)). The crisis protocol, the transcript and the memory keep working as they do today.
8. **Account emails from Marlix's own address.** Sign-up and recovery codes arrive from an address on Marlix's domain. Done when the staging acceptance test of the v0.2 design (section 5) passes. It needs a domain purchase ([decision D3](#decisions-that-need-the-owner)).
9. **A renewed support website and an illustrated manual.** The support site is redesigned, and a manual explains each screen with images of the approved interface. Done when both pass a review in Chrome with Mobile Simulator at phone widths and every image matches the shipped build.

## 2. Resources by feature

DeepSeek is the only paid service planned. Every other row costs USD 0. A row with any other cost is an owner decision. "Free plan" means a proprietary service with a free tier, and the row says what happens when the tier runs out.

| Feature | Candidate | Integration | License | Operating cost | Quota and what happens at the limit | Alternative | Pending test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Conversation | DeepSeek `deepseek-flash` (model DeepSeek-V4.1-Flash-1017), thinking off ([models and pricing](https://api-docs.deepseek.com/quick_start/pricing)) | New `LlmProvider` adapter in `api/src/shared/infrastructure/ai/`, OpenAI-format base URL `https://api.deepseek.com` | Proprietary API ([Open Platform terms](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html), effective 2026-04-29) | Prepaid balance. Per 1M tokens, off-peak and peak: input cache hit 0.003 and 0.006, cache miss 0.15 and 0.30, output 0.60 and 1.20 USD. Peak is 01:00 to 04:00 and 06:00 to 10:00 UTC on weekdays, which is 19:00 to 22:00 and 00:00 to 04:00 in Costa Rica. Estimate for 6,000 turns a month at the v0.2 token profile: about 4.6 USD off-peak and 9.2 USD at peak with no cache hits, before VAT (inferred) | 2,500 concurrent requests per account, then HTTP 429 ([rate limit](https://api-docs.deepseek.com/quick_start/rate_limit)). HTTP 402 when the balance is empty ([error codes](https://api-docs.deepseek.com/quick_start/error_codes)) | Groq Free `openai/gpt-oss-120b`, today's model, with ZDR | [Phase 2](#phase-2-deepseek-evaluation) |
| Crisis classifier | Groq Free `openai/gpt-oss-20b`, unchanged | Existing | Groq terms | 0 | Free-plan limits per model. A failure counts as a crisis (fails closed) | DeepSeek safety checks as an extra signal, never as the only one | Phase 2 runs `npm run crisis:eval` with DeepSeek as the chat model |
| Voice transcription | Groq Free `whisper-large-v3-turbo`, unchanged | Existing `POST /v1/transcribe` | Groq terms | 0 | Free audio-seconds quota. Text chat keeps working when it runs out | On-device ASR in sherpa-onnx (Apache-2.0), or DeepSeek ASR at 0.116 USD per audio hour ([pricing](https://api-docs.deepseek.com/quick_start/pricing)), which sends voice to DeepSeek | Phase 10 measures latency with both paths |
| Speech | Kokoro v1.0 multi-language int8 through `sherpa_onnx` 2.0.3 on pub.dev, `lang=es` ([config](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/csrc/offline-tts-kokoro-model-config.h)) | On the phone. The app downloads `kokoro-int8-multi-lang-v1_0.tar.bz2` (132 MB, [tts-models release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models)) and checks a pinned SHA-256, as it does for Supertonic today | sherpa-onnx Apache-2.0. Kokoro weights Apache-2.0 ([model card](https://huggingface.co/hexgrad/Kokoro-82M)) | 0 | Works offline after the download. Spanish voices: `ef_dora` (female), `em_alex` and `em_santa` (male) ([VOICES.md](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)) | Supertonic 3, today's engine: OpenRAIL-M weights, 31 languages including Spanish, 10 preset styles, 398 MB. Piper `es_MX` or `es_AR` voices, 21 to 114 MB, voice data licenses differ per voice ([voices.json](https://huggingface.co/rhasspy/piper-voices)) | [Phase 3](#phase-3-android-voice-spike). **Unverified:** sherpa-onnx 2.0 removed espeak-ng ([#3731](https://github.com/k2-fsa/sherpa-onnx/issues/3731)), so Spanish needs a lexicon or a G2P. Words missing from a lexicon are skipped |
| Mascot rendering | The existing vector layers (`app/assets/avatar/`) drawn by one renderer, reused by Flutter widgets and the game | `flutter_svg` (MIT, in use) and a Flame component | MIT | 0 | None | Rive runtime (MIT). Free Rive exports play a Rive splash screen and removing it is paid ([pricing](https://rive.app/pricing)), so Rive needs [decision D5](#decisions-that-need-the-owner) | [Phase 4](#phase-4-reusable-mascot-spike) |
| Photo to mascot look | On-device segmentation with MediaPipe Image Segmenter (Apache-2.0, [repo](https://github.com/google-ai-edge/mediapipe)), then a color quantizer (`material_color_utilities` 0.13.1) maps the result onto the mascot template | `camera` 0.12.2 or `image_picker` 1.2.4, then a pure Dart trait extractor | Apache-2.0 | 0 | None. The photo is not stored or uploaded | ML Kit subject segmentation (`google_mlkit_subject_segmentation` 0.3.2, proprietary, free, on-device). DeepSeek vision on `deepseek-flash` (paid tokens, the photo leaves the phone). Image generation (diffusion) is rejected: it needs a GPU or a paid API, and its output cannot be rigged | Phase 4 prototype, Phase 8 build. **Unverified:** the license of `material_color_utilities` and the MediaPipe Flutter path |
| Making the look animatable | A fixed template rig per species (head, ears, eyes, mouth, body, tail) whose layers take the extracted traits. Animation is code, not per-mascot artwork | Pure Dart model plus the renderer above | MIT | 0 | None | Meta AnimatedDrawings (MIT, archived, built for human figures, Python) is rejected | Phase 4 |
| Animated backgrounds | Flutter `CustomPainter` and fragment shaders, which ship with Flutter | Background layer behind the mascot | BSD-3 (Flutter) | 0 | None. Reduced motion shows a still frame | `lottie` 3.8.2 (MIT) | Phase 7 |
| 2D game | Flame 1.38.2 (MIT, [repo](https://github.com/flame-engine/flame)) | New `app/lib/features/game/` | MIT | 0 | None | Plain Flutter `CustomPainter` | Phase 13 |
| Mood records | A new Supabase table with RLS in the existing projects | New `mood` module in the API and feature in the app | Not applicable | 0 | Supabase Free, 500 MB of database per project | Records kept only on the phone | Phase 12 |
| Sala | Supabase tables and API polling every 3 seconds, as designed in v0.2 section 3.6 | New `sala` module | Not applicable | 0 | Render Free and Supabase Free limits. The polling load is an opening criterion | Supabase Realtime | Phase 16 |
| API hosting | Render Free, today's host (`render.yaml`) | Existing | Proprietary, free plan | 0 | 750 instance hours a month. A service sleeps after 15 minutes without traffic | None planned | None |
| Database | Supabase Free, production and staging | Existing | Proprietary, free plan | 0 | 2 projects. A project pauses after a week without activity (staging keepalive) | None planned | Carried item C1 below |
| Sending account codes | Resend Free as the custom SMTP of Supabase Auth | Supabase Auth settings. The templates in `infra/auth/` stay | Proprietary, free plan | 0 | 100 emails a day and 3,000 a month, received emails included. At the limit the API answers 429 `daily_quota_exceeded` or `monthly_quota_exceeded` and the email is not queued ([quotas](https://resend.com/docs/knowledge-base/account-quotas-and-limits)). Supabase allows 30 emails an hour with custom SMTP until the limit is raised ([SMTP guide](https://supabase.com/docs/guides/auth/auth-smtp)) | Brevo Free, 300 emails a day (listed by itsfree.dev, **unverified** officially) | Phase 14 |
| Support mailbox, receiving | Cloudflare Email Routing, which forwards `soporte@<domain>` to the owner's mailbox | Cloudflare DNS | Proprietary, free | 0 | Receive and forward only ([Email Service](https://developers.cloudflare.com/email-routing/)) | Resend inbound, which spends the same 100-a-day quota | Phase 14 |
| Support mailbox, replying from the own address | A Resend inbox (3 free inboxes) | Resend dashboard | Proprietary, free plan | 0 | Every sent or received inbox email counts against the 100-a-day quota | Gmail "Send mail as" through the Resend SMTP (**unverified**) | Phase 14 |
| Domain registration | A `.fyi` at Cloudflare Registrar, the v0.2 choice | Cloudflare | Not applicable | **Paid**: about 5.20 USD a year before VAT, from a third-party price mirror (v0.2 question C3, **unverified**) | Yearly renewal | No own domain, so no own sender | [Decision D3](#decisions-that-need-the-owner) |
| Support website and manual hosting | GitHub Pages, today's host (`.github/workflows/pages.yml`) | Existing workflow | Not applicable | 0 | **The site answers 404 today**: Pages needs a public repository on GitHub Free, and the repository is private | Cloudflare Pages Free, 500 builds a month (listed by itsfree.dev, **unverified** officially) | [Decision D2](#decisions-that-need-the-owner) |
| Prototypes, support site and manual review | Static HTML served from the computer, viewed in the owner's Chrome with Mobile Simulator ([extension](https://chromewebstore.google.com/detail/mobile-simulator-responsi/ckejmhbmlajgoklhgbapkiccekfoccmk): 80 device frames, side-by-side devices, PNG and video capture) | Local folder `prototypes/`, served by a small Node script | Not applicable | 0 | None | Penpot (open source, listed by itsfree.dev) | Phase 6 |
| Monitoring | UptimeRobot Free on `/health` (`docs/monitoring.md`) | Existing | Proprietary, free plan | 0 | 50 monitors, 5-minute checks | None | v0.2 question C11: confirm the monitor exists |
| CI | GitHub Actions | Existing `.github/workflows/` | Not applicable | 0 | A private repository gets 2,000 minutes a month on GitHub Free (listed by itsfree.dev, **unverified** officially). A public repository has no minute limit | None | Watch the minutes while the repository stays private |

**Sources for discovery.** The catalog [itsfree.dev](https://itsfree.dev/es) (143 resources, last reviewed October 2026) suggested Resend, Brevo, Unitpost, Mailtrap, Cloudflare Pages, Penpot and UptimeRobot. Each row above cites the official page where the condition was confirmed, or says **unverified**.

**VoiceStudio.** [VoiceStudio](https://github.com/debpalash/voicestudio) is an AGPL-3.0 desktop, server and phone app, not a library, so Marlix uses an engine it offers, not VoiceStudio itself. Its Android app offers KittenTTS mini, Kokoro multi-language, Piper Lessac, Supertonic 3, Pocket TTS, ZipVoice and OmniVoice (`mobile/contract/SPEC.md` in that repository). The Kokoro build it ships, `kokoro-int8-multi-lang-v1_1`, is version 1.1, which covers Chinese and English only. Spanish is in Kokoro version 1.0. The other phone engines do not fit. Pocket TTS terms are non-commercial. The OmniVoice weights are CC-BY-NC and weigh about 1.4 GB. Piper Lessac is English. The KittenTTS 2 weights use the Stellon Labs Community License, which needs a review before use.

## 3. Visual direction and prototype approval

**Method.** The visual phases use the installed `ui-ux-pro-max` skill. Each visual phase attaches the skill's deliverables to its evidence file: a navigation map, a component inventory, an accessibility checklist, and the screen states. The checklist covers TalkBack labels, text at 200 %, a contrast of at least 4.5 to 1, and touch targets of at least 48 dp. The screen states are empty, loading, error, offline, reduced motion and flag off.

**Direction.** A clean, organized mobile app. Muse is the reference for hierarchy and navigation. Its announcement ([Meta, 2026-09-08](https://about.fb.com/news/2026/09/introducing-muse-personal-ai-agent/)) describes the patterns to study. Talking to Muse works like messaging a person. It suggests things on its own and remembers what matters. It asks before sensitive actions and shows a record of what it did. The identity is Marlix's own and centers on the mascot. Muse's visual details (layout, type and spacing) are **unverified**. The announcement text does not describe them, so Phase 6 studies its video and images before drawing.

**Three prototypes.** Phase 6 builds three navigable HTML prototypes of the same journey with the same fictional data. The journey covers home, chat, voice mode, and the way to reach the mascot, mood, game and Sala. Each prototype is one distinct direction (for example: chat-first, mascot-first, and a card hub), chosen with the skill. A visible selector at the top switches between them, and each one also has its own local URL. The owner tests them in Chrome with Mobile Simulator, then chooses one or a combination. The choice and the reasons go to `docs/decisions.md`. No Flutter screen is restyled before that choice.

**Where each kind of check runs.**

| Check | Where | Tool |
| --- | --- | --- |
| Prototypes, support site, manual | Chrome on the computer | Mobile Simulator, local URLs |
| Camera, permissions, microphone, audio, on-device voice, performance | The `Pixel_8` emulator or the Galaxy S24 (ask the owner first) | `flutter run`, `adb`, screenshots |
| SDK, emulator images, native crashes | Android Studio | Only for these tasks |

The web preview, the API deploy and the Android publication are separate. A prototype never ships. An API deploy happens when `api/` reaches `main` (see [Delivery dependencies](#delivery-dependencies)). An Android release is a signed build that the owner publishes.

## 4. Architecture and Docker

### Code layout

Marlix keeps the Clean Architecture and domain-driven layout it is adopting. That move is committed locally and not yet on `main` (see row A0 in the [tracking table](#6-phase-tracking)). Code is grouped by capability:

- **API**: `api/src/modules/<capability>/{domain,application,infrastructure,presentation}`. Today's capabilities are `conversation`, `safety`, `memory`, `identity` and `usage`. `api/src/shared/` holds the model port (`application/ai/`), the provider adapters (`infrastructure/ai/`) and the configuration.
- **App**: `app/lib/features/<capability>/{domain,application,infrastructure,presentation,composition}` for `account`, `conversation`, `safety`, `memory`, `settings`, `avatar` and `voice`, plus `app/lib/shared/` and `app/lib/bootstrap/`.

New capabilities follow the same layout: `mascot` (renamed from `avatar` in Phase 4), `mood`, `game` and `sala`. Rules:

- The domain imports no framework, SDK or HTTP code. The architecture tests (`api/test/llm-boundary.test.ts`, `app/test/architecture_test.dart`) gain one rule per new boundary.
- A port and an adapter exist only where a real boundary exists: a model provider, a TTS engine, a camera, storage or the network. A use case with one caller and no boundary stays a function.
- One responsibility per file, with a clear name and a fixed location. A comment explains a decision or a constraint, never what the code does. This follows the reference project, Venmart (private repository, paths only): `CLAUDE.md` section 2 and the module layout in section 3.
- The mascot is one data shape, `MascotSpec`: species template, palette, markings, accessories, preset skin and background ID. Chat, voice, mood and game render that same value. The spec is the only thing saved, so the look cannot drift between screens.

### Docker: today and proposal

**Today.** `docker-compose.yml` runs `db` (`supabase/postgres:17.11.0.019`, pinned by digest) and `pgadmin` (`dpage/pgadmin4:9.19.0`, pinned by digest), both on loopback ports with healthchecks and named volumes. `docs/schema.sql` runs once, on the first start with an empty volume. The CI reads the `db` image from this file. The API is not in Docker. It needs a real `*.supabase.co` URL and an `sb_secret_` key (`api/src/shared/infrastructure/config/env.ts`), and `LLM_PROVIDER` accepts only `groq`. So no local mode works without real credentials.

**Proposal** (Phase 5, no infrastructure changes before then). It follows the shape of Venmart's `compose.yaml` and `infra/docker/api.Dockerfile`: one shared environment block, pinned images, real healthchecks, a one-shot migration service, and mock providers by default.

| Service | Why it is added | Local development | Staging | Production |
| --- | --- | --- | --- | --- |
| `db` (kept) | The Supabase Postgres image has the `auth` schema and roles that `docs/schema.sql` needs | Yes | Supabase staging project | Supabase production project |
| `pgadmin` (kept, behind a `tools` profile) | Inspecting the local database | Optional | No | No |
| `migrate` (new, one-shot) | Applies `docs/schema.sql`, then `docs/migrations/*.sql` in file-name order, then fails if `docs/verify-migrations.sql` prints `MISSING`. The init mount only runs on an empty volume, so it never rehearses a migration | Yes | The owner runs the same files in the SQL Editor, in the same order | Same as staging |
| `api` (new) | Runs the backend from `infra/docker/api.Dockerfile` (`node:24-bookworm-slim` pinned by tag and digest, a build stage and a non-root run stage). Healthcheck on `GET /health`. Bound to `127.0.0.1:3310`, because port 3000 belongs to another project | Yes | Render `marlix-api-staging` | Render `marlix-api` |

**Central configuration.** One `x-api-env` block in the compose file reads the root `.env`. `.env.example` documents every variable with a demo default. Real keys stay in the ignored `.env` and `api/.env`.

**Demo mode with no real credentials.** `MARLIX_MODE=demo` selects a demo composition root in the API. It wires in-memory adapters for the stores (`api/test/` already has fakes to start from), a deterministic mock `LlmProvider` and transcriber, and a demo session verifier. The crisis filter, the reply review and the usage limits stay the real code. It needs no database, so `docker compose up api` alone gives the app and the prototypes a working backend. The modes are:

| Mode | Data | Model | Use |
| --- | --- | --- | --- |
| `demo` | In memory, seeded with fictional data | Mock | Prototypes, UX checks, screenshots for the manual |
| `local` | Local `db` | Groq Free or DeepSeek with the owner's local key | Development |
| `staging` | Supabase staging | Same as production | Integration suite (`node tool/verify-integration.mjs staging`), migration rehearsal, restore drill |
| `production` | Supabase production | Production model | Only through Render |

Rejected services: Redis (no queue or cache need exists), Nginx (no web app to serve), and a local Supabase Auth stack (about ten more containers; demo mode covers the need).

## 5. Phases, dependencies and exit criteria

Each phase is one verifiable day of work. A larger phase is split into deliveries that each close on their own check. A phase closes only when its exit criterion has evidence in `docs/qa/phase-<n>-evidence.md`. Tests alone are not enough. Every phase that changes behavior also drives the real app or API.

The risky experiments come first. Phases 2, 3 and 4 can change the calendar, so they run before any visual or feature work.

```text
A0 architecture move ─► 1 UX audit and fixes ─► 2 DeepSeek ─┐
                                               3 voice ────┼─► 5 Docker ─► 6 prototypes ─► 7 foundation ─► 8.. features ─► 18 release
                                               4 mascot ───┘
```

Phases 2, 3 and 4 do not depend on each other. Phases 8 to 17 depend on Phase 7. Their other dependencies are listed in their own sections.

### Phase 1. UX audit and bug fixes

Status: `1a authorized on 2026-11-25, blocked by A0`. Deliveries 1b to 1d wait for their own instruction.

- **Depends on:** row A0 (the architecture move has landed or the owner has decided how to handle it).
- **Method:** a heuristic and functional audit guided by `ui-ux-pro-max`. It runs on the `Pixel_8` emulator against staging: the release APK, and a debug build when a step needs it. Each flow is a list of steps, and each step has an expected result and an observed result.
- **Account emails:** sign-up codes and password recovery use the sender available in staging. The own-domain sender stays in Phase 14. Staging sends the default link emails today, and its templates cannot be edited without a custom SMTP sender ([decision D13](#decisions-that-need-the-owner)). The sign-up code and password recovery steps need that decision.
- **Flows:**
	- **Sign-up and access:** sign-up with the six-digit code, sign-in, wrong password, password recovery, age check, AI notice, consent, onboarding, sign-out, delete account.
	- **Chat:** send, streamed reply, retry after a failure, history paging, the warning before the daily limit, the daily limit itself, crisis reply, offline.
	- **Voice mode:** microphone permission (granted, denied, permanently denied), model download (wifi, mobile data, no space, cut and resumed), listening, speaking, interruption, errors, leaving the screen.
	- **Settings:** reading aloud, reminders, voice choice, account.
	- **Help:** both help lines, the dialer opens without calling, the offline list, the 9-1-1 button.
	- **Across all screens:** TalkBack, text at 200 %, contrast, 48 dp targets, the keyboard (#188), consistent voseo (#187), the session notice (#186).
- **Severity:** S1 blocks a flow or breaks safety. S2 is wrong behavior with a workaround. S3 is a visual or copy defect. S4 is polish.
- **Deliveries:**
	- **1a.** Audit sign-up and access, and help. Findings table with screenshots.
	- **1b.** Audit chat, voice mode and settings. Findings table with screenshots.
	- **1c.** Fix the S1 and S2 findings of 1a, each with a regression test.
	- **1d.** Fix the S1 and S2 findings of 1b, each with a regression test. Re-run every audited step.
- **Exit criterion:** every audited step has a pass result with a screenshot. No S1 or S2 finding is open. S3 and S4 findings are fixed or listed with a target phase. Issues #186, #187 and #188 are closed or re-triaged with a reason. `npm run typecheck`, `npm test` and `npm run build` pass in `api/`. `flutter analyze` and `flutter test` pass in `app/`. The release APK passes the sign-up, chat and help steps on the emulator.
- **Evidence:** `docs/qa/phase-1-evidence.md` with the findings table (ID, flow, step, expected, observed, severity, screenshot, fix commit) and `docs/qa/phase-1/` for screenshots with no personal data.

### Phase 2. DeepSeek evaluation

- **Depends on:** the owner supplies a DeepSeek key and a first top-up ([decision D1](#decisions-that-need-the-owner)). Real conversations are never sent.
- **Deliveries:**
	- **2a.** A harness `api/scripts/model-eval.ts` behind the existing `LlmProvider` port. A synthetic dataset in `api/eval/`: 30 Spanish conversations of 8 turns, written in voseo, covering company, loneliness, a bad day, «Recordá esto», short voice replies, and refusals of clinical advice. The run spaces Groq calls 25 seconds apart.
	- **2b.** Run `deepseek-flash` (thinking off) against `openai/gpt-oss-120b`. The owner and two or three testers pick the better answer in each blind, anonymous pair.
- **Quality:** DeepSeek wins or ties in at least 2 of 3 pairs. The reply review (`api/src/modules/safety/domain/rules.ts`) flags no more replies than with Groq. Every reply keeps voseo and the length rules of `docs/system-prompt.md`.
- **Latency:** the median time to the first streamed sentence is at most 300 ms slower than Groq. The run also reports p90 for peak and off-peak hours.
- **Cost:** the measured input, cached input and output tokens per turn give a monthly estimate under the USD 10 cap with VAT, for the low, expected and high scenarios of v0.2 section 6.
- **Safety:** `npm run crisis:eval` passes unchanged. The crisis filter runs before the model, so a crisis message never reaches DeepSeek. That claim is checked with a test, not assumed.
- **Still to confirm before real data (recorded in the evidence file):**
	- Where API inputs are stored. The privacy policy says data is stored in the People's Republic of China ([privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)).
	- How long inputs are kept. The policy says "for as long as necessary".
	- Whether API inputs train models. No opt-out was found.
	- Whether a ZDR or data processing agreement exists. None was found.
	- The smallest top-up amount.
	- How the required safety checks behave on Spanish distress messages. DeepSeek says public-facing apps must enable them ([announcement, 2026-11-13](https://api-docs.deepseek.com/news/news261113/)).
	- The owner's usage page (`platform.deepseek.com/usage` answers 403 without a session) as the reconciliation source.
- **Transcript, memory and crisis protocol.** The app transcript stays in Supabase, and the provider never holds it. Memory extraction stays on its own Groq model with the two barriers against sensitive data (`sensitive.ts` and the extractor prompt), so DeepSeek receives only the selected memory lines in the prompt. The crisis filter, the classifier and the help lines do not depend on DeepSeek. A 402 or 429 shows the existing error with the help button.
- **Exit criterion:** the evidence file holds the three verdicts (quality, latency, cost), the crisis eval result, and the list above with each item answered or still open. The owner decides whether DeepSeek moves to Phase 11.

### Phase 3. Android voice spike

- **Depends on:** the owner confirms the Galaxy S24 is free. Listeners are available.
- **Deliveries:**
	- **3a.** A throwaway spike app outside the repository runs Kokoro v1.0 int8 in `sherpa_onnx` 2.0.3 with `lang=es` on the `Pixel_8` emulator, the low-end AVD and the S24. Record the size on disk, the peak memory, the real-time factor and the time to the first word.
	- **3b.** Settle the Spanish front end without espeak-ng: a Spanish lexicon, the rule-based G2P discussed in sherpa-onnx issue #3731, or a small Dart G2P. Count the words the front end skips in the test phrases.
	- **3c.** A blind listening test of Kokoro `ef_dora`, `em_alex` and `em_santa` against Supertonic F4, on the S24.
- **Costa Rican pronunciation:** 40 test phrases with voseo, local words (mae, diay, tuanis, brete, chunche), numbers, 24-hour times, dates, the help-line names and the 9-1-1 number. Listeners score intelligibility and naturalness from 1 to 5.
- **Latency and pauses:** the time from the final transcript to the first audio sample (p50 and p90), and the gap between sentences. The voice must keep the 1.3 real-time-factor rule of the S6-1 decision.
- **Interruptions:** the time from the person's first word to the end of playback while Marlix speaks, and the false-stop rate caused by echo.
- **License check:** every file the app downloads has a recorded license. No GPL code ships in the APK unless the owner accepts it ([decision D8](#decisions-that-need-the-owner)).
- **Exit criterion:** a written verdict per engine with measured numbers. Kokoro continues only if it skips no word in the test phrases, matches or beats Supertonic F4 in the blind test, and meets the latency rule on the S24 and the low-end AVD. Otherwise the next candidate is a Piper Spanish voice, and if that fails, Supertonic 3 stays with a new voice treatment.

### Phase 4. Reusable mascot spike

- **Depends on:** no other spike. It runs after Phase 1 only because one phase runs at a time.
- **Deliveries:**
	- **4a.** Define `MascotSpec` and one renderer. Draw the same spec in a chat-header widget, a full-screen voice widget, and a Flame scene, on one test screen.
	- **4b.** Prototype the photo-to-traits path on the phone: segmentation, a palette of five colors, and the markings mapped onto the template. Use the owner's own test photos only.
- **Exit criterion:** the three surfaces show the same spec with the same colors. Golden image tests compare the widget output, and a screenshot covers Flame. The Flame scene and the widget hold 60 fps on the S24 and the low-end AVD while animating. The photo path runs offline and stores nothing. The evidence lists which v0.2 avatar behaviors (expressions, tilt, reduced motion) the renderer keeps.

### Phase 5. Reproducible local environment

- **Depends on:** Phase 1 (the audit shows what the demo data must cover).
- **Deliveries:**
	- **5a.** `migrate` service and the `tools` profile.
	- **5b.** `api` image and the demo composition root with fictional seed data.
- **Exit criterion:** from a fresh clone with `.env.example` copied, `docker compose up` brings `db` and `api` to healthy, and `migrate` exits 0. `GET /health` answers `ok`. The app signs in and chats in demo mode with no real key. `docker compose down -v` followed by `up` reproduces the same state. CI still passes unchanged.

### Phase 6. Three prototypes

- **Depends on:** Phases 1, 3 and 4 (real flows, voice constraints, mascot surfaces).
- **Exit criterion:** three prototypes run from local URLs with a visible selector, share one journey and one set of fictional data, and pass the `ui-ux-pro-max` checklist at 360 and 412 px. The owner records the choice. This phase closes only on the owner's choice.

### Phase 7. Visual foundation in Flutter

- **Depends on:** Phase 6 (the chosen direction).
- **Scope:** theme, navigation and home as chosen. This absorbs v0.2 V2-15 (navigation, theme, first use, accessibility) and V2-16 (reduced motion).
- **Exit criterion:** every existing flow from Phase 1 still passes on the emulator with the new navigation. The accessibility checklist passes. Screenshots match the chosen prototype.

### Phases 8 to 18

Each of these phases is split into one-day deliveries when it starts. The v0.2 IDs show which approved acceptance criteria each phase reuses from the [design task list](../designs/marlix-v0-2.md#detailed-implementation-plan).

| Phase | Content | Depends on | Reuses from v0.2 |
| --- | --- | --- | --- |
| 8. Mascot | Preset skins, background gallery, the same mascot in chat and voice. Split: 8a presets and spec storage, 8b backgrounds, 8c photo to mascot | 4, 7, [D4](#decisions-that-need-the-owner) | V2-17, V2-18, V2-19, V2-30 |
| 9. New voices | 9a engine and verified download. 9b voice picker with samples, saved preference, and the switch from Supertonic (delete its 398 MB, keep the native fallback) | 3, 7 | V2-20 |
| 10. Voice mode redesign | Redesign with measured pronunciation, latency, pauses and interruptions on the S24 | 9 | S6-9, S6-10, S6-14 decisions |
| 11. DeepSeek in production | 11a provider adapter, spend governor against the prepaid balance, safety checks on, in staging. 11b privacy policy update and the production switch | 2, [D1](#decisions-that-need-the-owner) | V2-07, V2-08, V2-09, V2-11, V2-12a |
| 12. Mood screen | Records, the hourly timeline, the mascot state, deletion with the account | 7, 8, [D6](#decisions-that-need-the-owner) | None (new) |
| 13. Game | 13a round world, zones and persistence. 13b challenges | 4, 8, [D7](#decisions-that-need-the-owner) | V2-21 (replaced) |
| 14. Own-domain email | Sender, support mailbox, acceptance test in staging, then production | [D3](#decisions-that-need-the-owner) | V2-06a, V2-34 |
| 15. Support website and manual | Redesigned site and an illustrated manual with screenshots of the shipped build | 7, [D2](#decisions-that-need-the-owner) | V2-31 (site part) |
| 16. Sala beta | 16a data model, blocking and reporting. 16b message path and moderation. 16c screens and moderator view. 16d safety and privacy tests, then the beta gate | 7, 11a, C8, Q15, Q16, Q18, Q19 | V2-22 to V2-26, V2-36 |
| 17. Offline crisis response | Crisis layer 1 on the phone when the API cannot be reached | 1 | V2-37 |
| 18. Release | Release preparation, v0.1 compatibility, release checks and publication | All launch phases | V2-31, V2-32, V2-33 |

### Release gate

Adapted from the eleven v0.2 launch criteria. Criteria 3, 4 and 11 change because DeepSeek replaces paid Groq. The change is a proposal until the owner approves it ([decision D9](#decisions-that-need-the-owner)).

1. Google Play: the closed test is finished and production access is granted (issue #213).
2. A backup restore into staging passed: row counts match, RLS is on in every table, and the app signs in.
3. The spend governor runs in production against the DeepSeek prepaid balance, with a reconciliation against DeepSeek's usage data.
4. The crisis classifier keeps its own model and quota, and `npm run crisis:eval` passes.
5. The own-domain sender passes its acceptance test in staging and production.
6. The launch features pass their phase exit criteria.
7. The production build contains no Sala code, and no public page advertises the Sala while it is closed.
8. The privacy policy, the data safety form and the health declaration list the new processors.
9. The v0.1 APKs still work against the new backend.
10. All checks pass, and the release build is tested on the S24, the low-end AVD and from an internal app sharing link. With the network off, a crisis message shows the crisis response and the help lines.
11. DeepSeek has a spend alert or a small balance, and its safety checks are on.

### Delivery dependencies

These facts decide whether a phase can push to `main` on its own. Each one was checked on 2026-11-25.

- **The repository is private.** GitHub Free does not enforce rulesets or branch protection on private repositories, so `main` reads `protected: false` and the "Protect main" ruleset has no effect. Pushes are not blocked today.
- **If the repository becomes public again,** "Protect main" (squash merges only, required checks) rejects a direct push. Direct integration then needs a one-time owner change: add the owner's role as a bypass actor, or replace the pull-request rule with required checks on push. The exact behavior of required checks on a direct push is **unverified**.
- **A push to `main` that changes `api/` deploys production.** `render.yaml` sets `autoDeployTrigger: checksPass` with `rootDir: api` for `marlix-api`. So any phase that changes `api/` waits for the owner's go before its push, or the owner sets production deploys to manual first.
- **A push to `main` that changes `site/` runs the Pages workflow.** The workflow fails while Pages is unavailable ([decision D2](#decisions-that-need-the-owner)).
- **Migrations, Supabase settings, Render settings and secrets** require maintainer approval.
- **Five Dependabot pull requests are open** (#233 to #237) on their own branches. They are not part of any phase.

## 6. Phase tracking

| Phase | Status | Exit criterion | Evidence | Commit | Blockers | Next step |
| --- | --- | --- | --- | --- | --- | --- |
| 0. Plan consolidation | Done, committed locally | This plan exists, the old tracking files are retired, and active links point here | This plan | The documentation commit that follows `9390079` | Reaches `main` together with A0 | None |
| A0. Architecture move | Local checks pass, staging verification pending | API and app checks pass on the moved code, the docs that point at old paths are updated, the new API passes in staging, and the verified commit is on `main` | [A0 evidence](../qa/phase-a0-evidence.md) | `c3099a3`, `9390079` and the documentation commit (local) | Maintainer approval for the branch push and the staging deploy | Push `release/next-release`, deploy that commit to staging, verify it, then ask to push it to `main` |
| 1. UX audit and fixes | 1a authorized, blocked. 1b to 1d pending | See [Phase 1](#phase-1-ux-audit-and-bug-fixes) | `docs/qa/phase-1-evidence.md` (not created) | None | A0. D13: staging cannot send six-digit codes with its current sender | Close A0, settle the staging sender, run 1a |
| 2. DeepSeek evaluation | Not started | See [Phase 2](#phase-2-deepseek-evaluation) | None | None | D1 (key and first top-up) | Waits for Phase 1 and D1 |
| 3. Android voice spike | Not started | See [Phase 3](#phase-3-android-voice-spike) | None | None | S24 availability, listeners | Waits for Phase 1 |
| 4. Reusable mascot spike | Not started | See [Phase 4](#phase-4-reusable-mascot-spike) | None | None | None | Waits for Phase 1 |
| 5. Reproducible local environment | Not started | See [Phase 5](#phase-5-reproducible-local-environment) | None | None | None | Waits for Phase 1 |
| 6. Three prototypes | Not started | See [Phase 6](#phase-6-three-prototypes) | None | None | Phases 3 and 4 | Waits for Phases 3 and 4 |
| 7 to 18 | Not started | See [Phases 8 to 18](#phases-8-to-18) | None | None | Listed per phase | Planned when Phase 6 closes |

### Carried over from v0.2

These items were open on the retired board on 2026-11-22. They keep their v0.2 acceptance criteria.

| Item | State | What is left | Who acts |
| --- | --- | --- | --- |
| C1. Staging verification (V2-05a) | Paused | Criteria 1, 2, 3 and 6 have evidence. Criterion 4 passed on 2026-11-22: the integration suite passed 12 of 12 on `Pixel_8` against staging. Criterion 5 fails: the staging keepalive still fails, so an owner action on a repository secret is pending (detail in the private notes). Criterion 7 is rechecked on the next push | Owner, then agent |
| C2. Restore drill (V2-05b) | Waiting for C1 | All four criteria | Maintainer confirms sign-in |
| C3. Google Play publication (#213) | Closed test in progress on `0.1.2+3` | Finish the test and request production | Owner |
| C4. Issues #186, #187, #188 | Open | Phase 1 input | Phase 1 |
| C5. Service-role grants on staging | Applied by hand on 2026-11-22 | Decide whether `docs/schema.sql` or `docs/development.md` states them for new projects | Owner |
| C6. Groq paid plan (V2-35), separate classifier organization (V2-12b) | Superseded if D1 and D9 are approved | Nothing, unless the owner keeps Groq | Owner |
| C7. «Recordá esto» (V2-13), greeting and reminder migration (V2-14), medical-urgency layer (V2-27), ARCore and 3D spikes (V2-29), stable hostname (V2-06b), GitHub Issues and Projects (V2-04, C10) | Approved in v0.2, absent from the new list | Keep, defer or drop each one ([decision D10](#decisions-that-need-the-owner)) | Owner |

### Decisions that need the owner

| ID | Decision | Recommendation | Blocks |
| --- | --- | --- | --- |
| D1 | DeepSeek with real conversations. It changes the v0.2 rule "real data only to providers with ZDR". DeepSeek stores data in China and offers no ZDR or data processing agreement that this research found. It also needs a key and a prepaid top-up | Approve the synthetic evaluation now. Decide on real data after Phase 2, with a privacy policy update and consent shown in the app | Phase 2 (key), Phase 11 |
| D2 | The repository stays private during development. Choose public hosting for `site/` that works with a private repository. Cloudflare Pages is a candidate | Hosting decision due before Phase 15. The Play listing needs a reachable privacy policy URL | Phase 15, release gate 8 |
| D3 | Buy a domain for the own sender. This is a second paid service | Buy the `.fyi` after checking the final price with tax at checkout | Phase 14, release gate 5 |
| D4 | Which photo the mascot comes from (the person, a pet, an object) and whether it may ever leave the phone | Any photo, processed on the phone only, never stored | Phase 8c |
| D5 | Rive with a paid plan, or the free vector renderer | The free vector renderer, unless Phase 4 fails | Phase 4 |
| D6 | The "mi paciente" professional view: scope, consent and permissions | Leave it out of this release | Phase 12 |
| D7 | Game progress saved only on the phone or synced to the account | Sync to the account, so a reinstall keeps it | Phase 13 |
| D8 | Accept GPL code (espeak-ng) in the APK if Kokoro needs it in Spanish | Avoid it: use a lexicon or G2P with sherpa-onnx 2.0 | Phase 3 |
| D9 | The adapted release gate (criteria 3, 4 and 11) | Approve with D1 | Phase 18 |
| D10 | The v0.2 items listed in C7 | Keep «Recordá esto» and the greeting, defer the rest | Phase planning after Phase 7 |
| D11 | Who lands the architecture move (row A0) | Answered on 2026-11-25: verify it and commit it. Integration follows D12 | None |
| D12 | How to verify and integrate changes under `api/` while a push to `main` deploys production | Answered on 2026-11-26 for A0: verify the candidate in staging first, then approve the push to `main` with its production deploy | None |
| D13 | Sender for staging account emails, so the six-digit code flows can be audited. Options: (a) a custom SMTP sender for staging that costs nothing and needs no domain; (b) audit those steps with codes issued by the Supabase admin API, which leaves email delivery unverified; (c) leave them blocked until Phase 14 | (a) | Phase 1a (sign-up code and password recovery steps) |
