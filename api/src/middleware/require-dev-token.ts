import { createHash, timingSafeEqual } from 'node:crypto';

import type { RequestHandler } from 'express';

import { ApiError } from './error-handler.js';

const BEARER_PREFIX = 'Bearer ';

// Hashing both sides gives equal-length buffers, so the comparison takes the
// same time whatever the token sent, and nothing leaks about the real one.
function sha256(value: string): Buffer {
  return createHash('sha256').update(value).digest();
}

/**
 * Temporary access control (S1-7): only the developer, with the token from
 * DEV_ACCESS_TOKEN, can reach /v1 until the crisis filter exists (S2-1,
 * S2-3). It is replaced by the Supabase session check in S4-3.
 * Expects `Authorization: Bearer <token>`, like the real auth will.
 */
export function requireDevToken(expectedToken: string): RequestHandler {
  const expectedHash = sha256(expectedToken);

  return (req, _res, next) => {
    const header = req.get('authorization') ?? '';
    const token = header.startsWith(BEARER_PREFIX) ? header.slice(BEARER_PREFIX.length).trim() : '';

    if (!token || !timingSafeEqual(sha256(token), expectedHash)) {
      next(new ApiError(401, 'UNAUTHORIZED', 'Missing or invalid token.'));
      return;
    }
    next();
  };
}
