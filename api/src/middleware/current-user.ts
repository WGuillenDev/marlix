import type { Response } from 'express';

export interface AuthenticatedUser {
  id: string;
  plan: string;
}

/** The only identity until accounts exist (S4-3): whoever holds the development token. */
export const DEVELOPER: AuthenticatedUser = { id: 'developer', plan: 'personal' };

/** Set by the auth middleware; routes behind it can rely on it. */
export function setCurrentUser(res: Response, user: AuthenticatedUser): void {
  res.locals.user = user;
}

export function currentUser(res: Response): AuthenticatedUser {
  const user = res.locals.user as AuthenticatedUser | undefined;
  if (!user) throw new Error('Route reached without an authenticated user');
  return user;
}
