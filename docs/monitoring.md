# Monitoring

What watches marlix, what each alert means and what to do. Everything is free and nothing here has a card attached. Written for S7-6.

## The health endpoint

`GET /health` ([contract](api-contract.md#get-health)) never touches the database or Groq. It reports what the last real requests found:

| Body | Meaning | What to do |
|---|---|---|
| `{"status":"ok"}` | Up, counting replies and with Groq quota left. | Nothing. |
| `"problems":["usage_counter"]` | The last attempt to count a reply failed (usually a migration not applied). | Run `docs/verify-migrations.sql` in the Supabase SQL Editor; every row must say `ok` ([CONTRIBUTING](../CONTRIBUTING.md#database-migrations)). |
| `"problems":["groq_quota"]` | A Groq model has 20% or less of its daily requests left (it resets about every 24 hours; the body goes back to `ok` by itself). | See [Groq quota](#groq-quota). |

It always answers `200` when degraded, so Render does not restart a healthy process. That is why the monitor must look at the **body**, not only the status code.

## The uptime monitor (UptimeRobot)

One external monitor does three jobs: it warns when the backend stops answering, it keeps the Render free service awake (it sleeps after about 15 minutes without traffic) and it is the alert for the two `degraded` cases above.

`/health` does not query the database, so it does **not** keep the Supabase project from pausing after a week without activity. The daily backup ([backups.md](backups.md)) connects to the database every day, and any real use of the app does too; if Supabase ever emails a pause warning, open the project and restore it from the dashboard.

Set it up once, in [uptimerobot.com](https://uptimerobot.com) (free plan):

1. **Add New Monitor**, type **Keyword**.
2. **URL**: `https://marlix-api.onrender.com/health`.
3. **Keyword**: `"status":"ok"` (with the quotes), and set the alert for **keyword does not exist**.
4. **Monitoring interval**: the shortest the free plan allows (5 minutes; the card asks for 10 at most, and anything under 15 keeps Render awake).
5. **Alert contacts**: your email. Check that you receive the test message.

To test it (the card's check): in the Render dashboard, **marlix-api → Suspend Service**, wait for the email, then **Resume Service**. The service takes a minute to wake up and the monitor reports it up again.

## Groq quota

Groq's free plan limits the requests per day for each model (1,000 a day for `openai/gpt-oss-120b`, checked on 3 November 2026). One chat message can use several: the crisis classifier, the reply, the review and, later, the memory extraction. The per-person cap of 100 replies a day does not protect the account's total.

- **Alert.** Groq tells the backend how much is left in the headers of every answer. When any model has 20% or less of its daily requests, `/health` shows `groq_quota` and the monitor emails you. The backend makes no call of its own to measure it.
- **Periodic review.** Once a week, open [console.groq.com/dashboard/usage](https://console.groq.com/dashboard/usage) and compare the day's use with the limits in [console.groq.com/settings/limits](https://console.groq.com/settings/limits). If a model is often near the limit, reduce what each message spends (a shorter prompt, `GROQ_REASONING_EFFORT=low`) before thinking about a paid plan.
- **What it does not see.** The daily token limit, and Whisper's audio limit for voice mode, do not come in those headers. A 429 from either one shows up as the app's "try again later" message and as `LLM call failed: rate_limited` in the logs.

## No card, no charges (checklist)

Look at each service the project uses and tick the table in your own notes; do it again before opening the app to more people. The panels need your sign-in, so the owner does this, not the code.

| Service | Plan | What to look at |
|---|---|---|
| Render | Free web service | [Billing](https://dashboard.render.com/billing): no payment method, plan Hobby, no paid services. |
| Supabase | Free | [Billing](https://supabase.com/dashboard/org/_/billing): plan Free, spend cap on, no payment method. |
| Groq | Free | [Billing](https://console.groq.com/settings/billing): plan Free. A free account cannot go over the limit; at the limit it answers 429. |
| GitHub | Free (public repository) | Actions are free for public repositories. |
| UptimeRobot | Free | No payment method. |

## Logs

Render keeps the backend's logs (**marlix-api → Logs**). The backend logs the kind of failure and where it happened, never the content of a chat, a request or a response body: `LLM call failed: <kind>`, `Unexpected error: <name>` with the stack, and the crisis activations without text. Tests in `api/test` check that no message appears in the logs (for example in `chat.test.ts`, `history.test.ts` and `voice-replies.test.ts`).
