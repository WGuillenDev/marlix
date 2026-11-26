import type { RequestHandler } from 'express';

import type { SessionVerifier } from '../../modules/identity/application/session-verifier.js';
import { setCurrentUser } from './current-user.js';
import { ApiError } from './error-handler.js';

const BEARER_PREFIX = 'Bearer ';

export function requireSession(verify: SessionVerifier): RequestHandler {
  return async (req, res, next) => {
    const header = req.get('authorization') ?? '';
    const token = header.startsWith(BEARER_PREFIX) ? header.slice(BEARER_PREFIX.length).trim() : '';
    const user = token ? await verify(token) : null;
    if (!user) throw new ApiError(401, 'UNAUTHORIZED', 'Missing or invalid token.');
    setCurrentUser(res, user);
    next();
  };
}
