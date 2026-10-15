import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { loadPlansConfig, parsePlansConfig, PlansConfigError } from '../src/config/plans.js';
import type { PlansConfig } from '../src/config/plans.js';
import { costaRicaDay, nextCostaRicaMidnight } from '../src/services/usage/costa-rica-day.js';
import {
  createUsageLimiter,
  UsageLimitExceededError,
  type UsageLimitError,
} from '../src/services/usage/usage-limiter.js';
import { LlmError } from '../src/services/llm/index.js';
import { createFakeLlm, DEV_TOKEN, failingLlm, startApp } from './helpers.js';

const user = { id: 'ana', plan: 'personal' };

function plans(dailyInteractions: number, requests = 100, windowSeconds = 60): PlansConfig {
  return { personal: { dailyInteractions, rateLimit: { requests, windowSeconds } } };
}

function limitOf(action: () => void): UsageLimitError {
  try {
    action();
  } catch (error) {
    assert.ok(error instanceof UsageLimitExceededError);
    return error.limit;
  }
  assert.fail('expected a usage limit error');
}

describe('Costa Rica day', () => {
  it('follows Costa Rica time, not UTC', () => {
    // 05:00 UTC on the 15th is still 23:00 on the 14th in Costa Rica.
    const now = new Date('2026-10-15T05:00:00Z');
    assert.equal(costaRicaDay(now), '2026-10-14');
    assert.equal(nextCostaRicaMidnight(now).toISOString(), '2026-10-15T06:00:00.000Z');
  });

  it('moves to the next day right after local midnight', () => {
    const now = new Date('2026-10-15T06:00:01Z');
    assert.equal(costaRicaDay(now), '2026-10-15');
    assert.equal(nextCostaRicaMidnight(now).toISOString(), '2026-10-16T06:00:00.000Z');
  });
});

describe('createUsageLimiter', () => {
  it('stops at the daily cap and resets at Costa Rica midnight', () => {
    let now = new Date('2026-10-14T20:00:00Z');
    const limiter = createUsageLimiter(plans(2), () => now);

    for (let i = 0; i < 2; i++) {
      limiter.reserveAttempt(user);
      limiter.recordInteraction(user);
    }
    assert.deepEqual(limiter.snapshot(user), {
      plan: 'personal',
      used: 2,
      limit: 2,
      remaining: 0,
      resetsAt: '2026-10-15T06:00:00.000Z',
    });
    assert.deepEqual(limitOf(() => limiter.reserveAttempt(user)), {
      reason: 'daily_limit',
      resetsAt: '2026-10-15T06:00:00.000Z',
    });

    now = new Date('2026-10-15T06:00:01Z');
    assert.equal(limiter.snapshot(user).used, 0);
    limiter.reserveAttempt(user);
  });

  it('limits bursts and frees a slot once the window passes', () => {
    let now = new Date('2026-10-14T20:00:00Z');
    const limiter = createUsageLimiter(plans(100, 2, 60), () => now);

    limiter.reserveAttempt(user);
    now = new Date('2026-10-14T20:00:20Z');
    limiter.reserveAttempt(user);
    assert.deepEqual(limitOf(() => limiter.reserveAttempt(user)), {
      reason: 'rate_limit',
      retryAfterSeconds: 40,
    });

    now = new Date('2026-10-14T20:01:00.001Z');
    limiter.reserveAttempt(user);
  });

  it('keeps counters per user', () => {
    const limiter = createUsageLimiter(plans(1));
    limiter.recordInteraction(user);
    assert.equal(limiter.snapshot({ id: 'beto', plan: 'personal' }).used, 0);
  });

  it('applies the personal limits to an unknown plan instead of no limit', () => {
    const limiter = createUsageLimiter(plans(7));
    assert.equal(limiter.snapshot({ id: 'ana', plan: 'premium' }).limit, 7);
  });
});

describe('plans configuration', () => {
  it('ships the personal plan with 100 interactions a day', () => {
    assert.equal(loadPlansConfig().personal?.dailyInteractions, 100);
  });

  const invalid: [string, unknown][] = [
    ['no personal plan', { family: plans(10).personal }],
    ['a zero cap', plans(0)],
    [
      'a rate limit without a window',
      { personal: { dailyInteractions: 10, rateLimit: { requests: 5 } } },
    ],
  ];

  for (const [name, raw] of invalid) {
    it(`refuses ${name}`, () => {
      assert.throws(() => parsePlansConfig(raw), PlansConfigError);
    });
  }
});

