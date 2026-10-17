import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { decodeCursor, HistoryStoreError } from '../src/services/history/message-store.js';
import { createSupabaseMessageStore } from '../src/services/history/supabase-message-store.js';
import { fakeSupabaseClient } from './fake-supabase.js';
import { captureConsole } from './helpers.js';

const USER = '00000000-0000-4000-8000-00000000000a';
const CONVERSATION = '11111111-1111-4111-8111-111111111111';
const AVATAR = '22222222-2222-4222-8222-222222222222';

/** The message store over a fake Supabase. */
function fakeSupabase(respond: Parameters<typeof fakeSupabaseClient>[0]) {
  const { client, calls } = fakeSupabaseClient(respond);
  return { store: createSupabaseMessageStore(client), calls };
}

const row = (id: string, role: 'user' | 'assistant', createdAt: string) => ({
  id,
  role,
  content: `texto ${id}`,
  created_at: createdAt,
  interrupted: false,
});

describe('createSupabaseMessageStore', () => {
  it('saves both messages of a turn in one insert, in the open conversation', async () => {
    const { store, calls } = fakeSupabase((call) => {
      if (call.table === 'conversations') return { body: [{ id: CONVERSATION }] };
      return {
        body: [
          row('a', 'assistant', '2026-10-01T12:00:01.5+00:00'),
          row('u', 'user', '2026-10-01T12:00:00+00:00'),
        ],
      };
    });

    const turn = await store.saveTurn(USER, {
      message: 'Hola',
      reply: '¡Hola!',
      messageAt: new Date('2026-10-01T12:00:00Z'),
      crisis: false,
    });

    assert.equal(turn.userMessage.id, 'u');
    assert.equal(turn.reply.id, 'a');
    assert.equal(turn.reply.createdAt, '2026-10-01T12:00:01.500Z');

    const conversation = calls[0]!;
    assert.equal(conversation.params.get('user_id'), `eq.${USER}`);
    assert.equal(conversation.params.get('ended_at'), 'is.null');

    const inserts = calls.filter((call) => call.method === 'POST');
    assert.equal(inserts.length, 1);
    const [user, reply] = inserts[0]!.body as Record<string, string>[];
    assert.deepEqual(
      { ...user, ...{ created_at: undefined } },
      {
        user_id: USER,
        conversation_id: CONVERSATION,
        role: 'user',
        content: 'Hola',
        crisis: false,
        created_at: undefined,
      },
    );
    assert.equal(user!.created_at, '2026-10-01T12:00:00.000Z');
    assert.equal(reply!.role, 'assistant');
    assert.ok(Date.parse(reply!.created_at!) > Date.parse(user!.created_at!));
  });

  it("starts a conversation with the user's avatar when none is open", async () => {
    const { store, calls } = fakeSupabase((call) => {
      if (call.table === 'conversations' && call.method === 'GET') return { body: [] };
      if (call.table === 'users') return { body: { avatar_id: AVATAR } };
      if (call.table === 'conversations') return { body: { id: CONVERSATION } };
      return { body: [row('u', 'user', '2026-10-01T12:00:00Z'), row('a', 'assistant', '2026-10-01T12:00:01Z')] };
    });

    await store.saveTurn(USER, {
      message: 'Hola',
      reply: 'Hola',
      messageAt: new Date(),
      crisis: false,
    });

    const created = calls.find((call) => call.table === 'conversations' && call.method === 'POST');
    assert.deepEqual(created!.body, { user_id: USER, avatar_id: AVATAR });
    const profile = calls.find((call) => call.table === 'users');
    assert.equal(profile!.params.get('id'), `eq.${USER}`);
  });

  it('marks both messages of a crisis turn', async () => {
    const { store, calls } = fakeSupabase((call) =>
      call.table === 'conversations'
        ? { body: [{ id: CONVERSATION }] }
        : { body: [row('u', 'user', '2026-10-01T12:00:00Z'), row('a', 'assistant', '2026-10-01T12:00:01Z')] },
    );

    await store.saveTurn(USER, { message: 'x', reply: 'y', messageAt: new Date(), crisis: true });

    const inserted = calls.find((call) => call.method === 'POST')!.body as { crisis: boolean }[];
    assert.deepEqual(
      inserted.map((message) => message.crisis),
      [true, true],
    );
  });

  it('reads the context: the last messages of the open conversation, without crises', async () => {
    const { store, calls } = fakeSupabase((call) =>
      call.table === 'conversations'
        ? { body: [{ id: CONVERSATION }] }
        : {
            body: [
              { role: 'assistant', content: 'dos' },
              { role: 'user', content: 'uno' },
            ],
          },
    );

    const recent = await store.recent(USER, 16);

    assert.deepEqual(recent, [
      { role: 'user', content: 'uno' },
      { role: 'assistant', content: 'dos' },
    ]);
    const query = calls.find((call) => call.table === 'messages')!.params;
    assert.equal(query.get('user_id'), `eq.${USER}`);
    assert.equal(query.get('conversation_id'), `eq.${CONVERSATION}`);
    assert.equal(query.get('crisis'), 'eq.false');
    assert.equal(query.get('order'), 'created_at.desc,id.desc');
    assert.equal(query.get('limit'), '16');
  });

  it('has no context before the first conversation, and does not create one', async () => {
    const { store, calls } = fakeSupabase(() => ({ body: [] }));

    assert.deepEqual(await store.recent(USER, 16), []);
    assert.deepEqual(
      calls.map((call) => `${call.method} ${call.table}`),
      ['GET conversations'],
    );
  });

  it('reads a page of the caller only, newest first, asking for one extra row', async () => {
    const [a, b, c] = [1, 2, 3].map((n) => `33333333-3333-4333-8333-33333333333${n}`) as [
      string,
      string,
      string,
    ];
    const { store, calls } = fakeSupabase(() => ({
      body: [
        row(c, 'assistant', '2026-10-01T12:00:03.123456+00:00'),
        row(b, 'user', '2026-10-01T12:00:02+00:00'),
        row(a, 'assistant', '2026-10-01T12:00:01+00:00'),
      ],
    }));

    const page = await store.page(USER, { limit: 2 });

    const call = calls[0]!;
    assert.equal(call.params.get('user_id'), `eq.${USER}`);
    assert.equal(call.params.get('order'), 'created_at.desc,id.desc');
    assert.equal(call.params.get('limit'), '3');
    assert.deepEqual(
      page.messages.map((m) => m.id),
      [b, c],
    );
    // The cursor points at the oldest message of the page, with the database's precision.
    assert.deepEqual(decodeCursor(page.nextCursor!), {
      createdAt: '2026-10-01T12:00:02+00:00',
      id: b,
    });
  });

  it('has no cursor on the last page', async () => {
    const { store } = fakeSupabase(() => ({ body: [row('a', 'user', '2026-10-01T12:00:00Z')] }));
    const page = await store.page(USER, { limit: 2 });
    assert.equal(page.nextCursor, null);
  });

  it('continues after the cursor with a tie-break on the id', async () => {
    const { store, calls } = fakeSupabase(() => ({ body: [] }));
    const createdAt = '2026-10-01T12:00:02.5+00:00';
    const id = '33333333-3333-4333-8333-333333333333';

    await store.page(USER, { limit: 10, before: { createdAt, id } });

    assert.equal(
      calls[0]!.params.get('or'),
      `(created_at.lt.${createdAt},and(created_at.eq.${createdAt},id.lt.${id}))`,
    );
  });

  it("marks only the caller's own replies as interrupted", async () => {
    const { store, calls } = fakeSupabase(() => ({ body: [{ id: 'a' }] }));
    assert.equal(await store.markInterrupted(USER, 'a'), true);

    const call = calls[0]!;
    assert.equal(call.method, 'PATCH');
    assert.deepEqual(call.body, { interrupted: true });
    assert.equal(call.params.get('user_id'), `eq.${USER}`);
    assert.equal(call.params.get('role'), 'eq.assistant');
  });

  it('reports a reply that is not found', async () => {
    const { store } = fakeSupabase(() => ({ body: [] }));
    assert.equal(await store.markInterrupted(USER, 'a'), false);
  });

  it('fails without quoting the database, which can contain the message', async () => {
    const { store } = fakeSupabase(() => ({
      status: 400,
      body: {
        code: '23514',
        message: 'new row violates check constraint',
        details: 'Failing row contains (me siento muy solo)',
      },
    }));

    const { result, output } = await captureConsole(() =>
      store
        .page(USER, { limit: 10 })
        .then(() => undefined)
        .catch((error: unknown) => error),
    );

    assert.ok(result instanceof HistoryStoreError);
    assert.doesNotMatch(result.message, /solo/);
    assert.match(output, /23514/);
    assert.doesNotMatch(output, /solo|constraint/);
  });
});
