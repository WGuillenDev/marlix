import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { createFakeLlm, signSession, startApp } from './helpers.js';
import { createFakeMemories } from './memory-fakes.js';

const USER = '00000000-0000-4000-8000-00000000000a';
const OTHER_USER = '00000000-0000-4000-8000-00000000000b';
const COCO = '11111111-1111-4111-8111-111111111111';
const CAFE = '22222222-2222-4222-8222-222222222222';
const SECRET = '33333333-3333-4333-8333-333333333333';

interface MemoryBody {
  id: string;
  fact: string;
  category: string | null;
  createdAt: string;
  updatedAt: string;
}

function seed(id: string, userId: string, fact: string, category: string | null, second: number) {
  const at = `2026-10-01T12:00:0${second}.000Z`;
  return { id, userId, fact, category, createdAt: at, updatedAt: at };
}

describe('/v1/memories', () => {
  const fake = createFakeLlm();
  const memories = createFakeMemories();
  let app: Awaited<ReturnType<typeof startApp>>;

  const send = (
    method: string,
    path: string,
    body?: unknown,
    headers: Record<string, string> = app.authHeader,
  ) =>
    app.request(path, {
      method,
      headers: { 'content-type': 'application/json', ...headers },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });

  before(async () => {
    app = await startApp({ llm: fake.llm, memories: memories.store });
  });
  after(() => app.close());

  beforeEach(() => {
    memories.rows.length = 0;
    memories.rows.push(
      seed(COCO, USER, 'Tiene un perro llamado Coco', 'pets', 1),
      seed(CAFE, USER, 'Le gusta el café', null, 2),
      seed(SECRET, OTHER_USER, 'Dato de otra persona', 'other', 3),
    );
  });

  it('lists the memories of the person, newest first, and none of anybody else', async () => {
    const response = await send('GET', '/v1/memories');
    const body = (await response.json()) as { memories: MemoryBody[] };

    assert.equal(response.status, 200);
    assert.deepEqual(body.memories.map((m) => m.id), [CAFE, COCO]);
    assert.deepEqual(Object.keys(body.memories[0]!).sort(), [
      'category',
      'createdAt',
      'fact',
      'id',
      'updatedAt',
    ]);
    assert.equal(body.memories[0]!.category, null);
  });

  it('lists an empty array when there is nothing remembered', async () => {
    memories.rows.length = 0;
    const response = await send('GET', '/v1/memories');
    assert.deepEqual(await response.json(), { memories: [] });
  });

  it('edits the text of a memory and keeps the rest', async () => {
    const response = await send('PATCH', `/v1/memories/${COCO}`, {
      fact: '  Tiene una perrita llamada Coco ',
    });
    const body = (await response.json()) as MemoryBody;

    assert.equal(response.status, 200);
    assert.equal(body.id, COCO);
    assert.equal(body.fact, 'Tiene una perrita llamada Coco');
    assert.equal(body.category, 'pets');
    assert.equal(memories.rows.find((r) => r.id === COCO)!.fact, 'Tiene una perrita llamada Coco');
  });

  it('rejects an empty, blank, too long or unexpected edit', async () => {
    const invalid = [
      {},
      { fact: '' },
      { fact: '   ' },
      { fact: 'a'.repeat(501) },
      { fact: 3 },
      { fact: 'ok', category: 'pets' },
    ];
    for (const body of invalid) {
      const response = await send('PATCH', `/v1/memories/${COCO}`, body);
      assert.equal(response.status, 400, JSON.stringify(body));
      assert.equal(((await response.json()) as any).error.code, 'VALIDATION_ERROR');
    }
    assert.equal(memories.rows.find((r) => r.id === COCO)!.fact, 'Tiene un perro llamado Coco');
  });

  it('accepts a memory of exactly 500 characters', async () => {
    const response = await send('PATCH', `/v1/memories/${COCO}`, { fact: 'a'.repeat(500) });
    assert.equal(response.status, 200);
  });

  it('answers 404 for a memory that does not exist, is not an id or belongs to someone else', async () => {
    for (const id of ['99999999-9999-4999-8999-999999999999', 'no-es-un-id', SECRET]) {
      for (const [method, body] of [
        ['PATCH', { fact: 'Cambio' }],
        ['DELETE', undefined],
      ] as const) {
        const response = await send(method, `/v1/memories/${id}`, body);
        assert.equal(response.status, 404, `${method} ${id}`);
        assert.equal(((await response.json()) as any).error.code, 'NOT_FOUND');
      }
    }
    assert.equal(memories.rows.find((r) => r.id === SECRET)!.fact, 'Dato de otra persona');
  });

  it('deletes one memory', async () => {
    const response = await send('DELETE', `/v1/memories/${COCO}`);

    assert.equal(response.status, 204);
    assert.deepEqual(memories.rows.map((r) => r.id), [CAFE, SECRET]);
    assert.equal((await send('DELETE', `/v1/memories/${COCO}`)).status, 404);
  });

  it('deletes all the memories of the person and keeps those of others', async () => {
    const response = await send('DELETE', '/v1/memories');

    assert.equal(response.status, 204);
    assert.deepEqual(memories.rows.map((r) => r.id), [SECRET]);
    assert.equal((await send('DELETE', '/v1/memories')).status, 204);
  });

  it('stops sending a deleted or edited memory to the model from the very next message', async () => {
    const lastPrompt = () => JSON.stringify(fake.requests.at(-1));

    await app.postJson('/v1/chat', { message: 'Hola' });
    assert.match(lastPrompt(), /Coco/);

    await send('DELETE', `/v1/memories/${COCO}`);
    await app.postJson('/v1/chat', { message: 'Hola otra vez' });
    assert.doesNotMatch(lastPrompt(), /Coco/);
    assert.match(lastPrompt(), /café/);

    await send('PATCH', `/v1/memories/${CAFE}`, { fact: 'Le gusta el té' });
    await app.postJson('/v1/chat', { message: 'Hola de nuevo' });
    assert.match(lastPrompt(), /té/);
    assert.doesNotMatch(lastPrompt(), /café/);

    await send('DELETE', '/v1/memories');
    await app.postJson('/v1/chat', { message: 'Hola por última vez' });
    assert.doesNotMatch(lastPrompt(), /Le gusta el té|Coco|otra persona/);
  });

  it('requires a session on every route', async () => {
    const calls = [
      ['GET', '/v1/memories'],
      ['PATCH', `/v1/memories/${COCO}`],
      ['DELETE', `/v1/memories/${COCO}`],
      ['DELETE', '/v1/memories'],
    ] as const;
    for (const [method, path] of calls) {
      const response = await send(method, path, method === 'PATCH' ? { fact: 'x' } : undefined, {});
      assert.equal(response.status, 401, `${method} ${path}`);
    }
    assert.equal(memories.rows.length, 3);
  });

  it('serves each person their own memories', async () => {
    const token = await signSession({ claims: { sub: OTHER_USER } });
    const response = await send('GET', '/v1/memories', undefined, {
      authorization: `Bearer ${token}`,
    });
    const body = (await response.json()) as { memories: MemoryBody[] };
    assert.deepEqual(body.memories.map((m) => m.id), [SECRET]);
  });
});
