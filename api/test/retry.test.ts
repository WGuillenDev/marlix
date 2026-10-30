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
    async *stream() {
      const kind = failures[calls++];
      if (kind) throw new LlmError(kind, kind);
      yield 'ok';
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

  describe('stream', () => {
    const collect = async (pieces: AsyncIterable<string>) => {
      const all: string[] = [];
      for await (const piece of pieces) all.push(piece);
      return all;
    };

    it('retries when the stream fails before any piece', async () => {
      const flaky = flakyProvider(['unavailable']);
      const { result } = await captureConsole(() =>
        collect(withRetry(flaky.provider, quickRetry).stream(request)),
      );

      assert.deepEqual(result, ['ok']);
      assert.equal(flaky.calls(), 2);
    });

    it('does not start over once a piece was delivered, so nothing is said twice', async () => {
      let calls = 0;
      const midway: LlmProvider = {
        ...flakyProvider([]).provider,
        async *stream() {
          calls++;
          yield 'Hola. ';
          throw new LlmError('timeout', 'cut');
        },
      };

      await assert.rejects(collect(withRetry(midway, quickRetry).stream(request)), {
        kind: 'timeout',
      });
      assert.equal(calls, 1);
    });

    it('does not retry a quota error', async () => {
      const flaky = flakyProvider(['rate_limited']);
      await assert.rejects(collect(withRetry(flaky.provider, quickRetry).stream(request)), {
        kind: 'rate_limited',
      });
      assert.equal(flaky.calls(), 1);
    });
  });
});
