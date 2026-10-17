import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { decodeCursor, encodeCursor } from '../src/services/history/message-store.js';
import { LlmError } from '../src/services/llm/index.js';
import { captureConsole, createFakeLlm, failingLlm, signSession, startApp } from './helpers.js';
import { createMemoryMessageStore } from './memory-message-store.js';

const OTHER_USER = '00000000-0000-4000-8000-00000000000b';

interface HistoryBody {
  messages: { id: string; role: string; content: string; createdAt: string; interrupted: boolean }[];
  nextCursor: string | null;
}

describe('chat history', () => {
  const memory = createMemoryMessageStore();
  const fake = createFakeLlm((request) => `Eco: ${request.messages.at(-1)!.content}`);
  let app: Awaited<ReturnType<typeof startApp>>;

  const history = async (query = '', token?: string) => {
    const headers = token ? { authorization: `Bearer ${token}` } : app.authHeader;
    const response = await app.request(`/v1/history${query}`, { headers });
    return { response, body: (await response.json()) as any };
  };

  before(async () => {
    app = await startApp({ llm: fake.llm, messages: memory.store });
  });
  after(() => app.close());

  it('starts empty', async () => {
    const { response, body } = await history();
    assert.equal(response.status, 200);
    assert.deepEqual(body, { messages: [], nextCursor: null });
  });

  it('saves every turn with role and date, and returns the saved ids', async () => {
    const response = await app.postJson('/v1/chat', { message: 'Hola marlix' });
    const chat = (await response.json()) as any;

    const { body } = await history();
    assert.equal(body.messages.length, 2);
    const [user, reply] = body.messages as HistoryBody['messages'];
    assert.equal(user!.id, chat.userMessage.id);
    assert.equal(user!.role, 'user');
    assert.equal(user!.content, 'Hola marlix');
    assert.equal(reply!.id, chat.reply.id);
    assert.equal(reply!.role, 'assistant');
    assert.equal(reply!.content, 'Eco: Hola marlix');
    assert.ok(Date.parse(user!.createdAt) < Date.parse(reply!.createdAt));
    assert.equal(body.nextCursor, null);
  });

  it('pages from the newest, oldest first within each page, without gaps or repeats', async () => {
    for (let i = 1; i <= 4; i++) await app.postJson('/v1/chat', { message: `mensaje ${i}` });
    // The turn of the previous test plus these four make 10 messages.

    const seen: string[] = [];
    let cursor: string | null = null;
    let pages = 0;
    do {
      const { body }: { body: HistoryBody } = await history(
        `?limit=4${cursor ? `&before=${cursor}` : ''}`,
      );
      pages += 1;
      assert.ok(body.messages.length <= 4);
      seen.unshift(...body.messages.map((m) => m.id));
      cursor = body.nextCursor;
    } while (cursor);

    assert.equal(pages, 3);
    assert.equal(new Set(seen).size, 10);
    const all = (await history('?limit=100')).body as HistoryBody;
    assert.deepEqual(
      seen,
      all.messages.map((m) => m.id),
    );
  });

  it('keeps the crisis message and its fixed reply in the history', async () => {
    const response = await app.postJson('/v1/chat', { message: 'me quiero matar' });
    const chat = (await response.json()) as any;
    assert.equal(chat.type, 'crisis');

    const { body } = await history('?limit=2');
    assert.deepEqual(
      body.messages.map((m: { id: string }) => m.id),
      [chat.userMessage.id, chat.reply.id],
    );
    assert.equal(body.messages[1].content, chat.reply.content);
  });

  it("never shows another user's messages", async () => {
    const token = await signSession({ claims: { sub: OTHER_USER } });
    const { body } = await history('?limit=100', token);
    assert.deepEqual(body, { messages: [], nextCursor: null });
  });

  it('never writes the content of a message to the logs', async () => {
    const secret = 'mi secreto de prueba 8271';
    const { output } = await captureConsole(async () => {
      await app.postJson('/v1/chat', { message: secret });
      await history('?limit=100');
    });
    assert.doesNotMatch(output, /secreto de prueba/);
  });

  it('needs a session', async () => {
    const response = await app.request('/v1/history');
    assert.equal(response.status, 401);
  });

  const invalidQueries: [string, string, string][] = [
    ['a zero limit', '?limit=0', 'limit'],
    ['a limit over 100', '?limit=101', 'limit'],
    ['a limit that is not a number', '?limit=muchos', 'limit'],
    ['a cursor that was not issued', '?before=abc', 'before'],
    ['an unknown parameter', '?page=2', 'query'],
  ];
  for (const [name, query, field] of invalidQueries) {
    it(`rejects ${name} with 400 VALIDATION_ERROR`, async () => {
      const { response, body } = await history(query);
      assert.equal(response.status, 400);
      assert.equal(body.error.code, 'VALIDATION_ERROR');
      assert.ok(body.error.details.fields.some((entry: { field: string }) => entry.field === field));
    });
  }

  it('marks a reply as interrupted', async () => {
    const chat = (await (await app.postJson('/v1/chat', { message: 'uno' })).json()) as any;
    const next = await app.postJson('/v1/chat', {
      message: 'dos',
      interruptedMessageId: chat.reply.id,
    });
    assert.equal(next.status, 200);

    const { body } = await history('?limit=100');
    const interrupted = body.messages.filter((m: { interrupted: boolean }) => m.interrupted);
    assert.deepEqual(
      interrupted.map((m: { id: string }) => m.id),
      [chat.reply.id],
    );
  });

  it('answers 404 NOT_FOUND to an interruptedMessageId that does not exist', async () => {
    const response = await app.postJson('/v1/chat', {
      message: 'cuatro',
      interruptedMessageId: '00000000-0000-4000-8000-0000000000ff',
    });
    assert.equal(response.status, 404);
    assert.equal(((await response.json()) as any).error.code, 'NOT_FOUND');
  });

  it('answers 404 NOT_FOUND to the id of a message of the user, which is not a reply', async () => {
    const chat = (await (await app.postJson('/v1/chat', { message: 'tres' })).json()) as any;
    const response = await app.postJson('/v1/chat', {
      message: 'cuatro',
      interruptedMessageId: chat.userMessage.id,
    });
    assert.equal(response.status, 404);
  });

  it("does not let a user interrupt another user's reply", async () => {
    const chat = (await (await app.postJson('/v1/chat', { message: 'cinco' })).json()) as any;
    const token = await signSession({ claims: { sub: OTHER_USER } });
    const response = await app.postJson(
      '/v1/chat',
      { message: 'hola', interruptedMessageId: chat.reply.id },
      { authorization: `Bearer ${token}` },
    );
    assert.equal(response.status, 404);
  });
});

