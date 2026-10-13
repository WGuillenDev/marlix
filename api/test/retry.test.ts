import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { LlmError, type LlmErrorKind } from '../src/services/llm/errors.js';
import { withRetry } from '../src/services/llm/retry.js';
import type { LlmProvider } from '../src/services/llm/types.js';
import { captureConsole } from './helpers.js';

const request = { messages: [{ role: 'user' as const, content: 'Hola' }] };

/** A provider that fails with the given kinds, in order, and then answers. */
function flakyProvider(failures: LlmErrorKind[]) {
  let calls = 0;
  const provider: LlmProvider = {
    name: 'fake',
    model: 'fake-model',
    async complete() {
      const kind = failures[calls++];
      if (kind) throw new LlmError(kind, kind);
      return { content: 'ok' };
    },
  };
  return { provider, calls: () => calls };
}

const quickRetry = { retries: 1, delayMs: 1 };

describe('withRetry', () => {
  for (const kind of ['timeout', 'unavailable'] as const) {
    it(`retries once after a ${kind} error`, async () => {
      const flaky = flakyProvider([kind]);
      const { result } = await captureConsole(() =>
        withRetry(flaky.provider, quickRetry).complete(request),
      );

      assert.equal(result.content, 'ok');
      assert.equal(flaky.calls(), 2);
    });
  }

  it('gives up after one retry', async () => {
    const flaky = flakyProvider(['unavailable', 'timeout']);
    await captureConsole(() =>
      assert.rejects(withRetry(flaky.provider, quickRetry).complete(request), { kind: 'timeout' }),
    );
    assert.equal(flaky.calls(), 2);
  });

  const permanentKinds = [
    'rate_limited',
    'authentication',
    'invalid_request',
    'empty_response',
  ] as const;
  for (const kind of permanentKinds) {
    it(`does not retry a ${kind} error`, async () => {
      const flaky = flakyProvider([kind]);
      await assert.rejects(withRetry(flaky.provider, quickRetry).complete(request), { kind });
      assert.equal(flaky.calls(), 1);
    });
  }

  it('does not retry when the caller cancelled the request', async () => {
    const flaky = flakyProvider(['timeout']);
    const controller = new AbortController();
    controller.abort();

    await assert.rejects(
      withRetry(flaky.provider, quickRetry).complete({ ...request, signal: controller.signal }),
      { kind: 'timeout' },
    );
    assert.equal(flaky.calls(), 1);
  });
});
