import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { SAFE_REPLY } from '../src/services/review/reply-review.js';
import { captureConsole, createFakeLlm, startApp } from './helpers.js';
import { createMemoryMessageStore } from './memory-message-store.js';

const MESSY = '## Un respiro 😊\n- **Soltá** el aire\n- Mirá [esta guía](https://example.com)\nListo & 50%';
const SPOKEN = 'Un respiro. Soltá el aire. Mirá esta guía. Listo y 50 por ciento';

describe('voice replies (S6-3)', () => {
  const memory = createMemoryMessageStore();
  let answer = MESSY;
  const fake = createFakeLlm(() => answer);
  let app: Awaited<ReturnType<typeof startApp>>;

  const chat = async (body: object) => {
    const response = await app.postJson('/v1/chat', body);
    return { response, body: (await response.json()) as any };
  };
  const saved = async () => {
    const response = await app.request('/v1/history', { headers: app.authHeader });
    return ((await response.json()) as any).messages.map((m: any) => m.content) as string[];
  };

  before(async () => {
    app = await startApp({ llm: fake.llm, messages: memory.store });
  });
  after(() => app.close());

  it('cleans the reply in voice mode', async () => {
    const { response, body } = await chat({ message: 'Estoy ansiosa', mode: 'voice' });

    assert.equal(response.status, 200);
    assert.equal(body.type, 'reply');
    assert.equal(body.reply.content, SPOKEN);
  });

  it('saves the cleaned text, the same one that is said and shown', async () => {
    const messages = await saved();

    assert.equal(messages.at(-1), SPOKEN);
    assert.ok(!messages.at(-1)!.includes('😊'));
  });

  it('does not change a thing in text mode', async () => {
    const { body } = await chat({ message: 'Estoy ansiosa', mode: 'text' });
    assert.equal(body.reply.content, MESSY);

    const { body: byDefault } = await chat({ message: 'Estoy ansiosa' });
    assert.equal(byDefault.reply.content, MESSY, 'text is the default mode');
    assert.equal((await saved()).at(-1), MESSY);
  });

  it('answers with the safe reply, never an empty one, when nothing is left to say', async () => {
    answer = '😊😊';
    const { result, output } = await captureConsole(() => chat({ message: 'Hola', mode: 'voice' }));

    assert.equal(result.body.reply.content, SAFE_REPLY);
    assert.match(output, /nothing to say/);
    assert.ok(!output.includes('😊'), 'the reply itself is never logged');
    answer = MESSY;
  });

  it('keeps a plain reply exactly as the model wrote it', async () => {
    answer = '¡Qué dicha! Contame, ¿qué fue lo que salió mejor?';
    const { body } = await chat({ message: 'Hoy me fue bien', mode: 'voice' });

    assert.equal(body.reply.content, answer);
    answer = MESSY;
  });

  it('does not clean a crisis reply: it is fixed text and never goes through the model', async () => {
    const before = fake.requests.length;
    const { body } = await chat({ message: 'Me quiero morir', mode: 'voice' });

    assert.equal(body.type, 'crisis');
    assert.equal(fake.requests.length, before);
  });

  describe('the prompt', () => {
    const system = async (mode: 'text' | 'voice') => {
      await chat({ message: 'Hola', mode });
      return fake.requests.at(-1)!.messages[0]!.content;
    };

    it('asks for one to three short sentences, as people talk, in voice mode', async () => {
      const prompt = await system('voice');

      assert.match(prompt, /una a tres oraciones cortas/);
      assert.match(prompt, /como se habla y no como se escribe/);
      assert.match(prompt, /sin listas, títulos ni negritas/);
      assert.match(prompt, /sin emojis, símbolos/);
    });

    it('says nothing about voice in text mode', async () => {
      const prompt = await system('text');

      assert.match(prompt, /te está escribiendo por chat/);
      assert.doesNotMatch(prompt, /una a tres oraciones cortas/);
    });

    it('limits a voice reply to fewer tokens than a text one, which also spares the quota', async () => {
      await chat({ message: 'Hola', mode: 'voice' });
      const voice = fake.requests.at(-1)!.maxOutputTokens;
      await chat({ message: 'Hola', mode: 'text' });
      const text = fake.requests.at(-1)!.maxOutputTokens;

      assert.ok(voice! < text!);
    });
  });
});
