// HTTP calls go to a fake fetch, so no test spends real quota; `npm run
// llm:smoke` checks the real API.
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { LlmError } from '../src/services/llm/errors.js';
import { GroqProvider, parseRetryAfterSeconds } from '../src/services/llm/groq-provider.js';

const API_KEY = 'gsk_test_secret_key';
const messages = [
  { role: 'system', content: 'Sos marlix.' },
  { role: 'user', content: 'Hola' },
] as const;

function jsonResponse(status: number, body: unknown, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

function completionBody(content: string | null) {
  return {
    id: 'chatcmpl-1',
    object: 'chat.completion',
    created: 0,
    model: 'test-model',
    choices: [{ index: 0, finish_reason: 'stop', message: { role: 'assistant', content } }],
    usage: { prompt_tokens: 12, completion_tokens: 5, total_tokens: 17 },
  };
}

/** A provider whose HTTP calls go to `respond` instead of the network. */
function createProvider(
  respond: (request: Request) => Response | Promise<Response>,
  now = () => 0,
) {
  const requests: Request[] = [];
  const provider = new GroqProvider({
    apiKey: API_KEY,
    model: 'test-model',
    reasoningEffort: 'low',
    now,
    fetch: async (input, init) => {
      const request = new Request(input, init);
      requests.push(request);
      return respond(request);
    },
  });
  return { provider, requests };
}

async function rejectsWith(promise: Promise<unknown>, kind: string): Promise<LlmError> {
  try {
    await promise;
  } catch (error) {
    assert.ok(error instanceof LlmError, 'expected an LlmError');
    assert.equal(error.kind, kind);
    assert.ok(!error.message.includes(API_KEY), 'the key must never be in an error');
    return error;
  }
  assert.fail(`expected a ${kind} error`);
}

describe('GroqProvider', () => {
  it('returns the reply and usage for a list of messages', async () => {
    const { provider, requests } = createProvider(() =>
      jsonResponse(200, completionBody('  ¡Hola!  ')),
    );

    const result = await provider.complete({ messages, maxOutputTokens: 256 });

    assert.equal(result.content, '¡Hola!');
    assert.deepEqual(result.usage, { inputTokens: 12, outputTokens: 5 });

    const sent = (await requests[0]!.json()) as Record<string, unknown>;
    assert.equal(sent.model, 'test-model');
    assert.equal(sent.reasoning_effort, 'low');
    assert.equal(sent.max_completion_tokens, 256);
    assert.deepEqual(sent.messages, messages);
    assert.equal(requests[0]!.headers.get('authorization'), `Bearer ${API_KEY}`);
  });

  it('turns an empty reply into empty_response', async () => {
    const { provider } = createProvider(() => jsonResponse(200, completionBody(null)));
    await rejectsWith(provider.complete({ messages }), 'empty_response');
  });

  it('translates 401 into authentication', async () => {
    const { provider } = createProvider(() =>
      jsonResponse(401, { error: { message: 'Invalid API Key', code: 'invalid_api_key' } }),
    );
    await rejectsWith(provider.complete({ messages }), 'authentication');
  });

  it('translates 5xx into a transient unavailable error', async () => {
    const { provider } = createProvider(() => jsonResponse(503, { error: { message: 'down' } }));
    const error = await rejectsWith(provider.complete({ messages }), 'unavailable');
    assert.ok(error.isTransient);
  });

  it('does not copy the provider message into the error', async () => {
    const { provider } = createProvider(() =>
      jsonResponse(400, { error: { message: 'bad request near "Hola"' } }),
    );
    const error = await rejectsWith(provider.complete({ messages }), 'invalid_request');
    assert.ok(!error.message.includes('Hola'));
  });

  it('on 429, waits the time Groq asks for before calling again', async () => {
    let clock = 0;
    const { provider, requests } = createProvider(
      () => jsonResponse(429, { error: { message: 'Rate limit reached' } }, { 'retry-after': '7' }),
      () => clock,
    );

    const first = await rejectsWith(provider.complete({ messages }), 'rate_limited');
    assert.equal(first.retryAfterSeconds, 7);
    assert.ok(!first.isTransient);

    clock = 3_000;
    const second = await rejectsWith(provider.complete({ messages }), 'rate_limited');
    assert.equal(second.retryAfterSeconds, 4);
    assert.equal(requests.length, 1, 'no call to Groq while the quota is exhausted');

    clock = 7_000;
    await rejectsWith(provider.complete({ messages }), 'rate_limited');
    assert.equal(requests.length, 2, 'calls Groq again once the wait is over');
  });
});

describe('parseRetryAfterSeconds', () => {
  it('reads retry-after in seconds, rounding up', () => {
    assert.equal(parseRetryAfterSeconds(new Headers({ 'retry-after': '2.2' })), 3);
  });

  it('falls back to the longest x-ratelimit-reset header', () => {
    const headers = new Headers({
      'x-ratelimit-reset-tokens': '7.66s',
      'x-ratelimit-reset-requests': '1m2.5s',
    });
    assert.equal(parseRetryAfterSeconds(headers), 63);
  });

  it('uses a safe default when no header says how long to wait', () => {
    assert.equal(parseRetryAfterSeconds(new Headers()), 10);
    assert.equal(parseRetryAfterSeconds(new Headers({ 'x-ratelimit-reset-tokens': 'soon' })), 10);
  });
});
