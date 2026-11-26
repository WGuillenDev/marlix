
export type LlmRole = 'system' | 'user' | 'assistant';

export interface LlmMessage {
  role: LlmRole;
  content: string;
}

export interface LlmCompletionRequest {
  /** The full conversation for this call, system prompt first. */
  messages: readonly LlmMessage[];
  maxOutputTokens?: number;
  /** Zero requests the lowest sampling temperature for classification. */
  temperature?: number;
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
  /** Provider failures are normalized to LlmError. */
  complete(request: LlmCompletionRequest): Promise<LlmCompletion>;
  /** Stopping iteration or aborting the request signal cancels the provider call. */
  stream(request: LlmCompletionRequest): AsyncIterable<string>;
}
