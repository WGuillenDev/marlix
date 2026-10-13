import { LlmError } from './errors.js';
import type { LlmProvider } from './types.js';

export interface RetryOptions {
  /** How many extra attempts after the first one. */
  retries: number;
  /** Pause before each retry, so a provider hiccup has time to clear. */
  delayMs: number;
}

const DEFAULT_RETRY: RetryOptions = { retries: 1, delayMs: 500 };

/**
 * Wraps any provider so transient failures (timeout, network, 5xx) are tried
 * again. Quota, authentication and request errors are not retried: trying
 * again would fail the same way, or spend quota that is already exhausted.
 */
export function withRetry(
  provider: LlmProvider,
  options: RetryOptions = DEFAULT_RETRY,
): LlmProvider {
  return {
    name: provider.name,
    model: provider.model,
    async complete(request) {
      for (let attempt = 0; ; attempt++) {
        try {
          return await provider.complete(request);
        } catch (error) {
          const canRetry =
            error instanceof LlmError &&
            error.isTransient &&
            attempt < options.retries &&
            !request.signal?.aborted;
          if (!canRetry) throw error;

          console.warn(`LLM call failed (${error.kind}), retrying`);
          await new Promise((resolve) => setTimeout(resolve, options.delayMs));
        }
      }
    },
  };
}
