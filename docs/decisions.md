# Technical decisions

Every time the project picks between two technical options, the decision is recorded here: what was chosen, what was discarded and why. Newest first.

---

## 2026-09-30 — Chat flow: crisis filter before the daily cap, crisis messages kept in history (S0-8)

**Decision 1: the crisis filter runs even when the daily cap is reached.** The backend reads the usage before the filter, but only applies a reached cap to messages without risk. Crisis replies do not count against the cap.

- *Discarded:* rejecting every message once the cap is reached. A person in crisis would get "limit reached" instead of the 9-1-1 reply.

**Decision 2: crisis messages are saved in the user's own history,** together with the fixed reply. They are protected by RLS and the 90-day retention, and never go to Groq or to the logs. The activation log (S2-5) still has no content.

- *Discarded:* not saving them. It is slightly more private, but the user would come back to a chat without what they wrote or the help they got.

Full flow: [chat sequence diagram](diagrams/chat-sequence.md).

---

## 2026-09-30 — LLM provider: Groq free plan with `openai/gpt-oss-120b` (S0-11)

**Decision:** the conversation runs on Groq's free plan with the model `openai/gpt-oss-120b`, called with low reasoning effort. The model name lives in the `GROQ_MODEL` environment variable, never in code.

### Data policy review

marlix sends emotional conversations and the user's distilled memory to the provider on every call, so its data policy was reviewed before committing. Sources were read on 2026-09-30.

| Question | Finding | Source |
|---|---|---|
| Does it train on our data? | **No.** "Groq is not permitted to use Inputs or Outputs for training or fine-tuning any AI Model Services or other models, unless explicitly granted permission or instructed by Customer." | [Services Agreement §4.2](https://console.groq.com/docs/legal/services-agreement) (last modified 2026-06-22) |
| Can people read it? | Only when needed to run the service, comply with the law, keep the platform reliable or check compliance with the acceptable use policy. With **Zero Data Retention (ZDR)** enabled, Groq does not keep data for reliability or abuse monitoring. | [Services Agreement §4.2](https://console.groq.com/docs/legal/services-agreement), [Your Data in GroqCloud](https://console.groq.com/docs/your-data) |
| How long is it kept? | Inference requests are **not retained by default**. They may be logged temporarily, **up to 30 days**, only to troubleshoot reliability errors or investigate suspected abuse. ZDR turns that off. | [Your Data in GroqCloud](https://console.groq.com/docs/your-data) |
| Where is it processed? | Retained data is stored in Google Cloud Platform buckets **in the United States**. | [Your Data in GroqCloud](https://console.groq.com/docs/your-data) |
| Mental health use | Not forbidden by the [acceptable use policy](https://console.groq.com/docs/legal/ai-policy). The agreement says the models "should not be used for medical, legal, financial, or other professional advice", which matches marlix's rule of never diagnosing or presenting itself as therapy. | [Services Agreement §4.3](https://console.groq.com/docs/legal/services-agreement) |
| Minors | Not forbidden. If an app is likely to be used by minors, the developer is responsible for complying with the laws on minors and their data. | [Services Agreement §6.3](https://console.groq.com/docs/legal/services-agreement) |

**Verdict: acceptable for v1.** Groq does not train on the data and does not keep it by default. To close the remaining gap (abuse logs of up to 30 days), **Global ZDR was enabled on 2026-09-30** in the console under Settings → Data Controls. It also turns off batch processing and fine-tuning, which marlix does not use; the chat API keeps working.

This is a clear difference with the discarded option: Gemini's free plan uses content to improve Google's products and it can be read by human reviewers.

### Free plan limits

Limits apply **per organization and per model**: the whole family shares them. Official table read on 2026-09-30 ([Rate limits](https://console.groq.com/docs/rate-limits)). The account's own limits for `openai/gpt-oss-120b` were confirmed in the response headers of the test call (`x-ratelimit-limit-requests: 1000`, `x-ratelimit-limit-tokens: 8000`).

| Model | Requests/min | Requests/day | Tokens/min | Tokens/day |
|---|---|---|---|---|
| `openai/gpt-oss-120b` | 30 | 1,000 | 8,000 | 200,000 |
| `openai/gpt-oss-20b` | 30 | 1,000 | 8,000 | 200,000 |
| `openai/gpt-oss-safeguard-20b` | 30 | 1,000 | 8,000 | 200,000 |

What this means for marlix:

- **1,000 requests per day** for the whole account. With the per-user cap of 100 interactions (S2-6), about ten active users fit in a day. The cap is what stops one person, or a bug, from using up everyone's quota.
- **8,000 tokens per minute** is the tightest limit. One chat call (system prompt + memory + the last 15 to 20 messages + reply) can use a few thousand tokens, so only a few calls fit in a minute. The prompt must stay compact, and the backend must handle a `429` response with a friendly "try again in a moment" (S1-6).
- Background memory distillation (S4-6) spends the same quota; it should run spread out, not in bursts.
- Quotas are per model, so the isolated crisis classification (S2-2) can use a different model and not compete with the conversation.

### Model choice

| Option | Result |
|---|---|
| `openai/gpt-oss-120b` | **Chosen.** Production model, best quality of the free models and good Spanish. Called with low reasoning effort to save tokens and answer faster. |
| `openai/gpt-oss-20b` | Backup. Production model, faster but less nuanced. Switching is only a change of `GROQ_MODEL`. |
| `qwen/qwen3.8-27b` | Discarded as main model: it is a preview model on Groq and can be removed without notice. |
| Llama 3.3 70B, Llama 3.1 8B | Not chosen: they are not listed in the free plan table on 2026-09-30. |

Groq retires models from time to time. Because the model is an environment variable and the backend talks to the LLM through its own abstraction layer (S1-3), changing model or provider does not require rewriting code.

### Account and test call

The project's Groq account and a development API key were created on 2026-09-30. The key lives only in `api/.env`, which Git ignores; [`api/.env.example`](../api/.env.example) lists the variables without values. Production gets its own key on Render (Sprint 1).

Test call from the terminal (Git Bash), reading the key and model from `api/.env`:

~~~bash
set -a && . api/.env && set +a
curl -s https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$GROQ_MODEL\", \"reasoning_effort\": \"low\",
       \"messages\": [{\"role\": \"user\", \"content\": \"Saludame en una frase corta, en español de Costa Rica.\"}]}"
~~~

Result: `openai/gpt-oss-120b` answered in Spanish, using 113 tokens.

### If the policy or limits stop being acceptable

Alternatives, in order: another Groq model, a paid provider such as DeepSeek, or a local model with Ollama.
