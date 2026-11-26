# Marlix v0.2: a customizable care companion

*   **Author:** WGuillenDev
*   **Status:** Approved (2026-11-20). Public edition, 2026-11-21.
*   **Superseded in part (2026-11-25):** the [next release execution plan](../plans/execution-plan.md) replaces this design's sequence and milestones (section 9) and its earlier development flow, which is now maintained separately. The scope, the constraints, the Sala rules and the acceptance criteria of each task stay in force unless the plan lists a change for the owner's decision.
*   **Public edition:** this file keeps the product scope, architecture and launch criteria. Budget figures, account and provider-console details, the release schedule, open questions about accounts and billing, and notes about security work still in progress are kept in the maintainer's private notes, together with every task's full acceptance criteria.
*   **Language:** this file is in English because everything in the repository is in English ([engineering rules](architecture.md#engineering-rules)). Only in-app copy is in Spanish, and it appears here in guillemets or code, for example «Sala de Marlix» and «Recordá esto».

--------------------------------------------------------------------------------

## Overview

Marlix is an Android app (Flutter) for conversational companionship, for adults aged 18 or older. It has a 2D beagle avatar, text and voice chat, a memory of what the person shares, and a crisis protocol. The backend (`api/`, Node 24, Express 5) is the only component that talks to the language model and to the database (Supabase). Version 0.1 is distributed as an APK on GitHub Releases, and a Google Play release is in preparation.

This design defines v0.2: what gets built, what gets tested before it is included, how spending is controlled, and the process one person uses to develop, publish and maintain it.

**Promise of v0.2.** After one week, a person can say: «I made my Marlix mine, it feels alive, and I can talk to it when I need company. I also have a place to practice how to talk with other people.» The second sentence depends on the «Sala de Marlix» (Marlix Room in the README). While the Sala is switched off, that half of the promise is not met and is not advertised.

**The Sala de Marlix.** A shared text channel where enabled users talk to practice social skills: starting a conversation, asking questions, meeting people and taking part at their own pace. Suggested topics help break the ice and are optional. The Sala is validated first in a **private beta by invitation, with a confirmed host**, and opens to enabled users only once the beta shows it can be moderated well. Opening the Sala does not block the v0.2 launch.

**Constraints that are not negotiable:**

*   A strict monthly spending cap for the whole operation, enforced in code by the spend governor (section 3.2). Nothing depends on revenue from users.
*   One person develops and operates everything. In this document that person is **the author** (also called **the owner** when the text is about operating the service). **The assistant** is an AI coding assistant that works under the owner's rules and authorizations (workflow).
*   The crisis protocol and the help lines do not depend on any spending cap.
*   No diagnosis and no treatment. The person tells Marlix how they feel by voice or text; the camera is only used for the avatar and the environment, never to infer symptoms.
*   Real user data does not go to providers that lack zero data retention (ZDR) or an updated privacy policy.
*   The Sala is text only and is separate from the private chat with Marlix and from its memory.
*   The Sala is not opened to everyone while the coexistence and moderation controls are missing.
*   The [engineering rules](architecture.md#engineering-rules) apply. The execution plan governs the current development flow.

*   Terms for help used in this document: the **help lines** are the 9-1-1 and Línea Aquí Estoy phone lines; the **help button** opens the help screen with those lines; the **help response** is the crisis reply text (`api/config/crisis.json`) together with the help lines.
*   Identifiers used in this document: **S#-#** is a card of the backlog used before v0.2, whose decisions are recorded in `docs/adr/decisions.md` (for example S7-15, the signed release APK); **C#** and **Q#** are open questions; **V2-NN** is a task of the Detailed Implementation Plan.

## The Problem

1.  **v0.1 does not deliver the promise.** The avatar only reacts to the conversation, it cannot be customized, it does not respond to the phone, and there is no place where people practice talking to each other. A memory takes up to 30 minutes to appear, and the person cannot see when Marlix remembers something. The "greeting" is a notification at an hour chosen in Settings; opening the app does not greet.
2.  **Spending must be controlled per use.** A provider's own spending limit applies to a whole account and has no per-use control, so on its own it could stop the crisis classifier together with everything else. v0.2 adds a persistent spend control in the backend before any paid model plan is used.
3.  **The process depends on remembering context.** This design gives each session a single entry point (`status.md`) and a documented task cycle.

**The proposed solution**, in one sentence: ship a bounded v0.2 (three-tab redesign, a living 2D avatar with palette customization, phone voices with samples, «Recordá esto», a greeting by local time, and chat under a spend governor); add the Sala de Marlix validated in a private beta with a host (if it is not ready at release time, v0.2 ships with the Sala off); and keep the photo-to-skin feature, the medical-urgency layer, other chat models and 3D as experiments behind flags with exit criteria.

**The highest risk in v0.2 is the Sala.** It is the only feature where one person can harm another, and Marlix's audience includes people who look for company or are going through a bad moment. A real-time channel is moderated after the message has appeared, and one host does not cover every hour. That is why the Sala has a beta with opening criteria and is not launched directly.

## Goals

Each goal can be checked. The full launch criteria are in the section "Launch criteria" of the technical plan.

*   **G1. Publish on Google Play.** The first version is published when the launch criteria are met, after any testing that Google Play requires. Later updates roll out in stages.
*   **G2. Stay within the budget.** A strict monthly cap holds in every month, including months with a fixed charge or a paid test (section 6). A persistent spend governor with sub-caps per use enforces it.
*   **G3. A living avatar.** New expressions when listening, thinking, speaking and reacting; a wobble when the phone is tilted, a fall when it is turned upside down and a recovery when it is righted; reduced motion. 60 fps on the Galaxy S24 and on the low-end AVD (defined in `docs/operations/development.md`: an Android Virtual Device with API 31, 2 GB of RAM, 2 cores and the software GPU, SwiftShader), and 4 out of 5 testers who answer yes to «¿Sentís que Marlix está vivo?».
*   **G4. Customization.** A palette, pattern and SVG accessory picker, with no photo upload. The choices are saved on the phone and are still there after the app is closed and opened again. This goal is the one place that defines where the look is saved; the Sala profile publishes a copy of the choice IDs only (section 3.6).
*   **G5. Companionship by voice, with control.** Ten voices with samples, the system voice as a fallback, a microphone permission requested in context, and an app that stays usable with text if the permission is denied.
*   **G6. Fast, visible memories.** «Recordá esto» with the notice «Marlix recordó: … · Deshacer»; automatic extraction when a conversation ends after 10 minutes without messages; viewing, editing and deleting are kept.
*   **G7. Greeting and reminder.** A greeting by local time when the app opens; a fixed reminder at 19:00 with no time picker; a one-time migration for people who had chosen another time.
*   **G8. Safety that does not depend on one provider.** The crisis filter answers from local patterns even when any provider fails or the backend cannot be reached (the phone keeps a copy of the patterns), and the classifier has a quota isolated from memory extraction.
*   **G9. Sala de Marlix.** A shared text channel where enabled users talk freely to practice social skills, with optional suggested topics and the customized avatar in the profile. Its scope is defined in the section "Sala de Marlix: scope".
*   **G10. Coexistence and moderation.** In the Sala, any person can block another and report messages or profiles; authorized moderators can remove content, mute or expel according to the rules. The system distinguishes an infraction (harassment, threats, explicit sexual content) from a person who expresses distress or asks for help, and never penalizes the second. The identity of the person who reports is protected.
*   **G11. Separation and privacy of the Sala.** Sala messages do not enter the private chat with Marlix or its memory. The profile shows the avatar without exposing photos or captures. Deleting the account deletes the person's messages in the Sala.
*   **G12. A workflow that resumes in one minute.** A private board as the entry point of every session, with `status.md` at the repository root as its public summary from V2-01, a progress bar that counts finished launch tasks and a separate line for the Sala beta, a documented task cycle from start to finish, and, after C10, GitHub Issues for the detail of each task and a Kanban board on GitHub Projects for its state.

## Non-Goals

*   Private one-to-one chats in v0.2. They are designed in a later update, and the plan is to evaluate requiring both people to accept before the conversation opens.
*   More than one channel, topic rooms, or private rooms for 4 to 6 people. The brief proposed them; the author's decision replaces them with a single shared channel.
*   AI characters as a way to practice social skills. The brief proposed them for the launch; the Sala replaces them.
*   Voice or video between people. It is evaluated later, if the text Sala shows value.
*   Opening the Sala to everyone before the opening criteria are met.
*   Advertising the Sala while it is off (see "Effect on the launch").
*   A staged rollout for the first publication (see section 5).
*   Diagnosis, interpretation of symptoms, severity grading, medication or treatment. If that were ever wanted, it would be medical software and would need a clinical study, professional supervision and health registration.
*   Inferring pain or emotions from the camera or the voice.
*   Cloud voice APIs at launch (no strict spending cap).
*   Supabase Pro ($25 per month). The S7-5 decision (the backup plan, which required Pro before opening) is replaced by a restore tested against a real project.
*   A support mailbox with its own suite (Mailflare).
*   Meta Motivo and Locate 3D: they do not generate avatars or reconstruct spaces, and their license is non-commercial.
*   Real user data in DeepSeek.
*   The 3D avatar and room reconstruction (only their feasibility is tested, section 7).
*   Saving the avatar look in the account (see G4).
*   Charging users. The decision stays open and the plan does not depend on revenue.

## Sala de Marlix: scope

This section is the single place that defines the Sala's stages, entry, infractions, its effect on the launch and its opening criteria. The technical design is in section 3.6.

### Stages

| Stage | What it includes | Who gets in | To move to the next stage |
|---|---|---|---|
| **Off** | Nothing visible. No entry point in the app and no mention in the Play listing. | Nobody. | Meet the conditions to start the beta. |
| **Private beta** | A shared text channel; optional suggested topics; a profile with a nickname and avatar; blocking; reporting messages and profiles; moderation tools. | Invited people, with the confirmed host present. | Meet the opening criteria. |
| **Open** | The same channel for all Marlix users who meet the entry conditions, plus the ban list `room_bans` (section 3.6). | All enabled users (18+, rules and terms accepted, not on the ban list). | Holds as long as the defined moderation coverage holds. |
| **Later update** | Private one-to-one chats, designed separately. The plan is to evaluate requiring both people to accept before the conversation opens. Voice is also evaluated. | To be defined. | Its own design. |

**Entry conditions.** Age 18 or older, accepting the coexistence rules and the terms before writing, and being enabled: by invitation during the beta, and afterwards every user who meets the previous conditions. A person can leave whenever they want.

**Revoking access during the beta.** Access during the beta is the invitation itself, so revoking it needs no ban list. A moderator who expels someone sets `expelled_at` on their profile; the author also removes their row from `feature_flag_users`, so the Sala flag turns false for that account. Every Sala endpoint checks the flag, the profile and the role on each request (section 3.6), so the person loses access at their next request, which with polling is within 3 seconds, and the entry disappears from the app the next time it reads `GET /v1/me`. If the person deletes the account and signs up again, the new account is not invited and cannot enter. The author does not invite again a person who was expelled. `room_bans`, which stops an expelled person from returning with the same email, is required only before the **Open** stage.

### Infractions and requests for help

They are two different cases and are treated differently:

| Case | Examples | What happens | Who acts |
|---|---|---|---|
| **Harassment** | Repeated insults or mockery aimed at someone; following a person who asked to be left alone. | The moderator can remove the message, mute or expel, according to the rules. | Authorized moderator. |
| **Threats** | Threatening to harm another person. | Same as harassment, with review priority. | Authorized moderator. |
| **Explicit sexual content** | Explicit sexual text in the channel or in a nickname. The Sala is text only, and the profile avatar is drawn from the app's own layers. | Same as harassment. | Authorized moderator. |
| **Distress or a request for help** | Sadness, loneliness, physical pain, or saying they plan to hurt themselves. | Not an infraction and not penalized. The person receives the help response with the help lines in private, using the same protocol as the chat with Marlix, and is asked «¿Querés que alguien del equipo te escriba?». | The crisis filter (automatic). The host is told only if the person answers yes (section 3.6). |
| **A mix of both** | A message with distress and an insult. | Both paths apply: private help for the person, and moderator review of the part that breaks the rules. | Crisis filter and moderator. |

### Effect on the launch

*   Opening the Sala to the public **does not block** the v0.2 launch, and no launch task depends on a Sala task (Work order).
*   The production build leaves the Sala out at compile time (`--dart-define=SALA_ENABLED=false`), so it contains no Sala screen or route. The app reads the flag as `const bool.fromEnvironment('SALA_ENABLED')`, so the compiler drops the Sala code from a build where it is false. The beta uses a separate build that includes the Sala, distributed only to invited testers, and it still ships reporting, blocking and the terms.
*   While the Sala is not open, the production app shows no access to it, and the store listing, the privacy policy and the website do not advertise it as available. In the beta build, a missing flag or a failed call to the backend keeps it off.
*   It opens to enabled users when the beta confirms that it can be moderated well (opening criteria, below).

**Conditions to start the beta** (all of them, before inviting anyone):

*   **A. Confirmed host** with known hours.
*   **B. Blocking and reporting** of messages and profiles work in the app, with automated tests and a manual rehearsal using cases of harassment, threat, explicit sexual content, distress and a mix.
*   **C. Moderation tools** (remove, mute and expel, and the moderator's Reports view of V2-36) and at least one authorized moderator.
*   **D. Private help.** The crisis and distress cases in a test set receive the private help response with the same thresholds as `npm run crisis:eval`, and none ends in a penalty.
*   **E. Privacy verified.** Tests show that Sala messages do not reach the chat with Marlix or its memory; that the profile shows only the nickname and the avatar choices, never a photo; that the reported person cannot tell who reported them or when; and that deleting the account deletes their messages and profile.
*   **F. Rules and Play.** The coexistence rules and terms are accepted before writing; the privacy policy is updated; and what Google Play's user-generated content policy requires has been verified (Q18).

**What the beta must show to open the Sala to everyone.** Conditions A to F stay in force. The numbers are a starting proposal and are adjusted with the host before the beta starts:

1.  **Timely moderation.** At least 90% of reports are handled within 24 hours throughout the beta. Proposed minimum duration: 3 weeks, with at least 10 invited people.
2.  **Written coverage.** It is written down in which hours the channel is open and who moderates in each one. Without coverage it does not open (see Q15).
3.  **Value.** Half or more of the invited people return in the second week **and** answer yes to «¿practicaste algo que te cuesta?». If only one of the two holds, it does not open.
4.  **Costs and limits.** The polling load (one request every 3 seconds per open Sala screen, section 3.6) stays within the free plans of Render and Supabase, and the Sala's classifier calls stay within the Sala's own pool without borrowing from other pools (section 3.2). Before opening, polling is compared with Supabase Realtime for the expected number of people.
5.  **Ban list and age.** `room_bans` (section 3.6) is in production and disclosed in the privacy policy, and the author has decided what to do about self-declared age (Q17).

## Open Questions

Questions about accounts, billing, prices and the release schedule are tracked in the maintainer's private notes. These remain open in public:

*   **C7. A health professional to review the medical-urgency layer.** Without that review, the layer does not ship. **Task:** V2-27.
*   **C10. Adopt GitHub Issues and Projects for the v0.2 backlog.** The maintainer decides whether to adopt the board and create backlog issues. See the [execution plan](../plans/execution-plan.md#9-decisions-that-need-the-owner). **Task:** V2-04.
*   **Q12. Model for memory extraction and savings mode.** It must differ from the classifier's model. It is chosen with an evaluation of the extractor. **Task:** V2-12a, V2-11.
*   **Q15. Moderation coverage.** One host does not cover 24 hours. The options are in [Q15. Moderation coverage](#q15-moderation-coverage). **Blocks:** V2-24 and V2-26.
*   **Q16. What happens in the channel to a message that expresses distress.** The options are in [Q16. A message that expresses distress](#q16-a-message-that-expresses-distress). What the host sees is already decided (consent first, section 3.6). **Blocks:** V2-24 and V2-26.
*   **Q17. Self-declared age.** The 18-year rule uses the birth date the person types at sign-up; it is not verified. Opening the Sala to everyone requires deciding what to do about it.
*   **Q18. What Google Play requires for the Sala:** reporting, blocking, accepting the terms before posting, ongoing moderation, and what must be declared in the beta and at opening. **Task:** V2-26.
*   **Q19. Moderators and rules.** Who the authorized moderators are, who writes the coexistence rules, and how many reports per week one person can handle within the 24-hour target. **Task:** V2-26, V2-36.

## Critical User Journeys (CUJs)

### CUJ 1: First use from Google Play

*   **Given**: a person aged 18 or older installs Marlix from Play, with no previous account.
*   **When**: they open the app for the first time.
*   **Then**: they see the notice that Marlix is an AI, create the account and accept the consent, customize their avatar in about 30 seconds, choose a voice with samples and enter the first conversation with a greeting based on the local time. No permission is requested before it is needed. If they are under 18, the database rejects the sign-up.

### CUJ 2: Talking to Marlix when they need company

*   **Given**: the person is signed in and voice mode is available.
*   **When**: they tap the voice button.
*   **Then**: the app asks for the microphone permission at that moment. If they grant it, they talk by voice and can interrupt a reply. If they deny it, the app keeps working with text and explains how to turn it on. If the chat spending cap is reached, Marlix switches to savings mode and, if that is also used up, lowers the daily limit and explains it to the person.

### CUJ 3: Telling Marlix about physical or emotional distress

*   **Given**: the person tells Marlix, by voice or text, how they feel.
*   **When**: they express distress without urgency signals.
*   **Then**: Marlix listens, validates, asks for the intensity if the person wants to give it, and suggests a pause or a breathing exercise. If the distress continues or gets worse, it suggests talking to a professional. It does not diagnose or suggest medication.
*   **When** (medical urgency, only if the `medical_urgency` flag is on): they mention chest pain, shortness of breath, signs of a stroke, fainting, poisoning or heavy bleeding.
*   **Then**: they receive guidance to call 9-1-1 from local patterns, without depending on any provider.
*   **When** (crisis): the crisis filter triggers through the patterns or the classifier.
*   **Then**: they receive the crisis response with the help lines, as in v0.1. If the classifier fails, it counts as a crisis.

### CUJ 4: Asking Marlix to remember something, and controlling memories

*   **Given**: the person is in a conversation.
*   **When**: they tap «Recordá esto» or say those words.
*   **Then**: they see «Marlix recordó: … · Deshacer». They can undo it right away and, later, view, edit and delete the memory in «Lo que Marlix sabe de mí». Automatic extraction also shows the notice. Sensitive data is not saved.

### CUJ 5: Daily greeting and reminder, including existing accounts

*   **Given**: a person who already used v0.1 and had chosen a reminder time other than 19:00 updates to v0.2 (through GitHub; a person who moves to Play uninstalls and starts from scratch).
*   **When**: they open the app for the first time after updating.
*   **Then**: the app marks the migration as done, cancels the previous alarms and reschedules the reminder at 19:00. It shows the notice «Ahora el saludo diario llega a las 7 p. m.» only if the previous time was different. If the reminder was off, nothing changes. Every time the app opens it greets by local time («Buenos días», «Buenas tardes», «Buenas noches») without asking for permissions.

### CUJ 6: Joining the Sala de Marlix and talking

*   **Given**: the person was invited to the beta, their account has the Sala enabled and the host is present.
*   **When**: they open «Practicar» and enter the Sala de Marlix.
*   **Then**: they see the coexistence rules and the terms, and accept them before they can write. They see the participants with their nickname and avatar, read the messages and write whenever they want, with no turns. They can use a suggested topic to break the ice or ignore the topics. They can leave whenever they want. Their Sala messages do not appear in their chat with Marlix and do not enter its memory.
*   **When** (Sala off): a person without the Sala enabled, or with the production build, opens «Practicar».
*   **Then**: they see no access to the Sala and no message that promises it.

### CUJ 7: Blocking someone and reporting a message or a profile

*   **Given**: the person is in the Sala and something makes them uncomfortable.
*   **When**: they tap a message or a profile and choose to block or report, and for a report choose a reason.
*   **Then**: if they block, the two people stop seeing each other within one poll (3 seconds). A block never hides a member from the host or a moderator: the person can stop seeing a staff member's messages, but staff keep seeing theirs, and a person who disagrees with a staff member can write to the author. If they report, the message disappears from their own view at once and goes to moderation, and the app confirms that the report arrived. The message stays visible to everyone else until an authorized moderator decides. The reported person cannot tell who reported, and the report reaches only the authorized moderators.

### CUJ 8: A moderator handles a report

*   **Given**: a report of harassment, a threat or explicit sexual content arrives.
*   **When**: an authorized moderator reviews it in the Reports view of the Sala screen, within 24 hours. A case with two independent reports (from two different accounts) is shown first.
*   **Then**: according to the rules, they decide at once whether to remove the content for everyone, mute or expel; moderation is never delayed. Only a moderator can remove a message for the whole room; reports alone never do, so two people cannot remove a message by agreeing. The action is recorded. The penalized person sees which rule was applied, never the time of the report or who made it. The person who reported receives, in the next daily batch of notices, a notice that it was handled, without the detail of what was done to the other person.

### CUJ 9: Someone expresses distress or asks for help in the Sala

*   **Given**: a person is in the Sala.
*   **When**: they write that they feel bad, lonely, in physical pain, or that they plan to hurt themselves.
*   **Then**: they are not penalized. They receive the help response with the help lines in private, as in the chat with Marlix, and the question «¿Querés que alguien del equipo te escriba?». Only if they answer yes does the host receive a notice, without the message text. If they answer no or do not answer, nothing about them reaches the host, who sees only an anonymous count of help responses for each completed day. What happens to the message inside the channel is defined by Q16.

### CUJ 10: Customizing the avatar and feeling it alive

*   **Given**: the person is in «Mi Marlix».
*   **When**: they choose a palette, pattern and accessories, and tilt, invert and straighten the phone.
*   **Then**: the avatar updates, wobbles when tilted, falls toward the edge when inverted and recovers when straightened. With reduced motion (the app's own setting or the system's) animations are limited to simple changes. The customized avatar is the one shown in the Sala profile. Closing and reopening the app keeps the look, because it is saved on the phone. Reinstalling the app returns the avatar to its default look.

### CUJ 13: Publishing v0.2 and updating it afterwards

*   **Given**: the blocking launch criteria are met.
*   **When** (first publication): v0.2 is published.
*   **Then**: the version is available to Play users. The production build does not include the Sala, and the listing does not advertise it. If something fails, the new features are switched off with their flags from the backend and, if needed, a corrected version is published. Play does not allow going back to a lower version, and the v0.1 APKs keep working against the new backend.
*   **When** (later updates): a new version is published.
*   **Then**: it rolls out gradually and can be paused at any stage.

--------------------------------------------------------------------------------

## Technical Plan (Architecture)

### 1. What changes, and the rules the design follows

v0.2 adds to the existing system. It does not replace the backend, the schema or the crisis protocol. The design follows these rules:

*   **Every risky change, and every feature that must be on for some people only, ships behind a flag** (the Sala, `photo_skin`, `medical_urgency`). `main` deploys to production by itself once its GitHub checks pass (`render.yaml`, `autoDeployTrigger: checksPass`), so a merge is a release of the backend. A flag turns a merged feature on or off without a deploy. Local presentation changes in the app, such as the avatar animation, need no flag: they are checked before release and respect the reduced-motion setting.
*   **Migrations only add.** A column, table or function is added; none is dropped or changed in a way that breaks v0.1 clients. The v0.1 APKs keep calling `marlix-api.onrender.com` and must keep working.
*   **The [engineering rules](architecture.md#engineering-rules) hold:** the app never calls the model, every table has RLS, chat content never goes to logs, and the crisis filter runs before the model. They also apply to the Sala.
*   **No provider can switch off the crisis response.** Layer 1 (local patterns) answers first and depends on nothing external.
*   **Money is a runtime limit, not a plan on paper.** Every model and transcription call goes through the spend governor, which records its cost under a fixed use tag, and the caps are enforced in code.
*   **The phone can answer a crisis without the backend.** The app carries a copy of the crisis layer 1 patterns and the crisis response (section 3.3).

### 2. System overview and environments

```text
                      +-------------------------+
  Android app  -----> |  API (Node, Express)    | -----> Groq (chat, classifier,
  (Flutter)           |  Render URL, later      |        extractor, Whisper)
  - crisis layer 1    |  api.<domain>           | -----> Supabase Postgres
    copy (offline)    |  - flags                |        (accounts, messages, memories,
                      |  - spend governor       |         spend ledger, Sala tables)
                      |  - crisis filter        |
                      |  - Sala read and write  |
                      |    (polling, 3 s)       |
                      +-------------------------+
     |
     +--- Supabase Auth (email codes) ---> Resend SMTP ---> person's mailbox
```

| Environment | Hosting | Database | Purpose |
|---|---|---|---|
| Production | Render free plan, kept awake by an uptime monitor on `/health` (`docs/operations/monitoring.md`); later behind `api.<domain>` if the host allows a custom domain | Supabase Free project 1 | The real service. |
| Staging | A second Render service with automatic deploys off; the author deploys a branch or commit by hand from the Render dashboard before merging | Supabase Free project 2 | Email acceptance test, restore drill, migration rehearsal, Sala rehearsal. Sleeps when idle. |
| Local | Docker Compose (existing) | Local Postgres | Development and the database tests. |

*   Render's free plan gives 750 instance hours per month per workspace. A service kept awake uses about 730 to 744 hours, so only production stays awake; staging sleeps.

### 3. Backend changes

#### 3.1 Feature flags

*   **New:** `GET /v1/me` returns an additive `flags` object. Everything is off when the field is missing or the call fails.
*   The app receives only what it renders: `social_room` (true or false for this user) and `photo_skin`. The production build ignores `social_room` because it does not contain the Sala (see "Effect on the launch").
*   `medical_urgency` is backend-only and is never sent to the app.
*   Storage: a table `feature_flags` (`name`, `mode`: `off`, `invited`, `all`) and a table `feature_flag_users` (`flag`, `user_id`) for invitations. Both tables have RLS enabled with no policy for `anon` or `authenticated`; only the backend (service role) reads them.
*   The `social_room` value for a person is true if the mode is `all`, or if the mode is `invited` and the person is in `feature_flag_users`.

#### 3.2 Spend governor

Why: a provider's spending limit covers a whole account, has no per-use control and, when reached, blocks every key, including the crisis classifier's. The governor is the per-use control and the first barrier; the provider's limit is a second barrier set above it. The governor is a requirement for launch.

*   **Where:** at the service boundary, as two decorators: `governLlm(provider, { use, … })` wraps an `LlmProvider` and `governTranscriber(transcriber, { … })` wraps the transcriber. `createLlmProvider` (`api/src/shared/infrastructure/ai/index.ts`) gains a `governance` option (`{ use, ledger, monitor, prices }`) and builds `withRetry(governLlm(base, governance))`, so the governor sits below the retry and each attempt reserves on its own. `api/src/bootstrap/container.ts` builds five provider instances, each with a fixed tag (`chat`, `classifier_chat`, `classifier_room`, `extractor_auto`, `extractor_remember`), plus the transcriber wrapped with `governTranscriber` under `transcribe`. The private chat's crisis filter uses `classifier_chat`, and the Sala's own `createCrisisFilter(...)` uses `classifier_room` (section 3.6).
*   **Ledger:** a table `llm_spend` with one row per call: `at`, `use`, `model`, `input_tokens`, `cached_tokens`, `output_tokens`, `audio_seconds`, `state` (`held`, `settled` or `released`), `held_micros` (the maximum verifiable cost, in millionths of a USD, with tax), `settled_micros` (the real cost, once known) and `reconciled_at`. The ledger stores no message content and no user id, so it cannot become a second copy of conversations.
*   **Prices and plan as reviewed data:** provider prices live in `api/config/llm-prices.json` and the monthly plan (sub-caps, minimum margin, tax multiplier and fixed charges) in `api/config/spend-plan.json`. Both are reviewed in pull requests, like `api/config/crisis.json`.
*   **Sub-caps per use:** chat, memory extraction (with a share reserved for «Recordá esto»), the private chat's classifier, the Sala's classifier, voice transcription, and a margin. When chat reaches its sub-cap it switches to savings mode, then lowers the per-person daily limit and explains it in the app. When transcription reaches its sub-cap, `POST /v1/transcribe` answers HTTP 429 `VOICE_BUDGET_EXHAUSTED`; the app hides the voice button and text keeps working.
*   **Classifier pools are protected.** Nothing draws from them. When the private chat's pool is used up, it borrows unused headroom of the other uses and then part of the margin; only when nothing is left does the classifier fail closed (an ambiguous message receives the crisis response with the help lines). The Sala's pool never draws from the private chat's pool and does not borrow during the beta.
*   **Streams, retries and failures:** every attempt is counted, including retries and failed calls. Streaming replies report their usage (V2-09), because voice-mode replies stream and are billed even when the person interrupts.
*   **Clock:** the governor's month and day use UTC. The per-person daily limit keeps using Costa Rica time (`daily_usage`).
*   **Alerts and health.** `/health` keeps its current behavior (`docs/operations/monitoring.md`). `/health/spend` reports `degraded` near the end of a classifier pool or the transcription sub-cap; `/health/safety` reports `degraded` when the classifier fails repeatedly or the provider reports that spending is blocked. Their state is kept in memory, so no health check reads the database.

**How the cap holds** with simultaneous calls, retries and interrupted voice replies:

*   **Simultaneous calls.** A database function, `reserve_spend(use, worst_case_micros)`, runs as one atomic statement on a counter row per month and use (`spend_counters`: `spent_micros`, `reserved_micros`, `cap_micros`). It grants the reservation only if `spent + reserved + worst_case <= cap`. After the call, `settle_spend` replaces the reservation with the real cost. A reservation that is never settled stays held at its worst-case value, so a crash never lowers the total.
*   **Size of a reservation: the maximum cost the backend can verify,** from the prompt it sends (tokens counted with a conservative ratio plus a margin), the `max_completion_tokens` it sets, and the uncached price.
*   **Nothing is released on a guess.** A reservation shrinks only when there is evidence of the real cost (the provider's `usage`) or evidence that the call was not billed.

| Outcome of the call | Counts against the cap as | Released or reduced when |
|---|---|---|
| Completed, with `usage` in the response or in the final stream chunk | The real cost | At once: the difference to the reservation is returned |
| The provider answers with an error body (4xx or 429) | The worst case, held | After a reconciliation shows that the provider does not bill such calls; from then on, at once |
| 5xx, timeout or dropped connection | The worst case, held | At reconciliation |
| Stream aborted before the final `usage` | The worst case, held | At reconciliation |
| A reservation never settled (the process crashed) | The worst case, held | At reconciliation |
| Transcription | The billed audio duration at the per-hour price | When the response reports the billed duration, or at reconciliation |

*   **Reconciliation with the provider's data** is done per model and per period with one SQL function, `reconcile_spend(period_start, period_end, model, provider_total_micros)`, described in `docs/spend-reconciliation.md`. If the provider's total is lower than what the ledger holds, held rows are released oldest first; if it is higher, the shortfall is added as spent at once, never to a classifier pool, and an alert fires.
*   **If the ledger cannot be read,** chat and transcription fail closed with the existing "momentary problem" message and the help button visible. Only `classifier_chat` may run without the ledger, at a bounded rate, because refusing it would turn every ambiguous message into a crisis response. The Sala becomes read-only while the ledger is down.

#### 3.3 Model roles, quota isolation and provider failures

| Use | Model and provider | Notes |
|---|---|---|
| Chat | `openai/gpt-oss-120b` on Groq, ZDR on | Groq says it does not retain inference data by default and, with ZDR, does not retain it for abuse review either. Data is stored on GCP in the US. |
| Crisis classifier | `openai/gpt-oss-20b`, **exclusive** | The classifier gets a model and quota of its own (V2-12a, V2-12b). It reads its own variables (`CRISIS_CLASSIFIER_MODEL` and an optional `CRISIS_CLASSIFIER_GROQ_API_KEY`), so moving it is a hosting setting, not code. |
| Memory extraction and savings mode | A different Groq model, chosen with an evaluation of the extractor (Q12, V2-12a) | Groq's rate limits are per model within an organization, so separate models separate the rate limits. |
| Transcription | `whisper-large-v3-turbo`, Groq | Audio is not stored. |
| Other chat models | **Experiment, synthetic data only** | A provider without ZDR or a data processing agreement never receives real user data. |

**Behavior when a provider fails:**

| Failure | Behavior |
|---|---|
| Any | Layer 1 (local patterns) answers first and depends on no provider. |
| Classifier (error, quota, timeout) | Counts as a crisis, as today. Repeated failures mark `/health/safety` as `degraded` and the uptime monitor alerts the author. |
| Provider spend limit reached (`blocked_api_access`, mapped to the error kind `spend_blocked`) | Layer 1 answers; the classifier fails closed; chat shows the current error message with the help button; voice turns off; Sala messages are held; `/health/safety` reports `degraded`. |
| The backend cannot be reached from the phone | The app runs its copy of crisis layer 1 on the message and, on a match, shows the cached crisis response and the help lines (below). Otherwise it shows the current connection error with the help button. |
| Chat | Fallback to another Groq model, never to DeepSeek with real data. If that also fails, the current error message appears with the help button always visible. |
| Reply review | Local rules, for any provider. |
| Medical urgency | Deterministic patterns. Off behind a flag until the professional review. |
| Sala | The message goes through an API endpoint that filters before writing. If the classifier fails, the message is held and the person receives the help lines in private. |

**What always works, whatever the budget.** Five things need no model and no money:

1.  Crisis layer 1 and, when its flag is on, the medical-urgency patterns. They are local code and configuration, make no model call and do not touch the ledger.
2.  The help lines. `GET /v1/help-resources` is public and static, the app keeps an offline copy (added in S3-5), and the help screen and the 9-1-1 button open the phone's dialer with no network.
3.  The crisis response text, which is configuration (`api/config/crisis.json`) and not model output.
4.  **Crisis layer 1 on the phone (V2-37).** The build generates an app asset from the signal lists in `api/src/modules/safety/domain/signals.ts` (including the figurative-death exceptions) and the reply text in `api/config/crisis.json`; the Dart check reproduces the matching logic of `normalize.ts` and `filter.ts`. If the call to the API fails, the app runs the check on the device and, on a match, shows the reply text with the help lines it already caches from `GET /v1/help-resources` (`help_resources.dart`, with its fallback emergency line), so there is a single copy of the help lines on the phone. The patterns are already public in the repository, so shipping them in the APK exposes nothing new. The app never calls a model, and follows the [engineering rules](architecture.md#engineering-rules).
5.  The crisis classifier's own protected pools: one for the private chat and a separate one for the Sala. Nothing draws from them, and neither draws from the other. When the private chat's pool is used up it borrows unused chat, memory or Whisper headroom, then at most half of the margin (section 3.2); only if that is gone does its classifier fail closed (the person receives the crisis response with the help lines, never silence). The Sala's pool does not borrow during the beta; when it is used up, the Sala's ambiguous messages are held and their authors receive the help lines in private (section 3.2). Layer 1 still checks every Sala message, and the help button is visible on the Sala screen.

What stops when its sub-cap runs out: chat replies (after savings mode and the step-down of the daily limit), automatic memory extraction, and voice transcription.

#### 3.4 Memory: «Recordá esto» and automatic extraction

*   **New endpoint** `POST /v1/memories/remember` with `{ message_id }`. It runs the existing extractor on that one message, saves the result through the existing memory store, and returns the saved memory so the app can show «Marlix recordó: … · Deshacer». «Deshacer» calls the existing delete endpoint.
*   **Cost:** one extractor call per request, so it uses little quota and the person is in control.
*   **Automatic extraction** stays, with `CONVERSATION_IDLE_MINUTES` lowered from 30 to 10. It also shows the notice in the app on the next open.
*   **The two barriers against sensitive data stay** (`sensitive.ts` and the extractor prompt).
*   **Discarded:** extracting after every turn. About 6,000 extra calls per month in the expected scenario, and it would share quota with the classifier.
*   **When the memory budget runs out.** The memory sub-cap is split (section 3.2): automatic extraction uses one part, and another part stays reserved for «Recordá esto», which the person asks for explicitly.
    *   Automatic extraction pauses first, until the next month.
    *   If the reserved part is also used up, «Recordá esto» does not call a model. It saves the text of the chosen message as the person wrote it, up to 200 characters, after the local sensitive-data patterns (`sensitive.ts`), and the notice reads «Marlix lo guardó tal como lo escribiste · Deshacer». If the text is longer, or matches a sensitive pattern, the app asks the person to shorten it or explains that it cannot be saved. Viewing, editing and deleting keep working.
    *   Alternatives considered for this case: refuse until next month (the feature disappears at the moment it is used most), or queue the request and extract it later (a memory the person asked for appears days late). The verbatim fallback is the only behavior built.
*   **Why memories appear late today:** the job runs when a conversation has been idle for 30 minutes, started by a timer inside the process or by the next message. The 30-minute rule explains most of the delay. If the service is asleep, the timer does not run either; the uptime monitor in `docs/operations/monitoring.md` keeps it awake.

#### 3.5 Medical-urgency layer

*   A new set of deterministic patterns, next to `signals.ts`, for chest pain, shortness of breath, signs of a stroke, fainting, poisoning and heavy bleeding. A match answers with guidance to call 9-1-1 and the same help section as the crisis response.
*   Configured in `api/config/` (like `crisis.json`) so the text and the list are reviewed as data.
*   Behind the `medical_urgency` flag, backend-only.
*   **It does not ship until a health professional has reviewed the list and the texts** (C7), and the review is recorded in `docs/adr/decisions.md`.
*   Scope stays at orientation: it never diagnoses, grades severity or suggests medication.
*   The 9-1-1 number assumes Costa Rica. If testers from other countries join, the beta is limited to Costa Rica or a regional notice is added.

#### 3.6 Sala de Marlix

The product scope is in "Sala de Marlix: scope". This section is the single place for the Sala's data, reports and moderation mechanics.

**Data model** (all tables with RLS enabled; clients never read or write them directly, only through the API):

| Table | Main columns | Notes |
|---|---|---|
| `room_profiles` | `user_id` (pk, cascade on user delete), `nickname` (unique), `avatar_look` (a small JSON with the choice IDs: palette, pattern, accessories), `role` (`member`, `host`, `moderator`), `rules_version_accepted`, `muted_until`, `expelled_at` | Each client draws the avatar from the app's own SVG layers and these IDs. There is no image upload, no Storage bucket and nothing to moderate as an image. `avatar_look` is a published copy of the look for the Sala, written when the person joins or changes it; it is not a sync or restore of the look (G4). |
| `room_messages` | `id`, `user_id` (cascade), `body`, `topic_id` (nullable), `created_at`, `removed_at`, `removed_by` | Moderation removes a message for everyone by setting `removed_at`. |
| `room_blocks` | `blocker_id`, `blocked_id` (pk on both, cascade) | A block hides both people from each other, except that it never hides a member from the host or a moderator. |
| `room_reports` | `id`, `reporter_id`, `target_user_id`, `target_message_id` (nullable), `message_snapshot` (the reported text, copied when the report is made), `reason`, `status`, `priority`, `resolved_by`, `resolved_at`, `reporter_visible_at`, `purge_at` | Visible to authorized moderators only, through the API. The reported person has no path that reads it. |
| `room_actions` | `id`, `moderator_id`, `target_user_id`, `action` (`remove`, `mute`, `expel`), `rule`, `created_at` | An audit trail of moderation. |
| `room_help_requests` | `id`, `user_id` (cascade), `created_at`, `handled_at` | Only people who answered yes to «¿Querés que alguien del equipo te escriba?». No message text. |
| `room_help_daily` | `day`, `count` | The anonymous daily count of help responses in the Sala, with no user id. |

*   **Suggested topics** are a config file (`api/config/room-topics.json`), not a table. They are optional and appear as a prompt the person can tap.
*   **Retention:** messages are deleted after 7 days by the existing hourly retention job pattern (a starting value to confirm), except messages with an open report, which are kept until the report is resolved. A report, with its snapshot, is purged 30 days after it is resolved.
*   **Account deletion:** foreign keys cascade, as in the existing account deletion, so deleting an account removes the person's profile and `avatar_look`, messages, blocks, help requests and reports as reporter. Reports about the person keep only the snapshot until their purge date, as moderation evidence: `room_reports.target_user_id` and `room_actions.target_user_id` are `ON DELETE SET NULL`, not cascades.
*   **Ban list (required before the Open stage only, not in the beta).** `room_bans` holds a keyed hash (HMAC, with a key kept in the backend's environment) of the normalized email of an expelled person, and the expiry date, 12 months later. It is checked when a person enters the Sala, so an expelled person who deletes the account and signs up again with the same email cannot enter. The hash is personal data under Costa Rica's Ley 8968, so it is disclosed in the privacy policy before it is used. During the beta, access is revoked through the invitation instead (see "Revoking access during the beta").

**Write path** (clients never insert):

```text
App -- POST /v1/room/messages --> API
        1. require session, Sala flag, profile not muted or expelled, rules accepted
        2. per-person rate limit (usage-limiter pattern)
        3. crisis layer 1 (local patterns), then the Sala classifier if ambiguous
           (if the Sala's pool is used up, an ambiguous message is held and its
           author gets the help lines in private; section 3.2)
        4. distress or crisis? -> private help response, the question
           «¿Querés que alguien del equipo te escriba?», +1 to the anonymous
           daily count (what happens to the message itself: Q16)
        5. otherwise insert with the service role
```

*   **Read path (polling).** While the Sala screen is open, the app calls `GET /v1/room/messages?after=<id>` every 3 seconds, and stops when the screen closes or the app goes to the background. One server-side query applies blocks, removals and the reporter's own hides, so there is no client subscription and no Realtime RLS edge case (for example, a removal sent as an UPDATE that a filtered subscriber never receives). With 10 beta members this is about 3 requests per second. Realtime is reconsidered before opening (opening criterion 4).
*   **Access on every request.** `access.ts` checks the Sala flag, `expelled_at`, `muted_until` (for writing) and the role on each request, so a revoked or expelled person loses access at their next poll.
*   **Rate limit.** `POST /v1/room/messages` has a per-person limit (starting values: 6 messages per minute and 200 per day) on the existing `usage-limiter` pattern. A per-person share of the Sala's pool is added before the Open stage, together with `room_bans`.
*   **Endpoints (names fixed in `docs/design/api-contract.md` by the Sala tasks):** `GET /v1/room/messages`, `POST /v1/room/messages`, `POST /v1/room/blocks`, `DELETE /v1/room/blocks/{user_id}`, `POST /v1/room/reports`, `GET /v1/room/reports/mine`, `POST /v1/room/help-requests` (the person's yes), and for moderators `GET /v1/room/moderation/reports`, `POST /v1/room/moderation/actions` and `GET /v1/room/moderation/help`. Every Sala endpoint answers `404` when the flag is off for the account.
*   **Moderator view (V2-36).** A "Reports" view inside the Sala screen, shown only to the `host` and `moderator` roles, lists reports with two-report cases first, the help requests, and the anonymous counts of completed days (never the current day's, which in a small group could point to the author of a message that was just held). v0.2 sends no push or email for moderation.
*   **What a report does:** it hides the reported message from the reporter's own view at once and sends it to moderation with a snapshot of its text. Two reports from two different accounts about the same message raise the case's priority: it is shown first in the moderator view. Only an authorized moderator removes a message for the whole room, so two people cannot remove a message from everyone's view by agreeing.
*   **Moderation is immediate.** A moderator acts as soon as they review a case; nothing delays an action. Each action is recorded in `room_actions`, and the penalized person sees which rule was applied.
*   **Reporter privacy.** The reported person and the other members never see who reported or when: the penalized person sees the rule, never the time of the report, and the API never returns the report time to anyone but moderators. Moderators see the reporter only in the moderator view, and only the minimum needed to ask a follow-up question. The reporter sees the status of their own report through `GET /v1/room/reports/mine`, and a resolution becomes visible to them only in the next daily batch (`reporter_visible_at`, the next 09:00 Costa Rica time after the resolution), so the timing of the notice does not point to them.
*   **Help requests and the host.** A clear risk signal never leaves the backend ([engineering rules](architecture.md#engineering-rules)). The host learns about a person only when that person answers yes, and then sees a help request without the message text. Otherwise the host sees only the anonymous counts of completed days. This holds for every Q16 option.
*   **Separation from Marlix:** the Sala tables are not joined to `messages`, `memories` or the extraction job. A test checks that a Sala message never enters the chat history, the prompt or the extractor.
*   **Costs:** the Sala's classifier calls use the `classifier_room` provider instance and its own crisis filter, so they are charged to the Sala's pool and never to the private chat's pool; the two are separate rows in `spend_counters`. Near the end of the Sala's pool the author is alerted (`/health/spend`).
*   **Terms and rules:** the app shows the rules and terms and records `rules_version_accepted`. Writing is blocked until the current version is accepted.
*   **Age:** the 18-year rule uses the birth date from sign-up, which is self-declared (Q17).

**Pending architecture decisions.** These two have more than one defensible answer. They are not ranked; the author chooses.

##### Q15. Moderation coverage

| Option | Mechanism | Trade-off | Fails when |
|---|---|---|---|
| A. Scheduled hours | The channel is open only during announced hours when a moderator is present; outside them it is closed or read-only. | Every open hour is covered. Less of the free, real-time feel outside the windows, and activity can fragment. | The host misses a window, or people only show up outside it. |
| B. Always open, reviewed afterwards | The channel is always open; reports are handled within 24 hours. | Matches "talk freely in real time". Harm stays visible until someone reviews it. | Harassment happens at night and nobody sees it for hours. |
| C. Always open with a review queue | Messages from new members, or messages an automated check flags, wait for review before appearing. | Less exposure. More classifier cost, drawn from the Sala's own pool, delays in the conversation, and false positives. | The queue grows faster than one person can clear it. |

##### Q16. A message that expresses distress

In every option the person receives the private help response and the consent question, and the host is told only after a yes.

| Option | Mechanism | Trade-off | Fails when |
|---|---|---|---|
| A. Published, plus private help | The message appears in the channel. | The conversation is not interrupted and the person is not silenced. A sensitive message is visible to everyone, which does not follow the rule that a clear risk signal never leaves the backend ([engineering rules](architecture.md#engineering-rules)). | The text includes details others should not read, or people reply without knowing how. |
| B. Held, plus private help | A clear-risk message is not published; an ambiguous message that classifies as safe is published. The private reply explains why it did not appear. | Consistent with the existing crisis protocol. The person who reached out sees their message not appear. | A false positive silences someone who only wanted to talk. |
| C. Visible only to the person and the host | The message is not shown to the channel; the host decides whether to release it. | A human decides, and the channel is protected. The person sees a message as sent that others cannot see, which is a transparency problem, and it depends on the host being present. It also shows the text to the host without consent, so it would need the person's yes first. | The host is absent, so the message never gets handled. |

### 4. App changes

| Area | Change |
|---|---|
| Navigation | Three tabs: **Marlix** (chat and voice), **Practicar** (games and, when enabled, the Sala), **Mi Marlix** (avatar, voice and memories). Settings («Ajustes») opens from the profile. |
| First use | The AI notice, account (18+), consent, a 30-second personalization of the avatar, voice choice with samples, first conversation with a greeting by local time. Each permission is requested when it is needed. |
| Accessibility | TalkBack labels, text up to 200%, contrast, reduced motion, and a text equivalent for everything that is voice. |
| Living avatar | New expressions for listening, thinking, speaking and reacting in `avatar_marlix.dart`. Tilt, fall and recovery from `sensors_plus` (accelerometer and gyroscope; no permission on Android) with spring physics in Dart, and secondary motion in the ears and tail. A reduced-motion switch that also honors the system's `disableAnimations`. |
| Customization | A palette, pattern and accessory picker over the existing SVG layers (`docs/design/avatar.md`). The `photo_skin` experiment is behind its flag. |
| Voice | The ten Supertonic voices (F1 to F5, M1 to M5) with pre-recorded samples; the system voice (`flutter_tts`) while the ~398 MB model downloads and on low-end phones. The microphone permission is requested when the person taps the voice button; if denied, the app keeps working with text. When the API answers `VOICE_BUDGET_EXHAUSTED`, the voice button is hidden until the next day and text keeps working. |
| Crisis without the backend | A generated asset with the layer 1 patterns and the crisis response; used only when the API call fails (section 3.3, V2-37). |
| Memory | «Recordá esto» button and phrase, the notice «Marlix recordó: … · Deshacer», and the existing «Lo que Marlix sabe de mí» screen with view, edit and delete. |
| Greeting and reminder | A greeting by local time on open. The «Hora del saludo» picker is removed. The reminder is fixed at 19:00 and migrated once (below). |
| Games | A breathing exercise led by the avatar, and «¿Qué cambió en Marlix?» (attention). No streaks and no claims about improving memory. |
| Sala | Only in the beta build (`SALA_ENABLED=true`), and entry only when `flags.social_room` is true. Rules and terms screen, channel view refreshed by polling, nickname and avatar profile, block and report actions, suggested topics, the moderator's Reports view, and the help button always visible. |

**UI and UX method.** The interface is designed with the installed `ui-ux-pro-max` skill. It is the working method of V2-15 (navigation, theme and first use), V2-19 (appearance picker), V2-20 (voice picker and microphone permission), V2-21 (games), V2-25 (Sala screens) and V2-36 (moderator view), and a review pass on the UI states of V2-11, V2-13 and V2-14. Each of these tasks attaches to its pull request the deliverables reviewed with the skill: a navigation map, a component inventory, an accessibility checklist (TalkBack, text at 200%, contrast of at least 4.5 to 1, touch targets of at least 48 dp) and the screen states (empty, loading, error, offline, reduced motion and flag off). The issue template gains a "Working method" field, and `status.md` shows "UI method: ui-ux-pro-max" with a link to the task's UI section only while the active task is one of these.

**Reminder migration.** It runs once, marked by `reminders_migrated_v2`. If the reminder was on: `cancelAll`, reschedule at 19:00, and show «Ahora el saludo diario llega a las 7 p. m.» only if the previous time was different. If it was off, nothing changes. The operating-system alarms from v0.1 keep firing until the migration runs, so the marker is written only after the reschedule succeeds. Tests cover each state: on with 19:00, on with another time, off, and first install.

### 5. Hosting, email and Google Play

**Email.** Supabase Auth sends the sign-up and recovery codes through a custom SMTP provider with an own-domain sender. The templates in `infra/auth/` and the six-digit code flow (S7-9) do not change. **Acceptance test in staging:** (1) a full sign-up and a full password recovery in the app; (2) delivery to the main inbox in Gmail and in Outlook, with the domain sender visible and SPF, DKIM and DMARC at `pass` in the headers; (3) resending works after 60 seconds; (4) an expired code is rejected with the neutral message. The email provider is added to the privacy policy as a processor.

**Database.** Supabase stays for production and staging. A restore drill against a real project is a launch criterion: it passes if row counts match, RLS is on in all tables, and the app signs in (`docs/operations/backups.md`). A weekly ping from GitHub Actions keeps the staging project from pausing.

**Google Play.**

*   The production build is signed with the S7-15 key as the upload key, with Play App Signing.
*   Before publication, the exact production AAB is installed on real devices and checked with the production build check below.
*   The data safety form, content rating, target audience and health declaration are kept up to date. The user-generated content declaration is needed only for the update that opens the Sala (Q18).
*   People who installed from GitHub and move to Play must uninstall, because the signatures differ. The release notes say so. v0.2 is also published on GitHub with the same key, so those who stay there update without losing data.

**Production build check (launch).** Run in V2-33 with the exact production AAB of the release.

| # | Setup | Action | Expected |
|---|---|---|---|
| P1 | A device that is not enrolled in the Sala beta. | Install the exact production AAB. Read the installed versionCode with `adb shell dumpsys package io.github.wguillendev.marlix` and open «Practicar». | The versionCode is the production one, and «Practicar» has no Sala entry. |
| P2 | The production AAB, built without `--obfuscate`. | Copy the AAB to a `.zip`, extract `base/lib/arm64-v8a/libapp.so`, and search it with `Select-String -SimpleMatch` for `RoomScreen` and for `HomeShell`, a class every build contains (V2-15). | No match for `RoomScreen`; at least one match for `HomeShell`, which proves the search works. |

A widget test (V2-25) also builds the app with `SALA_ENABLED` false and true: with false, the route table and «Practicar» have no Sala route or entry; with true, they do.

### 6. Budget

The project runs on free plans wherever possible and holds a strict monthly spending cap. The cap covers every charge in the month it is paid, including fixed charges such as a domain and the smallest purchase of any paid experiment. The spend governor (section 3.2) enforces sub-caps per use, and the provider's own spending limit sits above the governor as a second barrier. The figures, the month-by-month check and the provider billing details are kept in the maintainer's private notes.

**Rule for contributors:** a change that adds or alters a model call records its use tag in the ledger and updates `api/config/llm-prices.json` or `api/config/spend-plan.json` when needed, reviewed in the same pull request.

### 7. Experiments and exit criteria

Each experiment is behind a flag or a separate spike. It enters v0.2 only if it meets its criterion. None blocks the launch.

| Bet | Small test | Continue if | Otherwise |
|---|---|---|---|
| Another chat model | Synthetic Spanish conversations compared blind against `gpt-oss-120b`; synthetic data only. | It wins most pairs, voice latency stays close, the cost fits the sub-cap, and real data would need ZDR and an accepted privacy-policy change. | Stay on the current model. |
| `photo_skin` (object photo to 2D skin) | The photo is processed on the phone and is not stored or uploaded; only the skin is saved. | 4 of 5 testers recognize the skin as theirs. | Keep only the palette picker. |
| Object to 3D avatar | Captures of the author's own objects, never of people, with a bounded paid test. | Most objects are recognizable within cost and time limits, and testers prefer it to the 2D skin. | Postpone. |
| Room to 3D scene | ARCore plane detection live (floor and table), without reconstructing the room. | The avatar walks on the detected floor and table on test phones. | Postpone. |
| Voice comparison | Blind listening of 5 phrases against other on-device voices with MIT-compatible licenses. | Another voice wins and its license is compatible with MIT. | Keep Supertonic. |
| Medical-urgency layer | Review by a health professional (C7). | The review is signed and recorded. | The layer does not ship. |
| Sala de Marlix opening | The private beta (see "Sala de Marlix: scope"). | The five opening criteria. | It stays in beta. |

### 8. Launch criteria

All of these block the launch.

| # | Criterion | Task(s) |
|---|---|---|
| 1 | Any testing that Google Play requires before production is complete. | V2-02, V2-03 |
| 2 | The restore drill against a real Supabase project passed. | V2-05b |
| 3 | The spend governor is in production: persistent ledger, every use routed under its own tag including transcription, usage from streams, the `/health/spend` alert, and a first reconciliation against the provider's data. | V2-08, V2-09, V2-10 |
| 4 | The classifier quota is isolated and `npm run crisis:eval` passes. | V2-12a, V2-12b |
| 5 | The own-domain email sender is verified in staging and in production. | V2-06a |
| 6 | The launch features are done with their tests: tabs and accessibility, the living avatar, voices, memory, the greeting with its migration, the games, and savings mode. | V2-11, V2-13 to V2-21 |
| 7 | The production build does not contain the Sala, and the listing, the privacy policy and the website do not advertise it. | V2-31, V2-33 |
| 8 | The privacy policy, the data safety form and the health declaration are updated with the new processors. | V2-31 |
| 9 | The v0.1 APKs still work against the new backend. | V2-07, V2-32 |
| 10 | `npm run typecheck`, `npm test`, `npm run build`, `flutter analyze` and `flutter test` are green; the release build was tested on real devices and the low-end AVD; with the network off, a crisis message shows the crisis response and the help lines. | V2-33, V2-37 |
| 11 | The production model provider runs with ZDR verified and a provider spending limit with alerts. | V2-35 |

Not blocking: the experiments, the stable hostname (V2-06b), and everything about the Sala.

### 9. Sequence and milestones

The dependencies in the [Work order](#work-order) are mandatory; the milestone sequence is recommended. Paid model traffic never runs without the spend governor in production, and the Sala tasks run in order (V2-22 to V2-26).

| Milestone | Content | Done when |
|---|---|---|
| M0. Prepare | Staging (V2-05a), the restore drill (V2-05b), and the checks that decide the publication path. | Staging works end to end and launch criterion 2 is met. |
| M1. Foundations | Own-domain email, flags with the v0.1 contract test, the spend governor, the isolated classifier, and the production model plan. | Launch criteria 3, 4, 5 and 11 are met. |
| M2. Tests | The experiments of section 7, taken only when no P0 or P1 task is next. | Each test has a recorded result against its exit criterion. |
| M3. Features | Tabs, avatar, voices, memory, greeting, games, savings mode, the crisis fallback on the phone. | Launch criterion 6. |
| M4. Sala readiness | Conditions A to F, in parallel with M3, in the beta build. | The beta starts, or its blockers are recorded. |
| M5. Launch | The first publication. | Launch criteria 1 to 11. |
| M6. Opening decision | The beta runs; the opening criteria are checked. | The Sala opens or stays in beta. |

## Alternatives Considered

The alternatives weighed for product scope, models, hosting, email, the avatar, the Sala and the process are recorded with their reasons in the maintainer's private notes. Lasting technical choices that the code depends on are recorded in [`docs/adr/decisions.md`](../adr/decisions.md).

## Future Improvements

*   **Server-side avatar look.** In v0.2 the palette, pattern and accessories are saved on the phone and survive closing and reopening the app (V2-19). Syncing them with the account, and restoring them after a reinstall or on another phone, are future improvements.
*   **Supabase Realtime for the Sala**, if polling stops being enough when the Sala opens.
*   **Private one-to-one chats** in the Sala, designed on their own, with both people accepting before the conversation opens.
*   **Voice between people** in the Sala, if the text channel shows value.
*   **More than one channel** or channels by topic.
*   **Age verification** stronger than the self-declared birth date (Q17).
*   **Automatic reconciliation** with the provider if it offers a per-request usage record or an API.
*   **A helper that prints the progress bars** and a **CI check on `status.md`** (Automation), when the thresholds there are reached.
*   **A 3D avatar** from a captured object and a **reusable 3D scene** from a room, if their feasibility tests pass.
*   **Another chat model with real data**, only if its terms offer zero data retention or a data processing agreement.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

The work is split into tasks named `V2-NN`. Before C10 this list is the v0.2 backlog and `status.md` summarizes its state; at C10 each task becomes an issue. The full acceptance criteria of each task live in the maintainer's private notes until the task becomes a public issue; each pull request states the criteria it closes and their evidence.

**Conventions that apply to every task** (not repeated in each one):

*   **Migrations** follow the [development guide](../operations/development.md#database-migrations): a file `docs/migrations/YYYY-MM-DD-<what-it-does>.sql` that runs once in a transaction, mirrored in `docs/schema.sql`, with its checks added to `docs/verify-migrations.sql` in the same pull request. A privilege or RLS change also adds cases to `docs/schema-test.sql` and updates `docs/design/erd.md`. The owner runs the migration in the Supabase SQL Editor before the merge, then runs `docs/verify-migrations.sql` (every row must say `ok`).
*   **Endpoints** update `docs/design/api-contract.md` in the same pull request, and extend `api/test/legacy-clients.test.ts` (V2-07) when a response a v0.1 client reads changes.
*   **Lasting decisions** are added to `docs/adr/decisions.md` in the pull request that makes them.
*   **`CHANGELOG.md`** is updated at release (V2-31) and when a milestone closes, not in each task.
*   **Tests** for the backend are `api/test/*.test.ts` (run by `tsx --test`); tests for the app are under `app/test/`.
*   **UI tasks** listed in section 4 ("UI and UX method") attach the `ui-ux-pro-max` deliverables to their pull request.
*   **Every task** ends with the checks and evidence in the [execution plan](../plans/execution-plan.md#phase-status).
*   **Roles:** the owner (the author of this design) and the assistant, as defined in the Overview. The plan uses "owner" throughout.
*   **Low-end AVD:** the profile in G3, written into `docs/operations/development.md` by V2-05a; a task that measures on it before V2-05a merges uses the profile in G3.
*   **Not applicable:** a task closed as not applicable is removed from the launch count and counts as met for its dependents.
*   **Worked examples:** a task may reference the numbered criteria of a worked example instead of repeating them (V2-17).

### Work order

The **List** column classifies every task once: **Launch** (blocks the v0.2 launch and counts in the launch bar), **Sala** (blocks only the Sala beta and counts in its own line), **Experiment** (counts in neither), and **Process**.

| Order | ID | Task | List | Milestone | Priority | Depends on |
|---|---|---|---|---|---|---|
| 1 | V2-01 | Set up v0.2 progress tracking | Launch | M0 | P0 | The owner's final approval (recorded as `Status: Approved`) |
| 2 | V2-02 | Verify the external conditions | Launch | M0 | P0 | none |
| 3 | V2-05a | Staging environment | Launch | M0 | P0 | none |
| 4 | V2-05b | Restore drill against staging | Launch | M0 | P0 | V2-05a |
| 5 | V2-34 | Check email delivery and model capacity in staging | Launch | M0 | P0 | V2-02, V2-05a |
| 6 | V2-03 | Complete the Google Play testing requirements, if they apply | Launch | M0 | P0 | V2-02, V2-34 |
| 7 | V2-04 | Move the backlog to GitHub Issues and a board | Process | M0 | P1 | V2-01 |
| 8 | V2-06a | Domain and own-domain email | Launch | M1 | P0 | V2-05a |
| 9 | V2-07 | Feature flags and the v0.1 contract test | Launch | M1 | P0 | V2-05a |
| 10 | V2-08 | Spend ledger, reservations and per-use routing | Launch | M1 | P0 | V2-05a |
| 11 | V2-09 | Stream usage, aborts and graceful shutdown | Launch | M1 | P0 | V2-08 |
| 12 | V2-12a | Separate models for the classifier and the extractor | Launch | M1 | P0 | V2-08 |
| 13 | V2-35 | Configure the production model plan with ZDR and a spending limit | Launch | M1 | P0 | V2-08, V2-09, V2-12a |
| 14 | V2-10 | Evidence rules and reconciliation | Launch | M1 | P0 | V2-08, V2-09 |
| 15 | V2-12b | Isolate the classifier quota from other uses | Launch | M1 | P0 | V2-12a, V2-35 |
| 16 | V2-11 | Savings mode and daily-limit step-down | Launch | M1 | P0 | V2-07, V2-08, V2-12a |
| 17 | V2-37 | Crisis layer 1 on the phone | Launch | M3 | P0 | none |
| 18 | V2-15 | Navigation, theme, first use and accessibility | Launch | M3 | P1 | none |
| 19 | V2-16 | Reduced-motion setting | Launch | M3 | P1 | none |
| 20 | V2-17 | Avatar reacts to device orientation | Launch | M3 | P1 | V2-16 |
| 21 | V2-18 | Avatar expressions | Launch | M3 | P1 | V2-16, V2-03 |
| 22 | V2-19 | Appearance picker | Launch | M3 | P1 | V2-15 |
| 23 | V2-20 | Voices with samples and the microphone permission | Launch | M3 | P1 | V2-15, V2-08 |
| 24 | V2-13 | «Recordá esto» and 10-minute extraction | Launch | M3 | P1 | V2-08, V2-12a |
| 25 | V2-14 | Greeting by local time and reminder migration | Launch | M3 | P1 | none |
| 26 | V2-21 | Games | Launch | M3 | P1 | V2-15 |
| 27 | V2-31 | Release preparation | Launch | M5 | P0 | V2-06a, V2-11, V2-13 to V2-21, V2-37 |
| 28 | V2-32 | Compatibility test with v0.1 clients | Launch | M5 | P0 | V2-07, V2-11, V2-13 |
| 29 | V2-33 | Release checks and publication | Launch | M5 | P0 | V2-03, V2-05b, V2-10, V2-12b, V2-31, V2-32, V2-35 |
| 30 | V2-22 | Sala data model | Sala | M4 | P1 | V2-05a, V2-07 |
| 31 | V2-23 | Sala blocking, reporting and moderation | Sala | M4 | P1 | V2-22 |
| 32 | V2-24 | Sala message path | Sala | M4 | P1 | V2-23, V2-08, V2-12a |
| 33 | V2-25 | Sala screens | Sala | M4 | P1 | V2-24, V2-15, V2-19 |
| 34 | V2-36 | Moderator view and notices | Sala | M4 | P1 | V2-23, V2-25 |
| 35 | V2-26 | Sala safety and privacy tests | Sala | M4 | P1 | V2-24, V2-25, V2-36 |
| 36 | V2-06b | Stable hostname `api.<domain>` | Experiment | M1 | P2 | V2-06a |
| 37 | V2-28 | Model comparison harness (synthetic data) | Experiment | M2 | P2 | none |
| 38 | V2-29 | Feasibility spikes (ARCore planes, object to 3D, voices) | Experiment | M2 | P2 | none |
| 39 | V2-27 | Medical-urgency layer | Experiment | M4 | P2 | V2-07 |
| 40 | V2-30 | Photo-to-skin experiment | Experiment | M4 | P2 | V2-19, V2-29 |

Counts: 28 Launch tasks, 6 Sala tasks, 5 Experiment tasks and 1 Process task. Take experiments only when no P0 or P1 task is eligible.

### Verification Plan

*   **Compilation/Build:** `npm run build` in `api/`; `flutter build apk --release --dart-define-from-file=config/production.json` for the production build check (with `SALA_ENABLED=false`); the production AAB for Play; the beta build with `SALA_ENABLED=true` while the beta runs.
*   **Unit tests:** `npm test` in `api/`; `flutter test` in `app/`.
*   **Static analysis and linting:** `npm run typecheck` in `api/`; `dart format --output=none --set-exit-if-changed lib test integration_test` and `flutter analyze` in `app/` (the same steps the CI runs); the crisis asset check (`npm run crisis:export`, V2-37); CodeQL runs on every pull request but is not a required check yet (S8-1, the CodeQL card).
*   **Database:** the Docker Postgres runs `docs/schema-test.sql`; the CI applies `docs/schema.sql` and `docs/verify-migrations.sql`; in production the owner runs `docs/verify-migrations.sql` after each migration and every row must say `ok`.
*   **Safety:** `npm run crisis:eval` before and after any change to the classifier, its model or its quota; the phone's layer 1 tests (V2-37).
*   **Contract:** `api/test/legacy-clients.test.ts` in CI from V2-07.
*   **Test coverage requirement:** the repository enforces no coverage percentage today. The requirement here is that every acceptance criterion has at least one automated test or one manual step written in its task, with the evidence ticked.
*   **E2E and integration:** the app against staging on the emulator, the low-end AVD and the Galaxy S24 (confirm with the owner that the phone is available); the release build is tested, not only the debug build; the production build check of section 5 runs at each release runs before the beta and at the first release while the beta is live; the v0.1 APK is tested against the new backend.
*   **Cost:** after any change that adds or alters a model call, the ledger shows the new use, `api/config/llm-prices.json` is correct, and `api/config/spend-plan.json` is reviewed; the reconciliation of `docs/spend-reconciliation.md` runs weekly in the first month and monthly afterwards (V2-10).
