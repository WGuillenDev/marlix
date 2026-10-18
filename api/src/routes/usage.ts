// GET /v1/usage (S2-6). Contract: docs/api-contract.md#get-v1usage.
import { Router } from 'express';

import { currentUser } from '../middleware/current-user.js';
import type { UsageLimiter } from '../services/usage/usage-limiter.js';

export function createUsageRouter(usageLimiter: UsageLimiter): Router {
  const router = Router();

  router.get('/usage', async (_req, res) => {
    res.status(200).json(await usageLimiter.snapshot(currentUser(res)));
  });

  return router;
}
