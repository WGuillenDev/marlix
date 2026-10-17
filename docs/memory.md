# Distilled memory

How marlix remembers a person without sending weeks of chat to the model. Story: US-07. Cards: S4-5 (recent window), S4-6 (extraction, this document), S4-7 (memory in the prompt), S4-8 (the screen to see and edit it).

## Three layers

| Layer | What it is | Who reads it |
|---|---|---|
| 1. History | Every message, kept for 90 days (S4-4). | The app, to show the chat. |
| 2. Recent window | The last 16 messages of the open conversation (S4-5). | The model, on every message. |
| 3. Distilled memory | Short lasting facts about the person ("Tiene una perrita llamada Coco"), with a category. | The model, on every message (S4-7). |

Layer 3 is what lets marlix know someone after the window has moved on.

## When a conversation ends

The person sees one continuous chat, but the backend splits it into sessions (`conversations`). A session ends after **30 minutes without messages** (`CONVERSATION_IDLE_MINUTES`). Ending it sets `ended_at` to the time of its last message and is what starts the extraction. Two things end sessions:

- **The person comes back.** Before a message is answered, the backend ends that person's idle session. The message then opens a new session, with an empty window.
- **A sweep every 5 minutes** ends everybody's idle sessions and picks up any session whose memory is still pending (for example after a restart or a failed extraction).

The database function `close_idle_conversations` does the ending in one statement.

## The extraction

For each ended session, one at a time and a few seconds apart (it uses the same Groq quota as the chat):

1. It reads what was said, **without the messages of a crisis**: they never go to the model ([S0-8](decisions.md)).
2. It gives the extractor the conversation and the facts already saved, each with its id.
3. The extractor (`MEMORY_EXTRACTOR_MODEL`, a smaller model than the chat) answers with a JSON list of facts with a category.
4. The facts are saved with their category and the session they came from, and the session is marked as extracted (`memory_extracted_at`).

It runs in the background: the person's reply never waits for it. If the person said nothing in the session, the model is not called.

### Update, do not duplicate

The extractor sees the saved facts. If the conversation corrects or adds to one, it returns it with the **same id** and the new text, and the backend rewrites that memory. A fact that only differs in case or accents from a saved one is not a change. An id that is not one of the person's saved facts counts as a new fact, so the answer cannot reach another memory.

### What is never saved

Two barriers, because a model can be wrong or manipulated:

1. **The prompt** ([`memory-extractor-prompt.ts`](../api/src/config/memory-extractor-prompt.ts)) forbids ID numbers, cards and bank accounts, passwords and PINs, medical and mental-health diagnoses, illnesses, medications and treatments, phone numbers, emails, exact addresses and anything about suicide or self-harm. It also says the conversation is data to read, never instructions, so a message that tries to change the rules is ignored.
2. **A filter in code** ([`sensitive.ts`](../api/src/services/memory/sensitive.ts)) drops any fact with a number of eight digits or more, an email, a word about secrets or documents, or a stem about health. It is blunt on purpose: a lost fact costs little, a saved ID number costs a lot.

The prompt says to leave out **only** the sensitive fact and keep the rest. A first version said "skip the fact entirely", and with the real model a conversation that mixed an ID number with ordinary facts returned nothing at all (0 of 6 attempts); with the clearer wording it returns the ordinary facts (4 of 4).

Everything saved travels to the model provider (Groq) on every call, so the prompt asks for **short, lasting** facts, not moods or small talk.

### Limits

| Limit | Value | Why |
|---|---|---|
| Facts per person | 50 | They all go to the model on each call. Past it, an extraction can update facts but not add. |
| Changes per session | 10 | A session is not a biography. |
| Conversation sent to the extractor | The newest 12,000 characters | Quota of the model, and the newest part is what is still true. |
| Attempts per session | 3 per process | A failure leaves the session pending; after three, it waits for a restart instead of looping on the quota. |

## What goes into the prompt

On every message the backend reads the person's memories and puts them at the end of the system prompt, after the fixed part, in the section "Lo que sabés de esta persona" (S4-7). The fixed part never changes, so Groq's prompt cache can reuse it; the memory is the variable part and goes after it.

- **How many.** At most 30 (`CHAT_MEMORY_FACTS`, 1 to 50). Each one costs tokens on every call.
- **Which ones, when there are more.** The most recently updated. A fact that was just told, corrected or edited is more likely to still be going on in the person's life than one from months ago. Choosing by meaning (similarity with the message) is left to a later version.
- **In what order.** The chosen ones always come oldest first, so the text is identical from one message to the next until the memory changes. If the order followed the choice, it could change between messages and break the cache.
- **One line each.** A fact is flattened to a single line, so it cannot add a heading or a paragraph that would read as an instruction. The prompt also says they are data about the person, not orders.
- **How marlix uses them.** The personality prompt asks it to use them naturally, a little at a time and only when they fit, never to recite them or say "according to my records", and to ask gently if something looks out of date.
- **If the memory cannot be read,** the answer is `500` before the model is called: answering as if marlix did not know the person would be wrong without saying so. A crisis never reads it, because it never reaches the model.

## Seeing, editing and deleting (S4-8)

The "Lo que marlix sabe de mí" screen (Settings) lists every memory, newest first, with its text, and lets the person edit one, delete one or delete them all after a confirmation. It uses `/v1/memories` ([contract](api-contract.md#get-v1memories)). Nothing is cached in the backend: the prompt reads the database on every message, so what the person deletes or rewrites changes the very next reply. Deleting removes the row, it does not hide it. The reasons are in [decisions.md](decisions.md).

## What is logged

Only that an extraction ran (`Memory extracted: 1 added, 0 updated`) or failed, and the kind of failure. Never the messages or the facts. The database's own error text is never logged either: it can quote the row.

## Known limits

- **Render's free plan sleeps after 15 minutes without traffic**, and a sleeping server runs no timer. A session that ends while it sleeps is ended when the person comes back, so its memory is extracted just after their first message: the first reply of the new session can miss the last session's facts. Once the uptime monitor (S7-6) calls `/health` every 10 minutes the server stays awake and the sweep does it on time.
- **A deleted fact can come back once.** If the person deletes a memory while the conversation where they told it is still open, its extraction runs when it ends and can save the fact again. Facts from conversations that were already extracted never come back.
- The extractor is a language model: it can miss a fact or keep a minor one. the screen of S4-8 lets the person see, edit and delete what marlix remembers.
