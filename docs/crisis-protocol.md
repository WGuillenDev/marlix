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
| `ambiguous` | The message has an indirect signal ("ya no aguanto más", "soy una carga"). | The second layer (S2-2) classifies only that message. If it says risk, fails or times out, the answer is the crisis reply. **Until S2-2 exists, `ambiguous` is treated as `risk`.** |
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

## The crisis reply

`POST /v1/chat` answers **`200`** with `"type": "crisis"`: a fixed text and the help resources, with 9-1-1 first. It is not an error code, because the app must show it right away and never offer a retry. The exact shape is in the [API contract](api-contract.md#post-v1chat).

The text acknowledges the person and points to 9-1-1. It gives no advice or techniques and does not try to contain the crisis. Until S2-3 moves the text and the resources to configuration, the reply is a minimal fixed text with 9-1-1 only.

## Known limits

- **Spanish only.** The app is in Spanish; messages in other languages are not checked.
- **Keywords miss indirect language.** That is what the second layer (S2-2) is for.
- **Words split with spaces** ("m a t a r m e") or deliberate misspellings that change letters are not detected.
- **False alarms** are possible, especially while ambiguous messages are treated as risk. They are accepted on purpose.

## Still to come

| Card | What it adds |
|---|---|
| S2-2 | Second layer: an isolated classification of ambiguous messages, with no history or memory. |
| S2-3 | Crisis text and help resources in configuration, with every verified Costa Rican resource. |
| S2-5 | A log of each activation, without the content of the message. |
| S2-7 | The full set of automated test cases. |
| S7-7 | Periodic verification of the help phone numbers. |
