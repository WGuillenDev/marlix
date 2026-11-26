import { Router } from 'express';

import { currentUser } from '../../../shared/presentation/current-user.js';
import { ApiError } from '../../../shared/presentation/error-handler.js';
import type { AccountStore } from '../application/account-store.js';

import { deleteAccount } from '../application/delete-account.js';

export function createAccountRouter(
  accounts: AccountStore,
  now: () => Date = () => new Date(),
): Router {
  const router = Router();

  router.delete('/account', async (_req, res) => {
    if (!(await deleteAccount(accounts, currentUser(res), now()))) {
      throw new ApiError(
        401,
        'REAUTHENTICATION_REQUIRED',
        'Sign in again to delete the account.',
      );
    }
    res.status(204).end();
  });

  return router;
}
