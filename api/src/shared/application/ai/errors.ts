
export type LlmErrorKind =
  | 'rate_limited'
  | 'timeout'
  | 'unavailable'
  | 'authentication'
  | 'invalid_request'
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

  get isTransient(): boolean {
    return TRANSIENT_KINDS.has(this.kind);
  }
}
