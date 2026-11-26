import type { Env } from '../config/env.js';
import { GroqProvider } from './groq-provider.js';
import type { QuotaMonitor } from './quota-monitor.js';
import { withRetry } from './retry.js';
import type { LlmProvider } from '../../application/ai/types.js';

export { LlmError, type LlmErrorKind } from '../../application/ai/errors.js';
export { GroqTranscriber, TRANSCRIPTION_PROMPT } from './groq-transcriber.js';
export { createQuotaMonitor, type QuotaMonitor } from './quota-monitor.js';
export type {
  LlmCompletion,
  LlmCompletionRequest,
  LlmMessage,
  LlmProvider,
  LlmRole,
  LlmUsage,
} from '../../application/ai/types.js';

export interface LlmProviderOverrides {
  model?: string;
  timeoutMs?: number;
  retry?: boolean;
  quota?: QuotaMonitor;
}

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
        ...(overrides.quota ? { quota: overrides.quota } : {}),
        ...(env.GROQ_REASONING_EFFORT !== 'none'
          ? { reasoningEffort: env.GROQ_REASONING_EFFORT }
          : {}),
      });
  }
}
