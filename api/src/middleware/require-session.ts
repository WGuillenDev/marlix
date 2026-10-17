import type { RequestHandler } from 'express';
import { createRemoteJWKSet, errors, jwtVerify, type JWTVerifyGetKey } from 'jose';

import { setCurrentUser } from './current-user.js';
import { ApiError } from './error-handler.js';

const BEARER_PREFIX = 'Bearer ';

// v1 has a single plan (plan_limits in docs/schema.sql). It is read from the
// profile once there is more than one (V2-2).
const V1_PLAN = 'personal';

export interface SessionCheck {
  /** `iss` of the project's tokens: `https://<project-ref>.supabase.co/auth/v1`. */
  issuer: string;
  /** Public keys the tokens are signed with. */
  keys: JWTVerifyGetKey;
}

/**
 * The Supabase project's signing keys, from its public JWKS endpoint. jose
 * keeps them in memory and fetches them again only for a key it does not
 * know, so a session check does not call Supabase on every request.
 */
export function supabaseSessionCheck(supabaseUrl: string): SessionCheck {
  return {
    issuer: new URL('/auth/v1', supabaseUrl).href,
    keys: createRemoteJWKSet(new URL('/auth/v1/.well-known/jwks.json', supabaseUrl)),
  };
}

/**
 * Lets through only requests with a valid Supabase access token (S4-3):
 * signed by the project, not expired, and issued to a signed-in user.
 * Expects `Authorization: Bearer <access token>` (docs/api-contract.md).
 */
export function requireSession({ issuer, keys }: SessionCheck): RequestHandler {
  return async (req, res, next) => {
    const header = req.get('authorization') ?? '';
    const token = header.startsWith(BEARER_PREFIX) ? header.slice(BEARER_PREFIX.length).trim() : '';
    if (!token) {
      next(unauthorized());
      return;
    }

    try {
      const { payload } = await jwtVerify(token, keys, {
        issuer,
        audience: 'authenticated',
        // Asymmetric keys only: an HS256 token would be signed with a shared
        // secret the backend does not hold, and `none` is never accepted.
        algorithms: ['ES256', 'RS256'],
        requiredClaims: ['sub', 'exp'],
      });
      // The anon key is a token too; only a user's session reaches /v1.
      if (payload.role !== 'authenticated' || !payload.sub) {
        next(unauthorized());
        return;
      }
      const signedInAt = lastSignInAt(payload.amr);
      setCurrentUser(res, {
        id: payload.sub,
        plan: V1_PLAN,
        ...(signedInAt === undefined ? {} : { signedInAt }),
      });
      next();
    } catch (error) {
      // Not reaching Supabase for the keys is our failure, not a bad token.
      const keysUnavailable =
        error instanceof errors.JWKSTimeout || error instanceof errors.JWKSInvalid;
      next(error instanceof errors.JOSEError && !keysUnavailable ? unauthorized() : error);
    }
  };
}

/** The newest `timestamp` of the token's `amr` claim, if it has a valid one. */
function lastSignInAt(amr: unknown): number | undefined {
  if (!Array.isArray(amr)) return undefined;
  const times = amr
    .map((entry: unknown) => (entry as { timestamp?: unknown } | null)?.timestamp)
    .filter((time): time is number => typeof time === 'number' && Number.isFinite(time));
  return times.length > 0 ? Math.max(...times) : undefined;
}

function unauthorized() {
  return new ApiError(401, 'UNAUTHORIZED', 'Missing or invalid token.');
}
