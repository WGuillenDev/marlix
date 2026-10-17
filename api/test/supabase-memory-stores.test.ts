import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createSupabaseConversationStore } from '../src/services/conversations/supabase-conversation-store.js';
import { DatabaseError } from '../src/services/database-error.js';
import { createSupabaseMemoryStore } from '../src/services/memory/supabase-memory-store.js';
import { fakeSupabaseClient } from './fake-supabase.js';
import { captureConsole } from './helpers.js';

const USER = '00000000-0000-4000-8000-00000000000a';
const CONVERSATION = '11111111-1111-4111-8111-111111111111';

describe('createSupabaseConversationStore', () => {
  it('ends the idle conversations of one user, or of everybody, with the database function', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({ body: [CONVERSATION] }));
    const store = createSupabaseConversationStore(client);

    assert.equal(await store.closeIdle(1800, USER), 1);
    assert.equal(await store.closeIdle(1800), 1);

    assert.deepEqual(calls.map((c) => [c.method, c.table]), [
      ['POST', 'close_idle_conversations'],
      ['POST', 'close_idle_conversations'],
    ]);
    assert.deepEqual(calls[0]!.body, { p_idle_seconds: 1800, p_user_id: USER });
    assert.deepEqual(calls[1]!.body, { p_idle_seconds: 1800, p_user_id: null });
  });

  it('lists the conversations that ended and still wait for their memory, oldest first', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({
      body: [{ id: CONVERSATION, user_id: USER }],
    }));
    const pending = await createSupabaseConversationStore(client).listPending();

    assert.deepEqual(pending, [{ id: CONVERSATION, userId: USER }]);
    const query = calls[0]!.params;
    assert.equal(query.get('ended_at'), 'not.is.null');
    assert.equal(query.get('memory_extracted_at'), 'is.null');
    assert.equal(query.get('order'), 'ended_at.asc');
  });

  it('reads a conversation of that user only, without the messages of a crisis', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({
      body: [
        { role: 'assistant', content: 'dos' },
        { role: 'user', content: 'uno' },
      ],
    }));

    const transcript = await createSupabaseConversationStore(client).transcript(CONVERSATION, USER);

    assert.deepEqual(transcript, [
      { role: 'user', content: 'uno' },
      { role: 'assistant', content: 'dos' },
    ]);
    const query = calls[0]!.params;
    assert.equal(query.get('conversation_id'), `eq.${CONVERSATION}`);
    assert.equal(query.get('user_id'), `eq.${USER}`);
    assert.equal(query.get('crisis'), 'eq.false');
  });

  it('marks a conversation of that user as extracted', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({ body: [] }));
    await createSupabaseConversationStore(client).markExtracted(CONVERSATION, USER);

    const call = calls[0]!;
    assert.equal(call.method, 'PATCH');
    assert.equal(call.params.get('id'), `eq.${CONVERSATION}`);
    assert.equal(call.params.get('user_id'), `eq.${USER}`);
    assert.ok(!Number.isNaN(Date.parse((call.body as { memory_extracted_at: string }).memory_extracted_at)));
  });

  it('fails without quoting the database', async () => {
    const { client } = fakeSupabaseClient(() => ({
      status: 400,
      body: { code: '42501', message: 'permission denied', details: 'Mi perro se llama Coco' },
    }));

    const { result, output } = await captureConsole(() =>
      createSupabaseConversationStore(client)
        .transcript(CONVERSATION, USER)
        .catch((error: unknown) => error),
    );

    assert.ok(result instanceof DatabaseError);
    assert.match(output, /42501/);
    assert.doesNotMatch(output + (result as Error).message, /Coco|permission/);
  });
});

