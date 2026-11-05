// Reply by sentences in voice mode (S6-10): POST /v1/chat with
// Accept: text/event-stream.
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { LlmError } from '../src/services/llm/index.js';
import type { LlmProvider } from '../src/services/llm/index.js';
import { SentenceStream } from '../src/services/speech/sentence-stream.js';
import { SAFE_REPLY } from '../src/services/review/reply-review.js';
import { captureConsole, createFakeLlm, failingLlm, startApp } from './helpers.js';
import { createMemoryMessageStore } from './memory-message-store.js';
import { createMemoryUsageStore } from './memory-usage-store.js';

interface SseEvent {
  event: string;
  data: any;
}

function parseEvents(text: string): SseEvent[] {
  return text
    .split('\n\n')
    .filter((block) => block.trim() !== '')
    .map((block) => {
      const event = /^event: (.+)$/m.exec(block)?.[1] ?? '';
      const data = JSON.parse(/^data: (.+)$/m.exec(block)?.[1] ?? 'null');
      return { event, data };
    });
}

describe('SentenceStream', () => {
  const feed = (...pieces: string[]) => {
    const stream = new SentenceStream();
    return [...pieces.flatMap((piece) => stream.push(piece)), ...stream.flush()];
  };

  it('completes a sentence only once the space after it has arrived', () => {
    const stream = new SentenceStream();
    assert.deepEqual(stream.push('¡Qué dicha!'), []);
    assert.deepEqual(stream.push(' Cont'), ['¡Qué dicha!']);
    assert.deepEqual(stream.push('ame más.'), []);
    assert.deepEqual(stream.flush(), ['Contame más.']);
  });

  it('gives the same sentences however the reply is cut into pieces', () => {
    const reply = '¡Qué dicha! ¿Cómo te fue?\nContame más… Aquí estoy.';
    const whole = feed(reply);
    assert.deepEqual(whole, ['¡Qué dicha!', '¿Cómo te fue?', 'Contame más…', 'Aquí estoy.']);
    assert.deepEqual(feed(...reply.split('')), whole);
  });

  it('does not cut a decimal number or an address', () => {
    assert.deepEqual(feed('Son 3.5 horas, en marlix.app sí.'), ['Son 3.5 horas, en marlix.app sí.']);
  });

  it('keeps a list marker with its item', () => {
    assert.deepEqual(feed('1. Respirá hondo.\n2. Soltá el aire.'), [
      '1. Respirá hondo.',
      '2. Soltá el aire.',
    ]);
  });

  it('returns nothing for an empty reply', () => {
    assert.deepEqual(feed('', '  \n '), []);
  });
});

describe('streamed reply (S6-10)', () => {
  const memory = createMemoryMessageStore();
  let answer = '¡Qué dicha! 😊 Contame, ¿qué fue lo que salió mejor?';
  const fake = createFakeLlm(() => answer);
  let app: Awaited<ReturnType<typeof startApp>>;

  const stream = async (body: object, headers: Record<string, string> = {}) => {
    const response = await app.postJson('/v1/chat', body, {
      accept: 'text/event-stream',
      ...headers,
    });
    return { response, events: parseEvents(await response.text()) };
  };
  const saved = async () => {
    const response = await app.request('/v1/history', { headers: app.authHeader });
    return ((await response.json()) as any).messages.map((m: any) => m.content) as string[];
  };

  before(async () => {
    app = await startApp({ llm: fake.llm, messages: memory.store });
  });
  after(() => app.close());

  it('sends each cleaned sentence and then the full saved reply', async () => {
    const { response, events } = await stream({ message: 'Hoy me fue bien', mode: 'voice' });

    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type') ?? '', /^text\/event-stream/);
    assert.deepEqual(
      events.map((event) => event.event),
      ['sentence', 'sentence', 'done'],
    );
    assert.deepEqual(events[0]?.data, { index: 0, text: '¡Qué dicha!' });
    assert.deepEqual(events[1]?.data, {
      index: 1,
      text: 'Contame, ¿qué fue lo que salió mejor?',
    });

    const done = events[2]!.data;
    assert.equal(done.type, 'reply');
    assert.equal(done.reply.content, '¡Qué dicha! Contame, ¿qué fue lo que salió mejor?');
    assert.equal(done.userMessage.content, 'Hoy me fue bien');
    assert.equal(done.usage.used, 1);
  });

  it('saves the full reply in the history, the same one that was said', async () => {
    assert.equal(
      (await saved()).at(-1),
      '¡Qué dicha! Contame, ¿qué fue lo que salió mejor?',
    );
  });

  it('answers with JSON when the app does not ask for a stream', async () => {
    const response = await app.postJson('/v1/chat', { message: 'Hola', mode: 'voice' });

    assert.match(response.headers.get('content-type') ?? '', /^application\/json/);
    assert.equal(((await response.json()) as any).type, 'reply');
  });

  it('keeps the text mode as JSON even if a stream is asked for', async () => {
    const response = await app.postJson(
      '/v1/chat',
      { message: 'Hola', mode: 'text' },
      { accept: 'text/event-stream' },
    );

    assert.match(response.headers.get('content-type') ?? '', /^application\/json/);
  });

  it('never speaks a sentence that fails the review, and says the safe reply instead', async () => {
    answer = 'Te entiendo. Por lo que contás, tenés depresión. Seguí así.';
    const { result, output } = await captureConsole(() =>
      stream({ message: 'Estoy mal del ánimo', mode: 'voice' }),
    );
    answer = '¡Qué dicha!';

    const spoken = result.events.filter((event) => event.event === 'sentence');
    assert.deepEqual(
      spoken.map((event) => event.data.text),
      ['Te entiendo.', SAFE_REPLY],
    );
    assert.ok(!JSON.stringify(result.events).includes('depresión'));
    assert.ok(!JSON.stringify(result.events).includes('Seguí así'));
    assert.equal(result.events.at(-1)?.event, 'done');
    assert.equal(result.events.at(-1)?.data.reply.content, `Te entiendo. ${SAFE_REPLY}`);
    assert.match(output, /diagnosis/);
    assert.ok(!output.includes('depresión'), 'the reply itself is never logged');
  });

  it('says the safe reply when nothing is left to say', async () => {
    answer = '😊😊';
    const { result } = await captureConsole(() => stream({ message: 'Hola', mode: 'voice' }));
    answer = '¡Qué dicha!';

    assert.deepEqual(
      result.events.map((event) => event.event),
      ['sentence', 'done'],
    );
    assert.equal(result.events[0]?.data.text, SAFE_REPLY);
  });

  it('answers a crisis with the fixed reply, with no sentences and without the model', async () => {
    const calls = fake.requests.length;
    const { events } = await stream({ message: 'Me quiero morir', mode: 'voice' });

    assert.deepEqual(
      events.map((event) => event.event),
      ['crisis'],
    );
    assert.equal(events[0]?.data.type, 'crisis');
    assert.ok(Array.isArray(events[0]?.data.resources));
    assert.equal(fake.requests.length, calls);
  });

  it('sends the checks that come before the model as a normal JSON error', async () => {
    const { response } = await stream({ message: '', mode: 'voice' });

    assert.equal(response.status, 400);
    assert.match(response.headers.get('content-type') ?? '', /^application\/json/);
  });
});

