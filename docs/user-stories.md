# User stories — v1

User stories for the marlix MVP. Every feature in the v1 scope is backed by at least one story, and every backlog card traces back to a story.

**Roles**

- **User**: a person who uses marlix for companionship. v1 has a single user type (no paid plan).
- **System**: behavior the app or backend performs on its own, without a direct user action.

**Priority** uses MoSCoW: **Must** (no MVP without it), **Should** (important, not blocking), **Could** (nice to have).

## Summary

| ID | Story | Role | Priority |
|---|---|---|---|
| US-01 | Sign up and sign in | User | Must |
| US-02 | First-time onboarding | User | Must |
| US-03 | Text chat with marlix | User | Must |
| US-04 | Crisis response | System | Must |
| US-05 | Help screen | User | Must |
| US-06 | Conversation history | User | Must |
| US-07 | marlix remembers me | System | Must |
| US-08 | See and manage what marlix knows | User | Must |
| US-09 | Delete my account | User | Must |
| US-10 | Daily usage limit | User / System | Must |
| US-11 | Voice conversation | User | Must |
| US-12 | Interrupt the avatar | User | Should |
| US-13 | Animated avatar | User | Must |
| US-14 | Inactivity reminders | User | Should |
| US-15 | Clear errors and waiting states | User | Must |

---

## US-01 — Sign up and sign in

**As a** user **I want** to create an account and sign in **so that** my conversations and memories are private and available only to me.

**Priority:** Must

**Acceptance criteria**
- [ ] I can sign up with email and password
- [ ] I can sign in and my session persists after closing the app
- [ ] I can sign out
- [ ] Wrong credentials show a clear error message, without revealing whether the email exists

---

## US-02 — First-time onboarding

**As a** new user **I want** marlix to introduce itself and explain how it works **so that** I know what to expect and agree to how my data is used.

**Priority:** Must

**Acceptance criteria**
- [ ] The avatar introduces itself with a welcome animation
- [ ] A notice states that marlix is not therapy and does not replace professional care
- [ ] It explains what data is stored and asks for explicit consent before continuing
- [ ] It asks for microphone permission and explains what it is for
- [ ] It offers to turn on inactivity reminders (US-14); saying no has no consequences
- [ ] It shows how to reach the help screen (US-05)
- [ ] It is shown only once per account

---

## US-03 — Text chat with marlix

**As a** user **I want** to chat with marlix by text **so that** I have company and someone to talk to whenever I need it.

**Priority:** Must

**Acceptance criteria**
- [ ] I can type a message and receive a reply
- [ ] While the reply is being generated, a "thinking" state is shown
- [ ] Replies are warm, close and use soft Costa Rican expressions without caricature
- [ ] marlix never diagnoses, prescribes or presents itself as a therapist
- [ ] marlix encourages me to connect with people in my life
- [ ] Under normal conditions, the reply appears in less than 5 seconds

---

## US-04 — Crisis response

**As the** system **I want** to detect risk signals before the message reaches the model **so that** nobody in crisis is left without real help.

**Priority:** Must

**Acceptance criteria**
- [ ] Every message is classified before the model as risk, ambiguous or normal
- [ ] A message with a clear risk signal never leaves the backend
- [ ] An ambiguous message is only sent to an isolated classification (no history, no memory), never to the conversation
- [ ] When in doubt, or if the classification fails, the crisis protocol is triggered
- [ ] The crisis reply is a fixed text that points to 9-1-1, with a button that dials directly
- [ ] The activation is logged without storing the message content

---

## US-05 — Help screen

**As a** user **I want** a help screen I can reach at any moment **so that** I know where to turn if I am not okay.

**Priority:** Must

**Acceptance criteria**
- [ ] It is reachable from the chat and from voice mode in one tap
- [ ] It shows 9-1-1 (free, 24/7) as the main option, with a button that dials directly
- [ ] It lists other Costa Rican resources, loaded from configuration, not hardcoded
- [ ] It clearly states that marlix does not replace professional care

---

## US-06 — Conversation history

**As a** user **I want** to see my previous messages when I open the app **so that** I can pick up the conversation where I left off.

**Priority:** Must

**Acceptance criteria**
- [ ] When I open the chat, my recent messages are loaded
- [ ] Messages are stored on the server, not only on the phone
- [ ] Raw messages are kept for 90 days and then deleted automatically

---

## US-07 — marlix remembers me

**As the** system **I want** to extract key facts from each conversation **so that** marlix knows the user without resending weeks of chat.

**Priority:** Must

**Acceptance criteria**
- [ ] When a conversation ends, key facts and summaries are extracted in the background
- [ ] The distilled memory is added to the system prompt of later conversations
- [ ] Only the most recent 15 to 20 messages are sent to the model on each call
- [ ] Sensitive data is never stored in the distilled memory (ID numbers, cards, diagnoses)

