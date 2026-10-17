import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createClient } from '@supabase/supabase-js';

import { decodeCursor, HistoryStoreError } from '../src/services/history/message-store.js';
import { createSupabaseMessageStore } from '../src/services/history/supabase-message-store.js';
import { captureConsole } from './helpers.js';

const USER = '00000000-0000-4000-8000-00000000000a';
const CONVERSATION = '11111111-1111-4111-8111-111111111111';
const AVATAR = '22222222-2222-4222-8222-222222222222';

interface Call {
  method: string;
  table: string;
  params: URLSearchParams;
  body: unknown;
}

/** Stands in for the Supabase API: records each call and answers from `respond`. */
function fakeSupabase(respond: (call: Call) => { status?: number; body: unknown }) {
  const calls: Call[] = [];
  const client = createClient('https://testproject.supabase.co', 'sb_secret_test', {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: async (input, init) => {
        const url = new URL(input instanceof Request ? input.url : String(input));
        const call: Call = {
          method: init?.method ?? 'GET',
          table: url.pathname.split('/').at(-1)!,
          params: url.searchParams,
          body: init?.body ? JSON.parse(String(init.body)) : undefined,
        };
        calls.push(call);
        const { status = 200, body } = respond(call);
        return new Response(JSON.stringify(body), {
          status,
          headers: { 'content-type': 'application/json' },
        });
      },
    },
  });
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

    await store.saveTurn(USER, { message: 'Hola', reply: 'Hola', messageAt: new Date() });

    const created = calls.find((call) => call.table === 'conversations' && call.method === 'POST');
    assert.deepEqual(created!.body, { user_id: USER, avatar_id: AVATAR });
    const profile = calls.find((call) => call.table === 'users');
    assert.equal(profile!.params.get('id'), `eq.${USER}`);
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
