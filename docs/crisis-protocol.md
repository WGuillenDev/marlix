# Crisis protocol

What marlix does when a message shows a risk signal. This is the project's non-negotiable rule: **the crisis filter runs before the model**, and nobody in crisis is left without real help (US-04).

> **marlix is not therapy and does not replace professional mental health care.** The protocol does not try to handle a crisis in the chat: it points the person to someone who can help, starting with 9-1-1.

See also the [chat sequence](diagrams/chat-sequence.md), the [architecture](architecture.md#the-crisis-filter-comes-first) and the [API contract](api-contract.md#post-v1chat).

## Where it runs

Every message to `POST /v1/chat`, in text and in voice mode, goes through the filter **before** anything else is done with it. A crisis never reaches the conversation model.

The filter lives in code (`api/src/services/crisis/`), not in the system prompt: a model can be wrong or manipulated, and a rule in code cannot.

## The three outcomes

| Outcome | When | What happens |
|---|---|---|
| `risk` | The message has a clear risk signal ("me quiero morir", "quitarme la vida"). | The message never leaves the backend. The answer is the crisis reply. |
| `ambiguous` | The message has an indirect signal ("ya no aguanto más", "soy una carga"). | The [second layer](#the-second-layer) classifies only that message. If it says risk, fails, times out or answers anything unexpected, the answer is the crisis reply. |
| `normal` | No signal. | The message continues to the conversation with the model. |

When in doubt, the protocol is triggered: a false alarm is better than leaving someone without help.

## How messages are compared

Both the message and the signals are normalized the same way before comparing, so these do not change the result:

- Uppercase and lowercase.
- Accents and `ñ` (`daño` → `dano`).
- Punctuation and emoji.
- Look-alike characters (`m4t4rme` → `matarme`).
- Stretched letters (`moriiiir` → `morir`).

Signals match as whole words, so a word inside another word does not trigger them. A signal ending in `*` matches any ending (`suicid*` covers `suicidio`, `suicidarme`, `suicida`).

Figurative uses of death that are part of everyday speech are removed before comparing: "me muero **de risa**", "muerta **de cansancio**", "morir **de la vergüenza**". They only cover a fixed list of causes (risa, hambre, sueño, cansancio, vergüenza…), so "me quiero morir" on its own still triggers the protocol.

## The signals

The lists are in [`api/src/services/crisis/signals.ts`](../api/src/services/crisis/signals.ts). The repository is public, so **the filter does not rely on the signals being secret**: knowing them does not help anyone avoid help, and anyone can propose additions.

To change them:

1. Add or move the phrase in `signals.ts`, as people would write it (with accents; normalization takes care of variants).
2. Add a case to the [test suite](#tests) (`api/test/fixtures/crisis-cases.ts`), and run `npm test`.
3. Prefer `ambiguous` for phrases that also have an everyday meaning ("me van a matar" can be a figure of speech). Use `risk` only for phrases that are almost never figurative.

## The second layer

Messages marked `ambiguous` get an isolated classification by an LLM (S2-2), so an indirect message is not answered with a crisis reply when it is clearly harmless ("ya no aguanto más este tráfico"), and is when it is not ("siento que soy una carga").

- **Only ambiguous messages.** A clear risk never goes to the classifier, and normal messages skip it.
- **Only the current message.** The request carries the classification policy and that one message: no history, no memory and no personality prompt. A message that would go to Groq anyway if it were normal is not exposed further.
- **A fixed answer.** The policy ([`api/src/config/crisis-classifier-prompt.ts`](../api/src/config/crisis-classifier-prompt.ts)) asks for one word, `RISK` or `SAFE`. Only an exact `SAFE` lets the message through.
- **Repeatable.** The classifier is called with temperature 0, so the same message always gets the same answer.
- **Conservative on failure.** An error, a quota error or a timeout counts as a crisis. The timeout is short (`CRISIS_CLASSIFIER_TIMEOUT_MS`, 5 seconds by default) and there is no retry.
- **Its own model.** It uses `CRISIS_CLASSIFIER_MODEL` (`openai/gpt-oss-20b` by default), not the chat model, so it does not spend the conversation's quota. Why this model is in [decisions.md](decisions.md).

How well it classifies is measured with the [test suite](#tests).

## The crisis reply

`POST /v1/chat` answers **`200`** with `"type": "crisis"`: a fixed text and the help resources, with 9-1-1 first. It is not an error code, because the app must show it right away and never offer a retry. The exact shape is in the [API contract](api-contract.md#post-v1chat).

The text acknowledges the person and points to 9-1-1. It gives no advice or techniques and does not try to contain the crisis: its only goal is to connect the person with someone who can help.

### Text and resources live in configuration

The reply text and the help resources are in [`api/config/crisis.json`](../api/config/crisis.json), not in code. The same resources are served to the app by the public [`GET /v1/help-resources`](api-contract.md#get-v1help-resources), so the help screen and the crisis reply always show the same numbers, and **changing a number never requires a new app build**: edit the file, open a pull request and Render deploys it.

| Resource | Phone | Hours |
|---|---|---|
| 9-1-1, Despacho de Apoyo Psicológico (**main option**) | 911 | 24/7, free |
| Aquí Estoy, Colegio de Psicólogos | 800-2737869 | Limited hours |
| Emergencias CCSS | 2225-7511 | Check |
| Emergencias CCSS (second line) | 2234-2730 | Check |

The server validates the file when it starts and **refuses to start** if it would break the protocol:

- The reply must mention 9-1-1.
- There must be exactly one primary resource, it must be 9-1-1 and it must be listed first.
- Phones are digits only, ready to dial; ids are unique; `updatedAt` is an ISO 8601 date.

When a number changes, also update `updatedAt`, so the app knows its cached copy is old.

**Numbers can change.** Verify them before using the app with anyone, and periodically after that (S7-7).

### In the app

The app shows the crisis reply as a card that stands out from the conversation, with a button that opens the dialer with 9-1-1 loaded and a way to the help screen (S3-4, S3-5). It never offers a retry. The help screen is one tap away from the chat at all times and works offline: it keeps the last list from `GET /v1/help-resources`, and 9-1-1 is always there ([decision](decisions.md)). The app never places a call by itself; the person confirms on the dialer.

## Activation log

Every time the protocol triggers, the backend records it (S2-5), so the filter can be tuned: too many activations suggest false alarms, none that it may not be detecting. **The record never holds the message in any form**: not the text, a hash or its length.

Each activation is one JSON line in the server logs:

~~~json
{"event":"crisis_activation","at":"2026-10-15T05:00:29.539Z","signal":"risk","layer":"keywords"}
~~~

| Field | Values |
|---|---|
| `at` | When it happened, ISO 8601 in UTC. |
| `signal` | `risk` or `ambiguous`. |
| `layer` | `keywords` (clear risk), `classifier` (the second layer said risk), `classifier_failure` (the second layer failed or timed out, so the conservative criterion applied) or `no_classifier` (ambiguous with no second layer configured). |

To count activations for a period, search the Render logs of `marlix-api` for `crisis_activation` and filter by date. A rising `classifier_failure` count means the classifier is failing (quota, timeouts) and every ambiguous message is being treated as risk.

The backend has no database until S4-1, so the record lives in the logs, which Render only keeps for a limited time. The record goes through the `ActivationLog` interface (`api/src/services/crisis/activation-log.ts`), so Sprint 4 can store it in a database table by replacing that one implementation.

## Tests

This is the one part of marlix that cannot rely on manual tests: if it fails, it fails with someone vulnerable (S2-7). The suite is built on a shared set of **invented** messages in [`api/test/fixtures/crisis-cases.ts`](../api/test/fixtures/crisis-cases.ts); never add a real conversation to it. Each case says what the whole filter should decide and what the keyword layer alone should find.

| Group | Cases | Expected |
|---|---|---|
| Clear risk, including other spellings and voice transcriptions | 25 | Crisis, decided by the keywords. |
| Ambiguous risk | 10 | Crisis, decided by the second layer. |
| Ambiguous but safe | 6 | No crisis, decided by the second layer. |
| Normal, including figurative death ("me muero de risa") | 20 | No crisis; the second layer is not called. |

**`npm test`** runs it automatically, without spending quota:

- Every case through the keyword layer.
- Every clear risk through `POST /v1/chat`: the answer is a crisis with 9-1-1 first, and **no model is called**, not even the classifier.
- Every ambiguous risk: a crisis, and the conversation model is never called.
- Every normal message: a normal reply, without the classifier.
- A report of false negatives and false positives, which fails on any:

  ~~~text
  ℹ clear risk detected: 25/25
  ℹ normal messages let through: 20/20
  ℹ ambiguous sent to the second layer: 16/16
  ℹ conservative mode: 0 false negatives, 6 false positives
  ~~~

  *Conservative mode* is the filter without a second layer: every ambiguous message is a crisis, so the only false alarms are the ambiguous safe ones.

**`npm run crisis:eval`** (in `api/`) runs the same cases through the real classifier and prints the confusion matrix of the whole filter. It spends quota, so it is run by hand, after changing the signals, the policy or the model. It fails if any crisis is missed. Result on 2026-10-14, twice in a row: **0 false negatives out of 35 and 0 false positives out of 26**.

The suite already caught two problems while it was being written: "me kiero matar" passed as normal (*k* and *q* for *qu* are now normalized), and the classifier gave different answers to the same message in different runs (it now uses temperature 0).

## Known limits

- **Spanish only.** The app is in Spanish; messages in other languages are not checked.
- **Keywords miss indirect language.** The second layer only sees messages that already have an ambiguous signal, so an indirect message with no signal at all goes to the conversation.
- **Words split with spaces** ("m a t a r m e") or deliberate misspellings that change letters are not detected.
- **False alarms** are possible, for example when the classifier is down or out of quota. They are accepted on purpose.

## Still to come

| Card | What it adds |
|---|---|
| S7-7 | Periodic verification of the help phone numbers. |
