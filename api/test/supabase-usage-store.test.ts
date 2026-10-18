import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createSupabaseUsageStore } from '../src/services/usage/supabase-usage-store.js';
import { UsageStoreError } from '../src/services/usage/usage-store.js';
import { fakeSupabaseClient } from './fake-supabase.js';
import { captureConsole } from './helpers.js';

const USER = '00000000-0000-4000-8000-00000000000a';

function fakeSupabase(
  respond: Parameters<typeof fakeSupabaseClient>[0],
  now: () => number = Date.now,
) {
  const { client, calls } = fakeSupabaseClient(respond);
  return { store: createSupabaseUsageStore(client, now), calls };
}

describe('createSupabaseUsageStore', () => {
  it('reads the count of one user on one day, and 0 if there is no row', async () => {
    const { store, calls } = fakeSupabase((call) => ({
      body: call.params.get('user_id') === `eq.${USER}` ? { interactions: 4 } : null,
    }));

    assert.equal(await store.used(USER, '2026-10-17'), 4);
    assert.equal(calls[0]!.table, 'daily_usage');
    assert.equal(calls[0]!.params.get('usage_date'), 'eq.2026-10-17');
    assert.equal(await store.used('someone-else', '2026-10-17'), 0);
  });

  it('reads the cap of a plan, and undefined for an unknown plan', async () => {
    const { store, calls } = fakeSupabase((call) => ({
      body: call.params.get('plan') === 'eq.personal' ? { daily_interactions: 100 } : null,
    }));

    assert.equal(await store.dailyCap('personal'), 100);
    assert.equal(await store.dailyCap('premium'), undefined);
    assert.equal(calls[0]!.table, 'plan_limits');
  });

  it('keeps a cap for a minute and then reads it again', async () => {
    let clock = 0;
    let cap = 100;
    const { store, calls } = fakeSupabase(() => ({ body: { daily_interactions: cap } }), () => clock);

    assert.equal(await store.dailyCap('personal'), 100);
    cap = 50;
    clock = 59_000;
    assert.equal(await store.dailyCap('personal'), 100);
    assert.equal(calls.length, 1);

    clock = 61_000;
    assert.equal(await store.dailyCap('personal'), 50);
    assert.equal(calls.length, 2);
  });

  it('keeps using the known cap if the database fails afterwards', async () => {
    let clock = 0;
    let failing = false;
    const { store } = fakeSupabase(
      () => (failing ? { status: 500, body: { code: 'XX000' } } : { body: { daily_interactions: 100 } }),
      () => clock,
    );

    await store.dailyCap('personal');
    failing = true;
    clock = 120_000;

    const { result } = await captureConsole(() => store.dailyCap('personal'));
    assert.equal(result, 100);
  });

  it('counts through the record_interaction function and returns the new total', async () => {
    const { store, calls } = fakeSupabase(() => ({ body: 3 }));

    assert.equal(await store.record(USER, '2026-10-17'), 3);
    assert.equal(calls[0]!.method, 'POST');
    assert.equal(calls[0]!.table, 'record_interaction');
    assert.deepEqual(calls[0]!.body, { p_user_id: USER, p_day: '2026-10-17' });
  });

  it('fails without quoting the database', async () => {
    const { store } = fakeSupabase(() => ({
      status: 400,
      body: { code: '23505', message: 'duplicate key value', details: 'Key (user_id)=(secret)' },
    }));

    const { result, output } = await captureConsole(() =>
      store.record(USER, '2026-10-17').catch((error: unknown) => error),
    );

    assert.ok(result instanceof UsageStoreError);
    assert.match(output, /23505/);
    assert.doesNotMatch(output, /secret|duplicate/);
  });
});
