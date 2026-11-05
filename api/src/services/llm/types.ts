// LLM layer types (S1-3). The only contract the rest of the backend knows
// about the LLM: provider SDKs stay inside services/llm/, and everything else
// talks to an LlmProvider. See docs/architecture.md#the-llm-layer.

export type LlmRole = 'system' | 'user' | 'assistant';

export interface LlmMessage {
  role: LlmRole;
  content: string;
}

export interface LlmCompletionRequest {
  /** The full conversation for this call, system prompt first. */
  messages: readonly LlmMessage[];
  /** Upper bound for the reply, so one call cannot use the whole quota. */
  maxOutputTokens?: number;
  /** 0 makes the answer repeatable, as a classifier needs. Provider default if omitted. */
  temperature?: number;
  /** Lets the caller cancel the call, for example when the client disconnects. */
  signal?: AbortSignal;
}

export interface LlmUsage {
  inputTokens: number;
  outputTokens: number;
}

export interface LlmCompletion {
  /** The model's reply, already trimmed. Never empty. */
  content: string;
  usage?: LlmUsage;
}

export interface LlmProvider {
  readonly name: string;
  readonly model: string;
  /**
   * Returns the model's reply to the conversation. Fails only with an
   * LlmError, so callers never handle provider-specific errors.
   */
  complete(request: LlmCompletionRequest): Promise<LlmCompletion>;
  /**
   * Yields the model's reply in pieces as it is generated (S6-10). Fails only
   * with an LlmError, and may end without yielding anything. Stopping the
   * iteration, or aborting `request.signal`, cancels the call.
   */
  stream(request: LlmCompletionRequest): AsyncIterable<string>;
}
