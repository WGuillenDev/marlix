# Marlix v0.2: a customizable care companion

*   **Author:** WGuillenDev
*   **Status:** Approved (2026-11-20)
*   **Date:** 2026-11-19 (review corrections applied on 2026-11-20)
*   **Main source:** the author's local brainstorm brief (in Spanish, not in the repository), closed on 2026-11-19, plus the decisions the author made afterwards about the «Sala de Marlix», the first Google Play release, the order of the email work and the closed test, how reports are handled, and where the avatar look is saved. Those decisions replace what the brief said on those points; the table in the Overview lists each one, so this document does not need the brief to be read.
*   **Language:** this file is in English because everything in the repository is in English (`CONTRIBUTING.md`, "Language and naming"). Only in-app copy is in Spanish, and it appears here in guillemets or code, for example «Sala de Marlix» and «Recordá esto».

--------------------------------------------------------------------------------

## Overview

Marlix is an Android app (Flutter) for conversational companionship, for adults aged 18 or older. It has a 2D beagle avatar, text and voice chat, a memory of what the person shares, and a crisis protocol. The backend (`api/`, Node 24, Express 5) is the only component that talks to the language model and to the database (Supabase). Version 0.1 is distributed as an APK on GitHub Releases. The Google Play listing is prepared, but the app is not published.

This design defines v0.2: what gets built, what gets tested before it is included, the budget that sustains it, and the process one person uses to develop, publish and maintain it. About 50 people are waiting for the launch. That number is an estimate, not a count of confirmed testers or of simultaneous connections.

**Promise of v0.2.** After one week, a person can say: «I made my Marlix mine, it feels alive, and I can talk to it when I need company. I also have a place to practice how to talk with other people.» The second sentence depends on the «Sala de Marlix». While the Sala is switched off, that half of the promise is not met and is not advertised.

**The Sala de Marlix.** This is a shared text chat channel, inspired by a Discord text channel. Every enabled user joins the same channel, reads, and talks freely in real time. The goal is to let people practice social skills by talking to each other: starting a conversation, asking questions, meeting people and taking part at their own pace. Suggested topics help break the ice and are optional. The conversation is text only, and each person shows their customized avatar in their profile. Private one-to-one chats are left for a later update.

The Sala is validated first in a **private beta by invitation, with a confirmed host**. The goal is to open the same channel to enabled users once the beta confirms that it can be moderated well (see "Sala de Marlix: scope").

**Opening the Sala to the public does not block the v0.2 launch** (see "Effect on the launch").

**Constraints that are not negotiable:**

*   Cash spending of at most USD 10 in every calendar month in which the card is charged, for the whole operation (hosting, models, voice, storage, email, domain and paid tests), including the month a domain is charged and every month with a paid test. There is no annual cap and no exception month, and nothing depends on revenue from users.
*   One person develops and operates everything. In this document that person is **the author** (also called **the owner** when the text is about operating the service). **The assistant** is an AI coding assistant that works under the rules in the local `CLAUDE.md`; it never commits, pushes or merges.
*   The crisis protocol and the help lines do not depend on any spending cap.
*   No diagnosis and no treatment. The person tells Marlix how they feel by voice or text; the camera is only used for the avatar and the environment, never to infer symptoms.
*   Real user data does not go to providers that lack zero data retention (ZDR) or an updated privacy policy.
*   The Sala is text only and is separate from the private chat with Marlix and from its memory.
*   The Sala is not opened to everyone while the coexistence and moderation controls are missing.
*   The rules in `CONTRIBUTING.md` stay in force, except those this design changes explicitly in the section "Marlix v0.2 development flow".

*   Terms for help used in this document: the **help lines** are the 9-1-1 and Línea Aquí Estoy phone lines; the **help button** opens the help screen with those lines; the **help response** is the crisis reply text (`api/config/crisis.json`) together with the help lines.
*   Identifiers used in this document: **D#** is a decision numbered in the author's brief; **S#-#** is a card of the old Notion backlog, whose decisions are recorded in `docs/decisions.md` (for example S7-15, the signed release APK); **C#** and **Q#** are the Open Questions below; **V2-NN** is a task of the Detailed Implementation Plan.

### What the author's decisions replace from the brief

