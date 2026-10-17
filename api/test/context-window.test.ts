import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { signSession, startApp, createFakeLlm } from './helpers.js';
import { createMemoryMessageStore } from './memory-message-store.js';

const OTHER_USER = '00000000-0000-4000-8000-00000000000b';

async function chat(app: Awaited<ReturnType<typeof startApp>>, message: string, token?: string) {
  const headers = token ? { authorization: `Bearer ${token}` } : {};
  const response = await app.postJson('/v1/chat', { message }, headers);
  assert.equal(response.status, 200, message);
  return (await response.json()) as any;
}

/** What the model received after the system prompt, as "role: content". */
function seenByModel(request: { messages: readonly { role: string; content: string }[] }) {
  return request.messages.slice(1).map((m) => `${m.role}: ${m.content}`);
}

describe('recent context window', () => {
  it('sends the conversation so far, then the new message', async () => {
    const fake = createFakeLlm((request) => `respuesta ${request.messages.length}`);
    const app = await startApp({ llm: fake.llm });
    try {
      await chat(app, 'Mi perro se llama Coco');
      await chat(app, 'Hoy lo llevé al parque');
      await chat(app, '¿Cómo se llama mi perro?');

      assert.deepEqual(seenByModel(fake.requests[0]!), ['user: Mi perro se llama Coco']);
      assert.deepEqual(seenByModel(fake.requests[2]!), [
        'user: Mi perro se llama Coco',
        'assistant: respuesta 2',
        'user: Hoy lo llevé al parque',
        'assistant: respuesta 4',
        'user: ¿Cómo se llama mi perro?',
      ]);
      assert.equal(fake.requests[2]!.messages[0]!.role, 'system');
    } finally {
      await app.close();
    }
  });

  it('sends only the last messages when the conversation is longer than the window', async () => {
    const fake = createFakeLlm((request) => `r${request.messages.length}`);
    const app = await startApp({ llm: fake.llm, contextMessages: 4 });
    try {
      for (const text of ['uno', 'dos', 'tres', 'cuatro']) await chat(app, text);

      // The window holds 4 messages: the last two turns, then the new message.
      assert.deepEqual(seenByModel(fake.requests[3]!), [
        'user: dos',
        'assistant: r4',
        'user: tres',
        'assistant: r6',
        'user: cuatro',
      ]);
    } finally {
      await app.close();
    }
  });

  it('uses 16 messages by default', async () => {
    const fake = createFakeLlm();
    const app = await startApp({ llm: fake.llm });
    try {
      for (let i = 1; i <= 10; i++) await chat(app, `mensaje ${i}`);

      // 9 earlier turns are 18 messages: the window keeps 16, plus the new one.
      assert.equal(seenByModel(fake.requests[9]!).length, 17);
      assert.equal(seenByModel(fake.requests[9]!)[0], 'user: mensaje 2');
    } finally {
      await app.close();
    }
  });

  it('never sends the messages of a crisis to the model', async () => {
    const fake = createFakeLlm(() => 'Qué bueno escucharte');
    const app = await startApp({ llm: fake.llm });
    try {
      await chat(app, 'Hola');
      const crisis = await chat(app, 'me quiero morir');
      assert.equal(crisis.type, 'crisis');
      await chat(app, '¿Seguís ahí?');

      const sent = seenByModel(fake.requests.at(-1)!);
      assert.deepEqual(sent, [
        'user: Hola',
        'assistant: Qué bueno escucharte',
        'user: ¿Seguís ahí?',
      ]);
      const everything = JSON.stringify(fake.requests);
      assert.ok(!everything.includes('quiero morir'));
      assert.ok(!everything.includes(crisis.reply.content));
    } finally {
      await app.close();
    }
  });

  it("does not mix in another user's messages", async () => {
    const fake = createFakeLlm();
    const app = await startApp({ llm: fake.llm });
    try {
      await chat(app, 'Soy Ana y esto es mío');
      await chat(app, 'Soy Beto', await signSession({ claims: { sub: OTHER_USER } }));

      assert.deepEqual(seenByModel(fake.requests[1]!), ['user: Soy Beto']);
    } finally {
      await app.close();
    }
  });

  it('does not send the new message twice', async () => {
    const fake = createFakeLlm();
    const memory = createMemoryMessageStore();
    const app = await startApp({ llm: fake.llm, messages: memory.store });
    try {
      await chat(app, 'Una sola vez');

      const sent = fake.requests[0]!.messages.filter((m) => m.content === 'Una sola vez');
      assert.equal(sent.length, 1);
    } finally {
      await app.close();
    }
  });
});
