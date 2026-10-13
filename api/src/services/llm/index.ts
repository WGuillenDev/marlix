// Public entry point of the LLM layer (S1-3). Code outside services/llm/
// imports from here, never from a provider adapter or SDK.
export { LlmError, type LlmErrorKind } from './errors.js';
export type {
  LlmCompletion,
  LlmCompletionRequest,
  LlmMessage,
  LlmProvider,
  LlmRole,
  LlmUsage,
} from './types.js';
