import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  createConsoleActivationLog,
  type CrisisActivation,
} from '../src/services/crisis/activation-log.js';
import { LlmError } from '../src/services/llm/index.js';
import { captureConsole, createFakeLlm, failingLlm, startApp } from './helpers.js';
import type { LlmProvider } from '../src/services/llm/index.js';

const MESSAGES = {
  risk: 'me quiero morir esta noche',
  ambiguous: 'siento que soy una carga',
  normal: 'hoy me fue bien',
};

/** Sends one message and returns what was recorded. */
async function recordFor(message: string, crisisClassifier?: LlmProvider) {
  const records: CrisisActivation[] = [];
  const app = await startApp({
    llm: createFakeLlm().llm,
    ...(crisisClassifier ? { crisisClassifier } : {}),
    activationLog: { record: (activation) => records.push(activation) },
  });
  try {
    await app.postJson('/v1/chat', { message });
    return records;
  } finally {
    await app.close();
  }
}

describe('crisis activation log', () => {
  const cases: [string, string, LlmProvider | undefined, Partial<CrisisActivation> | null][] = [
    ['clear risk', MESSAGES.risk, undefined, { signal: 'risk', layer: 'keywords' }],
    [
      'ambiguous, classified as risk',
      MESSAGES.ambiguous,
      createFakeLlm(() => 'RISK').llm,
      { signal: 'ambiguous', layer: 'classifier' },
    ],
    [
      'ambiguous, classifier failed',
      MESSAGES.ambiguous,
      failingLlm(new LlmError('timeout', 'timeout')),
      { signal: 'ambiguous', layer: 'classifier_failure' },
    ],
    [
      'ambiguous, no classifier',
      MESSAGES.ambiguous,
      undefined,
      { signal: 'ambiguous', layer: 'no_classifier' },
    ],
    ['ambiguous, classified as safe', MESSAGES.ambiguous, createFakeLlm(() => 'SAFE').llm, null],
    ['normal message', MESSAGES.normal, undefined, null],
  ];

  for (const [name, message, classifier, expected] of cases) {
    it(`${expected ? 'records' : 'does not record'} a ${name}`, async () => {
      const records = await recordFor(message, classifier);

      if (!expected) {
        assert.deepEqual(records, []);
        return;
      }
      assert.equal(records.length, 1);
      const [record] = records;
      assert.deepEqual(Object.keys(record!).sort(), ['at', 'layer', 'signal']);
      assert.equal(record!.signal, expected.signal);
      assert.equal(record!.layer, expected.layer);
      assert.ok(Math.abs(Date.parse(record!.at) - Date.now()) < 5000);
    });
  }

  it('keeps no trace of the words of the message', async () => {
    const [record] = await recordFor(MESSAGES.risk);
    const serialized = JSON.stringify(record);

    for (const word of MESSAGES.risk.split(' ')) {
      if (word.length > 3) assert.ok(!serialized.includes(word), `found "${word}"`);
    }
  });
});

describe('createConsoleActivationLog', () => {
  it('writes one JSON line that can be searched and counted', async () => {
    const { output } = await captureConsole(async () => {
      createConsoleActivationLog().record({
        at: '2026-10-14T03:00:00.000Z',
        signal: 'risk',
        layer: 'keywords',
      });
    });

    assert.deepEqual(JSON.parse(output), {
      event: 'crisis_activation',
      at: '2026-10-14T03:00:00.000Z',
      signal: 'risk',
      layer: 'keywords',
    });
  });
});
