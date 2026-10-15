// Groq adapter for the LLM layer (S1-4). Decision and free plan limits:
// docs/decisions.md.
import OpenAI, {
  APIConnectionError,
  APIConnectionTimeoutError,
  APIError,
  APIUserAbortError,
} from 'openai';

import { LlmError } from './errors.js';
import type { LlmCompletion, LlmCompletionRequest, LlmProvider } from './types.js';

export const GROQ_DEFAULT_BASE_URL = 'https://api.groq.com/openai/v1';

// Used when a 429 arrives without any header that says how long to wait.
const DEFAULT_RETRY_AFTER_SECONDS = 10;
// A longer wait is treated as a misread header, not a real limit.
const MAX_RETRY_AFTER_SECONDS = 3600;
const DEFAULT_TIMEOUT_MS = 15_000;

export type GroqReasoningEffort = 'low' | 'medium' | 'high';

export interface GroqProviderOptions {
  apiKey: string;
  model: string;
  baseUrl?: string;
  /** Sent to reasoning models such as gpt-oss; omit it for models without reasoning. */
  reasoningEffort?: GroqReasoningEffort;
  timeoutMs?: number;
  /** For tests: replaces the HTTP client and the clock. */
  fetch?: typeof fetch;
  now?: () => number;
}

/**
 * LlmProvider on top of Groq, through the OpenAI SDK (Groq is compatible with
 * the OpenAI API). The API key only lives inside the SDK client: it is never
 * logged and never included in an error.
 */
export class GroqProvider implements LlmProvider {
  readonly name = 'groq';
  readonly model: string;

  readonly #client: OpenAI;
  readonly #reasoningEffort: GroqReasoningEffort | undefined;
  readonly #now: () => number;
  // While the quota is exhausted, calls fail right away instead of hitting
  // Groq again before the wait time it asked for.
  #blockedUntil = 0;

  constructor(options: GroqProviderOptions) {
    this.model = options.model;
    this.#reasoningEffort = options.reasoningEffort;
    this.#now = options.now ?? Date.now;
    this.#client = new OpenAI({
      apiKey: options.apiKey,
      baseURL: options.baseUrl ?? GROQ_DEFAULT_BASE_URL,
      timeout: options.timeoutMs ?? DEFAULT_TIMEOUT_MS,
      // Retries are decided by the backend, not hidden inside the SDK.
      maxRetries: 0,
      logLevel: 'off',
      ...(options.fetch ? { fetch: options.fetch } : {}),
    });
  }

  async complete(request: LlmCompletionRequest): Promise<LlmCompletion> {
    const waitSeconds = Math.ceil((this.#blockedUntil - this.#now()) / 1000);
    if (waitSeconds > 0) {
      throw new LlmError('rate_limited', 'Groq quota exhausted; waiting before calling again', {
        retryAfterSeconds: waitSeconds,
      });
    }

    let completion: OpenAI.Chat.Completions.ChatCompletion;
    try {
      completion = await this.#client.chat.completions.create(
        {
          model: this.model,
          messages: request.messages.map(({ role, content }) => ({ role, content })),
          ...(request.maxOutputTokens ? { max_completion_tokens: request.maxOutputTokens } : {}),
          ...(request.temperature !== undefined ? { temperature: request.temperature } : {}),
          ...(this.#reasoningEffort ? { reasoning_effort: this.#reasoningEffort } : {}),
        },
        request.signal ? { signal: request.signal } : undefined,
      );
    } catch (error) {
      throw this.#translateError(error);
    }

    const content = completion.choices[0]?.message.content?.trim();
    if (!content) {
      throw new LlmError(
        'empty_response',
        `Groq returned no text (finish reason: ${completion.choices[0]?.finish_reason ?? 'none'})`,
      );
    }

    return {
      content,
      ...(completion.usage
        ? {
            usage: {
              inputTokens: completion.usage.prompt_tokens,
              outputTokens: completion.usage.completion_tokens,
            },
          }
        : {}),
    };
  }

  // Only the status and the provider's error code go into the message: the
  // provider's own text could echo parts of the conversation.
  #translateError(error: unknown): LlmError {
    if (error instanceof APIConnectionTimeoutError) {
      return new LlmError('timeout', 'Groq did not answer in time', { cause: error });
    }
    if (error instanceof APIUserAbortError) {
      return new LlmError('unavailable', 'Groq call was cancelled', { cause: error });
    }
    if (error instanceof APIConnectionError) {
      return new LlmError('unavailable', 'Could not reach Groq', { cause: error });
    }
    if (!(error instanceof APIError)) {
      return new LlmError('unavailable', 'Unexpected error calling Groq', { cause: error });
    }

    const status = error.status ?? 0;
    const detail = `Groq responded ${status}${error.code ? ` (${error.code})` : ''}`;

    if (status === 429) {
      const retryAfterSeconds = parseRetryAfterSeconds(error.headers);
      this.#blockedUntil = this.#now() + retryAfterSeconds * 1000;
      return new LlmError('rate_limited', detail, { retryAfterSeconds, cause: error });
    }
    if (status === 401 || status === 403) {
      return new LlmError('authentication', detail, { cause: error });
    }
    if (status === 400 || status === 404 || status === 413 || status === 422) {
      return new LlmError('invalid_request', detail, { cause: error });
    }
    return new LlmError('unavailable', detail, { cause: error });
  }
}

/**
 * Seconds to wait after a 429. Groq sends `retry-after` in seconds; if it is
 * missing, the `x-ratelimit-reset-*` headers ("7.66s", "2m59.56s") are used.
 */
export function parseRetryAfterSeconds(headers: Headers | undefined): number {
  const retryAfter = headers?.get('retry-after');
  let seconds = retryAfter ? Number(retryAfter) : Number.NaN;

  if (Number.isNaN(seconds) && retryAfter) {
    const date = Date.parse(retryAfter);
    if (!Number.isNaN(date)) seconds = (date - Date.now()) / 1000;
  }

  if (Number.isNaN(seconds)) {
    const resets = ['x-ratelimit-reset-tokens', 'x-ratelimit-reset-requests']
      .map((name) => parseDuration(headers?.get(name)))
      .filter((value) => value !== undefined);
    if (resets.length > 0) seconds = Math.max(...resets);
  }

  if (Number.isNaN(seconds) || seconds <= 0) return DEFAULT_RETRY_AFTER_SECONDS;
  return Math.min(Math.ceil(seconds), MAX_RETRY_AFTER_SECONDS);
}

// Parses Groq's reset durations such as "250ms", "7.66s", "2m59.56s" or "1h2m".
function parseDuration(value: string | null | undefined): number | undefined {
  if (!value) return undefined;
  const parts = [...value.matchAll(/(\d+(?:\.\d+)?)(ms|h|m|s)/g)];
  if (parts.length === 0 || parts.map((part) => part[0]).join('') !== value) return undefined;

  const unitSeconds = { h: 3600, m: 60, s: 1, ms: 0.001 } as const;
  return parts.reduce((total, [, amount, unit]) => {
    const seconds = unitSeconds[unit as keyof typeof unitSeconds];
    return total + Number(amount) * seconds;
  }, 0);
}