describe('limits in POST /v1/chat', () => {
  it('returns usage and counts only successful replies', async () => {
    const app = await startApp({ llm: createFakeLlm().llm, plans: plans(5) });
    try {
      const first = (await (await app.postJson('/v1/chat', { message: 'hola' })).json()) as any;
      const second = (await (await app.postJson('/v1/chat', { message: 'hola' })).json()) as any;

      assert.equal(first.usage.used, 1);
      assert.equal(second.usage.used, 2);
      assert.equal(second.usage.remaining, 3);
      assert.equal(second.usage.limit, 5);
      assert.ok(Date.parse(second.usage.resetsAt) > Date.now());
    } finally {
      await app.close();
    }
  });

  it('answers 429 DAILY_LIMIT_REACHED with the reset time at the cap', async () => {
    const app = await startApp({ llm: createFakeLlm().llm, plans: plans(1) });
    try {
      await app.postJson('/v1/chat', { message: 'hola' });
      const response = await app.postJson('/v1/chat', { message: 'hola otra vez' });
      const body = (await response.json()) as any;

      assert.equal(response.status, 429);
      assert.equal(body.error.code, 'DAILY_LIMIT_REACHED');
      assert.ok(Date.parse(body.error.details.resetsAt) > Date.now());
    } finally {
      await app.close();
    }
  });

  it('still answers a crisis at the cap, without counting it', async () => {
    const fake = createFakeLlm();
    const app = await startApp({ llm: fake.llm, plans: plans(1) });
    try {
      await app.postJson('/v1/chat', { message: 'hola' });
      const response = await app.postJson('/v1/chat', { message: 'me quiero morir' });
      const body = (await response.json()) as any;

      assert.equal(response.status, 200);
      assert.equal(body.type, 'crisis');
      assert.equal(body.usage.used, 1);
      assert.equal(fake.requests.length, 1);
    } finally {
      await app.close();
    }
  });

  it('answers 429 RATE_LIMITED with Retry-After when messages come too fast', async () => {
    const app = await startApp({ llm: createFakeLlm().llm, plans: plans(100, 2, 60) });
    try {
      await app.postJson('/v1/chat', { message: 'uno' });
      await app.postJson('/v1/chat', { message: 'dos' });
      const response = await app.postJson('/v1/chat', { message: 'tres' });

      assert.equal(response.status, 429);
      assert.equal(((await response.json()) as any).error.code, 'RATE_LIMITED');
      const retryAfter = Number(response.headers.get('retry-after'));
      assert.ok(retryAfter > 0 && retryAfter <= 60);
    } finally {
      await app.close();
    }
  });

  it('does not count a reply that failed', async () => {
    const app = await startApp({
      llm: failingLlm(new LlmError('unavailable', 'down')),
      plans: plans(5),
    });
    try {
      const response = await app.postJson('/v1/chat', { message: 'hola' });
      assert.equal(response.status, 503);

      const usage = (await (
        await app.request('/v1/usage', { headers: { authorization: `Bearer ${DEV_TOKEN}` } })
      ).json()) as any;
      assert.equal(usage.used, 0);
    } finally {
      await app.close();
    }
  });
});

describe('GET /v1/usage', () => {
  it('returns the usage of the caller, behind the token', async () => {
    const app = await startApp({ llm: createFakeLlm().llm, plans: plans(30) });
    try {
      assert.equal((await app.request('/v1/usage')).status, 401);

      const response = await app.request('/v1/usage', {
        headers: { authorization: `Bearer ${DEV_TOKEN}` },
      });
      const body = (await response.json()) as any;
      assert.equal(response.status, 200);
      assert.deepEqual(
        { plan: body.plan, used: body.used, limit: body.limit, remaining: body.remaining },
        { plan: 'personal', used: 0, limit: 30, remaining: 30 },
      );
    } finally {
      await app.close();
    }
  });
});
