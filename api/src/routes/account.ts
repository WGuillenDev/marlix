// DELETE /v1/account (S4-9). Contract: docs/api-contract.md#delete-v1account.
import { Router } from 'express';

import { currentUser } from '../middleware/current-user.js';
import { ApiError } from '../middleware/error-handler.js';
import type { AccountStore } from '../services/account/account-store.js';

/** How recent the last sign-in must be to delete an account. */
export const RECENT_SIGN_IN_SECONDS = 5 * 60;

export function createAccountRouter(
  accounts: AccountStore,
  now: () => Date = () => new Date(),
): Router {
  const router = Router();

  router.delete('/account', async (_req, res) => {
    const { id, signedInAt } = currentUser(res);
    // Without the claim there is no proof, so it is treated as an old session.
    if (signedInAt === undefined || now().getTime() / 1000 - signedInAt > RECENT_SIGN_IN_SECONDS) {
      throw new ApiError(
        401,
        'REAUTHENTICATION_REQUIRED',
        'Sign in again to delete the account.',
      );
    }
    await accounts.deleteAccount(id);
    res.status(204).end();
  });

  return router;
}