---

## US-08 — See and manage what marlix knows

**As a** user **I want** a screen that shows what marlix remembers about me **so that** I stay in control of my information.

**Priority:** Must

**Acceptance criteria**
- [ ] A "What marlix knows about me" screen lists every stored memory
- [ ] I can edit a memory
- [ ] I can delete a single memory or all of them
- [ ] Deleted memories are no longer used in later conversations

---

## US-09 — Delete my account

**As a** user **I want** to delete my account for real **so that** no trace of my data remains.

**Priority:** Must

**Acceptance criteria**
- [ ] I can delete my account from settings, after a confirmation step
- [ ] Deletion removes all my data in cascade: messages, memories, usage and profile
- [ ] After deletion I cannot sign in with that account

---

## US-10 — Daily usage limit

**As a** user **I want** to know how many interactions I have left today **so that** the shared free quota is not a surprise.

**As the** system **I want** to cap interactions per user **so that** one person, or a bug, cannot use up the quota for the whole family.

**Priority:** Must

**Acceptance criteria**
- [ ] Each user has a daily cap of interactions (text or voice), 100 by default, read from configuration
- [ ] The app shows how many interactions are left today
- [ ] When the cap is reached, a friendly message explains when it resets; the help screen stays available
- [ ] Voice generation on the phone does not count against the cap

---

## US-11 — Voice conversation

**As a** user **I want** to talk to marlix by voice and hear it answer **so that** it feels like a real conversation, like ChatGPT's voice mode.

**Priority:** Must

**Acceptance criteria**
- [ ] A full-screen voice mode shows the avatar
- [ ] The app detects when I stop talking; I do not need to press a button to send
- [ ] marlix answers with its own voice, generated on the phone
- [ ] The avatar starts speaking with the first sentence, before the full reply is ready
- [ ] Voice replies are short and conversational
- [ ] The crisis filter (US-04) applies exactly as in text chat
- [ ] Under normal conditions, marlix starts answering 1 to 2 seconds after I stop talking

---

## US-12 — Interrupt the avatar

**As a** user **I want** to interrupt marlix by talking **so that** the conversation flows naturally.

**Priority:** Should

**Acceptance criteria**
- [ ] If I start talking while marlix is speaking, it stops and listens
- [ ] The interrupted reply is still saved in the history

---

## US-13 — Animated avatar

**As a** user **I want** the avatar to react to the conversation **so that** it feels alive and close.

**Priority:** Must

**Acceptance criteria**
- [ ] The avatar has five states: idle, listening, thinking, speaking and happy
- [ ] While speaking, the mouth moves with the audio volume
- [ ] In idle it floats gently and blinks
- [ ] The animation runs smoothly on a mid-range Android phone

---

## US-14 — Inactivity reminders

**As a** user **I want** marlix to say hi when I have not opened the app for a while **so that** I remember it is there, without feeling pressured.

**Priority:** Should

**Acceptance criteria**
- [ ] Reminders are sent after 2, 5 and 10 days without opening the app, then they stop until I come back
- [ ] Messages never use guilt, streaks or day counters
- [ ] Messages never include my memories or personal data (they show on the lock screen)
- [ ] They are only active if I opted in, and I can turn them off in settings
- [ ] Tapping a reminder opens the chat

---

## US-15 — Clear errors and waiting states

**As a** user **I want** to know what is happening when something fails or takes long **so that** I am not left staring at a frozen screen.

**Priority:** Must

**Acceptance criteria**
- [ ] If the server is waking up, a "waking up" state is shown instead of an error
- [ ] If a message fails, I see a clear error and can retry without retyping it
- [ ] Without internet, the app says so and the help screen still works

---

## Traceability

| Story | Backlog cards |
|---|---|
| US-01 | S4-3 |
| US-02 | S5-5 |
| US-03 | S0-10, S1-3, S1-4, S1-5, S2-4, S3-2, S3-3 |
| US-04 | S2-1, S2-2, S2-3, S2-5, S2-7 |
| US-05 | S3-5, S7-7 |
| US-06 | S4-4, S4-10 |
| US-07 | S4-5, S4-6, S4-7 |
| US-08 | S4-8 |
| US-09 | S4-9 |
| US-10 | S2-6, S6-6 |
| US-11 | S6-1, S6-2, S6-3, S6-4, S6-7, S6-8, S6-10 |
| US-12 | S6-9 |
| US-13 | S5-1, S5-2, S5-4, S6-5 |
| US-14 | S5-3 |
| US-15 | S1-6, S3-4 |

Out of scope for v1 (see v2 cards): more avatars, choosing or renaming the avatar, paid plan, app store release.
