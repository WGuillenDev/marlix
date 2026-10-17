import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { LlmError } from '../src/services/llm/index.js';
import { captureConsole, createFakeLlm, failingLlm, startApp } from './helpers.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

describe('POST /v1/chat', () => {
  const fake = createFakeLlm(() => '¡Qué dicha! Contame más.');
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: fake.llm });
  });
  after(() => app.close());

  it('returns the reply in the contract shape', async () => {
    const response = await app.postJson('/v1/chat', { message: '  Hoy me fue mejor  ' });
    assert.equal(response.status, 200);

    const body = (await response.json()) as Record<string, any>;
    assert.equal(body.type, 'reply');
    assert.match(body.userMessage.id, UUID);
    assert.equal(body.userMessage.role, 'user');
    assert.equal(body.userMessage.content, 'Hoy me fue mejor');
    assert.ok(!Number.isNaN(Date.parse(body.userMessage.createdAt)));
    assert.match(body.reply.id, UUID);
    assert.equal(body.reply.role, 'assistant');
    assert.equal(body.reply.content, '¡Qué dicha! Contame más.');
    assert.equal(body.reply.interrupted, false);
    assert.ok(!Number.isNaN(Date.parse(body.reply.createdAt)));
  });

  it('sends the personality system prompt first on every call', async () => {
    await app.postJson('/v1/chat', { message: 'Hola', mode: 'voice' });
    const { messages } = fake.requests.at(-1)!;

    // The conversation so far (S4-5) goes between the prompt and the new message.
    assert.equal(messages[0]!.role, 'system');
    assert.match(messages[0]!.content, /Sos marlix/);
    assert.match(messages[0]!.content, /por voz/);
    assert.deepEqual(messages.at(-1), { role: 'user', content: 'Hola' });
    assert.equal(messages.filter((m) => m.role === 'system').length, 1);
  });

  it('accepts a 2,000-character message, counting emoji as one character', async () => {
    const response = await app.postJson('/v1/chat', { message: '🐶'.repeat(2000) });
    assert.equal(response.status, 200);
  });

  const invalidBodies: [string, unknown, string][] = [
    ['a missing message', {}, 'message'],
    ['an empty message', { message: '   ' }, 'message'],
    ['a message over 2,000 characters', { message: 'a'.repeat(2001) }, 'message'],
    ['a message that is not a string', { message: 42 }, 'message'],
    ['an unknown mode', { message: 'Hola', mode: 'video' }, 'mode'],
    [
      'an invalid interruptedMessageId',
      { message: 'Hola', interruptedMessageId: 'abc' },
      'interruptedMessageId',
    ],
    ['an unknown field', { message: 'Hola', extra: true }, 'body'],
    ['a body that is not an object', [1, 2], 'body'],
  ];

  for (const [name, body, field] of invalidBodies) {
    it(`rejects ${name} with 400 VALIDATION_ERROR`, async () => {
      const response = await app.postJson('/v1/chat', body);
      assert.equal(response.status, 400);

      const { error } = (await response.json()) as { error: Record<string, any> };
      assert.equal(error.code, 'VALIDATION_ERROR');
      assert.ok(error.details.fields.some((entry: { field: string }) => entry.field === field));
    });
  }

  it('rejects malformed JSON without logging the body', async () => {
    const { result: response, output } = await captureConsole(() =>
      app.postJson('/v1/chat', '{"message": "me siento muy solo'),
    );

    assert.equal(response.status, 400);
    assert.equal(((await response.json()) as any).error.code, 'VALIDATION_ERROR');
    assert.ok(!output.includes('me siento muy solo'));
  });

  it('never logs the message or the reply', async () => {
    const { output } = await captureConsole(() =>
      app.postJson('/v1/chat', { message: 'un secreto personal' }),
    );
    assert.ok(!output.includes('un secreto personal'));
    assert.ok(!output.includes('Contame más'));
  });
});

describe('central error handling', () => {
  it('answers unknown routes with 404 NOT_FOUND', async () => {
    const app = await startApp({ llm: createFakeLlm().llm });
    try {
      for (const response of [
        await app.request('/nothing-here'),
        await app.request('/v1/nothing-here', {
          headers: app.authHeader,
        }),
      ]) {
        assert.equal(response.status, 404);
        assert.deepEqual(await response.json(), {
          error: { code: 'NOT_FOUND', message: 'Route not found.' },
        });
      }
    } finally {
      await app.close();
    }
  });

  it('rejects a body that is too large with 400 VALIDATION_ERROR', async () => {
    const app = await startApp({ llm: createFakeLlm().llm });
    try {
      const response = await app.postJson('/v1/chat', { message: 'a'.repeat(20_000) });
      assert.equal(response.status, 400);
      assert.equal(((await response.json()) as any).error.code, 'VALIDATION_ERROR');
    } finally {
      await app.close();
    }
  });

  it('turns an unexpected error into 500 INTERNAL_ERROR without internal details', async () => {
    const app = await startApp({
      llm: createFakeLlm(() => {
        throw new TypeError('cannot read "mi diario personal"');
      }).llm,
    });
    try {
      const { result: response, output } = await captureConsole(() =>
        app.postJson('/v1/chat', { message: 'Hola' }),
      );
      const text = await response.text();

      assert.equal(response.status, 500);
      assert.deepEqual(JSON.parse(text), {
        error: { code: 'INTERNAL_ERROR', message: 'Unexpected error.' },
      });
      assert.ok(!output.includes('mi diario personal'), 'the error message is not logged');
      assert.match(output, /TypeError/);
    } finally {
      await app.close();
    }
  });
});

describe('POST /v1/chat when the LLM fails', () => {
  it('answers 503 LLM_UNAVAILABLE with a fixed message for any provider failure', async () => {
    const app = await startApp({
      llm: failingLlm(new LlmError('authentication', 'Groq responded 401 (invalid_api_key)')),
    });
    try {
      const { result: response } = await captureConsole(() =>
        app.postJson('/v1/chat', { message: 'Hola' }),
      );

      assert.equal(response.status, 503);
      assert.equal(response.headers.get('retry-after'), null);
      assert.deepEqual(await response.json(), {
        error: { code: 'LLM_UNAVAILABLE', message: 'The model is not available right now.' },
      });
    } finally {
      await app.close();
    }
  });

  it('answers 503 LLM_UNAVAILABLE with Retry-After on a quota error', async () => {
    const app = await startApp({
      llm: failingLlm(new LlmError('rate_limited', 'quota', { retryAfterSeconds: 7 })),
    });
    try {
      const { result: response, output } = await captureConsole(() =>
        app.postJson('/v1/chat', { message: 'algo privado' }),
      );

      assert.equal(response.status, 503);
      assert.equal(response.headers.get('retry-after'), '7');
      assert.equal(((await response.json()) as any).error.code, 'LLM_UNAVAILABLE');
      assert.ok(!output.includes('algo privado'));
    } finally {
      await app.close();
    }
  });
});
