# Marlix v0.2: a customizable care companion

*   **Author:** WGuillenDev
*   **Status:** Approved (2026-11-20). Public edition, 2026-11-21.
*   **Public edition:** this file keeps the product scope, the architecture, the launch criteria and the development flow that contributors and reviewers need. Budget figures, account and provider-console details, the release schedule, open questions about accounts and billing, and notes about security work still in progress are kept in the maintainer's private notes, together with every task's full acceptance criteria. Pull requests carry the evidence for each criterion they close.
*   **Language:** this file is in English because everything in the repository is in English (`CONTRIBUTING.md`, "Language and naming"). Only in-app copy is in Spanish, and it appears here in guillemets or code, for example «Sala de Marlix» and «Recordá esto».

--------------------------------------------------------------------------------

## Overview

Marlix is an Android app (Flutter) for conversational companionship, for adults aged 18 or older. It has a 2D beagle avatar, text and voice chat, a memory of what the person shares, and a crisis protocol. The backend (`api/`, Node 24, Express 5) is the only component that talks to the language model and to the database (Supabase). Version 0.1 is distributed as an APK on GitHub Releases, and a Google Play release is in preparation.

This design defines v0.2: what gets built, what gets tested before it is included, how spending is controlled, and the process one person uses to develop, publish and maintain it.

**Promise of v0.2.** After one week, a person can say: «I made my Marlix mine, it feels alive, and I can talk to it when I need company. I also have a place to practice how to talk with other people.» The second sentence depends on the «Sala de Marlix» (Marlix Room in the README). While the Sala is switched off, that half of the promise is not met and is not advertised.

**The Sala de Marlix.** A shared text channel where enabled users talk to practice social skills: starting a conversation, asking questions, meeting people and taking part at their own pace. Suggested topics help break the ice and are optional. The Sala is validated first in a **private beta by invitation, with a confirmed host**, and opens to enabled users only once the beta shows it can be moderated well. Opening the Sala does not block the v0.2 launch.

**Constraints that are not negotiable:**

*   A strict monthly spending cap for the whole operation, enforced in code by the spend governor (section 3.2). Nothing depends on revenue from users.
*   One person develops and operates everything. In this document that person is **the author** (also called **the owner** when the text is about operating the service). **The assistant** is an AI coding assistant that works under the owner's rules and authorizations ([workflow](../workflow.md#agent-assisted-work)).
*   The crisis protocol and the help lines do not depend on any spending cap.
*   No diagnosis and no treatment. The person tells Marlix how they feel by voice or text; the camera is only used for the avatar and the environment, never to infer symptoms.
*   Real user data does not go to providers that lack zero data retention (ZDR) or an updated privacy policy.
*   The Sala is text only and is separate from the private chat with Marlix and from its memory.
*   The Sala is not opened to everyone while the coexistence and moderation controls are missing.
*   The rules in `CONTRIBUTING.md` stay in force, except those this design changes explicitly in the section "Marlix v0.2 development flow".

