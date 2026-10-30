import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { LlmError } from '../src/services/llm/errors.js';
import { GroqTranscriber, TRANSCRIPTION_PROMPT } from '../src/services/llm/index.js';
import { cleanTranscript, type Transcriber } from '../src/services/transcription/transcriber.js';
import { TRANSCRIBE_RATE_LIMIT, wavSeconds } from '../src/routes/transcribe.js';
import { captureConsole, createFakeLlm, startApp } from './helpers.js';
import { createMemoryUsageStore } from './memory-usage-store.js';

/** A WAV like the app's: 16 kHz, mono, 16-bit PCM, `seconds` of silence. */
function wav(seconds: number, overrides: { rate?: number; channels?: number } = {}): Buffer {
  const rate = overrides.rate ?? 16_000;
  const channels = overrides.channels ?? 1;
  const data = Math.round(seconds * 16_000) * 2;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * channels * 2, 28);
  header.writeUInt16LE(channels * 2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(data, 40);
  return Buffer.concat([header, Buffer.alloc(data)]);
}

describe('wavSeconds', () => {
  it('reads the length of the app audio', () => {
    assert.equal(wavSeconds(wav(2)), 2);
  });

  it('refuses anything that is not the app format', () => {
    assert.equal(wavSeconds(wav(1, { rate: 44_100 })), undefined);
    assert.equal(wavSeconds(wav(1, { channels: 2 })), undefined);
    assert.equal(wavSeconds(Buffer.from('not audio at all, just text that is long enough....')), undefined);
    assert.equal(wavSeconds(Buffer.alloc(10)), undefined);
  });
});

describe('cleanTranscript', () => {
  it('keeps what the person said', () => {
    assert.equal(cleanTranscript('  Mae, qué tuanis  '), 'Mae, qué tuanis');
  });

  it('drops the phrases Whisper invents on silence', () => {
    assert.equal(cleanTranscript('¡Gracias por ver el video!'), '');
    assert.equal(cleanTranscript('Suscríbete'), '');
  });

  it('keeps a real thanks inside a sentence', () => {
    assert.equal(cleanTranscript('Gracias por escucharme'), 'Gracias por escucharme');
  });
});

describe('POST /v1/transcribe (S6-9)', () => {
  const heard: Uint8Array[] = [];
  let answer = 'hola, qué tal';
  let failure: LlmError | undefined;
  const transcriber: Transcriber = {
    async transcribe(audio) {
      heard.push(audio);
      if (failure) throw failure;
      return answer;
    },
  };
  const usage = createMemoryUsageStore({ personal: 2 });
  let app: Awaited<ReturnType<typeof startApp>>;

  const send = (body: Buffer, headers: Record<string, string> = {}) =>
    app.request('/v1/transcribe', {
      method: 'POST',
      headers: { 'content-type': 'audio/wav', ...app.authHeader, ...headers },
      body: new Uint8Array(body),
    });

  before(async () => {
    app = await startApp({ llm: createFakeLlm().llm, transcriber, usage: usage.store });
  });
  after(() => app.close());

  it('needs a session', async () => {
    const response = await app.request('/v1/transcribe', {
      method: 'POST',
      headers: { 'content-type': 'audio/wav' },
      body: new Uint8Array(wav(1)),
    });
    assert.equal(response.status, 401);
    assert.equal(heard.length, 0);
  });

  it('returns the text of the audio', async () => {
    const response = await send(wav(1.5));

    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { text: 'hola, qué tal' });
    assert.equal(heard.length, 1);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });

  it('returns an empty text when nothing was said', async () => {
    answer = '';
    const response = await send(wav(1));
    assert.deepEqual(await response.json(), { text: '' });
    answer = 'hola, qué tal';
  });

  it('refuses a body that is not WAV audio', async () => {
    const wrongType = await send(wav(1), { 'content-type': 'application/json' });
    assert.equal(wrongType.status, 400);

    const notWav = await send(Buffer.alloc(5000, 1));
    assert.equal(notWav.status, 400);

    const otherFormat = await send(wav(1, { rate: 44_100 }));
    assert.equal(otherFormat.status, 400);

    const empty = await send(Buffer.alloc(0));
    assert.equal(empty.status, 400);
  });

  it('refuses audio that is too short or too long', async () => {
    assert.equal((await send(wav(0.1))).status, 400);
    assert.equal((await send(wav(40))).status, 400);
  });

  it('does not reach the provider when the audio is refused', async () => {
    const before = heard.length;
    await send(Buffer.alloc(5000, 1));
    assert.equal(heard.length, before);
  });

  it('answers 503 when the provider fails, and keeps the audio out of the logs', async () => {
    failure = new LlmError('unavailable', 'Could not reach Groq');
    const { result: response, output } = await captureConsole(() => send(wav(1)));
    failure = undefined;

    assert.equal(response.status, 503);
    assert.equal(((await response.json()) as any).error.code, 'LLM_UNAVAILABLE');
    assert.ok(!output.includes('RIFF'));
  });

  it('passes the wait of Groq on a rate limit', async () => {
    failure = new LlmError('rate_limited', 'Groq responded 429', { retryAfterSeconds: 12 });
    const response = await send(wav(1));
    failure = undefined;

    assert.equal(response.status, 503);
    assert.equal(response.headers.get('retry-after'), '12');
  });

  it('stops when the day ran out', async () => {
    const limited = await startApp({
      llm: createFakeLlm().llm,
      transcriber,
      usage: (() => {
        const store = createMemoryUsageStore({ personal: 1 });
        return store.store;
      })(),
    });
    const user = await limited.postJson('/v1/chat', { message: 'Hola' });
    assert.equal(user.status, 200);

    const response = await limited.request('/v1/transcribe', {
      method: 'POST',
      headers: { 'content-type': 'audio/wav', ...limited.authHeader },
      body: new Uint8Array(wav(1)),
    });
    await limited.close();

    assert.equal(response.status, 429);
    assert.equal(((await response.json()) as any).error.code, 'DAILY_LIMIT_REACHED');
  });

  it('limits how often a person can send audio', async () => {
    const statuses: number[] = [];
    for (let i = 0; i < TRANSCRIBE_RATE_LIMIT.requests + 2; i++) {
      statuses.push((await send(wav(0.5))).status);
    }
    assert.ok(statuses.includes(429));
    const last = await send(wav(0.5));
    assert.equal(last.status, 429);
    assert.equal(((await last.json()) as any).error.code, 'RATE_LIMITED');
    assert.ok(Number(last.headers.get('retry-after')) > 0);
  });
});

