import type { Response } from 'express';

export interface AuthenticatedUser {
  /** The Supabase Auth user id (`sub` of the session token). */
  id: string;
  plan: string;
  /**
   * When the person last entered their credentials, in seconds since the
   * epoch (the newest `amr` entry of the token). A token refresh does not
   * change it, which is what makes it a proof of a recent sign-in.
   */
  signedInAt?: number;
}

/** Set by the auth middleware; routes behind it can rely on it. */
export function setCurrentUser(res: Response, user: AuthenticatedUser): void {
  res.locals.user = user;
}

export function currentUser(res: Response): AuthenticatedUser {
  const user = res.locals.user as AuthenticatedUser | undefined;
  if (!user) throw new Error('Route reached without an authenticated user');
  return user;
}
