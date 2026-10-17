import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createMemoryJob } from '../src/services/memory/memory-job.js';
import { createFakeLlm, startApp } from './helpers.js';
import {
  createFakeConversations,
  createFakeExtractor,
  createFakeMemories,
  said,
} from './memory-fakes.js';

const USER = '00000000-0000-4000-8000-00000000000a';

describe('memory in POST /v1/chat', () => {
  it('ends an idle conversation before the message is answered, and also before a crisis', async () => {
    const asked: string[] = [];
    const app = await startApp({
      llm: createFakeLlm().llm,
      memoryJob: {
        endIdleConversation: async (userId) => {
          asked.push(userId);
        },
      },
    });
    try {
      await app.postJson('/v1/chat', { message: 'Hola otra vez' });
      await app.postJson('/v1/chat', { message: 'me quiero morir' });
    } finally {
      await app.close();
    }
    assert.deepEqual(asked, [USER, USER]);
  });

  it('does not wait for the extraction to answer', async () => {
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => (release = resolve));
    const conversations = createFakeConversations();
    const memories = createFakeMemories();
    const model = createFakeExtractor(async () => {
      await gate;
      return [{ id: null, fact: 'Le gusta el café', category: 'preferences' }];
    });
    const job = createMemoryJob({
      conversations: conversations.store,
      memories: memories.store,
      extractor: model.extractor,
      idleSeconds: 1800,
      spacingMs: 0,
    });
    const old = conversations.add(USER, said('Me gusta el café'), { ended: false, idle: true });
    const app = await startApp({ llm: createFakeLlm().llm, memoryJob: job });
    try {
      const response = await app.postJson('/v1/chat', { message: 'Hola, volví' });

      // The reply is already here and the model of the extraction is still waiting.
      assert.equal(response.status, 200);
      assert.equal(old.ended, true);
      assert.equal(memories.rows.length, 0);

      release();
      await job.whenIdle();
      assert.deepEqual(memories.rows.map((row) => row.fact), ['Le gusta el café']);
      assert.equal(old.extracted, true);
    } finally {
      await app.close();
    }
  });

  it('answers even if the memory cannot end the conversation', async () => {
    const app = await startApp({
      llm: createFakeLlm().llm,
      memoryJob: {
        endIdleConversation: async () => {
          throw new Error('memory down');
        },
      },
    });
    try {
      const normal = await app.postJson('/v1/chat', { message: 'Hola' });
      const crisis = await app.postJson('/v1/chat', { message: 'me quiero morir' });

      assert.equal(normal.status, 200);
      assert.equal(crisis.status, 200);
      assert.equal(((await crisis.json()) as { type: string }).type, 'crisis');
    } finally {
      await app.close();
    }
  });
});