describe('createSupabaseMemoryStore', () => {
  it('lists the memories of that user only', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({
      body: [
        {
          id: 'm1',
          fact: 'Tiene un perro',
          category: 'pets',
          created_at: '2026-10-01T12:00:00+00:00',
          updated_at: '2026-10-02T12:00:00+00:00',
        },
      ],
    }));

    const memories = await createSupabaseMemoryStore(client).list(USER);

    assert.deepEqual(memories, [
      {
        id: 'm1',
        fact: 'Tiene un perro',
        category: 'pets',
        createdAt: '2026-10-01T12:00:00+00:00',
        updatedAt: '2026-10-02T12:00:00+00:00',
      },
    ]);
    assert.equal(calls[0]!.params.get('user_id'), `eq.${USER}`);
  });

  it('saves a memory with its category and the conversation it came from', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({ body: [] }));

    await createSupabaseMemoryStore(client).add(USER, {
      fact: 'Tiene un perro',
      category: 'pets',
      sourceConversationId: CONVERSATION,
    });

    assert.deepEqual(calls[0]!.body, {
      user_id: USER,
      fact: 'Tiene un perro',
      category: 'pets',
      source_conversation_id: CONVERSATION,
    });
  });

  it('rewrites only a memory of that user, and says if there was none', async () => {
    const found = fakeSupabaseClient(() => ({ body: [{ id: 'm1' }] }));
    const updated = await createSupabaseMemoryStore(found.client).update(USER, 'm1', {
      fact: 'Tiene una perrita',
      category: 'pets',
    });
    assert.equal(updated, true);
    assert.equal(found.calls[0]!.params.get('id'), 'eq.m1');
    assert.equal(found.calls[0]!.params.get('user_id'), `eq.${USER}`);
    assert.deepEqual(found.calls[0]!.body, { fact: 'Tiene una perrita', category: 'pets' });

    const missing = fakeSupabaseClient(() => ({ body: [] }));
    assert.equal(
      await createSupabaseMemoryStore(missing.client).update(USER, 'm9', { fact: 'x', category: 'other' }),
      false,
    );
  });

  it('edits only the text of a memory of that user and returns it', async () => {
    const row = { id: 'm1', fact: 'Tiene una perrita', category: 'pets', created_at: 'c', updated_at: 'u' };
    const { client, calls } = fakeSupabaseClient(() => ({ body: [row] }));
    const store = createSupabaseMemoryStore(client);

    assert.deepEqual(await store.edit(USER, 'm1', 'Tiene una perrita'), {
      id: 'm1',
      fact: 'Tiene una perrita',
      category: 'pets',
      createdAt: 'c',
      updatedAt: 'u',
    });
    assert.equal(calls[0]!.method, 'PATCH');
    assert.deepEqual(calls[0]!.body, { fact: 'Tiene una perrita' });
    assert.equal(calls[0]!.params.get('id'), 'eq.m1');
    assert.equal(calls[0]!.params.get('user_id'), `eq.${USER}`);

    const missing = fakeSupabaseClient(() => ({ body: [] }));
    assert.equal(await createSupabaseMemoryStore(missing.client).edit(USER, 'm9', 'x'), null);
  });

  it('deletes one memory of that user, or all of them, and says if there was none', async () => {
    const found = fakeSupabaseClient(() => ({ body: [{ id: 'm1' }] }));
    assert.equal(await createSupabaseMemoryStore(found.client).remove(USER, 'm1'), true);
    assert.equal(found.calls[0]!.method, 'DELETE');
    assert.equal(found.calls[0]!.params.get('id'), 'eq.m1');
    assert.equal(found.calls[0]!.params.get('user_id'), `eq.${USER}`);

    const missing = fakeSupabaseClient(() => ({ body: [] }));
    assert.equal(await createSupabaseMemoryStore(missing.client).remove(USER, 'm9'), false);

    const all = fakeSupabaseClient(() => ({ body: [] }));
    await createSupabaseMemoryStore(all.client).removeAll(USER);
    assert.equal(all.calls[0]!.method, 'DELETE');
    assert.equal(all.calls[0]!.params.get('user_id'), `eq.${USER}`);
    assert.equal(all.calls[0]!.params.get('id'), null);
  });

  it('fails without quoting the database when editing or deleting', async () => {
    const { client } = fakeSupabaseClient(() => ({
      status: 400,
      body: { code: '42501', message: 'denied', details: 'Mi perro se llama Coco' },
    }));
    const store = createSupabaseMemoryStore(client);

    const { result, output } = await captureConsole(async () => [
      await store.edit(USER, 'm1', 'x').catch((error: unknown) => error),
      await store.remove(USER, 'm1').catch((error: unknown) => error),
      await store.removeAll(USER).catch((error: unknown) => error),
    ]);

    for (const error of result) assert.ok(error instanceof DatabaseError);
    assert.doesNotMatch(output, /Coco|denied/);
  });
});
