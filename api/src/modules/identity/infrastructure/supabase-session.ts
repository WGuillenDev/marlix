import { createRemoteJWKSet, errors, jwtVerify, type JWTVerifyGetKey } from 'jose';

import type { SessionVerifier } from '../application/session-verifier.js';

// v1 has a single plan (plan_limits in docs/schema.sql). It is read from the
// profile once there is more than one (V2-2).
const V1_PLAN = 'personal';

export interface SessionCheck {
  issuer: string;
  keys: JWTVerifyGetKey;
}

/** The JWKS client caches signing keys and refreshes them when it sees a new key ID. */
export function supabaseSessionCheck(supabaseUrl: string): SessionCheck {
  return {
    issuer: new URL('/auth/v1', supabaseUrl).href,
    keys: createRemoteJWKSet(new URL('/auth/v1/.well-known/jwks.json', supabaseUrl)),
  };
}

export function verifySupabaseSession({ issuer, keys }: SessionCheck): SessionVerifier {
  return async (token) => {
    try {
      const { payload } = await jwtVerify(token, keys, {
        issuer,
        audience: 'authenticated',
        // Accept asymmetric signatures only. The backend does not hold a shared signing secret.
        algorithms: ['ES256', 'RS256'],
        requiredClaims: ['sub', 'exp'],
      });
      // The anon key is a token too; only a user's session reaches /v1.
      if (payload.role !== 'authenticated' || !payload.sub) return null;
      const signedInAt = lastSignInAt(payload.amr);
      return {
        id: payload.sub,
        plan: V1_PLAN,
        ...(signedInAt === undefined ? {} : { signedInAt }),
      };
    } catch (error) {
      if (error instanceof errors.JWKSTimeout || error instanceof errors.JWKSInvalid) throw error;
      if (error instanceof errors.JOSEError) return null;
      throw error;
    }
  };
}

function lastSignInAt(amr: unknown): number | undefined {
  if (!Array.isArray(amr)) return undefined;
  const times = amr
    .map((entry: unknown) => (entry as { timestamp?: unknown } | null)?.timestamp)
    .filter((time): time is number => typeof time === 'number' && Number.isFinite(time));
  return times.length > 0 ? Math.max(...times) : undefined;
}