describe('GroqTranscriber', () => {
  function create(respond: (request: Request) => Response) {
    const requests: Request[] = [];
    const transcriber = new GroqTranscriber({
      apiKey: 'gsk_test_secret_key',
      model: 'whisper-test',
      baseUrl: 'https://groq.test/openai/v1',
      fetch: async (input, init) => {
        const request = new Request(input as string | URL | Request, init);
        requests.push(request.clone());
        return respond(request);
      },
    });
    return { transcriber, requests };
  }

  it('sends the audio in Spanish with the Costa Rican prompt and reads the text', async () => {
    const { transcriber, requests } = create(
      () => new Response(JSON.stringify({ text: ' Mae, qué tuanis ' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );

    assert.equal(await transcriber.transcribe(wav(1)), 'Mae, qué tuanis');

    // The SDK first probes fetch with a data: URL; the transcription is the next call.
    const request = requests.find((sent) => sent.url.includes('/audio/transcriptions'))!;
    assert.equal(new URL(request.url).pathname, '/openai/v1/audio/transcriptions');
    const form = await request.formData();
    assert.equal(form.get('model'), 'whisper-test');
    assert.equal(form.get('language'), 'es');
    assert.equal(form.get('response_format'), 'verbose_json');
    assert.equal(form.get('prompt'), TRANSCRIPTION_PROMPT);
    assert.ok(form.get('file') instanceof File);
  });

  it('drops the stretches that Whisper doubts are speech', async () => {
    const segment = (text: string, extra: object) => ({
      text,
      no_speech_prob: 0.01,
      avg_logprob: -0.2,
      compression_ratio: 1.2,
      ...extra,
    });
    const { transcriber } = create(
      () => new Response(JSON.stringify({
        text: 'Hola mae Gracias por tanto Mae tuanis',
        segments: [
          segment(' Hola mae', {}),
          segment(' Gracias por tanto', { no_speech_prob: 0.7, avg_logprob: -1.4 }),
          segment(' Mae tuanis', { compression_ratio: 3 }),
          segment(' qué chiva', {}),
        ],
      }), { status: 200, headers: { 'content-type': 'application/json' } }),
    );

    assert.equal(await transcriber.transcribe(wav(1)), 'Hola mae qué chiva');
  });

  it('gives nothing when every stretch is noise', async () => {
    const { transcriber } = create(
      () => new Response(JSON.stringify({
        text: 'Me encantaría escuchar',
        segments: [
          { text: ' Me encantaría escuchar', no_speech_prob: 0.9, avg_logprob: -0.5, compression_ratio: 1 },
        ],
      }), { status: 200, headers: { 'content-type': 'application/json' } }),
    );

    assert.equal(await transcriber.transcribe(wav(1)), '');
  });

  it('turns Groq failures into LlmError without the provider text', async () => {
    const { transcriber } = create(
      () => new Response(JSON.stringify({ error: { message: 'secret detail' } }), {
        status: 429,
        headers: { 'content-type': 'application/json', 'retry-after': '7' },
      }),
    );

    await assert.rejects(
      () => transcriber.transcribe(wav(1)),
      (error: unknown) =>
        error instanceof LlmError &&
        error.kind === 'rate_limited' &&
        error.retryAfterSeconds === 7 &&
        !error.message.includes('secret detail'),
    );
  });
});
