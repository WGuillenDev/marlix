// The crisis test suite (S2-7): every invented case in fixtures/crisis-cases.ts
// through the keyword layer and through POST /v1/chat, with a report of false
// positives and false negatives. The real second layer is measured by
// `npm run crisis:eval`, which spends quota.
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createCrisisFilter, detectCrisisSignal } from '../src/services/crisis/filter.js';
import {
  ALL_CASES,
  AMBIGUOUS_RISK_CASES,
  AMBIGUOUS_SAFE_CASES,
  NORMAL_CASES,
  RISK_CASES,
} from './fixtures/crisis-cases.js';
import { createFakeLlm, startApp } from './helpers.js';

describe('crisis suite: keyword layer', () => {
  for (const { message, keywords } of ALL_CASES) {
    it(`"${message}" → ${keywords}`, () => {
      assert.equal(detectCrisisSignal(message), keywords);
    });
  }
});

describe('crisis suite: false positives and false negatives', () => {
  it('has no false negatives and no false positives in the keyword layer', (t) => {
    const missedRisk = RISK_CASES.filter((c) => detectCrisisSignal(c.message) !== 'risk');
    const flaggedNormal = NORMAL_CASES.filter((c) => detectCrisisSignal(c.message) !== 'normal');
    const ambiguous = [...AMBIGUOUS_RISK_CASES, ...AMBIGUOUS_SAFE_CASES];
    const notRouted = ambiguous.filter((c) => detectCrisisSignal(c.message) !== 'ambiguous');

    const share = (missed: unknown[], all: unknown[]) =>
      `${all.length - missed.length}/${all.length}`;
    t.diagnostic(`clear risk detected: ${share(missedRisk, [...RISK_CASES])}`);
    t.diagnostic(`normal messages let through: ${share(flaggedNormal, [...NORMAL_CASES])}`);
    t.diagnostic(`ambiguous sent to the second layer: ${share(notRouted, ambiguous)}`);

    assert.deepEqual(missedRisk, [], 'false negatives');
    assert.deepEqual(flaggedNormal, [], 'false positives');
    assert.deepEqual(notRouted, [], 'ambiguous messages not sent to the second layer');
  });

  it('without a second layer, misses no crisis', async (t) => {
    const filter = createCrisisFilter();
    let falseNegatives = 0;
    let falsePositives = 0;
    for (const { message, crisis } of ALL_CASES) {
      const decided = (await filter.check(message)).crisis;
      if (crisis && !decided) falseNegatives++;
      if (!crisis && decided) falsePositives++;
    }

    t.diagnostic(
      `conservative mode: ${falseNegatives} false negatives, ${falsePositives} false positives`,
    );
    assert.equal(falseNegatives, 0);
    assert.equal(falsePositives, AMBIGUOUS_SAFE_CASES.length);
  });
});

describe('crisis suite: POST /v1/chat', () => {
  const chat = createFakeLlm(() => '¡Qué dicha!');
  // Stands in for the second layer: it answers what the case expects, so this
  // checks the wiring; `npm run crisis:eval` checks the real classifier.
  const expected = new Map(ALL_CASES.map((c) => [c.message, c.crisis]));
  const classifier = createFakeLlm(({ messages }) =>
    expected.get(messages.at(-1)!.content) ? 'RISK' : 'SAFE',
  );
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: chat.llm, crisisClassifier: classifier.llm });
  });
  after(() => app.close());

  async function send(message: string) {
    const callsBefore = { chat: chat.requests.length, classifier: classifier.requests.length };
    const response = await app.postJson('/v1/chat', { message });
    const body = (await response.json()) as Record<string, any>;
    return {
      body,
      chatCalls: chat.requests.length - callsBefore.chat,
      classifierCalls: classifier.requests.length - callsBefore.classifier,
    };
  }

  for (const { message } of RISK_CASES) {
    it(`clear risk "${message}" never reaches any model and points to 9-1-1`, async () => {
      const { body, chatCalls, classifierCalls } = await send(message);
      assert.equal(body.type, 'crisis');
      assert.match(body.reply.content, /9-1-1/);
      assert.equal(body.resources[0].phone, '911');
      assert.equal(chatCalls, 0);
      assert.equal(classifierCalls, 0);
    });
  }

  for (const { message } of AMBIGUOUS_RISK_CASES) {
    it(`ambiguous risk "${message}" never reaches the conversation model`, async () => {
      const { body, chatCalls, classifierCalls } = await send(message);
      assert.equal(body.type, 'crisis');
      assert.match(body.reply.content, /9-1-1/);
      assert.equal(chatCalls, 0);
      assert.equal(classifierCalls, 1);
    });
  }

  for (const { message } of NORMAL_CASES) {
    it(`normal "${message}" goes to the conversation without the second layer`, async () => {
      const { body, chatCalls, classifierCalls } = await send(message);
      assert.equal(body.type, 'reply');
      assert.equal(chatCalls, 1);
      assert.equal(classifierCalls, 0);
    });
  }
});
