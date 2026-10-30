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
import { UsageStoreError } from '../src/services/usage/usage-store.js';
import { captureConsole, createFakeLlm, failingLlm, startApp } from './helpers.js';
import { createMemoryUsageStore } from './memory-usage-store.js';

const user = { id: 'ana', plan: 'personal' };

function plans(requests = 100, windowSeconds = 60): PlansConfig {
  return { personal: { rateLimit: { requests, windowSeconds } } };
}

async function limitOf(action: () => Promise<unknown>): Promise<UsageLimitError> {
  try {
    await action();
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
  it('stops at the daily cap and resets at Costa Rica midnight', async () => {
    let now = new Date('2026-10-14T20:00:00Z');
    const limiter = createUsageLimiter(plans(), createMemoryUsageStore({ personal: 2 }).store, () => now);

    for (let i = 0; i < 2; i++) {
      await limiter.reserveAttempt(user);
      await limiter.recordInteraction(user);
    }
    assert.deepEqual(await limiter.snapshot(user), {
      plan: 'personal',
      used: 2,
      limit: 2,
      remaining: 0,
      resetsAt: '2026-10-15T06:00:00.000Z',
    });
    assert.deepEqual(await limitOf(() => limiter.reserveAttempt(user)), {
      reason: 'daily_limit',
      resetsAt: '2026-10-15T06:00:00.000Z',
    });

    now = new Date('2026-10-15T06:00:01Z');
    assert.equal((await limiter.snapshot(user)).used, 0);
    await limiter.reserveAttempt(user);
  });

  it('limits bursts and frees a slot once the window passes', async () => {
    let now = new Date('2026-10-14T20:00:00Z');
    const limiter = createUsageLimiter(plans(2, 60), createMemoryUsageStore().store, () => now);

    await limiter.reserveAttempt(user);
    now = new Date('2026-10-14T20:00:20Z');
    await limiter.reserveAttempt(user);
    assert.deepEqual(await limitOf(() => limiter.reserveAttempt(user)), {
      reason: 'rate_limit',
      retryAfterSeconds: 40,
    });

    now = new Date('2026-10-14T20:01:00.001Z');
    await limiter.reserveAttempt(user);
  });

  it('keeps counters per user', async () => {
    const limiter = createUsageLimiter(plans(), createMemoryUsageStore().store);
    await limiter.recordInteraction(user);
    assert.equal((await limiter.snapshot({ id: 'beto', plan: 'personal' })).used, 0);
  });

  it('applies the personal cap to an unknown plan instead of no limit', async () => {
    const limiter = createUsageLimiter(plans(), createMemoryUsageStore({ personal: 7 }).store);
    assert.equal((await limiter.snapshot({ id: 'ana', plan: 'premium' })).limit, 7);
  });

  it('keeps the count when the limiter is created again, like after a restart', async () => {
    const database = createMemoryUsageStore({ personal: 5 });
    const before = createUsageLimiter(plans(), database.store);
    await before.recordInteraction(user);
    await before.recordInteraction(user);

    const afterRestart = createUsageLimiter(plans(), database.store);
    assert.equal((await afterRestart.snapshot(user)).used, 2);
  });

  it('applies a new cap from the database at once, with no new limiter', async () => {
    const database = createMemoryUsageStore({ personal: 100 });
    const limiter = createUsageLimiter(plans(), database.store);
    assert.equal((await limiter.snapshot(user)).limit, 100);

    database.caps.personal = 3;
    assert.equal((await limiter.snapshot(user)).limit, 3);
  });

  it('counts simultaneous replies one by one', async () => {
    const database = createMemoryUsageStore({ personal: 100 });
    const limiter = createUsageLimiter(plans(), database.store);

    await Promise.all(Array.from({ length: 10 }, () => limiter.recordInteraction(user)));

    assert.equal((await limiter.snapshot(user)).used, 10);
  });

  it('refuses to let a message through when the count cannot be read', async () => {
    const database = createMemoryUsageStore();
    database.failing.reads = true;
    const limiter = createUsageLimiter(plans(), database.store);

    await assert.rejects(() => limiter.reserveAttempt(user), UsageStoreError);
  });

  it('still delivers the reply when the count cannot be saved', async () => {
    const database = createMemoryUsageStore();
    database.failing.writes = true;
    const limiter = createUsageLimiter(plans(), database.store);

    assert.equal(await limiter.recordInteraction(user), undefined);
  });

  it('reports that it is not counting after a failed save, until one works', async () => {
    const database = createMemoryUsageStore();
    const limiter = createUsageLimiter(plans(), database.store);
    assert.equal(limiter.isCounting(), true);

    database.failing.writes = true;
    await limiter.recordInteraction(user);
    assert.equal(limiter.isCounting(), false);

    database.failing.writes = false;
    await limiter.recordInteraction(user);
    assert.equal(limiter.isCounting(), true);
  });

  it('fails if the database has no personal plan', async () => {
    const limiter = createUsageLimiter(plans(), createMemoryUsageStore({}).store);
    await assert.rejects(() => limiter.snapshot(user), UsageStoreError);
  });
});

describe('plans configuration', () => {
  it('ships the personal plan with 5 messages a minute and no daily cap', () => {
    assert.deepEqual(loadPlansConfig().personal, { rateLimit: { requests: 5, windowSeconds: 60 } });
  });

  const invalid: [string, unknown][] = [
    ['no personal plan', { family: plans().personal }],
    ['a rate limit without a window', { personal: { rateLimit: { requests: 5 } } }],
    ['a rate limit of zero requests', plans(0)],
  ];

  for (const [name, raw] of invalid) {
    it(`refuses ${name}`, () => {
      assert.throws(() => parsePlansConfig(raw), PlansConfigError);
    });
  }
});

