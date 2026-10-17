// Central error handling (S1-6). Error bodies follow docs/api-contract.md#errors.
import type { ErrorRequestHandler, RequestHandler } from 'express';

import { MessageNotFoundError } from '../services/history/message-store.js';
import { LlmError } from '../services/llm/index.js';
import { UsageLimitExceededError } from '../services/usage/usage-limiter.js';

export interface ValidationIssue {
  field: string;
  message: string;
}

/**
 * An error that maps to one of the contract's error responses. Routes throw
 * it and the central handler turns it into the response body.
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: Record<string, unknown>,
    readonly headers: Record<string, string> = {},
  ) {
    super(message);
    this.name = 'ApiError';
  }

  static validation(message: string, fields?: ValidationIssue[]): ApiError {
    return new ApiError(400, 'VALIDATION_ERROR', message, fields ? { fields } : undefined);
  }
}

export const notFoundHandler: RequestHandler = (_req, _res, next) => {
  next(new ApiError(404, 'NOT_FOUND', 'Route not found.'));
};

/**
 * The single place where errors become responses. Users only ever get the
 * contract's error body with a fixed message: never a stack trace, an
 * internal message or the provider's text. Logs keep the kind of error,
 * never a request or response body.
 */
export const errorHandler: ErrorRequestHandler = (error, _req, res, next) => {
  if (res.headersSent) {
    next(error);
    return;
  }

  const apiError = toApiError(error);
  res.status(apiError.status).set(apiError.headers).json({
    error: {
      code: apiError.code,
      message: apiError.message,
      ...(apiError.details ? { details: apiError.details } : {}),
    },
  });
};

function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;

  if (error instanceof LlmError) {
    // A bad key is a configuration problem the developer must see.
    const log = error.kind === 'authentication' ? console.error : console.warn;
    log(`LLM call failed: ${error.kind}`);
    return new ApiError(
      503,
      'LLM_UNAVAILABLE',
      'The model is not available right now.',
      undefined,
      error.retryAfterSeconds ? { 'Retry-After': String(error.retryAfterSeconds) } : {},
    );
  }

  if (error instanceof MessageNotFoundError) {
    return new ApiError(404, 'NOT_FOUND', 'The message does not exist.');
  }

  if (error instanceof UsageLimitExceededError) {
    const { limit } = error;
    return limit.reason === 'daily_limit'
      ? new ApiError(429, 'DAILY_LIMIT_REACHED', 'Daily interaction limit reached.', {
          resetsAt: limit.resetsAt,
        })
      : new ApiError(429, 'RATE_LIMITED', 'Too many requests.', undefined, {
          'Retry-After': String(limit.retryAfterSeconds),
        });
  }

  // Errors from the JSON body parser. Their message quotes the body, which
  // can be a user's message, so only the type is used.
  const bodyErrorType = getBodyParserErrorType(error);
  if (bodyErrorType === 'entity.parse.failed') {
    return ApiError.validation('The request body is not valid JSON.');
  }
  if (bodyErrorType === 'entity.too.large') {
    return ApiError.validation('The request body is too large.');
  }
  if (bodyErrorType) {
    return ApiError.validation('The request body could not be read.');
  }

  logUnexpectedError(error);
  return new ApiError(500, 'INTERNAL_ERROR', 'Unexpected error.');
}

function getBodyParserErrorType(error: unknown): string | undefined {
  if (typeof error !== 'object' || error === null || !('type' in error)) return undefined;
  const { type } = error as { type: unknown };
  return typeof type === 'string' && type.startsWith('entity.') ? type : undefined;
}

// Logs the error's name and where it happened, but not its message, which
// could contain data from the request.
function logUnexpectedError(error: unknown): void {
  if (error instanceof Error) {
    const frames = error.stack?.split('\n').slice(1).join('\n') ?? '';
    console.error(`Unexpected error: ${error.name}\n${frames}`);
  } else {
    console.error(`Unexpected error: ${typeof error}`);
  }
}
