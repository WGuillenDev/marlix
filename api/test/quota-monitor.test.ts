import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createFakeLlm, startApp } from './helpers.js';
import { GroqProvider, readQuota } from '../src/services/llm/groq-provider.js';
import { createQuotaMonitor } from '../src/services/llm/quota-monitor.js';

const reading = { limit: 1000, remaining: 500, resetsInSeconds: 3600 };

function quotaHeaders(remaining: number, reset = '1h0m0s') {
  return {
    'x-ratelimit-limit-requests': '1000',
    'x-ratelimit-remaining-requests': String(remaining),
    'x-ratelimit-reset-requests': reset,
  };
}

describe('QuotaMonitor', () => {
  it('is quiet while more than 20% is left and low at 20% or less', () => {
    const monitor = createQuotaMonitor(() => 0);
    monitor.record('a', { ...reading, remaining: 201 });
    assert.equal(monitor.isLow(), false);
    monitor.record('a', { ...reading, remaining: 200 });
    assert.equal(monitor.isLow(), true);
  });

  it('is low when any one model is low, and clears when it recovers', () => {
    const monitor = createQuotaMonitor(() => 0);
    monitor.record('chat', reading);
    monitor.record('classifier', { ...reading, remaining: 10 });
    assert.equal(monitor.isLow(), true);
    monitor.record('classifier', reading);
    assert.equal(monitor.isLow(), false);
  });

  it('forgets a reading once the daily window has reset', () => {
    let now = 0;
    const monitor = createQuotaMonitor(() => now);
    monitor.record('chat', { limit: 1000, remaining: 0, resetsInSeconds: 60 });
    assert.equal(monitor.isLow(), true);
    now = 61_000;
    assert.equal(monitor.isLow(), false);
  });
});

describe('readQuota', () => {
  it('reads the daily request headers and ignores the per-minute token ones', () => {
    const headers = new Headers({
      ...quotaHeaders(999, '1m26.4s'),
      'x-ratelimit-limit-tokens': '8000',
      'x-ratelimit-remaining-tokens': '7907',
    });
    assert.deepEqual(readQuota(headers), {
      limit: 1000,
      remaining: 999,
      resetsInSeconds: 86.4,
    });
  });

  it('gives nothing when the headers are missing or not numbers', () => {
    assert.equal(readQuota(new Headers()), undefined);
    assert.equal(readQuota(undefined), undefined);
    assert.equal(readQuota(new Headers(quotaHeaders(Number.NaN))), undefined);
    assert.equal(readQuota(new Headers(quotaHeaders(10, 'soon'))), undefined);
  });
});

describe('GroqProvider and the quota', () => {
  function createProvider(respond: () => Response) {
    const monitor = createQuotaMonitor();
    const provider = new GroqProvider({
      apiKey: 'gsk_test',
      model: 'test-model',
      quota: monitor,
      fetch: async () => respond(),
    });
    return { provider, monitor };
  }

  const request = { messages: [{ role: 'user', content: 'Hola' }] } as const;
  const completion = JSON.stringify({
    id: 'c1',
    object: 'chat.completion',
    created: 0,
    model: 'test-model',
    choices: [
      {
        index: 0,
        finish_reason: 'stop',
        message: { role: 'assistant', content: 'Hola' },
      },
    ],
  });

  it('records the quota from a successful answer', async () => {
    const { provider, monitor } = createProvider(
      () =>
        new Response(completion, {
          headers: { 'content-type': 'application/json', ...quotaHeaders(50) },
        }),
    );
    await provider.complete(request);
    assert.equal(monitor.isLow(), true);
  });

  it('records the quota from a streamed answer', async () => {
    const chunk = JSON.stringify({
      id: 'c1',
      object: 'chat.completion.chunk',
      created: 0,
      model: 'test-model',
      choices: [{ index: 0, delta: { content: 'Hola' }, finish_reason: null }],
    });
    const { provider, monitor } = createProvider(
      () =>
        new Response(`data: ${chunk}\n\ndata: [DONE]\n\n`, {
          headers: { 'content-type': 'text/event-stream', ...quotaHeaders(50) },
        }),
    );
    const pieces: string[] = [];
    for await (const piece of provider.stream(request)) pieces.push(piece);
    assert.deepEqual(pieces, ['Hola']);
    assert.equal(monitor.isLow(), true);
  });

  it('records the quota from a 429 that says nothing is left', async () => {
    const { provider, monitor } = createProvider(
      () =>
        new Response(
          JSON.stringify({
            error: { message: 'limit', code: 'rate_limit_exceeded' },
          }),
          {
            status: 429,
            headers: {
              'content-type': 'application/json',
              ...quotaHeaders(0, '5m0s'),
            },
          },
        ),
    );
    await assert.rejects(provider.complete(request));
    assert.equal(monitor.isLow(), true);
  });

  it('stays quiet while the quota is healthy', async () => {
    const { provider, monitor } = createProvider(
      () =>
        new Response(completion, {
          headers: { 'content-type': 'application/json', ...quotaHeaders(900) },
        }),
    );
    await provider.complete(request);
    assert.equal(monitor.isLow(), false);
  });
});

describe('GET /health and the Groq quota', () => {
  it('says degraded with groq_quota while the quota is low, ok again after the reset', async () => {
    let now = 0;
    const quota = createQuotaMonitor(() => now);
    const app = await startApp({ llm: createFakeLlm().llm, quota });
    try {
      assert.deepEqual(await (await app.request('/health')).json(), {
        status: 'ok',
      });

      quota.record('chat', {
        limit: 1000,
        remaining: 150,
        resetsInSeconds: 600,
      });
      const degraded = await app.request('/health');
      assert.equal(degraded.status, 200);
      assert.deepEqual(await degraded.json(), {
        status: 'degraded',
        problems: ['groq_quota'],
      });

      now = 601_000;
      assert.deepEqual(await (await app.request('/health')).json(), {
        status: 'ok',
      });
    } finally {
      await app.close();
    }
  });
});
