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
2. Add the case to the tests (`api/test/crisis-filter.test.ts`, and the full set of S2-7).
3. Prefer `ambiguous` for phrases that also have an everyday meaning ("me van a matar" can be a figure of speech). Use `risk` only for phrases that are almost never figurative.

## The second layer

Messages marked `ambiguous` get an isolated classification by an LLM (S2-2), so an indirect message is not answered with a crisis reply when it is clearly harmless ("ya no aguanto más este tráfico"), and is when it is not ("siento que soy una carga").

- **Only ambiguous messages.** A clear risk never goes to the classifier, and normal messages skip it.
- **Only the current message.** The request carries the classification policy and that one message: no history, no memory and no personality prompt. A message that would go to Groq anyway if it were normal is not exposed further.
- **A fixed answer.** The policy ([`api/src/config/crisis-classifier-prompt.ts`](../api/src/config/crisis-classifier-prompt.ts)) asks for one word, `RISK` or `SAFE`. Only an exact `SAFE` lets the message through.
- **Conservative on failure.** An error, a quota error or a timeout counts as a crisis. The timeout is short (`CRISIS_CLASSIFIER_TIMEOUT_MS`, 5 seconds by default) and there is no retry.
- **Its own model.** It uses `CRISIS_CLASSIFIER_MODEL` (`openai/gpt-oss-20b` by default), not the chat model, so it does not spend the conversation's quota. Why this model is in [decisions.md](decisions.md).

`npm run crisis:eval` (in `api/`) runs a set of ambiguous messages through the real classifier and reports how many it got right.

## The crisis reply

`POST /v1/chat` answers **`200`** with `"type": "crisis"`: a fixed text and the help resources, with 9-1-1 first. It is not an error code, because the app must show it right away and never offer a retry. The exact shape is in the [API contract](api-contract.md#post-v1chat).

The text acknowledges the person and points to 9-1-1. It gives no advice or techniques and does not try to contain the crisis. Until S2-3 moves the text and the resources to configuration, the reply is a minimal fixed text with 9-1-1 only.

## Known limits

- **Spanish only.** The app is in Spanish; messages in other languages are not checked.
- **Keywords miss indirect language.** The second layer only sees messages that already have an ambiguous signal, so an indirect message with no signal at all goes to the conversation.
- **Words split with spaces** ("m a t a r m e") or deliberate misspellings that change letters are not detected.
- **False alarms** are possible, for example when the classifier is down or out of quota. They are accepted on purpose.

## Still to come

| Card | What it adds |
|---|---|
| S2-3 | Crisis text and help resources in configuration, with every verified Costa Rican resource. |
| S2-5 | A log of each activation, without the content of the message. |
| S2-7 | The full set of automated test cases. |
| S7-7 | Periodic verification of the help phone numbers. |
