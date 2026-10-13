// Public entry point of the LLM layer (S1-3). Code outside services/llm/
// imports from here, never from a provider adapter or SDK.
import type { Env } from '../../config/env.js';
import { GroqProvider } from './groq-provider.js';
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

/** Creates the provider chosen by LLM_PROVIDER, configured from the environment. */
export function createLlmProvider(env: Env): LlmProvider {
  switch (env.LLM_PROVIDER) {
    case 'groq':
      return new GroqProvider({
        apiKey: env.GROQ_API_KEY,
        model: env.GROQ_MODEL,
        baseUrl: env.GROQ_BASE_URL,
        ...(env.GROQ_REASONING_EFFORT !== 'none'
          ? { reasoningEffort: env.GROQ_REASONING_EFFORT }
          : {}),
      });
  }
}
