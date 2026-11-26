# Marlix v0.2 Execution Plan

This plan is the source of truth for the v0.2 release scope, phase order, status, dependencies, exit gates and next steps. Use the approved [v0.2 design](../design/marlix-v0-2.md) for the product requirements and acceptance criteria referenced here. Record lasting implementation decisions in [Decisions](../adr/decisions.md).

## Phase status

| Phase | Status | Evidence |
| --- | --- | --- |
| [0. Plan consolidation](#phase-0-plan-consolidation) | `[x]` Complete | Plan and documentation in `a379210` through `47aa03f` |
| [A0. Architecture move](#phase-a0-architecture-move) | `[ ]` On `main`. Production deployment unverified | [A0 evidence](../qa/phase-a0-evidence.md) |
| [1. UX audit and bug fixes](#phase-1-ux-audit-and-bug-fixes) | `[ ]` 1a authorized. Real delivery awaits staging email. 1b–1d pending | — |
| [2. DeepSeek evaluation](#phase-2-deepseek-evaluation) | `[ ]` Pending | — |
| [3. Android voice spike](#phase-3-android-voice-spike) | `[ ]` Pending | — |
| [4. Reusable mascot spike](#phase-4-reusable-mascot-spike) | `[ ]` Pending | — |
| [5. Reproducible local environment](#phase-5-reproducible-local-environment) | `[ ]` Pending | — |
| [6. Three prototypes](#phase-6-three-prototypes) | `[ ]` Pending | — |
| [7. Visual foundation in Flutter](#phase-7-visual-foundation-in-flutter) | `[ ]` Pending | — |
| [8. Mascot](#phase-8-mascot) | `[ ]` Pending | — |
| [9. New voices](#phase-9-new-voices) | `[ ]` Pending | — |
| [10. Voice mode redesign](#phase-10-voice-mode-redesign) | `[ ]` Pending | — |
| [11. DeepSeek integration](#phase-11-deepseek-integration) | `[ ]` Pending | — |
| [12. Mood screen](#phase-12-mood-screen) | `[ ]` Pending | — |
| [13. Game](#phase-13-game) | `[ ]` Pending | — |
| [14. Account email verification](#phase-14-account-email-verification) | `[ ]` Pending | — |
| [15. Support website and manual](#phase-15-support-website-and-manual) | `[ ]` Pending | — |
| [16. Sala beta](#phase-16-sala-beta) | `[ ]` Pending | — |
| [17. Offline crisis response](#phase-17-offline-crisis-response) | `[ ]` Pending | — |
| [18. Release](#phase-18-release) | `[ ]` Pending | — |

### Where to resume

1. **A0.** The last recorded production check found the earlier build serving healthy. Confirm the intended A0 deployment in Render and verify its commit and `GET /health` before closing A0. GitHub `main` is at `47aa03f`, which includes the verified architecture move. CI passed and CodeQL failed at analysis. The [A0 evidence](../qa/phase-a0-evidence.md#main-and-production-follow-up) records the checks from 2026-11-26.
2. **Phase 1a.** The maintainer completes staging SMTP setup ([D13](#9-decisions-that-need-the-owner)). Configure the six-digit templates, then verify sign-up and password recovery. Record findings in `docs/qa/phase-1-evidence.md`. Phase 1a was authorized on 2026-11-25. Deliveries 1b through 1d await their own instruction.

## 1. Verified initial state

| Area | Recorded baseline |
| --- | --- |
| Repository | The A0 architecture move is on main at 47aa03f. The A0 evidence records the CI result and the pending production confirmation. |
| Local and staging verification | The A0 evidence records the tested revisions, the API and Flutter test results, and the staging checks from 2026-11-26. See the [A0 evidence](../qa/phase-a0-evidence.md). |
| Deployment | Render serves the API, Supabase provides the database and auth, and Google Play distributes the Android app. See the [development guide](../operations/development.md). |

### Release scope

Each item states what a person sees and what must be true for the item to count as done. App copy stays in Spanish.

1. **A cleaner app that works without surprises (Phase 1).** Sign-up, chat, voice mode, settings and help are audited end to end, and the bugs found are fixed. Done when every audited step has a pass result with a screenshot, and the open bugs [#186](https://github.com/WGuillenDev/marlix/issues/186), [#187](https://github.com/WGuillenDev/marlix/issues/187) and [#188](https://github.com/WGuillenDev/marlix/issues/188) are closed or re-triaged with a reason.
2. **My own mascot.** Two preset animal skins and a gallery of animated backgrounds are available. If the photo prototype passes, a person can take or pick a photo to derive colors and markings on the device. The original stays on the phone and is never copied to app storage. One saved mascot definition renders in chat, voice mode, mood and the game ([decision D4](#9-decisions-that-need-the-owner)).
3. **More natural voices.** If Kokoro passes the [Phase 3](#phase-3-android-voice-spike) checks, its Spanish voices replace the Supertonic styles. The person previews each voice and the app remembers the choice. Test the guided switch on a phone with the old model installed. If the checks fail, the existing engine remains available.
4. **Mood screen.** The person records how they feel, and the mascot shows that state. A timeline groups the records by hour. Done when a record appears in the timeline at its local hour, the mascot animation matches the recorded state, and the data follows the same deletion and privacy rules as chat. A view for health professionals ("mi paciente") is deferred beyond v0.2 ([decision D6](#9-decisions-that-need-the-owner)).
5. **A small world to bring back to color.** A 2D game where the mascot walks a round world that starts gray. Each challenge restores the color of one zone. Progress follows the account across restarts and reinstalls, and the game respects reduced motion ([decision D7](#9-decisions-that-need-the-owner)).
6. **Sala Marlix beta.** A text-only community to practice social skills, opened first as a moderated beta by invitation. It has reporting, blocking and opening criteria. Sala content never enters the private chat or Marlix's memory. Done when the beta start conditions A to F of the [v0.2 design](../design/marlix-v0-2.md#sala-de-marlix-scope) pass. Opening to everyone keeps its own criteria.
7. **DeepSeek as the conversation model.** Marlix's replies come from DeepSeek once a synthetic evaluation shows equal or better quality at an acceptable latency and cost, and once the owner accepts the privacy change ([decision D1](#9-decisions-that-need-the-owner)). The crisis protocol, the transcript and the memory keep working as they do today.
8. **Account email codes.** Sign-up and recovery continue to use the existing production sender. Verify delivery and code entry against the release build. A Marlix-owned sender is deferred ([decision D3](#9-decisions-that-need-the-owner)).
9. **A renewed support website and an illustrated manual.** The support site is redesigned, and a manual explains each screen with images of the approved interface. Both pass a review in Chrome with WebMobileFirst at phone widths, and every image matches the shipped build.

## 2. Dependency compatibility and selected tools

DeepSeek is the only paid service approved for this release, subject to the approved top-up and the existing monthly cap. Keep the other services on free plans. Use the selected tools in this table and apply the documented fallbacks at the phase exit checks. Reopen a tool decision only if its required check fails and its fallback cannot satisfy the phase. Continue independent work in the authorized queue when an approval or prerequisite blocks a specific delivery.

| Feature | Selected tool | Integration | License | Operating cost | Quota and what happens at the limit | Fallback or deferred option | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Conversation | DeepSeek `deepseek-flash` (model DeepSeek-V4.1-Flash-1017), thinking off ([models and pricing](https://api-docs.deepseek.com/quick_start/pricing)) | New `LlmProvider` adapter in `api/src/shared/infrastructure/ai/`, OpenAI-format base URL `https://api.deepseek.com` | Proprietary API ([Open Platform terms](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html), effective 2026-04-29) | Prepaid balance. Per 1M tokens, off-peak and peak: input cache hit 0.003 and 0.006, cache miss 0.15 and 0.30, output 0.60 and 1.20 USD. Peak is 01:00 to 04:00 and 06:00 to 10:00 UTC on weekdays, which is 19:00 to 22:00 and 00:00 to 04:00 in Costa Rica. Estimate for 6,000 turns a month at the v0.2 token profile: about 4.6 USD off-peak and 9.2 USD at peak with no cache hits, before VAT (inferred) | 2,500 concurrent requests per account, then HTTP 429 ([rate limit](https://api-docs.deepseek.com/quick_start/rate_limit)). HTTP 402 when the balance is empty ([error codes](https://api-docs.deepseek.com/quick_start/error_codes)) | Groq Free `openai/gpt-oss-120b`, today's model, with ZDR | [Phase 2](#phase-2-deepseek-evaluation) |
| Crisis classifier | Groq Free `openai/gpt-oss-20b`, unchanged | Existing | Groq terms | 0 | Free-plan limits per model. A failure counts as a crisis (fails closed) | DeepSeek safety checks as an extra signal, never as the only one | Phase 2 runs `npm run crisis:eval` with DeepSeek as the chat model |
| Voice transcription | Groq Free `whisper-large-v3-turbo`, unchanged | Existing `POST /v1/transcribe` | Groq terms | 0 | Free audio-seconds quota. Text chat keeps working when it runs out | Existing text chat | Phase 10 measures latency on the current path |
| Speech | Kokoro v1.0 multi-language int8 through `sherpa_onnx` 2.0.3 on pub.dev, `lang=es` ([config](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/csrc/offline-tts-kokoro-model-config.h)) | On the phone. The app downloads `kokoro-int8-multi-lang-v1_0.tar.bz2` (132 MB, [tts-models release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models)) and checks a pinned SHA-256, as it does for Supertonic today | sherpa-onnx Apache-2.0. Kokoro weights Apache-2.0 ([model card](https://huggingface.co/hexgrad/Kokoro-82M)) | 0 | Works offline after the download. Spanish voices: `ef_dora` (female), `em_alex` and `em_santa` (male) ([VOICES.md](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)) | Supertonic 3, today's engine: OpenRAIL-M weights, 31 languages including Spanish, 10 preset styles, 398 MB. Piper `es_MX` or `es_AR` voices, 21 to 114 MB, voice data licenses differ per voice ([voices.json](https://huggingface.co/rhasspy/piper-voices)) | [Phase 3](#phase-3-android-voice-spike). **Unverified:** sherpa-onnx 2.0 removed espeak-ng ([#3731](https://github.com/k2-fsa/sherpa-onnx/issues/3731)), so Spanish needs a lexicon or a G2P. Words missing from a lexicon are skipped |
| Mascot rendering | The existing vector layers (`app/assets/avatar/`) drawn by one renderer, reused by Flutter widgets and the game | `flutter_svg` (MIT, in use) and a Flame component | MIT | 0 | None | Rive runtime (MIT). Free Rive exports play a Rive splash screen and removing it is paid ([pricing](https://rive.app/pricing)), so Rive needs [decision D5](#9-decisions-that-need-the-owner) | [Phase 4](#phase-4-reusable-mascot-spike) |
| Avatar physics | [sensors_plus 7.1.1](https://pub.dev/packages/sensors_plus) and a pure Dart gravity and spring simulation | Android accelerometer including gravity, shared pose for Flutter and Flame | [Package license](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/sensors_plus/sensors_plus/LICENSE) | 0 | Local sensor stream while visible | Resting pose on missing sensor or reduced motion | Phase 4 spike and Phase 8 integration |
| Photo to mascot look | On-device segmentation with MediaPipe Image Segmenter (Apache-2.0, [repo](https://github.com/google-ai-edge/mediapipe)), then a color quantizer (`material_color_utilities` 0.13.1) maps the result onto the mascot template | `camera` 0.12.2 or `image_picker` 1.2.4, then a pure Dart trait extractor | Apache-2.0 | 0 | None. The photo is not stored or uploaded | Ship the two animal presets if local segmentation fails the Phase 4 gate | Phase 4 prototype, Phase 8 build. **Unverified:** the license of `material_color_utilities` and the MediaPipe Flutter path |
| Making the look animatable | A fixed template rig per species (head, ears, eyes, mouth, body, tail) whose layers take the extracted traits. Animation is code, not per-mascot artwork | Pure Dart model plus the renderer above | MIT | 0 | None | Meta AnimatedDrawings (MIT, archived, built for human figures, Python) is rejected | Phase 4 |
| Animated backgrounds | Flutter `CustomPainter` and fragment shaders, which ship with Flutter | Background layer behind the mascot | BSD-3 (Flutter) | 0 | None. Reduced motion shows a still frame | `lottie` 3.8.2 (MIT) | Phase 7 |
| 2D game | Flame 1.38.2 (MIT, [repo](https://github.com/flame-engine/flame)) | New `app/lib/features/game/` | MIT | 0 | None | Plain Flutter `CustomPainter` | Phase 13 |
| Mood records | A new Supabase table with RLS in the existing projects | New `mood` module in the API and feature in the app | Not applicable | 0 | Supabase Free, 500 MB of database per project | Records kept only on the phone | Phase 12 |
| Sala | Supabase tables and API polling every 3 seconds, as designed in v0.2 section 3.6 | New `sala` module | Not applicable | 0 | Render Free and Supabase Free limits. The polling load is an opening criterion | Supabase Realtime | Phase 16 |
| API hosting | Render Free, today's host (`render.yaml`) | Existing | Proprietary, free plan | 0 | 750 instance hours a month. A service sleeps after 15 minutes without traffic | None planned | None |
| Database | Supabase Free, production and staging | Existing | Proprietary, free plan | 0 | 2 projects. A project pauses after a week without activity (staging keepalive) | None planned | Carried item C1 below |
| Sending account codes | Dedicated Gmail SMTP in staging and the existing custom SMTP in production | Supabase Auth with the six-digit templates in `infra/auth/` | Existing services | No additional spend | Verify delivery, recovery and resend under the configured rate limits ([Supabase SMTP guide](https://supabase.com/docs/guides/auth/auth-smtp)) | Resend Free is a future option if Marlix has a [verified sending domain](https://resend.com/docs/dashboard/domains/introduction) | Phases 1a and 14 |
| Support mailbox and domain | Existing support contact. Own-domain sender and mailbox deferred | Keep the support contact reachable from the website | Existing service | 0 additional spend | A future domain requires its own approval | Cloudflare Email Routing for forwarding after domain approval | Phases 14 and 15 |
| Support website and manual hosting | GitHub Pages when the owner makes the repository public | Existing `.github/workflows/pages.yml` | Hosted service | 0 | The current GitHub Free setup requires a public repository | Cloudflare Pages Free for `site/` if the privacy policy must be public sooner. The [free limit](https://developers.cloudflare.com/pages/platform/limits/) is 500 builds per month | Phase 15 |
| Prototypes and responsive review | Installed `ui-ux-pro-max` skill and the free [WebMobileFirst extension](https://www.webmobilefirst.com/es/) in the owner's Chrome | Serve three navigable prototypes locally. Use the same extension for the support site, manual, and a Flutter web preview when available | Free browser extension | 0 | Preview a local or hosted web URL | Existing Android emulator or device for native checks | Phases 6, 7 and 15 |
| Monitoring | UptimeRobot Free on `/health` (`docs/operations/monitoring.md`) | Existing | Proprietary, free plan | 0 | 50 monitors, 5-minute checks | None | v0.2 question C11: confirm the monitor exists |
| CI | GitHub Actions | Existing `.github/workflows/` | Not applicable | 0 | A private repository gets 2,000 minutes a month on GitHub Free (listed by itsfree.dev, **unverified** officially). A public repository has no minute limit | None | Watch the minutes while the repository stays private |

**Sources for discovery.** The catalog [itsfree.dev](https://itsfree.dev/es) (143 resources, last reviewed October 2026) suggested Resend, Brevo, Unitpost, Mailtrap, Cloudflare Pages, Penpot and UptimeRobot. Each row above cites the official page where the condition was confirmed, or says **unverified**.

**VoiceStudio.** [VoiceStudio](https://github.com/debpalash/voicestudio) is an AGPL-3.0 desktop, server and phone app, not a library, so Marlix uses an engine it offers, not VoiceStudio itself. Its Android app offers KittenTTS mini, Kokoro multi-language, Piper Lessac, Supertonic 3, Pocket TTS, ZipVoice and OmniVoice (`mobile/contract/SPEC.md` in that repository). The Kokoro build it ships, `kokoro-int8-multi-lang-v1_1`, is version 1.1, which covers Chinese and English only. Spanish is in Kokoro version 1.0. The other phone engines do not fit. Pocket TTS terms are non-commercial. The OmniVoice weights are CC-BY-NC and weigh about 1.4 GB. Piper Lessac is English. The KittenTTS 2 weights use the Stellon Labs Community License, which needs a review before use.

## 3. Repository structure

### Code layout

Marlix keeps the Clean Architecture and domain-driven layout it is adopting. Row A0 of the [phase status table](#phase-status) records the state of that move. Code is grouped by capability:

- **API**: `api/src/modules/<capability>/{domain,application,infrastructure,presentation}`. Today's capabilities are `conversation`, `safety`, `memory`, `identity` and `usage`. `api/src/shared/` holds the model port (`application/ai/`), the provider adapters (`infrastructure/ai/`) and the configuration.
- **App**: `app/lib/features/<capability>/{domain,application,infrastructure,presentation,composition}` for `account`, `conversation`, `safety`, `memory`, `settings`, `avatar` and `voice`, plus `app/lib/shared/` and `app/lib/bootstrap/`.
- **Composition roots**: `api/src/bootstrap/` assembles production adapters and the HTTP app. `app/lib/bootstrap/` initializes the native adapters and Riverpod wiring. The [architecture guide](../design/architecture.md#code-organization) describes who owns each rule.

New capabilities follow the same layout: `mascot` (renamed from `avatar` in Phase 4), `mood`, `game` and `sala`. Rules:

- The domain imports no framework, SDK or HTTP code. The architecture tests (`api/test/llm-boundary.test.ts`, `app/test/architecture_test.dart`) gain one rule per new boundary.
- A port and an adapter exist only where a real boundary exists: a model provider, a TTS engine, a camera, storage or the network. A use case with one caller and no boundary stays a function.
- Give each file one responsibility and place it in the layer that owns it. Use comments to explain decisions or constraints.
- The mascot is one data shape, `MascotSpec`: species template, palette, markings, accessories, preset skin and background ID. Chat, voice, mood and game render that same value. The spec is the only thing saved, so the look cannot drift between screens.

## 4. Phases

Each phase targets one verifiable day of work. Split larger phases into deliveries that each close on their own check. Verify behavior through the applicable app or API entry point. Close a phase once its exit gate has evidence in `docs/qa/phase-<n>-evidence.md` with the commands run, actual results and any checks still unverified. Update the phase status and the next action in this plan when the evidence changes.

Run A0 and Phase 1 before the three experiments in Phases 2, 3 and 4. The experiments are independent and run before visual or feature implementation. Then follow Phases 5, 6 and 7. Phases 8 through 17 depend on Phase 7 and the dependencies listed below. Phase 18 closes the release.

### Phase 0. Plan consolidation

- **Deliverables:** Consolidate the release schedule, acceptance gates, open decisions and status into this plan. Retire the old tracking files and update active links.
- **Exit gate.** The current plan is the only active release tracker and is linked from the README and relevant design and development docs.
- **Evidence:** Plan consolidation landed on `main` in the documentation commits from `a379210` through `47aa03f`.

### Phase A0. Architecture move

- **Deliverables:** Group backend and app code by capability, add dependency-direction checks and update documentation paths.
- **Exit gate.** API and app checks pass on the moved code, the candidate passes staging, the verified code is on `main`, and the production deployment and health check are confirmed.
- **Evidence:** API and app moves are in `c3099a3` and `9390079`. Staging ran `a379210`. See [A0 evidence](../qa/phase-a0-evidence.md) and the [local composition follow-up](../qa/phase-a0-evidence.md#local-composition-follow-up).

### Phase 1. UX audit and bug fixes

- **Depends on:** the integrated A0 candidate for local and staging checks. Production verification remains an A0 exit gate.
- **Method:** a heuristic and functional audit guided by `ui-ux-pro-max`. It runs on the `Pixel_8` emulator against staging: the release APK, and a debug build when a step needs it. Each flow is a list of steps, and each step has an expected result and an observed result.
- **Account emails:** test delivery with the dedicated Gmail sender and the Marlix code templates in staging ([decision D13](#9-decisions-that-need-the-owner)). If a code does not arrive, record the affected step and continue the remaining audit. Phase 14 verifies the existing production sender.
- **Flows:**
	- **Sign-up and access:** sign-up with the six-digit code, sign-in, wrong password, password recovery, age check, AI notice, consent, onboarding, sign-out, delete account.
	- **Chat:** send, streamed reply, retry after a failure, history paging, the warning before the daily limit, the daily limit itself, crisis reply, offline.
	- **Voice mode:** microphone permission (granted, denied, permanently denied), model download (wifi, mobile data, no space, cut and resumed), listening, speaking, interruption, errors, leaving the screen.
	- **Settings:** reading aloud, reminders, voice choice, account.
	- **Help:** both help lines, the dialer opens without calling, the offline list, the 9-1-1 button.
	- **Across all screens:** TalkBack, text at 200 %, contrast, 48 dp targets, the keyboard (#188), consistent voseo (#187), the session notice (#186).
- **Severity:** S1 blocks a flow or breaks safety. S2 is wrong behavior with a workaround. S3 is a visual or copy defect. S4 is polish.
- **Deliverables:**
	- **1a.** Audit sign-up and access, and help. Findings table with screenshots.
	- **1b.** Audit chat, voice mode and settings. Findings table with screenshots.
	- **1c.** Fix the S1 and S2 findings of 1a, each with a regression test.
	- **1d.** Fix the S1 and S2 findings of 1b, each with a regression test. Re-run every audited step.
- **Exit gate.** Every audited step has a pass result with a screenshot. No S1 or S2 finding is open. S3 and S4 findings are fixed or listed with a target phase. Issues #186, #187 and #188 are closed or re-triaged with a reason. `npm run typecheck`, `npm test` and `npm run build` pass in `api/`. `flutter analyze` and `flutter test` pass in `app/`. The release APK passes the sign-up, chat and help steps on the emulator.
- **Evidence:** `docs/qa/phase-1-evidence.md` with the findings table (ID, flow, step, expected, observed, severity, screenshot, fix commit) and `docs/qa/phase-1/` for screenshots with no personal data.

### Phase 2. DeepSeek evaluation

- **Selected model:** DeepSeek Flash through the official API. Build the local harness and synthetic fixtures first. The live evaluation requires the owner's key and approval of the first prepaid top-up ([decision D1](#9-decisions-that-need-the-owner)). Use synthetic conversations for every evaluation request.
- **Deliverables:**
	- **2a.** A harness `api/scripts/model-eval.ts` behind the existing `LlmProvider` port. A synthetic dataset in `api/eval/`: 30 Spanish conversations of 8 turns, written in voseo, covering company, loneliness, a bad day, «Recordá esto», short voice replies, and refusals of clinical advice. The run spaces Groq calls 25 seconds apart.
	- **2b.** Run `deepseek-flash` (thinking off) against `openai/gpt-oss-120b`. The owner and two or three testers pick the better answer in each blind, anonymous pair.
- **Quality:** DeepSeek wins or ties in at least 2 of 3 pairs. The reply review (`api/src/modules/safety/domain/rules.ts`) flags no more replies than with Groq. Every reply keeps voseo and the length rules of `docs/design/system-prompt.md`.
- **Latency:** the median time to the first streamed sentence is at most 300 ms slower than Groq. The run also reports p90 for peak and off-peak hours.
- **Cost:** the measured input, cached input and output tokens per turn give a monthly estimate under the USD 10 cap with VAT, for the low, expected and high scenarios of v0.2 section 6.
- **Safety:** `npm run crisis:eval` passes unchanged. The crisis filter runs before the model, so a crisis message never reaches DeepSeek. That claim is checked with a test, not assumed.
- **Provider terms:** require written zero data retention and no training terms that cover the Marlix account and endpoint before using real data. The [stateless Responses API](https://api-docs.deepseek.com/api/create-response/) describes conversation state. Sections 6 and 7 of DeepSeek's [Open Platform privacy policy](https://cdn.deepseek.com/policies/zh-CN/deepseek-open-platform-privacy-policy.html) separately describe processing and possible uses of de-identified API inputs and outputs. Record whether the required account terms are available. Continue synthetic work while that decision is open.
- **Transcript, memory and crisis protocol:** apply the v0.2 budget and privacy contract above, including the separate legacy-client path. Send only the context needed for the turn. Exclude account identifiers and avoid logging message contents in telemetry and errors. Verify the outbound requests and logs using synthetic data. Keep memory extraction and the crisis protocol on their existing paths. A 402 or 429 shows the existing error with the help button.
- **Exit gate.** Record quality, latency, cost, request minimization and crisis regression results. Reconcile spend with the usage dashboard when available. Phase 11 can prepare the adapter in staging with synthetic data. If the production gate stays open, follow the current-provider fallback in Phase 11.

### Phase 3. Android voice spike

- **Depends on:** the owner confirms the Galaxy S24 is free. Listeners are available.
- **Deliverables:**
	- **3a.** A throwaway spike app outside the repository runs Kokoro v1.0 int8 in `sherpa_onnx` 2.0.3 with `lang=es` on the `Pixel_8` emulator, the low-end AVD and the S24. Record the size on disk, the peak memory, the real-time factor and the time to the first word.
	- **3b.** Settle the Spanish front end without espeak-ng: a Spanish lexicon, the rule-based G2P discussed in sherpa-onnx issue #3731, or a small Dart G2P. Count the words the front end skips in the test phrases.
	- **3c.** A blind listening test of Kokoro `ef_dora`, `em_alex` and `em_santa` against Supertonic F4, on the S24.
- **Costa Rican pronunciation:** 40 test phrases with voseo, local words (mae, diay, tuanis, brete, chunche), numbers, 24-hour times, dates, the help-line names and the 9-1-1 number. Listeners score intelligibility and naturalness from 1 to 5.
- **Latency and pauses:** the time from the final transcript to the first audio sample (p50 and p90), and the gap between sentences. The voice must keep the 1.3 real-time-factor rule of the S6-1 decision.
- **Interruptions:** the time from the person's first word to the end of playback while Marlix speaks, and the false-stop rate caused by echo.
- **License check:** every file the app downloads has a recorded license. No GPL code ships in the APK unless the owner accepts it ([decision D8](#9-decisions-that-need-the-owner)).
- **Exit gate.** Record Kokoro's measured results. Ship Kokoro only if it skips no words in the test phrases, matches or beats Supertonic F4 in the blind test, meets the latency rule on the S24 and the low-end AVD, and passes the license check. Keep the existing Supertonic engine if Kokoro fails. Piper stays a future option.

### Phase 4. Reusable mascot spike

- **Depends on:** no other spike. It runs after Phase 1 only because one phase runs at a time.
- **Deliverables:**
	- **4a.** Define `MascotSpec` and one renderer. Draw the same spec in a chat-header widget, a full-screen voice widget, and a Flame scene, on one test screen.
	- **4b.** Prototype the photo-to-traits path on the phone: segmentation, a palette of five colors, and the markings mapped onto the template. Use the owner's own test photos only.
- **Exit gate.** The three surfaces show the same spec with the same colors. Golden image tests compare the widget output, and a screenshot covers Flame. The Flame scene and the widget hold 60 fps on the S24 and the low-end AVD while animating. Validate MediaPipe offline without uploading or storing the original photo. If the photo path fails, defer Phase 8c and keep the animal presets in scope. Record the supported avatar behaviors and the photo verdict.

**4c. Tilt, fall and recovery.** Read accelerometer events through a device port while the mascot is visible. Low-pass filter gravity, map it to display coordinates and drive a bounded spring pose at a fixed simulation step. Side tilt makes the mascot lean and slide toward the lower edge. Inversion makes it tumble against the edge. Returning upright lets it settle into its resting pose. Use the same pose in chat, voice and the game. Keep controls and help buttons stationary. Stop listening when backgrounded, when reduced motion is enabled or when the sensor fails.

**Physics exit gate.** Replay upright, left, right, inverted and upright-again fixtures in Dart tests. Verify direction, bounds and recovery within two seconds, plus sensor loss, resume and reduced motion. Record an S24 demonstration and frame timings on the S24 and low-end AVD against the existing 60 fps target. Phase 8 ships the validated behavior with both preset skins.

### Phase 5. Reproducible local environment

- **Depends on:** Phase 1 (the audit shows what the demo data must cover).
- **Deliverables:**
	- **5a.** `migrate` service and the `tools` profile.
	- **5b.** `api` image and the demo composition root with fictional seed data.
- **Exit gate.** From a fresh clone with `.env.example` copied, `docker compose up` brings `db` and `api` to healthy, and `migrate` exits 0. `GET /health` answers `ok`. The app signs in and chats in demo mode with no real key. `docker compose down -v` followed by `up` reproduces the same state. CI still passes unchanged.

### Phase 6. Three prototypes

- **Depends on:** Phases 1, 3 and 4 (real flows, voice constraints, mascot surfaces).
- **Deliverables:** three navigable prototypes share one journey and one set of fictional data.
- **Exit gate.** The agent opens them in the owner's Chrome with WebMobileFirst at 360 and 412 px, provides the selector and direct local URLs, and records responsive and accessibility checks. The phase waits for the owner's explicit selection or combination before Phase 7 starts.

#### Visual direction and prototype approval

**Method.** The visual phases use the installed `ui-ux-pro-max` skill. Each visual phase attaches the skill's deliverables to its evidence file: a navigation map, a component inventory, an accessibility checklist, and the screen states. The checklist covers TalkBack labels, text at 200 %, a contrast of at least 4.5 to 1, and touch targets of at least 48 dp. The screen states are empty, loading, error, offline, reduced motion and flag off.

**Direction.** A clean, organized mobile app. Muse is the reference for hierarchy and navigation. Its announcement ([Meta, 2026-09-08](https://about.fb.com/news/2026/09/introducing-muse-personal-ai-agent/)) describes the patterns to study. Talking to Muse works like messaging a person. It suggests things on its own and remembers what matters. It asks before sensitive actions and shows a record of what it did. The identity is Marlix's own and centers on the mascot. Muse's visual details (layout, type and spacing) are **unverified**. The announcement text does not describe them, so Phase 6 studies its video and images before drawing.

**Three prototypes.** Use `ui-ux-pro-max` to build three distinct, navigable HTML prototypes of the same journey with the same fictional data. Cover home, chat, voice mode and entry points to the mascot, mood, game and Sala. Serve the prototypes on localhost and provide a shared selector and a direct URL for each option. Open all three in the owner's Chrome with WebMobileFirst at 360 and 412 px. Leave the local server running for the owner to try them. Record the owner's explicit choice or combination in `docs/adr/decisions.md` before starting the Flutter redesign.

**Where each kind of check runs.**

| Check | Where | Tool |
| --- | --- | --- |
| Prototypes, Flutter web preview, support site, manual | Owner's Chrome | Free WebMobileFirst extension with localhost or a hosted web URL |
| APK, native permissions, camera, microphone, on-device voice and Android performance | Existing Android emulator or Galaxy S24 (confirm availability) | `flutter run`, `adb` and SDK command-line tools |

For visual review, serve a Flutter web build when supported. If a feature requires a native plugin, show its visual states in the browser prototype with fictional data and verify the native behavior separately. WebMobileFirst displays web URLs. Android APK installation and testing use the existing emulator or device via CLI. An API deploy follows [Delivery dependencies](#7-delivery-dependencies). The owner publishes the signed Android build.

### Phase 7. Visual foundation in Flutter

- **Depends on:** Phase 6 (the chosen direction).
- **Deliverables:** theme, navigation and home as chosen. This absorbs v0.2 V2-15 (navigation, theme, first use, accessibility) and V2-16 (reduced motion).
- **Exit gate.** Responsive screenshots in WebMobileFirst match the chosen prototype, the accessibility checklist passes, and every existing Phase 1 flow still passes in its applicable web or native runtime. Use the Android CLI for the native checks.

### Phase 8. Mascot

- **Depends on:** Phases 4 and 7. Apply [D4](#9-decisions-that-need-the-owner) to photo processing.
- **Deliverables:** 8a adds animal presets and saved mascot specs. Include the explicit memory-save action and greeting from D10. Verify that saved facts appear only after confirmation and disappear on deletion. 8b adds the animated background gallery and ships the tilt, fall and recovery behavior from Phase 4c. 8c adds on-device photo-to-mascot customization if the Phase 4 photo path passes.
- **Exit gate.** Verify both animal presets, background selection, persistence and consistent rendering in chat and voice. If 8c ships, verify that photo-derived traits are retained and the original is neither uploaded nor copied to app storage. Otherwise record the deferral and verify the preset fallback.
- **v0.2 criteria:** V2-17, V2-18, V2-19 and V2-30.

### Phase 9. New voices

- **Depends on:** Phases 3 and 7.
- **Deliverables:** 9a integrates Kokoro and the verified model download if Phase 3 passes. 9b adds a voice picker with previews and a saved preference. Remove the old download when switching engines and keep the native fallback. If Phase 3 fails, retain Supertonic for this release.
- **Exit gate.** Verify download and fallback behavior, voice previews, and the saved choice after restarting the app. Record the Android engine and the Phase 3 result that supports it.
- **v0.2 criteria:** V2-20.

### Phase 10. Voice mode redesign

- **Depends on:** Phases 7 and 9.
- **Deliverables:** Redesign the voice mode screens and interactions using the chosen visual direction.
- **Exit gate.** Verify the applicable Phase 1 voice flows and record pronunciation, latency, pauses and interruptions on the S24 against the adopted voice criteria.
- **v0.2 decisions:** S6-9, S6-10 and S6-14.

### Phase 11. DeepSeek integration

- **Depends on:** Phase 7, Phase 2 for live validation, and [D1](#9-decisions-that-need-the-owner) for 11b.
- **Deliverables:** 11a implements the provider adapter and spend controls and exercises provider safety checks in staging with synthetic data. 11b updates the privacy disclosures and switches production after approval.
- **Exit gate.** Verify adapter behavior, spend controls and applicable safety checks in staging. For 11b, record approval, privacy updates and the verified production configuration. If D1 stays open or the evaluation fails, record the deferral, verify that real traffic cannot reach DeepSeek and apply the release checks to the existing provider.
- **v0.2 criteria:** V2-07, V2-08, V2-09, V2-11 and V2-12a.

### Phase 12. Mood screen

- **Depends on:** Phases 7 and 8, using the personal-only scope in [D6](#9-decisions-that-need-the-owner).
- **Deliverables:** Mood records, an hourly timeline, the mascot state and deletion with the account.
- **Exit gate.** Verify that saved records appear in the correct hourly slot, the mascot reflects the displayed state and account deletion removes the records.

### Phase 13. Game

- **Depends on:** Phases 4, 7 and 8. Apply [D7](#9-decisions-that-need-the-owner) to account sync.
- **Deliverables:** 13a builds the round world, zones and persistence. 13b adds challenges.
- **Exit gate.** Verify zone navigation and challenge completion on Android, and prove that account progress survives reinstall and sign-in.
- **v0.2 scope change:** This phase replaces V2-21.

### Phase 14. Account email verification

- **Depends on:** Phase 7 and the staging sender setup in [D13](#9-decisions-that-need-the-owner). The existing sender and domain scope follow D3.
- **Deliverables:** Sign-up and recovery verification with the staging sender and the existing production SMTP, with the current support contact retained.
- **Exit gate.** Record real six-digit sign-up and recovery code delivery and successful completion of both flows in staging and in production with the applicable approval.
- **v0.2 criteria:** V2-06a and V2-34.

### Phase 15. Support website and manual

- **Depends on:** Phase 7 and the hosting decision in [D2](#9-decisions-that-need-the-owner).
- **Deliverables:** Redesigned support site and illustrated manual using screenshots of the shipped build.
- **Exit gate.** Verify the responsive layout, manual steps and links to support and privacy information on the approved hosting target.
- **v0.2 criteria:** The website portion of V2-31.

### Phase 16. Sala beta

- **Depends on:** Phase 7 and the existing crisis controls. C8, Q15, Q16, Q18 and Q19 apply to moderation work and the beta opening.
- **Deliverables:** 16a adds the data model, blocking and reporting. 16b adds messaging and moderation. 16c adds user screens and the moderator view. 16d adds safety and privacy verification and the beta review.
- **Exit gate.** Verify blocking, reporting, moderation, polling load and the safety and privacy criteria before opening the beta. Record the opening decision. The beta follows its own gate and the public build excludes Sala while it is closed.
- **v0.2 criteria:** V2-22 through V2-26 and V2-36.

### Phase 17. Offline crisis response

- **Depends on:** Phases 1 and 7.
- **Deliverables:** Run crisis layer 1 on the phone when the API is unavailable.
- **Exit gate.** With networking disabled, submit a crisis test message through the Android app and verify the crisis response and help lines.
- **v0.2 criteria:** V2-37.

### Phase 18. Release

- **Depends on:** All required launch deliveries. Optional photo work, the DeepSeek production cutover and the Sala beta follow their own gates.
- **Deliverables:** Verified release candidate, v0.1 compatibility, release preparation and owner-approved Google Play publication.
- **Exit gate.** Complete the [release gate](#6-release-gate), record the published version and link the evidence.
- **v0.2 criteria:** V2-31, V2-32 and V2-33.

## 5. Docker and continuous verification

### Docker: today and proposal

**Today.** `docker-compose.yml` runs `db` (`supabase/postgres:17.11.0.019`, pinned by digest) and `pgadmin` (`dpage/pgadmin4:9.19.0`, pinned by digest), both on loopback ports with healthchecks and named volumes. `docs/schema.sql` runs once, on the first start with an empty volume. The CI reads the `db` image from this file. The API is not in Docker. It needs a real `*.supabase.co` URL and an `sb_secret_` key (`api/src/shared/infrastructure/config/env.ts`), and `LLM_PROVIDER` accepts only `groq`. So no local mode works without real credentials.

**Phase 5 proposal.** The local environment will use one shared environment block, pinned images, service health checks, a one-shot migration service and mock providers by default.

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

<a id="6-release-gate"></a>

### Release gate

Adapted from the eleven v0.2 launch criteria. Apply the spend, privacy and safety checks to the provider active at launch. DeepSeek activation has the additional D1 gate.

1. Google Play: the closed test is finished and production access is granted (issue #213).
2. A backup restore into staging passed: row counts match, RLS is on in every table, and the app signs in.
3. Verify the spend controls for the active production provider. If DeepSeek is active, reconcile its spend controls with prepaid balance and usage data.
4. The crisis classifier keeps its own model and quota, and `npm run crisis:eval` passes.
5. Real sign-up and recovery codes pass with the staging sender and the existing custom SMTP in production.
6. The launch features pass their phase exit criteria.
7. The production build contains no Sala code, and no public page advertises the Sala while it is closed.
8. The privacy policy, the data safety form and the health declaration list the new processors.
9. The v0.1 APKs still work against the new backend.
10. All checks pass, and the release build is tested on the S24, the low-end AVD and from an internal app sharing link. With the network off, a crisis message shows the crisis response and the help lines.
11. If DeepSeek is active, confirm D1 approval, its spend alert or capped balance, and its applicable safety checks. Otherwise verify that no production request can reach the DeepSeek adapter.

## 6. Cross-cutting working rules

### Execution order when an external check is pending

Within the authorized phase or queue, implement and test each independent delivery first. For 1a, start with help, offline behavior, accessibility and sign-in using a staging test account. Mark real email delivery pending until the sender is ready. Track the A0 production confirmation separately. A missing key blocks the paid evaluation only. A missing phone blocks hardware measurements only. Use synthetic fixtures, emulator sensors and the existing provider adapters for independent work. Record the command, result, blocker and next action in the phase evidence. Keep a phase open until its exit gate passes. Owner actions are limited to credentials, spend, physical-device access, visual selection and deployment or publication approvals under the existing workflow.

### Budget and privacy contract for v0.2

DeepSeek Flash is the only paid API. Keep total monthly spend within USD 10 including tax, disable automatic top-ups and reserve a conservative upper bound for each request and retry before dispatch. Enforce the shared budget atomically across concurrent requests. Stop paid calls when the remaining budget cannot cover one request. Keep crisis response and help available. All other hosted services use their existing free tiers. On quota exhaustion, use the documented fallback or defer the affected feature. No paid upgrade is part of this plan.

**Marlix zero retention for model traffic.** Implement one policy at the API boundary for every provider and call type, including streaming, classification, extraction and transcription. Process prompt bodies, audio, transcripts and replies in volatile request memory only. Disable body logging, SDK tracing, durable retry queues and payload caches. Release buffers on completion, timeout, cancellation or error. Send the minimum context and exclude account identifiers. Persist only content-free operational counters and cost totals. Raw sensor samples stay on the phone.

**User history and memory.** The current product saves chat history for up to 90 days and retains distilled memories. For v0.2 zero-retention sessions, keep the current conversation in volatile client memory, bypass server message writes and persistent memory extraction, and clear the turn buffer on sign-out or session end. Show the session-only behavior before the first message. User-requested saved memories require a separate explicit save and deletion control. Existing records and backups keep their documented expiry and deletion procedures. Document these exceptions before making a public retention claim. Preserve the legacy client contract through a versioned session mode and test both paths.

**Provider boundary.** App-side controls cover Marlix infrastructure. An external API controls its own copy, including provider-side caching. Keep D1 for real personal content. If the required terms are unavailable, DeepSeek stays synthetic-only and the existing approved free provider handles eligible traffic. If no approved provider is available, keep help and the local crisis response available. [DeepSeek API caching](https://api-docs.deepseek.com/guides/kv_cache/) · [Platform privacy policy](https://cdn.deepseek.com/policies/zh-CN/deepseek-open-platform-privacy-policy.html)

**Acceptance.** Phase 2 defines synthetic canary strings and captures outbound request shapes. Phase 11a runs normal, streaming, failed, retried and cancelled turns plus transcription through the staging entry points. Confirm that canaries never appear in database rows, logs, traces, persistent queues or a backup made after the run. Verify that explicit saves can be deleted and that old clients still read their existing history. Test the monthly ceiling with concurrent requests and a simulated 402. Apply these checks to the active provider before Phase 18, even if the DeepSeek cutover is deferred.

<a id="7-delivery-dependencies"></a>

### Delivery dependencies

These facts decide whether a phase can push to `main` on its own. Each one was checked on 2026-11-25.

- **The repository is private.** GitHub Free does not enforce rulesets or branch protection on private repositories, so `main` reads `protected: false` and the "Protect main" ruleset has no effect. Pushes are not blocked today.
- **If the repository becomes public again,** "Protect main" (squash merges only, required checks) rejects a direct push. Direct integration then needs a one-time owner change: add the owner's role as a bypass actor, or replace the pull-request rule with required checks on push. The exact behavior of required checks on a direct push is **unverified**.
- **A push to `main` that changes `api/` deploys production.** `render.yaml` sets `autoDeployTrigger: checksPass` with `rootDir: api` for `marlix-api`. So any phase that changes `api/` waits for the owner's go before its push, or the owner sets production deploys to manual first.
- **A push to `main` that changes `site/` runs the Pages workflow.** The workflow fails while Pages is unavailable ([decision D2](#9-decisions-that-need-the-owner)).
- **Migrations, Supabase settings, Render settings and secrets** require maintainer approval.
- **Five Dependabot pull requests are open** (#233 to #237) on their own branches. They are not part of any phase.

## 7. Main risks

| Risk | Mitigation |
| --- | --- |
| Provider terms or budget block the DeepSeek rollout | Keep evaluation synthetic, apply the monthly ceiling and use the approved free provider for eligible traffic. See D1 and D9. |
| Kokoro fails Spanish pronunciation, licensing or performance checks | Keep Supertonic under D8 and preserve the native fallback. |
| Tilt tracking or avatar motion fails on a device | Test deterministic gravity traces and physical hardware. Use the resting pose when sensors are unavailable or reduced motion is enabled. |
| SMTP, hosting or deployment awaits external action | Continue independent work and record the pending check. Follow the release gate before publication. |
| Local photo segmentation misses the Phase 4 gate | Ship the two animal presets and defer photo customization. |

### Carried over from v0.2

These items were open on the retired board on 2026-11-22. They keep their v0.2 acceptance criteria.

| Item | State | What is left | Who acts |
| --- | --- | --- | --- |
| C1. Staging verification (V2-05a) | Paused | Criteria 1, 2, 3 and 6 have evidence. Criterion 4 passed on 2026-11-22: the integration suite passed 12 of 12 on `Pixel_8` against staging. Criterion 5 fails: the staging keepalive still fails, so an owner action on a repository secret is pending (detail in the private notes). Criterion 7 is rechecked on the next push | Owner, then agent |
| C2. Restore drill (V2-05b) | Waiting for C1 | All four criteria | Maintainer confirms sign-in |
| C3. Google Play publication (#213) | Closed test in progress on `0.1.2+3` | Finish the test and request production | Owner |
| C4. Issues #186, #187, #188 | Open | Phase 1 input | Phase 1 |
| C5. Service-role grants on staging | Applied by hand on 2026-11-22 | Decide whether `docs/schema.sql` or `docs/operations/development.md` states them for new projects | Owner |
| C6. Groq paid plan (V2-35), separate classifier organization (V2-12b) | Superseded if D1 and D9 are approved | Nothing, unless the owner keeps Groq | Owner |
| C7. «Recordá esto» (V2-13), greeting and reminder migration (V2-14), medical-urgency layer (V2-27), ARCore and 3D spikes (V2-29), stable hostname (V2-06b), GitHub Issues and Projects (V2-04, C10) | Approved in v0.2, absent from the new list | Apply the recorded scope in D10 | Phase 8 |

<a id="9-decisions-that-need-the-owner"></a>

### Release decisions and owner actions

| ID | Decision | Execution rule | Blocks |
| --- | --- | --- | --- |
| D1 | DeepSeek Flash selected. Synthetic evaluation and staging integration only until production approval | Owner supplies the key and approves the first top-up. Real data requires account-specific written ZDR and no-training terms, the applicable privacy updates, and explicit owner approval. Keep the existing provider if the gate remains open | Live Phase 2 evaluation and Phase 11b only |
| D2 | Keep the repository private during development and use GitHub Pages when the owner makes it public | Use Cloudflare Pages Free for `site/` if the privacy policy needs to be reachable sooner | Owner approves hosting configuration or repository visibility when due |
| D3 | Own domain deferred. DeepSeek is the only paid service in scope | Keep the current production SMTP and support contact. Revisit the domain in a later release | None |
| D4 | Animal avatars only. Process the original photo on the device with MediaPipe | Keep only the derived appearance. Ship animal presets if photo processing fails validation | None |
| D5 | Use the existing vector layers, with Flutter and Flame | Apply Phase 4 renderer checks | None |
| D6 | The "mi paciente" professional view: scope, consent and permissions | Deferred beyond v0.2. Build the personal mood timeline | None |
| D7 | Sync game progress to the account in Supabase | Verify that progress survives reinstall and sign-in | None |
| D8 | Kokoro v1.0 is the selected Android TTS | Validate a Spanish lexicon or G2P approach and applicable licenses. Keep Supertonic if Kokoro fails. Piper stays deferred | None |
| D9 | Apply the release criteria to the active provider | A pending DeepSeek cutover can defer Phase 11b while the release proceeds with the current provider if its checks pass | None |
| D10 | The v0.2 items listed in C7 | Phase 8 implements explicit memory saves and the greeting. Defer the other C7 items beyond v0.2 | None |
| D11 | Who lands the architecture move (row A0) | Answered on 2026-11-25: verify it and commit it. Integration follows D12 | None |
| D12 | How to verify and integrate changes under `api/` while a push to `main` deploys production | Answered on 2026-11-26 for A0: verify the candidate in staging first, then approve the push to `main` with its production deploy | None |
| D13 | Dedicated Gmail SMTP for staging. **Pending setup** | The maintainer enters the app password in Supabase staging. Then configure the six-digit templates and run real delivery checks | Registration and recovery email delivery in Phase 1a |
| D14 | Review three `ui-ux-pro-max` proposals in the owner's Chrome with WebMobileFirst | Owner picks one option or a combination. Record approval before implementing the Flutter redesign | Phase 7 |
