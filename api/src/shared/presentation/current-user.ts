import type { Response } from 'express';

import type { AuthenticatedUser } from '../../modules/identity/domain/authenticated-user.js';

export function setCurrentUser(res: Response, user: AuthenticatedUser): void {
  res.locals.user = user;
}

export function currentUser(res: Response): AuthenticatedUser {
  const user = res.locals.user as AuthenticatedUser | undefined;
  if (!user) throw new Error('Route reached without an authenticated user');
  return user;
}
