import { Router } from 'express';

import { currentUser } from '../../../shared/presentation/current-user.js';
import type { UsageLimiter } from '../application/usage-limiter.js';

export function createUsageRouter(usageLimiter: UsageLimiter): Router {
  const router = Router();

  router.get('/usage', async (_req, res) => {
    res.status(200).json(await usageLimiter.snapshot(currentUser(res)));
  });

  return router;
}
