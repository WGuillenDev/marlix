// Public entry point of the LLM layer (S1-3). Code outside services/llm/
// imports from here, never from a provider adapter or SDK.
import type { Env } from '../../config/env.js';
import { GroqProvider } from './groq-provider.js';
import { withRetry } from './retry.js';
import type { LlmProvider } from './types.js';

export { LlmError, type LlmErrorKind } from './errors.js';
export type {
  LlmCompletion,
  LlmCompletionRequest,
  LlmMessage,
  LlmProvider,
  LlmRole,
  LlmUsage,
} from './types.js';

export interface LlmProviderOverrides {
  model?: string;
  timeoutMs?: number;
  /** One retry for transient failures. On by default. */
  retry?: boolean;
}

/**
 * Creates the provider chosen by LLM_PROVIDER, configured from the
 * environment. The conversation uses the defaults; the crisis classifier
 * passes its own model and timeout, without retry.
 */
export function createLlmProvider(env: Env, overrides: LlmProviderOverrides = {}): LlmProvider {
  const provider = createBaseProvider(env, overrides);
  return overrides.retry === false ? provider : withRetry(provider);
}

function createBaseProvider(env: Env, overrides: LlmProviderOverrides): LlmProvider {
  switch (env.LLM_PROVIDER) {
    case 'groq':
      return new GroqProvider({
        apiKey: env.GROQ_API_KEY,
        model: overrides.model ?? env.GROQ_MODEL,
        baseUrl: env.GROQ_BASE_URL,
        timeoutMs: overrides.timeoutMs ?? env.LLM_TIMEOUT_MS,
        ...(env.GROQ_REASONING_EFFORT !== 'none'
          ? { reasoningEffort: env.GROQ_REASONING_EFFORT }
          : {}),
      });
  }
}