*   Terms for help used in this document: the **help lines** are the 9-1-1 and Línea Aquí Estoy phone lines; the **help button** opens the help screen with those lines; the **help response** is the crisis reply text (`api/config/crisis.json`) together with the help lines.
*   Identifiers used in this document: **S#-#** is a card of the backlog used before v0.2, whose decisions are recorded in `docs/decisions.md` (for example S7-15, the signed release APK); **C#** and **Q#** are open questions; **V2-NN** is a task of the Detailed Implementation Plan.

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
*   **G3. A living avatar.** New expressions when listening, thinking, speaking and reacting; a wobble when the phone is tilted, a fall when it is turned upside down and a recovery when it is righted; reduced motion. 60 fps on the Galaxy S24 and on the low-end AVD (defined in `docs/development.md`: an Android Virtual Device with API 31, 2 GB of RAM, 2 cores and the software GPU, SwiftShader), and 4 out of 5 testers who answer yes to «¿Sentís que Marlix está vivo?».
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
*   **C10. Adopt GitHub Issues and Projects for the v0.2 backlog.** The author approves the proposal in section 10.9 before the board and its backlog issues are created. Until then, use the [interim workflow](../workflow.md#interim-mode-before-c10). **Task:** V2-04.
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

### CUJ 11: The owner resumes work when opening a session

*   **Given**: the owner opens a new session without remembering the previous state.
*   **When**: they read the private board (`status.md` is its public summary).
*   **Then**: in one minute they see the launch progress bar and the separate Sala beta line, the version goal and the current milestone, the active task with its link, the next tasks in order, the blockers with their cause, dependency and the action that unblocks them, the launch criteria still pending (shown apart from the progress bar), and the concrete next step.

### CUJ 12: The owner closes a task from start to finish

This journey describes the flow after C10. Before C10 the same steps apply without the board and the issue, as [Interim mode](../workflow.md#interim-mode-before-c10) and [The cycle before C10](../workflow.md#the-cycle-before-c10) in `docs/workflow.md` describe.

*   **Given**: a task is in the Ready column of the board, and its issue states the expected outcome, the acceptance criteria, how to verify them, what blocks it and its version.
*   **When**: they take it (it moves to In Progress), work on `wil`, verify the criteria, commit and push, a pull request is opened (In Review) and CI passes.
*   **Then**: after the merge the task is in Done, the issue is closed, and `status.md` already shows the new progress and the next step, because the pull request carried them.

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
*   **The four rules of `CONTRIBUTING.md` hold:** the app never calls the model, every table has RLS, chat content never goes to logs, and the crisis filter runs before the model. They also apply to the Sala.
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
| Production | Render free plan, kept awake by an uptime monitor on `/health` (`docs/monitoring.md`); later behind `api.<domain>` if the host allows a custom domain | Supabase Free project 1 | The real service. |
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

*   **Where:** at the service boundary, as two decorators: `governLlm(provider, { use, … })` wraps an `LlmProvider` and `governTranscriber(transcriber, { … })` wraps the transcriber. `createLlmProvider` (`api/src/services/llm/index.ts`) gains a `governance` option (`{ use, ledger, monitor, prices }`) and builds `withRetry(governLlm(base, governance))`, so the governor sits below the retry and each attempt reserves on its own. `api/src/server.ts` builds five provider instances, each with a fixed tag (`chat`, `classifier_chat`, `classifier_room`, `extractor_auto`, `extractor_remember`), plus the transcriber wrapped with `governTranscriber` under `transcribe`. The private chat's crisis filter uses `classifier_chat`, and the Sala's own `createCrisisFilter(...)` uses `classifier_room` (section 3.6).
*   **Ledger:** a table `llm_spend` with one row per call: `at`, `use`, `model`, `input_tokens`, `cached_tokens`, `output_tokens`, `audio_seconds`, `state` (`held`, `settled` or `released`), `held_micros` (the maximum verifiable cost, in millionths of a USD, with tax), `settled_micros` (the real cost, once known) and `reconciled_at`. The ledger stores no message content and no user id, so it cannot become a second copy of conversations.
*   **Prices and plan as reviewed data:** provider prices live in `api/config/llm-prices.json` and the monthly plan (sub-caps, minimum margin, tax multiplier and fixed charges) in `api/config/spend-plan.json`. Both are reviewed in pull requests, like `api/config/crisis.json`.
*   **Sub-caps per use:** chat, memory extraction (with a share reserved for «Recordá esto»), the private chat's classifier, the Sala's classifier, voice transcription, and a margin. When chat reaches its sub-cap it switches to savings mode, then lowers the per-person daily limit and explains it in the app. When transcription reaches its sub-cap, `POST /v1/transcribe` answers HTTP 429 `VOICE_BUDGET_EXHAUSTED`; the app hides the voice button and text keeps working.
*   **Classifier pools are protected.** Nothing draws from them. When the private chat's pool is used up, it borrows unused headroom of the other uses and then part of the margin; only when nothing is left does the classifier fail closed (an ambiguous message receives the crisis response with the help lines). The Sala's pool never draws from the private chat's pool and does not borrow during the beta.
*   **Streams, retries and failures:** every attempt is counted, including retries and failed calls. Streaming replies report their usage (V2-09), because voice-mode replies stream and are billed even when the person interrupts.
*   **Clock:** the governor's month and day use UTC. The per-person daily limit keeps using Costa Rica time (`daily_usage`).
*   **Alerts and health.** `/health` keeps its current behavior (`docs/monitoring.md`). `/health/spend` reports `degraded` near the end of a classifier pool or the transcription sub-cap; `/health/safety` reports `degraded` when the classifier fails repeatedly or the provider reports that spending is blocked. Their state is kept in memory, so no health check reads the database.

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
4.  **Crisis layer 1 on the phone (V2-37).** The build generates an app asset from the signal lists in `api/src/services/crisis/signals.ts` (including the figurative-death exceptions) and the reply text in `api/config/crisis.json`; the Dart check reproduces the matching logic of `normalize.ts` and `filter.ts`. If the call to the API fails, the app runs the check on the device and, on a match, shows the reply text with the help lines it already caches from `GET /v1/help-resources` (`help_resources.dart`, with its fallback emergency line), so there is a single copy of the help lines on the phone. The patterns are already public in the repository, so shipping them in the APK exposes nothing new. The app never calls a model, so `CONTRIBUTING.md` rules 1 and 4 hold.
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
*   **Why memories appear late today:** the job runs when a conversation has been idle for 30 minutes, started by a timer inside the process or by the next message. The 30-minute rule explains most of the delay. If the service is asleep, the timer does not run either; the uptime monitor in `docs/monitoring.md` keeps it awake.

#### 3.5 Medical-urgency layer

*   A new set of deterministic patterns, next to `signals.ts`, for chest pain, shortness of breath, signs of a stroke, fainting, poisoning and heavy bleeding. A match answers with guidance to call 9-1-1 and the same help section as the crisis response.
*   Configured in `api/config/` (like `crisis.json`) so the text and the list are reviewed as data.
*   Behind the `medical_urgency` flag, backend-only.
*   **It does not ship until a health professional has reviewed the list and the texts** (C7), and the review is recorded in `docs/decisions.md`.
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
*   **Endpoints (names fixed in `docs/api-contract.md` by the Sala tasks):** `GET /v1/room/messages`, `POST /v1/room/messages`, `POST /v1/room/blocks`, `DELETE /v1/room/blocks/{user_id}`, `POST /v1/room/reports`, `GET /v1/room/reports/mine`, `POST /v1/room/help-requests` (the person's yes), and for moderators `GET /v1/room/moderation/reports`, `POST /v1/room/moderation/actions` and `GET /v1/room/moderation/help`. Every Sala endpoint answers `404` when the flag is off for the account.
*   **Moderator view (V2-36).** A "Reports" view inside the Sala screen, shown only to the `host` and `moderator` roles, lists reports with two-report cases first, the help requests, and the anonymous counts of completed days (never the current day's, which in a small group could point to the author of a message that was just held). v0.2 sends no push or email for moderation.
*   **What a report does:** it hides the reported message from the reporter's own view at once and sends it to moderation with a snapshot of its text. Two reports from two different accounts about the same message raise the case's priority: it is shown first in the moderator view. Only an authorized moderator removes a message for the whole room, so two people cannot remove a message from everyone's view by agreeing.
*   **Moderation is immediate.** A moderator acts as soon as they review a case; nothing delays an action. Each action is recorded in `room_actions`, and the penalized person sees which rule was applied.
*   **Reporter privacy.** The reported person and the other members never see who reported or when: the penalized person sees the rule, never the time of the report, and the API never returns the report time to anyone but moderators. Moderators see the reporter only in the moderator view, and only the minimum needed to ask a follow-up question. The reporter sees the status of their own report through `GET /v1/room/reports/mine`, and a resolution becomes visible to them only in the next daily batch (`reporter_visible_at`, the next 09:00 Costa Rica time after the resolution), so the timing of the notice does not point to them.
*   **Help requests and the host.** A clear risk signal never leaves the backend (`CONTRIBUTING.md`, rule 4). The host learns about a person only when that person answers yes, and then sees a help request without the message text. Otherwise the host sees only the anonymous counts of completed days. This holds for every Q16 option.
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
| A. Published, plus private help | The message appears in the channel. | The conversation is not interrupted and the person is not silenced. A sensitive message is visible to everyone, which does not follow the rule that a clear risk signal never leaves the backend (`CONTRIBUTING.md`, rule 4). | The text includes details others should not read, or people reply without knowing how. |
| B. Held, plus private help | A clear-risk message is not published; an ambiguous message that classifies as safe is published. The private reply explains why it did not appear. | Consistent with the existing crisis protocol. The person who reached out sees their message not appear. | A false positive silences someone who only wanted to talk. |
| C. Visible only to the person and the host | The message is not shown to the channel; the host decides whether to release it. | A human decides, and the channel is protected. The person sees a message as sent that others cannot see, which is a transparency problem, and it depends on the host being present. It also shows the text to the host without consent, so it would need the person's yes first. | The host is absent, so the message never gets handled. |

### 4. App changes

| Area | Change |
|---|---|
| Navigation | Three tabs: **Marlix** (chat and voice), **Practicar** (games and, when enabled, the Sala), **Mi Marlix** (avatar, voice and memories). Settings («Ajustes») opens from the profile. |
| First use | The AI notice, account (18+), consent, a 30-second personalization of the avatar, voice choice with samples, first conversation with a greeting by local time. Each permission is requested when it is needed. |
| Accessibility | TalkBack labels, text up to 200%, contrast, reduced motion, and a text equivalent for everything that is voice. |
| Living avatar | New expressions for listening, thinking, speaking and reacting in `avatar_marlix.dart`. Tilt, fall and recovery from `sensors_plus` (accelerometer and gyroscope; no permission on Android) with spring physics in Dart, and secondary motion in the ears and tail. A reduced-motion switch that also honors the system's `disableAnimations`. |
| Customization | A palette, pattern and accessory picker over the existing SVG layers (`docs/avatar.md`). The `photo_skin` experiment is behind its flag. |
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

**Database.** Supabase stays for production and staging. A restore drill against a real project is a launch criterion: it passes if row counts match, RLS is on in all tables, and the app signs in (`docs/backups.md`). A weekly ping from GitHub Actions keeps the staging project from pausing.

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

### 10. Marlix v0.2 development flow

This section extends decision D15 of the brief (one entry point for each session and a visible measure of progress). The goal is a process one person can sustain, where each day starts by reading one file and no context has to be rebuilt. The work follows a Kanban flow: a board shows the state of each task, an issue holds the detail of each task, and `status.md` gives a one-minute summary.

**Two phases.** In [interim mode](../workflow.md#interim-mode-before-c10), `status.md` is the session entry point and records the state of the V2-NN backlog defined in this design. Existing GitHub issues and pull requests keep their own discussion and review. Marlix works from the repository and GitHub. The board, issues for the v0.2 backlog and the rules that need them (10.1, 10.3 and the board columns of 10.6) come into force at C10.

**Where these rules live.** V2-01 moved the rules that run before C10 to [`docs/workflow.md`](../workflow.md), as "What moves where" (10.6) lists them, and each subsection keeps its heading with a link. What depends on C10 (10.3's board, 10.4 as written, 10.9) stays here and moves in V2-04, only if C10 is approved.

#### 10.1 Where each kind of information lives

One rule decides it: each fact lives in one place, and the other places point to it or summarize it. The table describes the flow after C10; before C10, the state of each task lives in `status.md`, its detail lives in this design's task list, and its acceptance evidence lives in the pull request body ([Interim mode](../workflow.md#interim-mode-before-c10)).

| Information | Lives in | Updated when |
|---|---|---|
| The state of each task (its column, and whether it is blocked) | The GitHub Projects board (proposed) | Every move. A move is not a commit. |
| The detail of each task: expected outcome, acceptance criteria, how to verify, blockers, version | A GitHub Issue (template `.github/ISSUE_TEMPLATE/task.md`) | When the task is defined, taken or blocked |
| A one-minute summary: progress bar, milestone, active task, blockers, next step | `status.md` (repository root) | In the task's pull request and at the end of a session (10.6) |
| The code change and its review | A pull request with `Closes #N`, plus CI | Per task |
| Lasting decisions | `docs/decisions.md` | In the pull request that makes the decision |
| The design | This document, published as `docs/designs/marlix-v0-2.md` | When the design changes |
| Release history | `CHANGELOG.md` and GitHub Releases | At each release |
| Local assistant rules | `CLAUDE.md` (local, ignored by git), without state blocks | When the process changes |
| Records of earlier work | `docs/decisions.md`, `CHANGELOG.md` and closed GitHub issues | When a lasting decision or release is recorded, or an issue closes |

The board is the live truth for the state of a task. `status.md` summarizes the board and never contradicts it: when they differ, the board wins and `status.md` is fixed.

**Documentation layout (author decision, following the structure of the EGM project).** The README stays short and points to the rest. Approved designs live in `docs/designs/`. Operating guides that are in force live in `docs/` (for example `docs/workflow.md`, `docs/development.md`, `docs/backups.md`). Diagrams sit next to the topic they explain. `status.md` holds progress and the next step; `CLAUDE.md` holds only the rules in force. Cleaning up the existing documentation to this layout is reviewed later, as its own task, not in V2-01.

#### 10.2 Rules kept, and rules changed

Kept as they are:

*   The four non-negotiable rules of `CONTRIBUTING.md`, and "no secrets or real user data in the repository".
*   `main` receives changes only through pull requests, and CI must pass (API, App and Database checks).
*   Conventional Commits in English, in the imperative and with no trailing period, one change per commit.
*   No Claude attribution in commits, pull requests or issues.
*   The Definition of Done, and the migration procedure (run the SQL in the Supabase SQL Editor before merging, then `docs/verify-migrations.sql`).
*   English in the repository; Spanish only for in-app copy.
*   Comments only where they explain a reason, a constraint, a safety rule or a link.
*   A didactic summary at the end of each task (what, how, why), given in chat.

Changed, with the reason. "In force from" says whether the change applies once this design is approved, or only at C10.

| # | Today | Proposed | Why | In force from |
|---|---|---|---|---|
| 1 | The issue title begins with the card ID (`S1-5 ...`), from the previous backlog. | The title is a short imperative English sentence. The GitHub issue number is the ID. | The `S#-#` IDs belong to the previous backlog. Two ID systems are two backlogs. | C10 |
| 2 | The issue is created only when the card is taken (`CLAUDE.md`). | The issue is the backlog entry. It is created when the task is defined, for the milestone `v0.2` and for open bugs, and it sits on the board. | After the transition there is no other place to hold the task. To avoid a long list, ideas for later stay as at most five one-line items in `status.md`, not as issues. | C10 |
| 3 | Cards are taken in strict ID order. | The next task is the top of Ready: tasks whose dependencies are all completed and verified, ordered by priority, then by number (10.3). | The launch has a critical path. Strict numeric order would make unblocked work wait. | Design approval |
| 4 | The task template says "A backlog card turned into an issue" and asks for `SX-N`. | The template drops the card ID and gains: **Expected outcome**, **Version**, **Priority**, **Blocker record**, **Launch criterion served**, **Working method** (for UI tasks, section 4) and **Flag** where one applies. | These fields are what the Definition of Ready and `status.md` need. | C10 |
| 5 | The sprint security audit closes each sprint. | The same audit closes each milestone. | Milestones replace sprints as the unit. | Design approval |
| 6 | Nothing requires a flag. | A risky change, or a feature that must be on for some people only, ships behind a flag. | `main` deploys to production on its own. | Design approval |
| 7 | The Definition of Done does not mention cost or the summary. | Added: if the change adds or alters a model call, it is recorded in the spend ledger and the budget table is updated. Added: `status.md` is updated. | The USD 10 cap and the entry point depend on them. | Design approval (the template text changes at C10) |
| 8 | `CLAUDE.md` keeps long "session state" blocks. | `CLAUDE.md` keeps only rules and points to `status.md` for state. | The state blocks duplicate what `status.md` will hold and grow without limit. | Design approval, for v0.2 work (V2-01) |
| 9 | A tool outside the repository was the source of truth for the backlog. | Before C10: `status.md` provides the entry point and the V2-NN list holds the v0.2 backlog. Existing GitHub issues keep their own discussion. After C10: GitHub Issues and Projects track the backlog, and `status.md` remains the entry point. | One place for each fact, with links to related work. | Design approval (interim), C10 (final) |
| 10 | One card in progress at a time. | One main task is active at a time. A second task may stay paused in In Progress only while it is blocked (10.3). | A blocked task would otherwise stop all work. | Design approval |
| 11 | Each task has its own `<type>/<short-description>` branch, and the owner runs every commit, push and merge. | `wil` is the only shared working branch; pull requests go from `wil` to `main`, one at a time. Within a run the owner authorizes, the assistant commits, pushes, opens the pull request, fixes CI and, if authorized, merges ([Branches](../workflow.md#branches-main-and-wil), [Autonomous runs](../workflow.md#agent-assisted-work)). | Work no longer stops while the owner is away; `main` keeps its protections. | Owner decision, 2026-11-21 |
| 12 | No sprint cadence. | A weekly sprint: the owner picks a verifiable Sprint Goal and approves its items, a daily async check-in, and a weekly review and retrospective ([Planning and reviews](../workflow.md#planning-and-reviews)). | Plans and reviews against a goal; the board alone tracks state, not purpose. | Owner decision, 2026-11-21 |

#### 10.3 The Kanban board

Before C10: [Definition of Ready](../workflow.md#definition-of-ready), [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching) and [Post-merge checks](../workflow.md#post-merge-checks) in `docs/workflow.md`. The board below comes into force at C10.

**Columns and what must be true to move between them.** The columns are the starting point and can change after the first two weeks of use.

| Column | The task is here when | It moves on when |
|---|---|---|
| **Backlog** | The issue exists in the milestone `v0.2` (or is an open bug) but is not ready: criteria are missing, or a dependency is open. | It meets the Definition of Ready. |
| **Ready** | It meets the [Definition of Ready](../workflow.md#definition-of-ready). Hard dependencies filter the column: an item whose "Blocked by" is not completed and verified is not Ready. Within Ready the order is priority, then the lowest issue number. | It is the top item, no other main task is active, the issue is assigned, its branch exists, and the owner agrees. |
| **In Progress** | It is the main task being worked on, or the one paused task that is blocked. | Every acceptance criterion is ticked with evidence, the local checks are green, and the pull request from `wil` to `main` is open with `Closes #N`. |
| **In Review** | The pull request from `wil` is open, carries the evidence and shows the CI state of its last pushed commit. | CI is green and the owner merges, or the assistant merges when the run authorizes it. If CI fails or the owner asks for changes, the task goes back to In Progress. |
| **Done** | The pull request is merged, the issue is closed as completed, and the post-merge checks passed: CI of `main` is green, `GET /health` answers `ok` after a backend deploy, and `docs/verify-migrations.sql` returns only `ok` after a migration. | If a post-merge check fails, the issue is reopened and moves back to In Progress. It stops counting as done ([Post-merge checks](../workflow.md#post-merge-checks)). |

**Labels and milestone.**

*   Kept: `backend`, `app`, `data`, `design`, `docs`, `infra`, `security`, `accessibility`, `bug`, `blocker`, `help-resources`.
*   New: `P0` (blocks the launch or the critical path), `P1` (needed for v0.2), `P2` (useful if there is time), `blocked`, `launch` (serves a launch criterion), `sala` (a Sala-beta task; counted on its own line, not in the launch bar), and `experiment` (behind a flag with an exit criterion; not counted in any bar).
*   There is no `in-progress` label and no `later` label: the board column holds the state of a task, and ideas for later stay in `status.md`.
*   Milestone: `v0.2`. Milestones for later versions are created when they are needed.
*   Dependencies: a "Blocked by #N" line in the issue body. If the account supports GitHub's native "blocked by" relationship, that is used too (to verify).

**Board mechanics (all to verify when the board is created).**

*   The board is a GitHub Project owned by the author, private by default. A private board does not change the visibility of the repository's issues: they stay public, so an issue carries only a title, criteria and evidence that are safe to share ([Visibility after C10](../workflow.md#moving-to-github-issues-and-projects-c10)).
*   Built-in project workflows move items automatically in some cases (for example, an item whose issue is closed or whose pull request is merged moves to Done). Which workflows exist must be checked in the project settings. Where one is missing, the move is manual.
*   The assistant moves cards with `gh project item-edit`. That needs the `project` scope on the GitHub CLI token, which the owner grants once with `gh auth refresh -s project`.

#### 10.4 The life of a task

Before C10: [The cycle before C10](../workflow.md#the-cycle-before-c10) in `docs/workflow.md`.

**A** is the assistant and **O** is the owner. This is the flow after C10.

1.  **Start the session (A).** Read the private board, look at the GitHub Projects board, run `git status` and `git log -5`, and check the CI of `main`. If they disagree, the board wins for the state of a task, and `status.md` is fixed. Before C10 there is no board: `status.md` is compared with `git log` and the merged pull requests.
2.  **Choose (A, O agrees).** Take the top of Ready. If a task is already active or paused, apply [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching). If Ready is empty, the next step is to bring the top Backlog item to Ready.
3.  **Take it (A).** Move the card to In Progress, assign the issue and re-read its criteria against reality. If the scope has to change, tell the owner before changing the issue and propose the update. Anything outside the scope becomes a new issue.
4.  **Prepare `wil` (A).** `wil` matches `origin/main` with no pending commits ([Preparing `wil` after a merge](../workflow.md#preparing-wil-after-a-merge)).
5.  **Work (A).** Small commits. For a database change, follow the migration procedure. For an endpoint change, update `docs/api-contract.md` in the same pull request. For a lasting decision, add it to `docs/decisions.md`. Put a risky change behind a flag. If the task blocks, apply [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching).
6.  **Verify (A).** Run `npm run typecheck`, `npm test` and `npm run build` in `api/`, and `flutter analyze` and `flutter test` in `app/`. Tick each acceptance criterion in the issue and write the evidence beside it: the test name, the command or a screenshot. Check screens on the emulator, and on the Galaxy S24 when a criterion says so (confirm with the owner that the phone is available). Re-read every comment and remove those that restate the code.
7.  **Prepare the summary (A).** Edit `status.md` as it should read once the pull request is merged: this task counted as done, the new progress bar, the next task as active, the new next step ([`status.md`](../workflow.md#statusmd)).
8.  **Commit and push (A, within the run authorization).** Check the staged diff and the attribution rule, commit in Conventional Commits and `git push origin wil`. Give the owner the didactic summary.
9.  **Open the pull request (A).** `gh pr create --base main --head wil` with the template's sections (Work Item & Sprint Goal, Why, What Changed, Acceptance Criteria, Verification, Risks & Follow-ups) and `Closes #N`.
10. **Watch CI (A).** `gh pr checks <n> --watch`. If a check fails because of the change, fix it on `wil` with a new commit and keep the card in In Progress.
11. **In Review (A).** When the pull request goes from `wil` to `main`, the diff matches the scope, every ticked criterion has evidence and the CI state of the last commit is known, move the card to In Review. The CodeQL job stays non-required until it has run stably on several pull requests (S8-1).
12. **Merge (O, or A when the run authorizes it).** Squash merge with the title `type: summary (#PR)`. `Closes #N` closes the issue.
13. **Close out (A).** Sync `main`, prepare `wil` for the next item, check the [post-merge checks](../workflow.md#post-merge-checks) (CI of `main`, `GET /health` after a backend deploy, `docs/verify-migrations.sql` after a migration), and confirm the card is in Done. If the progress bar in `status.md` differs from the real count, fix it in the next pull request. Then go back to step 2.

#### 10.5 A clear task, with a worked example

The fields every task answers are in [A clear task](../workflow.md#a-clear-task) in `docs/workflow.md`. The example below shows the flow after C10.

**Worked example.** The issue and pull request numbers and the dates are illustrative; the issues do not exist yet.

```markdown
Title: Make the avatar react to device orientation
Labels: app, P1, launch
Milestone: v0.2

## Expected outcome
When the person tilts the phone, the avatar sways and its ears and tail follow
a moment later. When they turn the phone upside down, the avatar falls toward
the lower edge of the screen. When they turn it upright again, it recovers.
This is what makes Marlix feel alive (goal G3). With reduced motion on, the
avatar never falls and only eases between poses.

## Acceptance criteria
- [ ] 1. Tilting the phone up to 45 degrees sways the avatar; ears and tail follow with a short delay.
- [ ] 2. After gravity stays reversed on the vertical axis for 300 ms, the avatar falls toward the lower edge and settles.
- [ ] 3. After the phone has been upright again for 300 ms, the avatar recovers its pose within 1 second.
- [ ] 4. With reduced motion on (the app's setting or the system's), none of these animations run; the pose changes with a 150 ms ease.
- [ ] 5. If the device has no accelerometer, or the sensor stream fails, the avatar behaves as in v0.1 and no error is shown.
- [ ] 6. The sensor subscription is cancelled when the screen with the avatar is not visible.
- [ ] 7. In profile mode, no frame takes longer than 16 ms during a 30-second tilt session, on the Galaxy S24 and on the low-end AVD (docs/development.md).

## How to verify
1. `flutter analyze` and `flutter test` in app/ (new tests for the physics, with a fake sensor stream).
2. Emulator, Extended controls, Virtual sensors: tilt, invert and straighten the device.
3. Galaxy S24 (confirm with the owner that the phone is available): run in profile mode and record the frame times in DevTools.
4. Turn reduced motion on in the app and in the system settings, and repeat.

## Blocked by
#232 Add the reduced-motion setting (Done).

## Version, priority and launch criterion
v0.2 · P1 · serves launch criterion 6 (launch features done).

## Out of scope
The 3D avatar. The Sala. Haptic feedback.

## Technical details
New: app/lib/widgets/avatar_physics.dart (spring model and thresholds);
app/test/widgets/avatar_physics_test.dart. Modified: app/pubspec.yaml (adds
sensors_plus), app/lib/widgets/avatar_marlix.dart, docs/avatar.md,
docs/decisions.md (the thresholds and why).
```

**From Ready to Done:**

| Date | Column | What happens | Who |
|---|---|---|---|
| 2026-12-04 | Backlog → Ready | The Definition of Ready is checked: outcome, seven criteria, verification steps, the dependency #232 is Done, P1, milestone `v0.2`, about two sessions. | A proposes, O agrees |
| 2026-12-07 | Ready → In Progress | #230 is the top of Ready: no `P0` item is unblocked, because #227 is blocked by a provider check. The issue is assigned and `wil` is realigned to `main`. | A |
| 2026-12-07 | In Progress | Tests first, with a fake sensor stream. Then the physics, then the widget. Commits: `test: cover avatar tilt, fall and recovery`, `feat: add spring physics for the avatar`, `feat: make the avatar react to device orientation`, `docs: record the avatar motion thresholds`. | A |
| 2026-12-08 | In Progress | Criteria 1 to 6 are ticked with the test names. For criterion 7 the owner connects the Galaxy S24; the assistant records the frame times and ticks it with the numbers. | A, O |
| 2026-12-08 | In Progress | `status.md` is edited as if the pull request were merged: 9 of 28 tasks, the next task active, a new next step. Within the run authorization, the assistant commits and runs `git push origin wil`. | A |
| 2026-12-08 | In Progress → In Review | `gh pr create --base main --head wil` opens PR #233 with `Closes #230`. | A |
| 2026-12-08 | In Review | The API, App, Database and CodeQL checks run. All pass. | A |
| 2026-12-09 | In Review → Done | The owner squash-merges with the title `feat: make the avatar react to device orientation (#233)`. The issue closes by itself. The card moves to Done. | O |
| 2026-12-09 | Done | The assistant syncs `main`, prepares `wil` for the next item, sees the CI of `main` green, and confirms that the bar in `status.md` matches the real count (9 of 28). | A |

**Pull request body for the example:**

```markdown
Closes #230

## Work Item & Sprint Goal
#230 · serves the Sprint Goal "the avatar feels alive on a real phone" · 3 points

## Why
The avatar ignored the phone's movement; goal G3 needs it to feel alive.

## What Changed
- Spring physics for tilt, fall and recovery; reduced motion eases between poses.
- No accelerometer: the avatar behaves as in v0.1. Out of scope: the 3D avatar.

## Acceptance Criteria
- [x] 1-6. Tilt, fall, recovery, reduced motion, no sensor, cancelled subscription: `avatar_physics_test.dart`
- [x] 7. No frame over 16 ms in 30 s on the Galaxy S24 and the low-end AVD (numbers in the issue)

## Verification
- `flutter analyze` and `flutter test` in app/: pass
- Emulator, Virtual sensors: tilt, invert, straighten
- CI on the last commit: API, App, Database and CodeQL passed

## Risks & Follow-ups
No model call changed. Post-merge: CI of `main` green.
```

**Variation: the task blocks half way.** If on 2026-12-08 the owner could not lend the Galaxy S24 until the evening, criterion 7 could not be checked. The assistant would write this in the issue and add the `blocked` label:

```markdown
## Blocker
Cause: criterion 7 needs the Galaxy S24 and the owner has it away until the evening.
Depends on: the owner connecting the phone.
Action to unblock: connect the Galaxy S24 by USB, enable debugging and tell the assistant.
Who acts: owner.
Recorded on: 2026-12-08
```

Because the blocker will not clear in the current session and the work for #231 touches other files, the assistant may take #231 as the main task (rules 1 to 6 of [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching)). #230 stays paused in In Progress. When the phone is connected, #230 is picked up before the next Ready item of equal or lower priority.

#### 10.6 `status.md`: the public summary

Before C10: [`status.md`](../workflow.md#statusmd) in `docs/workflow.md` holds the rules, the interim mode, the event table, the progress bars, "Automation" and the interim template. What stays here is the record of the move and what waits for C10.

**What moves where.** V2-01 copies into `docs/workflow.md` the rules in force before C10, under these headings:

*   **The cycle before C10:** the "Cycle before C10". Its references to steps of 10.4 become links to section 10.4 of `docs/designs/marlix-v0-2.md`.
*   **Definition of Ready:** 10.3's Definition of Ready, verbatim.
*   **Blocked tasks and switching:** from 10.3, "One main task at a time"; "When a task is blocked", from its first sentence to the clearing sentence, with the blocker record verbatim; "When it is right to take another task", with its five conditions and the two paragraphs after them; and "A pull request waiting for review".
*   **Post-merge checks:** the post-merge checks of 10.3's Done row.
*   **A clear task:** 10.5's fields. The worked example stays in this design, and this heading links to it.
*   **`status.md`:** from 10.6, the rules, the interim mode, "The update is written as if the pull request were merged", "Publishing with a protected `main`", the progress bars, "Automation", the interim template and the event table with three columns (Event, Interim before C10, `status.md`). In the interim template, "the template above" becomes a link to the 10.6 template in this design.
*   **References in all copied text:** "this design" and "the Detailed Implementation Plan" become links to `docs/designs/marlix-v0-2.md`; a reference to moved text (10.3's Definition of Ready, blocker record, switching rules and post-merge checks; the 10.6 rules and table) becomes a link to the matching `docs/workflow.md` heading; any other section reference (10.3's columns, 10.4, 10.9, section 4, the Work order) becomes a link to that section of the design; "above" and "below" are replaced by the link.

The [workflow](../workflow.md#statusmd) defines how the summary shows readiness, active work, reviews, and blockers. This design defines the task priorities and dependencies.

These stay in this design until V2-04 moves them: 10.3's columns, labels and board mechanics; 10.4 as written (with the board); 10.6's template after C10; the board and issue columns of the event table; and 10.9.

**Which event changes what (after C10).** The interim and `status.md` columns are in [Which event changes what](../workflow.md#which-event-changes-what).

| Event | Board (after C10) | Issue (after C10) |
|---|---|---|
| A task is defined | A card in Backlog | The issue is created |
| A task becomes Ready | Moves to Ready | Definition of Ready checked |
| A task is taken | Moves to In Progress | Assigned |
| A task blocks | `blocked` label | `## Blocker` section |
| The pull request opens | Moves to In Review | `Closes #N` |
| The pull request merges | Moves to Done | Closes |
| The owner decides something | Nothing | A comment |
| A session ends | Nothing | Optional comment |

**Template with a complete example (after C10).** The numbers are illustrative until the issues exist. `status.md` is the public summary; blockers, the launch checklist, owner decisions and the run queue live in the maintainer's private board ([workflow](../workflow.md#statusmd)).

```markdown
# Marlix v0.2

**Release progress** `[██░░░░░░░░]` **28%** · 8 of 28 launch tasks verified

**Requirements for release** 2 of 11 met · **Sala beta** 2 of 6 tasks verified

Scope: 28 tasks; approved on 2026-12-01 at 27. Changes: +#240 greeting by local
time (2026-12-05), -#237 voice comparison (moved to experiments, 2026-12-06),
+#241 reminder migration test matrix (2026-12-07).

## Milestones

| Milestone | Status | Done when |
| --- | --- | --- |
| Build the technical foundations (M1) | In progress | Launch criteria 3, 4, 5, and 11 pass in staging, and criterion 11 passes in production. |

## In Progress

**Make the avatar react to device orientation (#230).** Criteria 1 to 6 pass;
the frame-time check on a real phone (criterion 7) is next.

## In Review

No open pull requests.

## Ready

1. Add the palette, pattern, and accessory picker (#231).
2. Add the «Recordá esto» button and notice (#234).
3. Add the greeting by local time (#240).

Updated: 2026-12-08 · [Design](docs/designs/marlix-v0-2.md) · [Workflow](docs/workflow.md)
```

#### 10.7 Release

*   A release is a version bump in `app/pubspec.yaml` (the `versionCode` always grows), an entry in `CHANGELOG.md`, a git tag, and the artifacts: the signed APK on GitHub Releases and the production AAB for Play, both signed with the S7-15 key (the signed release APK card). While the Sala beta runs, the same commit also produces the Sala AAB for the internal track, with a higher versionCode ("Effect on the launch").
*   The first Play publication goes to production once the launch criteria are met. Later updates roll out at 10%, 50% and 100% and can be paused.
*   Going back means switching a flag off or publishing a corrected version; Play does not allow a lower version.

#### 10.8 Closing a milestone

At the end of each milestone: the security audit already used at sprint close (secrets in the history, ignored files, RLS and grants, endpoints, dependencies, repository protections), plus the new surfaces of v0.2 (the spend ledger, the Sala tables including `room_help_requests` and, when it exists, `room_bans`, the flags tables, and the crisis asset in the app). Each finding becomes an issue in the next milestone.

#### 10.9 Adopting GitHub Issues and Projects (C10)

**The author approves C10 before starting steps T1 through T8.** Until then, `status.md` and the V2-NN list remain in use under the [interim workflow](../workflow.md#interim-mode-before-c10). Existing GitHub issues and pull requests remain available for their current work.

| Step | What happens | Who |
|---|---|---|
| T0. Decision | The author approves this plan. | Owner |
| T1. Baseline | Confirm the current V2-NN list, scope and completed tasks from the private board, `status.md` and the design. | Owner |
| T2. Inventory | Map each V2-NN task to an existing GitHub issue or mark it for issue creation. Record the reason for excluding any out-of-scope item. | Assistant prepares, owner decides |
| T3. Map | Prepare the issue text in English with the fields of 10.5: expected outcome, criteria, how to verify, dependencies, version, priority and labels. The map stays outside the repository until the issues exist. | Assistant |
| T4. Create the board | Create the GitHub Project (private), with the columns Backlog, Ready, In Progress, In Review and Done. Check which built-in workflows exist. The owner grants the CLI the `project` scope with `gh auth refresh -s project`. Create the labels `P0`, `P1`, `P2`, `blocked`, `launch`, `sala` and `experiment`. | Owner grants access, assistant sets up |
| T5. Set up the issues | Reuse matching issues and create the remaining issues in batches of at most ten, each batch approved by the owner. Add the `V2-NN` ID to each issue. Items that meet the Definition of Ready go to Ready; the rest go to Backlog. Record tasks completed under the interim bar as issues closed as completed, so the total and done count carry over. | Assistant, owner approves each batch |
| T6. Verify completeness | (a) *Count:* each in-scope V2-NN task maps to one issue in the milestone `v0.2`. (b) *Metadata:* every issue has a priority and the milestone, and the owner checks each `P0` issue against its design entry. (c) *Bars:* the totals equal the interim totals plus the scope changes recorded since, and the done counts equal the interim counts. | Assistant, owner signs off |
| T7. Pilot | Run one real task through the cycle in 10.4, including the board moves and the `status.md` edit. If any step is awkward, fix the process before continuing. | Both |
| T8. Switch | Keep the private board as the session entry point and `status.md` as the public summary, with no link to the private board. Update `CLAUDE.md` after the pilot, and update the issue template, pull request template, `CONTRIBUTING.md` and `docs/workflow.md` in a pull request. | Assistant proposes, owner approves |

*   **Rollback:** If T6 or T7 fails, keep the interim workflow until the gap is fixed.

--------------------------------------------------------------------------------

## Alternatives Considered

The alternatives weighed for product scope, models, hosting, email, the avatar, the Sala and the process are recorded with their reasons in the maintainer's private notes. Lasting technical choices that the code depends on are recorded in [`docs/decisions.md`](../decisions.md).

## Future Improvements

*   **Server-side avatar look.** In v0.2 the palette, pattern and accessories are saved on the phone and survive closing and reopening the app (V2-19). Syncing them with the account, and restoring them after a reinstall or on another phone, are future improvements.
*   **Supabase Realtime for the Sala**, if polling stops being enough when the Sala opens.
*   **Private one-to-one chats** in the Sala, designed on their own, with both people accepting before the conversation opens.
*   **Voice between people** in the Sala, if the text channel shows value.
*   **More than one channel** or channels by topic.
*   **Age verification** stronger than the self-declared birth date (Q17).
*   **Automatic reconciliation** with the provider if it offers a per-request usage record or an API.
*   **A helper that prints the progress bars** and a **CI check on `status.md`** ([Automation](../workflow.md#automation-when-it-would-add-value)), when the thresholds there are reached.
*   **A 3D avatar** from a captured object and a **reusable 3D scene** from a room, if their feasibility tests pass.
*   **Another chat model with real data**, only if its terms offer zero data retention or a data processing agreement.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

The work is split into tasks named `V2-NN`. Before C10 this list is the v0.2 backlog and `status.md` summarizes its state ([Interim mode](../workflow.md#interim-mode-before-c10)); at C10 each task becomes an issue. The full acceptance criteria of each task live in the maintainer's private notes until the task becomes a public issue; each pull request states the criteria it closes and their evidence.

**Conventions that apply to every task** (not repeated in each one):

*   **Migrations** follow `CONTRIBUTING.md`: a file `docs/migrations/YYYY-MM-DD-<what-it-does>.sql` that runs once in a transaction, mirrored in `docs/schema.sql`, with its checks added to `docs/verify-migrations.sql` in the same pull request. A privilege or RLS change also adds cases to `docs/schema-test.sql` and updates `docs/erd.md`. The owner runs the migration in the Supabase SQL Editor before the merge, then runs `docs/verify-migrations.sql` (every row must say `ok`).
*   **Endpoints** update `docs/api-contract.md` in the same pull request, and extend `api/test/legacy-clients.test.ts` (V2-07) when a response a v0.1 client reads changes.
*   **Lasting decisions** are added to `docs/decisions.md` in the pull request that makes them.
*   **`CHANGELOG.md`** is updated at release (V2-31) and when a milestone closes, not in each task.
*   **Tests** for the backend are `api/test/*.test.ts` (run by `tsx --test`); tests for the app are under `app/test/`.
*   **UI tasks** listed in section 4 ("UI and UX method") attach the `ui-ux-pro-max` deliverables to their pull request.
*   **Every task** ends with the Definition of Done of `.github/pull_request_template.md` and an updated `status.md` ([`status.md`](../workflow.md#statusmd)).
*   **Roles:** the owner (the author of this design) and the assistant, as defined in the Overview. The plan uses "owner" throughout.
*   **Low-end AVD:** the profile in G3, written into `docs/development.md` by V2-05a; a task that measures on it before V2-05a merges uses the profile in G3.
*   **Not applicable:** a task closed as not applicable is removed from the launch count and counts as met for its dependents ([Interim mode](../workflow.md#interim-mode-before-c10)).
*   **Worked examples:** a task may reference the numbered criteria of a worked example instead of repeating them (V2-17).

### Work order

The **List** column classifies every task once: **Launch** (blocks the v0.2 launch and counts in the launch bar), **Sala** (blocks only the Sala beta and counts in its own line), **Experiment** (counts in neither), and **Process**.

| Order | ID | Task | List | Milestone | Priority | Depends on |
|---|---|---|---|---|---|---|
| 1 | V2-01 | Create `status.md` and `docs/workflow.md` | Launch | M0 | P0 | The owner's final approval (recorded as `Status: Approved`) |
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