describe('streamed reply, limits and failures (S6-10)', () => {
  it('answers 429 DAILY_LIMIT_REACHED as JSON at the cap, without opening a stream', async () => {
    const app = await startApp({
      llm: createFakeLlm().llm,
      usage: createMemoryUsageStore({ personal: 1 }).store,
    });
    try {
      const ask = () =>
        app.postJson('/v1/chat', { message: 'hola', mode: 'voice' }, { accept: 'text/event-stream' });
      assert.equal((await ask()).status, 200);
      const response = await ask();

      assert.equal(response.status, 429);
      assert.equal(((await response.json()) as any).error.code, 'DAILY_LIMIT_REACHED');
    } finally {
      await app.close();
    }
  });

  it('shares the daily cap with the text mode', async () => {
    const app = await startApp({
      llm: createFakeLlm().llm,
      usage: createMemoryUsageStore({ personal: 1 }).store,
    });
    try {
      assert.equal((await app.postJson('/v1/chat', { message: 'hola' })).status, 200);
      const response = await app.postJson(
        '/v1/chat',
        { message: 'hola', mode: 'voice' },
        { accept: 'text/event-stream' },
      );

      assert.equal(response.status, 429);
      assert.equal(((await response.json()) as any).error.code, 'DAILY_LIMIT_REACHED');
    } finally {
      await app.close();
    }
  });

  it('answers 503 as JSON when the model fails before the first sentence', async () => {
    const app = await startApp({ llm: failingLlm(new LlmError('unavailable', 'down')) });
    try {
      const { result } = await captureConsole(() =>
        app.postJson('/v1/chat', { message: 'hola', mode: 'voice' }, { accept: 'text/event-stream' }),
      );

      assert.equal(result.status, 503);
      assert.equal(((await result.json()) as any).error.code, 'LLM_UNAVAILABLE');
    } finally {
      await app.close();
    }
  });

  it('closes with an error event, and saves and counts nothing, if the model fails midway', async () => {
    const memory = createMemoryMessageStore();
    const usage = createMemoryUsageStore();
    const broken: LlmProvider = {
      ...createFakeLlm().llm,
      async *stream() {
        yield '¡Qué dicha! Con';
        throw new LlmError('timeout', 'cut');
      },
    };
    const app = await startApp({ llm: broken, messages: memory.store, usage: usage.store });
    try {
      const { result } = await captureConsole(async () => {
        const response = await app.postJson(
          '/v1/chat',
          { message: 'hola', mode: 'voice' },
          { accept: 'text/event-stream' },
        );
        return parseEvents(await response.text());
      });

      assert.deepEqual(
        result.map((event) => event.event),
        ['sentence', 'error'],
      );
      assert.equal(result[1]?.data.error.code, 'LLM_UNAVAILABLE');

      const history = (await (await app.request('/v1/history', { headers: app.authHeader })).json()) as any;
      assert.deepEqual(history.messages, []);
      const usageResponse = (await (await app.request('/v1/usage', { headers: app.authHeader })).json()) as any;
      assert.equal(usageResponse.used, 0);
    } finally {
      await app.close();
    }
  });

  it('delivers the first sentence while the model is still generating', async () => {
    let release!: () => void;
    const gate = new Promise<void>((resolve) => (release = resolve));
    const slow: LlmProvider = {
      ...createFakeLlm().llm,
      async *stream() {
        yield '¡Qué dicha! ';
        await gate;
        yield 'Contame más.';
      },
    };
    const app = await startApp({ llm: slow });
    try {
      const response = await app.postJson(
        '/v1/chat',
        { message: 'hola', mode: 'voice' },
        { accept: 'text/event-stream' },
      );
      const reader = response.body!.getReader();
      const first = await reader.read();

      assert.match(new TextDecoder().decode(first.value), /¡Qué dicha!/);

      release();
      let rest = '';
      for (let chunk = await reader.read(); !chunk.done; chunk = await reader.read()) {
        rest += new TextDecoder().decode(chunk.value);
      }
      assert.deepEqual(
        parseEvents(rest).map((event) => event.event),
        ['sentence', 'done'],
      );
    } finally {
      await app.close();
    }
  });
});