| The brief said | Now |
|---|---|
| D12: social practice in the first version is a **guided practice with Marlix characters** (AI) on top of the existing chat. | No AI characters for this module. Practice means talking to other people in the Sala. |
| D12: a **private room** for 4 to 6 adults, by invitation, with 45-minute sessions hosted by someone, as the `social_rooms` experiment. | A **single shared channel** for all enabled users, with no 4-to-6 limit and no scheduled sessions as the way of use. It starts as a beta by invitation with a host. |
| Alternatives: **open rooms** were rejected because moderation was not realistic. | Opening to everyone is the goal, conditional on having the controls and the moderation coverage. The reason for the rejection becomes the criterion for opening. |
| Launch criterion 6 included the "guided practice". | The Sala is not a launch criterion. The criterion becomes: if the Sala is on for anyone, it meets the conditions to start the beta; if it does not, it is off. |
| D1: the Play closed test starts now with the current AAB, and the launch rolls out at 10%, 50% and 100%. | The account type is verified first (C1). The closed test is run only if it applies to the account. The first publication goes to production when the criteria are met, and 10%, 50% and 100% are kept for later updates. |
| Flag `social_rooms`. | The Sala flag (named in the technical plan as `social_room`). |
| D13: own-domain email is accepted before the closed test (the brief's own sequence also starts the test first). | The closed test starts first, after a check in staging that the current email setup works for the first testers (V2-34). The own-domain sender must be verified before the public release of v0.2. |
| D12: with 2 reports a message is hidden for the whole room. | Each report hides the message only for the person who reported it and sends it to moderation. Two independent reports raise the case's priority. Only an authorized moderator removes a message for everyone, so two users cannot remove a message by agreeing. |
| D7: a palette, pattern and accessory picker; where the choices are stored is not stated. | The choices are saved on the phone and are still there after the app is closed and opened again. Syncing them with the account and restoring them after a reinstall are future improvements. |
| The domain cost is prorated over 12 months. | Cash is counted per calendar month, with no annual cap. The domain is a `.fyi` (USD 5.88 with VAT at purchase and at renewal) because a `.com` breaks the cap in the month it is paid (section 5). |
| Groq's free plan is rejected for chat. | Chat may run on Groq Free during the closed test if its limits are enough (checked in V2-34). Groq moves to the paid plan only after the spend governor is in production and ZDR is verified (V2-35). |

## The Problem

There are four problems: one about the product, two about operating it, and one about the process.

1.  **v0.1 does not deliver the promise.** The avatar only reacts to the conversation, it cannot be customized, it does not respond to the phone, and there is no place where people practice talking to each other. A memory takes up to 30 minutes to appear, and the person cannot see when Marlix remembers something. The "greeting" is a notification at an hour chosen in Settings; opening the app does not greet.
2.  **The launch may have a critical path that has not started.** For personal accounts created after November 2023, Google Play requires a closed test with 12 testers for 14 consecutive days before production. We do not know whether that rule applies to the owner's account, and the test has not started.
3.  **Nothing in the backend limits the spend on a paid model today.** Groq's free plan may not cover 50 people (its daily capacity for chat is estimated, not measured, and is checked in V2-34). A paid plan does not stop with a 429 error when it reaches a rate limit. Groq offers an organization-wide monthly spend limit, but it has no per-use control and, when reached, blocks every key, including the crisis classifier's. Moving to a paid plan without a persistent spend control in the backend can break the USD 10 cap or switch off safety.
4.  **The process depends on remembering context.** The current flow uses Notion as the backlog and a local `CLAUDE.md` with long state blocks. A person who works a little each day loses time rebuilding where they left off. This design proposes a single entry point (`status.md`) from the first task, and GitHub Issues for tasks once the author approves the move away from Notion (C10).

**The proposed solution**, in one sentence: ship a bounded v0.2 (three-tab redesign, a living 2D avatar with palette customization, phone voices with samples, «Recordá esto», a greeting by local time, and a paid chat model under a spend governor); add the Sala de Marlix validated in a private beta with a host (if it is not ready at release time, v0.2 ships with the Sala off); verify the Play account type and run the closed test if it applies; and keep DeepSeek, the photo-to-skin feature, the medical-urgency layer and 3D as experiments behind flags with exit criteria.

**The highest risk in v0.2 is the Sala.** It is the only feature where one person can harm another, and Marlix's audience includes people who look for company or are going through a bad moment. A real-time channel is moderated after the message has appeared, and one host does not cover every hour. That is why the Sala has a beta with opening criteria and is not launched directly.

## Goals

Each goal can be checked. The full launch criteria are in the section "Launch criteria" of the technical plan.

*   **G1. Publish on Google Play.** First verify the type and date of the account (C1). If Play's rule applies to the account, run the closed test with at least 12 testers for 14 consecutive days before requesting production access. The first version is published to production when the launch criteria are met. Staged rollouts at 10%, 50% and 100% are kept for later updates.
*   **G2. Stay within the budget.** Cash spending of at most USD 10 in every calendar month in which the card is charged, including the month the domain is charged and every month with a paid test (section 6). There is no annual cap and no exception month. A persistent spend governor with sub-caps per use enforces it.
*   **G3. A living avatar.** New expressions when listening, thinking, speaking and reacting; a wobble when the phone is tilted, a fall when it is turned upside down and a recovery when it is righted; reduced motion. 60 fps on the Galaxy S24 and on the low-end AVD (defined in `docs/development.md`: an Android Virtual Device with API 31, 2 GB of RAM, 2 cores and the software GPU, SwiftShader), and 4 out of 5 testers who answer yes to «¿Sentís que Marlix está vivo?».
*   **G4. Customization.** A palette, pattern and SVG accessory picker, with no photo upload. The choices are saved on the phone and are still there after the app is closed and opened again. This goal is the one place that defines where the look is saved; the Sala profile publishes a copy of the choice IDs only (section 3.6).
*   **G5. Companionship by voice, with control.** Ten voices with samples, the system voice as a fallback, a microphone permission requested in context, and an app that stays usable with text if the permission is denied.
*   **G6. Fast, visible memories.** «Recordá esto» with the notice «Marlix recordó: … · Deshacer»; automatic extraction when a conversation ends after 10 minutes without messages; viewing, editing and deleting are kept.
*   **G7. Greeting and reminder.** A greeting by local time when the app opens; a fixed reminder at 19:00 with no time picker; a one-time migration for people who had chosen another time.
*   **G8. Safety that does not depend on one provider.** The crisis filter answers from local patterns even when any provider fails or the backend cannot be reached (the phone keeps a copy of the patterns), and the classifier has a quota isolated from memory extraction.
*   **G9. Sala de Marlix.** A shared text channel where enabled users talk freely to practice social skills, with optional suggested topics and the customized avatar in the profile. Its scope is defined in the section "Sala de Marlix: scope".
*   **G10. Coexistence and moderation.** In the Sala, any person can block another and report messages or profiles; authorized moderators can remove content, mute or expel according to the rules. The system distinguishes an infraction (harassment, threats, explicit sexual content) from a person who expresses distress or asks for help, and never penalizes the second. The identity of the person who reports is protected.
*   **G11. Separation and privacy of the Sala.** Sala messages do not enter the private chat with Marlix or its memory. The profile shows the avatar without exposing photos or captures. Deleting the account deletes the person's messages in the Sala.
*   **G12. A workflow that resumes in one minute.** `status.md` at the repository root as the entry point of every session from V2-01, a progress bar that counts finished launch tasks and a separate line for the Sala beta, a documented task cycle from start to finish, and, after C10, GitHub Issues for the detail of each task and a Kanban board on GitHub Projects for its state.

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

### Effect on the launch (author decision, resolves Q14)

This is the single place that defines how the Sala relates to the launch and how it is distributed.

*   Opening the Sala to the public **does not block** the v0.2 launch, and no launch task depends on a Sala task (Work order).
*   **Distribution (default while Q18 is open):** the production build leaves the Sala out at compile time (`--dart-define=SALA_ENABLED=false`), so it contains no Sala screen or route. The beta runs on a Play **internal testing track** (up to 100 testers) with a build that includes the Sala. Google Play says internal testing "might not be subject to standard Play policy" reviews, which is not a clear exemption, so the internal build still ships reporting, blocking and the terms. Opening to everyone is a later production update that includes the Sala, with the user-generated content declaration.
*   **Which build goes where.** The app reads the flag as `const bool.fromEnvironment('SALA_ENABLED')`, so the compiler drops the Sala code from a build where it is false. Each release produces two AABs from the same commit: the production AAB (`SALA_ENABLED=false`) and the Sala AAB (`SALA_ENABLED=true`), which always has the higher versionCode so that beta testers keep the Sala. The **internal track** carries only the Sala AAB. Release candidates go to the **closed track**. The install check of the exact production AAB uses Play's **internal app sharing**, which installs a given build without a track. The "Sala track delivery test" (section 5) verifies the delivery before the beta starts; the "Production build check" verifies the production AAB at each release.
*   If Q18 shows that Play accepts the Sala code in the production build behind the server flag, the author may change this default; the change is recorded in `docs/decisions.md`.
*   At release time, if all the conditions to start the beta (A to F, below) are met, the Sala is tested by invitation on the internal track. If any is missing, the beta waits, and production is unaffected.
*   While the Sala is not open, the production app shows no access to it, and the Play listing, the privacy policy and the website do not advertise it as available. In the internal build, a missing flag or a failed call to the backend keeps it off. Verified in the repository: the current listing (`docs/play-store/`) mentions no room or social feature.
*   It opens to enabled users when the beta confirms that it can be moderated well (opening criteria, below).

**Conditions to start the beta** (all of them, before inviting anyone):

*   **A. Confirmed host** with known hours (C8).
*   **B. Blocking and reporting** of messages and profiles work in the app, with automated tests and a manual rehearsal using cases of harassment, threat, explicit sexual content, distress and a mix.
*   **C. Moderation tools** (remove, mute and expel, and the moderator's Reports view of V2-36) and at least one authorized moderator.
*   **D. Private help.** The crisis and distress cases in a test set receive the private help response with the same thresholds as `npm run crisis:eval`, and none ends in a penalty.
*   **E. Privacy verified.** Tests show that Sala messages do not reach the chat with Marlix or its memory; that the profile shows only the nickname and the avatar choices, never a photo; that the reported person cannot tell who reported them or when; and that deleting the account deletes their messages and profile.
*   **F. Rules and Play.** The coexistence rules and terms are accepted before writing; the privacy policy is updated; and it was verified in Play Console and in the Play help pages what the user-generated content policy and the internal testing track require (Q18).

**What the beta must show to open the Sala to everyone.** Conditions A to F stay in force. The numbers are a starting proposal and are adjusted with the host before the beta starts:

1.  **Timely moderation.** At least 90% of reports are handled within 24 hours throughout the beta. Proposed minimum duration: 3 weeks, with at least 10 invited people.
2.  **Written coverage.** It is written down in which hours the channel is open and who moderates in each one. Without coverage it does not open (see Q15).
3.  **Value.** Half or more of the invited people return in the second week **and** answer yes to «¿practicaste algo que te cuesta?». If only one of the two holds, it does not open.
4.  **Costs and limits.** The polling load (one request every 3 seconds per open Sala screen, section 3.6) stays within the free plans of Render and Supabase, and the Sala's classifier calls stay within the Sala's own pool (USD 0.15 a month) without borrowing from other pools (section 3.2). Before opening, polling is compared with Supabase Realtime for the expected number of people.
5.  **Ban list and age.** `room_bans` (section 3.6) is in production and disclosed in the privacy policy, and the author has decided what to do about self-declared age (Q17).

## Open Questions

These are the brief's conditions and the new questions about the Sala. While one is open, the part of the design that depends on it is marked. Each item names the task that depends on it and who verifies it (the owner, or the assistant from public pages or the code). Q14 (effect of the Sala on the launch) was resolved by the author; see "Effect on the launch".

**Which list each item blocks:** launch: C1, C2, C3, C5, C6 (only for V2-10, V2-12b and, through item (f), V2-35), C11, Q11, Q12, Q13; Sala beta: C8, Q15, Q16, Q18, Q19; opening the Sala: Q17; experiments or optional work: C4, C7, C9, C12.

*   **C1. Type and state of the Play Console account.** Decides whether the 12-tester, 14-day closed test applies and, with it, when v0.2 can be published. It also decides whether the current AAB (`0.1.2+3`) is accepted on a closed track and counts toward the requirement (target API level, Play App Signing, declarations). If it is not, the test starts with a rebuilt 0.1.x against the same backend. It is the first thing to verify. **Task:** V2-02, then V2-03 and V2-33. **Verified by:** owner.
*   **C2. 13% VAT on foreign services.** Assumed, not confirmed. Verified from the charge of another subscription. It sets `tax_multiplier` (section 6). **Task:** V2-02. **Verified by:** owner.
*   **C3. Domain price at checkout.** The decision is a `.fyi` at Cloudflare (section 5): USD 5.20 before tax at purchase and at renewal, 5.88 with VAT. The figure comes from a third-party mirror of Cloudflare's prices, so the purchase is not authorized until the owner sees the final price with tax at Cloudflare's checkout. If it is above USD 6.50 with tax, the budget table of section 6 is recomputed before buying. At purchase the owner also records the date on which Cloudflare will charge the renewal (its auto-renew lead time), because that date, not the anniversary, decides the cash month of the renewal (section 3.2). The public release needs the own-domain sender, so C3 must be resolved before it. **Task:** V2-06a. **Verified by:** owner.
*   **C4. OVHcloud VPS-1.** Final price from Costa Rica, a US city, whether it can be bought from Costa Rica, and how many hours per week the author can give it. It only matters if the hosting decision is reopened; Render stays the default, and the VPS-1 budget is removed until then. **Task:** none. **Verified by:** owner.
*   **C5. Provider and sender of the current Supabase SMTP.** They are not documented. They must be written down privately before touching email. **Task:** V2-02, then V2-34. **Verified by:** owner.
*   **C6. Groq billing data still unconfirmed.** Narrowed on 2026-11-19, when these were verified on Groq's pages: rate limits apply per organization and are listed per model; a monthly, organization-wide spend limit exists on the paid plan, and when reached every key gets a 400 with code `blocked_api_access`, with 10 to 15 minutes of lag; Whisper bills at least 10 seconds per request; the console shows usage per model; prompt caching gives 50% off cached input tokens on the `gpt-oss` models. **Still open:** (a) whether there is a usage export or a billing API, and by which period; (b) whether 4xx, 429 and aborted streams are billed, and how much; (c) whether streaming responses support `stream_options.include_usage`; (d) whether a second organization has its own billing, spend limit and ZDR switch; (e) whether Groq bills by UTC month. (f) when Groq charges the card for a usage month: in the same month, in arrears at the start of the next month, or when a usage threshold is crossed. Until (f) is known, the design lowers both usage months around each fixed charge (section 3.2), which holds the cap if Groq charges in the same month or in the next one (section 6). If Groq charges part of a usage month in that month and the rest in the next, the cap does not hold and the budget is redesigned first, so (f) gates V2-35. "Export: none; fallback: invoice" is a valid answer to (a). **Blocks:** V2-10 and V2-12b, V2-35 through item (f), and launch criteria 3, 4 and 11 through them; the streams decision of V2-09 (G19 in the review, kept open) waits for (b). **Task:** V2-02, V2-10. **Verified by:** owner, reading Groq's Usage and Billing pages and recording each item as yes, no or not offered.
*   **C7. A health professional to review the medical-urgency layer.** Without that review, the layer does not ship. **Task:** V2-27. **Verified by:** owner.
*   **C8. Confirmed host of the Sala.** It is condition A to start the beta. Who it is and which hours they are available still need confirming. Without a host, the beta waits and the launch does not stop. **Task:** V2-26. **Verified by:** owner.
*   **C9. Custom domains on Render's free plan.** Not verified. If they cannot be used, the Render URL stays. **Task:** V2-06b. **Verified by:** assistant from Render's documentation, then owner in the dashboard.
*   **C10. Transition away from Notion.** A decision that needs the author's approval. The proposal is in section 10.9. Nothing is created before the author approves. Until then the interim mode applies ([Interim mode](../workflow.md#interim-mode-before-c10)). **Blocks:** V2-04 and everything that assumes a board or issues. **Task:** V2-04. **Verified by:** owner.
*   **C11. The UptimeRobot monitor on `/health`.** `docs/monitoring.md` and S7-6 (the monitoring card) describe it, and it is what keeps the free Render service awake, but whether the owner created it has never been confirmed. Render stays the default host only if it exists or is created. **Task:** V2-02. **Verified by:** owner.
*   **C12. Smallest purchase for each paid experiment provider.** DeepSeek is prepaid by top-up, Meshy sells credit packs, and GPU rentals usually require a deposit, so the cash charged is the smallest purchase, not the expected usage. The minimum, with VAT, is read for each provider before its experiment, and that amount is the fixed charge of the month it is paid. If it is above USD 8.00, or above what the month allows, the experiment is postponed or redesigned. **Task:** V2-28, V2-29. **Verified by:** owner.
*   **Q11. Real cost measurements.** The real `usage` and `cached_tokens` per turn are measured before fixing the final sub-caps. The figures in the brief are estimates. **Task:** V2-10. **Verified by:** assistant, from the ledger.
*   **Q12. Model for memory extraction and savings mode.** It cannot be `gpt-oss-20b`, which the classifier uses. It is chosen with an evaluation of the extractor. **Task:** V2-12a, V2-11. **Verified by:** assistant, with a key the owner supplies.
*   **Q13. State compatibility.** How to inform people who move from the GitHub APK to Play (the different signature forces an uninstall and erases the session, preferences and the voice model). **Task:** V2-31 (release notes and listing). **Verified by:** owner.
*   **Q15. Moderation coverage.** One host does not cover 24 hours. The options are in [Q15. Moderation coverage](#q15-moderation-coverage); the author chooses. **Blocks:** V2-24 (the Sala message path), and V2-26 after it. **Verified by:** owner.
*   **Q16. What happens in the channel to a message that expresses distress.** The options are in [Q16. A message that expresses distress](#q16-a-message-that-expresses-distress); the author chooses. What the host sees is already decided (consent first, section 3.6). **Blocks:** V2-24, and V2-26 after it. **Verified by:** owner.
*   **Q17. Self-declared age.** The 18-year rule is applied with the birth date the person types at sign-up; it is not verified. In a shared channel that weighs more than in a private chat with Marlix. The beta by invitation reduces the exposure, and opening to everyone requires deciding what to do about it. **Task:** opening decision (M6). **Verified by:** owner.
*   **Q18. What Google Play requires for the Sala.** The user-generated content policy asks for in-app reporting and blocking, accepting the terms before posting, and ongoing moderation. It remains to verify what the internal testing track requires, what must be declared in the beta and at opening, whether the Sala code may ship in the production build behind a server flag, and how Play serves versionCodes to a person who is on more than one track (checked by the "Sala track delivery test", section 5). The pages to read are "Prepare your app for review" (`answer/9859455`) and the Data safety help (`answer/10787469`). Until it is answered, the default of "Effect on the launch" applies. **Task:** V2-26. **Verified by:** assistant from the help pages, then owner in Play Console.
*   **Q19. Moderators and rules.** Who the authorized moderators are besides the host and the author, who writes the coexistence rules, and how many reports per week one person can handle while still meeting the 24-hour target. **Task:** V2-26, V2-36. **Verified by:** owner.

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
*   **When**: they read `status.md`.
*   **Then**: in one minute they see the launch progress bar and the separate Sala beta line, the version goal and the current milestone, the active task with its link, the next tasks in order, the blockers with their cause, dependency and the action that unblocks them, the launch criteria still pending (shown apart from the progress bar), and the concrete next step. They do not need to read the history or Notion.

### CUJ 12: The owner closes a task from start to finish

This journey describes the flow after C10. Before C10 the same steps apply without the board and the issue, as [Interim mode](../workflow.md#interim-mode-before-c10) and [The cycle before C10](../workflow.md#the-cycle-before-c10) in `docs/workflow.md` describe.

*   **Given**: a task is in the Ready column of the board, and its issue states the expected outcome, the acceptance criteria, how to verify them, what blocks it and its version.
*   **When**: they take it (it moves to In Progress), work on its branch, verify the criteria, commit and push, a pull request is opened (In Review) and CI passes.
*   **Then**: after the merge the task is in Done, the issue is closed, and `status.md` already shows the new progress and the next step, because the pull request carried them.

### CUJ 13: Publishing v0.2 and updating it afterwards

*   **Given**: C1 is resolved. If the closed test applies to the account, it is finished with at least 12 testers for 14 consecutive days and production access is approved. The blocking launch criteria are met.
*   **When** (first publication): v0.2 is published to production.
*   **Then**: the version is available to all Play users. The production build does not include the Sala; the beta runs on the internal testing track only if conditions A to F are met (see "Effect on the launch"), and the listing does not advertise it. If something fails, the new features are switched off with their flags from the backend and, if needed, a corrected version is published. Play does not allow going back to a lower version, and the v0.1 APKs keep working against the new backend.
*   **When** (later updates): a new version is published.
*   **Then**: it rolls out gradually at 10%, 50% and 100%, and can be paused at any stage.

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
  - crisis layer 1    |  api.<domain> (C9)      | -----> Supabase Postgres
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
| Production | Render free plan, kept awake by an UptimeRobot monitor on `/health` (documented in `docs/monitoring.md`; its existence is unconfirmed, C11), behind `api.<domain>` (CNAME at Cloudflare) once C9 allows it | Supabase Free project 1 | The real service. |
| Staging | A second Render service with automatic deploys off; the author deploys a branch or commit by hand from the Render dashboard before merging | Supabase Free project 2 | Email acceptance test, restore drill, migration rehearsal, Sala rehearsal. Sleeps when idle. |
| Local | Docker Compose (existing) | Local Postgres | Development and the database tests. |

*   Render's free plan gives 750 instance hours per month per workspace. A service kept awake uses about 730 to 744 hours, so only production stays awake; staging sleeps.
*   The VPS-1 stays a conditional alternative (C4). It is used only if a limit measured on Render forces it. With VAT it costs about USD 5.13 a month, which leaves too little for the sub-caps (section 6), so this design gives it no budget until C4 is reopened.
*   Whether Render's free plan accepts a custom domain is unverified (C9). Until it is verified, the app keeps the Render URL and the CNAME work is postponed.

### 3. Backend changes

#### 3.1 Feature flags

*   **New:** `GET /v1/me` returns an additive `flags` object. Everything is off when the field is missing or the call fails.
*   The app receives only what it renders: `social_room` (true or false for this user) and `photo_skin`. The production build ignores `social_room` because it does not contain the Sala (see "Effect on the launch").
*   `medical_urgency` is backend-only and is never sent to the app.
*   Storage: a table `feature_flags` (`name`, `mode`: `off`, `invited`, `all`) and a table `feature_flag_users` (`flag`, `user_id`) for invitations. Both tables have RLS enabled with no policy for `anon` or `authenticated`; only the backend (service role) reads them.
*   The `social_room` value for a person is true if the mode is `all`, or if the mode is `invited` and the person is in `feature_flag_users`.

#### 3.2 Spend governor

Why: Groq's paid plan has an organization-wide monthly spend limit, but it has no per-use control and, when reached, blocks every key, including the crisis classifier's (C6). The governor is the per-use control and the first barrier; the provider limit is a second barrier set above it (V2-35). The governor is a requirement for launch.

*   **Where:** at the service boundary, as two decorators: `governLlm(provider, { use, … })` wraps an `LlmProvider` and `governTranscriber(transcriber, { … })` wraps the transcriber (signatures in V2-08). `createLlmProvider` (`api/src/services/llm/index.ts`) gains a `governance` option (`{ use, ledger, monitor, prices }`) and builds `withRetry(governLlm(base, governance))`, so the governor sits below the retry and each attempt reserves on its own. `api/src/server.ts` builds five provider instances, each with a fixed tag (`chat`, `classifier_chat`, `classifier_room`, `extractor_auto`, `extractor_remember`), plus the `GroqTranscriber` wrapped with `governTranscriber` under `transcribe`. The `extractor_auto` instance goes to the memory job; the others are passed to `createApp` (`api/src/app.ts`), which builds the crisis filters today: the private chat's filter over `classifier_chat`, and the Sala's own `createCrisisFilter(...)` over `classifier_room` (section 3.6). Today a single classifier instance serves every caller and the transcriber is built outside `createLlmProvider`, so neither the Sala's calls nor the transcriptions could be told apart.
*   **Ledger:** a table `llm_spend` with one row per call: `at`, `use`, `model`, `input_tokens`, `cached_tokens`, `output_tokens`, `audio_seconds`, `state` (`held`, `settled` or `released`), `held_micros` (the maximum verifiable cost, in millionths of a USD, with tax), `settled_micros` (the real cost, once known) and `reconciled_at`. The ledger stores no message content and no user id, so it cannot become a second copy of conversations.
*   **Prices and plan as reviewed data:** provider prices live in `api/config/llm-prices.json` (`model`, `input_per_million`, `cached_per_million`, `output_per_million`, `per_audio_hour`), and the monthly plan in `api/config/spend-plan.json` (the sub-caps, the minimum margin, `tax_multiplier` and the fixed cash of each calendar month, section 6). Both are reviewed in pull requests, like `api/config/crisis.json`. Every provider price is multiplied by `tax_multiplier` (1.13 until C2 says otherwise), so the ledger and the caps are in cash.
*   **Streams:** the Groq provider does not request `stream_options.include_usage` today, and `LlmProvider.stream` cannot return usage. Both must change (V2-09), because voice-mode replies stream and are billed even when the person interrupts. Whether Groq supports that option is C6 (c); without it, every stream stays held until reconciliation.
*   **Retries and failures:** every attempt is counted, including retries (`withRetry`) and failed calls.
*   **Clock:** the governor's month and day use UTC. Whether Groq bills by UTC month is C6 (e); until it is known, reconciliation treats the first and last UTC day of each month as shared between both months, and the margin covers the difference. The per-person daily limit keeps using Costa Rica time (`daily_usage`).
*   **Shared state:** every backend instance reads and writes the same ledger. During a move to `api.<domain>`, the old Render URL and the new one point at the same service, so there is one ledger.

**Caps.** Starting values with Render as the host, in cash (VAT included), fixed after measuring Q11:

| Sub-cap | USD per month | When it is reached |
|---|---|---|
| Chat | 6.00 in a normal usage month; lowered in the usage months tied to a fixed charge (below) | Savings mode: the model chosen in Q12 and a shorter context. If savings mode is also used up, the per-person daily limit drops to 10 and the app explains it. |
| Memory extraction | 0.50 | Split in two: automatic extraction may use up to 0.30, and 0.20 is reserved for «Recordá esto». When the 0.30 is used, automatic extraction pauses until next month. Section 3.4 says what happens when the reserved 0.20 is also used. |
| Crisis classifier, private chat | 0.45 | Protected: nothing draws from it. When it is used up it borrows (below). Only if nothing is left to borrow does the classifier fail closed: an ambiguous message receives the crisis response with the help lines. |
| Crisis classifier, Sala | 0.15 | The Sala's own pool. It never draws from the private chat's pool, nothing draws from it, and **during the beta it does not borrow**. At 80% the author is alerted. What happens when it is used up is described below ("When the Sala's pool runs out during the beta"). |
| Voice transcription (Whisper) | 0.40 | The API answers HTTP 429 `VOICE_BUDGET_EXHAUSTED`; the app hides the voice button and text keeps working. |
| Margin | 2.50 in a normal usage month; never below 0.50 | Absorbs price changes, a VAT different from the assumed one, and estimate errors. The private chat's classifier may borrow at most half of it; the other half is never granted. |

*   **Cash months and usage months.** The cap applies to each calendar month **in which the card is charged** (the "cash month"). The governor counts **usage months** (UTC). A Groq invoice for a usage month may be charged in that same month or in the next one; which one is C6 (f), still open. Each fixed charge (the domain, a paid experiment's smallest purchase, C12) is listed in `spend-plan.json` under the cash month in which the card is charged. For the domain renewal, that is the date Cloudflare charges the renewal, recorded at purchase (C3).
*   **Lowered usage months.** While C6 (f) is open, a fixed charge F in cash month R lowers **both** usage months R−1 and R, so the cap holds whether Groq charges in the same month or the next one (the table in section 6 checks both). In a lowered usage month, the governor lowers only the chat sub-cap: chat = the lower of 6.00 and (10 − F − the other sub-caps − 0.50), and the margin is 0.50. It never lowers a classifier pool. F may be at most USD 8.00 while Groq is on the paid plan, so chat never goes below zero. Once C6 (f) is known, only the one usage month whose invoice lands in R is lowered. A fixed charge is entered in `spend-plan.json` before usage month R−1 starts.
*   **Classifier borrowing (one way, private chat only).** When the private chat's classifier pool is used up, its reservation is granted from unused headroom of chat, then memory, then Whisper, then at most half of the margin. The borrowed amount is recorded in the classifier's own counter and subtracted from the lender's. Nothing ever draws from a classifier pool. Safety therefore degrades only when the money it may borrow is gone, and the governor's total never exceeds the sub-caps plus half the margin, which stays below the provider spend limit (section 3.3).
*   **When the Sala's pool runs out during the beta.** The Sala's classifier pool does not borrow, and its per-person share is deferred to the Open stage, so in the beta only the per-person rate limit and this pool protect it. When the pool is used up, for the rest of the usage month: layer 1 still checks every Sala message; a message with a clear risk signal gets the private help response with the help lines and the consent question, as before; an **ambiguous** message, which would need the classifier, is **held**: it is not published, and its author receives in private the help response with the help lines and a short note that the message could not be published; a message with no signal is published as usual; the help button stays visible; the private chat is not touched. `/health/spend` alerts the author at 80% and at 100%. The author may raise the pool for the rest of the month only by a reviewed change to `spend-plan.json` that keeps the invariant.
*   **Whisper.** A transcription reserves `max(WAV seconds, 10) × price × tax_multiplier`, because Groq bills at least 10 seconds per request, and settles at that reserved amount, because the transcriber returns only the text (V2-08). Each person has a daily share of the pool: 6 billed minutes (36 requests at the floor), a starting value fixed after Q11. When the pool or the person's share is used up, `POST /v1/transcribe` answers `VOICE_BUDGET_EXHAUSTED` without calling Groq.
*   **Alerts and health.** `/health` keeps what it does today (`api/src/routes/health.ts`): it answers 200 for Render and the keep-awake monitor, and reports `degraded` with `usage_counter` or `groq_quota` from in-memory monitors (`docs/monitoring.md`). Nothing about it changes. Two new endpoints carry the new alerts, built on the same in-memory monitor pattern as `QuotaMonitor`, each with its own UptimeRobot keyword monitor: `/health/spend` reports `degraded` at 80% of either classifier pool or of Whisper, or when the month's total passes 90% of the cash available to Groq; chat at 80% appears in the response body as information only, because the expected scenario reaches it every month. `/health/safety` reports `degraded` when the classifier fails more than 5 times in one hour or the provider answers `spend_blocked`. Their state comes from the results of the reservations kept in memory, so no health check reads the database.
*   The beta daily limit per person goes from 100 to 40. This is a reversible data change in `plan_limits` (the table of daily limits per plan; every account is on the plan `personal`). The move to 10 needs code and a message in the app.

**How the cap holds** with simultaneous calls, retries and interrupted voice replies. The invariant, for every cash month, is: the fixed charges of that month, plus the Groq invoices charged in it, is at most USD 10, with every price multiplied by `tax_multiplier`. For each usage month, the governor grants at most the sub-caps plus half the margin, and the provider spend limit stops Groq at the sub-caps plus three quarters of the margin; the last quarter absorbs estimate errors and the provider's 10 to 15 minutes of lag. Section 6 checks the invariant month by month for both billing timings.

*   **Simultaneous calls.** A database function, `reserve_spend(use, worst_case_micros)`, runs as one atomic statement on a counter row per month and use (`spend_counters`: `spent_micros`, `reserved_micros`, `cap_micros`). It grants the reservation only if `spent + reserved + worst_case <= cap`, and otherwise refuses it, or, for a classifier use, tries the lenders in order. Two calls that arrive together cannot both pass, in the same way the existing `record_interaction` function counts replies atomically. After the call, `settle_spend` replaces the reservation with the real cost. A reservation that is never settled (for example, the process crashed) stays held at its worst-case value, so a crash never lowers the total.
*   **Size of a reservation: the maximum cost the backend can verify.** It is computed from facts the backend itself knows: the prompt it sends (tokens counted with a conservative ratio, plus a 20% margin), the `max_completion_tokens` it sets (1,024 for chat today, per `chat-service.ts`), and the price table at the uncached price. When the remainder is smaller than one worst-case chat reservation, chat switches to savings mode before the sub-cap is empty.
*   **What a reservation guarantees.** A reservation keeps one call within its sub-cap unless the token ratio under-counts by more than 20% or the price table is out of date. The margin covers errors in both.
*   **Nothing is released on a guess.** A reservation shrinks only when there is evidence of the real cost (the provider's `usage`) or evidence that the call was not billed. Until then it stays `held` at its maximum and counts against the sub-cap.
*   **Retries.** The decorator sits below `withRetry`, next to the HTTP call, so each attempt reserves on its own. A retry never reuses or frees the reservation of the attempt before it.
*   **Interrupted voice replies.** When the person interrupts, the backend aborts the upstream request at once. An aborted stream may be billed for only what was generated, or for the whole reply, and the backend cannot tell which (C6 (b)). So the call stays held at its full worst case until the provider's data show the real cost. The tokens already streamed, counted from the chunks, are recorded as a lower bound to help reconciliation, never to release the hold. Whether to keep reading an interrupted stream to obtain its final `usage` is decided when C6 (b) is answered (V2-09).
*   **Deploys.** On `SIGTERM` the server already stops its jobs and lets requests in flight finish (`api/src/server.ts`). The governor adds a bounded wait: calls in flight are settled before the process exits, and any stream still open after 20 seconds is aborted and stays held.

| Outcome of the call | Counts against the cap as | Released or reduced when |
|---|---|---|
| Completed, with `usage` in the response or in the final stream chunk | The real cost | At once: the difference to the reservation is returned |
| The provider answers with an error body (4xx or 429) | The worst case, held | After a reconciliation shows that the provider does not bill such calls (C6 (b)); from then on, at once |
| 5xx, timeout or dropped connection | The worst case, held | At reconciliation |
| Stream aborted before the final `usage` | The worst case, held | At reconciliation |
| A reservation never settled (the process crashed) | The worst case, held | At reconciliation |
| Transcription | `max(audio seconds, 10)` at the per-hour price | When the response reports the billed duration, or at reconciliation |

*   **Reconciliation with the provider's data.** Held amounts are released here, or by the evidence in the table. It is done **per model and per period**, because Groq reports usage per model, not per use. Weekly during the first month and monthly afterwards, the owner reads the provider's usage per model for the period (an export if C6 (a) finds one; otherwise the invoice total plus the `usage` already in the ledger), and the assistant runs one SQL function, `reconcile_spend(period_start, period_end, model, provider_total_micros)`, described in `docs/spend-reconciliation.md`. If the provider's total is lower than what the ledger holds for that model, held rows of that model are released oldest first. If it is higher, the shortfall is added as spent at once, charged to the margin first and then to chat, never to a classifier pool, and an alert fires. Each reconciliation is recorded in `docs/decisions.md`. Held amounts that are not reconciled stay counted in the month they happened, so over-holding reduces what can be spent but never raises the cash cost. The expected cost of holding and the calibration test are in V2-10.
*   **If the ledger cannot be read.** Chat and transcription fail closed: the request is refused with the existing "momentary problem" message and the help button stays visible. Only `classifier_chat` may run without the ledger, at most 30 calls per hour, and its cost is recorded afterwards, because refusing it would turn every ambiguous message in the private chat into a crisis response. The Sala becomes read-only while the ledger is down.

#### 3.3 Model roles, quota isolation and provider failures

| Use | Model and provider | Notes |
|---|---|---|
| Chat | `openai/gpt-oss-120b` on Groq, ZDR on (checked in V2-02 and again in V2-35) | Groq Free during the closed test; the paid plan only after V2-35 (rule below). Groq says it does not retain inference data by default and, with ZDR, does not retain it for abuse review either. Data is stored on GCP in the US. |
| Crisis classifier | `openai/gpt-oss-20b`, **exclusive** | Today the classifier and the extractor share this model and key. The classifier fails closed, so a quota used up by extraction would answer harmless ambiguous messages with the crisis response. From V2-12a the classifier reads its own variables (`CRISIS_CLASSIFIER_MODEL`, which exists today, and a new optional `CRISIS_CLASSIFIER_GROQ_API_KEY`), so moving it to another key or organization is a Render setting, not code. |
| Memory extraction and savings mode | A different Groq model, chosen with an evaluation of the extractor (Q12, V2-12a) | Groq's rate limits are per model within an organization, so separate models already separate the rate limits. A second key in the same organization isolates nothing. A separate organization (V2-12b) would mainly protect the classifier from the organization-wide spend block, and only if C6 (d) shows it has its own limit. |
| Transcription | `whisper-large-v3-turbo`, Groq | Audio is not stored. |
| DeepSeek | **Experiment, synthetic data only** | Its terms say data is stored in the People's Republic of China, give no retention period for API inputs, and offer no ZDR or data processing agreement. |

Comments in the repository that contradict this must be corrected in V2-12a: `.env.example` ("its own quota"), `memory-job.ts` ("the same quota as the chat") and `docs/monitoring.md`, which says the reply review uses Groq requests (the **reply review** is the local check of a model reply before it is sent; it uses no model).

**Groq plan.** During the closed test, chat runs on Groq Free if its limits are enough for the testers (V2-34 checks it). ZDR was confirmed on in the production organization on 2026-10-29; V2-02 checks it again in Settings > Data controls before any tester is invited, and if ZDR is not on for the free plan, no tester is invited until V2-35 is done. Groq moves to the paid plan only after V2-08, V2-09 and V2-12a are in production and ZDR is verified again (V2-35).

**Provider spend limit (the second barrier).** V2-35 sets it to `(the sum of the usage month's sub-caps + three quarters of the margin) / tax_multiplier`: about USD 8.30 in a normal usage month and 3.54 in a lowered one (section 6). The governor grants at most the sub-caps plus half the margin, so it always stops first; the provider limit catches estimate errors, and the last quarter of the margin covers the 10 to 15 minutes of lag. The limit is lowered by hand on the first day of each lowered usage month and restored on the first day of the next normal one; `status.md` lists both dates under "Later". If the classifier has its own organization (V2-12b), that organization's limit is the private chat's classifier pool plus its margin borrowing plus the Sala pool, `(0.45 + 1.25 + 0.15) / 1.13`, about USD 1.64 in a normal month and `(0.45 + 0.25 + 0.15) / 1.13`, about 0.75, in a lowered one, and the main organization's limit is lowered by the same amount (about 6.66 and 2.79), so the two together never exceed the formula. With two organizations the classifier can only borrow from the margin, never from chat, memory or Whisper headroom, because those are billed to the other organization; its borrowing stays capped at half the margin.

**Behavior when a provider fails:**

| Failure | Behavior |
|---|---|
| Any | Layer 1 (local patterns) answers first and depends on no provider. |
| Classifier (error, quota, timeout) | Counts as a crisis, as today. More than 5 in one hour marks `/health/safety` as `degraded` and UptimeRobot emails the author. |
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
5.  The crisis classifier's own protected pools: one for the private chat (USD 0.45) and a separate one for the Sala (USD 0.15). Nothing draws from them, and neither draws from the other. When the private chat's pool is used up it borrows unused chat, memory or Whisper headroom, then at most half of the margin (section 3.2); only if that is gone does its classifier fail closed (the person receives the crisis response with the help lines, never silence). The Sala's pool does not borrow during the beta; when it is used up, the Sala's ambiguous messages are held and their authors receive the help lines in private (section 3.2). Layer 1 still checks every Sala message, and the help button is visible on the Sala screen.

What stops when its sub-cap runs out: chat replies (after savings mode and the step-down of the daily limit), automatic memory extraction, and voice transcription.

#### 3.4 Memory: «Recordá esto» and automatic extraction

*   **New endpoint** `POST /v1/memories/remember` with `{ message_id }`. It runs the existing extractor on that one message, saves the result through the existing memory store, and returns the saved memory so the app can show «Marlix recordó: … · Deshacer». «Deshacer» calls the existing delete endpoint.
*   **Cost:** one extractor call per request, so it uses little quota and the person is in control.
*   **Automatic extraction** stays, with `CONVERSATION_IDLE_MINUTES` lowered from 30 to 10. It also shows the notice in the app on the next open.
*   **The two barriers against sensitive data stay** (`sensitive.ts` and the extractor prompt).
*   **Discarded:** extracting after every turn. About 6,000 extra calls per month in the expected scenario, and it would share quota with the classifier.
*   **When the memory budget runs out.** The memory sub-cap is split (section 3.2): automatic extraction may use up to 0.30, and 0.20 stays reserved for «Recordá esto», which the person asks for explicitly.
    *   Automatic extraction pauses first, until the next month.
    *   If the reserved 0.20 is also used up, «Recordá esto» does not call a model. It saves the text of the chosen message as the person wrote it, up to 200 characters, after the local sensitive-data patterns (`sensitive.ts`), and the notice reads «Marlix lo guardó tal como lo escribiste · Deshacer». If the text is longer, or matches a sensitive pattern, the app asks the person to shorten it or explains that it cannot be saved. Viewing, editing and deleting keep working.
    *   Alternatives considered for this case: refuse until next month (the feature disappears at the moment it is used most), or queue the request and extract it later (a memory the person asked for appears days late). The verbatim fallback is the only behavior built.
*   **Why memories appear late today:** the job runs when a conversation has been idle for 30 minutes, started by a timer inside the process or by the next message. The 30-minute rule explains most of the delay. If the service is asleep, the timer does not run either; `docs/monitoring.md` documents an UptimeRobot monitor that prevents that, but whether the monitor exists is unconfirmed (C11).

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
*   **Rate limit.** `POST /v1/room/messages` has a per-person limit (starting values: 6 messages per minute and 200 per day) on the existing `usage-limiter` pattern. During the beta this limit and the Sala's own pool are the only protections of that pool; a per-person share of the pool is added before the Open stage, together with `room_bans`.
*   **Endpoints (names fixed in `docs/api-contract.md` by the Sala tasks):** `GET /v1/room/messages`, `POST /v1/room/messages`, `POST /v1/room/blocks`, `DELETE /v1/room/blocks/{user_id}`, `POST /v1/room/reports`, `GET /v1/room/reports/mine`, `POST /v1/room/help-requests` (the person's yes), and for moderators `GET /v1/room/moderation/reports`, `POST /v1/room/moderation/actions` and `GET /v1/room/moderation/help`. Every Sala endpoint answers `404` when the flag is off for the account.
*   **Moderator view (V2-36).** A "Reports" view inside the Sala screen, shown only to the `host` and `moderator` roles, lists reports with two-report cases first, the help requests, and the anonymous counts of completed days (never the current day's, which in a small group could point to the author of a message that was just held). v0.2 sends no push or email for moderation.
*   **What a report does:** it hides the reported message from the reporter's own view at once and sends it to moderation with a snapshot of its text. Two reports from two different accounts about the same message raise the case's priority: it is shown first in the moderator view. Only an authorized moderator removes a message for the whole room, so two people cannot remove a message from everyone's view by agreeing.
*   **Moderation is immediate.** A moderator acts as soon as they review a case; nothing delays an action. Each action is recorded in `room_actions`, and the penalized person sees which rule was applied.
*   **Reporter privacy.** The reported person and the other members never see who reported or when: the penalized person sees the rule, never the time of the report, and the API never returns the report time to anyone but moderators. Moderators see the reporter only in the moderator view, and only the minimum needed to ask a follow-up question. The reporter sees the status of their own report through `GET /v1/room/reports/mine`, and a resolution becomes visible to them only in the next daily batch (`reporter_visible_at`, the next 09:00 Costa Rica time after the resolution), so the timing of the notice does not point to them.
*   **Help requests and the host.** A clear risk signal never leaves the backend (`CONTRIBUTING.md`, rule 4). The host learns about a person only when that person answers yes, and then sees a help request without the message text. Otherwise the host sees only the anonymous counts of completed days. This holds for every Q16 option.
*   **Separation from Marlix:** the Sala tables are not joined to `messages`, `memories` or the extraction job. A test checks that a Sala message never enters the chat history, the prompt or the extractor.
*   **Costs:** the Sala's classifier calls use the `classifier_room` provider instance and its own crisis filter, so they are charged to the Sala's pool (USD 0.15 a month) and never to the private chat's pool (USD 0.45); the two are separate rows in `spend_counters`. At 80% of the Sala's pool the author is alerted (`/health/spend`).
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
| Sala | Only in the internal-track build (`SALA_ENABLED=true`), and entry only when `flags.social_room` is true. Rules and terms screen, channel view refreshed by polling, nickname and avatar profile, block and report actions, suggested topics, the moderator's Reports view, and the help button always visible. |

**UI and UX method.** The interface is designed with the installed `ui-ux-pro-max` skill. It is the working method of V2-15 (navigation, theme and first use), V2-19 (appearance picker), V2-20 (voice picker and microphone permission), V2-21 (games), V2-25 (Sala screens) and V2-36 (moderator view), and a review pass on the UI states of V2-11, V2-13 and V2-14. Each of these tasks attaches to its pull request the deliverables reviewed with the skill: a navigation map, a component inventory, an accessibility checklist (TalkBack, text at 200%, contrast of at least 4.5 to 1, touch targets of at least 48 dp) and the screen states (empty, loading, error, offline, reduced motion and flag off). The issue template gains a "Working method" field, and `status.md` shows "UI method: ui-ux-pro-max" with a link to the task's UI section only while the active task is one of these.

**Reminder migration.** It runs once, marked by `reminders_migrated_v2`. If the reminder was on: `cancelAll`, reschedule at 19:00, and show «Ahora el saludo diario llega a las 7 p. m.» only if the previous time was different. If it was off, nothing changes. The operating-system alarms from v0.1 keep firing until the migration runs, so the marker is written only after the reschedule succeeds. Tests cover each state: on with 19:00, on with another time, off, and first install.

### 5. Hosting, email and Google Play

**Email.** Resend's free plan is the SMTP for Supabase Auth (`smtp.resend.com`); the domain is registered at Cloudflare. The templates in `infra/auth/` and the six-digit code flow (S7-9) do not change.

| Option | Cost | Limits | With Supabase | Upkeep |
|---|---|---|---|---|
| Current SMTP | Unknown (C5) | Unknown | Already set | If it is a Gmail address it cannot send from an own domain |
| **Resend (proposed)** | $0 | 3,000 emails per month, 100 per day, 3 domains; 30-day retention | On Supabase's list of providers | SPF and DKIM from Resend, DMARC by hand |
| Amazon SES | $0.10 per 1,000 (à la carte); new accounts start on the Essentials plan at $0.16 | Sandbox at the start (not confirmed) | On Supabase's list | An AWS account, IAM, leaving the sandbox |
| Mailflare | Free software (AGPL-3.0), but it still sends through Resend, SES or Cloudflare | Those of the sender | Does not replace the SMTP | A mail suite to operate |

*   **Support mailbox:** not needed to launch. If wanted, Cloudflare Email Routing (free) forwards `soporte@<domain>` to the owner's mailbox.
*   **Supabase rate limit:** with custom SMTP, Supabase allows 30 emails per hour by default. That is enough for 50 users over time, but not for inviting a whole group of testers at once, so invitations go in batches (V2-34).
*   **Domain:** a `.fyi` at Cloudflare (author decision). The cap is per cash month, so the domain must fit both when it is bought and at every renewal, together with the Groq charges that land in the same cash month (section 6). Prices before tax come from a third-party mirror of Cloudflare's prices (Cloudflare states it adds no markup); the final price with tax is confirmed at checkout before buying (C3).

| TLD | Before tax, purchase and renewal | With 13% VAT | Left for chat in a lowered usage month, after the other sub-caps (1.50) and the minimum margin (0.50) | Outcome |
|---|---|---|---|---|
| `.fyi` | 5.20 | 5.88 | 2.12 | **Chosen.** Chat runs in savings mode in that month. |
| `.link` | 7.20 | 8.14 | none (0.36 is below the minimum margin) | Rejected: chat would stop in two usage months a year. |

*   `.com` (11.82 with VAT) and `.app` (16.05 with VAT on renewal) break the cap in the month they are paid. The deliverability reputation of niche domains was not checked, so V2-06a repeats the Gmail and Outlook main-inbox test with the `.fyi` sender.
*   **Order:** the own-domain sender is verified in staging and then in production before the public release of v0.2, and it can be prepared in parallel with the closed test. The closed test does not wait for it, provided the check of V2-34 passes: staging replicates the production provider and sender, the sign-up and recovery codes reach Gmail and Outlook and work in the app, and the send limits cover each batch of testers. If the check fails, the email is fixed before the testers are invited. Resend is added to the privacy policy as a processor.
*   **Acceptance test in staging:** (1) a full sign-up and a full password recovery in the app; (2) delivery to the main inbox in Gmail and in Outlook, with the domain sender visible and SPF, DKIM and DMARC at `pass` in the headers; (3) resending works after 60 seconds; (4) an expired code (expiration shortened in staging) is rejected with the neutral message.

**Database.** Supabase Free stays for production and staging (two active projects). A restore drill against a real project is a launch criterion: the 2026-11-03 drill used local containers and synthetic data (`docs/backups.md`). It passes if row counts match, RLS is on in all tables, and the app signs in. After a restore, everyone signs in again (`docs/backups.md`). A weekly ping from GitHub Actions keeps the staging project from pausing after a week of inactivity.

**Google Play.**
*   Verify the account type, creation date and identity verification first (C1).
*   If the closed test applies, run it with at least 12 testers for 14 consecutive days, with the AAB that C1 allows. Recruiting more than 12 covers drop-outs. The requirement is met once per app or account, not per version, so running it on the v0.1 AAB lets the 14 days pass while v0.2 is built (to confirm under C1).
*   After day 14 the closed track stays open, and v0.2 release candidates are uploaded to it, so the same testers are the panel for the "4 of 5 testers" criteria. Whether Play allows continuing the track after production access is granted is to verify.
*   Before production, the exact production AAB is installed on real devices through Play's internal app sharing. The internal testing track (up to 100 testers) is reserved for the Sala beta build (see "Effect on the launch").

**Production build check (launch).** Run in V2-33 with the exact production AAB of the release. It needs no Sala code or build, so no launch task depends on the Sala.

| # | Setup | Action | Expected |
|---|---|---|---|
| P1 | A device whose Google account is on no Sala tester list. | Install the exact production AAB through an internal app sharing link. Read the installed versionCode with `adb shell dumpsys package io.github.wguillendev.marlix` and open «Practicar». | The versionCode is the production one, and «Practicar» has no Sala entry. |
| P2 | The production AAB, built without `--obfuscate` (the app does not use it today). | Copy the AAB to a `.zip`, extract `base/lib/arm64-v8a/libapp.so`, and search it with `Select-String -SimpleMatch` for `RoomScreen` and for `HomeShell`, a class every build contains (V2-15). | No match for `RoomScreen`; at least one match for `HomeShell`, which proves the search works. |

**Sala track delivery test (Sala beta).** Run in V2-26 before the first beta invitation, and again at the first release while the beta is live. It never uploads test builds to the closed track during the closed test. Results go to `docs/decisions.md`; if Play behaves differently from the expected column, the distribution rule is changed before any invitation. A closed track is created for this test even if C1 shows the closed test is not required.

| # | Setup | Action | Expected |
|---|---|---|---|
| S1 | Three test Google accounts, each on its own device (emulators with the Play Store, or the Galaxy S24 if the owner says it is free): A only on the internal track's tester list, B only on the closed track's list, C on both. The Sala flag is on for all three in staging. | Upload the Sala AAB with versionCode N+1 to the internal track and a production candidate with versionCode N to the closed track. Each account opts in through its track link and installs from Play. Read each installed versionCode and open «Practicar». | A gets N+1 with the Sala entry; B gets N without it; C gets N+1, the highest versionCode it is eligible for. This is the rule that requires the Sala AAB to be rebuilt with a higher versionCode for every release. |
| S2 | The Sala AAB of the same commit. | Run the search of P2 on it. | At least one match for `RoomScreen`. |
| S3 | `flutter test` (V2-25). | A widget test builds the app with `SALA_ENABLED` false and true. | With false, the route table and «Practicar» have no Sala route or entry; with true, they do. |

*   The first publication goes to production when the launch criteria are met (author decision). Staged rollouts at 10%, 50% and 100% apply from the second release.
*   Complete in Play Console: Play App Signing, data safety, content rating, target audience and the health declaration. The user-generated content declaration is needed only for the production update that opens the Sala (Q18).
*   People who installed from GitHub and move to Play must uninstall, because the signatures differ (Q13). The release notes and the listing say so (V2-31). v0.2 is also published on GitHub with the same key, so those who stay there update without losing data.

### 6. Budget

All amounts are US dollars of cash with 13% VAT included (`tax_multiplier` 1.13 until C2 confirms it). Nothing is prorated. A **cash month** is the calendar month in which the card is charged; a **usage month** is the UTC month the governor counts (section 3.2). The figures come from official pages read on 2026-11-19; where one is unconfirmed it is marked.

**Fixed costs.** Hosting (Render free plan), Supabase Free, Resend Free, Cloudflare DNS and Email Routing, GitHub and UptimeRobot cost 0. The only recurring fixed charge is the domain, `.fyi` at 5.20 before tax (a price mirror; C3), 5.88 with VAT, once a year. The VPS-1 has no budget in this design (C4): at about 5.13 a month with VAT it would leave too little for the sub-caps.

**What one usage month can cost.** A lowered usage month is one tied to a fixed charge F (section 3.2); the column uses the domain, F = 5.88.

| Item | Normal usage month | Lowered usage month (F = 5.88) |
|---|---|---|
| Chat sub-cap | 6.00 | 2.12 |
| Other sub-caps (memory 0.50, classifiers 0.45 and 0.15, Whisper 0.40) | 1.50 | 1.50 |
| Margin | 2.50 | 0.50 |
| Governor ceiling: sub-caps plus half the margin | 8.75 | 3.87 |
| Provider spend limit, before tax: (sub-caps + ¾ of the margin) / 1.13 | 8.30 | 3.54 |
| **Most that Groq can charge for the usage month, with VAT** | **9.38** | **4.00** |

For any fixed charge F up to 8.00, a lowered usage month can cost Groq at most 9.88 − F, so F plus that month's Groq charge is at most 9.88.

**Month-by-month check around a fixed charge.** The domain is charged in cash month R. While C6 (f) is open, usage months R−1 and R are both lowered. The table checks the two billing timings the design allows.

| Groq charges a usage month | Usage month | Groq charge, with VAT, at most | Cash month in which it is charged | Fixed charge in that cash month | Total from the card in that cash month |
|---|---|---|---|---|---|
| In the same month | R−2 | 9.38 | R−2 | 0 | 9.38 |
| In the same month | R−1 (lowered) | 4.00 | R−1 | 0 | 4.00 |
| In the same month | R (lowered) | 4.00 | R | 5.88 | **9.88** |
| In the same month | R+1 | 9.38 | R+1 | 0 | 9.38 |
| In the next month | R−2 | 9.38 | R−1 | 0 | 9.38 |
| In the next month | R−1 (lowered) | 4.00 | R | 5.88 | **9.88** |
| In the next month | R (lowered) | 4.00 | R+1 | 0 | 4.00 |
| In the next month | R+1 | 9.38 | R+2 | 0 | 9.38 |

Both timings stay at or below USD 10 in every cash month; the worst month is 9.88. The price is one extra month in savings mode around each fixed charge until C6 (f) is answered.

**The timing this check does not cover.** If Groq charges part of a usage month during that month (for example, when a usage threshold is crossed) and the rest in the next month, one cash month can carry parts of two usage months. Then a normal cash month could reach 9.38 + 9.38, and cash month R could reach 4.00 + 4.00 + 5.88 = 13.88. The design does not hold the cap in that case. C6 (f) therefore gates V2-35: before Groq moves to the paid plan, the owner reads how Groq charges the card. If it is this mixed timing, the budget is redesigned before V2-35, for example by capping each usage month's Groq charge at half of what its cash months allow. On the free plan, before V2-35, nothing is charged, so the closed test is not affected.

**Expected use.** Estimates for 50 people. The chat estimate assumes about 3,500 input tokens and about 400 output tokens per turn including reasoning (about USD 0.00077 per turn before tax on `gpt-oss-120b`, with no caching credit; 0.00087 with VAT). It also assumes that 30% of turns use voice, billed at about 12 seconds each (the 10-second minimum and short utterances). Real values are measured first (Q11).

| Scenario | Turns per month | Chat | Memory | Classifiers and Whisper | Total with VAT |
|---|---|---|---|---|---|
| Low | 1,500 | 1.30 | 0.11 | 0.10 | about 1.5 |
| Expected | 6,000 | 5.19 | 0.47 | 0.40 | about 6.1; in a lowered usage month chat goes to savings mode |
| High | 30,000 | cut at the sub-cap | cut at the sub-cap | cut at the sub-cap | at most the governor ceiling |

*   Per-person daily limits do not bound the spend: 50 people at 40 turns for 30 days is 60,000 turns, twice the high scenario. The governor does.
*   `deepseek-flash` would cost 0.46, 1.83 and 9.15 before tax with caching, and 1.38, 5.52 and 27.6 without it. `deepseek-v4-pro` would cost about 7.4 with caching and about 31 without it in the expected scenario. DeepSeek's peak prices (19:00 to 22:00 in Costa Rica) double the rates and coincide with the 19:00 reminder, so at least half of the traffic is assumed to land in peak.

**Cash plan.** One rule covers every case: each charge is entered in `spend-plan.json` (in `status.md` before V2-08) under the cash month in which the card is charged, before usage month R−1 starts, and every cash month must pass the check above.

| Example | Fixed charge with VAT | Groq | What the rule gives |
|---|---|---|---|
| Domain purchase while Groq is on the free plan | 5.88 | Free, nothing charged | 5.88 in that cash month. |
| Domain purchase or renewal while Groq is on the paid plan | 5.88 | Paid | Usage months R−1 and R lowered (chat 2.12); the worst cash month is 9.88. |
| A paid experiment (V2-28 or V2-29 (b)) | its smallest purchase (C12), for example 3.39 for a 3.00 pack | Free or paid | If paid, usage months R−1 and R lowered (chat 4.61 for 3.39); the worst cash month is 9.88. Postponed if the smallest purchase is above 8.00. |

*   Scheduling rule: two fixed charges are never scheduled in the same or consecutive cash months, so no usage month is lowered twice. On the paid plan, a fixed charge is entered in `spend-plan.json` at least one full usage month before its cash month, because usage month R−1 must already be lowered.
*   For each lowered usage month, `status.md` lists the date to lower the Groq spend limit and the date to restore it ("Later" section), and, one month before the renewal, a reminder to confirm the renewal price.

### 7. Experiments and exit criteria

Each experiment is behind a flag or a separate spike. It enters v0.2 only if it meets its criterion. None blocks the launch. Before C10, an experiment task is taken only when "Next up" in `status.md` lists no P0 or P1 task; after C10, only when no P0 or P1 issue is in Ready.

| Bet | Small test | Continue if | Otherwise |
|---|---|---|---|
| DeepSeek `deepseek-flash` and `deepseek-v4-pro` for chat | 30 synthetic Spanish conversations of 8 turns; answers mixed and anonymous; the owner and 2 or 3 testers pick the better answer in each pair against `gpt-oss-120b`. V4 Pro runs without reasoning and only as a bounded test. | The candidate wins at least 2 of 3 pairs, the median time to the first sentence in voice mode is at most 300 ms slower than Groq, and the expected cost fits the sub-cap. Real data additionally needs an accepted privacy-policy change. | Stay on Groq. |
| `photo_skin` (object photo to 2D skin) | The photo is processed on the phone and is not stored or uploaded; only the skin is saved. | 4 of 5 testers recognize the skin as theirs. | Keep only the palette picker. |
| Object to 3D avatar | 20 captures of the author's own objects, never of people, through the Meshy API (texturing 30 credits, rigging 5; price per credit not verified) or TRELLIS.2 (MIT license, about 16 GB of VRAM) on a rented GPU. Procedural animation, because automatic rigging only works for humanoids and quadrupeds. Expected usage of at most $3 before tax ($3.39 with VAT); the cash charged is the provider's smallest purchase (C12), in its own cash month (section 6). | 15 of 20 objects recognizable, at most $0.05 per capture, at most 2 minutes, and 4 of 5 testers prefer it to the 2D skin. | Postpone. |
| Room to 3D scene | First, ARCore plane detection live (floor and table), without reconstructing the room, at $0. | The avatar walks on the detected floor and table on the Galaxy S24 and on a mid-range phone. The Flutter AR plugin is not verified. | Postpone. |
| Voice comparison | Blind listening of 5 phrases: Supertonic, Kokoro or Piper through sherpa-onnx (Apache-2.0; espeak-ng is GPLv3; Kokoro in Spanish is not confirmed), the system voice, and Google WaveNet as a reference. | Another voice wins and its license is compatible with MIT. | Keep Supertonic (the official repository is archived since 2026-09-09; the model is local and keeps working without updates). |
| Medical-urgency layer | Review by a health professional (C7). | The review is signed and recorded. | The layer does not ship. |
| Sala de Marlix opening | The private beta (see "Sala de Marlix: scope"). | The five opening criteria. | It stays in beta. |

Meta Motivo and Locate 3D were reviewed and discarded: Meta Motivo controls a simulated humanoid, takes no images and is CC BY-NC 4.0; Locate 3D finds objects in RGB-D scenes with camera poses, does not reconstruct them, is CC BY-NC and has been archived since 2026-08-01.

### 8. Launch criteria

All of these block the launch. Each names the tasks that meet it, who verifies it, and the open condition that prevents publishing until it is answered.

| # | Criterion | Task(s) | Verified by | Open condition that prevents publishing |
|---|---|---|---|---|
| 1 | C1 is resolved. If the closed test applies, it is finished (at least 12 testers, 14 consecutive days) and production access is granted. | V2-02, V2-03 | Owner, in Play Console | C1 |
| 2 | The restore drill against a real Supabase project passed. | V2-05b | Assistant runs it; owner confirms the app sign-in | none |
| 3 | The spend governor is in production: persistent ledger (held and settled states), every use routed under its own tag including Whisper, usage from streams, the `/health/spend` alert, and a first reconciliation against the provider's data (an export or, if there is none, the invoice). | V2-08, V2-09, V2-10 | Assistant; owner reads the provider's usage | C6 (a) decides the source of the reconciliation, not whether it can be done |
| 4 | The classifier quota is isolated (its own model from V2-12a; its own organization from V2-12b, or V2-12b closed as not applicable), and `npm run crisis:eval` passes. | V2-12a, V2-12b | Assistant | Q12; C6 (d) |
| 5 | The own-domain email sender is verified and accepted in staging and in production before the public release. The current SMTP may serve the closed test if V2-34 passes, never the public release. | V2-06a | Owner, with the assistant's checklist | C3, C5 |
| 6 | The launch features are done with their tests: tabs and accessibility, the living avatar (60 fps on the Galaxy S24 and the low-end AVD, 4 of 5 testers), voices, memory, the greeting with its migration, the games, and savings mode. | V2-11, V2-13 to V2-21 | Assistant; testers of the closed track for "4 of 5" | none |
| 7 | The production build does not contain the Sala, and the Play listing, the privacy policy and the website do not advertise it. | V2-31, V2-33 | Assistant, with the "Production build check" (section 5, P1 and P2) | none (Q18 changes only the Sala's own distribution) |
| 8 | The privacy policy, the data safety form and the health declaration are updated with the new processors. | V2-31 | Assistant for the site; owner in Play Console | none |
| 9 | The v0.1 APKs still work against the new backend. The daily-limit step-down reuses `DAILY_LIMIT_REACHED`, so v0.1 shows its usual limit message; a voice-budget refusal shows v0.1's generic error, and text keeps working. | V2-07 (contract test in CI from M1), V2-32 | Assistant | none |
| 10 | `npm run typecheck`, `npm test`, `npm run build`, `flutter analyze` and `flutter test` are green; the release build was tested on the Galaxy S24, on the low-end AVD and from an internal app sharing link; with the network off, a crisis message shows the crisis response and the help lines. | V2-33, V2-37 | Assistant; owner lends the Galaxy S24 | none |
| 11 | Groq is on the paid plan with ZDR verified in the organization, and the provider spend limit is set with alerts at 50, 75 and 90%. | V2-35 | Owner, in the Groq console | C6 (f), and a budget redesign first if Groq charges a usage month across two cash months |

Not blocking: the experiments (`photo_skin`, DeepSeek, 3D, ARCore, `medical_urgency`), the stable hostname (V2-06b), and everything about the Sala.

### 9. Sequence and milestones

Nothing here starts until this design is approved. The edges in "Depends on" (Work order) and the gates are **mandatory**; the Order column and the milestone sequence are **recommended**.

**Mandatory sequence:**

*   V2-34 passes before V2-03 invites anyone.
*   V2-08, V2-09 and V2-12a (the per-use routing of section 3.2) are in production before V2-35, so no paid traffic runs without the governor.
*   V2-08, then V2-09, then V2-10.
*   C1 is resolved before V2-33.
*   C3 is answered and V2-06a is accepted before the public release (V2-33).
*   V2-22, then V2-23, then V2-24, then V2-25, then V2-26.

| Milestone | Content | Done when |
|---|---|---|
| M0. Unblock | Resolve C1, C2, C5 and C11; record the state of C6 and C10 (V2-02). Create staging (V2-05a) and run the restore drill (V2-05b). If the closed test applies, check the current email setup and the Groq Free capacity in staging (V2-34) and, if it passes, start the test with the AAB that C1 allows (V2-03). | C1 is known, the Play path is decided, and the restore drill passed (launch criterion 2). |
| M1. Foundations | The domain and Resend in staging, with the own-domain sender verified in production before the public release (it can run during the closed test); flags with the v0.1 contract test; the spend governor; the isolated classifier; the switch to Groq's paid plan. | Launch criteria 3, 4, 5 and 11 are met in staging, and in production for 11. |
| M3. Features | Tabs, avatar, voices, memory, greeting, games, savings mode, the crisis fallback on the phone. | Launch criterion 6. |
| M2. Tests (taken only when no P0 or P1 task is next, so usually after M3; section 7) | The model test and the 3D test (paid, each in its own cash month, section 6); ARCore and voice listening (free). | Each test has a recorded result against its exit criterion. |
| M4. Sala readiness | Conditions A to F, in parallel with M3, on the internal track. | The beta starts, or its blockers are recorded. |
| M5. Launch | The first publication to production. | Launch criteria 1 to 11. |
| M6. Opening decision | The beta runs; the opening criteria are checked. | The Sala opens or stays in beta. |

### 10. Marlix v0.2 development flow

This section extends decision D15 of the brief (one entry point for each session and a visible measure of progress). The goal is a process one person can sustain, where each day starts by reading one file and no context has to be rebuilt. The work follows a Kanban flow: a board shows the state of each task, an issue holds the detail of each task, and `status.md` gives a one-minute summary.

**Two phases.** Until the author approves the transition (C10) there is no board and there are no issues. `status.md` exists from V2-01, gated only on the approval of this design, and runs in the **interim mode** ([`docs/workflow.md`](../workflow.md#interim-mode-before-c10)): the V2-NN list of this design is the v0.2 backlog, its state lives in `status.md`, and V2 tasks are not copied into Notion, which keeps only work outside v0.2 (author decision). This means the `CLAUDE.md` rule "Notion is the only source of truth" does not apply to v0.2 work before C10; V2-01 records that exception in `CLAUDE.md`. The board, the issues and the rules that need them (10.1, 10.3 and the board columns of 10.6) come into force at C10.

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
| The old backlog | Notion, a read-only archive after the transition (10.9) | Never again |

The board is the live truth for the state of a task. `status.md` summarizes the board and never contradicts it: when they differ, the board wins and `status.md` is fixed.

**Documentation layout (author decision, following the structure of the EGM project).** The README stays short and points to the rest. Approved designs live in `docs/designs/`. Operating guides that are in force live in `docs/` (for example `docs/workflow.md`, `docs/development.md`, `docs/backups.md`). Diagrams sit next to the topic they explain. `status.md` holds progress and the next step; `CLAUDE.md` holds only the rules in force. Cleaning up the existing documentation to this layout is reviewed later, as its own task, not in V2-01.

#### 10.2 Rules kept, and rules changed

Kept as they are:

*   The four non-negotiable rules of `CONTRIBUTING.md`, and "no secrets or real user data in the repository".
*   `main` receives changes only through pull requests, and CI must pass (API, App and Database checks).
*   Branch names `<type>/<short-description>`, Conventional Commits in English, in present tense and with no trailing period, one change per commit.
*   The assistant never runs `git commit`, `git push` or a merge. The owner does, and says "ready" after the push and "merged" after the merge.
*   No Claude attribution in commits, pull requests or issues.
*   The Definition of Done, and the migration procedure (run the SQL in the Supabase SQL Editor before merging, then `docs/verify-migrations.sql`).
*   English in the repository; Spanish only for in-app copy.
*   Comments only where they explain a reason, a constraint, a safety rule or a link.
*   A didactic summary at the end of each task (what, how, why), given in chat.

Changed, with the reason. "In force from" says whether the change applies once this design is approved, or only at C10.

| # | Today | Proposed | Why | In force from |
|---|---|---|---|---|
| 1 | The issue title begins with the card ID (`S1-5 ...`), from Notion. | The title is a short imperative English sentence. The GitHub issue number is the ID. | The `S#-#` IDs belong to Notion. Two ID systems are two backlogs. | C10 |
| 2 | The issue is created only when the card is taken (`CLAUDE.md`). | The issue is the backlog entry. It is created when the task is defined, for the milestone `v0.2` and for open bugs, and it sits on the board. | After the transition there is no other place to hold the task. To avoid a long list, ideas for later stay as at most five one-line items in `status.md`, not as issues. | C10 |
| 3 | Cards are taken in strict ID order. | The next task is the top of Ready: tasks whose dependencies are all completed and verified, ordered by priority, then by number (10.3). | The launch has a critical path (C1, then the Play test). Strict numeric order would make unblocked work wait. | Design approval |
| 4 | The task template says "A backlog card turned into an issue" and asks for `SX-N`. | The template drops the card ID and gains: **Expected outcome**, **Version**, **Priority**, **Blocker record**, **Launch criterion served**, **Working method** (for UI tasks, section 4) and **Flag** where one applies. | These fields are what the Definition of Ready and `status.md` need. | C10 |
| 5 | The sprint security audit closes each sprint. | The same audit closes each milestone. | Milestones replace sprints as the unit. | Design approval |
| 6 | Nothing requires a flag. | A risky change, or a feature that must be on for some people only, ships behind a flag. | `main` deploys to production on its own. | Design approval |
| 7 | The Definition of Done does not mention cost or the summary. | Added: if the change adds or alters a model call, it is recorded in the spend ledger and the budget table is updated. Added: `status.md` is updated. | The USD 10 cap and the entry point depend on them. | Design approval (the template text changes at C10) |
| 8 | `CLAUDE.md` keeps long "session state" blocks. | `CLAUDE.md` keeps only rules and points to `status.md` for state. | The state blocks duplicate what `status.md` will hold and grow without limit. | Design approval, for v0.2 work (V2-01) |
| 9 | Notion is the only source of truth for the backlog (`CLAUDE.md`). | Before C10: the V2-NN list and `status.md` for v0.2; Notion for everything else. After C10: GitHub Issues, the board and `status.md`. | One list per kind of work, with no copy kept by hand. | Design approval (interim), C10 (final) |
| 10 | One card in progress at a time. | One main task is active at a time. A second task may stay paused in In Progress only while it is blocked (10.3). | A blocked task would otherwise stop all work. | Design approval |

#### 10.3 The Kanban board

Before C10: [Definition of Ready](../workflow.md#definition-of-ready), [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching) and [Post-merge checks](../workflow.md#post-merge-checks) in `docs/workflow.md`. The board below comes into force at C10.

**Columns and what must be true to move between them.** The columns are the starting point and can change after the first two weeks of use.

| Column | The task is here when | It moves on when |
|---|---|---|
| **Backlog** | The issue exists in the milestone `v0.2` (or is an open bug) but is not ready: criteria are missing, or a dependency is open. | It meets the Definition of Ready. |
| **Ready** | It meets the [Definition of Ready](../workflow.md#definition-of-ready). Hard dependencies filter the column: an item whose "Blocked by" is not completed and verified is not Ready. Within Ready the order is priority, then the lowest issue number. | It is the top item, no other main task is active, the issue is assigned, its branch exists, and the owner agrees. |
| **In Progress** | It is the main task being worked on, or the one paused task that is blocked. | Every acceptance criterion is ticked with evidence, the local checks are green, the owner has pushed the commit and the pull request is open with `Closes #N`. |
| **In Review** | The pull request is open and waits for CI and for the owner's merge. | CI is green and the owner merges. If CI fails or the owner asks for changes, the task goes back to In Progress. |
| **Done** | The pull request is merged, the issue is closed as completed, and the post-merge checks passed: CI of `main` is green, `GET /health` answers `ok` after a backend deploy, and `docs/verify-migrations.sql` returns only `ok` after a migration. | If a post-merge check fails, the issue is reopened and moves back to In Progress. It stops counting as done ([Post-merge checks](../workflow.md#post-merge-checks)). |

**Labels and milestone.**

*   Kept: `backend`, `app`, `data`, `design`, `docs`, `infra`, `security`, `accessibility`, `bug`, `blocker`, `help-resources`.
*   New: `P0` (blocks the launch or the critical path), `P1` (needed for v0.2), `P2` (useful if there is time), `blocked`, `launch` (serves a launch criterion), `sala` (a Sala-beta task; counted on its own line, not in the launch bar), and `experiment` (behind a flag with an exit criterion; not counted in any bar).
*   There is no `in-progress` label and no `later` label: the board column holds the state of a task, and ideas for later stay in `status.md`.
*   Milestone: `v0.2`. Milestones for later versions are created when they are needed.
*   Dependencies: a "Blocked by #N" line in the issue body. If the account supports GitHub's native "blocked by" relationship, that is used too (to verify).

**Board mechanics (all to verify when the board is created).**

*   The board is a GitHub Project owned by the author, private by default. The issues themselves stay public, so no issue may contain anything that should not be public.
*   Built-in project workflows move items automatically in some cases (for example, an item whose issue is closed or whose pull request is merged moves to Done). Which workflows exist must be checked in the project settings. Where one is missing, the move is manual.
*   The assistant moves cards with `gh project item-edit`. That needs the `project` scope on the GitHub CLI token, which the owner grants once with `gh auth refresh -s project`.

#### 10.4 The life of a task

Before C10: [The cycle before C10](../workflow.md#the-cycle-before-c10) in `docs/workflow.md`.

**A** is the assistant and **O** is the owner. This is the flow after C10.

1.  **Start the session (A).** Read `status.md` from the branch you are on, look at the board, run `git status` and `git log -5`, and check the CI of `main`. If they disagree, the board wins for the state of a task, and `status.md` is fixed. Before C10 there is no board: `status.md` is compared with `git log` and the merged pull requests.
2.  **Choose (A, O agrees).** Take the top of Ready. If a task is already active or paused, apply [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching). If Ready is empty, the next step is to bring the top Backlog item to Ready.
3.  **Take it (A).** Move the card to In Progress, assign the issue and re-read its criteria against reality. If the scope has to change, tell the owner before changing the issue and propose the update. Anything outside the scope becomes a new issue.
4.  **Branch (A).** `<type>/<short-description>` from an up-to-date `main`.
5.  **Work (A).** Small commits. For a database change, follow the migration procedure. For an endpoint change, update `docs/api-contract.md` in the same pull request. For a lasting decision, add it to `docs/decisions.md`. Put a risky change behind a flag. If the task blocks, apply [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching).
6.  **Verify (A).** Run `npm run typecheck`, `npm test` and `npm run build` in `api/`, and `flutter analyze` and `flutter test` in `app/`. Tick each acceptance criterion in the issue and write the evidence beside it: the test name, the command or a screenshot. Check screens on the emulator, and on the Galaxy S24 when a criterion says so (confirm with the owner that the phone is available). Re-read every comment and remove those that restate the code.
7.  **Prepare the summary (A).** Edit `status.md` as it should read once the pull request is merged: this task counted as done, the new progress bar, the next task as active, the new next step ([`status.md`](../workflow.md#statusmd)).
8.  **Hand over (A).** Give a summary, the exact `git add` paths (including `status.md`), a `git commit -m "..."` in Conventional Commits and the `git push -u origin <branch>`, plus the didactic summary.
9.  **Commit and push (O).** Run the commands and say "ready".
10. **Open the pull request (A).** `gh pr create` with an English body, `Closes #N`, the "How to test" steps and the Definition of Done checklist. Move the card to In Review.
11. **Watch CI (A).** `gh pr checks <n> --watch`. If a check fails, fix it on the same branch with a new commit, move the card back to In Progress, and the owner pushes. The CodeQL job stays non-required until it has run stably on several pull requests (S8-1).
12. **Merge (O).** Squash merge with the title `type: summary (#PR)` and a list of the branch commits, which the assistant provides. The owner deletes the remote branch and says "merged". `Closes #N` closes the issue.
13. **Close out (A).** Sync `main`, delete the local branch, check the [post-merge checks](../workflow.md#post-merge-checks) (CI of `main`, `GET /health` after a backend deploy, `docs/verify-migrations.sql` after a migration), and confirm the card is in Done. If the progress bar in `status.md` differs from the real count, fix it in the next pull request. Then go back to step 2.

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
| 2026-12-07 | Ready → In Progress | #230 is the top of Ready: no `P0` item is unblocked, because #227 is blocked by C6. The issue is assigned and the branch `feature/avatar-device-orientation` is created from `main`. | A |
| 2026-12-07 | In Progress | Tests first, with a fake sensor stream. Then the physics, then the widget. Commits: `test: cover avatar tilt, fall and recovery`, `feat: add spring physics for the avatar`, `feat: make the avatar react to device orientation`, `docs: record the avatar motion thresholds`. | A |
| 2026-12-08 | In Progress | Criteria 1 to 6 are ticked with the test names. For criterion 7 the owner connects the Galaxy S24; the assistant records the frame times and ticks it with the numbers. | A, O |
| 2026-12-08 | In Progress | `status.md` is edited as if the pull request were merged: 9 of 28 tasks, the next task active, a new next step. The assistant gives the `git add` paths, the commit message and `git push -u origin feature/avatar-device-orientation`. The owner runs them and says "ready". | A, O |
| 2026-12-08 | In Progress → In Review | `gh pr create` opens PR #233 with `Closes #230`. | A |
| 2026-12-08 | In Review | The API, App, Database and CodeQL checks run. All pass. | A |
| 2026-12-09 | In Review → Done | The owner squash-merges with the title `feat: make the avatar react to device orientation (#233)` and deletes the remote branch. The issue closes by itself. The card moves to Done. | O |
| 2026-12-09 | Done | The assistant syncs `main`, deletes the local branch, sees the CI of `main` green, and confirms that the bar in `status.md` matches the real count (9 of 28). | A |

**Pull request body for the example:**

```markdown
Closes #230

## Summary
The avatar sways with the phone's tilt, falls when the phone is inverted and
recovers when it is upright again. With reduced motion on it only eases between
poses. If there is no accelerometer it behaves as before.

## How to test
1. `flutter analyze` and `flutter test` in app/.
2. Emulator, Virtual sensors: tilt, invert, straighten.
3. Galaxy S24, profile mode: no frame over 16 ms in 30 seconds (numbers in the issue).

## Definition of Done
(the checklist from the pull request template, plus: no model call changed,
and status.md updated)
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

Because the blocker will not clear in the current session and the work for #231 touches other files, the assistant may take #231 as the main task (rules 1 to 5 of [Blocked tasks and switching](../workflow.md#blocked-tasks-and-switching)). #230 stays paused in In Progress. When the phone is connected, #230 is picked up before the next Ready item of equal or lower priority.

#### 10.6 `status.md`: the entry point of every session

Before C10: [`status.md`](../workflow.md#statusmd) in `docs/workflow.md` holds the rules, the interim mode, the event table, the progress bars, "Automation" and the interim template. What stays here is the record of the move and what waits for C10.

**What moves where.** V2-01 copies into `docs/workflow.md` the rules in force before C10, under these headings:

*   **The cycle before C10:** the "Cycle before C10". Its references to steps of 10.4 become links to section 10.4 of `docs/designs/marlix-v0-2.md`.
*   **Definition of Ready:** 10.3's Definition of Ready, verbatim.
*   **Blocked tasks and switching:** from 10.3, "One main task at a time"; "When a task is blocked", from its first sentence to the clearing sentence, with the blocker record verbatim; "When it is right to take another task", with its five conditions and the two paragraphs after them; and "A pull request waiting for review".
*   **Post-merge checks:** the post-merge checks of 10.3's Done row.
*   **A clear task:** 10.5's fields. The worked example stays in this design, and this heading links to it.
*   **`status.md`:** from 10.6, the rules, the interim mode, "The update is written as if the pull request were merged", "Publishing with a protected `main`", the progress bars, "Automation", the interim template and the event table with three columns (Event, Interim before C10, `status.md`). In the interim template, "the template above" becomes a link to the 10.6 template in this design.
*   **References in all copied text:** "this design" and "the Detailed Implementation Plan" become links to `docs/designs/marlix-v0-2.md`; a reference to moved text (10.3's Definition of Ready, blocker record, switching rules and post-merge checks; the 10.6 rules and table) becomes a link to the matching `docs/workflow.md` heading; any other section reference (10.3's columns, 10.4, 10.9, section 4, the Work order) becomes a link to that section of the design; "above" and "below" are replaced by the link.

This line is the first line under the "Definition of Ready" heading and under the "Blocked tasks and switching" heading: "Before C10, 'issue' means the V2-NN entry; 'Backlog' means a V2-NN task not yet in 'Next up'; 'Ready' means 'Next up'; 'In Progress' means the active or paused task in `status.md`; 'In Review' means an open pull request; 'Blocked by' means the task's Depends on; a reopened task stops counting and becomes the active task again; the blocker record and its clearing date go in `status.md`'s Blocked section; there is no label."

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

**Template with a complete example (after C10).** The numbers are illustrative until the issues exist.

```markdown
# marlix status

Updated: 2026-12-08 · Board: <URL of the GitHub Projects board> · Milestone: M1 Foundations (2026-12-01 to 2026-12-14)

## Progress
v0.2 launch progress [██░░░░░░░░] 28% (8 of 28 launch tasks complete)
Sala beta: 2 of 6 tasks complete (does not block the launch)
Scope: 28 tasks; approved on 2026-12-01 at 27. Changes: +#240 greeting by local
time (2026-12-05), -#237 voice comparison (moved to experiments, 2026-12-06),
+#241 reminder migration test matrix (2026-12-07).
Launch criteria met: 2 of 11. Finished tasks are not the same as ready to publish.

## Active task
#230 Make the avatar react to device orientation · P1 · In Progress
Branch: feature/avatar-device-orientation
Criteria 1 to 6 are ticked. Criterion 7 (no frame over 16 ms on the Galaxy S24) is still to measure.

## Review
Nothing waiting.

## Next up (Ready, in order)
1. #231 Add the palette, pattern and accessory picker · P1
2. #234 Add the «Recordá esto» button and notice · P1
3. #240 Add the greeting by local time · P1

## Blocked
- #227 Isolate the classifier in its own Groq organization · P0 · paused in In Progress
  Cause: it is unknown whether a second Groq organization has its own spend limit (C6 (d)).
  Depends on: the owner reading Groq's billing pages.
  Action to unblock: open the Groq console, Settings, Billing; note whether a new
  organization gets its own spend limit and ZDR switch; tell the assistant.
  Recorded on: 2026-12-06

## Launch criteria still pending (9 of 11)
- [ ] 1 Closed test: day 9 of 14, enough testers opted in; then production access
- [ ] 3 Spend governor in production
- [ ] 4 Classifier quota isolated · crisis:eval green
- [ ] 6 Launch features done (avatar frames, voices, memory, greeting, games)
- [ ] 7 Production build without the Sala; nothing advertises it
- [ ] 8 Privacy policy, data safety and health declaration updated
- [ ] 9 v0.1 APKs still work against the new backend
- [ ] 10 Checks green; release build tested on the Galaxy S24, the low-end AVD and internal app sharing
- [ ] 11 Groq paid plan with ZDR and the provider spend limit
Met: 2 restore drill · 5 own-domain email

## Decisions waiting on the owner
- C8 Confirm the host of the Sala (the beta waits until there is one)
- Q15 Sala moderation coverage · Q16 Sala message that expresses distress

## Next step
On the Galaxy S24 (ask first that it is free): run the app in profile mode,
tilt, invert and straighten the phone for 30 seconds, and record the frame times for
criterion 7 of #230. Then tick it, check that this file reads 9 of 28, and hand the
commit commands to the owner.

## Later
- Lower the Groq spend limit on <date> and restore it on <date> (usage months around the domain renewal); confirm the renewal price
- Compare Supertonic with Kokoro or Piper by blind listening
- 3D object feasibility test (cap USD 3 before tax, in its own month)
```

#### 10.7 Release

*   A release is a version bump in `app/pubspec.yaml` (the `versionCode` always grows), an entry in `CHANGELOG.md`, a git tag, and the artifacts: the signed APK on GitHub Releases and the production AAB for Play, both signed with the S7-15 key (the signed release APK card). While the Sala beta runs, the same commit also produces the Sala AAB for the internal track, with a higher versionCode ("Effect on the launch").
*   The first Play publication goes to production once the launch criteria are met. Later updates roll out at 10%, 50% and 100% and can be paused.
*   Going back means switching a flag off or publishing a corrected version; Play does not allow a lower version.

#### 10.8 Closing a milestone

At the end of each milestone: the security audit already used at sprint close (secrets in the history, ignored files, RLS and grants, endpoints, dependencies, repository protections), plus the new surfaces of v0.2 (the spend ledger, the Sala tables including `room_help_requests` and, when it exists, `room_bans`, the flags tables, and the crisis asset in the app). Each finding becomes an issue in the next milestone.

#### 10.9 Moving the backlog from Notion to GitHub Issues and a Projects board (C10, pending the author's approval)

**Nothing in this subsection is done before the author approves C10.** Until then, Notion stays the backlog for work outside v0.2, the V2-NN list and `status.md` hold v0.2 ([Interim mode](../workflow.md#interim-mode-before-c10)), and no board or issue is created. The only `CLAUDE.md` change before C10 is the v0.2 exception that V2-01 records. Approving means approving steps T1 to T8 below, in order.

| Step | What happens | Who |
|---|---|---|
| T0. Decision | The author approves this plan. | Owner |
| T1. Freeze | Stop creating or editing cards in Notion. Export the backlog (Markdown and CSV) to a private folder **outside the repository**, because cards may hold personal details. | Owner |
| T2. Inventory | List every card that is not Done. Mark each as *migrate*, *already covered by this design* or *discard*, with a one-line reason. Done cards stay in Notion; their history is already in `docs/decisions.md`, `CHANGELOG.md` and the closed issues. | Assistant prepares, owner decides |
| T3. Map | For each card to migrate, write the issue text in English with the fields of 10.5: expected outcome, criteria, how to verify, dependencies, version, priority and labels. The map stays outside the repository until the issues exist. | Assistant |
| T4. Create the board | Create the GitHub Project (private), with the columns Backlog, Ready, In Progress, In Review and Done. Check which built-in workflows exist. The owner grants the CLI the `project` scope with `gh auth refresh -s project`. Create the labels `P0`, `P1`, `P2`, `blocked`, `launch`, `sala` and `experiment`. | Owner grants access, assistant sets up |
| T5. Create the issues | Create the issues in batches of at most ten, each batch approved by the owner. An issue may cite the old card ID (for example "migrated from S7-9") but never a Notion URL, because the repository is public. Items that meet the Definition of Ready go to Ready; the rest go to Backlog. Tasks already completed under the interim bar are created as issues already closed as completed, with their `V2-NN` ID in the body, so the total and the done count carry over. | Assistant, owner approves each batch |
| T6. Verify completeness | (a) *Count:* open cards, minus discarded, equals issues created, and every discarded card has its reason; `gh issue list --milestone v0.2` returns the expected count. (b) *Metadata:* every issue has a priority and the milestone, and the owner checks each `P0` issue against its card. (c) *Bars:* the totals equal the interim totals plus the scope changes recorded since, and the done counts equal the interim counts. | Assistant, owner signs off |
| T7. Pilot | Run one real task through the cycle in 10.4, including the board moves and the `status.md` edit. If any step is awkward, fix the process before continuing. | Both |
| T8. Switch | Put a banner on the Notion backlog ("Archived: the backlog lives in GitHub Issues and the board") and make it read-only. Replace the Notion project home with a link to `status.md`. **Only now** replace the `CLAUDE.md` rule that names Notion as the source of truth (until now it had only the v0.2 exception), remove its session-state blocks, and update the issue template, the pull request template, `CONTRIBUTING.md` and `docs/workflow.md` in a pull request. | Assistant proposes, owner approves |

*   **Rollback:** Notion is not deleted for at least 30 days. If T6 or T7 fails, Notion stays the backlog until the gap is fixed.
*   **Why the `CLAUDE.md` rule changes last:** that rule tells the assistant where to look. Changing it before the issues are complete and one task has run through the new cycle would leave the assistant with no reliable backlog.
*   **Alternatives to this migration** (documented in "Alternatives Considered"): keep Notion as the backlog and use GitHub only for code traceability (today's flow); keep a Notion board and synchronize it with issues by hand; or run the Kanban flow with labels on issues and no Projects board.

--------------------------------------------------------------------------------

## Alternatives Considered

These are the options weighed in the brainstorm and in this design, with the reason each was or was not chosen. The outcome labels mean: **Rejected by author** (the author decided it), **Replaced by the author's decision** (the brief proposed it and the author changed it later), **Rejected in the brief** (reasoned in the brainstorm, whose brief the author accepted as the base of this design), **Postponed** (not chosen now, with the condition that would reopen it), and **Pending C10** (waits for the author's approval of the Notion transition). Nothing here is attributed to anyone else.

### Product and scope

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| AI characters as the way to practice social skills (brief D12) | Needs no moderation and no Play user-content declaration; works on day one. | People rehearse against a script, not with other people; it does not give the shared space the author wants. | **Replaced by the author's decision:** the Sala de Marlix. |
| Private rooms of 4 to 6 people with scheduled, hosted sessions (brief D12) | Small groups are easier to moderate. | A host is needed for every session, fewer chances to meet people, and the author wants one shared channel. | **Replaced by the author's decision.** |
| Open the Sala to everyone with no beta | Reaches all users at once. | One host cannot cover every hour, and harm stays visible until someone reviews it. | **Rejected by author** for the first version: beta first, opening once the criteria are met. |
| Wait for the Sala before launching (Q14, option C) | The whole promise exists on day one. | The date depends on a host and on moderation, and nothing else ships meanwhile. | **Rejected by author:** the public opening does not block the launch. |
| Always ship the Sala hidden (Q14, option A) or always ship the beta inside the app (option B) | Each is simple to state. | A hides the feature even if it is ready; B requires the controls from day one. | **Adopted together, conditionally:** B if conditions A to F are met at release time, otherwise A. |
| A staged rollout at 10%, 50% and 100% for the first publication | Limits the number of people a serious bug reaches. | The author prefers publishing to production once the criteria are met. | **Rejected by author** for the first publication; kept for later updates. An install of the exact production AAB through internal app sharing before production covers part of the risk. |
| Keep the reminder-time picker | No migration is needed. | The author wants a fixed 19:00 reminder and a greeting that adapts to the local time. | **Rejected by author.** |
| The greeting as an automatic notification instead of a greeting when the app opens | Reaches the person outside the app. | It needs the notification permission on Android 13 and later, and inexact alarms arrive late (a 2-minute delay was measured on the Galaxy S24 in S7-11). | **Not chosen for the greeting.** The in-app greeting needs no permission. The daily reminder, which is a notification, stays at 19:00. |
| Diagnosis, interpretation of symptoms, severity grading, or inferring pain from the camera or voice | Would let Marlix respond to the person's physical state. | Software that diagnoses is medical software: it needs a clinical study, professional supervision and health registration. | **Out of scope** (see Non-Goals). |

### Models, cost and privacy

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| `deepseek-v4-pro` for everyday chat | Probably the most capable model on the list. | About USD 7.4 a month with caching and about USD 31 without it in the expected scenario before tax, against a chat sub-cap of USD 6.00 with VAT. | **Rejected in the brief** for everyday chat; kept as a bounded test. |
| `deepseek-flash` with real user data | Same list price as `gpt-oss-120b` off-peak and a very low cached-input price. | Its terms say data is stored in the People's Republic of China, give no retention period for API inputs and offer no ZDR or data processing agreement. The peak price (19:00 to 22:00 in Costa Rica) doubles the rates. | **Postponed:** synthetic data only until the privacy terms are resolved. |
| Groq's free plan for the chat | No cost. | Its daily capacity for chat was estimated in the brief at about 54 turns, which is not measured and is far below what 50 people need. | **Replaced by the author's decision:** used during the closed test if V2-34 shows it is enough; the paid plan after V2-35. |
| Estimating the cost of uncertain calls (timeouts, some errors, interrupted streams) and releasing the reservation | Frees budget sooner. | An estimate can be too low, and the cap would then depend on a test passing. | **Rejected by author:** a reservation shrinks only on evidence of the real cost or of non-billing. |
| A provider-side spending limit as the only control | Simple; the provider stops the spend. | It exists on Groq's paid plan, but it is organization-wide, has no per-use control, reacts with 10 to 15 minutes of lag, and blocks the crisis classifier with everything else. | **Rejected as the only control.** Set as a second barrier above the governor (V2-35). |
| Prorating the domain over 12 months, or an annual cap | A `.com` fits on paper. | The domain is paid at once; the purchase and renewal months would break the monthly cap. | **Rejected by author:** cash per calendar month, and a `.fyi` domain. |
| One crisis classifier instance shared by every caller, and a wrapper inside `createLlmProvider` | Less wiring. | Sala calls would be charged to the private chat's pool, and transcriptions would bypass the governor. | **Rejected:** one provider instance per use, and governor decorators that include the transcriber. |
| A classifier pool that fails closed as soon as it is used up | Simple and predictable. | A busy month would turn ambiguous messages into crisis responses while money is still left elsewhere. | **Rejected by author:** one-way borrowing from chat, memory, Whisper and half of the margin for the private chat's pool; the Sala's pool does not borrow during the beta. |
| Prices and reconciliations as database tables (`llm_prices`, `spend_reconciliations`) | A price change needs no deploy. | Two more tables to secure and test for data that changes a few times a year. | **Rejected by author:** `api/config/llm-prices.json` reviewed in pull requests, and reconciliations recorded in `docs/decisions.md`. |
| One classifier pool shared by the private chat and the Sala | Simpler accounting. | A busy Sala could use up the reserve that the private chat's safety depends on. | **Rejected by author.** |
| One shared pool plus a rule that stops Sala calls before they reach the private chat's balance | One number to configure. | The rule is code that must be right at every moment, and it is harder to audit than two counters. | **Not selected:** the author chose separate pools. |
| Two separate classifier pools: USD 0.45 for the private chat and USD 0.15 for the Sala | Easy to audit, and a Sala call cannot reach the private chat's safety balance. | Two numbers to configure and to reconcile. | **Selected by author.** |
| Memory extraction after every turn | The fastest memories. | About 6,000 extra model calls a month in the expected scenario, and it would share quota with the classifier. | **Rejected in the brief.** |
| The classifier and the extractor on the same model and key (today) | One model to configure. | A quota used up by extraction makes the classifier fail closed. | **Rejected in the brief** (D6, Q12). |
| «Recordá esto» refuses, or queues, when its budget is gone | No unreviewed text is saved. | The feature disappears when it is most used, or a requested memory appears days late. | **Not chosen:** the verbatim fallback of section 3.4 is the only behavior built. |

### Hosting, data and email

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| OVHcloud VPS-1 as the default host | The list price is USD 4.54; the service never sleeps. | About USD 5.13 with the assumed VAT, which leaves too little for the sub-caps and breaks the cap in the cash month of the domain charge; it needs server administration of about one hour a week; price, city and purchase from Costa Rica are unconfirmed. | **Postponed** (C4), with no budget in this design. |
| A `.link` domain | Cheaper than `.com` at purchase and renewal. | USD 8.14 with VAT leaves too little for chat in the usage months around the renewal. | **Rejected by author:** `.fyi`. |
| Supabase Pro before opening (decision S7-5) | Backups and no pausing. | USD 25 a month. | **Rejected by author:** replaced by a restore drill against a real project. |
| A second Render service kept awake for staging | Staging is always ready. | It would exceed the free plan's 750 hours a month. | **Rejected:** staging sleeps. |
| Mailflare for sending the codes | One suite for domains and mailboxes. | It still sends through Resend, SES or Cloudflare, so it does not replace the SMTP, and it is an AGPL suite to operate. | **Rejected in the brief.** |
| Amazon SES | USD 0.10 per 1,000 emails à la carte. | An AWS account, IAM and leaving the sandbox (not confirmed). | **Not chosen;** the second option after Resend. |
| Keep the current SMTP | Nothing to change. | Its provider and sender are undocumented (C5), and a Gmail sender cannot use an own domain. | **Used during the closed test if V2-34 passes;** not an option for the public release (author decision). |

### Avatar, 3D and voice

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| Meta Motivo | A published research model. | It controls a simulated humanoid, takes no images, and is CC BY-NC 4.0. | **Rejected in the brief.** |
| Locate 3D | A published research model. | It finds objects in RGB-D scenes with camera poses, does not reconstruct them, is CC BY-NC, and its repository is archived. | **Rejected in the brief.** |
| Hunyuan3D | Strong image-to-3D results. | A third-party summary says its license excludes the EU, the UK and South Korea, and full texturing needs a lot of GPU memory. The primary license text was not read. | **Rejected in the brief** (to verify against the license). |
| A 3D avatar from a photo, or room reconstruction, in the launch | The most distinctive experience. | It needs a GPU or a paid API per capture, animation for arbitrary objects is unsolved, and it threatens the schedule and the budget. | **Postponed:** feasibility tests with exit criteria (section 7). |
| Cloud voice APIs (Google Cloud TTS, ElevenLabs, DeepSeek text to speech) | More natural voices. | No strict spending cap, added latency, and one more processor of the person's text. | **Postponed.** |
| Another on-device voice at launch (Kokoro or Piper) | A maintained alternative to an archived project. | Kokoro in Spanish is unconfirmed, and espeak-ng is GPLv3. | **Not chosen yet:** blind listening test (section 7). |

### The Sala

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| Clients write straight into the messages table | Less backend code. | The message reaches the channel before the crisis filter runs, and RLS cannot call the classifier. | **Rejected:** an endpoint filters first, then writes. |
| Supabase Realtime for the beta | Messages appear at once, with no polling. | Removals arrive as UPDATEs that a filtered subscriber may never receive, DELETE events skip RLS, and blocks and reporter-only hides need policies tested under Realtime. | **Postponed by author:** polling every 3 seconds for the beta; Realtime is reconsidered before opening. |
| An exported PNG of the avatar in Storage for the profile | Any client can show it. | An upload path, a Storage bucket and images to moderate. | **Rejected by author:** the profile stores the look's choice IDs and each client draws the avatar. |
| A ban list (`room_bans`) from the start of the beta | Stops an expelled person from returning with the same email. | It stores personal data (a keyed hash of the email) when the invitation already controls who enters. | **Postponed by author** to the Open stage; in the beta, access is revoked through the invitation. |
| Delaying moderation actions to hide when a report arrived | Makes the reporter harder to guess in a small group. | Harmful content stays visible longer. | **Rejected by author:** moderation is immediate; the report time is never shown and the reporter's notice comes in a daily batch. |
| Telling the host about every distress message | The host can reach out quickly. | A clear risk signal would leave the backend without the person's consent (`CONTRIBUTING.md`, rule 4). | **Rejected by author:** the host is told only after the person says yes. |
| Every moderator sees who reported | The simplest report view. | It exposes the reporter. | **Rejected:** moderators see the reporter only as far as a follow-up question needs. |
| Hide a message for the whole room after two reports (brief D12) | A fast response when no moderator is present. | Two people can remove any message from everyone's view by agreeing, and the author is silenced with no review. | **Replaced by the author's decision:** a report hides the message for the reporter only; two independent reports raise the priority; a moderator decides. |
| Direct messages from the start | Closer to what Discord offers. | Each message adds a contact surface for harassment before the channel is proven. | **Rejected by author** for v0.2: one-to-one chats come later, and the plan is to require both people to accept first. |

### Process

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| Keep Notion as the backlog (today's flow) | Nothing to migrate. | Two ID systems and a source of truth outside the repository. | **Pending C10.** |
| Keep a Notion board and sync it with issues by hand | Keeps the familiar view. | Two backlogs that drift apart. | **Pending C10.** |
| Mirror every V2 task as a Notion card until C10 | Notion stays the only source of truth. | Two lists kept in step by hand. | **Rejected by author:** before C10, v0.2 lives in the V2-NN list and `status.md`. |
| Kanban with labels on issues and no Projects board | No new tool; all in the repository. | No board view, and every move is a label edit. | **Pending C10.** |
| Take cards in strict ID order | Predictable. | It makes unblocked work wait while the critical path is blocked. | **Replaced:** priority and dependencies. |
| Several main tasks at once | Fewer idle periods. | Context switching for one person, and more half-finished work. | **Rejected by author:** one main task, with one paused blocked task allowed. |
| Update `status.md` in a separate pull request after each merge | The file always shows what merged. | One extra pull request per task. | **Rejected:** the pull request carries the state it will have after the merge. |
| A bot that commits `status.md` to `main` | No manual edits. | It needs a bypass of "Protect main", so not every change passes through a pull request. | **Rejected.** |
| A scheduled workflow that opens a daily status pull request | Automatic. | A pull request to review each day with no new information. | **Rejected.** |
| `status.md` ignored by git, like `CLAUDE.md` | No privacy risk. | It is not versioned and not visible on GitHub; the author wants a persistent file at the root of the repository. | **Rejected by author.** |
| Progress by story points, by pull requests or by launch criteria | More detailed. | More to maintain, and a task that needs three pull requests would count three times. | **Rejected:** the unit is the issue, and launch readiness is shown apart. |

--------------------------------------------------------------------------------

## Risks & Mitigations

| Risk | Failure mode | Mitigation | Section |
|---|---|---|---|
| Harm in the Sala | Harassment or a threat stays visible, or a person in distress is exposed. | Private beta by invitation with a host; blocking and reporting; immediate moderation; distress never penalized and never sent to the host without consent; opening criteria. | Sala scope, 3.6 |
| Budget overrun | The domain charge, a paid test's smallest purchase, a Groq invoice that lands in the next month, or an estimate error pushes a cash month over USD 10. | Cash counted by the month the card is charged; both usage months around a fixed charge lowered; a mixed Groq billing timing blocks the paid switch until the budget is redesigned (C6 (f)); reservations held until evidence; the margin; the provider spend limit as a second barrier. | 3.2, 6 |
| Spend block by the provider | Groq's organization-wide limit blocks every key, including the classifier's. | The limit sits above the governor's sub-caps; `spend_blocked` handling; layer 1 on the server and on the phone; `/health/safety`. | 3.3, V2-35 |
| Provider failure or backend unreachable | Chat, classifier or Whisper fail; the phone has no network to the API. | Layer 1 answers first; the classifier fails closed; the phone's copy of layer 1 and the cached crisis response; the help lines work offline. | 3.3, V2-37 |
| Play policy | The Sala or a declaration is rejected in review. | The production build leaves the Sala out; the beta runs on an internal track; Q18 is read before opening. | Effect on the launch, Q18 |
| The closed test slips | Testers drop out or the 14 days restart. | Recruit more than 12; run it on the v0.1 AAB while v0.2 is built; invite in batches. | 5, V2-03, V2-34 |
| A single operator | Illness or absence stops moderation, releases or reconciliation. | The Sala does not block the launch; flags switch features off without a deploy; `status.md` lets work resume in one minute. | 10.6 |

## Non-Functional Requirements

The security, privacy, cost and rollout requirements are in the Technical Plan: the four rules of `CONTRIBUTING.md` (section 1), the spend cap and the hold-until-evidence rule (section 3.2), the behavior when a provider fails and what always works without money (section 3.3), the Sala's privacy, reporter protection and retention (section 3.6), the Play declarations (section 5), and flags, environments and rollout (sections 1, 2, 5 and 8). This design adds none beyond them.

--------------------------------------------------------------------------------

## Additional Resources

*   The author's local brainstorm brief (in Spanish, not in the repository). The table "What the author's decisions replace from the brief" makes this design self-contained.
*   Project documents read for this design: `CONTRIBUTING.md`, `docs/decisions.md` (S7-5, S7-9, S7-15, S8-1, S8-2), `docs/crisis-protocol.md`, `docs/memory.md`, `docs/avatar.md`, `docs/backups.md`, `docs/monitoring.md`, `docs/development.md`, `docs/play-store/listing.md`, `render.yaml` and the workflows in `.github/workflows/`.
*   Official pages read on 2026-11-19: Groq (`console.groq.com/docs/rate-limits`, `/docs/models`, `/docs/your-data`), DeepSeek (`api-docs.deepseek.com`, the Open Platform Terms and the privacy policy on `cdn.deepseek.com`), OVHcloud (`us.ovhcloud.com/vps/`), Resend (pricing and SMTP documentation), AWS (SES pricing), Supabase (custom SMTP, pricing, Realtime limits), Cloudflare (Registrar and Email Routing), Google Play Help (closed-test requirement, testing tracks and the user-generated content policy), Groq spend limits, prompt caching and speech-to-text, the ARCore Raw Depth documentation, and the Meta Motivo, Locate 3D and Mailflare repositories. Prices and limits are read at that date and must be re-checked before they are relied on.
*   The Muse design article (`muse.ai/blog/how-we-designed-muse`), used for its product principles and not for a visual style.

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
*   **DeepSeek with real data**, if its API terms offer a retention limit and zero data retention or a data processing agreement.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

The work is split into tasks named `V2-NN`. They are planned items, not GitHub issues. Before C10 this list is the v0.2 backlog and `status.md` holds its state ([Interim mode](../workflow.md#interim-mode-before-c10)); at C10 each task becomes an issue with the fields of section 10.5. The order follows the milestones of section 9. A task is **gated** when it cannot be closed until a stated condition is resolved. A gate that also prevents starting says so in the task (V2-04). No task starts until the owner gives the final approval of this design (V2-01).

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
*   **Notes:** budget figures and context that are not a gate go in a **Notes** line.

### Work order

The **List** column classifies every task once: **Launch** (blocks the v0.2 launch and counts in the launch bar), **Sala** (blocks only the Sala beta and counts in its own line), **Experiment** (an experiment or optional work; counts in neither), and **Process** (V2-04, which waits for C10). No Launch task depends on a Sala or Experiment task. The Order column is recommended; "Depends on" and "Gate" are mandatory (section 9).

| Order | ID | Task | List | Milestone | Priority | Depends on | Gate |
|---|---|---|---|---|---|---|---|
| 1 | V2-01 | Create `status.md` and `docs/workflow.md` | Launch | M0 | P0 | The owner's final approval (recorded as `Status: Approved`) | none |
| 2 | V2-02 | Verify the external conditions | Launch | M0 | P0 | none | owner: C1, C2, C5, C6, C11 |
| 3 | V2-05a | Staging environment | Launch | M0 | P0 | none | none |
| 4 | V2-05b | Restore drill against staging | Launch | M0 | P0 | V2-05a | none |
| 5 | V2-34 | Check the current email setup and Groq Free capacity in staging | Launch | M0 | P0 | V2-02, V2-05a | C1, C5 |
| 6 | V2-03 | Run the Play closed test, if it applies | Launch | M0 | P0 | V2-02, V2-34 | C1 |
| 7 | V2-04 | Move the backlog to GitHub Issues and a board | Process | M0 | P1 | V2-01 | C10 |
| 8 | V2-06a | Domain and own-domain email | Launch | M1 | P0 | V2-05a | C3, C5 |
| 9 | V2-07 | Feature flags and the v0.1 contract test | Launch | M1 | P0 | V2-05a | none |
| 10 | V2-08 | Spend ledger, reservations and per-use routing | Launch | M1 | P0 | V2-05a | none |
| 11 | V2-09 | Stream usage, aborts and graceful shutdown | Launch | M1 | P0 | V2-08 | none |
| 12 | V2-12a | Separate models for the classifier and the extractor | Launch | M1 | P0 | V2-08 | Q12 |
| 13 | V2-35 | Switch Groq to the paid plan with ZDR and a spend limit | Launch | M1 | P0 | V2-08, V2-09, V2-12a | owner's go-ahead to pay; C6 (f) |
| 14 | V2-10 | Evidence rules and reconciliation | Launch | M1 | P0 | V2-08, V2-09 | C6 (a, b, e); Q11 |
| 15 | V2-12b | The classifier in its own Groq organization | Launch | M1 | P0 | V2-12a, V2-35 | C6 (d) |
| 16 | V2-11 | Savings mode and daily-limit step-down | Launch | M1 | P0 | V2-07, V2-08, V2-12a | Q12 |
| 17 | V2-37 | Crisis layer 1 on the phone | Launch | M3 | P0 | none | none |
| 18 | V2-15 | Navigation, theme, first use and accessibility | Launch | M3 | P1 | none | none |
| 19 | V2-16 | Reduced-motion setting | Launch | M3 | P1 | none | none |
| 20 | V2-17 | Avatar reacts to device orientation | Launch | M3 | P1 | V2-16 | none |
| 21 | V2-18 | Avatar expressions | Launch | M3 | P1 | V2-16, V2-03 | none |
| 22 | V2-19 | Appearance picker | Launch | M3 | P1 | V2-15 | none |
| 23 | V2-20 | Voices with samples and the microphone permission | Launch | M3 | P1 | V2-15, V2-08 | none |
| 24 | V2-13 | «Recordá esto» and 10-minute extraction | Launch | M3 | P1 | V2-08, V2-12a | none |
| 25 | V2-14 | Greeting by local time and reminder migration | Launch | M3 | P1 | none | none |
| 26 | V2-21 | Games | Launch | M3 | P1 | V2-15 | none |
| 27 | V2-31 | Release preparation | Launch | M5 | P0 | V2-06a, V2-11, V2-13 to V2-21, V2-37 | Q13 |
| 28 | V2-32 | Compatibility test with v0.1 clients | Launch | M5 | P0 | V2-07, V2-11, V2-13 | none |
| 29 | V2-33 | Release checks and publication | Launch | M5 | P0 | V2-03, V2-05b, V2-10, V2-12b, V2-31, V2-32, V2-35 | C1; C3 (through V2-06a) |
| 30 | V2-22 | Sala data model | Sala | M4 | P1 | V2-05a, V2-07 | none |
| 31 | V2-23 | Sala blocking, reporting and moderation | Sala | M4 | P1 | V2-22 | none |
| 32 | V2-24 | Sala message path | Sala | M4 | P1 | V2-23, V2-08, V2-12a | Q15; Q16 |
| 33 | V2-25 | Sala screens | Sala | M4 | P1 | V2-24, V2-15, V2-19 | none |
| 34 | V2-36 | Moderator view and notices | Sala | M4 | P1 | V2-23, V2-25 | Q19 |
| 35 | V2-26 | Sala safety and privacy tests | Sala | M4 | P1 | V2-24, V2-25, V2-36 | C8; Q18; Q19 |
| 36 | V2-06b | Stable hostname `api.<domain>` | Experiment | M1 | P2 | V2-06a | C9 |
| 37 | V2-28 | Model comparison harness (DeepSeek) | Experiment | M2 | P2 | none | owner supplies a test key; C12 |
| 38 | V2-29 | Feasibility spikes (ARCore planes, object to 3D, voices) | Experiment | M2 | P2 | none | C12 (for spike b) |
| 39 | V2-27 | Medical-urgency layer | Experiment | M4 | P2 | V2-07 | C7 |
| 40 | V2-30 | Photo-to-skin experiment | Experiment | M4 | P2 | V2-19, V2-29 | experiment result |

Counts: 28 Launch tasks, 6 Sala tasks, 5 Experiment tasks and 1 Process task. Experiment tasks are taken as section 7 says: before C10, only when "Next up" lists no P0 or P1 task.

**What each gate means.**

*   **C10** (the owner's approval of the Notion transition) blocks V2-04 only. Until then, the interim mode applies ([Interim mode](../workflow.md#interim-mode-before-c10)).
*   **C6** blocks only:
    *   V2-10: items (a) the reconciliation source and (b) when holds of 4xx, 429 and aborted calls are released. Item (e) is recorded in V2-10. With Q11, (a) and (b) set the final sub-caps.
    *   V2-12b: item (d), whether a second organization has its own limit.
    *   V2-35: item (f), when Groq charges the card.
*   Not gated by C6: the ledger, the reservations, the use tags, the Whisper decorator and the pool tests.
*   Launch criteria 3 and 4 stay open until V2-10 and V2-12b close.
*   "Export: none; fallback: invoice" is a valid C6 answer.
*   **Q15 and Q16** stay open. They block only V2-24, and V2-24 is built around one replaceable policy so the rest of the Sala can proceed.
*   **C7** (a health professional's review) blocks V2-27 from being switched on. The code can be written and left off.
*   **C1** decides whether V2-34 and V2-03 apply and which AAB the closed test uses.
*   V2-33 cannot publish before C1 is resolved.
*   **C3** (the final domain price at checkout) must be answered before V2-06a buys the domain, and so before V2-33.
*   **Q11** (the measured cost per turn) gates V2-10, which sets the final sub-caps; **Q12** gates V2-12a and V2-11; **Q13** gates V2-31.
*   **C6 (c)** gates nothing: without a usage chunk, a stream stays held (V2-09, criterion 3).
*   **V2-34** is a check and not a question: if the email check fails, the email work of V2-06a is finished before any tester is invited; if Groq Free is not enough, V2-35 and its prerequisites come first, or the closed test runs with a lower daily limit per person.

### Tasks

Every task uses the same fields, in this order: **Depends on** (task IDs), **Gate** (open conditions and at most one rule; "none" if there is none), **Working method** (UI tasks only, section 4), **Files** (one sub-bullet per file, or per group of files that receive the same change; actions outside the repository go in a final "Outside the repository" sub-bullet), **Acceptance criteria** (a numbered list, one testable statement per item), **Verification**, and **Notes** when needed. "Confirm with the owner that the phone is available" applies to every use of the Galaxy S24.

#### Organization and verification (M0)

**V2-01. Create `status.md` and `docs/workflow.md` (the first organization task).**

*   **Depends on:** the owner's explicit final approval of this design, given in chat as «Apruebo el diseño y autorizo V2-01».
*   **Gate:** none.
*   **Files:**
    *   `docs/designs/marlix-v0-2.md` (add to git; modify), in four steps:
        1.  Set the header line to `*   **Status:** Approved (YYYY-MM-DD)`, the date of the approval. This line is the record of the approval.
        2.  Add the file to the repository in the first commit of this task. The local working files (`design_draft.md`, `concepts_brief.md` and the review reports) stay out of the repository (D-16).
        3.  Shorten section 10 as "What moves where" (10.6) says: the moved text is removed and the rest stays. Each subsection 10.3 to 10.6 keeps its heading followed by a one-line link to the matching `docs/workflow.md` heading; 10.4 links to "The cycle before C10". Where moved text is embedded in text that stays (the post-merge checks in the Done row, the "Definition of Ready (below)" references), it stays in place and the reference becomes a link to the `docs/workflow.md` heading.
        4.  Point the references in the Work order, section 10 and CUJ 12 to those headings. V2-17 keeps its references to the worked example in 10.5, which stays. Other references to 10.6 keep resolving through the kept heading.
    *   `docs/workflow.md` (create), with the headings "The cycle before C10", "Definition of Ready", "Blocked tasks and switching", "Post-merge checks", "A clear task" and "`status.md`". It contains every item that "What moves where" (10.6) lists, under the heading that list gives; that list is the only source.
    *   `status.md` (create): the interim mode of 10.6, with the content of acceptance criteria 7 to 16.
    *   `README.md` (modify): two rows added to the Documentation table, after the "Technical decisions" row, verbatim: `| [Project status](status.md) | Progress, the active task and the next step. |` and `| [Workflow](docs/workflow.md) | How a task goes from start to merge. |`.
    *   `.gitignore` and `app/.gitignore` (verify; modify only if a rule matches `status.md`).
    *   `CLAUDE.md` (local, ignored by git, not in the pull request): replace the session-state blocks with the rules in force, and add this sentence: "For v0.2 work before C10, the backlog is the V2-NN list in `docs/designs/marlix-v0-2.md`, its progress and next step live in `status.md`, and the Notion rule applies only to work outside v0.2."
*   **Acceptance criteria:**
    1.  The design's header line reads `*   **Status:** Approved (YYYY-MM-DD)`, and the design is tracked by git.
    2.  `docs/workflow.md` contains every item listed for V2-01 in "What moves where" (10.6), and the design links to it.
    3.  The design still contains 10.3's columns, labels and board mechanics, 10.4 as written, 10.6's template after C10 and the board and issue columns of the event table, and 10.9.
    4.  `status.md` has the sections of 10.6 in their order.
    5.  `status.md` has at most 70 lines.
    6.  `status.md` contains no email address, key, token, device or account identifier, or personal name.
    7.  The `status.md` header reads `Updated: <date> · Board: none yet (C10 pending); tasks use their V2 ID · Milestone: M0 Unblock`.
    8.  The launch line reads `v0.2 launch progress [░░░░░░░░░░] 3% (1 of 28 launch tasks complete)`, because V2-01 counts itself as done under the as-if-merged rule of 10.6, and the next line reads `Sala beta: 0 of 6 tasks complete (does not block the launch)`.
    9.  The progress section also has `Scope: 28 launch tasks from docs/designs/marlix-v0-2.md (experiments and V2-04 not counted).`, `Completed and verified: V2-01` and `Launch criteria met: 0 of 11. Finished tasks are not the same as ready to publish.`
    10. "Active task" is `V2-02 Verify the external conditions · P0 · M0 · owner`.
    11. "Next up" is, in order: V2-05a, V2-37, V2-14, V2-15, V2-16 (dependencies met and no gate that prevents starting; priority, then number). V2-04 is not listed, because C10 is open. Each line reads `<ID> <title> · <priority>`, for example `V2-05a Staging environment · P0`.
    12. "Blocked" reads "Nothing blocked.", and "Review" reads "Nothing waiting."
    13. The heading reads `## Launch criteria still pending (11 of 11)`, there is no "Met" line, and the list is, one line each: 1 Closed test done or not required (C1); 2 Restore drill on a real project; 3 Spend governor in production; 4 Classifier isolated, crisis:eval green; 5 Own-domain sender verified; 6 Launch features done; 7 Production build without the Sala; 8 Privacy policy, data safety, health declaration; 9 v0.1 APKs work; 10 Checks green, release build tested; 11 Groq paid with ZDR and spend limit.
    14. "Decisions waiting on the owner" lists the open conditions that the owner verifies and that block the launch, the Sala beta or the process: for the launch, C1, C2, C3, C5, C6, C11 and Q13; for the Sala beta, C8, Q15, Q16, Q18 and Q19; for the process, C10.
    15. "Next step" reads: "Owner: open Play Console, the Groq console, the Supabase SMTP settings, UptimeRobot and a card statement with a foreign-service charge, and record the answers of V2-02 criteria 1 to 8."
    16. "Later" contains only "Review the existing documentation against the layout of 10.1 (README short, designs in `docs/designs/`, guides in force, diagrams beside their topic)".
    17. Git tracks `status.md` and `docs/workflow.md`.
    18. The owner confirms in chat that the local `CLAUDE.md` holds the sentence above and no session-state blocks.
*   **Verification:** `git check-ignore status.md` prints nothing; `(Get-Content status.md).Count` is at most 70; `Select-String -Path status.md -Pattern '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+|sb_secret|sb_publishable|gsk_|eyJ'` prints nothing; the assistant reads `status.md` for names by hand; a fresh reader finds the next step in `status.md` in at most 60 seconds (CUJ 11); the links to `status.md` and `docs/workflow.md` resolve.

**V2-02. Verify the external conditions (owner).**

*   **Depends on:** none.
*   **Gate:** the owner reads the consoles (C1, C2, C5, C6, C11).
*   **Files:**
    *   `status.md` (modify: record yes or no and the decision each answer changes).
    *   `docs/decisions.md` (modify, only if an answer changes a decision, for example that the closed test does not apply).
*   **Acceptance criteria:**
    1.  C1 is known: account type, creation date, identity verification, app registration, Play App Signing, and whether the AAB `0.1.2+3` is accepted on a closed track.
    2.  C2 is known (VAT on foreign services).
    3.  C5 is known and written down **outside the repository** (the current SMTP provider and sender).
    4.  Each still-open item of C6, (a) to (f), is recorded as yes, no or not offered, and (f) as same month, next month or mixed.
    5.  ZDR is on in Settings > Data controls of the Groq organization used by production (a re-check of the 2026-10-29 confirmation).
    6.  If ZDR is not on for the free plan, that is recorded, and no tester is invited before V2-35.
    7.  C11 is known: the UptimeRobot monitor on `/health` exists, or it is created.
    8.  The state of C10 is recorded.
    9.  V2-01 is recorded only in `status.md` and its pull request body, and V2-02 only in `status.md` (the pilot of the interim mode).
    10. A new session resumes from `status.md` alone (CUJ 11).
*   **Verification:** the owner checks each panel; the assistant records only the answer, never a screenshot, a key or an email address.

**V2-34. Check the current email setup and Groq Free capacity in staging (before the closed test).**

*   **Depends on:** V2-02 (C5 known), V2-05a (staging exists).
*   **Gate:** C1; C5.
*   **Files:**
    *   `docs/development.md` (modify: the result, in general terms, without the sender address or any credential).
    *   `docs/decisions.md` (modify: pass or fail, the limits found and what they mean for the testers).
    *   `status.md` (modify).
    *   Outside the repository: the Supabase Auth settings of the staging project.
*   **Acceptance criteria:**
    1.  The staging Auth SMTP settings replicate the provider and sender that production uses today; the owner checks them field by field and shares no credential.
    2.  A sign-up code and a recovery code reach the main inbox in Gmail and in Outlook.
    3.  A code typed in the app completes a sign-up and a recovery on staging.
    4.  Testers are invited in batches of at most 12 per hour, and the emails of a batch (testers × 2, for the sign-up and one resend) stay at or below 80% of the lower of the provider's hourly limit and Supabase's Auth rate limit (30 emails per hour by default with custom SMTP). If not, the batch size is lowered or the Supabase limit is raised before the check.
    5.  The daily and per-minute limits of Groq's free plan for `gpt-oss-120b`, the classifier model and Whisper are read in the console and compared with the testers' expected use (testers × expected turns per day, with the current per-person limit). The brief's estimate of about 54 chat turns a day is verified or corrected.
    6.  If the free plan is not enough, either V2-35 and its prerequisites come before inviting testers, or the closed test runs with a lower daily limit per person, recorded in `docs/decisions.md`.
    7.  If any of criteria 1 to 4 fails, the result is recorded as "fail", and the email work of V2-06a is finished and accepted before any tester is invited.
*   **Verification:** manual, on staging and the emulator, with a Gmail and an Outlook mailbox; the headers are kept privately and only pass or fail is recorded in the repository; the Groq limits are read from the console and recorded as numbers.
*   **Notes:** if C1 shows the closed test does not apply, this task is removed from the launch count and the own-domain email proceeds in V2-06a on its own.

**V2-03. Run the Play closed test, if it applies.**

*   **Depends on:** V2-02, V2-34.
*   **Gate:** C1.
*   **Files:**
    *   `status.md` (modify: the day counter).
    *   Outside the repository: Play Console.
*   **Acceptance criteria:**
    1.  If the rule applies, at least 12 testers stay opted in for 14 consecutive days on a closed track, with the AAB that C1 allows (the current `0.1.2+3`, or a rebuilt 0.1.x against the same backend).
    2.  More than 12 testers are recruited to cover drop-outs, and they are invited in the batches of V2-34, only after V2-34 passes.
    3.  The production-access request is sent after day 14, and the track stays open for v0.2 release candidates.
    4.  If the rule does not apply, that is recorded and the task is removed from the launch count.
*   **Verification:** Play Console shows the tester count and the days; `status.md` records counts only.

**V2-04. Move the backlog to GitHub Issues and a board.**

*   **Depends on:** V2-01.
*   **Gate:** C10. Nothing in this task starts before the owner approves the transition.
*   **Files:**
    *   `.github/ISSUE_TEMPLATE/task.md` (modify): drop the card ID and the "backlog card" wording; add Expected outcome, Version, Priority, Blocker record, Launch criterion served, Working method and Flag.
    *   `.github/pull_request_template.md` (modify): add the two Definition of Done lines of 10.2 (row 7).
    *   `CONTRIBUTING.md` (modify): the workflow steps, the flag rule and the Definition of Done additions of 10.2.
    *   `docs/workflow.md` (modify): receives what V2-01 left in the design ("What moves where", 10.6): 10.3's columns, labels and board mechanics, 10.4 as written, 10.6's template after C10 and the board and issue columns of the event table, and 10.9. The design keeps a link.
    *   `docs/decisions.md` (modify): record the transition and the flow.
    *   `status.md` (modify): compute the bars from the issues of the milestone `v0.2` (with the `sala` and `experiment` labels), put the board link in the header, and remove the "Completed and verified" line.
    *   `CLAUDE.md` (local, ignored by git; edited last, step T8): replace the Notion rule.
    *   Outside the repository: the GitHub Project, labels and milestone, and the issues, following steps T1 to T8 of 10.9.
*   **Acceptance criteria:**
    1.  The completeness checks of T6 pass.
    2.  One pilot task closes through the full cycle (T7).
    3.  Notion shows the archive banner.
    4.  The bars come from the issues of the milestone `v0.2`, and their totals equal the interim totals plus the scope changes recorded since.
    5.  The `CLAUDE.md` rule changes only after the pilot.
*   **Verification:** `gh issue list --milestone v0.2 --state all --json number` returns the expected count; the owner checks every `P0` issue against its card; the board's column counts match the issues' states.

**V2-05a. Staging environment.**

*   **Depends on:** none.
*   **Gate:** none.
*   **Files:**
    *   `render.yaml` (modify): add a `marlix-api-staging` service with `rootDir: api`, `autoDeployTrigger: off` and its own `sync: false` variables, so production keeps deploying from `main` (`autoDeployTrigger: checksPass`) and staging deploys only by hand.
    *   `.github/workflows/staging-keepalive.yml` (create): on the cron `0 12 * * 1,4` and by hand, runs `psql "$STAGING_DATABASE_URL" -c "select 1"`, so the free Supabase staging project sees database activity and does not pause (`/health` does not read the database); read-only permissions and actions pinned by SHA like the other workflows. The owner creates the repository secret `STAGING_DATABASE_URL`.
    *   `app/config/staging.example.json` (create) and `app/.gitignore` (modify): a template and an ignore rule for an uncommitted `app/config/staging.json` that points the app at staging.
    *   `docs/development.md` (modify): the staging section, and the **low-end AVD** profile used by every performance check (an Android Virtual Device with API 31, 2 GB of RAM, 2 cores and the software GPU, SwiftShader).
    *   `docs/monitoring.md` (modify): staging notes.
    *   Outside the repository: the staging Supabase project, where the owner runs `docs/schema.sql` and then `docs/verify-migrations.sql` in the SQL Editor; and the staging Render service, with the same variables as production (`SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `GROQ_API_KEY` and the others in `api/.env.example`) set to staging values.
*   **Acceptance criteria:**
    1.  Staging has its own Supabase project and shares no key with production.
    2.  `docs/verify-migrations.sql` returns only `ok` on staging.
    3.  Staging never deploys on its own.
    4.  The app signs in against staging.
    5.  The keepalive workflow runs once by hand and its `select 1` succeeds.
    6.  The low-end AVD is defined once, in `docs/development.md`.
    7.  The existing CI jobs pass unchanged.
*   **Verification:** `GET /health` on staging; sign in with the app on the emulator against staging; the keepalive workflow's log; the AVD is created from the written profile.

**V2-05b. Restore drill against staging.**

*   **Depends on:** V2-05a.
*   **Gate:** none.
*   **Files:**
    *   `docs/backups.md` (modify: the drill against a real project and its result).
    *   `docs/decisions.md` (modify: replace the S7-5 condition "move to Pro before opening" with the drill).
*   **Acceptance criteria:**
    1.  The latest encrypted backup is restored into the staging project.
    2.  Row counts match the backup.
    3.  RLS is on in all tables.
    4.  The app signs in against the restored project (launch criterion 2).
*   **Verification:** restore from the backup artifact into the staging project; run `docs/verify-migrations.sql` (all `ok`) and a row-count query; sign in with the app on the emulator against staging.

#### Foundations (M1)

**V2-06a. Domain and own-domain email.**

*   **Depends on:** V2-05a.
*   **Gate:** C3 (the purchase waits for the owner's confirmation of the final price with tax at checkout); C5.
*   **Files:**
    *   `docs/development.md` (modify): the SMTP section for Resend, the sender, and the SPF, DKIM and DMARC records.
    *   `docs/decisions.md` (modify): the domain and email decision, the price paid with tax, and the date on which Cloudflare will charge the renewal (C3); it supersedes the provider part of S7-9 (the six-digit email codes).
    *   `api/config/spend-plan.json` (modify, once V2-08 exists; before that, `status.md`): the purchase and the renewal as fixed charges in the cash months in which the card is charged.
    *   `infra/auth/confirm-email.html` and `infra/auth/reset-password.html` (verify; modify only if the sender wording needs it).
    *   `site/privacy.html` (modify): Resend and Cloudflare as processors.
    *   Outside the repository: the domain purchase, Cloudflare DNS, Resend domain verification and the Supabase SMTP settings (staging first, then production).
*   **Acceptance criteria:**
    1.  The four email tests of section 5 pass with the `.fyi` sender, with delivery to the main inbox in Gmail and Outlook.
    2.  Before paying, the purchase is entered as a fixed charge under cash month R, the month the card is charged.
    3.  If Groq is on the paid plan, the entry is made before usage month R−1 starts, usage months R−1 and R are lowered, and `status.md` lists their spend-limit dates (section 6).
*   **Verification:** a full sign-up and a full recovery on staging and then on production, with Gmail and Outlook headers showing SPF, DKIM and DMARC at `pass`.
*   **Notes:** the task may run during the closed test; the own-domain sender must be accepted in staging and production before V2-33 (launch criterion 5).

**V2-06b. Stable hostname `api.<domain>` (optional).**

*   **Depends on:** V2-06a.
*   **Gate:** C9.
*   **Files:**
    *   `app/config/production.json` (modify: the API base URL becomes `https://api.<domain>`).
    *   `docs/api-contract.md` and `README.md` (modify: the base URL).
    *   Outside the repository: the CNAME at Cloudflare and the custom domain in Render.
*   **Acceptance criteria:**
    1.  `https://api.<domain>/health` answers with valid TLS.
    2.  The old Render URL still answers.
    3.  A v0.1 APK still works.
*   **Verification:** `Invoke-RestMethod https://api.<domain>/health` returns `ok`; install the v0.1 APK on the emulator and send a message.
*   **Notes:** if Render's free plan does not accept a custom domain, this task is closed as not applicable and the app keeps the Render URL.

**V2-07. Feature flags and the v0.1 contract test.**

*   **Depends on:** V2-05a.
*   **Gate:** none.
*   **Files:**
    *   `docs/migrations/YYYY-MM-DD-feature-flags.sql` (create): `feature_flags` (`name text primary key`, `mode text not null check (mode in ('off','invited','all'))`) and `feature_flag_users` (`flag text references feature_flags(name)`, `user_id uuid references auth.users on delete cascade`, primary key `(flag, user_id)`); seed rows `('social_room','off')`, `('photo_skin','off')` and `('medical_urgency','off')`; RLS on, no policy for `anon` or `authenticated`.
    *   `docs/schema.sql`, `docs/verify-migrations.sql`, `docs/schema-test.sql`, `docs/erd.md` (modify): the mirror, the checks, the privilege cases and the diagram.
    *   `api/src/services/flags/flag-store.ts` and `api/src/services/flags/supabase-flag-store.ts` (create): the interface and its Supabase implementation.
    *   `api/src/routes/profile.ts` (modify): `GET /v1/me` returns an additive `flags` object.
    *   `api/src/server.ts` (modify): build the Supabase flag store.
    *   `api/src/app.ts` (modify): a new `flags` field in `AppDependencies`, passed to the profile router.
    *   `api/test/helpers.ts` (modify): `startApp` passes a fake flag store.
    *   `docs/api-contract.md` (modify): the new field.
    *   `app/lib/models/profile.dart` (modify): read `flags`, with every flag false when the field is missing.
    *   `api/test/legacy-clients.test.ts` (create): a CI contract test with requests shaped like v0.1 (no new fields or headers) against `/v1/me`, chat in JSON and in SSE, memories and usage. It grows with each later endpoint change (Conventions).
    *   `api/test/flags.test.ts` (create), `api/test/profile.test.ts` (modify), `app/test/models/profile_flags_test.dart` (create).
*   **Acceptance criteria:**
    1.  `GET /v1/me` returns `"flags": {"social_room": false, "photo_skin": false}` with the seeded rows.
    2.  With empty or unreachable tables, every flag is false.
    3.  `social_room` is true only for mode `all`, or for `invited` and a listed user.
    4.  `medical_urgency` is never sent to the app.
    5.  The tables have RLS and no client policy.
    6.  The contract documents the field.
    7.  The v0.1 contract test passes in CI.
*   **Verification:** `npm test` in `api/`; the database privilege tests; `docs/verify-migrations.sql`; a staging call with the tables empty and with one invited user; `flutter test` in `app/`.

**V2-08. Spend ledger, reservations and per-use routing.**

*   **Depends on:** V2-05a.
*   **Gate:** none.
*   **Files:**
    *   `docs/migrations/YYYY-MM-DD-llm-spend.sql` (create): tables `llm_spend` and `spend_counters` (section 3.2); functions `reserve_spend` (with the one-way borrowing of 3.2), `settle_spend` and `release_spend`; the column `daily_usage.voice_seconds integer not null default 0` and the atomic function `record_voice_seconds(p_user_id uuid, p_day date, p_seconds integer)`, executable only by `service_role`; RLS on all, no client policy.
    *   `docs/schema.sql`, `docs/verify-migrations.sql`, `docs/schema-test.sql`, `docs/erd.md` (modify).
    *   `api/config/llm-prices.json` and `api/config/spend-plan.json` (create), with `api/src/config/spend-config.ts` (create: validation like `crisis-config.ts`).
    *   `api/src/services/spend/spend-ledger.ts` (create): the interface; `api/src/services/spend/supabase-spend-ledger.ts` (create): the calls to the three functions.
    *   `api/src/services/llm/types.ts` and `api/src/services/llm/groq-provider.ts` (modify): `LlmUsage` gains an optional `cachedInputTokens`, present only when the response has `prompt_tokens_details.cached_tokens`.
    *   `api/test/groq-provider.test.ts` (modify): covers a response with and without `cached_tokens`.
    *   `api/src/services/transcription/wav.ts` (create): `SAMPLE_RATE`, `WAV_HEADER_BYTES`, `BYTES_PER_SECOND` and `wavSeconds`, moved from `api/src/routes/transcribe.ts`, which imports them (its `MAX_BYTES` needs them), so a service does not import from a route; `api/test/transcribe.test.ts` imports `wavSeconds` from `wav.ts`.
    *   `api/src/services/spend/pricing.ts` (create): worst-case and real cost from the price table (`input_per_million`, `cached_per_million`, `output_per_million`, `per_audio_hour`), times `tax_multiplier`; the billed-seconds helper returns `max(seconds, 10)`. `Transcriber.transcribe` returns only text, so a transcription settles at these reserved billed seconds.
    *   `api/src/services/spend/govern.ts` (create): the decorators `governLlm(provider, { use, ledger, monitor, prices })` and `governTranscriber(transcriber, { ledger, monitor, prices })`; chat and transcription fail closed when the ledger cannot be read; `classifier_chat` runs without it at most 30 times per hour; a refused reservation, or an unreadable ledger, throws `SpendRefusedError`, which is not an `LlmError`, so `withRetry` does not retry it; `governTranscriber` throws `UsageLimitExceededError` with `{ reason: 'voice_budget', resetsAt }`, where `resetsAt` for an exhausted pool is the first instant of the next UTC usage month.
    *   `api/src/services/spend/spend-monitor.ts` (create): the in-memory state of the spend and safety alerts, on the pattern of `api/src/services/llm/quota-monitor.ts`; `govern.ts` reports to it.
    *   `api/src/services/llm/index.ts` (modify): `createLlmProvider(env, overrides)` gains the override `governance?: { use, ledger, monitor, prices }`, builds `governLlm(base, governance)`, and wraps it in `withRetry` only when `retry` is not false. The classifier keeps `retry: false`, its model and its timeout, and every instance still receives `quota`.
    *   `api/src/server.ts` (modify): builds the ledger, the price table and one `spendMonitor` instance shared by the decorators and the health router; one provider instance per LLM use tag; and the transcriber wrapped with `governTranscriber`. The `extractor_auto` instance goes to `createMemoryExtractor` in `server.ts`; the others are passed to `createApp`.
    *   `api/src/app.ts` (modify): in `AppDependencies`, `llmByUse: { chat: LlmProvider; classifier_chat?: LlmProvider }` replaces `llm` and `crisisClassifier` (V2-13 adds `extractor_remember` and V2-24 adds `classifier_room`; without `classifier_chat`, ambiguous messages count as a crisis, as today), `spendMonitor` is added, and `spendPlan?: SpendPlan` is added, defaulting to the loader in `spend-config.ts` like `plans = loadPlansConfig()`; the private chat's crisis filter is built over `llmByUse.classifier_chat`; `llmByUse.chat` is passed to the chat service; `createHealthRouter(usage, quota, spendMonitor)`.
    *   `api/src/services/usage/usage-store.ts`, `api/src/services/usage/supabase-usage-store.ts` and `api/test/memory-usage-store.ts` (modify): `voiceSeconds(userId, day)` and `recordVoiceSeconds(userId, day, seconds)`, for the Costa Rica day (`costa-rica-day.ts`); the Supabase store calls `record_voice_seconds`.
    *   `api/src/services/usage/usage-limiter.ts` (modify): `createUsageLimiter(plans, store, now, options?)` gains an optional `options` parameter that carries `voiceSecondsPerPerson` from `spend-plan.json` (`voice_seconds_per_person`, default 360 seconds: the daily share of 6 billed minutes in 3.2), so the existing calls with two or three arguments do not change. The `UsageLimitError` union gains `{ reason: 'voice_budget'; resetsAt }`, and `UsageLimiter` gains `checkVoice(user, seconds)` and `recordVoice(user, seconds)`, which take a `UsageUser` like the existing methods. The route passes WAV seconds; both methods apply the 10-second floor through `pricing.ts`'s billed-seconds helper, so `recordVoice` records billed seconds. A person's exhausted share has `resetsAt` = `nextCostaRicaMidnight`.
    *   `api/src/middleware/error-handler.ts` (modify): a branch for `voice_budget`, HTTP 429 with code `VOICE_BUDGET_EXHAUSTED` and `resetsAt`; `SpendRefusedError` maps to 503 `LLM_UNAVAILABLE`, which the app already shows as the "momentary problem", with its own log line.
    *   `api/src/routes/chat.ts` (modify): `streamError` maps a `SpendRefusedError` raised after the first SSE event to `LLM_UNAVAILABLE`, not `INTERNAL_ERROR`.
    *   `api/src/routes/transcribe.ts` (modify): receives only the usage limiter; calls `checkVoice` before any Groq call and `recordVoice` after a transcription.
    *   `api/src/services/memory/memory-job.ts` (modify): a `SpendRefusedError` re-queues the conversation without counting an attempt and is logged as "paused: budget", so automatic extraction resumes next month instead of giving up until a restart.
    *   `api/src/routes/health.ts` (modify): `/health` keeps its current behavior; two new routes in the same file, `/health/spend` and `/health/safety`, read `spend-monitor.ts` with no database read.
    *   `docs/api-contract.md`, `docs/monitoring.md` (modify: the two endpoints, their UptimeRobot keyword monitors and `VOICE_BUDGET_EXHAUSTED`).
    *   `api/test/spend-governor.test.ts`, `api/test/supabase-spend-ledger.test.ts`, `api/test/fake-spend-ledger.ts`, `api/test/spend-monitor.test.ts` (create).
    *   `api/test/spend-concurrency.test.ts` (create): skipped unless `TEST_DATABASE_URL` is set.
    *   `api/test/helpers.ts` (modify): `startApp` keeps its `llm` and `crisisClassifier` parameters and maps them to `llmByUse.chat` and `llmByUse.classifier_chat`, so the existing tests do not change; it passes the new dependencies.
    *   `api/test/transcribe.test.ts`, `api/test/supabase-usage-store.test.ts`, `api/test/usage-limits.test.ts`, `api/test/quota-monitor.test.ts` (modify; the existing health tests stay in the last two).
    *   `api/package.json` (modify): `pg` and `@types/pg` as dev dependencies, for the concurrency test.
    *   `.github/workflows/ci.yml` (modify): in the `database` job, the existing `docker run` adds `-p 127.0.0.1:5432:5432`; new steps with `working-directory: api` set up Node 24, run `npm ci` and run `node --import tsx --test test/spend-concurrency.test.ts` with `TEST_DATABASE_URL=postgres://postgres:ci-only@127.0.0.1:5432/postgres`. Each test connection runs `set role service_role` before calling `reserve_spend`, following the `set local role` pattern of `docs/schema-test.sql`.
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  Two simultaneous calls whose combined worst case exceeds the cap: exactly one is granted.
    2.  Each retry reserves on its own, and the classifier is still built without retries.
    3.  There are separate counters for `chat`, `classifier_chat`, `classifier_room`, `extractor_auto`, `extractor_remember` and `transcribe`, and each moves only for its own calls.
    4.  With `classifier_chat` exhausted and chat headroom left, an ambiguous message is still classified and the chat counter grows by the classifier's cost.
    5.  `classifier_chat` never borrows more than half the margin.
    6.  `classifier_room` never borrows, and with it exhausted the `classifier_chat` counter does not change.
    7.  A 2-second clip is reserved as 10 seconds.
    8.  With the transcription pool or the person's daily share used up, `POST /v1/transcribe` answers 429 `VOICE_BUDGET_EXHAUSTED` and no Groq call is made.
    9.  A fixed charge in cash month R lowers only the chat sub-cap of usage months R−1 and R, and leaves both classifier pools unchanged.
    10. The governor ceiling of a usage month never exceeds the sub-caps plus half the margin.
    11. An unreadable ledger refuses chat and transcription with 503 `LLM_UNAVAILABLE`, not retried, and lets `classifier_chat` run within its hourly limit.
    12. `/health` answers as before (`usage_counter`, `groq_quota`); `/health/spend` turns `degraded` at 80% of a classifier pool or of Whisper and at 90% of the month's cash available to Groq, and reports chat at 80% as information only.
    13. The month boundary of the ledger is UTC; the voice seconds use the Costa Rica day.
    14. The ledger stores no message content and no user id.
    15. `anon` and `authenticated` can neither read nor write any new table, nor call any new function. As with `interactions` today, `authenticated` can read `voice_seconds` on its own `daily_usage` row only.
*   **Verification:** unit tests with the fake ledger; `api/test/spend-concurrency.test.ts`, which calls `reserve_spend` from two connections against the Postgres of the CI `database` job; `docs/schema-test.sql`; a manual run on staging; one UptimeRobot monitor per new health endpoint fires on its own.
*   **Notes:** `tax_multiplier` is 1.13 until V2-02 records C2.

**V2-09. Stream usage, aborts and graceful shutdown.**

*   **Depends on:** V2-08.
*   **Gate:** none.
*   **Files:**
    *   `api/src/services/llm/types.ts` (modify): `stream()` returns `{ chunks: AsyncIterable<string>, usage: Promise<LlmUsage | undefined> }`. `usage` never rejects: it resolves `undefined` on an error or an abort, because nothing awaits it on the chat path and a rejection would end the process.
    *   `api/src/services/llm/retry.ts` (modify): `withRetry.stream` passes through the `usage` of the attempt that streamed.
    *   `api/test/helpers.ts`, `api/test/retry.test.ts`, `api/test/quota-monitor.test.ts` (modify): the fakes and tests follow the new `stream()` shape.
    *   `api/src/services/llm/groq-provider.ts` (modify): request `stream_options.include_usage` and resolve `usage` from the final chunk.
    *   `api/src/services/chat-service.ts` (modify): consumes `chunks` only.
    *   `api/src/services/spend/govern.ts` (modify): settles each streamed attempt from its inner `usage`, below `withRetry`. A module-level tracker holds the calls in flight. Each governed call combines the caller's signal with its own `AbortController` through `AbortSignal.any`, so the drain can abort it.
    *   `api/src/services/spend/shutdown.ts` (create): `drainGoverned(timeoutMs)` waits for the calls in flight, then aborts any open stream, which stays held.
    *   `api/src/routes/chat.ts`, `api/src/services/chat-service.ts` and `api/src/services/llm/groq-provider.ts` (verify only): the abort on client disconnect (`res.on('close')` in `chat.ts`) and the signal passed through to the provider.
    *   `api/src/server.ts` (modify): on `SIGTERM`, in this order: stop the existing jobs (`memoryJob`, `retentionJob`), `server.close()`, `await drainGoverned(20_000)`, then `process.exit(0)`.
    *   `api/test/groq-provider.test.ts`, `api/test/sentence-streaming.test.ts`, `api/test/voice-replies.test.ts`, `api/test/spend-governor.test.ts` (modify).
    *   `api/test/shutdown.test.ts` (create): resets the module-level tracker between tests.
    *   `docs/decisions.md` (modify): the interrupted-stream decision (below).
*   **Acceptance criteria:**
    1.  A completed stream with a final usage chunk settles at its real `usage`.
    2.  A stream cut off before the final chunk stays `held` at its worst case.
    3.  A completed stream with no usage chunk (C6 (c) answered no) also stays `held` at its worst case, and a test asserts it.
    4.  A client disconnect aborts the upstream request (a new test in `api/test/sentence-streaming.test.ts` covers `res.on('close')` in `chat.ts`).
    5.  On `SIGTERM`, a call in flight settles before the exit, and a stream still open after the wait stays held.
    6.  The non-stream path is unchanged.
*   **Verification:** tests with a fake stream that ends with usage, ends without it, is cut and is aborted, and a shutdown test with a call in flight; on staging, interrupt a voice reply and check that its ledger row is `held`.
*   **Notes:** C6 (c) is handled by the fallback in criterion 3. Interrupted streams are decided when C6 (b) is answered. Two options are recorded: (1) **abort and hold**, the current design, which is cheaper if Groq bills only what was generated; (2) **drain**, which keeps reading the interrupted stream without sending it to the person, to obtain the final `usage` and settle at once, at no extra cost if Groq bills the whole reply anyway. The task ships option 1; switching to option 2 is recorded in `docs/decisions.md` once C6 (b) is known.

**V2-10. Evidence rules and reconciliation.**

*   **Depends on:** V2-08, V2-09.
*   **Gate:** C6 (a), (b), (e); Q11.
*   **Files:**
    *   `docs/migrations/YYYY-MM-DD-spend-reconciliation.sql` (create): the function `reconcile_spend(period_start, period_end, model, provider_total_micros)`, which releases held rows of that model oldest first, or adds the shortfall to the margin and then chat, never to a classifier pool; mirrored in `docs/schema.sql`, `docs/verify-migrations.sql` and `docs/schema-test.sql`.
    *   `api/src/services/spend/evidence.ts` (create): the outcome table of 3.2 as one function from a call outcome to its state.
    *   `docs/spend-reconciliation.md` (create): the procedure (weekly in the first month, monthly afterwards), which source to read (an export, or the invoice total plus the ledger's `usage` if there is none), the SQL to run in the SQL Editor, the shared first and last UTC day of each month until C6 (e) is known, and how to record the result in `docs/decisions.md`.
    *   `api/config/spend-plan.json` (modify): the final sub-caps after Q11.
    *   `api/test/spend-evidence.test.ts`, `api/test/spend-reconciliation.test.ts` (create).
    *   `docs/monitoring.md`, `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  The held, settled and released transitions follow the table of 3.2.
    2.  A reconciliation below the ledger's total for a model releases the difference, oldest first.
    3.  A reconciliation above it adds the shortfall at once, charged to the margin and then chat, and raises the alert.
    4.  The invoice fallback is tested.
    5.  C6 (a), (b) and (e) are recorded.
    6.  Q11 is answered: the measured `usage` and `cached_tokens` per turn are recorded, and the final sub-caps are written in section 6 and `spend-plan.json`.
*   **Verification:** tests; on staging, run the first reconciliation with the real provider data and record the result and the held-to-billed ratio in `docs/decisions.md`; the 20-interruption calibration.
*   **Notes:** if about 20% of chat calls end without a final `usage` (an assumption to measure), the expected scenario holds about 280 calls a week at a worst case of about USD 0.0014 each with VAT, which is about USD 0.38, about 6% of the chat sub-cap of USD 6.00. Until this task closes, launch criterion 3 stays open. Interrupting 20 voice replies in staging and comparing the held amounts with the Groq console shows how far the hold exceeds the real cost, and so how often reconciliation is needed. The cap does not depend on this test.

**V2-11. Savings mode and daily-limit step-down.**

*   **Depends on:** V2-07 (`legacy-clients.test.ts`), V2-08, V2-12a.
*   **Gate:** Q12 (the savings model).
*   **Files:**
    *   `api/src/services/chat-service.ts` (modify): receives two providers, `chat` and `chatSavings`, and `spendState`; it uses the second with a shorter context when `chatMode()` is `savings`.
    *   `api/src/config/env.ts`, `api/.env.example` (modify): `CHAT_SAVINGS_MODEL` and `CHAT_SAVINGS_CONTEXT_MESSAGES`, both with defaults in `env.ts` (the model chosen by Q12), so a deploy without them still validates.
    *   `api/src/services/spend/spend-state.ts` (create): the governor's read interface, `SpendState.chatMode(): Promise<'normal' | 'savings' | 'step_down'>`, read from the ledger's chat counter. An unreadable `chatMode()` counts as `normal` in the limiter, because the governor already fails closed on chat.
    *   `api/src/services/spend/spend-ledger.ts`, `api/src/services/spend/supabase-spend-ledger.ts` and `api/test/fake-spend-ledger.ts` (modify): a `chatCounter()` read.
    *   `api/src/services/usage/usage-limiter.ts` (modify): the `options` parameter of `createUsageLimiter` (V2-08) gains `spendState`; an effective daily limit of 10 when `chatMode()` is `step_down`; the `daily_limit` reason gains an optional `reduced: true`.
    *   `api/src/middleware/error-handler.ts` (modify): the step-down keeps HTTP 429 with code `DAILY_LIMIT_REACHED` and `resetsAt`, which v0.1 already shows, and adds `details.reason: "reduced"`, which only v0.2 reads.
    *   `api/src/server.ts` and `api/src/app.ts` (modify): `AppDependencies` gains `chatSavings`, a second provider built with `CHAT_SAVINGS_MODEL` and governed under the `chat` counter, and `spendState`, which is passed to the chat service and to the usage limiter.
    *   `api/test/helpers.ts` (modify): `startApp` passes the savings provider and a fake `spendState`.
    *   `docs/migrations/YYYY-MM-DD-beta-daily-limit.sql` (create) and `docs/schema.sql` (modify): the beta daily limit of 40 for the plan `personal`; a reversible data change.
    *   `docs/api-contract.md` (modify).
    *   `app/lib/services/marlix_api.dart` (modify): read `details.reason` of `DAILY_LIMIT_REACHED`.
    *   `app/lib/services/api_exception.dart` (modify): `DailyLimitReachedException` carries whether the limit was reduced.
    *   `app/lib/screens/chat/chat_controller.dart`, `app/lib/widgets/chat_states.dart` (modify): explain the lower limit to the person in Spanish.
    *   `api/test/chat.test.ts`, `api/test/usage-limits.test.ts`, `api/test/legacy-clients.test.ts`, `app/test/screens/chat_states_test.dart` (modify).
*   **Acceptance criteria:**
    1.  When the chat sub-cap's remaining headroom is below one worst-case reservation, chat answers in savings mode.
    2.  With savings mode also used up, the daily limit is 10, and the API answers `DAILY_LIMIT_REACHED` with `details.reason: "reduced"`.
    3.  v0.2 explains the lower limit; a v0.1 request gets the same code and shows its usual limit message.
    4.  The help button stays visible in every state.
    5.  Layer 1 still answers.
    6.  The new states pass the UI review of section 4.
    7.  During the step-down, `GET /v1/usage` and the chat `usage` snapshot report a limit of 10, so the usage chip of v0.1 stays accurate.
*   **Verification:** tests with a fake governor; on staging, set tiny caps in `spend-plan.json` and walk through normal, savings and step-down.

**V2-12a. Separate models for the classifier and the extractor.**

*   **Depends on:** V2-08.
*   **Gate:** Q12.
*   **Files:**
    *   `api/src/config/env.ts`, `api/.env.example` (modify): a new default for `MEMORY_EXTRACTOR_MODEL`, other than the classifier's; an optional `CRISIS_CLASSIFIER_GROQ_API_KEY` that falls back to `GROQ_API_KEY`. `CRISIS_CLASSIFIER_MODEL` keeps its `env.ts` default. `parseEnv` rejects a configuration where `MEMORY_EXTRACTOR_MODEL` equals `CRISIS_CLASSIFIER_MODEL`.
    *   `render.yaml` (modify): `CRISIS_CLASSIFIER_GROQ_API_KEY` with `sync: false` in both services (production and `marlix-api-staging`), so moving the classifier to another key or organization is a Render setting.
    *   `api/src/services/llm/index.ts` (modify): `createLlmProvider` gains an `apiKey` option (today it always uses `env.GROQ_API_KEY`).
    *   `api/src/server.ts` (modify): the classifier instances use the classifier key.
    *   `api/scripts/crisis-classifier-eval.ts` (modify): builds the classifier with `env.CRISIS_CLASSIFIER_GROQ_API_KEY ?? env.GROQ_API_KEY`, so V2-12b can run `crisis:eval` against the second organization.
    *   `api/src/services/memory/memory-job.ts` (modify): only the corrected comment ("the same quota as the chat").
    *   `api/test/fixtures/memory-extraction-cases.ts` (create): fixed extraction cases, including sensitive data that must not be saved.
    *   `api/scripts/memory-extractor-eval.ts` (create) and `api/package.json` (modify: the script `memory:eval`): evaluate candidate extractor models on those cases.
    *   `docs/monitoring.md` (modify): fix the claim that the reply review uses Groq requests.
    *   `docs/decisions.md` (modify): the Q12 outcome, with the baseline score.
    *   `api/test/env.test.ts`, `api/test/crisis-classifier.test.ts`, `api/test/memory-extractor.test.ts` (modify).
*   **Acceptance criteria:**
    1.  `parseEnv` rejects equal classifier and extractor models, and a test covers it.
    2.  The classifier provider reads its own key variable, with the fallback.
    3.  The baseline is today's model's score on `memory-extraction-cases.ts`; the chosen extractor model scores at least as high and saves no sensitive data.
    4.  `npm run crisis:eval` gives the same result as before.
    5.  The wrong comments in `.env.example`, `memory-job.ts` and `monitoring.md` are corrected.
*   **Verification:** `npm run crisis:eval`; `npm run memory:eval` (the owner supplies a key); `npm test`.

**V2-12b. The classifier in its own Groq organization.**

*   **Depends on:** V2-12a, V2-35 (a spend limit exists only on the paid plan).
*   **Gate:** C6 (d).
*   **Files:**
    *   `docs/decisions.md` (modify).
    *   Outside the repository: the second organization with ZDR on and its own spend limit, set as in section 3.3 (about USD 1.64 in a normal usage month, USD 0.75 in a lowered one) with the main organization's limit lowered by the same amount, and its key in Render as `CRISIS_CLASSIFIER_GROQ_API_KEY`.
*   **Acceptance criteria:**
    1.  With the main organization's spend limit reached in staging (or simulated by a revoked key), the classifier still answers.
    2.  ZDR is on in the second organization.
    3.  `npm run crisis:eval` passes against it (launch criterion 4).
*   **Verification:** a staging run with the main key revoked; the Groq console of both organizations.
*   **Notes:** if C6 shows a second organization brings no separate spend limit or billing, this task is closed as not applicable and removed from the launch count.

**V2-35. Switch Groq to the paid plan with ZDR and a spend limit.**

*   **Depends on:** V2-08, V2-09, V2-12a, all in production.
*   **Gate:** the owner's go-ahead to pay; C6 (f).
*   **Files:**
    *   `api/src/services/llm/errors.ts` (modify): a new `LlmErrorKind`, `spend_blocked`, not transient.
    *   `api/src/services/llm/groq-provider.ts` (modify): map a 400 with code `blocked_api_access` to `spend_blocked` (today every 400 becomes `invalid_request`).
    *   `api/src/middleware/error-handler.ts` (verify): `spend_blocked`, like every `LlmError`, reaches the client as the existing `503 LLM_UNAVAILABLE`, which v0.1 already shows; only the logs and `/health/safety` tell it apart.
    *   `api/src/services/spend/govern.ts` (modify): reports a caught `spend_blocked` error to `spend-monitor.ts`.
    *   `api/src/services/spend/spend-monitor.ts` (modify): `spend_blocked` marks `/health/safety` as `degraded`.
    *   `api/test/groq-provider.test.ts`, `api/test/spend-monitor.test.ts` (modify).
    *   `docs/decisions.md` (modify): the switch date, the limit set and the ZDR check.
    *   `status.md` (modify): the "Later" dates to lower and restore the limit around each fixed charge.
    *   Outside the repository: the paid plan, ZDR in Settings > Data controls, and the spend limit in Settings > Billing > Limits.
*   **Acceptance criteria:**
    1.  ZDR is verified on in the organization.
    2.  C6 (f) is recorded.
    3.  The provider spend limit is set to `(the sum of the usage month's sub-caps + three quarters of the margin) / tax_multiplier`: about USD 8.30 in a normal usage month and USD 3.54 in a lowered one, above the governor ceiling of section 6.
    4.  Email alerts are set at 50, 75 and 90%.
    5.  A staging call answered with `blocked_api_access` produces `spend_blocked`, the behavior of the failure table in 3.3, and a `degraded` `/health/safety` (launch criterion 11).
*   **Verification:** tests with a fake 400; the Groq console (the owner reads the settings; no screenshot or key enters the repository).
*   **Notes:** if C6 (f) shows Groq charges part of a usage month in the following cash month, section 6 is redesigned before this task starts.

#### Features (M3)

**V2-37. Crisis layer 1 on the phone.**

*   **Depends on:** none.
*   **Gate:** none.
*   **Files:**
    *   `api/scripts/export-crisis-asset.ts` (create) and `api/package.json` (modify: the script `crisis:export`): writes `app/assets/config/crisis-layer1.json` from the signal lists of `api/src/services/crisis/signals.ts` and the reply text of `api/config/crisis.json`. The help lines are not copied; the app already caches them.
    *   `app/assets/config/crisis-layer1.json` (create, generated and committed) and `app/pubspec.yaml` (modify: add `assets/config/crisis-layer1.json`, because the config assets are listed by name).
    *   `.github/workflows/ci.yml` (modify): in the API job, `npm run crisis:export && git diff --exit-code ../app/assets/config/crisis-layer1.json`, so the phone's copy never drifts from the backend.
    *   `app/lib/services/crisis/local_crisis_check.dart` (create): a Dart port of the matching in `api/src/services/crisis/normalize.ts` (`normalizeForMatching`, `compilePhrasePattern`) and `api/src/services/crisis/filter.ts` (`FIGURATIVE_PATTERN`, `detectCrisisSignal`), including the figurative-death exception. On the phone an ambiguous signal counts as a crisis, as a classifier failure does on the server.
    *   `app/lib/screens/chat/chat_controller.dart` (modify): when the API call fails, run the local check and, on a match, show the reply text with the help lines from `HelpResourcesController` (`app/lib/services/help_resources.dart`, with its fallback emergency line).
    *   `docs/crisis-protocol.md`, `docs/decisions.md` (modify).
    *   `app/test/services/crisis/local_crisis_check_test.dart` (create).
*   **Acceptance criteria:**
    1.  With the network off, a crisis message shows the help response: the reply text and the cached help lines (part of launch criterion 10).
    2.  A message with no signal shows the current connection error with the help button.
    3.  The cases of `npm run crisis:eval` that layer 1 decides give the same result on the phone, including figurative-death phrases that must not count as a crisis.
    4.  The app makes no model call.
    5.  The CI fails when the asset is stale.
*   **Verification:** `flutter test`; `npm test`; on the emulator in airplane mode, send a crisis phrase, a figurative phrase and a neutral phrase.

**V2-13. «Recordá esto» and 10-minute extraction.**

*   **Depends on:** V2-08, V2-12a.
*   **Gate:** none.
*   **Files:**
    *   `api/src/routes/memories.ts` (modify): `POST /v1/memories/remember` with `{ message_id }`.
    *   `api/src/server.ts` and `api/src/app.ts` (modify): the `extractor_remember` provider and the message store passed to the memories router (today `createMemoriesRouter(memories)` receives only the memory store).
    *   `api/src/services/memory/memory-store.ts` and `api/src/services/memory/supabase-memory-store.ts` (modify): `add` returns the saved `Memory`.
    *   `api/src/services/history/message-store.ts` and `api/src/services/history/supabase-message-store.ts` (modify): `getById(userId, messageId): Promise<(StoredMessage & { conversationId: string }) | null>`; «Recordá esto» passes that `conversationId` as `sourceConversationId`.
    *   `api/test/memory-fakes.ts`, `api/test/memory-message-store.ts` and `api/test/helpers.ts` (modify): the fakes follow the new signatures.
    *   `api/test/supabase-memory-stores.test.ts` and `api/test/supabase-message-store.test.ts` (modify): cover the returned `Memory` and `getById`.
    *   `api/src/services/memory/extractor.ts` (modify): a one-message extraction.
    *   `api/src/services/memory/remember-fallback.ts` (create): the verbatim fallback of 3.4, at most 200 characters, after the local patterns, saved with the category `other`.
    *   `api/src/services/memory/sensitive.ts` (modify only if a pattern is missing).
    *   `api/src/config/env.ts`, `api/.env.example` (modify): `CONVERSATION_IDLE_MINUTES` defaults to 10 (30 today).
    *   `docs/memory.md`, `docs/api-contract.md` (modify).
    *   `api/test/memories.test.ts`, `api/test/memory-extractor.test.ts`, `api/test/memory-job.test.ts` (modify).
    *   `app/lib/services/marlix_api.dart`, `app/lib/screens/memories/memories_controller.dart`, `app/lib/screens/chat/chat_controller.dart`, `app/lib/widgets/message_bubble.dart`, `app/lib/models/memory.dart` (modify).
    *   `app/test/screens/chat_screen_test.dart`, `app/test/screens/memories_screen_test.dart`, `app/test/services/marlix_api_test.dart` (modify).
*   **Acceptance criteria:**
    1.  The notice «Marlix recordó: … · Deshacer» appears, and «Deshacer» deletes the memory.
    2.  When the reserved USD 0.20 is gone, the text is saved as written with the notice «Marlix lo guardó tal como lo escribiste · Deshacer».
    3.  Text over 200 characters, or matching a sensitive pattern, is not saved, and the person is told why.
    4.  The call is recorded under `extractor_remember`.
    5.  Viewing, editing and deleting still work.
    6.  The notice states pass the UI review of section 4.
*   **Verification:** `npm test`, `flutter test`, and a manual run on the emulator against staging, including the exhausted-budget path with a tiny cap.

**V2-14. Greeting by local time and reminder migration.**

*   **Depends on:** none.
*   **Gate:** none.
*   **Files:**
    *   `app/lib/services/greeting.dart` (create): «Buenos días» from 05:00 to 11:59, «Buenas tardes» from 12:00 to 18:59 and «Buenas noches» from 19:00 to 04:59, local time.
    *   `app/lib/services/reminders.dart`, `app/lib/services/reminder_scheduler.dart` (modify): fixed 19:00 and the one-time migration marked `reminders_migrated_v2`, written only after the reschedule succeeds.
    *   `app/lib/models/reminder_config.dart` and `app/assets/config/reminders.json` (modify): the fixed time.
    *   `app/lib/screens/settings_screen.dart` and `app/lib/screens/reminders_toggle.dart` (modify): remove «Hora del saludo».
    *   `app/lib/screens/chat/chat_screen.dart` (modify): show the greeting on open.
    *   `app/lib/app.dart` (modify): run the migration at start.
    *   `app/test/services/greeting_test.dart`, `app/test/services/reminder_migration_test.dart` (create); `app/test/screens/reminders_test.dart`, `app/test/models/reminder_config_test.dart` (modify).
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  CUJ 5 holds in each state: on at 19:00, on at another time, off, and first install.
    2.  The greeting changes with the local time and asks for no permission.
    3.  The «Hora del saludo» picker is gone.
    4.  The greeting and the notice pass the UI review of section 4.
*   **Verification:** `flutter test`; on the emulator, change the clock and time zone with `adb` to see each greeting, and check the pending alarms with `adb shell dumpsys alarm` before and after the migration.

**V2-15. Navigation, theme, first use and accessibility.**

*   **Depends on:** none.
*   **Gate:** none.
*   **Working method:** `ui-ux-pro-max` (section 4).
*   **Files:**
    *   `app/lib/screens/home_shell.dart` (create): the class `HomeShell` with the three tabs, «Marlix», «Practicar» and «Mi Marlix».
    *   `app/lib/screens/onboarding/profile_gate.dart`, `app/lib/screens/onboarding/onboarding_screen.dart` (modify): the first-use flow of CUJ 1.
    *   `app/lib/screens/chat/chat_screen.dart`, `app/lib/screens/settings_screen.dart` (modify): «Ajustes» opens from the profile.
    *   `app/lib/theme/app_theme.dart` (modify): the white theme, whose color and type tokens are a deliverable of this task (section 4).
    *   `app/lib/app.dart` (modify): a reminder tap lands on the Marlix tab.
    *   `app/test/screens/home_shell_test.dart` (create); the existing screen tests (modify); `app/test/architecture_test.dart` (verify).
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  The home screen shows exactly three tabs: «Marlix», «Practicar» and «Mi Marlix».
    2.  «Ajustes» opens from the profile.
    3.  No permission is requested at first launch; the microphone permission is requested only on the first tap of the voice button.
    4.  Every control has a TalkBack label.
    5.  Text at 200% does not clip a control.
    6.  Body-text contrast is at least 4.5 to 1, and touch targets are at least 48 dp.
    7.  The `ui-ux-pro-max` deliverables (navigation map, component inventory with the theme tokens, accessibility checklist, screen states) are reviewed and attached to the pull request.
*   **Verification:** `flutter analyze` and `flutter test`, including widget tests at a text scale of 2.0 and the framework's tap-target and contrast guidelines; TalkBack on the Galaxy S24; screenshots on the emulator and the low-end AVD.

**V2-16. Reduced-motion setting.**

*   **Depends on:** none.
*   **Gate:** none.
*   **Files:**
    *   `app/lib/services/motion_preference.dart` (create): the app's setting combined with the system's `disableAnimations`.
    *   `app/lib/screens/settings_screen.dart` (modify).
    *   `app/test/services/motion_preference_test.dart` (create).
    *   `docs/avatar.md` (modify).
*   **Acceptance criteria:**
    1.  Turning on either the app's setting or the system's `disableAnimations` turns reduced motion on.
    2.  The preference survives a restart.
*   **Verification:** `flutter test`; toggle both on the emulator.

**V2-17. Avatar reacts to device orientation.** The worked example of 10.5.

*   **Depends on:** V2-16.
*   **Gate:** none.
*   **Files:**
    *   `app/pubspec.yaml` and `app/pubspec.lock` (modify: add `sensors_plus`).
    *   `app/lib/widgets/avatar_physics.dart` (create).
    *   `app/lib/widgets/avatar_marlix.dart` (modify).
    *   `app/test/widgets/avatar_physics_test.dart` (create).
    *   `docs/avatar.md` and `docs/decisions.md` (modify: the thresholds and why).
*   **Acceptance criteria:** criteria 1 to 7 of the example in 10.5, with the frame check on the Galaxy S24 and the low-end AVD.
*   **Verification:** the four steps of the example in 10.5.

**V2-18. Avatar expressions.**

*   **Depends on:** V2-16, V2-03.
*   **Gate:** none.
*   **Files:**
    *   `app/lib/widgets/avatar_marlix.dart` and `app/lib/screens/chat/avatar_controller.dart` (modify).
    *   `app/assets/avatars/marlix/` (create: one SVG layer per expression, named in the layer table of `docs/avatar.md`, which this task updates).
    *   `app/pubspec.yaml` (modify only if the asset list needs it).
    *   `app/test/avatar/avatar_marlix_test.dart`, `app/test/avatar/marlix_layers_test.dart`, `app/test/screens/avatar_events_test.dart` (modify).
    *   Outside the repository: if V2-03 did not apply, a closed track in Play Console with 5 invited testers (recorded only as counts in `docs/decisions.md`).
*   **Acceptance criteria:**
    1.  Each of listening, thinking, speaking and reacting uses a different set of SVG layers.
    2.  With reduced motion on, expressions change without animation.
    3.  A missing layer leaves a gap and not an error, as today.
    4.  In profile mode, the avatar renders at 60 fps on the Galaxy S24 and on the low-end AVD.
    5.  4 of 5 testers answer «Sí» to «¿Sentís que Marlix está vivo?» (goal G3). The testers are those of the closed track of V2-03, or of the track in "Outside the repository".
*   **Verification:** `flutter test`; screenshots of each state on the emulator; frame times in profile mode; the testers' answers recorded as counts in `docs/decisions.md`.

**V2-19. Appearance picker.**

*   **Depends on:** V2-15.
*   **Gate:** none.
*   **Working method:** `ui-ux-pro-max` (section 4).
*   **Files:**
    *   `app/lib/screens/my_marlix/appearance_screen.dart` (create).
    *   `app/lib/widgets/avatar_marlix.dart` (modify: palette, pattern and accessory layers).
    *   `app/assets/avatars/marlix/accessories/` (create: the accessory SVGs, named in the layer table of `docs/avatar.md`).
    *   `app/pubspec.yaml` (modify: the asset folder).
    *   `app/lib/services/avatar_look.dart` (create: saved on the device with `shared_preferences`, and serialized as the choice IDs the Sala profile publishes).
    *   `app/test/screens/appearance_test.dart`, `app/test/services/avatar_look_test.dart` (create).
    *   `docs/avatar.md`, `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  Palette, pattern and accessories change the avatar immediately.
    2.  The look survives closing and reopening the app.
    3.  After a reinstall the avatar has its default look.
    4.  No photo is read or uploaded.
    5.  The look can be serialized as choice IDs and drawn again from them (used by V2-25).
    6.  The `ui-ux-pro-max` deliverables are attached.
*   **Verification:** `flutter test`; on the emulator, stop the app with `adb shell am force-stop` and reopen it to see the look kept, then uninstall and reinstall it to see the default look.
*   **Notes:** the look is saved on the phone (owner decision) and is kept when the app is closed and opened again (G4). This needs no new endpoint or migration. A reinstall, or another phone, starts from the default look.

**V2-20. Voices with samples and the microphone permission.**

*   **Depends on:** V2-15, V2-08 (`VOICE_BUDGET_EXHAUSTED`).
*   **Gate:** none.
*   **Working method:** `ui-ux-pro-max` (section 4).
*   **Files:**
    *   `app/lib/screens/voice/voice_picker_screen.dart` (create).
    *   `app/assets/voice-samples/F1.wav` to `F5.wav` and `M1.wav` to `M5.wav` (create: ten short samples generated with the existing engine during development).
    *   `app/pubspec.yaml` (modify).
    *   `app/lib/models/voice_config.dart`, `app/lib/services/voice/voice_providers.dart`, `app/lib/services/voice/voice_service.dart` (modify: use the chosen voice).
    *   `app/lib/services/voice/native_voice_engine.dart` (modify: the fallback while the model downloads and on low-end phones).
    *   `app/lib/services/microphone_permission.dart` (modify: ask on the first tap of the voice button and handle denial).
    *   `app/lib/services/marlix_api.dart` (modify: map `VOICE_BUDGET_EXHAUSTED` to a new exception).
    *   `app/lib/services/api_exception.dart` (modify): the new `VoiceBudgetExhaustedException`, carrying `resetsAt`.
    *   `app/lib/services/voice/speech_recognizer.dart` (modify): a new `SpeechFailure.voiceBudget`, and `SpeechException` carries an optional `resetsAt`.
    *   `app/lib/services/voice/server_speech_recognizer.dart` (modify): maps `VoiceBudgetExhaustedException` to `SpeechException(SpeechFailure.voiceBudget)` with its `resetsAt`, instead of `SpeechFailure.other`.
    *   `app/lib/screens/voice/speech_controller.dart` (modify): on `voiceBudget`, records `resetsAt` in a new `voiceBudgetProvider`.
    *   `app/lib/screens/chat/chat_screen.dart` (modify): hides the voice button while `voiceBudgetProvider` holds a `resetsAt` in the future.
    *   `app/lib/screens/voice/voice_mode_screen.dart` (modify): ask for the microphone on the first tap of the voice button and handle denial; a Spanish hint for `voiceBudget` that points to text chat.
    *   `app/test/services/voice/server_speech_recognizer_test.dart`, `app/test/screens/voice_controller_test.dart`, `app/test/services/voice/voice_service_test.dart`, `app/test/screens/voice_mode_test.dart` and `app/test/screens/chat_screen_test.dart` (modify).
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  The picker lists ten voices, and each plays its sample.
    2.  The chosen voice is used in voice mode.
    3.  The system voice is used until the model is downloaded.
    4.  Denying the microphone leaves the app usable with text and explains how to turn it on.
    5.  A `VOICE_BUDGET_EXHAUSTED` answer hides the voice button and leaves text working.
    6.  The `ui-ux-pro-max` deliverables are attached.
*   **Verification:** `flutter test`; listen to all ten samples on the Galaxy S24; deny and then grant the permission on the emulator.

**V2-21. Games.**

*   **Depends on:** V2-15.
*   **Gate:** none.
*   **Working method:** `ui-ux-pro-max` (section 4).
*   **Files:**
    *   `app/lib/screens/practice/practice_screen.dart` (create: the «Practicar» tab).
    *   `app/lib/screens/practice/breathing_game.dart` and `app/lib/screens/practice/what_changed_game.dart` (create).
    *   `app/test/screens/practice_test.dart` (create).
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  The «Practicar» tab offers a breathing exercise led by the avatar, with vibration and a text alternative.
    2.  «¿Qué cambió en Marlix?» changes one avatar layer for the person to find.
    3.  Neither game shows a streak or claims to improve memory or health.
    4.  The `ui-ux-pro-max` deliverables are attached.
*   **Verification:** `flutter test`; both games with TalkBack and with reduced motion on.

#### The Sala (M4)

None of these tasks blocks the launch. The Sala code is compiled only into the Sala AAB (`--dart-define=SALA_ENABLED=true`). Conditions A to F are those of "Sala de Marlix: scope".

**V2-22. Sala data model.**

*   **Depends on:** V2-05a, V2-07.
*   **Gate:** none.
*   **Files:**
    *   `docs/migrations/YYYY-MM-DD-room.sql` (create): the tables of the data model table in 3.6 (`room_profiles` with `avatar_look jsonb`, `room_messages`, `room_blocks`, `room_reports` with `message_snapshot`, `priority` and `reporter_visible_at`, `room_actions`, `room_help_requests` and `room_help_daily`), with `uuid` keys referencing `auth.users`, RLS on and no client policy; a function `room_visible_messages(viewer uuid, after_id bigint)` that applies blocks (never hiding a member from the host or a moderator), removals and the viewer's own reports; cascades from the user, except `room_reports.target_user_id` and `room_actions.target_user_id`, which are `ON DELETE SET NULL`.
    *   `docs/schema.sql`, `docs/verify-migrations.sql`, `docs/schema-test.sql`, `docs/erd.md` (modify).
*   **Acceptance criteria:**
    1.  Two blocked members never see each other's messages.
    2.  A member who blocks a moderator stops seeing the moderator's messages, while the moderator keeps seeing theirs.
    3.  A removed message is hidden.
    4.  A message a person reported is hidden from that person only.
    5.  Clients can read no Sala table.
    6.  Deleting an account removes its profile and `avatar_look`, messages, blocks, help requests and reports as reporter.
    7.  Reports and actions about a deleted person keep their snapshot, with `target_user_id` set to null, until `purge_at`.
*   **Verification:** `docs/schema-test.sql` against the Docker Postgres; a staging run with two accounts.

**V2-23. Sala blocking, reporting and moderation.**

*   **Depends on:** V2-22.
*   **Gate:** none.
*   **Files:**
    *   `api/src/routes/room.ts` (create: blocks, reports, `GET /v1/room/reports/mine` and the moderator endpoints; mounted under `/v1` after `requireSession`).
    *   `api/src/services/room/room-store.ts` (create: the interface) and `api/src/services/room/supabase-room-store.ts` (create: its implementation).
    *   `api/src/services/room/moderation.ts` (create).
    *   `api/src/services/room/access.ts` (create: the flag, `expelled_at`, `muted_until` and role checks on every request).
    *   `api/src/server.ts` (modify: build the room store).
    *   `api/src/app.ts` (modify: the room store in `AppDependencies`).
    *   `api/test/helpers.ts` (modify: `startApp` passes a fake room store).
    *   `docs/api-contract.md` (modify).
    *   `api/test/room-blocks.test.ts` and `api/test/room-moderation.test.ts` (create).
*   **Acceptance criteria:**
    1.  Blocking hides both people within one poll, except for the host and moderators (V2-22).
    2.  A report hides the message from the reporter at once, stores a snapshot of its text, and reaches only moderators.
    3.  Two reports from two different accounts raise the case's priority, and never remove the message for others.
    4.  Only a moderator can remove, mute and expel; each action is recorded in `room_actions` and takes effect at once.
    5.  The penalized person sees the rule applied, and never the time of the report or the reporter.
    6.  A resolution becomes visible to the reporter only at the next daily batch.
    7.  An expelled person, or one removed from `feature_flag_users`, gets `404` from every Sala endpoint at their next request.
    8.  Every endpoint answers `404` when the flag is off for the account.
*   **Verification:** `npm test`; a staging rehearsal with cases of harassment, a threat and explicit content (condition B of "Sala de Marlix: scope").

**V2-24. Sala message path.**

*   **Depends on:** V2-23, V2-08, V2-12a.
*   **Gate:** Q15; Q16.
*   **Files:**
    *   `api/src/services/room/room-policy.ts` (create: one replaceable policy holding the decisions of Q15 and Q16).
    *   `api/src/services/room/message-service.ts` (create: access and rules checks, the per-person rate limit on the `usage-limiter` pattern, layer 1, its own crisis filter, built with `createCrisisFilter` over the `classifier_room` instance, the consent question, then the write with the service role).
    *   `api/src/routes/room.ts` (modify: `GET /v1/room/messages?after=<id>`, `POST /v1/room/messages` and `POST /v1/room/help-requests`).
    *   `api/config/room-topics.json` and `api/config/room-rules.json` (create).
    *   `api/src/services/crisis/filter.ts` (verify only: `createCrisisFilter` already takes its own resolver).
    *   `api/src/services/retention/retention-job.ts` (modify: 7-day messages except those with an open report, and reports 30 days after resolution).
    *   `api/src/server.ts` (modify: the retention job receives the room store).
    *   `api/src/app.ts` (modify: the Sala's crisis filter over `classifier_room` and the message service).
    *   `api/test/helpers.ts` (modify).
    *   `api/src/config/env.ts` and `api/.env.example` (modify).
    *   `docs/api-contract.md` (modify).
    *   `api/test/room-messages.test.ts` and `api/test/room-retention.test.ts` (create).
*   **Acceptance criteria:**
    1.  Every message passes layer 1 and, if ambiguous, the Sala classifier before it is written.
    2.  A Sala classifier call moves only the `classifier_room` counter.
    3.  A distress message is never penalized; its author receives the private help response and the consent question.
    4.  Only «Sí» creates a help request, without the message text.
    5.  «No», or no answer, sends nothing to the host and only adds to the anonymous daily count.
    6.  With the Sala's pool used up, an ambiguous message is held, and its author receives the help lines in private and a note that it was not published.
    7.  With the Sala's pool used up, a message with no signal is still published.
    8.  With the Sala's pool used up, the `classifier_chat` counter does not change.
    9.  The rate limit refuses a burst.
    10. With the ledger down, the Sala is read-only.
    11. Messages older than 7 days are deleted unless a report on them is open.
    12. `room-policy.ts` implements the Q15 and Q16 decisions recorded in `docs/decisions.md`, and a test covers each decision.
*   **Verification:** `npm test`; the Sala cases of `npm run crisis:eval`, including a «No» answer that sends nothing to the host (condition D of "Sala de Marlix: scope"); a staging run with a tiny Sala pool to see the held path.

**V2-25. Sala screens.**

*   **Depends on:** V2-24, V2-15, V2-19.
*   **Gate:** none.
*   **Working method:** `ui-ux-pro-max` (section 4).
*   **Files:**
    *   `app/lib/screens/room/room_screen.dart` (create: the class `RoomScreen`), `app/lib/screens/room/room_rules_screen.dart`, `app/lib/screens/room/room_profile_sheet.dart` (create).
    *   `app/lib/services/room_poller.dart` (create: polls every 3 seconds while the screen is visible and stops in the background) and `app/lib/models/room.dart` (create).
    *   `app/lib/services/marlix_api.dart` (modify).
    *   `app/lib/screens/practice/practice_screen.dart` (modify: the entry, compiled only with `SALA_ENABLED=true` and shown only when `flags.social_room` is true).
    *   `app/test/screens/room_test.dart` and `app/test/services/room_poller_test.dart` (create).
*   **Acceptance criteria:**
    1.  The rules and terms must be accepted before writing.
    2.  Participants appear with their nickname and an avatar drawn from their `avatar_look`.
    3.  Suggested topics appear and can be ignored.
    4.  Every message and profile offers the block and report actions.
    5.  After a help response, the consent question appears.
    6.  The help button is visible at all times.
    7.  A removed, blocked or reported message disappears from an open client within one poll.
    8.  With the flag off there is no entry and no mention.
    9.  S3 of the "Sala track delivery test" passes, and P2 finds no `RoomScreen` in a locally built production AAB.
    10. The profile never contains a photo.
    11. The `ui-ux-pro-max` deliverables are attached.
*   **Verification:** `flutter test`; P2 and S2 of section 5 on locally built AABs; two emulators, or one emulator and the Galaxy S24, on staging with the Sala AAB.

**V2-36. Moderator view and notices.**

*   **Depends on:** V2-23, V2-25.
*   **Gate:** Q19 (who the moderators are).
*   **Working method:** `ui-ux-pro-max` (section 4).
*   **Files:**
    *   `app/lib/screens/room/room_moderation_view.dart` (create: the «Reportes» view, shown only to the `host` and `moderator` roles, with two-report cases first, the snapshot of each reported message, the actions, the help requests and the anonymous counts of completed days).
    *   `app/lib/services/marlix_api.dart` (modify).
    *   `api/src/routes/room.ts` (modify: `GET /v1/room/moderation/help`).
    *   `docs/api-contract.md` (modify).
    *   `app/test/screens/room_moderation_test.dart` (create).
    *   `api/test/room-moderation.test.ts` (modify).
*   **Acceptance criteria:**
    1.  Only `host` and `moderator` see the view.
    2.  Cases with two reports come first.
    3.  An action from the view takes effect at once.
    4.  A help request shows no message text.
    5.  The view shows help counts only for completed days.
    6.  v0.2 sends no push or email for moderation (condition C of "Sala de Marlix: scope").
*   **Verification:** `flutter test`; `npm test`; a staging rehearsal with the host.

**V2-26. Sala safety and privacy tests.**

*   **Depends on:** V2-24, V2-25, V2-36.
*   **Gate:** C8 (the host); Q18 (Play's requirements); Q19 (moderators and rules).
*   **Files:**
    *   `api/test/room-privacy.test.ts` (create: a Sala message never reaches the chat history, the prompt or the extractor; the reporter and the report time are never exposed; deleting the account deletes the messages and the profile).
    *   `api/test/room-crisis.test.ts` (create: condition D).
    *   `docs/crisis-protocol.md` (modify: the Sala section).
    *   `docs/decisions.md` (modify: Q15, Q16, Q18 and the state of conditions A to F).
    *   **at the start of the beta, not before:** `site/privacy.html` and `site/delete-account.html` (modify).
*   **Acceptance criteria:**
    1.  Conditions A to F of "Sala de Marlix: scope" are checked one by one and recorded.
    2.  The Play help pages named in Q18 are read, and the answer is recorded.
    3.  The "Sala track delivery test" (section 5, S1 to S3) passes and is recorded before the first invitation.
    4.  The Sala AAB is on the internal track.
    5.  The privacy policy is updated before the first invitation.
*   **Verification:** `npm test`; a manual rehearsal with the host on staging, including a check that the timing of notices does not point to a reporter; the Play Console answer for Q18 recorded.

#### Experiments and optional work (M1, M2 and M4)

**V2-27. Medical-urgency layer.**

*   **Depends on:** V2-07.
*   **Gate:** C7. The code can be written and left off; the flag is switched on only after the review.
*   **Files:**
    *   `api/src/services/crisis/medical-urgency.ts` (create: deterministic patterns).
    *   `api/config/medical-urgency.json` (create: the list and the response text, reviewed as data).
    *   `api/src/config/medical-urgency-config.ts` (create: validation like `crisis-config.ts`).
    *   `api/src/services/chat-service.ts` (modify).
    *   `docs/crisis-protocol.md` (modify).
    *   `docs/decisions.md` (modify: the review record).
    *   `api/test/medical-urgency.test.ts` (create).
*   **Acceptance criteria:**
    1.  With the flag off, nothing changes.
    2.  With it on, each listed signal answers with the medical-urgency text and the help lines, with no model call.
    3.  The review by a health professional is recorded before the flag is switched on.
*   **Verification:** `npm test`; `npm run crisis:eval` unchanged; the professional's sign-off.

**V2-28. Model comparison harness.**

*   **Depends on:** none.
*   **Gate:** the owner supplies a test key; C12.
*   **Files:**
    *   `api/scripts/model-compare.ts` (create: runs the same conversations through each candidate through an OpenAI-compatible client, records time to the first sentence, cost with and without caching, and the cache rate).
    *   `api/test/fixtures/synthetic-conversations.json` (create: 30 synthetic Spanish conversations of 8 turns, with no real data).
    *   `api/package.json` (modify: a script `llm:compare`).
    *   `docs/decisions.md` (modify: the result). No DeepSeek adapter enters `api/src/` unless the test passes.
*   **Acceptance criteria:**
    1.  The candidate wins at least 2 of 3 blind pairs (section 7).
    2.  The median first-sentence time is at most 300 ms slower than Groq.
    3.  The expected cost fits the chat sub-cap of section 6.
    4.  The result against these criteria (section 7) is recorded.
*   **Verification:** run the script from the owner's machine; a blind ranking by the owner and 2 or 3 testers; the cost compared with the console.
*   **Notes:** the fixed charge recorded for its cash month is the smallest DeepSeek top-up, and the test is postponed if that is above USD 8.00 (section 6). Synthetic data only; expected usage of USD 2.05 before tax (2.32 with VAT).

**V2-29. Feasibility spikes.**

*   **Depends on:** none.
*   **Gate:** C12, for spike (b).
*   **Files:**
    *   `docs/decisions.md` (modify: one entry for each spike with its result against the criteria of section 7). Results only.
*   **Acceptance criteria:**
    1.  (a) ARCore: the avatar stands on a detected floor and table on the Galaxy S24 and on a second ARCore-supported phone whose model is recorded with the result, and the Flutter plugin chosen is named.
    2.  (b) Object to 3D: 20 captures of the owner's own objects (never of people) are converted to 3D, the result is recorded, and the expected usage stays at or below USD 3 before tax.
    3.  (c) Voices: 5 phrases are rendered by each candidate, ranked in a blind listening, and the ranking is recorded.
*   **Verification:** the spikes live on `docs/` branches (per `CONTRIBUTING.md`, spikes use the `docs/` prefix) and their code is not merged.
*   **Notes:** results only; no feature code is merged. For (b), the fixed charge recorded for its cash month is the smallest pack or deposit of the provider used, and the spike is postponed if that is above USD 8.00.

**V2-30. Photo-to-skin experiment.**

*   **Depends on:** V2-19, V2-29.
*   **Gate:** the experiment result.
*   **Files:**
    *   `app/lib/services/skin_from_photo.dart` (create: palette and pattern extracted on the device; the photo is neither stored nor uploaded).
    *   `app/lib/screens/my_marlix/appearance_screen.dart` (modify: an entry shown only when `flags.photo_skin` is true).
    *   `app/test/services/skin_from_photo_test.dart` (create).
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  With the flag off, nothing is shown.
    2.  The photo never leaves the device.
    3.  4 of 5 testers recognize the skin as theirs.
*   **Verification:** `flutter test`; a network capture on the emulator shows no photo upload.

#### Launch (M5)

**V2-31. Release preparation.**

*   **Depends on:** V2-06a, V2-11, V2-13 to V2-21, V2-37.
*   **Gate:** Q13 (how people moving from the GitHub APK are told to uninstall).
*   **Files:**
    *   `app/pubspec.yaml` (modify: the version, with a larger `versionCode` than `0.1.2+3`).
    *   `CHANGELOG.md`, `README.md`, `docs/architecture.md`, `docs/erd.md`, `docs/api-contract.md` (final pass).
    *   `docs/play-store/listing.md` and `docs/play-store/screenshot-*.png` (modify: the new description and screenshots, **no mention of the Sala**, and the uninstall notice).
    *   `docs/release-notes/v0.2.0.md` (create: the release notes, with the same notice).
    *   `site/index.html`, `site/privacy.html`, `site/delete-account.html`, `site/updates.html` (check; modify for the new processors).
    *   `docs/decisions.md` (modify).
*   **Acceptance criteria:**
    1.  Launch criterion 8: the privacy policy, the data safety form and the health declaration are updated.
    2.  Every feature named in the listing is present in the production AAB, and no feature of the Sala is named.
    3.  The uninstall notice is in the listing and in the release notes (Q13).
    4.  `README.md`, `docs/architecture.md`, `docs/erd.md` and `docs/api-contract.md` match the merged code of v0.2.
*   **Verification:** links and anchors checked; the policy compared with the code, as in the S8-2 decision (the Play listing and privacy pages); `git diff --check`.

**V2-32. Compatibility test with v0.1 clients.**

*   **Depends on:** V2-07, V2-11, V2-13.
*   **Gate:** none.
*   **Files:** `api/test/legacy-clients.test.ts` (modify: a final pass over every endpoint changed in v0.2).
*   **Acceptance criteria:**
    1.  v0.1 requests still succeed.
    2.  A new field in a response never breaks them.
    3.  The step-down answers `DAILY_LIMIT_REACHED`, which v0.1 shows as its usual limit message; `VOICE_BUDGET_EXHAUSTED` shows v0.1's generic error on voice, and text keeps working (launch criterion 9).
*   **Verification:** `npm test`; install the v0.1 APK on the emulator and chat against staging.

**V2-33. Release checks and publication.**

*   **Depends on:** V2-03, V2-05b, V2-10, V2-12b, V2-31, V2-32, V2-35.
*   **Gate:** C1; C3 (through V2-06a).
*   **Files:**
    *   `status.md` (modify).
    *   `docs/release-notes/v0.2.0.md` (modify: final).
    *   Outside the repository: Play Console (an internal app sharing install, the closed-test result, Play App Signing, data safety, content rating, target audience and the health declaration) and a GitHub Release with the signed APK.
*   **Acceptance criteria:**
    1.  Launch criteria 1 to 11 of section 8 are met.
    2.  The production AAB is built with `SALA_ENABLED=false`.
    3.  The "Production build check" (section 5, P1 and P2) passes with this release's production AAB; no Sala AAB or Sala task is needed.
    4.  The first publication goes to production.
*   **Verification:** the criteria checklist in `status.md`; the results of the production build check recorded in `docs/decisions.md`; `GET /health`, `/health/spend` and `/health/safety` answer `ok` after publication; the first 24 hours are watched through the health endpoints, the spend ledger and Play's crash reports.

### Verification Plan

*   **Compilation/Build:** `npm run build` in `api/`; `flutter build apk --release --dart-define-from-file=config/production.json` for the production build check (with `SALA_ENABLED=false`); the production AAB for Play; the Sala AAB with `SALA_ENABLED=true` for the internal track while the beta runs.
*   **Unit tests:** `npm test` in `api/`; `flutter test` in `app/`.
*   **Static analysis and linting:** `npm run typecheck` in `api/`; `dart format --output=none --set-exit-if-changed lib test integration_test` and `flutter analyze` in `app/` (the same steps the CI runs); the crisis asset check (`npm run crisis:export`, V2-37); CodeQL runs on every pull request but is not a required check yet (S8-1, the CodeQL card).
*   **Database:** the Docker Postgres runs `docs/schema-test.sql`; the CI applies `docs/schema.sql` and `docs/verify-migrations.sql`; in production the owner runs `docs/verify-migrations.sql` after each migration and every row must say `ok`.
*   **Safety:** `npm run crisis:eval` before and after any change to the classifier, its model or its quota; the phone's layer 1 tests (V2-37).
*   **Contract:** `api/test/legacy-clients.test.ts` in CI from V2-07.
*   **Test coverage requirement:** the repository enforces no coverage percentage today. The requirement here is that every acceptance criterion has at least one automated test or one manual step written in its task, with the evidence ticked.
*   **E2E and integration:** the app against staging on the emulator, the low-end AVD and the Galaxy S24 (confirm with the owner that the phone is available); the release build is tested, not only the debug build; the production build check of section 5 runs at each release, and the Sala track delivery test runs before the beta and at the first release while the beta is live; the v0.1 APK is tested against the new backend.
*   **Cost:** after any change that adds or alters a model call, the ledger shows the new use, `api/config/llm-prices.json` is correct, and the budget table in section 6 is updated; the reconciliation of `docs/spend-reconciliation.md` runs weekly in the first month and monthly afterwards (V2-10).
