import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { LlmError } from '../src/services/llm/index.js';
import { createMemoryJob, MAX_MEMORIES_PER_USER } from '../src/services/memory/memory-job.js';
import { captureConsole } from './helpers.js';
import {
  createFakeConversations,
  createFakeExtractor,
  createFakeMemories,
  said,
} from './memory-fakes.js';

const ANA = '00000000-0000-4000-8000-00000000000a';
const BETO = '00000000-0000-4000-8000-00000000000b';

function setup({
  respond,
  maxAttempts,
  memories = [],
}: {
  respond?: Parameters<typeof createFakeExtractor>[0];
  maxAttempts?: number;
  memories?: Parameters<typeof createFakeMemories>[0];
} = {}) {
  const conversations = createFakeConversations();
  const stored = createFakeMemories(memories);
  const model = createFakeExtractor(respond);
  const job = createMemoryJob({
    conversations: conversations.store,
    memories: stored.store,
    extractor: model.extractor,
    idleSeconds: 1800,
    spacingMs: 0,
    ...(maxAttempts ? { maxAttempts } : {}),
  });
  return { conversations, stored, model, job };
}

describe('memory job', () => {
  it('saves the facts of an ended conversation with their category and marks it done', async () => {
    const { conversations, stored, model, job } = setup({
      respond: () => [{ id: null, fact: 'Tiene una perrita llamada Coco', category: 'pets' }],
    });
    const conversation = conversations.add(ANA, said('Mi perrita se llama Coco'));

    await job.sweep();

    assert.equal(model.calls.length, 1);
    assert.deepEqual(model.calls[0]!.transcript, conversation.messages);
    assert.deepEqual(
      stored.rows.map(({ userId, fact, category }) => ({ userId, fact, category })),
      [{ userId: ANA, fact: 'Tiene una perrita llamada Coco', category: 'pets' }],
    );
    assert.equal(conversation.extracted, true);
  });

  it('shows the saved memories to the extractor and updates a fact instead of duplicating it', async () => {
    const { conversations, stored, model, job } = setup({
      memories: [{ id: 'm1', userId: ANA, fact: 'Tiene un perro', category: 'pets' }],
      respond: () => [{ id: 'm1', fact: 'Tiene una perrita llamada Coco', category: 'pets' }],
    });
    conversations.add(ANA, said('Mi perrita se llama Coco'));

    await job.sweep();

    assert.deepEqual(model.calls[0]!.existing, [
      { id: 'm1', fact: 'Tiene un perro', category: 'pets' },
    ]);
    assert.equal(stored.rows.length, 1);
    assert.equal(stored.rows[0]!.fact, 'Tiene una perrita llamada Coco');
  });

  it('does not call the model when the person said nothing', async () => {
    const { conversations, model, job } = setup();
    const conversation = conversations.add(ANA, [{ role: 'assistant', content: 'Hola' }]);

    await job.sweep();

    assert.equal(model.calls.length, 0);
    assert.equal(conversation.extracted, true);
  });

  it('keeps the memories of each user apart', async () => {
    const { conversations, stored, job } = setup({
      respond: ({ transcript }) => [
        { id: null, fact: `Dijo: ${transcript[0]!.content}`, category: 'other' },
      ],
    });
    conversations.add(ANA, said('cosa de Ana'));
    conversations.add(BETO, said('cosa de Beto'));

    await job.sweep();

    assert.deepEqual(
      stored.rows.map((row) => [row.userId, row.fact]),
      [
        [ANA, 'Dijo: cosa de Ana'],
        [BETO, 'Dijo: cosa de Beto'],
      ],
    );
  });

  it('runs one extraction at a time', async () => {
    let active = 0;
    let most = 0;
    const { conversations, job } = setup({
      respond: async () => {
        active += 1;
        most = Math.max(most, active);
        await new Promise((resolve) => setTimeout(resolve, 5));
        active -= 1;
        return [];
      },
    });
    for (let i = 0; i < 4; i++) conversations.add(ANA, said(`mensaje ${i}`));

    await job.sweep();

    assert.equal(most, 1);
    assert.ok(conversations.conversations.every((c) => c.extracted));
  });

  it('leaves a failed extraction pending and tries again until the limit', async () => {
    const { conversations, model, job } = setup({
      maxAttempts: 2,
      respond: () => {
        throw new LlmError('rate_limited', 'busy');
      },
    });
    const conversation = conversations.add(ANA, said('algo'));

    const { output } = await captureConsole(async () => {
      await job.sweep();
      assert.equal(conversation.extracted, false);
      await job.sweep();
      await job.sweep();
    });

    assert.equal(model.calls.length, 2);
    assert.equal(conversation.extracted, false);
    assert.match(output, /LLM rate_limited/);
    assert.match(output, /giving up/);
  });

  it('adds nothing past the ceiling, but still updates', async () => {
    const full = Array.from({ length: MAX_MEMORIES_PER_USER }, (_, i) => ({
      id: `m${i}`,
      userId: ANA,
      fact: `Dato ${i}`,
      category: 'other',
    }));
    const { conversations, stored, job } = setup({
      memories: full,
      respond: () => [
        { id: null, fact: 'Un dato nuevo', category: 'other' },
        { id: 'm0', fact: 'Dato 0 corregido', category: 'other' },
      ],
    });
    conversations.add(ANA, said('algo'));

    await job.sweep();

    assert.equal(stored.rows.length, MAX_MEMORIES_PER_USER);
    assert.equal(stored.rows[0]!.fact, 'Dato 0 corregido');
  });

  it('logs how many facts it kept, never the facts', async () => {
    const { conversations, job } = setup({
      respond: () => [{ id: null, fact: 'Tiene una perrita llamada Coco', category: 'pets' }],
    });
    conversations.add(ANA, said('Mi perrita se llama Coco'));

    const { output } = await captureConsole(() => job.sweep());

    assert.match(output, /1 added, 0 updated/);
    assert.doesNotMatch(output, /Coco/);
  });
});

