import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { parseEnv } from '../src/config/env.js';
import { CRISIS_CLASSIFIER_PROMPT } from '../src/config/crisis-classifier-prompt.js';
import { createAmbiguousClassifier } from '../src/services/crisis/classifier.js';
import { createCrisisFilter } from '../src/services/crisis/filter.js';
import { LlmError } from '../src/services/llm/index.js';
import { createFakeLlm, failingLlm, startApp } from './helpers.js';

describe('createAmbiguousClassifier', () => {
  it('sends only the classification policy and the current message', async () => {
    const fake = createFakeLlm(() => 'SAFE');
    await createAmbiguousClassifier(fake.llm)('ya no aguanto más');

    assert.deepEqual(fake.requests[0]!.messages, [
      { role: 'system', content: CRISIS_CLASSIFIER_PROMPT },
      { role: 'user', content: 'ya no aguanto más' },
    ]);
    assert.doesNotMatch(CRISIS_CLASSIFIER_PROMPT, /Sos marlix/);
  });

  it('asks for a repeatable answer (temperature 0)', async () => {
    const fake = createFakeLlm(() => 'SAFE');
    await createAmbiguousClassifier(fake.llm)('ya no aguanto más');
    assert.equal(fake.requests[0]!.temperature, 0);
  });

  const answers: [string, boolean][] = [
    ['SAFE', false],
    [' safe. ', false],
    ['RISK', true],
    ['risk', true],
    ['I am not sure', true],
    ['Probably SAFE', true],
  ];

  for (const [answer, isCrisis] of answers) {
    const outcome = isCrisis ? 'a crisis' : 'safe';
    it(`treats the answer ${JSON.stringify(answer)} as ${outcome}`, async () => {
      const classify = createAmbiguousClassifier(createFakeLlm(() => answer).llm);
      assert.equal(await classify('ya no aguanto más'), isCrisis);
    });
  }

  for (const kind of ['timeout', 'rate_limited', 'unavailable'] as const) {
    it(`makes the filter answer with a crisis when the classifier fails (${kind})`, async () => {
      const classifier = createAmbiguousClassifier(failingLlm(new LlmError(kind, kind)));
      const filter = createCrisisFilter(classifier);
      assert.equal((await filter.check('ya no aguanto más')).crisis, true);
    });
  }
});

describe('POST /v1/chat with the second layer', () => {
  async function send(message: string, classifierAnswer: string) {
    const chat = createFakeLlm(() => '¡Qué dicha!');
    const classifier = createFakeLlm(() => classifierAnswer);
    const app = await startApp({ llm: chat.llm, crisisClassifier: classifier.llm });
    try {
      const response = await app.postJson('/v1/chat', { message });
      const body = (await response.json()) as { type: string };
      return {
        type: body.type,
        chatCalls: chat.requests.length,
        classifierCalls: classifier.requests.length,
      };
    } finally {
      await app.close();
    }
  }

  it('lets an ambiguous message through when the classifier says SAFE', async () => {
    assert.deepEqual(await send('ya no aguanto más este tráfico', 'SAFE'), {
      type: 'reply',
      chatCalls: 1,
      classifierCalls: 1,
    });
  });

  it('answers an ambiguous message with a crisis when the classifier says RISK', async () => {
    assert.deepEqual(await send('siento que soy una carga', 'RISK'), {
      type: 'crisis',
      chatCalls: 0,
      classifierCalls: 1,
    });
  });

  it('never sends a clear risk message to the classifier', async () => {
    assert.deepEqual(await send('me quiero morir', 'SAFE'), {
      type: 'crisis',
      chatCalls: 0,
      classifierCalls: 0,
    });
  });

  it('does not run the classifier on normal messages', async () => {
    assert.deepEqual(await send('hoy me fue bien', 'RISK'), {
      type: 'reply',
      chatCalls: 1,
      classifierCalls: 0,
    });
  });
});

describe('classifier configuration', () => {
  it('defaults to a model other than the chat, with a short timeout', () => {
    const env = parseEnv({
      DEV_ACCESS_TOKEN: 'a'.repeat(32),
      GROQ_API_KEY: 'test-key',
      GROQ_MODEL: 'openai/gpt-oss-120b',
      SUPABASE_URL: 'https://abcdefghijklmnop.supabase.co',
      SUPABASE_SECRET_KEY: 'sb_secret_test-key',
    });
    assert.equal(env.CRISIS_CLASSIFIER_MODEL, 'openai/gpt-oss-20b');
    assert.equal(env.CRISIS_CLASSIFIER_TIMEOUT_MS, 5000);
  });
});