describe('limits in POST /v1/chat', () => {
  it('returns usage and counts only successful replies', async () => {
    const app = await startApp({ llm: createFakeLlm().llm, usage: createMemoryUsageStore({ personal: 5 }).store });
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
    const app = await startApp({ llm: createFakeLlm().llm, usage: createMemoryUsageStore({ personal: 1 }).store });
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
    const app = await startApp({ llm: fake.llm, usage: createMemoryUsageStore({ personal: 1 }).store });
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
    const app = await startApp({ llm: createFakeLlm().llm, plans: plans(2, 60) });
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
      usage: createMemoryUsageStore({ personal: 5 }).store,
    });
    try {
      const response = await app.postJson('/v1/chat', { message: 'hola' });
      assert.equal(response.status, 503);

      const usage = (await (
        await app.request('/v1/usage', { headers: app.authHeader })
      ).json()) as any;
      assert.equal(usage.used, 0);
    } finally {
      await app.close();
    }
  });
});

describe('GET /v1/usage', () => {
  it('returns the usage of the caller, behind the token', async () => {
    const app = await startApp({ llm: createFakeLlm().llm, usage: createMemoryUsageStore({ personal: 30 }).store });
    try {
      assert.equal((await app.request('/v1/usage')).status, 401);

      const response = await app.request('/v1/usage', {
        headers: app.authHeader,
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

describe('usage in the database (S4-13)', () => {
  it('keeps the count across a restart: a new app over the same database', async () => {
    const database = createMemoryUsageStore({ personal: 5 });
    const first = await startApp({ llm: createFakeLlm().llm, usage: database.store });
    try {
      await first.postJson('/v1/chat', { message: 'hola' });
      await first.postJson('/v1/chat', { message: 'hola' });
    } finally {
      await first.close();
    }

    const restarted = await startApp({ llm: createFakeLlm().llm, usage: database.store });
    try {
      const usage = (await (
        await restarted.request('/v1/usage', { headers: restarted.authHeader })
      ).json()) as any;
      assert.equal(usage.used, 2);
      assert.equal(usage.remaining, 3);
    } finally {
      await restarted.close();
    }
  });

  it('applies a cap changed in plan_limits to the next message, with no restart', async () => {
    const database = createMemoryUsageStore({ personal: 100 });
    const app = await startApp({ llm: createFakeLlm().llm, usage: database.store });
    try {
      assert.equal((await app.postJson('/v1/chat', { message: 'uno' })).status, 200);

      database.caps.personal = 1;
      const response = await app.postJson('/v1/chat', { message: 'dos' });

      assert.equal(response.status, 429);
      assert.equal(((await response.json()) as any).error.code, 'DAILY_LIMIT_REACHED');
    } finally {
      await app.close();
    }
  });

  it('answers 500 before calling the model when the count cannot be read', async () => {
    const database = createMemoryUsageStore();
    database.failing.reads = true;
    const fake = createFakeLlm();
    const app = await startApp({ llm: fake.llm, usage: database.store });
    try {
      const { result } = await captureConsole(() => app.postJson('/v1/chat', { message: 'hola' }));

      assert.equal(result.status, 500);
      assert.equal(fake.requests.length, 0);
    } finally {
      await app.close();
    }
  });

  it('delivers the reply without usage when the count cannot be saved', async () => {
    const database = createMemoryUsageStore();
    database.failing.writes = true;
    const app = await startApp({ llm: createFakeLlm().llm, usage: database.store });
    try {
      const response = await app.postJson('/v1/chat', { message: 'hola' });
      const body = (await response.json()) as any;

      assert.equal(response.status, 200);
      assert.equal(body.type, 'reply');
      assert.equal('usage' in body, false);
    } finally {
      await app.close();
    }
  });

  it('answers a crisis even if the database cannot be read', async () => {
    const database = createMemoryUsageStore();
    database.failing.reads = true;
    const app = await startApp({ llm: createFakeLlm().llm, usage: database.store });
    try {
      const response = await app.postJson('/v1/chat', { message: 'me quiero morir' });
      const body = (await response.json()) as any;

      assert.equal(response.status, 200);
      assert.equal(body.type, 'crisis');
      assert.equal('usage' in body, false);
    } finally {
      await app.close();
    }
  });
});

describe('GET /health and the usage counter', () => {
  it('says ok, then degraded while counting fails, then ok again', async () => {
    const database = createMemoryUsageStore();
    const app = await startApp({ llm: createFakeLlm().llm, usage: database.store });
    try {
      assert.deepEqual(await (await app.request('/health')).json(), { status: 'ok' });

      database.failing.writes = true;
      assert.equal((await app.postJson('/v1/chat', { message: 'hola' })).status, 200);
      const degraded = await app.request('/health');
      assert.equal(degraded.status, 200);
      assert.deepEqual(await degraded.json(), { status: 'degraded', problems: ['usage_counter'] });

      database.failing.writes = false;
      await app.postJson('/v1/chat', { message: 'hola' });
      assert.deepEqual(await (await app.request('/health')).json(), { status: 'ok' });
    } finally {
      await app.close();
    }
  });
});