describe('chat history when saving fails', () => {
  const memory = createMemoryMessageStore();
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: createFakeLlm().llm, messages: memory.store });
  });
  after(() => app.close());

  it('still answers a crisis with the help, only unsaved', async () => {
    memory.setFailing(true);
    const response = await app.postJson('/v1/chat', { message: 'me quiero matar' });
    memory.setFailing(false);

    assert.equal(response.status, 200);
    const body = (await response.json()) as any;
    assert.equal(body.type, 'crisis');
    assert.ok(body.reply.content.includes('9-1-1'));
    assert.equal(memory.rows.length, 0);
  });

  it('answers 500 and does not count a normal reply that could not be saved', async () => {
    memory.setFailing(true);
    const { result: response } = await captureConsole(() =>
      app.postJson('/v1/chat', { message: 'Hola' }),
    );
    memory.setFailing(false);
    assert.equal(response.status, 500);

    const usage = (await (await app.request('/v1/usage', { headers: app.authHeader })).json()) as any;
    assert.equal(usage.used, 0);
  });

  it('does not save a message when the model fails', async () => {
    const failing = await startApp({
      llm: failingLlm(new LlmError('unavailable', 'down')),
      messages: memory.store,
    });
    const { result: response } = await captureConsole(() =>
      failing.postJson('/v1/chat', { message: 'Hola' }),
    );
    await failing.close();
    assert.equal(response.status, 503);
    assert.equal(memory.rows.length, 0);
  });
});

describe('history cursor', () => {
  const cursor = {
    createdAt: '2026-10-01T12:00:00.123456+00:00',
    id: '00000000-0000-4000-8000-00000000000a',
  };

  it('round-trips', () => {
    assert.deepEqual(decodeCursor(encodeCursor(cursor)), cursor);
  });

  const forged = [
    '',
    'abc',
    encodeCursor({ ...cursor, id: 'no-uuid' }),
    encodeCursor({ ...cursor, createdAt: 'ayer' }),
    // Would add a condition to the query filter if it got through.
    encodeCursor({ ...cursor, createdAt: '2026-10-01T12:00:00Z),user_id.neq.x,(a.eq.1' }),
    Buffer.from(`${cursor.createdAt}|${cursor.id}|extra`).toString('base64url'),
  ];
  for (const value of forged) {
    it(`refuses ${JSON.stringify(value.slice(0, 30))}`, () => {
      assert.equal(decodeCursor(value), undefined);
    });
  }
});
