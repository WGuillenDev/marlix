import type { AuthenticatedUser } from '../domain/authenticated-user.js';

export type SessionVerifier = (token: string) => Promise<AuthenticatedUser | null>;