describe('ending idle conversations', () => {
  it('ends the conversation of the user and extracts it after returning', async () => {
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => (release = resolve));
    const { conversations, stored, job } = setup({
      respond: async () => {
        await gate;
        return [{ id: null, fact: 'Le gusta caminar', category: 'hobbies' }];
      },
    });
    const idle = conversations.add(ANA, said('Me gusta caminar'), { ended: false, idle: true });
    const other = conversations.add(BETO, said('otra cosa'), { ended: false, idle: true });

    // The caller (a chat message) gets control back while the model has not answered yet.
    await job.endIdleConversation(ANA);
    assert.equal(idle.ended, true);
    assert.equal(other.ended, false);
    assert.equal(stored.rows.length, 0);

    release();
    await job.whenIdle();
    assert.equal(stored.rows.length, 1);
    assert.equal(idle.extracted, true);
    assert.equal(other.extracted, false);
  });

  it('does nothing when the conversation is still active', async () => {
    const { conversations, model, job } = setup();
    const active = conversations.add(ANA, said('hola'), { ended: false, idle: false });

    await job.endIdleConversation(ANA);
    await job.whenIdle();

    assert.equal(active.ended, false);
    assert.equal(model.calls.length, 0);
  });

  it('never fails when the database does: a chat message cannot depend on the memory', async () => {
    const { conversations, job } = setup();
    conversations.failClosing(new Error('database down'));

    await job.endIdleConversation(ANA);
    await assert.doesNotReject(job.sweep());
  });

  it('a sweep ends everybody idle conversations and extracts them', async () => {
    const { conversations, model, job } = setup();
    conversations.add(ANA, said('uno'), { ended: false, idle: true });
    conversations.add(BETO, said('dos'), { ended: false, idle: true });

    await job.sweep();

    assert.equal(model.calls.length, 2);
    assert.ok(conversations.conversations.every((c) => c.ended && c.extracted));
  });
});
