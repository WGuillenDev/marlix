import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createRetentionJob } from '../src/services/retention/retention-job.js';
import { captureConsole } from './helpers.js';
import { createMemoryMessageStore } from './memory-message-store.js';

const ANA = '00000000-0000-4000-8000-00000000000a';
// The fake store stamps its messages from 2026-10-01T12:00:00Z on.
const day = (iso: string) => () => new Date(`${iso}T12:00:00.000Z`);

async function turn(store: ReturnType<typeof createMemoryMessageStore>['store'], text: string) {
  await store.saveTurn(ANA, {
    message: text,
    reply: 'ok',
    messageAt: new Date(),
    crisis: false,
  });
}

describe('retention job', () => {
  it('deletes the messages older than the retention period and keeps the rest', async () => {
    const { store, rows } = createMemoryMessageStore();
    await turn(store, 'viejo');
    const job = createRetentionJob({ messages: store, retentionDays: 90, now: day('2026-12-31') });

    assert.equal(await job.sweep(), 2);
    assert.equal(rows.length, 0);
  });

  it('keeps messages that are still inside the period', async () => {
    const { store, rows } = createMemoryMessageStore();
    await turn(store, 'reciente');
    const job = createRetentionJob({ messages: store, retentionDays: 90, now: day('2026-12-29') });

    assert.equal(await job.sweep(), 0);
    assert.equal(rows.length, 2);
  });

  it('uses the configured period', async () => {
    const { store, rows } = createMemoryMessageStore();
    await turn(store, 'hola');

    await createRetentionJob({
      messages: store,
      retentionDays: 30,
      now: day('2026-10-20'),
    }).sweep();
    assert.equal(rows.length, 2);

    await createRetentionJob({
      messages: store,
      retentionDays: 7,
      now: day('2026-10-20'),
    }).sweep();
    assert.equal(rows.length, 0);
  });

  it('does not throw when the database fails, and logs no content', async () => {
    const { store } = createMemoryMessageStore();
    store.deleteOlderThan = async () => {
      throw Object.assign(new Error('me siento muy solo'), { name: 'HistoryStoreError' });
    };
    const job = createRetentionJob({ messages: store, retentionDays: 90 });

    const { result, output } = await captureConsole(() => job.sweep());

    assert.equal(result, 0);
    assert.match(output, /HistoryStoreError/);
    assert.doesNotMatch(output, /solo/);
  });

  it('start sweeps at once and stop ends the timer', async () => {
    const { store } = createMemoryMessageStore();
    let sweeps = 0;
    store.deleteOlderThan = async () => {
      sweeps += 1;
      return 0;
    };
    const job = createRetentionJob({ messages: store, retentionDays: 90, sweepEveryMs: 5 });

    job.start();
    job.start();
    await new Promise((resolve) => setTimeout(resolve, 40));
    job.stop();
    const stopped = sweeps;
    await new Promise((resolve) => setTimeout(resolve, 40));

    assert.ok(stopped >= 2);
    assert.equal(sweeps, stopped);
  });
});
