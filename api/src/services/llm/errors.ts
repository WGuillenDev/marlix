// LLM layer errors (S1-3), provider-agnostic. Each adapter translates its
// provider's failures into one of these kinds, so the rest of the backend
// decides what to do (retry, wait, show an error) without knowing which
// provider failed.

export type LlmErrorKind =
  /** The provider's quota or rate limit is exhausted. Not retried right away. */
  | 'rate_limited'
  /** The call took longer than the configured timeout. Transient. */
  | 'timeout'
  /** Network failure or provider-side error (5xx). Transient. */
  | 'unavailable'
  /** The API key is missing, invalid or revoked. A configuration problem. */
  | 'authentication'
  /** The provider rejected the request itself (bad model, too many tokens). */
  | 'invalid_request'
  /** The provider answered without any usable text. */
  | 'empty_response';

const TRANSIENT_KINDS: ReadonlySet<LlmErrorKind> = new Set(['timeout', 'unavailable']);

/** `message` is for developers and logs: it never contains the conversation or an API key. */
export class LlmError extends Error {
  readonly kind: LlmErrorKind;
  /** For rate_limited: seconds the provider asked to wait before calling again. */
  readonly retryAfterSeconds: number | undefined;

  constructor(
    kind: LlmErrorKind,
    message: string,
    options: { retryAfterSeconds?: number; cause?: unknown } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = 'LlmError';
    this.kind = kind;
    this.retryAfterSeconds = options.retryAfterSeconds;
  }

  /** Transient failures are worth one more try; quota and auth errors are not. */
  get isTransient(): boolean {
    return TRANSIENT_KINDS.has(this.kind);
  }
}
